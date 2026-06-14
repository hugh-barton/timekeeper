import SwiftUI
import UIKit

enum AppStorageKeys {
    static let developerModeEnabled = "developerModeEnabled"
    static let mockDataset = "mockDataset"
    static let realDataset = "realDataset"
}

enum DataMode {
    case mock
    case real
}

struct CodableColor: Codable {
    let red: Double
    let green: Double
    let blue: Double
    let alpha: Double
}

struct StoredHabitGoal: Codable {
    let unit: String
    let dailyTarget: Int

    init(_ goal: HabitGoal) {
        unit = goal.unit
        dailyTarget = goal.dailyTarget
    }

    var value: HabitGoal {
        HabitGoal(unit: unit, dailyTarget: dailyTarget)
    }
}

struct StoredRestDay: Codable {
    let id: String
    let markedAt: Date
    let year: Int
    let month: Int
    let day: Int

    init(_ restDay: RestDay) {
        id = restDay.id
        markedAt = restDay.markedAt
        year = restDay.year
        month = restDay.month
        day = restDay.day
    }

    var value: RestDay {
        RestDay(id: id, markedAt: markedAt, year: year, month: month, day: day)
    }
}

struct StoredTimeEntry: Codable {
    let id: String
    let loggedAt: Date
    let year: Int
    let month: Int
    let day: Int
    let minutes: Int
    let unitLabel: String
    let dailyTarget: Int?

    init(_ timeEntry: TimeEntry) {
        id = timeEntry.id
        loggedAt = timeEntry.loggedAt
        year = timeEntry.year
        month = timeEntry.month
        day = timeEntry.day
        minutes = timeEntry.minutes
        unitLabel = timeEntry.unitLabel
        dailyTarget = timeEntry.dailyTarget
    }

    var value: TimeEntry {
        TimeEntry(
            id: id,
            loggedAt: loggedAt,
            year: year,
            month: month,
            day: day,
            minutes: minutes,
            unitLabel: unitLabel,
            dailyTarget: dailyTarget
        )
    }
}

struct StoredRewardStampEntry: Codable {
    let id: UUID
    let stampedAt: Date
    let amount: Int

    init(_ entry: RewardStampEntry) {
        id = entry.id
        stampedAt = entry.stampedAt
        amount = entry.amount
    }

    var value: RewardStampEntry {
        RewardStampEntry(id: id, stampedAt: stampedAt, amount: amount)
    }
}

struct StoredHabit: Codable {
    let id: UUID
    let name: String
    let symbolName: String
    let color: CodableColor
    let createdAt: Date
    let isTrackingEnabled: Bool
    let trackingUnit: String
    let goal: StoredHabitGoal?
    let reminder: HabitReminder?
    let completedDays: Set<String>
    let restDays: [StoredRestDay]
    let timeEntries: [StoredTimeEntry]

    init(_ habit: Habit) {
        id = habit.id
        name = habit.name
        symbolName = habit.symbolName
        color = habit.color.codableColor
        createdAt = habit.createdAt
        isTrackingEnabled = habit.isTrackingEnabled
        trackingUnit = habit.trackingUnit
        goal = habit.goal.map { StoredHabitGoal($0) }
        reminder = habit.reminder
        completedDays = habit.completedDays
        restDays = habit.restDays.map { StoredRestDay($0) }
        timeEntries = habit.timeEntries.map { StoredTimeEntry($0) }
    }

    var value: Habit {
        Habit(
            id: id,
            name: name,
            symbolName: symbolName,
            color: Color(codableColor: color),
            createdAt: createdAt,
            isTrackingEnabled: isTrackingEnabled,
            trackingUnit: trackingUnit,
            goal: goal?.value,
            reminder: reminder,
            completedDays: completedDays,
            restDays: restDays.map(\.value),
            timeEntries: timeEntries.map(\.value)
        )
    }
}

struct StoredReward: Codable {
    let id: UUID
    let name: String
    let stampTarget: Int
    let linkedHabitID: UUID?
    let startDate: Date
    let endDate: Date?
    let linkedProgressRule: RewardProgressRule?
    let manualStampEntries: [StoredRewardStampEntry]
    let isArchived: Bool
    let claimedAt: Date?
    let claimDates: [Date]?

    init(_ reward: Reward) {
        id = reward.id
        name = reward.name
        stampTarget = reward.stampTarget
        linkedHabitID = reward.linkedHabitID
        startDate = reward.startDate
        endDate = reward.endDate
        linkedProgressRule = reward.linkedProgressRule
        manualStampEntries = reward.manualStampEntries.map { StoredRewardStampEntry($0) }
        isArchived = reward.isArchived
        claimedAt = reward.claimedAt
        claimDates = reward.claimDates
    }

    var value: Reward {
        Reward(
            id: id,
            name: name,
            stampTarget: stampTarget,
            linkedHabitID: linkedHabitID,
            startDate: startDate,
            endDate: endDate,
            linkedProgressRule: linkedProgressRule ?? .automatic,
            manualStampEntries: manualStampEntries.map(\.value),
            isArchived: isArchived,
            claimedAt: claimedAt,
            claimDates: claimDates ?? []
        )
    }
}

struct StoredDataset: Codable {
    let habits: [StoredHabit]
    let rewards: [StoredReward]
}

private extension Color {
    init(codableColor: CodableColor) {
        self = Color(
            .sRGB,
            red: codableColor.red,
            green: codableColor.green,
            blue: codableColor.blue,
            opacity: codableColor.alpha
        )
    }

    var codableColor: CodableColor {
        let uiColor = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        if uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
            return CodableColor(
                red: Double(red),
                green: Double(green),
                blue: Double(blue),
                alpha: Double(alpha)
            )
        }

        return CodableColor(red: 0, green: 1, blue: 0, alpha: 1)
    }
}
