#if canImport(CoreLocation)
import CoreLocation
#endif
import Foundation

/// Protocol for providing current location coordinates.
public protocol LocationProviding: Sendable {
    func currentLocation() async throws -> (latitude: Double, longitude: Double)
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
    case unknown

    public var errorDescription: String? {
        switch self {
        case .authorizationDenied:
            return "Location access was denied."
        case .unknown:
            return "Unknown location error."
        }
    }
}
