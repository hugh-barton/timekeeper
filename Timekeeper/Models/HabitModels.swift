import SwiftUI

struct Habit: Identifiable {
    let id: UUID
    var name: String
    var symbolName: String
    var color: Color
    var createdAt: Date
    var isTrackingEnabled: Bool
    var trackingUnit: String
    var goal: HabitGoal?
    var reminder: HabitReminder?
    var completedDays: Set<String> = []
    var restDays: [RestDay] = []
    var timeEntries: [TimeEntry] = []

    init(
        id: UUID = UUID(),
        name: String,
        symbolName: String = "circle.fill",
        color: Color,
        createdAt: Date = Date(),
        isTrackingEnabled: Bool = false,
        trackingUnit: String = "",
        goal: HabitGoal? = nil,
        reminder: HabitReminder? = nil,
        completedDays: Set<String> = [],
        restDays: [RestDay] = [],
        timeEntries: [TimeEntry] = []
    ) {
        self.id = id
        self.name = name
        self.symbolName = symbolName
        self.color = color
        self.createdAt = createdAt
        self.isTrackingEnabled = isTrackingEnabled || goal != nil
        self.trackingUnit = goal?.unit ?? trackingUnit
        self.goal = goal
        self.reminder = reminder
        self.completedDays = completedDays
        self.restDays = restDays
        self.timeEntries = timeEntries
    }
}

struct HabitGoal {
    var unit: String
    var dailyTarget: Int
}

enum HabitReminderFrequency: String, Codable, CaseIterable, Identifiable {
    case daily
    case weekly
    case monthly

    var id: String { rawValue }

    var title: String {
        rawValue.capitalized
    }
}

enum HabitReminderWeekday: Int, Codable, CaseIterable, Identifiable {
    case monday = 2
    case tuesday = 3
    case wednesday = 4
    case thursday = 5
    case friday = 6
    case saturday = 7
    case sunday = 1

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .monday: "Monday"
        case .tuesday: "Tuesday"
        case .wednesday: "Wednesday"
        case .thursday: "Thursday"
        case .friday: "Friday"
        case .saturday: "Saturday"
        case .sunday: "Sunday"
        }
    }
}

struct HabitReminder: Codable, Equatable {
    var frequency: HabitReminderFrequency
    var hour: Int
    var minute: Int
    var weekday: HabitReminderWeekday
    var dayOfMonth: Int

    init(
        frequency: HabitReminderFrequency = .daily,
        hour: Int = 9,
        minute: Int = 0,
        weekday: HabitReminderWeekday = .monday,
        dayOfMonth: Int = 1
    ) {
        self.frequency = frequency
        self.hour = hour
        self.minute = minute
        self.weekday = weekday
        self.dayOfMonth = dayOfMonth
    }
}

struct RestDay: Identifiable {
    let id: String
    let markedAt: Date
    let year: Int
    let month: Int
    let day: Int
}

struct TimeEntry: Identifiable {
    let id: String
    let loggedAt: Date
    let year: Int
    let month: Int
    let day: Int
    let minutes: Int
    let unitLabel: String
    let dailyTarget: Int?

    init(
        id: String = UUID().uuidString,
        loggedAt: Date,
        year: Int,
        month: Int,
        day: Int,
        minutes: Int,
        unitLabel: String = "min",
        dailyTarget: Int? = nil
    ) {
        self.id = id
        self.loggedAt = loggedAt
        self.year = year
        self.month = month
        self.day = day
        self.minutes = minutes
        self.unitLabel = unitLabel
        self.dailyTarget = dailyTarget
    }
}

struct RewardStampEntry: Identifiable {
    let id: UUID
    let stampedAt: Date
    let amount: Int

    init(id: UUID = UUID(), stampedAt: Date = Date(), amount: Int) {
        self.id = id
        self.stampedAt = stampedAt
        self.amount = amount
    }
}

enum RewardProgressRule: String, Codable, CaseIterable, Identifiable {
    case automatic
    case loggedQuantity
    case completedDays
    case goalMetDays

    var id: String { rawValue }

    var title: String {
        switch self {
        case .automatic:
            "Automatic"
        case .loggedQuantity:
            "Logged quantity"
        case .completedDays:
            "Completed days"
        case .goalMetDays:
            "Goal-met days"
        }
    }

    func description(for habit: Habit?) -> String {
        switch self {
        case .automatic:
            habit?.isTrackingEnabled == true ? "Each logged unit earns one point." : "Each completed day earns one point."
        case .loggedQuantity:
            "Each logged unit earns one point."
        case .completedDays:
            "Each completed day earns one point."
        case .goalMetDays:
            "Each day that reaches the habit goal earns one point."
        }
    }
}

struct Reward: Identifiable {
    let id: UUID
    var name: String
    var stampTarget: Int
    var linkedHabitID: UUID?
    var startDate: Date
    var endDate: Date?
    var linkedProgressRule: RewardProgressRule
    var manualStampEntries: [RewardStampEntry]
    var isArchived: Bool
    var claimedAt: Date?
    var claimDates: [Date]

    init(
        id: UUID = UUID(),
        name: String,
        stampTarget: Int,
        linkedHabitID: UUID? = nil,
        startDate: Date = Date(),
        endDate: Date? = nil,
        linkedProgressRule: RewardProgressRule = .automatic,
        manualStampEntries: [RewardStampEntry] = [],
        isArchived: Bool = false,
        claimedAt: Date? = nil,
        claimDates: [Date] = []
    ) {
        self.id = id
        self.name = name
        self.stampTarget = stampTarget
        self.linkedHabitID = linkedHabitID
        self.startDate = startDate
        self.endDate = endDate
        self.linkedProgressRule = linkedProgressRule
        self.manualStampEntries = manualStampEntries
        self.isArchived = isArchived
        self.claimedAt = claimedAt
        self.claimDates = claimDates.isEmpty ? claimedAt.map { [$0] } ?? [] : claimDates
    }
}
