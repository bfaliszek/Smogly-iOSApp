import Foundation
import CoreLocation

class AirQualityService: ObservableObject {
    private let baseURL = "http://api.myopenair.com:5000/api/v1/airpollution"
    private let locationManager: LocationManager
    
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    init(locationManager: LocationManager) {
        self.locationManager = locationManager
    }
    
    func fetchAirQualityData(latitude: Double, longitude: Double, datasource: DataSource = .all) async throws -> AirQualityResponse {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        defer {
            Task { @MainActor in
                isLoading = false
            }
        }
        
        var components = URLComponents(string: baseURL)!
        components.queryItems = [
            URLQueryItem(name: "lat", value: String(latitude)),
            URLQueryItem(name: "long", value: String(longitude)),
            URLQueryItem(name: "datasource", value: datasource.rawValue)
        ]
        
        guard let url = components.url else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 30
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }
            
            guard httpResponse.statusCode == 200 else {
                throw NetworkError.serverError(httpResponse.statusCode)
            }
            
            // Debug: Print the raw response
            if let jsonString = String(data: data, encoding: .utf8) {
                print("API Response: \(jsonString)")
            }
            
            let decoder = JSONDecoder()
            let airQualityResponse = try decoder.decode(AirQualityResponse.self, from: data)
            
            return airQualityResponse
        } catch {
            if let decodingError = error as? DecodingError {
                print("Decoding error: \(decodingError)")
                throw NetworkError.decodingError(decodingError)
            }
            print("Network error: \(error)")
            throw NetworkError.networkError(error)
        }
    }
    
    func fetchAirQualityForCurrentLocation(datasource: DataSource = .all) async throws -> AirQualityResponse {
        do {
            let location = try await locationManager.getCurrentLocation()
            return try await fetchAirQualityData(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                datasource: datasource
            )
        } catch {
            // Fallback to default location if user location is not available
            let defaultLatitude = 52.229770
            let defaultLongitude = 21.011780
            
            return try await fetchAirQualityData(
                latitude: defaultLatitude,
                longitude: defaultLongitude,
                datasource: datasource
            )
        }
    }
    
    func fetchAirQualityWithFallback(datasource: DataSource) async throws -> AirQualityResponse {
        do {
            return try await fetchAirQualityForCurrentLocation(datasource: datasource)
        } catch {
            // If the selected datasource fails, try with ALL datasource
            if datasource != .all {
                print("Failed to fetch data for datasource \(datasource.rawValue), falling back to ALL")
                return try await fetchAirQualityForCurrentLocation(datasource: .all)
            } else {
                // If ALL also fails, re-throw the error
                throw error
            }
        }
    }
}

// MARK: - Network Errors
enum NetworkError: LocalizedError {
    case invalidURL
    case invalidResponse
    case serverError(Int)
    case decodingError(DecodingError)
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .serverError(let code):
            return "Server error with code: \(code)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription). Please check the console for details."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
} 
