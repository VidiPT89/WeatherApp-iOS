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

    /// `CLLocationManager.requestLocation()` gives no guarantee on how long a fix takes -- indoors
    /// or with weak GPS/WiFi signal it can hang well past what's reasonable for a "where am I"
    /// weather lookup, with nothing surfacing to the caller in the meantime. This bounds the wait
    /// so a bad fix fails fast instead of leaving the caller (and the UI) stuck indefinitely.
    private static let locationTimeout: Duration = .seconds(15)

    func requestCurrentLocation() async throws -> CLLocationCoordinate2D {
        try await withThrowingTaskGroup(of: CLLocationCoordinate2D.self) { group in
            group.addTask { try await self.awaitLocation() }
            group.addTask {
                try await Task.sleep(for: Self.locationTimeout)
                throw LocationError.unavailable
            }
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }

    /// Wrapped in `withTaskCancellationHandler` because `requestCurrentLocation`'s timeout branch
    /// cancels this task (via `group.cancelAll()`) once it loses the race -- plain `Task`
    /// cancellation does NOT resume a suspended `CheckedContinuation` on its own, so without this
    /// handler a timed-out call would leak its continuation forever (a runtime-logged misuse) and
    /// leave `self.continuation` pointing at it. A caller that retries right after a timeout would
    /// then overwrite `self.continuation` with its own, and if CoreLocation's delegate callback for
    /// the *first*, abandoned request fires late, it would resolve the *second* request's
    /// continuation with the first request's (stale/unrelated) coordinate instead of its own.
    private func awaitLocation() async throws -> CLLocationCoordinate2D {
        try await withTaskCancellationHandler {
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
        } onCancel: {
            Task { @MainActor in
                self.continuation?.resume(throwing: CancellationError())
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
