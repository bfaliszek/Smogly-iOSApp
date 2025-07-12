import SwiftUI
import MapKit

struct ContentView: View {
    @StateObject private var locationManager = LocationManager()
    @StateObject private var airQualityService: AirQualityService
    @StateObject private var userDefaultsManager = UserDefaultsManager()
    @State private var airQualityData: [AirQualityData] = []
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 50.172816, longitude: 19.143306),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )
    @State private var showingDataSourcePicker = false
    @State private var showingError = false
    @State private var showingFallbackAlert = false
    @State private var fallbackMessage = ""
    
    init() {
        let locationManager = LocationManager()
        self._locationManager = StateObject(wrappedValue: locationManager)
        self._airQualityService = StateObject(wrappedValue: AirQualityService(locationManager: locationManager))
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Map View
                Map(coordinateRegion: $region, showsUserLocation: true, annotationItems: airQualityData) { data in
                    MapAnnotation(coordinate: CLLocationCoordinate2D(
                        latitude: data.location.coordinates[1],
                        longitude: data.location.coordinates[0]
                    )) {
                        AirQualityAnnotationView(data: data)
                    }
                }
                .frame(height: 300)
                .overlay(
                    VStack {
                        HStack {
                            Spacer()
                            Button(action: centerOnUserLocation) {
                                Image(systemName: "location.fill")
                                    .font(.title2)
                                    .foregroundColor(.white)
                                    .frame(width: 44, height: 44)
                                    .background(Color.blue)
                                    .clipShape(Circle())
                                    .shadow(radius: 2)
                            }
                            .padding(.trailing, 16)
                            .padding(.top, 16)
                        }
                        Spacer()
                    }
                )
                
                // Air Quality Data Display
                ScrollView {
                    VStack(spacing: 16) {
                        // Data Source Selector
                        HStack {
                            Text("Data Source:")
                                .font(.headline)
                            Spacer()
                            Button(userDefaultsManager.selectedDataSource.displayName) {
                                showingDataSourcePicker = true
                            }
                            .foregroundColor(.blue)
                        }
                        .padding(.horizontal)
                        
                        // Air Quality Cards
                        if airQualityData.isEmpty && !airQualityService.isLoading {
                            VStack {
                                CloudIcon(size: 80, color: .gray)
                                Text("No air quality data available")
                                    .font(.title2)
                                    .foregroundColor(.gray)
                                Text("Tap refresh to load data")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            .padding()
                        } else {
                            LazyVStack(spacing: 12) {
                                ForEach(airQualityData) { data in
                                    AirQualityCard(data: data)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("🌤️ Smogly Air Quality")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: loadAirQualityData) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(airQualityService.isLoading)
                }
            }
            .sheet(isPresented: $showingDataSourcePicker) {
                DataSourcePickerView(selectedDataSource: $userDefaultsManager.selectedDataSource)
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(airQualityService.errorMessage ?? "Unknown error occurred")
            }
            .alert("Data Source Fallback", isPresented: $showingFallbackAlert) {
                Button("OK") { }
            } message: {
                Text("Unable to fetch data from the selected source. Using 'All Sources' instead.")
            }
            .onAppear {
                locationManager.requestLocationPermission()
                loadAirQualityData()
            }
            .onChange(of: userDefaultsManager.selectedDataSource) { _ in
                loadAirQualityData()
            }
            .onChange(of: locationManager.location) { location in
                if let location = location {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        region.center = location.coordinate
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                loadAirQualityData()
            }
        }
    }
    
    private func loadAirQualityData() {
        Task {
            do {
                let response = try await airQualityService.fetchAirQualityWithFallback(datasource: userDefaultsManager.selectedDataSource)
                await MainActor.run {
                    // Convert single response to array format for display
                    self.airQualityData = [response.toAirQualityData()]
                    self.showingError = false
                    self.showingFallbackAlert = false
                }
            } catch {
                await MainActor.run {
                    self.airQualityService.errorMessage = error.localizedDescription
                    self.showingError = true
                }
            }
        }
    }
    
    private func centerOnUserLocation() {
        if let location = locationManager.location {
            withAnimation(.easeInOut(duration: 0.5)) {
                region.center = location.coordinate
            }
        } else {
            locationManager.startLocationUpdates()
        }
    }
}

// MARK: - Air Quality Card View
struct AirQualityCard: View {
    let data: AirQualityData
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Source: \(data.datasource)")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
                Text(formatTimestamp(data.timestamp))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Divider()
            
            ForEach(data.measurements, id: \.parameter) { measurement in
                if measurement.parameter == "PM2.5" || measurement.parameter == "PM10" {
                    HStack {
                        Text(measurement.parameter)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Spacer()
                        Text("\(String(format: "%.1f", measurement.value)) \(measurement.unit)")
                            .font(.subheadline)
                            .foregroundColor(getColorForParameter(measurement.parameter, value: measurement.value))
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    private func formatTimestamp(_ timestamp: String) -> String {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: timestamp) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .short
            displayFormatter.timeStyle = .short
            return displayFormatter.string(from: date)
        }
        return timestamp
    }
    
    private func getColorForParameter(_ parameter: String, value: Double) -> Color {
        switch parameter {
        case "PM2.5":
            return getPM25Color(value)
        case "PM10":
            return getPM10Color(value)
        default:
            return .primary
        }
    }
    
    private func getPM25Color(_ value: Double) -> Color {
        switch value {
        case 0..<12: return .green
        case 12..<35.4: return .yellow
        case 35.4..<55.4: return .orange
        case 55.4..<150.4: return .red
        case 150.4..<250.4: return .purple
        default: return Color(red: 0.5, green: 0, blue: 0)
        }
    }
    
    private func getPM10Color(_ value: Double) -> Color {
        switch value {
        case 0..<54: return .green
        case 54..<154: return .yellow
        case 154..<254: return .orange
        case 254..<354: return .red
        case 354..<424: return .purple
        default: return Color(red: 0.5, green: 0, blue: 0)
        }
    }
}

// MARK: - Map Annotation View
struct AirQualityAnnotationView: View {
    let data: AirQualityData
    
    var body: some View {
        VStack {
            Image(systemName: "aqi.medium")
                .font(.title2)
                .foregroundColor(.white)
                .frame(width: 30, height: 30)
                .background(getAnnotationColor())
                .clipShape(Circle())
            
            Text(data.datasource)
                .font(.caption2)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(Color(.systemBackground))
                .cornerRadius(4)
        }
    }
    
    private func getAnnotationColor() -> Color {
        let pm25Measurement = data.measurements.first { $0.parameter == "PM2.5" }
        if let pm25 = pm25Measurement {
            return getPM25Color(pm25.value)
        }
        return .gray
    }
    
    private func getPM25Color(_ value: Double) -> Color {
        switch value {
        case 0..<12: return .green
        case 12..<35.4: return .yellow
        case 35.4..<55.4: return .orange
        case 55.4..<150.4: return .red
        case 150.4..<250.4: return .purple
        default: return Color(red: 0.5, green: 0, blue: 0)
        }
    }
}

// MARK: - Data Source Picker View
struct DataSourcePickerView: View {
    @Binding var selectedDataSource: DataSource
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List(DataSource.allCases, id: \.self) { dataSource in
                Button(action: {
                    selectedDataSource = dataSource
                    dismiss()
                }) {
                    HStack {
                        Text(dataSource.displayName)
                            .foregroundColor(.primary)
                        Spacer()
                        if selectedDataSource == dataSource {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
            .navigationTitle("Select Data Source")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    ContentView()
} 