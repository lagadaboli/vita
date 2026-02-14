import Foundation
import VITACore

/// Coordinator for environmental data collection.
/// Fetches weather, AQI, and pollen data from Open-Meteo on a 30-minute interval.
public final class EnvironmentBridge: @unchecked Sendable {
    private let database: VITADatabase
    private let healthGraph: HealthGraph
    private let client: OpenMeteoClient
    private let locationProvider: LocationProviding
    private var monitoringTask: Task<Void, Never>?

    /// Polling interval: 30 minutes.
    private let pollingInterval: TimeInterval = 30 * 60

    public init(
        database: VITADatabase,
        healthGraph: HealthGraph,
        client: OpenMeteoClient = OpenMeteoClient(),
        locationProvider: LocationProviding? = nil
    ) {
        self.database = database
        self.healthGraph = healthGraph
        self.client = client

        #if canImport(CoreLocation)
        self.locationProvider = locationProvider ?? CoreLocationProvider()
        #else
        self.locationProvider = locationProvider ?? StaticLocationProvider()
        #endif
    }

    /// Start monitoring: fetch immediately, then every 30 minutes.
    public func startMonitoring() {
        monitoringTask?.cancel()
        monitoringTask = Task { [weak self] in
            guard let self else { return }

            // Initial fetch
            await self.fetchAndIngest()

            // Periodic polling
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(self.pollingInterval * 1_000_000_000))
                guard !Task.isCancelled else { break }
                await self.fetchAndIngest()
            }
        }
    }

    /// Stop monitoring.
    public func stopMonitoring() {
        monitoringTask?.cancel()
        monitoringTask = nil
    }

    /// Fetch environmental data from Open-Meteo and ingest into the health graph.
    public func fetchAndIngest() async {
        do {
            let location = try await locationProvider.currentLocation()
            var condition = try await client.fetchAll(latitude: location.latitude, longitude: location.longitude)
            try healthGraph.ingest(&condition)
        } catch {
            // Log silently — environment data is non-critical
            #if DEBUG
            print("[EnvironmentBridge] Fetch failed: \(error.localizedDescription)")
            #endif
        }
    }
}
