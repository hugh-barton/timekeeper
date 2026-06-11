//
//  ContentView.swift
//  Timekeeper
//
//  Created by Hugh Barton on 1/6/2026.
//

import Charts
import SwiftUI
import UIKit

struct Habit: Identifiable {
    let id: UUID
    var name: String
    var symbolName: String
    var color: Color
    var createdAt: Date
    var isTrackingEnabled: Bool
    var trackingUnit: String
    var goal: HabitGoal?
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
        self.completedDays = completedDays
        self.restDays = restDays
        self.timeEntries = timeEntries
    }
}

struct HabitGoal {
    var unit: String
    var dailyTarget: Int
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

func rewardStampCount(for reward: Reward, habits: [Habit]) -> Int {
    let calendar = Calendar(identifier: .gregorian)
    let rewardStartDate = calendar.startOfDay(for: reward.startDate)

    guard let linkedHabitID = reward.linkedHabitID else {
        return reward.manualStampEntries.reduce(0) { partialResult, entry in
            let stampedAt = calendar.startOfDay(for: entry.stampedAt)
            return stampedAt >= rewardStartDate ? partialResult + entry.amount : partialResult
        }
    }

    return habits.first(where: { $0.id == linkedHabitID }).map {
        linkedRewardProgress(for: $0, startDate: rewardStartDate, rule: reward.linkedProgressRule, calendar: calendar)
    } ?? 0
}

func linkedRewardProgress(
    for habit: Habit,
    startDate: Date,
    rule: RewardProgressRule = .automatic,
    calendar: Calendar = Calendar(identifier: .gregorian)
) -> Int {
    let resolvedRule: RewardProgressRule = rule == .automatic
        ? (habit.isTrackingEnabled ? .loggedQuantity : .completedDays)
        : rule

    switch resolvedRule {
    case .automatic:
        return 0
    case .loggedQuantity:
        return habit.timeEntries.reduce(0) { partialResult, entry in
            let entryDate = calendar.startOfDay(for: entry.loggedAt)
            return entryDate >= startDate ? partialResult + entry.minutes : partialResult
        }
    case .completedDays:
        return rewardCompletedDayKeys(for: habit).reduce(0) { partialResult, key in
            guard let day = rewardDate(from: key, calendar: calendar) else { return partialResult }
            return day >= startDate ? partialResult + 1 : partialResult
        }
    case .goalMetDays:
        guard let goal = habit.goal else { return 0 }
        let quantitiesByDay = Dictionary(grouping: habit.timeEntries) { entry in
            "\(entry.year)-\(entry.month)-\(entry.day)"
        }

        return quantitiesByDay.reduce(0) { partialResult, item in
            guard let day = rewardDate(from: item.key, calendar: calendar), day >= startDate else {
                return partialResult
            }
            let quantity = item.value.reduce(0) { $0 + $1.minutes }
            return quantity >= goal.dailyTarget ? partialResult + 1 : partialResult
        }
    }
}

func rewardCompletedDayKeys(for habit: Habit) -> Set<String> {
    let restDayKeys = Set(habit.restDays.map(\.id))
    var completedDayKeys = habit.completedDays.subtracting(restDayKeys)

    guard habit.isTrackingEnabled else { return completedDayKeys }

    let quantitiesByDay = Dictionary(grouping: habit.timeEntries) {
        "\($0.year)-\($0.month)-\($0.day)"
    }

    for (key, entries) in quantitiesByDay where !restDayKeys.contains(key) {
        let quantity = entries.reduce(0) { $0 + $1.minutes }
        if let goal = habit.goal {
            if quantity >= goal.dailyTarget {
                completedDayKeys.insert(key)
            }
        } else if quantity > 0 {
            completedDayKeys.insert(key)
        }
    }

    return completedDayKeys
}

func rewardDate(from dayKey: String, calendar: Calendar = Calendar(identifier: .gregorian)) -> Date? {
    let parts = dayKey.split(separator: "-").compactMap { Int($0) }
    guard parts.count == 3 else { return nil }

    return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
}

struct RewardHistoryEntry: Identifiable {
    let id: String
    let date: Date
    let amount: Int
    let detail: String
}

func rewardHistoryEntries(
    for reward: Reward,
    habits: [Habit],
    calendar: Calendar = Calendar(identifier: .gregorian)
) -> [RewardHistoryEntry] {
    let startDate = calendar.startOfDay(for: reward.startDate)
    var entries: [RewardHistoryEntry] = reward.manualStampEntries.compactMap { entry in
        guard calendar.startOfDay(for: entry.stampedAt) >= startDate else { return nil }
        return RewardHistoryEntry(
            id: "manual-\(entry.id.uuidString)",
            date: entry.stampedAt,
            amount: entry.amount,
            detail: "Manual points"
        )
    }

    if let linkedHabitID = reward.linkedHabitID,
       let habit = habits.first(where: { $0.id == linkedHabitID }) {
        let resolvedRule: RewardProgressRule = reward.linkedProgressRule == .automatic
            ? (habit.isTrackingEnabled ? .loggedQuantity : .completedDays)
            : reward.linkedProgressRule

        switch resolvedRule {
        case .automatic:
            break
        case .loggedQuantity:
            entries += habit.timeEntries.compactMap { entry in
                guard calendar.startOfDay(for: entry.loggedAt) >= startDate else { return nil }
                return RewardHistoryEntry(
                    id: "quantity-\(entry.id)",
                    date: entry.loggedAt,
                    amount: entry.minutes,
                    detail: "\(habit.name) logged"
                )
            }
        case .completedDays:
            entries += rewardCompletedDayKeys(for: habit).compactMap { key in
                guard let date = rewardDate(from: key, calendar: calendar), date >= startDate else { return nil }
                return RewardHistoryEntry(
                    id: "completion-\(habit.id.uuidString)-\(key)",
                    date: date,
                    amount: 1,
                    detail: "\(habit.name) completed"
                )
            }
        case .goalMetDays:
            guard let goal = habit.goal else { break }
            let quantitiesByDay = Dictionary(grouping: habit.timeEntries) {
                "\($0.year)-\($0.month)-\($0.day)"
            }
            entries += quantitiesByDay.compactMap { key, dayEntries in
                guard
                    let date = rewardDate(from: key, calendar: calendar),
                    date >= startDate,
                    dayEntries.reduce(0, { $0 + $1.minutes }) >= goal.dailyTarget
                else { return nil }

                return RewardHistoryEntry(
                    id: "goal-\(habit.id.uuidString)-\(key)",
                    date: date,
                    amount: 1,
                    detail: "\(habit.name) goal met"
                )
            }
        }
    }

    entries += reward.claimDates.map { claimedAt in
        RewardHistoryEntry(
            id: "claimed-\(reward.id.uuidString)-\(claimedAt.timeIntervalSinceReferenceDate)",
            date: claimedAt,
            amount: 0,
            detail: "Reward claimed"
        )
    }

    if let claimedAt = reward.claimedAt, !reward.claimDates.contains(claimedAt) {
        entries.append(
            RewardHistoryEntry(
                id: "claimed-\(reward.id.uuidString)",
                date: claimedAt,
                amount: 0,
                detail: "Reward claimed"
            )
        )
    }

    return entries.sorted { $0.date > $1.date }
}

struct MockData {
    static let habits: [Habit] = {
        let calendar = Calendar(identifier: .gregorian)
        let specs: [(id: UUID, name: String, symbolName: String, color: Color, createdAt: DateComponents, isTrackingEnabled: Bool, trackingUnit: String, goal: HabitGoal?, seed: UInt64)] = [
            (UUID(uuidString: "11111111-1111-1111-1111-111111111111")!, "Strength", "dumbbell.fill", .red, DateComponents(year: 2026, month: 1, day: 12), false, "", nil, 11),
            (UUID(uuidString: "22222222-2222-2222-2222-222222222222")!, "Reading", "book.closed.fill", .green, DateComponents(year: 2026, month: 2, day: 3), true, "pages", nil, 22),
            (UUID(uuidString: "33333333-3333-3333-3333-333333333333")!, "Meditation", "brain.head.profile", .purple, DateComponents(year: 2026, month: 3, day: 18), false, "", nil, 33),
            (UUID(uuidString: "44444444-4444-4444-4444-444444444444")!, "Running", "figure.run", .yellow, DateComponents(year: 2026, month: 4, day: 7), true, "km", HabitGoal(unit: "km", dailyTarget: 5), 44)
        ]

        guard
            let startDate = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1)),
            let endDate = calendar.date(from: DateComponents(year: 2026, month: 6, day: 2))
        else { return [] }

        return specs.compactMap { spec in
            guard let createdAt = calendar.date(from: spec.createdAt) else { return nil }

            var generator = SeededGenerator(seed: spec.seed)
            var completedDays = Set<String>()
            var restDays: [RestDay] = []
            var timeEntries: [TimeEntry] = []
            var currentDate = max(startDate, createdAt)

            while currentDate <= endDate {
                let components = calendar.dateComponents([.year, .month, .day], from: currentDate)
                let key = dayKey(for: currentDate, calendar: calendar)
                let stateRoll = generator.nextInt(upperBound: 100)

                if stateRoll < 70 {
                    if spec.isTrackingEnabled {
                        let quantity: Int
                        let dailyTarget: Int?

                        if let goal = spec.goal {
                            dailyTarget = goal.dailyTarget

                            if stateRoll < 45 {
                                quantity = goal.dailyTarget + generator.nextInt(upperBound: goal.dailyTarget + 1)
                                completedDays.insert(key)
                            } else {
                                quantity = 1 + generator.nextInt(upperBound: max(goal.dailyTarget - 1, 1))
                            }
                        } else {
                            dailyTarget = nil
                            quantity = 5 + generator.nextInt(upperBound: 26)
                        }

                        timeEntries.append(
                            TimeEntry(
                                id: "\(spec.id.uuidString)-\(key)-time",
                                loggedAt: currentDate,
                                year: components.year ?? 0,
                                month: components.month ?? 0,
                                day: components.day ?? 0,
                                minutes: quantity,
                                unitLabel: spec.goal?.unit ?? spec.trackingUnit,
                                dailyTarget: dailyTarget
                            )
                        )
                    } else {
                        completedDays.insert(key)
                    }
                } else if stateRoll < 80 {
                    restDays.append(
                        RestDay(
                            id: key,
                            markedAt: currentDate,
                            year: components.year ?? 0,
                            month: components.month ?? 0,
                            day: components.day ?? 0
                        )
                    )
                }

                guard let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) else { break }
                currentDate = nextDate
            }

            return Habit(
                id: spec.id,
                name: spec.name,
                symbolName: spec.symbolName,
                color: spec.color,
                createdAt: createdAt,
                isTrackingEnabled: spec.isTrackingEnabled,
                trackingUnit: spec.trackingUnit,
                goal: spec.goal,
                completedDays: completedDays,
                restDays: restDays,
                timeEntries: timeEntries
            )
        }
    }()

    static let rewards: [Reward] = {
        let calendar = Calendar(identifier: .gregorian)

        return [
            Reward(
                id: UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!,
                name: "Fresh Notebook",
                stampTarget: 120,
                linkedHabitID: UUID(uuidString: "22222222-2222-2222-2222-222222222222"),
                startDate: calendar.date(from: DateComponents(year: 2026, month: 2, day: 3)) ?? Date()
            ),
            Reward(
                id: UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")!,
                name: "Massage Voucher",
                stampTarget: 8,
                startDate: calendar.date(from: DateComponents(year: 2026, month: 3, day: 1)) ?? Date(),
                manualStampEntries: [
                    RewardStampEntry(
                        id: UUID(uuidString: "12121212-1212-1212-1212-121212121212")!,
                        stampedAt: calendar.date(from: DateComponents(year: 2026, month: 3, day: 8)) ?? Date(),
                        amount: 2
                    ),
                    RewardStampEntry(
                        id: UUID(uuidString: "34343434-3434-3434-3434-343434343434")!,
                        stampedAt: calendar.date(from: DateComponents(year: 2026, month: 4, day: 9)) ?? Date(),
                        amount: 3
                    )
                ]
            ),
            Reward(
                id: UUID(uuidString: "cccccccc-cccc-cccc-cccc-cccccccccccc")!,
                name: "Race Day Entry",
                stampTarget: 30,
                linkedHabitID: UUID(uuidString: "44444444-4444-4444-4444-444444444444"),
                startDate: calendar.date(from: DateComponents(year: 2026, month: 4, day: 7)) ?? Date(),
                linkedProgressRule: .goalMetDays
            )
        ]
    }()

    private static func dayKey(for day: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: day)
        return "\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)"
    }
}

private enum AppStorageKeys {
    static let developerModeEnabled = "developerModeEnabled"
    static let mockDataset = "mockDataset"
    static let realDataset = "realDataset"
}

private enum DataMode {
    case mock
    case real
}

private struct CodableColor: Codable {
    let red: Double
    let green: Double
    let blue: Double
    let alpha: Double
}

private struct StoredHabitGoal: Codable {
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

private struct StoredRestDay: Codable {
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

private struct StoredTimeEntry: Codable {
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

private struct StoredRewardStampEntry: Codable {
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

private struct StoredHabit: Codable {
    let id: UUID
    let name: String
    let symbolName: String
    let color: CodableColor
    let createdAt: Date
    let isTrackingEnabled: Bool
    let trackingUnit: String
    let goal: StoredHabitGoal?
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
            completedDays: completedDays,
            restDays: restDays.map(\.value),
            timeEntries: timeEntries.map(\.value)
        )
    }
}

private struct StoredReward: Codable {
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

private struct StoredDataset: Codable {
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

struct SeededGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func nextInt(upperBound: Int) -> Int {
        state = 6364136223846793005 &* state &+ 1442695040888963407
        return Int(state % UInt64(upperBound))
    }
}

struct ContentView: View {
    @State private var isDeveloperModeEnabled: Bool
    @State private var mockHabits: [Habit]
    @State private var mockRewards: [Reward]
    @State private var realHabits: [Habit]
    @State private var realRewards: [Reward]
    @State private var isShowingAddHabit = false
    @State private var newHabitName = ""
    @State private var newHabitSymbolName = HabitSymbolOption.defaultSymbolName
    @State private var newHabitColor = Color.green
    @State private var newHabitIsTrackingEnabled = false
    @State private var newHabitTrackingUnit = ""
    @State private var newHabitHasGoal = false
    @State private var newHabitGoalUnit = ""
    @State private var newHabitGoalTarget = ""
    @State private var editingHabitID: UUID?
    @State private var isShowingAddReward = false
    @State private var newRewardName = ""
    @State private var newRewardTarget = ""
    @State private var newRewardLinkedHabitID: UUID?
    @State private var newRewardStartDate = Date()
    @State private var newRewardHasCustomStartDate = false
    @State private var newRewardEndDate = Date()
    @State private var newRewardHasDeadline = false
    @State private var newRewardProgressRule = RewardProgressRule.automatic
    @State private var editingRewardID: UUID?
    @State private var selectedBulkStampRewardID: UUID?
    @State private var bulkStampAmount = ""
    @State private var highlightedRewardID: UUID?
    @State private var celebratingRewardID: UUID?

    private let calendar = Calendar(identifier: .gregorian)
    private let storage: UserDefaults

    init(
        storage: UserDefaults = .standard,
        developerModeOverride: Bool? = nil,
        usePersistedDatasets: Bool = true
    ) {
        self.storage = storage

        let storedDeveloperModeEnabled = storage.object(forKey: AppStorageKeys.developerModeEnabled) as? Bool ?? true
        let storedMockDataset = usePersistedDatasets ? Self.loadDataset(forKey: AppStorageKeys.mockDataset, storage: storage) : nil
        let storedRealDataset = usePersistedDatasets ? Self.loadDataset(forKey: AppStorageKeys.realDataset, storage: storage) : nil

        _isDeveloperModeEnabled = State(initialValue: developerModeOverride ?? storedDeveloperModeEnabled)
        _mockHabits = State(initialValue: storedMockDataset?.habits.map(\.value) ?? MockData.habits)
        _mockRewards = State(initialValue: storedMockDataset?.rewards.map(\.value) ?? MockData.rewards)
        _realHabits = State(initialValue: storedRealDataset?.habits.map(\.value) ?? [])
        _realRewards = State(initialValue: storedRealDataset?.rewards.map(\.value) ?? [])
    }

    var body: some View {
        TabView {
            NavigationStack {
                ZStack {
                    Color.black
                        .ignoresSafeArea()

                    GeometryReader { proxy in
                        let rowSpacing: CGFloat = 12
                        let verticalPadding: CGFloat = 16
                        let cardHeight = max((proxy.size.height - (verticalPadding * 2) - (rowSpacing * 3)) / 4, 96)

                        ScrollView {
                            LazyVStack(spacing: rowSpacing) {
                                ForEach(activeHabitsBinding) { $habit in
                                    HabitRow(
                                        habit: $habit,
                                        days: daysIn2026,
                                        expandedHeight: cardHeight,
                                        todayKey: dayKey(for: today),
                                        isFutureDay: { day in day > today },
                                        dayKey: dayKey(for:),
                                        makeRestDay: makeRestDay(day:),
                                        makeTimeEntry: makeTimeEntry(minutes:unitLabel:dailyTarget:),
                                        onEdit: editHabit(_:),
                                        onDelete: deleteHabit(_:)
                                    )
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, verticalPadding)
                        }
                    }
                }
                .navigationTitle("Timekeeper")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            startAddingHabit()
                        } label: {
                            Image(systemName: "plus")
                                .font(.headline)
                        }
                        .accessibilityLabel("Add habit")
                    }
                }
                .sheet(isPresented: $isShowingAddHabit) {
                    AddHabitView(
                        habitName: $newHabitName,
                        symbolName: $newHabitSymbolName,
                        habitColor: $newHabitColor,
                        isTrackingEnabled: $newHabitIsTrackingEnabled,
                        trackingUnit: $newHabitTrackingUnit,
                        hasGoal: $newHabitHasGoal,
                        goalUnit: $newHabitGoalUnit,
                        goalTarget: $newHabitGoalTarget,
                        title: editingHabitID == nil ? "New Habit" : "Edit Habit",
                        saveButtonTitle: editingHabitID == nil ? "Add" : "Save",
                        onCancel: cancelHabitModal,
                        onSave: saveHabit
                    )
                    .preferredColorScheme(.dark)
                }
            }
            .tabItem {
                Label("Habits", systemImage: "checkmark.square")
            }

            StatsView(habits: activeHabits, rewards: activeRewards)
                .tabItem {
                    Label("Stats", systemImage: "chart.bar")
                }

            RewardsView(
                rewards: activeRewardsBinding,
                habits: activeHabits,
                isEditingReward: editingRewardID != nil,
                isShowingAddReward: $isShowingAddReward,
                newRewardName: $newRewardName,
                newRewardTarget: $newRewardTarget,
                newRewardLinkedHabitID: $newRewardLinkedHabitID,
                newRewardStartDate: $newRewardStartDate,
                newRewardHasCustomStartDate: $newRewardHasCustomStartDate,
                newRewardEndDate: $newRewardEndDate,
                newRewardHasDeadline: $newRewardHasDeadline,
                newRewardProgressRule: $newRewardProgressRule,
                selectedBulkStampRewardID: $selectedBulkStampRewardID,
                bulkStampAmount: $bulkStampAmount,
                highlightedRewardID: $highlightedRewardID,
                celebratingRewardID: $celebratingRewardID,
                onStartAddingReward: startAddingReward,
                onEditReward: editReward(_:),
                onDeleteReward: deleteReward(_:),
                onCancelRewardModal: cancelRewardModal,
                onSaveReward: saveReward,
                onRewardTap: handleRewardTap(_:),
                onConfirmBulkStamp: confirmBulkStamp,
                onClaimReward: claimReward(_:),
                onRestoreReward: restoreReward(_:)
            )
            .tabItem {
                Label("Rewards", systemImage: "gift.fill")
            }

            SettingsView(isDeveloperModeEnabled: developerModeBinding)
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
        .preferredColorScheme(.dark)
    }

    private var currentDataMode: DataMode {
        isDeveloperModeEnabled ? .mock : .real
    }

    private var activeHabits: [Habit] {
        habits(for: currentDataMode)
    }

    private var activeRewards: [Reward] {
        rewards(for: currentDataMode)
    }

    private var activeHabitsBinding: Binding<[Habit]> {
        Binding(
            get: { habits(for: currentDataMode) },
            set: { setHabits($0, for: currentDataMode) }
        )
    }

    private var activeRewardsBinding: Binding<[Reward]> {
        Binding(
            get: { rewards(for: currentDataMode) },
            set: { setRewards($0, for: currentDataMode) }
        )
    }

    private var developerModeBinding: Binding<Bool> {
        Binding(
            get: { isDeveloperModeEnabled },
            set: { newValue in
                isDeveloperModeEnabled = newValue
                storage.set(newValue, forKey: AppStorageKeys.developerModeEnabled)
                resetTransientState()
            }
        )
    }

    private var today: Date {
        calendar.startOfDay(for: Date())
    }

    private var daysIn2026: [Date] {
        guard
            let start = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1)),
            let end = calendar.date(from: DateComponents(year: 2026, month: 12, day: 31))
        else { return [] }

        var days: [Date] = []
        var currentDay = start

        while currentDay <= end {
            days.append(currentDay)
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: currentDay) else { break }
            currentDay = nextDay
        }

        return days
    }

    private func dayKey(for day: Date) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: day)
        return "\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)"
    }

    private func startAddingHabit() {
        resetNewHabit()
        isShowingAddHabit = true
    }

    private func editHabit(_ habit: Habit) {
        editingHabitID = habit.id
        newHabitName = habit.name
        newHabitSymbolName = habit.symbolName
        newHabitColor = habit.color
        newHabitIsTrackingEnabled = habit.isTrackingEnabled
        newHabitTrackingUnit = habit.trackingUnit
        newHabitHasGoal = habit.goal != nil
        newHabitGoalUnit = habit.goal?.unit ?? ""
        newHabitGoalTarget = habit.goal.map { "\($0.dailyTarget)" } ?? ""
        isShowingAddHabit = true
    }

    private func saveHabit() {
        let trimmedName = newHabitName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedTrackingUnit = newHabitTrackingUnit.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedGoalUnit = newHabitGoalUnit.trimmingCharacters(in: .whitespacesAndNewlines)
        let dailyTarget = Int(newHabitGoalTarget.trimmingCharacters(in: .whitespacesAndNewlines))
        guard !trimmedName.isEmpty else { return }
        guard !newHabitIsTrackingEnabled || newHabitHasGoal || !trimmedTrackingUnit.isEmpty else { return }
        guard !newHabitHasGoal || (!trimmedGoalUnit.isEmpty && (dailyTarget ?? 0) > 0) else { return }

        let goal = newHabitHasGoal ? HabitGoal(unit: trimmedGoalUnit, dailyTarget: dailyTarget ?? 0) : nil
        let isTrackingEnabled = newHabitIsTrackingEnabled || goal != nil
        let trackingUnit = goal?.unit ?? (isTrackingEnabled ? trimmedTrackingUnit : "")

        let dataMode = currentDataMode
        var updatedHabits = habits(for: dataMode)

        if let editingHabitID, let habitIndex = updatedHabits.firstIndex(where: { $0.id == editingHabitID }) {
            updatedHabits[habitIndex].name = trimmedName
            updatedHabits[habitIndex].symbolName = newHabitSymbolName
            updatedHabits[habitIndex].color = newHabitColor
            updatedHabits[habitIndex].isTrackingEnabled = isTrackingEnabled
            updatedHabits[habitIndex].trackingUnit = trackingUnit
            updatedHabits[habitIndex].goal = goal
        } else {
            updatedHabits.append(
                Habit(
                    name: trimmedName,
                    symbolName: newHabitSymbolName,
                    color: newHabitColor,
                    isTrackingEnabled: isTrackingEnabled,
                    trackingUnit: trackingUnit,
                    goal: goal
                )
            )
        }

        setHabits(updatedHabits, for: dataMode)

        resetNewHabit()
        isShowingAddHabit = false
    }

    private func resetNewHabit() {
        newHabitName = ""
        newHabitSymbolName = HabitSymbolOption.defaultSymbolName
        newHabitColor = .green
        newHabitIsTrackingEnabled = false
        newHabitTrackingUnit = ""
        newHabitHasGoal = false
        newHabitGoalUnit = ""
        newHabitGoalTarget = ""
        editingHabitID = nil
    }

    private func cancelHabitModal() {
        resetNewHabit()
        isShowingAddHabit = false
    }

    private func deleteHabit(_ habitID: UUID) {
        let dataMode = currentDataMode
        var updatedHabits = habits(for: dataMode)
        updatedHabits.removeAll { $0.id == habitID }
        setHabits(updatedHabits, for: dataMode)
    }

    private func makeRestDay(day: Date) -> RestDay {
        let components = calendar.dateComponents([.year, .month, .day], from: day)

        return RestDay(
            id: dayKey(for: day),
            markedAt: Date(),
            year: components.year ?? 0,
            month: components.month ?? 0,
            day: components.day ?? 0
        )
    }

    private func makeTimeEntry(minutes: Int, unitLabel: String, dailyTarget: Int?) -> TimeEntry {
        let now = Date()
        let components = calendar.dateComponents([.year, .month, .day], from: now)

        return TimeEntry(
            loggedAt: now,
            year: components.year ?? 0,
            month: components.month ?? 0,
            day: components.day ?? 0,
            minutes: minutes,
            unitLabel: unitLabel,
            dailyTarget: dailyTarget
        )
    }

    private func startAddingReward() {
        resetNewReward()
        isShowingAddReward = true
    }

    private func editReward(_ reward: Reward) {
        editingRewardID = reward.id
        newRewardName = reward.name
        newRewardTarget = "\(reward.stampTarget)"
        newRewardLinkedHabitID = reward.linkedHabitID
        newRewardStartDate = reward.startDate
        newRewardHasCustomStartDate = true
        newRewardEndDate = reward.endDate ?? today
        newRewardHasDeadline = reward.endDate != nil
        newRewardProgressRule = reward.linkedProgressRule
        isShowingAddReward = true
    }

    private func saveReward() {
        let trimmedName = newRewardName.trimmingCharacters(in: .whitespacesAndNewlines)
        let target = Int(newRewardTarget.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0

        guard !trimmedName.isEmpty, target > 0 else { return }

        let dataMode = currentDataMode
        var updatedRewards = rewards(for: dataMode)

        if let editingRewardID, let rewardIndex = updatedRewards.firstIndex(where: { $0.id == editingRewardID }) {
            updatedRewards[rewardIndex].name = trimmedName
            updatedRewards[rewardIndex].stampTarget = target
            updatedRewards[rewardIndex].linkedHabitID = newRewardLinkedHabitID
            updatedRewards[rewardIndex].startDate = calendar.startOfDay(for: newRewardStartDate)
            updatedRewards[rewardIndex].endDate = newRewardHasDeadline ? calendar.startOfDay(for: newRewardEndDate) : nil
            updatedRewards[rewardIndex].linkedProgressRule = newRewardLinkedHabitID == nil ? .automatic : newRewardProgressRule
        } else {
            updatedRewards.append(
                Reward(
                    name: trimmedName,
                    stampTarget: target,
                    linkedHabitID: newRewardLinkedHabitID,
                    startDate: calendar.startOfDay(for: newRewardStartDate),
                    endDate: newRewardHasDeadline ? calendar.startOfDay(for: newRewardEndDate) : nil,
                    linkedProgressRule: newRewardLinkedHabitID == nil ? .automatic : newRewardProgressRule
                )
            )
        }

        setRewards(updatedRewards, for: dataMode)

        resetNewReward()
        isShowingAddReward = false
    }

    private func resetNewReward() {
        newRewardName = ""
        newRewardTarget = ""
        newRewardLinkedHabitID = nil
        newRewardStartDate = today
        newRewardHasCustomStartDate = false
        newRewardEndDate = today
        newRewardHasDeadline = false
        newRewardProgressRule = .automatic
        editingRewardID = nil
    }

    private func cancelRewardModal() {
        resetNewReward()
        isShowingAddReward = false
    }

    private func deleteReward(_ rewardID: UUID) {
        let dataMode = currentDataMode
        var updatedRewards = rewards(for: dataMode)
        updatedRewards.removeAll { $0.id == rewardID }
        setRewards(updatedRewards, for: dataMode)
    }

    private func handleRewardTap(_ reward: Reward) {
        let dataMode = currentDataMode

        guard reward.linkedHabitID == nil else { return }
        guard rewardStampCount(for: reward, habits: habits(for: dataMode)) < reward.stampTarget else { return }

        if reward.stampTarget > 10 {
            bulkStampAmount = ""
            selectedBulkStampRewardID = reward.id
            return
        }

        addManualStamps(to: reward.id, amount: 1, in: dataMode)
    }

    private func confirmBulkStamp() {
        let amount = Int(bulkStampAmount.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
        guard let selectedBulkStampRewardID, amount > 0 else { return }

        addManualStamps(to: selectedBulkStampRewardID, amount: amount, in: currentDataMode)
        bulkStampAmount = ""
        self.selectedBulkStampRewardID = nil
    }

    private func addManualStamps(to rewardID: UUID, amount: Int, in dataMode: DataMode) {
        var updatedRewards = rewards(for: dataMode)
        guard let rewardIndex = updatedRewards.firstIndex(where: { $0.id == rewardID }) else { return }

        updatedRewards[rewardIndex].manualStampEntries.append(RewardStampEntry(amount: amount))
        setRewards(updatedRewards, for: dataMode)
        highlightedRewardID = rewardID

        withAnimation(.easeOut(duration: 0.22)) {
            highlightedRewardID = rewardID
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            withAnimation(.easeOut(duration: 0.3)) {
                if highlightedRewardID == rewardID {
                    highlightedRewardID = nil
                }
            }
        }
    }

    private func claimReward(_ reward: Reward) {
        let dataMode = currentDataMode
        guard rewardStampCount(for: reward, habits: habits(for: dataMode)) >= reward.stampTarget else { return }

        withAnimation(.spring(response: 0.42, dampingFraction: 0.7)) {
            celebratingRewardID = reward.id
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            var updatedRewards = rewards(for: dataMode)
            guard let rewardIndex = updatedRewards.firstIndex(where: { $0.id == reward.id }) else { return }

            withAnimation(.easeInOut(duration: 0.28)) {
                updatedRewards[rewardIndex].isArchived = true
                let claimedAt = Date()
                updatedRewards[rewardIndex].claimedAt = claimedAt
                updatedRewards[rewardIndex].claimDates.append(claimedAt)
                setRewards(updatedRewards, for: dataMode)
            }

            celebratingRewardID = nil
        }
    }

    private func restoreReward(_ reward: Reward) {
        let dataMode = currentDataMode
        var updatedRewards = rewards(for: dataMode)
        guard let rewardIndex = updatedRewards.firstIndex(where: { $0.id == reward.id }) else { return }

        updatedRewards[rewardIndex].isArchived = false
        updatedRewards[rewardIndex].claimedAt = nil
        setRewards(updatedRewards, for: dataMode)
    }

    private func habits(for dataMode: DataMode) -> [Habit] {
        switch dataMode {
        case .mock:
            mockHabits
        case .real:
            realHabits
        }
    }

    private func rewards(for dataMode: DataMode) -> [Reward] {
        switch dataMode {
        case .mock:
            mockRewards
        case .real:
            realRewards
        }
    }

    private func setHabits(_ habits: [Habit], for dataMode: DataMode) {
        switch dataMode {
        case .mock:
            mockHabits = habits
            persistDataset(for: .mock)
        case .real:
            realHabits = habits
            persistDataset(for: .real)
        }
    }

    private func setRewards(_ rewards: [Reward], for dataMode: DataMode) {
        switch dataMode {
        case .mock:
            mockRewards = rewards
            persistDataset(for: .mock)
        case .real:
            realRewards = rewards
            persistDataset(for: .real)
        }
    }

    private func persistDataset(for dataMode: DataMode) {
        let dataset = StoredDataset(
            habits: habits(for: dataMode).map { StoredHabit($0) },
            rewards: rewards(for: dataMode).map { StoredReward($0) }
        )

        guard let encodedDataset = try? JSONEncoder().encode(dataset) else { return }

        let key = switch dataMode {
        case .mock:
            AppStorageKeys.mockDataset
        case .real:
            AppStorageKeys.realDataset
        }

        storage.set(encodedDataset, forKey: key)
    }

    private func resetTransientState() {
        resetNewHabit()
        isShowingAddHabit = false
        resetNewReward()
        isShowingAddReward = false
        selectedBulkStampRewardID = nil
        bulkStampAmount = ""
        highlightedRewardID = nil
        celebratingRewardID = nil
    }

    private static func loadDataset(forKey key: String, storage: UserDefaults = .standard) -> StoredDataset? {
        guard let storedData = storage.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(StoredDataset.self, from: storedData)
    }
}

struct SettingsView: View {
    @Binding var isDeveloperModeEnabled: Bool

    var body: some View {
        NavigationStack {
            Form {
                Toggle("Developer Mode", isOn: $isDeveloperModeEnabled)
            }
            .scrollContentBackground(.hidden)
            .background(Color.black)
            .navigationTitle("Settings")
        }
    }
}

struct HabitRow: View {
    @Binding var habit: Habit

    let days: [Date]
    let expandedHeight: CGFloat
    let todayKey: String
    let isFutureDay: (Date) -> Bool
    let dayKey: (Date) -> String
    let makeRestDay: (Date) -> RestDay
    let makeTimeEntry: (Int, String, Int?) -> TimeEntry
    let onEdit: (Habit) -> Void
    let onDelete: (UUID) -> Void

    @State private var isShowingTimeEntry = false
    @State private var isShowingHistory = false
    @State private var shouldMarkCompleteOnSave = false
    @State private var sessionMinutes = 0
    @State private var manualTimeInput = ""
    @State private var isCollapsed = false

    private let calendar = Calendar(identifier: .gregorian)

    private var squareSize: CGFloat { isCollapsed ? 8 : 10 }
    private var squareSpacing: CGFloat { isCollapsed ? 3 : 4 }
    private var checkboxSize: CGFloat { isCollapsed ? 24 : 30 }
    private var saveButtonSize: CGFloat { isCollapsed ? 24 : 30 }
    private var horizontalSpacing: CGFloat { isCollapsed ? 10 : 12 }
    private var cardSpacing: CGFloat { isCollapsed ? 6 : 8 }
    private var cardPadding: CGFloat { isCollapsed ? 10 : 14 }
    private var titleFont: Font { isCollapsed ? .callout.weight(.medium) : .body.weight(.medium) }
    private var symbolFont: Font { isCollapsed ? .callout.weight(.medium) : .body.weight(.medium) }
    private var compactHeatMapDays: [Date] {
        Array(days.filter { $0 <= Date() }.suffix(5))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: cardSpacing) {
            HStack(spacing: isCollapsed ? 6 : 8) {
                Image(systemName: habit.symbolName)
                    .font(symbolFont)
                    .foregroundStyle(habit.color)
                    .frame(width: isCollapsed ? 16 : 18)

                Text(habit.name)
                    .font(titleFont)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                isShowingHistory = true
            }

            HStack(alignment: .center, spacing: horizontalSpacing) {
                Group {
                    if isCollapsed {
                        compactHeatMap
                    } else {
                        ScrollViewReader { proxy in
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(alignment: .top, spacing: squareSpacing) {
                                    ForEach(weekColumns, id: \.start) { column in
                                        VStack(spacing: squareSpacing) {
                                            ForEach(0..<7, id: \.self) { index in
                                                if let day = column.days[index] {
                                                    heatMapSquare(for: day)
                                                } else {
                                                    Color.clear
                                                        .frame(width: squareSize, height: squareSize)
                                                }
                                            }
                                        }
                                        .id(column.id)
                                    }
                                }
                                .padding(.vertical, 1)
                            }
                            .onAppear {
                                guard let currentWeekColumnID else { return }

                                DispatchQueue.main.async {
                                    proxy.scrollTo(currentWeekColumnID, anchor: .trailing)
                                }
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture {
                    isShowingHistory = true
                }

                VStack(alignment: .trailing, spacing: isCollapsed ? 6 : 8) {
                    Button {
                        handlePrimaryProgressAction()
                    } label: {
                        progressIndicator
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(habit.isTrackingEnabled ? "Log progress for \(habit.name)" : "Toggle \(habit.name)")
                    .accessibilityValue(progressAccessibilityValue)

                    if habit.isTrackingEnabled {
                        Button {
                            shouldMarkCompleteOnSave = false
                            isShowingTimeEntry = true
                        } label: {
                            Image(systemName: "plus")
                                .font(isCollapsed ? .caption2.weight(.bold) : .caption.weight(.bold))
                                .frame(width: saveButtonSize, height: saveButtonSize)
                        }
                        .buttonStyle(.bordered)
                        .accessibilityLabel("Log progress for \(habit.name)")
                    }
                }
            }
        }
        .padding(cardPadding)
        .frame(
            maxWidth: .infinity,
            minHeight: isCollapsed ? nil : expandedHeight,
            maxHeight: isCollapsed ? nil : expandedHeight,
            alignment: .topLeading
        )
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.07))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .opacity(isRestToday ? 0.52 : 1)
        .contextMenu {
            Button {
                onEdit(habit)
            } label: {
                Label("Edit", systemImage: "pencil")
            }

            Button {
                toggleTodayRest()
            } label: {
                Label(isRestToday ? "Unmark Rest Day" : "Mark Day as Rest", systemImage: "moon")
            }

            Button {
                isCollapsed.toggle()
            } label: {
                Label(isCollapsed ? "Expand" : "Collapse", systemImage: isCollapsed ? "arrow.down.left.and.arrow.up.right" : "arrow.up.left.and.arrow.down.right")
            }

            Button(role: .destructive) {
                onDelete(habit.id)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .sheet(isPresented: $isShowingTimeEntry) {
            TimeEntryView(
                habitName: habit.name,
                unitLabel: activeUnitLabel,
                title: "Log Progress",
                placeholder: activeUnitLabel.capitalized,
                manualTimeInput: $manualTimeInput,
                sessionMinutes: $sessionMinutes,
                allowsEmptySave: shouldMarkCompleteOnSave,
                onCancel: cancelTimeEntrySession,
                onSave: saveTimeEntry
            )
            .preferredColorScheme(.dark)
        }
        .sheet(isPresented: $isShowingHistory) {
            HabitHistorySheet(habit: $habit, initialMonth: calendar.component(.month, from: Date()))
                .preferredColorScheme(.dark)
        }
    }

    private var isCompleteToday: Bool {
        if let goal = habit.goal {
            return habit.completedDays.contains(todayKey) || progress(for: todayKey) >= goal.dailyTarget
        }

        if habit.isTrackingEnabled {
            return habit.completedDays.contains(todayKey) || progress(for: todayKey) > 0
        }

        return habit.completedDays.contains(todayKey)
    }

    private var isRestToday: Bool {
        habit.restDays.contains { $0.id == todayKey }
    }

    private var manualTimeMinutes: Int {
        let trimmedInput = manualTimeInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let minutes = Int(trimmedInput), minutes > 0 else { return 0 }
        return minutes
    }

    private var totalTimeEntryMinutes: Int {
        sessionMinutes + manualTimeMinutes
    }

    private var progressAccessibilityValue: String {
        guard let goal = habit.goal else {
            if habit.isTrackingEnabled {
                let progress = progress(for: todayKey)
                return isRestToday ? "Rest day" : "\(progress) \(activeUnitLabel)"
            }

            return isRestToday ? "Rest day" : isCompleteToday ? "Complete" : "Incomplete"
        }

        let progress = progress(for: todayKey)
        return isRestToday ? "Rest day" : "\(progress) of \(goal.dailyTarget) \(goal.unit)"
    }

    @ViewBuilder
    private var progressIndicator: some View {
        if isRestToday {
            ZStack {
                Circle()
                    .fill(Color.clear)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.42), lineWidth: 1.5)
                    )

                Image(systemName: "moon.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.82))
            }
            .frame(width: checkboxSize, height: checkboxSize)
        } else if habit.goal == nil {
            Circle()
                .fill(isCompleteToday ? habit.color : Color.clear)
                .overlay(
                    Circle()
                        .stroke(isCompleteToday ? habit.color : Color.white.opacity(0.42), lineWidth: 1.5)
                )
                .frame(width: checkboxSize, height: checkboxSize)
        } else {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.18), lineWidth: 4)

                Circle()
                    .trim(from: 0, to: todayProgressRatio)
                    .stroke(habit.color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            .frame(width: checkboxSize, height: checkboxSize)
        }
    }

    private var todayProgressRatio: Double {
        progressRatio(for: todayKey)
    }

    private var activeUnitLabel: String {
        habit.goal?.unit ?? habit.trackingUnit
    }

    private var currentWeekColumnID: Int? {
        weekColumns.first { column in
            column.days.contains { day in
                guard let day else { return false }
                return dayKey(day) == todayKey
            }
        }?.id
    }

    private var weekColumns: [WeekColumn] {
        guard let currentWeekIndex = allWeekColumns.firstIndex(where: { column in
            column.days.contains { day in
                guard let day else { return false }
                return dayKey(day) == todayKey
            }
        }) else {
            return allWeekColumns
        }

        return Array(allWeekColumns.prefix(through: currentWeekIndex))
    }

    private var compactHeatMap: some View {
        HStack(spacing: squareSpacing) {
            ForEach(compactHeatMapDays, id: \.self) { day in
                heatMapSquare(for: day)
            }
        }
        .padding(.vertical, 1)
    }

    private var allWeekColumns: [WeekColumn] {
        guard let firstDay = days.first else { return [] }

        let leadingEmptyDays = mondayBasedWeekdayIndex(for: firstDay)
        let totalSlots = leadingEmptyDays + days.count
        let columnCount = Int(ceil(Double(totalSlots) / 7.0))

        return (0..<columnCount).map { columnIndex in
            let columnStart = columnIndex * 7
            let columnDays = (0..<7).map { rowIndex -> Date? in
                let dayIndex = columnStart + rowIndex - leadingEmptyDays
                guard days.indices.contains(dayIndex) else { return nil }
                return days[dayIndex]
            }

            return WeekColumn(start: columnIndex, days: columnDays)
        }
    }

    private func heatMapSquare(for day: Date) -> some View {
        let key = dayKey(day)
        let isRest = habit.restDays.contains { $0.id == key }
        let progressRatio = progressRatio(for: key)
        let fillColor = if isRest && !isFutureDay(day) {
            Color.white.opacity(0.12)
        } else if progressRatio > 0 && !isFutureDay(day) {
            habit.color.opacity(progressRatio)
        } else {
            Color.white.opacity(0.12)
        }

        return RoundedRectangle(cornerRadius: 2)
            .fill(fillColor)
            .frame(width: squareSize, height: squareSize)
            .overlay(
                ZStack {
                    RoundedRectangle(cornerRadius: 2)
                        .stroke(Color.white.opacity(0.08), lineWidth: 0.5)

                    if isRest && !isFutureDay(day) {
                        Image(systemName: "moon")
                            .font(.system(size: squareSize * 0.6, weight: .thin))
                            .foregroundStyle(.white.opacity(0.82))
                    }
                }
            )
    }

    private func toggleTodayCompletion() {
        guard !isRestToday else { return }

        if habit.completedDays.contains(todayKey) {
            habit.completedDays.remove(todayKey)
        } else {
            habit.completedDays.insert(todayKey)
        }
    }

    private func handlePrimaryProgressAction() {
        if isRestToday {
            toggleTodayRest()
            return
        }

        if habit.isTrackingEnabled {
            if isCompleteToday {
                clearTodayProgress()
            } else {
                shouldMarkCompleteOnSave = true
                isShowingTimeEntry = true
            }
        } else {
            toggleTodayCompletion()
        }
    }

    private func saveTimeEntry() {
        let minutes = totalTimeEntryMinutes
        guard shouldMarkCompleteOnSave || minutes > 0 else { return }

        habit.timeEntries.append(makeTimeEntry(minutes, activeUnitLabel, habit.goal?.dailyTarget))

        if shouldMarkCompleteOnSave {
            habit.completedDays.insert(todayKey)
        }

        updateGoalCompletionForToday()
        resetTimeEntrySession()
        shouldMarkCompleteOnSave = false
        isShowingTimeEntry = false
    }

    private func updateGoalCompletionForToday() {
        guard let goal = habit.goal else { return }

        if habit.completedDays.contains(todayKey) || progress(for: todayKey) >= goal.dailyTarget {
            habit.completedDays.insert(todayKey)
        } else {
            habit.completedDays.remove(todayKey)
        }
    }

    private func clearTodayProgress() {
        habit.completedDays.remove(todayKey)
        habit.timeEntries.removeAll { "\($0.year)-\($0.month)-\($0.day)" == todayKey }
    }

    private func resetTimeEntrySession() {
        sessionMinutes = 0
        manualTimeInput = ""
        shouldMarkCompleteOnSave = false
    }

    private func cancelTimeEntrySession() {
        resetTimeEntrySession()
        isShowingTimeEntry = false
    }

    private func toggleTodayRest() {
        if isRestToday {
            habit.restDays.removeAll { $0.id == todayKey }
            return
        }

        habit.completedDays.remove(todayKey)
        habit.restDays.append(makeRestDay(Date()))
    }

    private func progress(for key: String) -> Int {
        entries(for: key).reduce(0) { $0 + $1.minutes }
    }

    private func progressRatio(for key: String) -> Double {
        let entries = entries(for: key)

        if habit.completedDays.contains(key) {
            return 1
        }

        if !entries.isEmpty {
            if let dailyTarget = entries.first(where: { $0.dailyTarget != nil })?.dailyTarget, dailyTarget > 0 {
                return min(Double(progress(for: key)) / Double(dailyTarget), 1)
            }

            if let goal = habit.goal, goal.dailyTarget > 0 {
                return min(Double(progress(for: key)) / Double(goal.dailyTarget), 1)
            }

            return 1
        }

        return habit.completedDays.contains(key) ? 1 : 0
    }

    private func entries(for key: String) -> [TimeEntry] {
        habit.timeEntries.filter { "\($0.year)-\($0.month)-\($0.day)" == key }
    }

    private func mondayBasedWeekdayIndex(for day: Date) -> Int {
        let weekday = Calendar(identifier: .gregorian).component(.weekday, from: day)
        return (weekday + 5) % 7
    }
}

private struct IdentifiableDay: Identifiable {
    let date: Date

    var id: Date { date }
}

struct HabitHistorySheet: View {
    @Binding var habit: Habit

    @State private var selectedMonth: Int
    @State private var selectedDay: IdentifiableDay?

    private let calendar = Calendar(identifier: .gregorian)
    private let today: Date

    init(habit: Binding<Habit>, initialMonth: Int) {
        _habit = habit
        _selectedMonth = State(initialValue: initialMonth)
        today = Calendar(identifier: .gregorian).startOfDay(for: Date())
    }

    var body: some View {
        let stats = HabitStatsCalculator(habit: habit, today: today, calendar: calendar)

        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        HStack {
                            Button {
                                selectedMonth -= 1
                            } label: {
                                Image(systemName: "chevron.left")
                                    .font(.headline.weight(.semibold))
                                    .frame(width: 36, height: 36)
                            }
                            .buttonStyle(.bordered)
                            .disabled(selectedMonth == 1)

                            Spacer()

                            VStack(spacing: 4) {
                                Text(stats.monthName(for: selectedMonth, style: .wide))
                                    .font(.title3.weight(.bold))
                                    .foregroundStyle(.white)

                                Text(String(calendar.component(.year, from: today)))
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.white.opacity(0.6))
                            }

                            Spacer()

                            Button {
                                selectedMonth += 1
                            } label: {
                                Image(systemName: "chevron.right")
                                    .font(.headline.weight(.semibold))
                                    .frame(width: 36, height: 36)
                            }
                            .buttonStyle(.bordered)
                            .disabled(selectedMonth == 12)
                        }

                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 8) {
                            ForEach(0..<7, id: \.self) { weekdayIndex in
                                Text(stats.weekdayName(for: weekdayIndex).prefix(3))
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.white.opacity(0.65))
                                    .frame(maxWidth: .infinity)
                            }

                            ForEach(Array(stats.monthGridDays(for: selectedMonth).enumerated()), id: \.offset) { _, date in
                                if let date {
                                    let day = stats.day(for: date)

                                    HabitHeatMapSquare(
                                        habit: habit,
                                        day: day,
                                        squareSize: 40,
                                        isEnabled: !isFutureDay(date)
                                    ) {
                                        guard !isFutureDay(date) else { return }
                                        selectedDay = IdentifiableDay(date: date)
                                    }
                                } else {
                                    Color.clear
                                        .frame(height: 40)
                                }
                            }
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 18)
                                .fill(Color.white.opacity(0.05))
                        )
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 20)
                }
            }
            .navigationTitle(habit.name)
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(item: $selectedDay) { selectedDay in
            HabitDayEditorView(habit: $habit, date: selectedDay.date) { date, quantity, isComplete, isRestDay in
                applyDayEdit(for: date, quantity: quantity, isComplete: isComplete, isRestDay: isRestDay)
            }
            .preferredColorScheme(.dark)
            .presentationDetents([.fraction(0.75)])
        }
    }

    private func applyDayEdit(for date: Date, quantity: Int, isComplete: Bool, isRestDay: Bool) {
        let normalizedDate = calendar.startOfDay(for: date)
        let key = dayKey(for: normalizedDate)

        habit.timeEntries.removeAll { "\($0.year)-\($0.month)-\($0.day)" == key }
        habit.completedDays.remove(key)
        habit.restDays.removeAll { $0.id == key }

        if isRestDay {
            let components = calendar.dateComponents([.year, .month, .day], from: normalizedDate)
            habit.restDays.append(
                RestDay(
                    id: key,
                    markedAt: normalizedDate,
                    year: components.year ?? 0,
                    month: components.month ?? 0,
                    day: components.day ?? 0
                )
            )
            adjustCreatedAtIfNeeded(for: normalizedDate)
            return
        }

        if habit.isTrackingEnabled && quantity > 0 {
            let components = calendar.dateComponents([.year, .month, .day], from: normalizedDate)
            habit.timeEntries.append(
                TimeEntry(
                    loggedAt: normalizedDate,
                    year: components.year ?? 0,
                    month: components.month ?? 0,
                    day: components.day ?? 0,
                    minutes: quantity,
                    unitLabel: habit.goal?.unit ?? habit.trackingUnit,
                    dailyTarget: habit.goal?.dailyTarget
                )
            )
        }

        if isComplete {
            habit.completedDays.insert(key)
        }

        if quantity > 0 || isComplete {
            adjustCreatedAtIfNeeded(for: normalizedDate)
        }
    }

    private func adjustCreatedAtIfNeeded(for date: Date) {
        let normalizedCreatedAt = calendar.startOfDay(for: habit.createdAt)
        if date < normalizedCreatedAt {
            habit.createdAt = date
        }
    }

    private func dayKey(for day: Date) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: day)
        return "\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)"
    }

    private func isFutureDay(_ date: Date) -> Bool {
        calendar.startOfDay(for: date) > today
    }
}

struct HabitDayEditorView: View {
    @Binding var habit: Habit

    let date: Date
    let onSave: (Date, Int, Bool, Bool) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var quantityInput: String
    @State private var isMarkedComplete: Bool
    @State private var isRestDay: Bool

    private let keypadColumns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)
    private let keypadKeys = ["1", "2", "3", "4", "5", "6", "7", "8", "9", ".", "0", "⌫"]

    init(habit: Binding<Habit>, date: Date, onSave: @escaping (Date, Int, Bool, Bool) -> Void) {
        _habit = habit
        self.date = Calendar(identifier: .gregorian).startOfDay(for: date)
        self.onSave = onSave

        let calendar = Calendar(identifier: .gregorian)
        let normalizedDate = calendar.startOfDay(for: date)
        let key = HabitDayEditorView.dayKey(for: normalizedDate, calendar: calendar)
        let quantity = habit.wrappedValue.timeEntries
            .filter { "\($0.year)-\($0.month)-\($0.day)" == key }
            .reduce(0) { $0 + $1.minutes }
        let isRestDay = habit.wrappedValue.restDays.contains { $0.id == key }
        let isMarkedComplete = HabitDayEditorView.completionState(for: habit.wrappedValue, key: key, quantity: quantity)

        _quantityInput = State(initialValue: quantity > 0 ? "\(quantity)" : "0")
        _isMarkedComplete = State(initialValue: isMarkedComplete)
        _isRestDay = State(initialValue: isRestDay)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 14) {
                    Text(date.formatted(date: .long, time: .omitted))
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, alignment: .center)

                    Text(displayValue)
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.white.opacity(0.07))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )

                    if habit.isTrackingEnabled {
                        keypad
                            .layoutPriority(1)
                    }

                    Spacer(minLength: 0)

                    VStack(spacing: 12) {
                        Toggle("Mark as complete", isOn: $isMarkedComplete)
                            .tint(habit.color)
                            .onChange(of: isMarkedComplete) { _, isEnabled in
                                if isEnabled {
                                    isRestDay = false
                                }
                            }

                        Toggle("Mark as rest day", isOn: $isRestDay)
                            .tint(.indigo)
                            .onChange(of: isRestDay) { _, isEnabled in
                                guard isEnabled else { return }
                                isMarkedComplete = false
                                quantityInput = "0"
                            }

                        Button("Clear Day", role: .destructive) {
                            quantityInput = "0"
                            isMarkedComplete = false
                            isRestDay = false
                        }
                        .frame(maxWidth: .infinity)
                        .buttonStyle(.bordered)

                        Button("Save") {
                            saveAndDismiss()
                        }
                        .frame(maxWidth: .infinity)
                        .buttonStyle(.borderedProminent)
                        .tint(habit.color)
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.white.opacity(0.05))
                    )
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }
            .navigationTitle("Edit Day")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        saveAndDismiss()
                    }
                }
            }
        }
    }

    private var quantityValue: Int {
        let trimmedInput = quantityInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let quantity = Double(trimmedInput), quantity > 0 else { return 0 }
        return Int(quantity.rounded())
    }

    private var displayValue: String {
        quantityInput.isEmpty ? "0" : quantityInput
    }

    private var keypad: some View {
        LazyVGrid(columns: keypadColumns, spacing: 12) {
            ForEach(keypadKeys, id: \.self) { key in
                keypadButton(for: key)
            }
        }
    }

    private func keypadButton(for key: String) -> some View {
        Button {
            handleKeypadInput(key)
        } label: {
            Text(key)
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white.opacity(0.08))
                )
        }
        .buttonStyle(.plain)
    }

    private func saveAndDismiss() {
        onSave(date, quantityValue, isMarkedComplete, isRestDay)
        dismiss()
    }

    private func handleKeypadInput(_ key: String) {
        switch key {
        case "⌫":
            if quantityInput.count <= 1 {
                quantityInput = "0"
            } else {
                quantityInput.removeLast()
            }
        case ".":
            guard !quantityInput.contains(".") else { return }
            quantityInput += "."
        default:
            if quantityInput == "0" {
                quantityInput = key
            } else {
                quantityInput += key
            }
        }

        if quantityValue > 0 || quantityInput.contains(".") {
            isRestDay = false
        }
    }

    private static func completionState(for habit: Habit, key: String, quantity: Int) -> Bool {
        if let goal = habit.goal {
            return habit.completedDays.contains(key) || quantity >= goal.dailyTarget
        }

        if habit.isTrackingEnabled {
            return habit.completedDays.contains(key) || quantity > 0
        }

        return habit.completedDays.contains(key)
    }

    private static func dayKey(for day: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: day)
        return "\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)"
    }
}

struct WeekColumn: Identifiable {
    let start: Int
    let days: [Date?]

    var id: Int { start }
}

struct HabitStatsDay: Identifiable {
    let date: Date
    let key: String
    let quantity: Int
    let isCompleted: Bool
    let isRestDay: Bool
    let isEligible: Bool
    let progressRatio: Double

    var id: String { key }
}

struct HabitStatsWeekPoint: Identifiable {
    let startDate: Date
    let value: Double
    let consistency: Double

    var id: Date { startDate }
}

struct HabitStatsMonthPoint: Identifiable {
    let month: Int
    let startDate: Date
    let totalQuantity: Int
    let completedDays: Int
    let eligibleDays: Int

    var id: Int { month }
    var consistency: Double {
        guard eligibleDays > 0 else { return 0 }
        return Double(completedDays) / Double(eligibleDays)
    }
}

struct HabitWeekdayInsight: Identifiable {
    let weekdayIndex: Int
    let completionRate: Double

    var id: Int { weekdayIndex }
}

struct HabitLinkedRewardSummary: Identifiable {
    let reward: Reward
    let progress: Int

    var id: UUID { reward.id }
}

struct HabitStatsCalculator {
    let habit: Habit
    let today: Date
    let calendar: Calendar

    private var currentYear: Int {
        calendar.component(.year, from: today)
    }

    private var startOfYear: Date {
        calendar.date(from: DateComponents(year: currentYear, month: 1, day: 1)) ?? today
    }

    private var endOfYear: Date {
        calendar.date(from: DateComponents(year: currentYear, month: 12, day: 31)) ?? today
    }

    private var cappedEndDate: Date {
        min(today, endOfYear)
    }

    private var createdAtDay: Date {
        max(startOfYear, calendar.startOfDay(for: habit.createdAt))
    }

    var activeUnitLabel: String {
        habit.goal?.unit ?? habit.trackingUnit
    }

    var showsQuantityMetrics: Bool {
        habit.isTrackingEnabled
    }

    var allYearDays: [HabitStatsDay] {
        var days: [HabitStatsDay] = []
        var currentDay = startOfYear

        while currentDay <= endOfYear {
            days.append(day(for: currentDay))
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: currentDay) else { break }
            currentDay = nextDay
        }

        return days
    }

    var elapsedDays: [HabitStatsDay] {
        allYearDays.filter { $0.date <= cappedEndDate }
    }

    private var consistencyDays: [HabitStatsDay] {
        elapsedDays.filter { $0.date >= createdAtDay }
    }

    var totalQuantity: Int {
        elapsedDays.reduce(0) { $0 + $1.quantity }
    }

    var eligibleDayCount: Int {
        consistencyDays.filter(\.isEligible).count
    }

    var completedDayCount: Int {
        consistencyDays.filter { $0.isEligible && $0.isCompleted }.count
    }

    var consistencyRatio: Double {
        guard eligibleDayCount > 0 else { return 0 }
        return Double(completedDayCount) / Double(eligibleDayCount)
    }

    var averageQuantityPerDay: Double {
        guard eligibleDayCount > 0 else { return 0 }
        return Double(totalQuantity) / Double(eligibleDayCount)
    }

    var averageQuantityPerWeek: Double {
        guard elapsedWeekCount > 0 else { return 0 }
        return Double(totalQuantity) / Double(elapsedWeekCount)
    }

    var averageCompletionsPerDay: Double {
        guard eligibleDayCount > 0 else { return 0 }
        return Double(completedDayCount) / Double(eligibleDayCount)
    }

    var averageCompletionsPerWeek: Double {
        guard elapsedWeekCount > 0 else { return 0 }
        return Double(completedDayCount) / Double(elapsedWeekCount)
    }

    var currentStreak: Int {
        var streak = 0

        for day in elapsedDays.reversed() {
            if !day.isEligible { continue }
            guard day.isCompleted else { break }
            streak += 1
        }

        return streak
    }

    var longestStreak: Int {
        var longest = 0
        var current = 0

        for day in elapsedDays where day.isEligible {
            if day.isCompleted {
                current += 1
                longest = max(longest, current)
            } else {
                current = 0
            }
        }

        return longest
    }

    var fullYearWeekColumns: [WeekColumn] {
        weekColumns(for: allYearDays.map(\.date))
    }

    var currentWeekColumnID: Int? {
        fullYearWeekColumns.first { column in
            column.days.contains { date in
                guard let date else { return false }
                return dayKey(for: date) == dayKey(for: today)
            }
        }?.id
    }

    var monthPoints: [HabitStatsMonthPoint] {
        (1...12).compactMap { month in
            guard let startDate = calendar.date(from: DateComponents(year: currentYear, month: month, day: 1)) else {
                return nil
            }

            let days = elapsedDays.filter { calendar.component(.month, from: $0.date) == month }
            return HabitStatsMonthPoint(
                month: month,
                startDate: startDate,
                totalQuantity: days.reduce(0) { $0 + $1.quantity },
                completedDays: days.filter { $0.isEligible && $0.isCompleted }.count,
                eligibleDays: days.filter(\.isEligible).count
            )
        }
    }

    var weeklyTrendPoints: [HabitStatsWeekPoint] {
        let grouped = Dictionary(grouping: elapsedDays) { weekStart(for: $0.date) }

        return grouped.keys.sorted().map { startDate in
            let days = grouped[startDate] ?? []
            let totalQuantity = days.reduce(0) { $0 + $1.quantity }
            let completedDays = days.filter { $0.isEligible && $0.isCompleted }.count
            let eligibleDays = days.filter(\.isEligible).count
            let consistency = eligibleDays > 0 ? Double(completedDays) / Double(eligibleDays) : 0

            return HabitStatsWeekPoint(
                startDate: startDate,
                value: showsQuantityMetrics ? Double(totalQuantity) : Double(completedDays),
                consistency: consistency
            )
        }
    }

    var weekdayInsights: [HabitWeekdayInsight] {
        let grouped = Dictionary(grouping: elapsedDays.filter(\.isEligible)) { day in
            mondayBasedWeekdayIndex(for: day.date)
        }

        return (0..<7).map { weekdayIndex in
            let days = grouped[weekdayIndex] ?? []
            let rate = days.isEmpty ? 0 : Double(days.filter(\.isCompleted).count) / Double(days.count)
            return HabitWeekdayInsight(weekdayIndex: weekdayIndex, completionRate: rate)
        }
    }

    var bestWeekday: HabitWeekdayInsight? {
        guard eligibleDayCount > 0 else { return nil }
        return weekdayInsights.max { lhs, rhs in
            if lhs.completionRate == rhs.completionRate {
                return lhs.weekdayIndex > rhs.weekdayIndex
            }
            return lhs.completionRate < rhs.completionRate
        }
    }

    var worstWeekday: HabitWeekdayInsight? {
        guard eligibleDayCount > 0 else { return nil }
        return weekdayInsights.min { lhs, rhs in
            if lhs.completionRate == rhs.completionRate {
                return lhs.weekdayIndex > rhs.weekdayIndex
            }
            return lhs.completionRate < rhs.completionRate
        }
    }

    var longestGap: Int {
        var longest = 0
        var current = 0

        for day in elapsedDays where day.isEligible {
            if day.isCompleted {
                current = 0
            } else {
                current += 1
                longest = max(longest, current)
            }
        }

        return longest
    }

    var bestMonth: HabitStatsMonthPoint? {
        monthPoints
            .filter { $0.eligibleDays > 0 }
            .max { lhs, rhs in
            if lhs.consistency == rhs.consistency {
                return lhs.month > rhs.month
            }
            return lhs.consistency < rhs.consistency
        }
    }

    var goalBreakdown: (met: Int, partial: Int, missed: Int)? {
        guard let goal = habit.goal else { return nil }

        let met = elapsedDays.filter { $0.isEligible && $0.quantity >= goal.dailyTarget }.count
        let partial = elapsedDays.filter { $0.isEligible && $0.quantity > 0 && $0.quantity < goal.dailyTarget }.count
        let missed = elapsedDays.filter { $0.isEligible && $0.quantity == 0 }.count
        return (met, partial, missed)
    }

    func linkedRewards(from rewards: [Reward]) -> [HabitLinkedRewardSummary] {
        rewards
            .filter { !$0.isArchived && $0.linkedHabitID == habit.id }
            .map { HabitLinkedRewardSummary(reward: $0, progress: rewardStampCount(for: $0, habits: [habit])) }
    }

    func monthGridDays(for month: Int) -> [Date?] {
        guard
            let firstDay = calendar.date(from: DateComponents(year: currentYear, month: month, day: 1)),
            let dayRange = calendar.range(of: .day, in: .month, for: firstDay)
        else { return [] }

        let leadingEmptyDays = mondayBasedWeekdayIndex(for: firstDay)
        let days = dayRange.compactMap { day in
            calendar.date(from: DateComponents(year: currentYear, month: month, day: day))
        }

        return Array(repeating: nil, count: leadingEmptyDays) + days
    }

    func monthScrollColumnID(for month: Int) -> Int? {
        fullYearWeekColumns.first { column in
            column.days.contains { date in
                guard let date else { return false }
                let components = calendar.dateComponents([.year, .month, .day], from: date)
                return components.year == currentYear && components.month == month && components.day == 1
            }
        }?.id
    }

    func tooltipText(for day: HabitStatsDay) -> String {
        if day.isRestDay {
            return "Rest day"
        }

        if showsQuantityMetrics {
            if let goal = habit.goal, goal.dailyTarget > 0 {
                if day.quantity >= goal.dailyTarget {
                    return "Goal met"
                }
                return day.quantity > 0 ? "Partial progress" : "Missed"
            }

            return day.quantity > 0 ? "Logged" : "No entry"
        }

        return day.isCompleted ? "Completed" : "Missed"
    }

    func day(for date: Date) -> HabitStatsDay {
        let key = dayKey(for: date)
        let isRestDay = habit.restDays.contains { $0.id == key }
        let quantity = progress(for: key)
        let isEligible = date >= createdAtDay && date <= cappedEndDate && !isRestDay
        let isCompleted = completionState(for: key, quantity: quantity)
        let progressRatio = progressRatio(for: key, quantity: quantity)

        return HabitStatsDay(
            date: date,
            key: key,
            quantity: quantity,
            isCompleted: isCompleted,
            isRestDay: isRestDay,
            isEligible: isEligible,
            progressRatio: progressRatio
        )
    }

    func formattedAverage(_ value: Double) -> String {
        if value == 0 { return "0" }
        if value >= 10, value.rounded() == value {
            return String(Int(value))
        }

        return value.formatted(.number.precision(.fractionLength(1)))
    }

    func monthName(for month: Int, style: Date.FormatStyle.Symbol.Month = .abbreviated) -> String {
        let date = calendar.date(from: DateComponents(year: currentYear, month: month, day: 1)) ?? today
        return date.formatted(.dateTime.month(style))
    }

    func weekdayName(for weekdayIndex: Int) -> String {
        let symbols = calendar.weekdaySymbols
        let adjustedIndex = (weekdayIndex + 1) % 7
        return symbols[adjustedIndex]
    }

    private var elapsedWeekCount: Double {
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: cappedEndDate) else { return 1 }
        let distance = weekInterval.start.timeIntervalSince(startOfYear)
        return max((distance / (7 * 24 * 60 * 60)) + 1, 1)
    }

    private func progress(for key: String) -> Int {
        habit.timeEntries
            .filter { "\($0.year)-\($0.month)-\($0.day)" == key }
            .reduce(0) { $0 + $1.minutes }
    }

    private func completionState(for key: String, quantity: Int) -> Bool {
        if let goal = habit.goal {
            return habit.completedDays.contains(key) || quantity >= goal.dailyTarget
        }

        if habit.isTrackingEnabled {
            return habit.completedDays.contains(key) || quantity > 0
        }

        return habit.completedDays.contains(key)
    }

    private func progressRatio(for key: String, quantity: Int) -> Double {
        if habit.completedDays.contains(key) {
            return 1
        }

        if let goal = habit.goal, goal.dailyTarget > 0 {
            return min(Double(quantity) / Double(goal.dailyTarget), 1)
        }

        return quantity > 0 ? 1 : 0
    }

    private func dayKey(for day: Date) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: day)
        return "\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)"
    }

    private func weekStart(for day: Date) -> Date {
        calendar.dateInterval(of: .weekOfYear, for: day)?.start ?? day
    }

    private func weekColumns(for days: [Date]) -> [WeekColumn] {
        guard let firstDay = days.first else { return [] }

        let leadingEmptyDays = mondayBasedWeekdayIndex(for: firstDay)
        let totalSlots = leadingEmptyDays + days.count
        let columnCount = Int(ceil(Double(totalSlots) / 7.0))

        return (0..<columnCount).map { columnIndex in
            let columnStart = columnIndex * 7
            let columnDays = (0..<7).map { rowIndex -> Date? in
                let dayIndex = columnStart + rowIndex - leadingEmptyDays
                guard days.indices.contains(dayIndex) else { return nil }
                return days[dayIndex]
            }

            return WeekColumn(start: columnIndex, days: columnDays)
        }
    }

    private func mondayBasedWeekdayIndex(for day: Date) -> Int {
        let weekday = calendar.component(.weekday, from: day)
        return (weekday + 5) % 7
    }
}

struct StatsView: View {
    let habits: [Habit]
    let rewards: [Reward]
    private let calendar = Calendar(identifier: .gregorian)

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black
                    .ignoresSafeArea()

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 18) {
                        ForEach(habits) { habit in
                            NavigationLink {
                                HabitStatsDetailView(
                                    habit: habit,
                                    rewards: rewards,
                                    today: today,
                                    calendar: calendar
                                )
                            } label: {
                                StatsHabitCard(habit: habit, today: today, calendar: calendar)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 20)
                }
            }
            .navigationTitle("Stats")
        }
    }

    private var today: Date {
        calendar.startOfDay(for: Date())
    }
}

struct HabitStatsDetailView: View {
    let habit: Habit
    let rewards: [Reward]
    let today: Date
    let calendar: Calendar

    @State private var selectedMonth: Int
    @State private var selectedDayKey: String?

    init(habit: Habit, rewards: [Reward], today: Date, calendar: Calendar) {
        self.habit = habit
        self.rewards = rewards
        self.today = today
        self.calendar = calendar
        _selectedMonth = State(initialValue: calendar.component(.month, from: today))
    }

    var body: some View {
        let stats = HabitStatsCalculator(habit: habit, today: today, calendar: calendar)

        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 24) {
                    HabitStatsHeader(habit: habit, stats: stats)
                    HabitStatsSummarySection(habit: habit, stats: stats)
                    HabitYearHeatMapSection(
                        habit: habit,
                        stats: stats,
                        selectedMonth: $selectedMonth,
                        selectedDayKey: $selectedDayKey
                    )
                    HabitTrendsSection(habit: habit, stats: stats)
                    HabitPatternInsightsSection(stats: stats)

                    if habit.goal != nil {
                        HabitGoalSection(stats: stats)
                    }

                    let linkedRewards = stats.linkedRewards(from: rewards)
                    if !linkedRewards.isEmpty {
                        HabitLinkedRewardsSection(linkedRewards: linkedRewards)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
            }
        }
        .navigationTitle("Habit Stats")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct HabitStatsHeader: View {
    let habit: Habit
    let stats: HabitStatsCalculator

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(habit.color.opacity(0.18))
                    .frame(width: 52, height: 52)

                Image(systemName: habit.symbolName)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(habit.color)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(habit.name)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)

                Text(stats.showsQuantityMetrics ? stats.activeUnitLabel.capitalized : "Binary habit")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.6))
            }

            Spacer()

            RoundedRectangle(cornerRadius: 10)
                .fill(habit.color)
                .frame(width: 26, height: 26)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
                )
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(Color.white.opacity(0.07))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

struct HabitStatsSummarySection: View {
    let habit: Habit
    let stats: HabitStatsCalculator

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Summary")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)

            LazyVGrid(columns: columns, spacing: 12) {
                if stats.showsQuantityMetrics {
                    summaryMetric(title: "Total Logged", value: "\(stats.totalQuantity) \(stats.activeUnitLabel)")
                }

                summaryMetric(title: "Eligible vs Completed", value: "\(stats.eligibleDayCount) / \(stats.completedDayCount)")
                summaryMetric(title: "Current Streak", value: "\(stats.currentStreak) days")
                summaryMetric(title: "Longest Streak", value: "\(stats.longestStreak) days")
                summaryMetric(title: "Consistency", value: "\(Int((stats.consistencyRatio * 100).rounded()))%")
            }

            if stats.showsQuantityMetrics {
                HStack(spacing: 12) {
                    averageMetric(title: "Average per day", value: "\(stats.formattedAverage(stats.averageQuantityPerDay)) \(stats.activeUnitLabel)")
                    averageMetric(title: "Average per week", value: "\(stats.formattedAverage(stats.averageQuantityPerWeek)) \(stats.activeUnitLabel)")
                }
            } else {
                HStack(spacing: 12) {
                    averageMetric(title: "Completions per day", value: stats.formattedAverage(stats.averageCompletionsPerDay))
                    averageMetric(title: "Completions per week", value: stats.formattedAverage(stats.averageCompletionsPerWeek))
                }
            }
        }
    }

    private func summaryMetric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(.white.opacity(0.6))

            Text(value)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.07))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private func averageMetric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(.white.opacity(0.6))

            Text(value)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
        )
    }
}

struct HabitYearHeatMapSection: View {
    let habit: Habit
    let stats: HabitStatsCalculator
    @Binding var selectedMonth: Int
    @Binding var selectedDayKey: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Full Year Heat Map")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)

            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 8) {
                        ForEach(stats.fullYearWeekColumns) { column in
                            VStack(spacing: 8) {
                                ForEach(0..<7, id: \.self) { index in
                                    if let date = column.days[index] {
                                        let day = stats.day(for: date)
                                        HabitHeatMapSquare(
                                            habit: habit,
                                            day: day,
                                            squareSize: 22
                                        ) {
                                            selectedDayKey = day.key == todayKey ? nil : day.key
                                        }
                                    } else {
                                        Color.clear
                                            .frame(width: 22, height: 22)
                                    }
                                }
                            }
                            .id(column.id)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .onAppear {
                    if let currentWeekColumnID = stats.currentWeekColumnID {
                        DispatchQueue.main.async {
                            proxy.scrollTo(currentWeekColumnID, anchor: .trailing)
                        }
                    }
                }
                .onChange(of: selectedMonth) { _, month in
                    guard let columnID = stats.monthScrollColumnID(for: month) else { return }
                    withAnimation(.easeInOut(duration: 0.25)) {
                        proxy.scrollTo(columnID, anchor: .leading)
                    }
                }
            }

            HabitHeatMapTooltip(habit: habit, stats: stats, day: selectedDay)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(1...12, id: \.self) { month in
                        Button {
                            selectedMonth = month
                        } label: {
                            Text(stats.monthName(for: month))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(selectedMonth == month ? .black : .white.opacity(0.8))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(selectedMonth == month ? .white : Color.white.opacity(0.07))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                Text(stats.monthName(for: selectedMonth, style: .wide))
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)

                LazyVGrid(columns: Array(repeating: GridItem(.fixed(28), spacing: 8), count: 7), spacing: 8) {
                    ForEach(Array(stats.monthGridDays(for: selectedMonth).enumerated()), id: \.offset) { _, date in
                        if let date {
                            let day = stats.day(for: date)
                            HabitHeatMapSquare(
                                habit: habit,
                                day: day,
                                squareSize: 28
                            ) {
                                selectedDayKey = day.key == todayKey ? nil : day.key
                            }
                        } else {
                            Color.clear
                                .frame(width: 28, height: 28)
                        }
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.white.opacity(0.05))
            )
        }
    }

    private var selectedDay: HabitStatsDay {
        if let selectedDayKey,
           let selectedDay = stats.allYearDays.first(where: { $0.key == selectedDayKey }) {
            return selectedDay
        }

        return stats.day(for: Date())
    }

    private var todayKey: String {
        stats.day(for: Date()).key
    }
}

struct HabitHeatMapSquare: View {
    let habit: Habit
    let day: HabitStatsDay
    let squareSize: CGFloat
    let isEnabled: Bool
    let onTap: () -> Void

    init(habit: Habit, day: HabitStatsDay, squareSize: CGFloat, isEnabled: Bool = true, onTap: @escaping () -> Void) {
        self.habit = habit
        self.day = day
        self.squareSize = squareSize
        self.isEnabled = isEnabled
        self.onTap = onTap
    }

    var body: some View {
        Button(action: onTap) {
            RoundedRectangle(cornerRadius: squareSize * 0.22)
                .fill(fillColor)
                .frame(width: squareSize, height: squareSize)
                .overlay(
                    ZStack {
                        RoundedRectangle(cornerRadius: squareSize * 0.22)
                            .stroke(Color.white.opacity(0.09), lineWidth: 1)

                        if day.isRestDay && !isFutureDay {
                            Image(systemName: "moon")
                                .font(.system(size: squareSize * 0.58, weight: .thin))
                                .foregroundStyle(.white.opacity(0.82))
                        }
                    }
                )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }

    private var fillColor: Color {
        if day.date > Date() {
            return Color.white.opacity(0.05)
        }

        if day.isRestDay {
            return Color.white.opacity(0.12)
        }

        if day.progressRatio > 0 {
            return habit.color.opacity(max(day.progressRatio, 0.2))
        }

        return Color.white.opacity(0.12)
    }

    private var isFutureDay: Bool {
        day.date > Date()
    }
}

struct HabitHeatMapTooltip: View {
    let habit: Habit
    let stats: HabitStatsCalculator
    let day: HabitStatsDay

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(day.date.formatted(date: .long, time: .omitted))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)

                HStack(spacing: 8) {
                    Circle()
                        .fill(habit.color)
                        .frame(width: 8, height: 8)

                    Text(stats.tooltipText(for: day))
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.88))
                }
            }

            Spacer()

            Text(valueText)
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.09))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private var valueText: String {
        if stats.showsQuantityMetrics {
            return "\(day.quantity) \(stats.activeUnitLabel)"
        }

        return day.isCompleted ? "Completed" : day.isRestDay ? "Rest" : "Missed"
    }
}

struct HabitTrendsSection: View {
    let habit: Habit
    let stats: HabitStatsCalculator

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Trends")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)

            VStack(alignment: .leading, spacing: 12) {
                Text(stats.showsQuantityMetrics ? "Weekly quantity" : "Weekly completions")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)

                Chart(stats.weeklyTrendPoints) { point in
                    BarMark(
                        x: .value("Week", point.startDate, unit: .weekOfYear),
                        y: .value("Value", point.value)
                    )
                    .foregroundStyle(habit.color.gradient)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .chartXAxis(.hidden)
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .frame(height: 180)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.white.opacity(0.05))
            )

            VStack(alignment: .leading, spacing: 12) {
                Text("Weekly consistency")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)

                Chart(stats.weeklyTrendPoints) { point in
                    LineMark(
                        x: .value("Week", point.startDate, unit: .weekOfYear),
                        y: .value("Consistency", point.consistency * 100)
                    )
                    .foregroundStyle(.white)
                    .lineStyle(StrokeStyle(lineWidth: 2.5))

                    AreaMark(
                        x: .value("Week", point.startDate, unit: .weekOfYear),
                        y: .value("Consistency", point.consistency * 100)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [habit.color.opacity(0.28), habit.color.opacity(0.02)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
                .chartXAxis(.hidden)
                .chartYScale(domain: 0...100)
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .frame(height: 180)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.white.opacity(0.05))
            )
        }
    }
}

struct HabitPatternInsightsSection: View {
    let stats: HabitStatsCalculator

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Pattern Insights")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)

            VStack(spacing: 12) {
                insightRow(
                    title: "Best day",
                    value: insightText(for: stats.bestWeekday)
                )
                insightRow(
                    title: "Worst day",
                    value: insightText(for: stats.worstWeekday)
                )
                insightRow(
                    title: "Longest gap",
                    value: "\(stats.longestGap) days"
                )
                insightRow(
                    title: "Best month",
                    value: bestMonthText
                )
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.white.opacity(0.05))
            )
        }
    }

    private var bestMonthText: String {
        guard let bestMonth = stats.bestMonth else { return "No data" }
        return "\(stats.monthName(for: bestMonth.month)) · \(Int((bestMonth.consistency * 100).rounded()))%"
    }

    private func insightText(for insight: HabitWeekdayInsight?) -> String {
        guard let insight else { return "No data" }
        return "\(stats.weekdayName(for: insight.weekdayIndex)) · \(Int((insight.completionRate * 100).rounded()))%"
    }

    private func insightRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.white.opacity(0.65))
            Spacer()
            Text(value)
                .foregroundStyle(.white)
                .multilineTextAlignment(.trailing)
        }
        .font(.subheadline.weight(.medium))
    }
}

struct HabitGoalSection: View {
    let stats: HabitStatsCalculator

    var body: some View {
        guard let goal = stats.habit.goal, let breakdown = stats.goalBreakdown else {
            return AnyView(EmptyView())
        }

        return AnyView(
            VStack(alignment: .leading, spacing: 16) {
                Text("Goal")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Daily target")
                            .foregroundStyle(.white.opacity(0.65))
                        Spacer()
                        Text("\(goal.dailyTarget) \(goal.unit)")
                            .foregroundStyle(.white)
                    }

                    HStack {
                        Text("Actual average")
                            .foregroundStyle(.white.opacity(0.65))
                        Spacer()
                        Text("\(stats.formattedAverage(stats.averageQuantityPerDay)) \(goal.unit)")
                            .foregroundStyle(.white)
                    }

                    Divider()
                        .overlay(Color.white.opacity(0.08))

                    HStack {
                        goalStatePill(title: "Met", value: breakdown.met, color: .green)
                        goalStatePill(title: "Partial", value: breakdown.partial, color: .yellow)
                        goalStatePill(title: "Missed", value: breakdown.missed, color: .red)
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color.white.opacity(0.05))
                )
            }
        )
    }

    private func goalStatePill(title: String, value: Int, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(.white.opacity(0.6))

            Text("\(value)")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(color.opacity(0.14))
        )
    }
}

struct HabitLinkedRewardsSection: View {
    let linkedRewards: [HabitLinkedRewardSummary]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Linked Rewards")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(linkedRewards) { item in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(item.reward.name)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                                .lineLimit(1)

                            Text("\(item.progress) / \(item.reward.stampTarget) stamps")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.white.opacity(0.68))
                        }
                        .padding(12)
                        .frame(width: 150, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.white.opacity(0.07))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                    }
                }
            }
        }
    }
}

struct RewardsView: View {
    @Binding var rewards: [Reward]
    let habits: [Habit]
    let isEditingReward: Bool
    @Binding var isShowingAddReward: Bool
    @Binding var newRewardName: String
    @Binding var newRewardTarget: String
    @Binding var newRewardLinkedHabitID: UUID?
    @Binding var newRewardStartDate: Date
    @Binding var newRewardHasCustomStartDate: Bool
    @Binding var newRewardEndDate: Date
    @Binding var newRewardHasDeadline: Bool
    @Binding var newRewardProgressRule: RewardProgressRule
    @Binding var selectedBulkStampRewardID: UUID?
    @Binding var bulkStampAmount: String
    @Binding var highlightedRewardID: UUID?
    @Binding var celebratingRewardID: UUID?

    let onStartAddingReward: () -> Void
    let onEditReward: (Reward) -> Void
    let onDeleteReward: (UUID) -> Void
    let onCancelRewardModal: () -> Void
    let onSaveReward: () -> Void
    let onRewardTap: (Reward) -> Void
    let onConfirmBulkStamp: () -> Void
    let onClaimReward: (Reward) -> Void
    let onRestoreReward: (Reward) -> Void

    @State private var isShowingRewardHistory = false
    @State private var rewardPendingDeletion: Reward?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black
                    .ignoresSafeArea()

                if activeRewards.isEmpty {
                    ContentUnavailableView(
                        "No Rewards Yet",
                        systemImage: "gift",
                        description: Text("Add a reward to start collecting stamps.")
                    )
                    .foregroundStyle(.white.opacity(0.8))
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(activeRewards) { reward in
                                RewardCard(
                                    reward: reward,
                                    stampCount: rewardStampCount(for: reward, habits: habits),
                                    linkedHabitName: linkedHabitName(for: reward),
                                    isHighlighted: highlightedRewardID == reward.id,
                                    isCelebrating: celebratingRewardID == reward.id,
                                    onTap: { onRewardTap(reward) },
                                    onClaim: { onClaimReward(reward) },
                                    onEdit: { onEditReward(reward) },
                                    onDelete: { rewardPendingDeletion = reward }
                                )
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 20)
                    }
                }
            }
            .navigationTitle("Rewards")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        isShowingRewardHistory = true
                    } label: {
                        Image(systemName: "clock.arrow.circlepath")
                    }
                    .accessibilityLabel("Reward history")
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        onStartAddingReward()
                    } label: {
                        Image(systemName: "plus")
                            .font(.headline)
                    }
                    .accessibilityLabel("Add reward")
                }
            }
            .sheet(isPresented: $isShowingAddReward) {
                AddRewardView(
                    rewardName: $newRewardName,
                    stampTarget: $newRewardTarget,
                    linkedHabitID: $newRewardLinkedHabitID,
                    startDate: $newRewardStartDate,
                    hasCustomStartDate: $newRewardHasCustomStartDate,
                    endDate: $newRewardEndDate,
                    hasDeadline: $newRewardHasDeadline,
                    progressRule: $newRewardProgressRule,
                    habits: habits,
                    title: isEditingReward ? "Edit Reward" : "New Reward",
                    saveButtonTitle: isEditingReward ? "Save" : "Add",
                    onCancel: onCancelRewardModal,
                    onSave: onSaveReward
                )
                .preferredColorScheme(.dark)
            }
            .sheet(
                isPresented: Binding(
                    get: { selectedBulkStampRewardID != nil },
                    set: { isPresented in
                        if !isPresented {
                            bulkStampAmount = ""
                            selectedBulkStampRewardID = nil
                        }
                    }
                )
            ) {
                RewardBulkStampView(
                    amount: $bulkStampAmount,
                    onCancel: {
                        bulkStampAmount = ""
                        selectedBulkStampRewardID = nil
                    },
                    onConfirm: onConfirmBulkStamp
                )
                .preferredColorScheme(.dark)
                .presentationDetents([.height(220)])
            }
            .sheet(isPresented: $isShowingRewardHistory) {
                RewardHistoryView(
                    rewards: rewards,
                    habits: habits,
                    onEdit: onEditReward,
                    onDelete: onDeleteReward,
                    onRestore: onRestoreReward
                )
                .preferredColorScheme(.dark)
            }
            .confirmationDialog(
                "Delete \(rewardPendingDeletion?.name ?? "Reward")?",
                isPresented: Binding(
                    get: { rewardPendingDeletion != nil },
                    set: { if !$0 { rewardPendingDeletion = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Delete Reward", role: .destructive) {
                    guard let rewardPendingDeletion else { return }
                    onDeleteReward(rewardPendingDeletion.id)
                    self.rewardPendingDeletion = nil
                }
            }
        }
    }

    private var activeRewards: [Reward] {
        rewards.filter { !$0.isArchived }
    }

    private func linkedHabitName(for reward: Reward) -> String? {
        guard let linkedHabitID = reward.linkedHabitID else { return nil }
        return habits.first(where: { $0.id == linkedHabitID })?.name
    }
}

struct TimeEntryView: View {
    let habitName: String
    let unitLabel: String
    let title: String
    let placeholder: String

    @Binding var manualTimeInput: String
    @Binding var sessionMinutes: Int

    let allowsEmptySave: Bool
    let onCancel: () -> Void
    let onSave: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                TextField(placeholder, text: $manualTimeInput)
                    .keyboardType(.numberPad)

                HStack(spacing: 10) {
                    incrementButton(minutes: 5)
                    incrementButton(minutes: 15)
                    incrementButton(minutes: 30)
                }

                HStack {
                    Text("Session total")
                    Spacer()
                    Text("\(displayedTotal) \(unitLabel)")
                        .foregroundStyle(.secondary)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.black)
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave()
                    }
                    .disabled(!allowsEmptySave && displayedTotal <= 0)
                }
            }
        }
    }

    private var manualMinutes: Int {
        let trimmedInput = manualTimeInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let minutes = Int(trimmedInput), minutes > 0 else { return 0 }
        return minutes
    }

    private var displayedTotal: Int {
        sessionMinutes + manualMinutes
    }

    private func incrementButton(minutes: Int) -> some View {
        Button("+\(minutes)") {
            sessionMinutes += minutes
        }
        .buttonStyle(.bordered)
        .frame(maxWidth: .infinity)
    }
}

struct AddRewardView: View {
    @Binding var rewardName: String
    @Binding var stampTarget: String
    @Binding var linkedHabitID: UUID?
    @Binding var startDate: Date
    @Binding var hasCustomStartDate: Bool
    @Binding var endDate: Date
    @Binding var hasDeadline: Bool
    @Binding var progressRule: RewardProgressRule

    let habits: [Habit]
    let title: String
    let saveButtonTitle: String
    let onCancel: () -> Void
    let onSave: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                TextField("Reward name", text: $rewardName)
                    .textInputAutocapitalization(.words)

                TextField("Stamp target", text: $stampTarget)
                    .keyboardType(.numberPad)

                Section {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            hasCustomStartDate.toggle()
                        }
                    } label: {
                        Text("I already started working towards this")
                            .foregroundStyle(.blue)
                    }

                    if hasCustomStartDate {
                        DatePicker("Start date", selection: $startDate, displayedComponents: .date)
                    }
                }

                Section {
                    Toggle("Set a deadline", isOn: $hasDeadline)

                    if hasDeadline {
                        DatePicker("Deadline", selection: $endDate, displayedComponents: .date)
                    }
                }

                Picker("Linked habit", selection: $linkedHabitID) {
                    Text("None")
                        .tag(UUID?.none)

                    ForEach(habits) { habit in
                        Text(habit.name)
                            .tag(Optional(habit.id))
                    }
                }

                if let linkedHabit {
                    Section("Linked progress") {
                        Picker("Count", selection: $progressRule) {
                            ForEach(availableProgressRules(for: linkedHabit)) { rule in
                                Text(rule.title)
                                    .tag(rule)
                            }
                        }

                        Text(progressRule.description(for: linkedHabit))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.black)
            .navigationTitle(title)
            .onChange(of: linkedHabitID) { _, _ in
                if !availableProgressRules(for: linkedHabit).contains(progressRule) {
                    progressRule = .automatic
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(saveButtonTitle) {
                        onSave()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }

    private var canSave: Bool {
        let trimmedName = rewardName.trimmingCharacters(in: .whitespacesAndNewlines)
        let target = Int(stampTarget.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
        return !trimmedName.isEmpty && target > 0
    }

    private var linkedHabit: Habit? {
        guard let linkedHabitID else { return nil }
        return habits.first { $0.id == linkedHabitID }
    }

    private func availableProgressRules(for habit: Habit?) -> [RewardProgressRule] {
        guard let habit else { return [.automatic] }

        var rules: [RewardProgressRule] = [.automatic, .completedDays]
        if habit.isTrackingEnabled {
            rules.insert(.loggedQuantity, at: 1)
        }
        if habit.goal != nil {
            rules.append(.goalMetDays)
        }
        return rules
    }
}

struct RewardBulkStampView: View {
    @Binding var amount: String

    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("How many points would you like to add?")
                        .foregroundStyle(.white)

                    TextField("Points", text: $amount)
                        .keyboardType(.numberPad)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.black)
            .navigationTitle("Add Points")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Confirm") {
                        onConfirm()
                    }
                    .disabled((Int(amount.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0) <= 0)
                }
            }
        }
    }
}

struct RewardHistoryView: View {
    let rewards: [Reward]
    let habits: [Habit]
    let onEdit: (Reward) -> Void
    let onDelete: (UUID) -> Void
    let onRestore: (Reward) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var rewardPendingDeletion: Reward?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                if rewards.isEmpty {
                    ContentUnavailableView(
                        "No Reward History",
                        systemImage: "clock.arrow.circlepath",
                        description: Text("Reward activity will appear here.")
                    )
                } else {
                    List {
                        ForEach(sortedRewards) { reward in
                            Section {
                                let entries = rewardHistoryEntries(for: reward, habits: habits)

                                if entries.isEmpty {
                                    Text("No activity yet")
                                        .foregroundStyle(.secondary)
                                } else {
                                    ForEach(entries) { entry in
                                        HStack(spacing: 12) {
                                            VStack(alignment: .leading, spacing: 3) {
                                                Text(entry.detail)
                                                    .foregroundStyle(.primary)

                                                Text(entry.date.formatted(date: .abbreviated, time: .shortened))
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }

                                            Spacer()

                                            if entry.amount > 0 {
                                                Text("+\(entry.amount)")
                                                    .font(.headline.monospacedDigit())
                                                    .foregroundStyle(.yellow)
                                            }
                                        }
                                    }
                                }

                                if reward.isArchived {
                                    Button("Restore Reward") {
                                        onRestore(reward)
                                    }
                                }
                            } header: {
                                HStack {
                                    Text(reward.name)
                                    Spacer()
                                    Text(reward.isArchived ? "Claimed" : "\(rewardStampCount(for: reward, habits: habits)) / \(reward.stampTarget)")
                                }
                            }
                            .contextMenu {
                                Button {
                                    dismiss()
                                    DispatchQueue.main.async {
                                        onEdit(reward)
                                    }
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }

                                Button(role: .destructive) {
                                    rewardPendingDeletion = reward
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Reward History")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .confirmationDialog(
                "Delete \(rewardPendingDeletion?.name ?? "Reward")?",
                isPresented: Binding(
                    get: { rewardPendingDeletion != nil },
                    set: { if !$0 { rewardPendingDeletion = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Delete Reward", role: .destructive) {
                    guard let rewardPendingDeletion else { return }
                    onDelete(rewardPendingDeletion.id)
                    self.rewardPendingDeletion = nil
                }
            }
        }
    }

    private var sortedRewards: [Reward] {
        rewards.sorted {
            ($0.claimedAt ?? $0.startDate) > ($1.claimedAt ?? $1.startDate)
        }
    }
}

struct AddHabitView: View {
    @Binding var habitName: String
    @Binding var symbolName: String
    @Binding var habitColor: Color
    @Binding var isTrackingEnabled: Bool
    @Binding var trackingUnit: String
    @Binding var hasGoal: Bool
    @Binding var goalUnit: String
    @Binding var goalTarget: String

    let title: String
    let saveButtonTitle: String
    let onCancel: () -> Void
    let onSave: () -> Void

    @State private var isShowingSymbolPicker = false

    var body: some View {
        NavigationStack {
            Form {
                TextField("Habit name", text: $habitName)
                    .textInputAutocapitalization(.words)

                Button {
                    isShowingSymbolPicker = true
                } label: {
                    HStack {
                        Text("Symbol")
                            .foregroundStyle(.primary)

                        Spacer()

                        Image(systemName: symbolName)
                            .font(.body.weight(.medium))
                            .foregroundStyle(habitColor)

                        Text(HabitSymbolOption.label(for: symbolName))
                            .foregroundStyle(.secondary)
                    }
                }

                ColorPicker("Habit color", selection: $habitColor, supportsOpacity: false)

                Section("Tracking") {
                    Toggle("Track progress", isOn: $isTrackingEnabled)

                    Toggle("Set a daily goal", isOn: $hasGoal)

                    if hasGoal {
                        TextField("Unit, e.g. pages", text: $goalUnit)
                            .textInputAutocapitalization(.never)

                        TextField("Daily target", text: $goalTarget)
                            .keyboardType(.numberPad)
                    } else if isTrackingEnabled {
                        TextField("Unit, e.g. minutes", text: $trackingUnit)
                            .textInputAutocapitalization(.never)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.black)
            .navigationTitle(title)
            .sheet(isPresented: $isShowingSymbolPicker) {
                SymbolPickerView(selection: $symbolName, accentColor: habitColor)
                    .preferredColorScheme(.dark)
            }
            .onChange(of: hasGoal) { _, newValue in
                if newValue {
                    isTrackingEnabled = true
                }
            }
            .onChange(of: isTrackingEnabled) { _, newValue in
                if !newValue {
                    hasGoal = false
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(saveButtonTitle) {
                        onSave()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }

    private var canSave: Bool {
        let trimmedName = habitName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedTrackingUnit = trackingUnit.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedUnit = goalUnit.trimmingCharacters(in: .whitespacesAndNewlines)
        let target = Int(goalTarget.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0

        return !trimmedName.isEmpty
            && (!isTrackingEnabled || hasGoal || !trimmedTrackingUnit.isEmpty)
            && (!hasGoal || (!trimmedUnit.isEmpty && target > 0))
    }
}

struct RewardCard: View {
    let reward: Reward
    let stampCount: Int
    let linkedHabitName: String?
    let isHighlighted: Bool
    let isCelebrating: Bool
    let onTap: () -> Void
    let onClaim: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(reward.name)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)

                    if let endDateText {
                        Text("Deadline: \(endDateText)")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.72))
                    }

                    if let linkedHabitName {
                        Text("Linked to \(linkedHabitName)")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.62))

                        Text(reward.linkedProgressRule.title)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.5))
                    } else {
                        Text("Tap to add stamps")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.62))
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 10) {
                    Menu {
                        Button {
                            onEdit()
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }

                        Button(role: .destructive) {
                            onDelete()
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.title3)
                            .foregroundStyle(.white.opacity(0.75))
                    }

                    if reward.stampTarget > 10 {
                        Text("\(stampCount) / \(reward.stampTarget)")
                            .font(.headline.monospacedDigit())
                            .foregroundStyle(progressColor)
                    }
                }
            }

            if reward.stampTarget <= 10 {
                HStack(spacing: 10) {
                    ForEach(0..<reward.stampTarget, id: \.self) { index in
                        Circle()
                            .fill(index < stampCount ? progressColor : Color.clear)
                            .frame(width: 18, height: 18)
                            .overlay(
                                Circle()
                                    .stroke(index < stampCount ? progressColor : Color.white.opacity(0.25), style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
                            )
                    }
                }
            }

            if isReadyToClaim {
                Button("Claim") {
                    onClaim()
                }
                .buttonStyle(.borderedProminent)
                .tint(.yellow)
            }

            if isCelebrating {
                Text("Congratulations")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.yellow)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(cardFillColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(borderColor, lineWidth: isHighlighted || isCelebrating ? 2 : 1)
        )
        .scaleEffect(isCelebrating ? 1.03 : 1)
        .animation(.easeOut(duration: 0.2), value: isHighlighted)
        .animation(.spring(response: 0.4, dampingFraction: 0.72), value: isCelebrating)
        .contentShape(RoundedRectangle(cornerRadius: 20))
        .onTapGesture {
            onTap()
        }
        .contextMenu {
            Button {
                onEdit()
            } label: {
                Label("Edit", systemImage: "pencil")
            }

            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private var isReadyToClaim: Bool {
        stampCount >= reward.stampTarget
    }

    private var endDateText: String? {
        guard let endDate = reward.endDate else { return nil }
        return endDate.formatted(date: .abbreviated, time: .omitted)
    }

    private var progressColor: Color {
        isReadyToClaim ? .yellow : .white
    }

    private var cardFillColor: Color {
        if isCelebrating {
            return Color.yellow.opacity(0.22)
        }

        if isHighlighted {
            return Color.yellow.opacity(0.16)
        }

        return Color.white.opacity(0.07)
    }

    private var borderColor: Color {
        if isCelebrating || isHighlighted {
            return Color.yellow.opacity(0.88)
        }

        return Color.white.opacity(0.08)
    }
}

struct StatsHabitCard: View {
    let habit: Habit
    let today: Date
    let calendar: Calendar

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                HStack(spacing: 10) {
                    Image(systemName: habit.symbolName)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(habit.color)
                        .frame(width: 24)

                    Text(habit.name)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                }

                Spacer()

                if showsQuantityMetrics {
                    Text(totalText)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(habit.color)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.08))

                        Capsule()
                            .fill(habit.color)
                            .frame(width: max(proxy.size.width * consistencyRatio, consistencyRatio > 0 ? 8 : 0))
                    }
                }
                .frame(height: 10)

                HStack {
                    Text(averageText)
                        .foregroundStyle(.white.opacity(0.68))

                    Spacer()

                    Text(consistencyText)
                        .foregroundStyle(.white.opacity(0.9))
                }
                .font(.subheadline.weight(.medium))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.white.opacity(0.07))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .overlay(alignment: .trailing) {
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white.opacity(0.45))
                .padding(.trailing, 16)
        }
    }

    private var elapsedDays: [Date] {
        guard
            let startOfYear = calendar.date(from: DateComponents(year: calendar.component(.year, from: today), month: 1, day: 1))
        else { return [] }

        var days: [Date] = []
        var currentDay = max(startOfYear, calendar.startOfDay(for: habit.createdAt))

        while currentDay <= today {
            days.append(currentDay)
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: currentDay) else { break }
            currentDay = nextDay
        }

        return days
    }

    private var eligibleDayCount: Int {
        elapsedDays.filter { day in
            !habit.restDays.contains { $0.id == dayKey(for: day) }
        }.count
    }

    private var completedDayCount: Int {
        elapsedDays.filter { day in
            let key = dayKey(for: day)
            guard !habit.restDays.contains(where: { $0.id == key }) else { return false }

            if let goal = habit.goal {
                return habit.completedDays.contains(key) || progress(for: key) >= goal.dailyTarget
            }

            if habit.isTrackingEnabled {
                return habit.completedDays.contains(key) || progress(for: key) > 0
            }

            return habit.completedDays.contains(key)
        }.count
    }

    private var consistencyRatio: Double {
        guard eligibleDayCount > 0 else { return 0 }
        return min(Double(completedDayCount) / Double(eligibleDayCount), 1)
    }

    private var consistencyText: String {
        "\(Int((consistencyRatio * 100).rounded()))% consistency"
    }

    private var totalQuantity: Int {
        habit.timeEntries.reduce(0) { $0 + $1.minutes }
    }

    private var activeUnitLabel: String {
        habit.goal?.unit ?? habit.trackingUnit
    }

    private var showsQuantityMetrics: Bool {
        habit.isTrackingEnabled
    }

    private var totalText: String {
        "\(totalQuantity) \(activeUnitLabel)"
    }

    private var averageText: String {
        if showsQuantityMetrics {
            guard eligibleDayCount > 0 else { return "0 \(activeUnitLabel)/day" }
            let average = Double(totalQuantity) / Double(eligibleDayCount)
            return "\(formattedAverage(average)) \(activeUnitLabel)/day"
        }

        return consistencyFractionText
    }

    private var consistencyFractionText: String {
        "\(completedDayCount) of \(eligibleDayCount) days"
    }

    private func progress(for key: String) -> Int {
        habit.timeEntries
            .filter { "\($0.year)-\($0.month)-\($0.day)" == key }
            .reduce(0) { $0 + $1.minutes }
    }

    private func dayKey(for day: Date) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: day)
        return "\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)"
    }

    private func formattedAverage(_ value: Double) -> String {
        if value >= 10, value.rounded() == value {
            return String(Int(value))
        }

        return value.formatted(.number.precision(.fractionLength(2)))
    }
}

struct HabitSymbolOption: Identifiable {
    let name: String
    let label: String

    var id: String { name }

    static let defaultSymbolName = "circle.fill"

    static let all: [HabitSymbolOption] = [
        HabitSymbolOption(name: "circle.fill", label: "Circle"),
        HabitSymbolOption(name: "star.fill", label: "Star"),
        HabitSymbolOption(name: "heart.fill", label: "Heart"),
        HabitSymbolOption(name: "bolt.fill", label: "Bolt"),
        HabitSymbolOption(name: "flame.fill", label: "Flame"),
        HabitSymbolOption(name: "leaf.fill", label: "Leaf"),
        HabitSymbolOption(name: "moon.fill", label: "Moon"),
        HabitSymbolOption(name: "sun.max.fill", label: "Sun"),
        HabitSymbolOption(name: "cloud.fill", label: "Cloud"),
        HabitSymbolOption(name: "drop.fill", label: "Drop"),
        HabitSymbolOption(name: "book.closed.fill", label: "Book"),
        HabitSymbolOption(name: "pencil.and.scribble", label: "Writing"),
        HabitSymbolOption(name: "graduationcap.fill", label: "Learning"),
        HabitSymbolOption(name: "brain.head.profile", label: "Meditation"),
        HabitSymbolOption(name: "figure.run", label: "Running"),
        HabitSymbolOption(name: "figure.walk", label: "Walking"),
        HabitSymbolOption(name: "figure.cooldown", label: "Cooldown"),
        HabitSymbolOption(name: "dumbbell.fill", label: "Strength"),
        HabitSymbolOption(name: "bicycle", label: "Cycling"),
        HabitSymbolOption(name: "figure.yoga", label: "Yoga"),
        HabitSymbolOption(name: "fork.knife", label: "Nutrition"),
        HabitSymbolOption(name: "cup.and.saucer.fill", label: "Coffee"),
        HabitSymbolOption(name: "waterbottle.fill", label: "Hydration"),
        HabitSymbolOption(name: "bed.double.fill", label: "Sleep"),
        HabitSymbolOption(name: "alarm.fill", label: "Alarm"),
        HabitSymbolOption(name: "timer", label: "Timer"),
        HabitSymbolOption(name: "calendar", label: "Calendar"),
        HabitSymbolOption(name: "checkmark.circle.fill", label: "Checkmark"),
        HabitSymbolOption(name: "target", label: "Target"),
        HabitSymbolOption(name: "chart.line.uptrend.xyaxis", label: "Growth"),
        HabitSymbolOption(name: "briefcase.fill", label: "Work"),
        HabitSymbolOption(name: "hammer.fill", label: "Build"),
        HabitSymbolOption(name: "paintbrush.fill", label: "Art"),
        HabitSymbolOption(name: "camera.fill", label: "Photo"),
        HabitSymbolOption(name: "music.note", label: "Music"),
        HabitSymbolOption(name: "guitars.fill", label: "Instrument"),
        HabitSymbolOption(name: "mic.fill", label: "Voice"),
        HabitSymbolOption(name: "airplane", label: "Travel"),
        HabitSymbolOption(name: "car.fill", label: "Driving"),
        HabitSymbolOption(name: "house.fill", label: "Home"),
        HabitSymbolOption(name: "pawprint.fill", label: "Pet"),
        HabitSymbolOption(name: "stethoscope", label: "Health"),
        HabitSymbolOption(name: "cross.case.fill", label: "Care"),
        HabitSymbolOption(name: "hands.clap.fill", label: "Celebrate"),
        HabitSymbolOption(name: "person.2.fill", label: "Social"),
        HabitSymbolOption(name: "message.fill", label: "Messages"),
        HabitSymbolOption(name: "phone.fill", label: "Calls"),
        HabitSymbolOption(name: "globe", label: "Explore"),
        HabitSymbolOption(name: "sparkles", label: "Reflect"),
        HabitSymbolOption(name: "tree.fill", label: "Nature"),
        HabitSymbolOption(name: "gamecontroller.fill", label: "Gaming"),
        HabitSymbolOption(name: "film.fill", label: "Film"),
        HabitSymbolOption(name: "shippingbox.fill", label: "Shipping"),
        HabitSymbolOption(name: "scissors", label: "Trim"),
        HabitSymbolOption(name: "trash.fill", label: "Cleanup")
    ]

    static func label(for symbolName: String) -> String {
        all.first(where: { $0.name == symbolName })?.label ?? symbolName
    }
}

struct SymbolPickerView: View {
    @Binding var selection: String
    let accentColor: Color

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private let columns = [
        GridItem(.adaptive(minimum: 68, maximum: 88), spacing: 12)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(filteredOptions) { option in
                        Button {
                            selection = option.name
                            dismiss()
                        } label: {
                            VStack(spacing: 10) {
                                Image(systemName: option.name)
                                    .font(.system(size: 22, weight: .medium))
                                    .foregroundStyle(selection == option.name ? accentColor : .white)
                                    .frame(width: 36, height: 36)

                                Text(option.label)
                                    .font(.caption2.weight(.medium))
                                    .foregroundStyle(.white.opacity(0.88))
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 92)
                            .padding(.horizontal, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color.white.opacity(selection == option.name ? 0.12 : 0.05))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(selection == option.name ? accentColor : Color.white.opacity(0.08), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Choose Symbol")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search symbols")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var filteredOptions: [HabitSymbolOption] {
        let trimmedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSearch.isEmpty else { return HabitSymbolOption.all }

        return HabitSymbolOption.all.filter { option in
            option.label.localizedCaseInsensitiveContains(trimmedSearch)
                || option.name.localizedCaseInsensitiveContains(trimmedSearch)
        }
    }
}

#Preview {
    ContentView(
        storage: UserDefaults(suiteName: "TimekeeperPreview") ?? .standard,
        developerModeOverride: true,
        usePersistedDatasets: false
    )
}
