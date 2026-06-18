import Foundation
import UserNotifications

/// Schedules the two daily "your read is ready" reminders that anchor the
/// product: a morning edition (07:00) and an afternoon edition (16:00).
///
/// These are repeating local notifications, so they keep firing every day even
/// with no server. The copy is generic because the headline for a future day
/// isn't known when the repeating trigger is registered; embedding the real
/// title would require remote push or daily rescheduling after each fetch.
@MainActor
final class NotificationService: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    /// Whether the user wants the daily reminders (intent), independent of the
    /// system-level permission which can still be denied.
    @Published private(set) var isEnabled: Bool
    /// True when the user wants reminders but iOS permission is denied, so the
    /// UI can point them to Settings.
    @Published private(set) var permissionDenied: Bool = false

    private let defaults: UserDefaults
    private let enabledKey = "dailyNotificationsEnabled"
    private let center = UNUserNotificationCenter.current()

    private let morningIdentifier = "oneread.daily.morning"
    private let afternoonIdentifier = "oneread.daily.afternoon"
    private let morningHour = 7
    private let afternoonHour = 16

    /// Notifications are temporarily hidden from the product. This cleanup is
    /// safe to call on launch: it never requests permission or schedules work.
    static func clearPreviouslyScheduledReminders() {
        let center = UNUserNotificationCenter.current()
        let identifiers = ["oneread.daily.morning", "oneread.daily.afternoon"]
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        // Default ON: a scheduled-content product lives or dies by the reminder.
        self.isEnabled = defaults.object(forKey: enabledKey) as? Bool ?? true
        super.init()
        center.delegate = self
    }

    /// Call once on launch: reconcile the user's intent with the system
    /// permission and (re)install the schedule if appropriate.
    func bootstrap() async {
        guard isEnabled else {
            clearScheduledReminders()
            return
        }

        let granted = await ensureAuthorization()
        permissionDenied = !granted
        if granted {
            scheduleReminders()
        } else {
            clearScheduledReminders()
        }
    }

    /// Toggle handler for the settings switch.
    func setEnabled(_ enabled: Bool) async {
        isEnabled = enabled
        defaults.set(enabled, forKey: enabledKey)

        guard enabled else {
            permissionDenied = false
            clearScheduledReminders()
            return
        }

        let granted = await ensureAuthorization()
        permissionDenied = !granted
        if granted {
            scheduleReminders()
        } else {
            // System permission is off; reflect reality so the switch doesn't
            // pretend reminders will arrive.
            isEnabled = false
            defaults.set(false, forKey: enabledKey)
            clearScheduledReminders()
        }
    }

    // MARK: - Authorization

    /// Returns whether we are authorized to post notifications, requesting
    /// permission the first time if it has never been determined.
    private func ensureAuthorization() async -> Bool {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        @unknown default:
            return false
        }
    }

    // MARK: - Scheduling

    private func scheduleReminders() {
        clearScheduledReminders()

        addReminder(
            identifier: morningIdentifier,
            hour: morningHour,
            title: "Your morning read is ready",
            body: "Learn English with today's most important AI story.",
            slot: .morning
        )

        addReminder(
            identifier: afternoonIdentifier,
            hour: afternoonHour,
            title: "Your afternoon read just dropped",
            body: "Your second AI English lesson is ready.",
            slot: .afternoon
        )
    }

    private func addReminder(
        identifier: String,
        hour: Int,
        title: String,
        body: String,
        slot: ArticleEditionSlot
    ) {
        var components = DateComponents()
        components.hour = hour
        components.minute = 0

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.userInfo = [
            "oneReadEvent": "daily_notification",
            "slot": slot.rawValue
        ]

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        center.add(request)
    }

    private func clearScheduledReminders() {
        center.removePendingNotificationRequests(
            withIdentifiers: [morningIdentifier, afternoonIdentifier]
        )
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        RetentionAnalytics.record(
            "notification_open",
            metadata: ["slot": userInfo["slot"] as? String ?? "unknown"]
        )
    }
}
