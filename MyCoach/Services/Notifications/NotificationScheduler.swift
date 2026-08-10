import Foundation
import UserNotifications

// MARK: - Protocol

protocol NotificationScheduling: Sendable {
    func requestAuthorization() async -> Bool
    func reschedule(using settings: NotificationSettings, mealTimesMinutes: [Int], stepTarget: Int) async
    func cancelAllManaged() async
}

// MARK: - Categories & deep links

enum CoachNotificationCategory: String, Sendable {
    case morningWeighIn = "mycoach.morning_weigh_in"
    case mealReminder = "mycoach.meal_reminder"
    case stepReminder = "mycoach.step_reminder"
    case weeklyCheckIn = "mycoach.weekly_check_in"
    case progressPhotos = "mycoach.progress_photos"
}

enum CoachNotificationDeepLink {
    /// Deep link opened from the morning weigh-in notification.
    static let morningWeight = "mycoach://weigh-in/morning"

    static let morningWeightIdentifier = "deep_link.morning_weight"

    static func url(for category: CoachNotificationCategory) -> URL? {
        switch category {
        case .morningWeighIn:
            return URL(string: morningWeight)
        case .mealReminder:
            return URL(string: "mycoach://meals")
        case .stepReminder:
            return URL(string: "mycoach://steps")
        case .weeklyCheckIn:
            return URL(string: "mycoach://check-in")
        case .progressPhotos:
            return URL(string: "mycoach://progress-photos")
        }
    }
}

// MARK: - Scheduler

struct NotificationScheduler: NotificationScheduling {
    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func requestAuthorization() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    func registerCategories() async {
        let openWeight = UNNotificationAction(
            identifier: CoachNotificationDeepLink.morningWeightIdentifier,
            title: "Log Weight",
            options: [.foreground]
        )
        let morning = UNNotificationCategory(
            identifier: CoachNotificationCategory.morningWeighIn.rawValue,
            actions: [openWeight],
            intentIdentifiers: [],
            options: []
        )
        let meals = UNNotificationCategory(
            identifier: CoachNotificationCategory.mealReminder.rawValue,
            actions: [],
            intentIdentifiers: [],
            options: []
        )
        let steps = UNNotificationCategory(
            identifier: CoachNotificationCategory.stepReminder.rawValue,
            actions: [],
            intentIdentifiers: [],
            options: []
        )
        let weekly = UNNotificationCategory(
            identifier: CoachNotificationCategory.weeklyCheckIn.rawValue,
            actions: [],
            intentIdentifiers: [],
            options: []
        )
        let photos = UNNotificationCategory(
            identifier: CoachNotificationCategory.progressPhotos.rawValue,
            actions: [],
            intentIdentifiers: [],
            options: []
        )
        center.setNotificationCategories([morning, meals, steps, weekly, photos])
    }

    func reschedule(
        using settings: NotificationSettings,
        mealTimesMinutes: [Int] = [],
        stepTarget: Int = 0
    ) async {
        await cancelAllManaged()
        await registerCategories()

        if settings.morningWeighInEnabled {
            await scheduleMorningWeighIn(hour: settings.morningWeighInHour, minute: settings.morningWeighInMinute)
        }
        if settings.mealRemindersEnabled {
            await scheduleMealReminders(timesMinutes: mealTimesMinutes)
        }
        if settings.stepRemindersEnabled {
            await scheduleStepReminder(stepTarget: stepTarget)
        }
        if settings.weeklyCheckInEnabled {
            await scheduleWeeklyCheckIn()
        }
        if settings.progressPhotosEnabled {
            await scheduleProgressPhotos()
        }
    }

    func cancelAllManaged() async {
        let ids = managedIdentifiers()
        center.removePendingNotificationRequests(withIdentifiers: ids)
        center.removeDeliveredNotifications(withIdentifiers: ids)
    }

    // MARK: - Individual schedules

    private func scheduleMorningWeighIn(hour: Int, minute: Int) async {
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        let content = UNMutableNotificationContent()
        content.title = "Morning weigh-in"
        content.body = "Log your morning weight to keep your weekly average accurate."
        content.categoryIdentifier = CoachNotificationCategory.morningWeighIn.rawValue
        content.sound = .default
        content.userInfo = [
            "deepLink": CoachNotificationDeepLink.morningWeight,
            "deepLinkIdentifier": CoachNotificationDeepLink.morningWeightIdentifier
        ]
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(
            identifier: Self.id(.morningWeighIn),
            content: content,
            trigger: trigger
        )
        try? await center.add(request)
    }

    private func scheduleMealReminders(timesMinutes: [Int]) async {
        let times = timesMinutes.isEmpty ? [8 * 60, 12 * 60, 18 * 60] : timesMinutes
        for (index, minutes) in times.prefix(6).enumerated() {
            var components = DateComponents()
            components.hour = minutes / 60
            components.minute = minutes % 60
            let content = UNMutableNotificationContent()
            content.title = "Meal reminder"
            content.body = "Log your meal to stay on track with today’s targets."
            content.categoryIdentifier = CoachNotificationCategory.mealReminder.rawValue
            content.sound = .default
            content.userInfo = ["deepLink": "mycoach://meals"]
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            let request = UNNotificationRequest(
                identifier: "\(Self.id(.mealReminder)).\(index)",
                content: content,
                trigger: trigger
            )
            try? await center.add(request)
        }
    }

    private func scheduleStepReminder(stepTarget: Int) async {
        var components = DateComponents()
        components.hour = 17
        components.minute = 0
        let content = UNMutableNotificationContent()
        content.title = "Steps check-in"
        let targetText = stepTarget > 0 ? " toward your \(stepTarget) step target" : ""
        content.body = "How are your steps looking\(targetText)?"
        content.categoryIdentifier = CoachNotificationCategory.stepReminder.rawValue
        content.sound = .default
        content.userInfo = ["deepLink": "mycoach://steps"]
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(
            identifier: Self.id(.stepReminder),
            content: content,
            trigger: trigger
        )
        try? await center.add(request)
    }

    private func scheduleWeeklyCheckIn() async {
        // Monday evening — aligns with Mon–Sun coaching week.
        var components = DateComponents()
        components.weekday = 2 // Sunday=1 in Gregorian; Monday=2
        components.hour = 19
        components.minute = 0
        let content = UNMutableNotificationContent()
        content.title = "Weekly check-in"
        content.body = "Complete your weekly check-in so your coach can review progress."
        content.categoryIdentifier = CoachNotificationCategory.weeklyCheckIn.rawValue
        content.sound = .default
        content.userInfo = ["deepLink": "mycoach://check-in"]
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(
            identifier: Self.id(.weeklyCheckIn),
            content: content,
            trigger: trigger
        )
        try? await center.add(request)
    }

    private func scheduleProgressPhotos() async {
        var components = DateComponents()
        components.weekday = 1 // Sunday
        components.hour = 10
        components.minute = 0
        let content = UNMutableNotificationContent()
        content.title = "Progress photos"
        content.body = "Take this week’s front, side, and back progress photos."
        content.categoryIdentifier = CoachNotificationCategory.progressPhotos.rawValue
        content.sound = .default
        content.userInfo = ["deepLink": "mycoach://progress-photos"]
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(
            identifier: Self.id(.progressPhotos),
            content: content,
            trigger: trigger
        )
        try? await center.add(request)
    }

    private static func id(_ category: CoachNotificationCategory) -> String {
        "mycoach.notification.\(category.rawValue)"
    }

    private func managedIdentifiers() -> [String] {
        var ids = [
            Self.id(.morningWeighIn),
            Self.id(.stepReminder),
            Self.id(.weeklyCheckIn),
            Self.id(.progressPhotos)
        ]
        for index in 0..<6 {
            ids.append("\(Self.id(.mealReminder)).\(index)")
        }
        return ids
    }
}
