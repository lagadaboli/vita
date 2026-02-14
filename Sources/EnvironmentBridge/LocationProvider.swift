#if canImport(CoreLocation)
import CoreLocation
#endif
import Foundation

/// Protocol for providing current location coordinates.
public protocol LocationProviding: Sendable {
    func currentLocation() async throws -> (latitude: Double, longitude: Double)
}

/// Tries multiple location providers in order until one succeeds.
public final class FallbackLocationProvider: LocationProviding, @unchecked Sendable {
    private let providers: [any LocationProviding]

    public init(providers: [any LocationProviding]) {
        self.providers = providers
    }

    public func currentLocation() async throws -> (latitude: Double, longitude: Double) {
        var lastError: Error?

        for provider in providers {
            do {
                return try await provider.currentLocation()
            } catch {
                lastError = error
            }
        }

        throw lastError ?? LocationError.unableToResolve
    }
}

/// Wraps a location provider with a timeout to prevent hanging indefinitely.
public final class TimeoutLocationProvider: LocationProviding, @unchecked Sendable {
    private let base: any LocationProviding
    private let timeoutSeconds: Double

    public init(base: any LocationProviding, timeoutSeconds: Double) {
        self.base = base
        self.timeoutSeconds = timeoutSeconds
    }

    public func currentLocation() async throws -> (latitude: Double, longitude: Double) {
        try await withThrowingTaskGroup(of: (latitude: Double, longitude: Double).self) { group in
            group.addTask {
                try await self.base.currentLocation()
            }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(self.timeoutSeconds * 1_000_000_000))
                throw LocationError.timedOut
            }

            let location = try await group.next()!
            group.cancelAll()
            return location
        }
    }
}

/// IP-based geolocation provider using a public API.
/// No API key required.
public struct IPGeolocationProvider: LocationProviding, Sendable {
    public init() {}

    public func currentLocation() async throws -> (latitude: Double, longitude: Double) {
        let url = URL(string: "https://ipwho.is/")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(IPWhoIsResponse.self, from: data)

        guard response.success else {
            throw LocationError.ipGeolocationFailed(response.message ?? "IP geolocation request failed.")
        }

        guard let latitude = response.latitude, let longitude = response.longitude else {
            throw LocationError.invalidCoordinates
        }

        return (latitude: latitude, longitude: longitude)
    }
}

private struct IPWhoIsResponse: Codable, Sendable {
    let success: Bool
    let latitude: Double?
    let longitude: Double?
    let message: String?
}

/// Fallback location provider that returns a configurable static location.
/// Used on macOS, in tests, and when CoreLocation is unavailable.
public final class StaticLocationProvider: LocationProviding, Sendable {
    private let latitude: Double
    private let longitude: Double

    /// Default: San Francisco, CA.
    public init(latitude: Double = 37.7749, longitude: Double = -122.4194) {
        self.latitude = latitude
        self.longitude = longitude
    }

    public func currentLocation() async throws -> (latitude: Double, longitude: Double) {
        (latitude: latitude, longitude: longitude)
    }
}

#if canImport(CoreLocation)
/// Real location provider using CLLocationManager.
/// Requests `.whenInUse` authorization.
public final class CoreLocationProvider: NSObject, LocationProviding, CLLocationManagerDelegate, @unchecked Sendable {
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<(latitude: Double, longitude: Double), Error>?

    public override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    public func currentLocation() async throws -> (latitude: Double, longitude: Double) {
        // Return cached location if available and recent
        if let location = manager.location,
           Date().timeIntervalSince(location.timestamp) < 600 {
            return (latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
        }

        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation

            let status: CLAuthorizationStatus
            if #available(iOS 14.0, macOS 11.0, *) {
                status = manager.authorizationStatus
            } else {
                status = CLLocationManager.authorizationStatus()
            }

            switch status {
            case .notDetermined:
                manager.requestWhenInUseAuthorization()
            case .authorizedWhenInUse, .authorizedAlways:
                manager.requestLocation()
            case .denied, .restricted:
                self.continuation = nil
                continuation.resume(throwing: LocationError.authorizationDenied)
            @unknown default:
                self.continuation = nil
                continuation.resume(throwing: LocationError.unknown)
            }
        }
    }

    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        continuation?.resume(returning: (latitude: location.coordinate.latitude, longitude: location.coordinate.longitude))
        continuation = nil
    }

    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        continuation?.resume(throwing: error)
        continuation = nil
    }

    public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status: CLAuthorizationStatus
        if #available(iOS 14.0, macOS 11.0, *) {
            status = manager.authorizationStatus
        } else {
            status = CLLocationManager.authorizationStatus()
        }

        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        case .denied, .restricted:
            continuation?.resume(throwing: LocationError.authorizationDenied)
            continuation = nil
        default:
            break
        }
    }
}
#endif

public enum LocationError: Error, LocalizedError {
    case authorizationDenied
    case timedOut
    case ipGeolocationFailed(String)
    case invalidCoordinates
    case unableToResolve
    case unknown

    public var errorDescription: String? {
        switch self {
        case .authorizationDenied:
            return "Location access was denied."
        case .timedOut:
            return "Timed out while requesting location."
        case .ipGeolocationFailed(let message):
            return "IP geolocation failed: \(message)"
        case .invalidCoordinates:
            return "Location API returned invalid coordinates."
        case .unableToResolve:
            return "Unable to resolve current location from available providers."
        case .unknown:
            return "Unknown location error."
        }
    }
}
