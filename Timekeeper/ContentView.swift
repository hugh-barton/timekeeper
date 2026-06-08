//
//  ContentView.swift
//  Timekeeper
//
//  Created by Hugh Barton on 1/6/2026.
//

import Charts
import SwiftUI

struct Habit: Identifiable {
    let id: UUID
    var name: String
    var symbolName: String
    var color: Color
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

struct Reward: Identifiable {
    let id: UUID
    var name: String
    var stampTarget: Int
    var linkedHabitID: UUID?
    var startDate: Date
    var endDate: Date?
    var manualStampEntries: [RewardStampEntry]
    var isArchived: Bool

    init(
        id: UUID = UUID(),
        name: String,
        stampTarget: Int,
        linkedHabitID: UUID? = nil,
        startDate: Date = Date(),
        endDate: Date? = nil,
        manualStampEntries: [RewardStampEntry] = [],
        isArchived: Bool = false
    ) {
        self.id = id
        self.name = name
        self.stampTarget = stampTarget
        self.linkedHabitID = linkedHabitID
        self.startDate = startDate
        self.endDate = endDate
        self.manualStampEntries = manualStampEntries
        self.isArchived = isArchived
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
        linkedRewardProgress(for: $0, startDate: rewardStartDate, calendar: calendar)
    } ?? 0
}

func linkedRewardProgress(for habit: Habit, startDate: Date, calendar: Calendar = Calendar(identifier: .gregorian)) -> Int {
    if habit.isTrackingEnabled {
        return habit.timeEntries.reduce(0) { partialResult, entry in
            let entryDate = calendar.startOfDay(for: entry.loggedAt)
            return entryDate >= startDate ? partialResult + entry.minutes : partialResult
        }
    }

    return habit.completedDays.reduce(0) { partialResult, key in
        guard let day = rewardDate(from: key, calendar: calendar) else { return partialResult }
        return day >= startDate ? partialResult + 1 : partialResult
    }
}

func rewardDate(from dayKey: String, calendar: Calendar = Calendar(identifier: .gregorian)) -> Date? {
    let parts = dayKey.split(separator: "-").compactMap { Int($0) }
    guard parts.count == 3 else { return nil }

    return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
}

struct MockData {
    static let habits: [Habit] = {
        let calendar = Calendar(identifier: .gregorian)
        let specs: [(id: UUID, name: String, symbolName: String, color: Color, isTrackingEnabled: Bool, trackingUnit: String, goal: HabitGoal?, seed: UInt64)] = [
            (UUID(uuidString: "11111111-1111-1111-1111-111111111111")!, "Strength", "dumbbell.fill", .red, false, "", nil, 11),
            (UUID(uuidString: "22222222-2222-2222-2222-222222222222")!, "Reading", "book.closed.fill", .green, true, "pages", nil, 22),
            (UUID(uuidString: "33333333-3333-3333-3333-333333333333")!, "Meditation", "brain.head.profile", .purple, false, "", nil, 33),
            (UUID(uuidString: "44444444-4444-4444-4444-444444444444")!, "Running", "figure.run", .blue, true, "km", HabitGoal(unit: "km", dailyTarget: 5), 44)
        ]

        guard
            let startDate = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1)),
            let endDate = calendar.date(from: DateComponents(year: 2026, month: 6, day: 2))
        else { return [] }

        return specs.map { spec in
            var generator = SeededGenerator(seed: spec.seed)
            var completedDays = Set<String>()
            var restDays: [RestDay] = []
            var timeEntries: [TimeEntry] = []
            var currentDate = startDate

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
                isTrackingEnabled: spec.isTrackingEnabled,
                trackingUnit: spec.trackingUnit,
                goal: spec.goal,
                completedDays: completedDays,
                restDays: restDays,
                timeEntries: timeEntries
            )
        }
    }()

    private static func dayKey(for day: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: day)
        return "\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)"
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
    @State private var habits: [Habit] = MockData.habits
    @State private var rewards: [Reward] = []
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
    @State private var selectedBulkStampRewardID: UUID?
    @State private var bulkStampAmount = ""
    @State private var highlightedRewardID: UUID?
    @State private var celebratingRewardID: UUID?

    private let calendar = Calendar(identifier: .gregorian)

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
                                ForEach($habits) { $habit in
                                    HabitRow(
                                        habit: $habit,
                                        days: daysIn2026,
                                        todayKey: dayKey(for: today),
                                        isFutureDay: { day in day > today },
                                        dayKey: dayKey(for:),
                                        makeRestDay: makeRestDay(day:),
                                        makeTimeEntry: makeTimeEntry(minutes:unitLabel:dailyTarget:),
                                        onEdit: editHabit(_:),
                                        onDelete: deleteHabit(_:)
                                    )
                                    .frame(height: cardHeight)
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

            StatsView(habits: habits, rewards: rewards)
                .tabItem {
                    Label("Stats", systemImage: "chart.bar")
                }

            RewardsView(
                rewards: $rewards,
                habits: habits,
                isShowingAddReward: $isShowingAddReward,
                newRewardName: $newRewardName,
                newRewardTarget: $newRewardTarget,
                newRewardLinkedHabitID: $newRewardLinkedHabitID,
                newRewardStartDate: $newRewardStartDate,
                newRewardHasCustomStartDate: $newRewardHasCustomStartDate,
                newRewardEndDate: $newRewardEndDate,
                newRewardHasDeadline: $newRewardHasDeadline,
                selectedBulkStampRewardID: $selectedBulkStampRewardID,
                bulkStampAmount: $bulkStampAmount,
                highlightedRewardID: $highlightedRewardID,
                celebratingRewardID: $celebratingRewardID,
                onStartAddingReward: startAddingReward,
                onCancelRewardModal: cancelRewardModal,
                onSaveReward: saveReward,
                onRewardTap: handleRewardTap(_:),
                onConfirmBulkStamp: confirmBulkStamp,
                onClaimReward: claimReward(_:)
            )
            .tabItem {
                Label("Rewards", systemImage: "gift.fill")
            }
        }
        .preferredColorScheme(.dark)
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

        if let editingHabitID, let habitIndex = habits.firstIndex(where: { $0.id == editingHabitID }) {
            habits[habitIndex].name = trimmedName
            habits[habitIndex].symbolName = newHabitSymbolName
            habits[habitIndex].color = newHabitColor
            habits[habitIndex].isTrackingEnabled = isTrackingEnabled
            habits[habitIndex].trackingUnit = trackingUnit
            habits[habitIndex].goal = goal
        } else {
            habits.append(
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
        habits.removeAll { $0.id == habitID }
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

    private func saveReward() {
        let trimmedName = newRewardName.trimmingCharacters(in: .whitespacesAndNewlines)
        let target = Int(newRewardTarget.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0

        guard !trimmedName.isEmpty, target > 0 else { return }

        rewards.append(
            Reward(
                name: trimmedName,
                stampTarget: target,
                linkedHabitID: newRewardLinkedHabitID,
                startDate: calendar.startOfDay(for: newRewardStartDate),
                endDate: newRewardHasDeadline ? calendar.startOfDay(for: newRewardEndDate) : nil
            )
        )

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
    }

    private func cancelRewardModal() {
        resetNewReward()
        isShowingAddReward = false
    }

    private func handleRewardTap(_ reward: Reward) {
        guard reward.linkedHabitID == nil else { return }
        guard rewardStampCount(for: reward, habits: habits) < reward.stampTarget else { return }

        if reward.stampTarget > 10 {
            bulkStampAmount = ""
            selectedBulkStampRewardID = reward.id
            return
        }

        addManualStamps(to: reward.id, amount: 1)
    }

    private func confirmBulkStamp() {
        let amount = Int(bulkStampAmount.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
        guard let selectedBulkStampRewardID, amount > 0 else { return }

        addManualStamps(to: selectedBulkStampRewardID, amount: amount)
        bulkStampAmount = ""
        self.selectedBulkStampRewardID = nil
    }

    private func addManualStamps(to rewardID: UUID, amount: Int) {
        guard let rewardIndex = rewards.firstIndex(where: { $0.id == rewardID }) else { return }

        rewards[rewardIndex].manualStampEntries.append(RewardStampEntry(amount: amount))
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
        guard rewardStampCount(for: reward, habits: habits) >= reward.stampTarget else { return }

        withAnimation(.spring(response: 0.42, dampingFraction: 0.7)) {
            celebratingRewardID = reward.id
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            guard let rewardIndex = rewards.firstIndex(where: { $0.id == reward.id }) else { return }

            withAnimation(.easeInOut(duration: 0.28)) {
                rewards[rewardIndex].isArchived = true
            }

            celebratingRewardID = nil
        }
    }
}

struct HabitRow: View {
    @Binding var habit: Habit

    let days: [Date]
    let todayKey: String
    let isFutureDay: (Date) -> Bool
    let dayKey: (Date) -> String
    let makeRestDay: (Date) -> RestDay
    let makeTimeEntry: (Int, String, Int?) -> TimeEntry
    let onEdit: (Habit) -> Void
    let onDelete: (UUID) -> Void

    @State private var isShowingTimeEntry = false
    @State private var shouldMarkCompleteOnSave = false
    @State private var sessionMinutes = 0
    @State private var manualTimeInput = ""

    private let squareSize: CGFloat = 10
    private let squareSpacing: CGFloat = 4
    private let checkboxSize: CGFloat = 30
    private let saveButtonSize: CGFloat = 30

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: habit.symbolName)
                    .font(.body.weight(.medium))
                    .foregroundStyle(habit.color)
                    .frame(width: 18)

                Text(habit.name)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(alignment: .center, spacing: 12) {
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

                VStack(alignment: .trailing, spacing: 8) {
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
                                .font(.caption.weight(.bold))
                                .frame(width: saveButtonSize, height: saveButtonSize)
                        }
                        .buttonStyle(.bordered)
                        .accessibilityLabel("Log progress for \(habit.name)")
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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

            Button(role: .destructive) {
                onDelete(habit.id)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
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
            Color.gray.opacity(0.5)
        } else if progressRatio > 0 && !isFutureDay(day) {
            habit.color.opacity(progressRatio)
        } else {
            Color.white.opacity(0.12)
        }

        return RoundedRectangle(cornerRadius: 2)
            .fill(fillColor)
            .frame(width: squareSize, height: squareSize)
            .overlay(
                RoundedRectangle(cornerRadius: 2)
                    .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
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

    var totalQuantity: Int {
        elapsedDays.reduce(0) { $0 + $1.quantity }
    }

    var eligibleDayCount: Int {
        elapsedDays.filter(\.isEligible).count
    }

    var completedDayCount: Int {
        elapsedDays.filter { $0.isEligible && $0.isCompleted }.count
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
        let isEligible = date <= cappedEndDate && !isRestDay
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
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            RoundedRectangle(cornerRadius: squareSize * 0.22)
                .fill(fillColor)
                .frame(width: squareSize, height: squareSize)
                .overlay(
                    RoundedRectangle(cornerRadius: squareSize * 0.22)
                        .stroke(Color.white.opacity(0.09), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private var fillColor: Color {
        if day.date > Date() {
            return Color.white.opacity(0.05)
        }

        if day.isRestDay {
            return Color.gray.opacity(0.55)
        }

        if day.progressRatio > 0 {
            return habit.color.opacity(max(day.progressRatio, 0.2))
        }

        return Color.white.opacity(0.12)
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
    @Binding var isShowingAddReward: Bool
    @Binding var newRewardName: String
    @Binding var newRewardTarget: String
    @Binding var newRewardLinkedHabitID: UUID?
    @Binding var newRewardStartDate: Date
    @Binding var newRewardHasCustomStartDate: Bool
    @Binding var newRewardEndDate: Date
    @Binding var newRewardHasDeadline: Bool
    @Binding var selectedBulkStampRewardID: UUID?
    @Binding var bulkStampAmount: String
    @Binding var highlightedRewardID: UUID?
    @Binding var celebratingRewardID: UUID?

    let onStartAddingReward: () -> Void
    let onCancelRewardModal: () -> Void
    let onSaveReward: () -> Void
    let onRewardTap: (Reward) -> Void
    let onConfirmBulkStamp: () -> Void
    let onClaimReward: (Reward) -> Void

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
                                    onClaim: { onClaimReward(reward) }
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
                    habits: habits,
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

    let habits: [Habit]
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
            }
            .scrollContentBackground(.hidden)
            .background(Color.black)
            .navigationTitle("New Reward")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
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
                    } else {
                        Text("Tap to add stamps")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.62))
                    }
                }

                Spacer()

                if reward.stampTarget > 10 {
                    Text("\(stampCount) / \(reward.stampTarget)")
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(progressColor)
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
        var currentDay = startOfYear

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
    ContentView()
}
