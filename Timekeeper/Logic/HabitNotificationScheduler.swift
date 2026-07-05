import Foundation
import UserNotifications

enum HabitNotificationScheduler {
    static func scheduleReminder(for habit: Habit) async {
        cancelReminders(for: habit.id)

        guard let reminder = habit.reminder else { return }
        guard await canScheduleNotifications() else { return }

        let content = UNMutableNotificationContent()
        content.body = "Time to work on \(habit.name)"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: notificationIdentifier(for: habit.id),
            content: content,
            trigger: UNCalendarNotificationTrigger(
                dateMatching: dateComponents(for: reminder),
                repeats: true
            )
        )

        try? await UNUserNotificationCenter.current().add(request)
    }

    static func cancelReminders(for habitID: UUID) {
        let identifiers = [notificationIdentifier(for: habitID)]
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
    }

    static func dateComponents(for reminder: HabitReminder) -> DateComponents {
        var components = DateComponents()
        components.hour = reminder.hour
        components.minute = reminder.minute

        switch reminder.frequency {
        case .daily:
            break
        case .weekly:
            components.weekday = reminder.weekday.rawValue
        case .monthly:
            components.day = reminder.dayOfMonth
        }

        return components
    }

    private static func canScheduleNotifications() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()

        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        case .denied:
            return false
        @unknown default:
            return false
        }
    }

    private static func notificationIdentifier(for habitID: UUID) -> String {
        "habit-reminder-\(habitID.uuidString)"
    }
}
