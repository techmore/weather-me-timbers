import CoreLocation
import Foundation

@Observable
final class LocationService: NSObject, CLLocationManagerDelegate {
    var location: CLLocationCoordinate2D?
    var cityName = "Unknown"
    var authorizationStatus: CLAuthorizationStatus = .notDetermined
    var isLoading = false
    var error: String?

    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
    }

    func requestLocation() {
        isLoading = true
        authorizationStatus = manager.authorizationStatus

        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            isLoading = false
            error = "Location access denied. Use manual entry in Settings."
        case .authorized, .authorizedAlways:
            manager.requestLocation()
        @unknown default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        location = loc.coordinate
        isLoading = false
        reverseGeocode(loc)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        self.error = error.localizedDescription
        isLoading = false
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        if manager.authorizationStatus == .authorized {
            manager.requestLocation()
        }
    }

    private func reverseGeocode(_ location: CLLocation) {
        Task { @MainActor in
            do {
                let placemarks = try await geocoder.reverseGeocodeLocation(location)
                if let placemark = placemarks.first {
                    cityName = placemark.locality ?? placemark.administrativeArea ?? "Unknown"
                }
            } catch {
                self.error = "Geocoding failed: \(error.localizedDescription)"
            }
        }
    }
}
