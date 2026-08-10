import Foundation

#if canImport(HealthKit)
import HealthKit
#endif

// MARK: - Protocol

protocol StepProviding: Sendable {
    /// Whether HealthKit step reads are available on this device (never required for paid features).
    var isHealthKitAvailable: Bool { get }

    func requestHealthKitAuthorization() async throws -> Bool
    func healthKitSteps(on localDate: Date) async throws -> Int?
    func manualEntry(localDate: Date, steps: Int, existingID: UUID?) -> StepEntry
}

// MARK: - Service

struct StepService: StepProviding {
    #if canImport(HealthKit)
    private let healthStore: HKHealthStore?
    #endif

    init() {
        #if canImport(HealthKit)
        if HKHealthStore.isHealthDataAvailable() {
            healthStore = HKHealthStore()
        } else {
            healthStore = nil
        }
        #endif
    }

    var isHealthKitAvailable: Bool {
        #if canImport(HealthKit)
        return healthStore != nil
        #else
        return false
        #endif
    }

    /// Requests read access for step count. Declining does **not** block coaching, logging, or paid features.
    func requestHealthKitAuthorization() async throws -> Bool {
        #if canImport(HealthKit)
        guard let healthStore,
              let stepType = HKObjectType.quantityType(forIdentifier: .stepCount) else {
            return false
        }
        try await healthStore.requestAuthorization(toShare: [], read: [stepType])
        return true
        #else
        return false
        #endif
    }

    /// Optional HealthKit read for a local calendar day. Returns `nil` if unavailable or unauthorized.
    func healthKitSteps(on localDate: Date) async throws -> Int? {
        #if canImport(HealthKit)
        guard let healthStore,
              let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
            return nil
        }

        let calendar = Calendar.current
        let start = calendar.startOfDay(for: localDate)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return nil }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: stepType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, statistics, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let sum = statistics?.sumQuantity()?.doubleValue(for: HKUnit.count()) ?? 0
                continuation.resume(returning: Int(sum.rounded()))
            }
            healthStore.execute(query)
        }
        #else
        return nil
        #endif
    }

    /// Manual entry always works — HealthKit is never required.
    func manualEntry(localDate: Date, steps: Int, existingID: UUID? = nil) -> StepEntry {
        StepEntry(
            id: existingID ?? UUID(),
            localDate: Calendar.current.startOfDay(for: localDate),
            steps: max(0, steps),
            source: .manual
        )
    }

    /// Builds a HealthKit-sourced entry when a successful read exists.
    func healthKitEntry(localDate: Date, steps: Int, existingID: UUID? = nil) -> StepEntry {
        StepEntry(
            id: existingID ?? UUID(),
            localDate: Calendar.current.startOfDay(for: localDate),
            steps: max(0, steps),
            source: .healthKit
        )
    }

    /// Prefer an existing manual entry for the day; otherwise try HealthKit without failing closed.
    func resolveSteps(
        for localDate: Date,
        existing: [StepEntry]
    ) async -> StepEntry? {
        let day = Calendar.current.startOfDay(for: localDate)
        if let manual = existing.first(where: {
            Calendar.current.isDate($0.localDate, inSameDayAs: day) && $0.source == .manual
        }) {
            return manual
        }
        if let existingHK = existing.first(where: {
            Calendar.current.isDate($0.localDate, inSameDayAs: day) && $0.source == .healthKit
        }) {
            return existingHK
        }
        guard isHealthKitAvailable else { return nil }
        do {
            if let steps = try await healthKitSteps(on: day) {
                return healthKitEntry(localDate: day, steps: steps)
            }
        } catch {
            return nil
        }
        return nil
    }
}
