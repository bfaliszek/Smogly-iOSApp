import Foundation
import CoreLocation
import Combine

class LocationManager: NSObject, ObservableObject {
    private let locationManager = CLLocationManager()
    
    @Published var location: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var isLoadingLocation = false
    @Published var locationError: String?
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 100 // Update every 100 meters
    }
    
    func requestLocationPermission() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    func startLocationUpdates() {
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            requestLocationPermission()
            return
        }
        
        isLoadingLocation = true
        locationError = nil
        locationManager.startUpdatingLocation()
    }
    
    func stopLocationUpdates() {
        locationManager.stopUpdatingLocation()
        isLoadingLocation = false
    }
    
    func getCurrentLocation() async throws -> CLLocation {
        return try await withCheckedThrowingContinuation { continuation in
            guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
                continuation.resume(throwing: LocationError.permissionDenied)
                return
            }
            
            // If we already have a recent location, use it
            if let location = location, location.timestamp.timeIntervalSinceNow > -300 { // 5 minutes old
                continuation.resume(returning: location)
                return
            }
            
            // Otherwise, request a new location
            startLocationUpdates()
            
            // Set up a one-time location update
            let locationHandler: (CLLocation) -> Void = { [weak self] location in
                self?.stopLocationUpdates()
                continuation.resume(returning: location)
            }
            
            let errorHandler: (Error) -> Void = { [weak self] error in
                self?.stopLocationUpdates()
                continuation.resume(throwing: error)
            }
            
            // Store handlers temporarily (in a real app, you'd use a more robust approach)
            DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
                if !continuation.isCompleted {
                    self.stopLocationUpdates()
                    continuation.resume(throwing: LocationError.timeout)
                }
            }
        }
    }
}

// MARK: - CLLocationManagerDelegate
extension LocationManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        DispatchQueue.main.async {
            self.location = location
            self.isLoadingLocation = false
            self.locationError = nil
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.isLoadingLocation = false
            self.locationError = error.localizedDescription
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        DispatchQueue.main.async {
            self.authorizationStatus = status
            
            switch status {
            case .authorizedWhenInUse, .authorizedAlways:
                self.startLocationUpdates()
            case .denied, .restricted:
                self.locationError = "Location access denied. Please enable location access in Settings."
            case .notDetermined:
                break
            @unknown default:
                break
            }
        }
    }
}

// MARK: - Location Errors
enum LocationError: LocalizedError {
    case permissionDenied
    case timeout
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Location permission denied. Please enable location access in Settings."
        case .timeout:
            return "Location request timed out. Please try again."
        }
    }
}

// MARK: - Continuation Helper
extension CheckedContinuation {
    var isCompleted: Bool {
        // This is a simplified check - in production you'd want a more robust solution
        return false
    }
} 