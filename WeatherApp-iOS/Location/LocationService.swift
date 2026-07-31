import CoreLocation

enum LocationError: LocalizedError {
    case permissionDenied
    case unavailable

    var errorDescription: String? {
        switch self {
        case .permissionDenied: return "Localização não autorizada."
        case .unavailable: return "Não foi possível obter a tua localização."
        }
    }
}

/// Wraps CoreLocation's delegate-based API in a single async call: requests
/// when-in-use authorization if not yet determined, then a one-shot location
/// fix, resolving a single continuation from whichever delegate callback fires.
@MainActor
final class LocationService: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocationCoordinate2D, Error>?

    override init() {
        super.init()
        manager.delegate = self
        // A weather lookup only needs city-level precision -- the default `.best` accuracy makes
        // CoreLocation wait for a fine-grained GPS lock (slow, especially indoors/cold-start),
        // when a much faster WiFi/cell-based fix is already precise enough for reverse-geocoding
        // to a city.
        manager.desiredAccuracy = kCLLocationAccuracyReduced
    }

    func requestCurrentLocation() async throws -> CLLocationCoordinate2D {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation

            switch manager.authorizationStatus {
            case .denied, .restricted:
                continuation.resume(throwing: LocationError.permissionDenied)
                self.continuation = nil
            case .notDetermined:
                manager.requestWhenInUseAuthorization()
            case .authorizedWhenInUse, .authorizedAlways:
                manager.requestLocation()
            @unknown default:
                continuation.resume(throwing: LocationError.unavailable)
                self.continuation = nil
            }
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            switch self.manager.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                self.manager.requestLocation()
            case .denied, .restricted:
                continuation?.resume(throwing: LocationError.permissionDenied)
                continuation = nil
            case .notDetermined:
                break
            @unknown default:
                continuation?.resume(throwing: LocationError.unavailable)
                continuation = nil
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            guard let location = locations.first else { return }
            continuation?.resume(returning: location.coordinate)
            continuation = nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            continuation?.resume(throwing: error)
            continuation = nil
        }
    }
}
