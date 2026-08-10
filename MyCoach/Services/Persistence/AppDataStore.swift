import Foundation

/// File-based JSON persistence in Application Support (local device only — not iCloud).
actor AppDataStore {
    enum StoreError: Error, LocalizedError, Sendable {
        case directoryUnavailable
        case encodingFailed
        case decodingFailed(String)
        case writeFailed

        var errorDescription: String? {
            switch self {
            case .directoryUnavailable:
                "Could not access the local Application Support directory."
            case .encodingFailed:
                "Failed to encode data for local storage."
            case .decodingFailed(let name):
                "Failed to decode \(name) from local storage."
            case .writeFailed:
                "Failed to write local data."
            }
        }
    }

    struct Snapshot: Codable, Equatable, Sendable {
        var profile: UserProfile?
        var weightEntries: [WeightEntry]
        var foodLogEntries: [FoodLogEntry]
        var customFoods: [FoodItem]
        var nutritionTargets: NutritionTargetPair?
        var weeklyCheckIns: [WeeklyCheckIn]
        var planAdjustments: [PlanAdjustment]
        var mealPlanDays: [MealPlanDay]
        var stepEntries: [StepEntry]
        var progressPhotos: [ProgressPhotoSet]
        var coachChatMessages: [CoachChatMessage]
        var preferences: UserPreferences
        var subscriptionSnapshot: SubscriptionEntitlement?

        static let empty = Snapshot(
            profile: nil,
            weightEntries: [],
            foodLogEntries: [],
            customFoods: [],
            nutritionTargets: nil,
            weeklyCheckIns: [],
            planAdjustments: [],
            mealPlanDays: [],
            stepEntries: [],
            progressPhotos: [],
            coachChatMessages: [],
            preferences: UserPreferences(),
            subscriptionSnapshot: nil
        )
    }

    private enum FileKey: String, CaseIterable {
        case profile
        case weightEntries
        case foodLogEntries
        case customFoods
        case nutritionTargets
        case weeklyCheckIns
        case planAdjustments
        case mealPlanDays
        case stepEntries
        case progressPhotos
        case coachChatMessages
        case preferences
        case subscriptionSnapshot
    }

    private let fileManager: FileManager
    private let rootDirectory: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    private(set) var snapshot: Snapshot = .empty

    init(fileManager: FileManager = .default, directoryName: String = "MyCoachData") throws {
        self.fileManager = fileManager
        guard let support = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw StoreError.directoryUnavailable
        }
        let root = support.appendingPathComponent(directoryName, isDirectory: true)
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        // Explicitly exclude from iCloud / device backup when possible.
        var rootValues = URLResourceValues()
        rootValues.isExcludedFromBackup = true
        var mutableRoot = root
        try? mutableRoot.setResourceValues(rootValues)

        self.rootDirectory = root
        self.encoder = JSONEncoder()
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder.dateEncodingStrategy = .iso8601
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
    }

    // MARK: - Load / Save

    func load() async throws {
        var next = Snapshot.empty
        next.profile = try loadOptional(UserProfile.self, key: .profile)
        next.weightEntries = try loadArray(WeightEntry.self, key: .weightEntries)
        next.foodLogEntries = try loadArray(FoodLogEntry.self, key: .foodLogEntries)
        next.customFoods = try loadArray(FoodItem.self, key: .customFoods)
        next.nutritionTargets = try loadOptional(NutritionTargetPair.self, key: .nutritionTargets)
        next.weeklyCheckIns = try loadArray(WeeklyCheckIn.self, key: .weeklyCheckIns)
        next.planAdjustments = try loadArray(PlanAdjustment.self, key: .planAdjustments)
        next.mealPlanDays = try loadArray(MealPlanDay.self, key: .mealPlanDays)
        next.stepEntries = try loadArray(StepEntry.self, key: .stepEntries)
        next.progressPhotos = try loadArray(ProgressPhotoSet.self, key: .progressPhotos)
        next.coachChatMessages = try loadArray(CoachChatMessage.self, key: .coachChatMessages)
        next.preferences = try loadOptional(UserPreferences.self, key: .preferences) ?? UserPreferences()
        next.subscriptionSnapshot = try loadOptional(SubscriptionEntitlement.self, key: .subscriptionSnapshot)
        snapshot = next
    }

    func save() async throws {
        try write(snapshot.profile, key: .profile)
        try write(snapshot.weightEntries, key: .weightEntries)
        try write(snapshot.foodLogEntries, key: .foodLogEntries)
        try write(snapshot.customFoods, key: .customFoods)
        try write(snapshot.nutritionTargets, key: .nutritionTargets)
        try write(snapshot.weeklyCheckIns, key: .weeklyCheckIns)
        try write(snapshot.planAdjustments, key: .planAdjustments)
        try write(snapshot.mealPlanDays, key: .mealPlanDays)
        try write(snapshot.stepEntries, key: .stepEntries)
        try write(snapshot.progressPhotos, key: .progressPhotos)
        try write(snapshot.coachChatMessages, key: .coachChatMessages)
        try write(snapshot.preferences, key: .preferences)
        try write(snapshot.subscriptionSnapshot, key: .subscriptionSnapshot)
    }

    func replaceSnapshot(_ snapshot: Snapshot) async throws {
        self.snapshot = snapshot
        try await save()
    }

    // MARK: - Typed mutators

    func updateProfile(_ profile: UserProfile?) async throws {
        snapshot.profile = profile
        try write(profile, key: .profile)
    }

    func updateWeightEntries(_ entries: [WeightEntry]) async throws {
        snapshot.weightEntries = entries
        try write(entries, key: .weightEntries)
    }

    func updateFoodLogEntries(_ entries: [FoodLogEntry]) async throws {
        snapshot.foodLogEntries = entries
        try write(entries, key: .foodLogEntries)
    }

    func updateCustomFoods(_ foods: [FoodItem]) async throws {
        snapshot.customFoods = foods
        try write(foods, key: .customFoods)
    }

    func updateNutritionTargets(_ pair: NutritionTargetPair?) async throws {
        snapshot.nutritionTargets = pair
        try write(pair, key: .nutritionTargets)
    }

    func updateWeeklyCheckIns(_ entries: [WeeklyCheckIn]) async throws {
        snapshot.weeklyCheckIns = entries
        try write(entries, key: .weeklyCheckIns)
    }

    func updatePlanAdjustments(_ entries: [PlanAdjustment]) async throws {
        snapshot.planAdjustments = entries
        try write(entries, key: .planAdjustments)
    }

    func updateMealPlanDays(_ days: [MealPlanDay]) async throws {
        snapshot.mealPlanDays = days
        try write(days, key: .mealPlanDays)
    }

    func updateStepEntries(_ entries: [StepEntry]) async throws {
        snapshot.stepEntries = entries
        try write(entries, key: .stepEntries)
    }

    func updateProgressPhotos(_ sets: [ProgressPhotoSet]) async throws {
        snapshot.progressPhotos = sets
        try write(sets, key: .progressPhotos)
    }

    func updateCoachChatMessages(_ messages: [CoachChatMessage]) async throws {
        snapshot.coachChatMessages = messages
        try write(messages, key: .coachChatMessages)
    }

    func updatePreferences(_ preferences: UserPreferences) async throws {
        snapshot.preferences = preferences
        try write(preferences, key: .preferences)
    }

    func updateSubscriptionSnapshot(_ entitlement: SubscriptionEntitlement?) async throws {
        snapshot.subscriptionSnapshot = entitlement
        try write(entitlement, key: .subscriptionSnapshot)
    }

    // MARK: - Export / delete

    /// Full local export for Settings → "Export My Data".
    func exportJSONData() async throws -> Data {
        do {
            return try encoder.encode(snapshot)
        } catch {
            throw StoreError.encodingFailed
        }
    }

    func exportJSONString() async throws -> String {
        let data = try await exportJSONData()
        guard let string = String(data: data, encoding: .utf8) else {
            throw StoreError.encodingFailed
        }
        return string
    }

    /// Clears coaching-related history while keeping profile, preferences, custom foods, and subscription snapshot.
    func deleteCoachingData() async throws {
        snapshot.weightEntries = []
        snapshot.foodLogEntries = []
        snapshot.nutritionTargets = nil
        snapshot.weeklyCheckIns = []
        snapshot.planAdjustments = []
        snapshot.mealPlanDays = []
        snapshot.stepEntries = []
        snapshot.progressPhotos = []
        snapshot.coachChatMessages = []
        try write(snapshot.weightEntries, key: .weightEntries)
        try write(snapshot.foodLogEntries, key: .foodLogEntries)
        try write(snapshot.nutritionTargets, key: .nutritionTargets)
        try write(snapshot.weeklyCheckIns, key: .weeklyCheckIns)
        try write(snapshot.planAdjustments, key: .planAdjustments)
        try write(snapshot.mealPlanDays, key: .mealPlanDays)
        try write(snapshot.stepEntries, key: .stepEntries)
        try write(snapshot.progressPhotos, key: .progressPhotos)
        try write(snapshot.coachChatMessages, key: .coachChatMessages)
    }

    /// Removes all local Application Support data managed by this store.
    func deleteAllLocalData() async throws {
        snapshot = .empty
        for key in FileKey.allCases {
            let url = fileURL(for: key)
            if fileManager.fileExists(atPath: url.path) {
                try fileManager.removeItem(at: url)
            }
        }
    }

    // MARK: - Private I/O

    private func fileURL(for key: FileKey) -> URL {
        rootDirectory.appendingPathComponent("\(key.rawValue).json", isDirectory: false)
    }

    private func loadOptional<T: Decodable>(_ type: T.Type, key: FileKey) throws -> T? {
        let url = fileURL(for: key)
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        do {
            let data = try Data(contentsOf: url)
            if data.isEmpty { return nil }
            return try decoder.decode(T.self, from: data)
        } catch {
            throw StoreError.decodingFailed(key.rawValue)
        }
    }

    private func loadArray<T: Decodable>(_ type: T.Type, key: FileKey) throws -> [T] {
        try loadOptional([T].self, key: key) ?? []
    }

    private func write<T: Encodable>(_ value: T?, key: FileKey) throws {
        let url = fileURL(for: key)
        guard let value else {
            if fileManager.fileExists(atPath: url.path) {
                try fileManager.removeItem(at: url)
            }
            return
        }
        do {
            let data = try encoder.encode(value)
            try data.write(to: url, options: [.atomic])
        } catch {
            throw StoreError.writeFailed
        }
    }
}
