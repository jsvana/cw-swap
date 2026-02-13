import CoreLocation
import Observation

@MainActor
@Observable
final class LocationManager: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()

    var lastLocation: CLLocationCoordinate2D?
    var authorizationStatus: CLAuthorizationStatus
    var isLocating = false
    var error: Error?

    private var continuation: CheckedContinuation<CLLocationCoordinate2D?, Never>?

    override init() {
        authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
    }

    /// Request a single location fix. Returns the coordinate, or nil on failure/denial.
    func requestSingleLocation() async -> CLLocationCoordinate2D? {
        error = nil

        switch authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
            // Wait for authorization callback, then proceed
            let status = await withCheckedContinuation { (cont: CheckedContinuation<CLAuthorizationStatus, Never>) in
                authContinuation = cont
            }
            guard status == .authorizedWhenInUse || status == .authorizedAlways else {
                return nil
            }
        case .denied, .restricted:
            return nil
        case .authorizedWhenInUse, .authorizedAlways:
            break
        @unknown default:
            break
        }

        isLocating = true
        let location = await withCheckedContinuation { (cont: CheckedContinuation<CLLocationCoordinate2D?, Never>) in
            continuation = cont
            manager.requestLocation()
        }
        isLocating = false
        lastLocation = location
        return location
    }

    // MARK: - CLLocationManagerDelegate

    private var authContinuation: CheckedContinuation<CLAuthorizationStatus, Never>?

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            self.authorizationStatus = status
            if let cont = self.authContinuation {
                self.authContinuation = nil
                cont.resume(returning: status)
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let coordinate = locations.last?.coordinate
        Task { @MainActor in
            if let cont = self.continuation {
                self.continuation = nil
                cont.resume(returning: coordinate)
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            self.error = error
            if let cont = self.continuation {
                self.continuation = nil
                cont.resume(returning: nil)
            }
        }
    }
}
