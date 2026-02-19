#if canImport(HealthKit)
import HealthKit
#endif
import Foundation
import VITACore

/// Central manager for HealthKit authorization and observer query registration.
/// Coordinates all collectors and manages the authorization flow.
public final class HealthKitManager: @unchecked Sendable {
    #if canImport(HealthKit)
    private let healthStore: HKHealthStore
    #endif
    private let database: VITADatabase

    public private(set) var isAuthorized: Bool = false

    /// All HealthKit types VITA needs to read.
    public static let requiredReadTypes: Set<String> = [
        "HKQuantityTypeIdentifierHeartRateVariabilitySDNN",
        "HKQuantityTypeIdentifierHeartRate",
        "HKQuantityTypeIdentifierRestingHeartRate",
        "HKQuantityTypeIdentifierBodyMass",
        "HKQuantityTypeIdentifierBloodGlucose",
        "HKQuantityTypeIdentifierOxygenSaturation",
        "HKQuantityTypeIdentifierRespiratoryRate",
        "HKQuantityTypeIdentifierActiveEnergyBurned",
        "HKQuantityTypeIdentifierStepCount",
        "HKCategoryTypeIdentifierSleepAnalysis",
    ]

    public init(database: VITADatabase) {
        self.database = database
        #if canImport(HealthKit)
        self.healthStore = HKHealthStore()
        #endif
    }

    #if canImport(HealthKit)
    /// Request HealthKit authorization for all required types.
    public func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitError.healthDataNotAvailable
        }

        let readTypes: Set<HKObjectType> = [
            HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
            HKQuantityType.quantityType(forIdentifier: .heartRate)!,
            HKQuantityType.quantityType(forIdentifier: .restingHeartRate)!,
            HKQuantityType.quantityType(forIdentifier: .bodyMass)!,
            HKQuantityType.quantityType(forIdentifier: .bloodGlucose)!,
            HKQuantityType.quantityType(forIdentifier: .oxygenSaturation)!,
            HKQuantityType.quantityType(forIdentifier: .respiratoryRate)!,
            HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKQuantityType.quantityType(forIdentifier: .stepCount)!,
            HKCategoryType.categoryType(forIdentifier: .sleepAnalysis)!,
        ]

        try await healthStore.requestAuthorization(toShare: [], read: readTypes)
        isAuthorized = true
    }

    /// Enable background delivery for critical metrics.
    public func enableBackgroundDelivery() async throws {
        let criticalTypes: [(HKObjectType, HKUpdateFrequency)] = [
            (HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!, .immediate),
            (HKQuantityType.quantityType(forIdentifier: .heartRate)!, .hourly),
            (HKQuantityType.quantityType(forIdentifier: .restingHeartRate)!, .immediate),
            (HKQuantityType.quantityType(forIdentifier: .bloodGlucose)!, .immediate),
            (HKCategoryType.categoryType(forIdentifier: .sleepAnalysis)!, .hourly),
        ]

        for (type, frequency) in criticalTypes {
            try await healthStore.enableBackgroundDelivery(for: type, frequency: frequency)
        }
    }

    /// Access the underlying HKHealthStore for collectors.
    public var store: HKHealthStore {
        healthStore
    }
    #endif
}

// MARK: - Errors

public enum HealthKitError: Error, LocalizedError {
    case healthDataNotAvailable
    case authorizationDenied
    case queryFailed(String)
    case anchorDecodingFailed

    public var errorDescription: String? {
        switch self {
        case .healthDataNotAvailable:
            return "HealthKit is not available on this device."
        case .authorizationDenied:
            return "HealthKit authorization was denied."
        case .queryFailed(let detail):
            return "HealthKit query failed: \(detail)"
        case .anchorDecodingFailed:
            return "Failed to decode persisted HKQueryAnchor."
        }
    }
}
