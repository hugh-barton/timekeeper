import SwiftUI
import UniformTypeIdentifiers

private struct RewardLinkedHabitLoggingSession: Identifiable {
    let rewardID: UUID
    let habitID: UUID
    let dataMode: DataMode

    var id: String {
        let modeID = switch dataMode {
        case .mock: "mock"
        case .real: "real"
        }
        return "\(rewardID.uuidString)-\(habitID.uuidString)-\(modeID)"
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
    @State private var newHabitReminder: HabitReminder?
    @State private var editingHabitID: UUID?
    @State private var isShowingReorderHabits = false
    @State private var draggedHabitID: UUID?
    @State private var isShowingAddReward = false
    @State private var newRewardName = ""
    @State private var newRewardDescription = ""
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
    @State private var linkedRewardLoggingSession: RewardLinkedHabitLoggingSession?
    @State private var linkedRewardShouldMarkCompleteOnSave = false
    @State private var linkedRewardSessionMinutes = 0
    @State private var linkedRewardManualInput = ""

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
                                        rewards: activeRewards,
                                        days: daysIn2026,
                                        expandedHeight: cardHeight,
                                        todayKey: dayKey(for: today),
                                        isFutureDay: { day in day > today },
                                        dayKey: dayKey(for:),
                                        makeRestDay: makeRestDay(day:),
                                        makeTimeEntry: makeTimeEntry(minutes:unitLabel:dailyTarget:),
                                        onEdit: editHabit(_:),
                                        onReorder: { isShowingReorderHabits = true },
                                        onDelete: deleteHabit(_:)
                                    )
                                    .onDrag {
                                        draggedHabitID = habit.id
                                        return NSItemProvider(object: habit.id.uuidString as NSString)
                                    }
                                    .onDrop(
                                        of: [UTType.text],
                                        delegate: HabitCardDropDelegate(
                                            destinationHabitID: habit.id,
                                            habits: activeHabitsBinding,
                                            draggedHabitID: $draggedHabitID
                                        )
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
                        reminder: $newHabitReminder,
                        title: editingHabitID == nil ? "New Habit" : "Edit Habit",
                        saveButtonTitle: editingHabitID == nil ? "Add" : "Save",
                        onCancel: cancelHabitModal,
                        onSave: saveHabit
                    )
                    .preferredColorScheme(.dark)
                }
                .sheet(isPresented: $isShowingReorderHabits) {
                    ReorderHabitsView(habits: activeHabits) { reorderedHabits in
                        setHabits(reorderedHabits, for: currentDataMode)
                    }
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
                newRewardDescription: $newRewardDescription,
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
                onRemoveStamp: removeRewardStamp(_:),
                onConfirmBulkStamp: confirmBulkStamp,
                onClaimReward: claimReward(_:),
                onRestoreReward: restoreReward(_:)
            )
            .sheet(item: $linkedRewardLoggingSession) { session in
                if let habitBinding = habitBinding(for: session.habitID, in: session.dataMode) {
                    TimeEntryView(
                        habitName: habitBinding.wrappedValue.name,
                        unitLabel: habitBinding.wrappedValue.goal?.unit ?? habitBinding.wrappedValue.trackingUnit,
                        loggedTodayValue: loggedQuantityToday(for: habitBinding.wrappedValue),
                        title: "Log Progress",
                        placeholder: (habitBinding.wrappedValue.goal?.unit ?? habitBinding.wrappedValue.trackingUnit).capitalized,
                        manualTimeInput: $linkedRewardManualInput,
                        sessionMinutes: $linkedRewardSessionMinutes,
                        allowsEmptySave: linkedRewardShouldMarkCompleteOnSave,
                        onClear: linkedRewardClearAction(for: session),
                        onCancel: cancelLinkedRewardLogging,
                        onSave: saveLinkedRewardEntry
                    )
                    .preferredColorScheme(.dark)
                }
            }
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
        newHabitReminder = habit.reminder
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
        let savedHabit: Habit

        if let editingHabitID, let habitIndex = updatedHabits.firstIndex(where: { $0.id == editingHabitID }) {
            updatedHabits[habitIndex].name = trimmedName
            updatedHabits[habitIndex].symbolName = newHabitSymbolName
            updatedHabits[habitIndex].color = newHabitColor
            updatedHabits[habitIndex].isTrackingEnabled = isTrackingEnabled
            updatedHabits[habitIndex].trackingUnit = trackingUnit
            updatedHabits[habitIndex].goal = goal
            updatedHabits[habitIndex].reminder = newHabitReminder
            savedHabit = updatedHabits[habitIndex]
        } else {
            savedHabit = Habit(
                name: trimmedName,
                symbolName: newHabitSymbolName,
                color: newHabitColor,
                isTrackingEnabled: isTrackingEnabled,
                trackingUnit: trackingUnit,
                goal: goal,
                reminder: newHabitReminder
            )
            updatedHabits.append(savedHabit)
        }

        setHabits(updatedHabits, for: dataMode)
        Task {
            await HabitNotificationScheduler.scheduleReminder(for: savedHabit)
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
        newHabitReminder = nil
        editingHabitID = nil
    }

    private func cancelHabitModal() {
        resetNewHabit()
        isShowingAddHabit = false
    }

    private func deleteHabit(_ habitID: UUID) {
        HabitNotificationScheduler.cancelReminders(for: habitID)

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
        newRewardDescription = reward.description
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
        let trimmedDescription = newRewardDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        let target = Int(newRewardTarget.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0

        guard !trimmedName.isEmpty, target > 0 else { return }

        let dataMode = currentDataMode
        var updatedRewards = rewards(for: dataMode)

        if let editingRewardID, let rewardIndex = updatedRewards.firstIndex(where: { $0.id == editingRewardID }) {
            updatedRewards[rewardIndex].name = trimmedName
            updatedRewards[rewardIndex].description = trimmedDescription
            updatedRewards[rewardIndex].stampTarget = target
            updatedRewards[rewardIndex].linkedHabitID = newRewardLinkedHabitID
            updatedRewards[rewardIndex].startDate = calendar.startOfDay(for: newRewardStartDate)
            updatedRewards[rewardIndex].endDate = newRewardHasDeadline ? calendar.startOfDay(for: newRewardEndDate) : nil
            updatedRewards[rewardIndex].linkedProgressRule = newRewardLinkedHabitID == nil ? .automatic : newRewardProgressRule
        } else {
            updatedRewards.append(
                Reward(
                    name: trimmedName,
                    description: trimmedDescription,
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
        newRewardDescription = ""
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

        if reward.linkedHabitID != nil {
            openLinkedRewardLogging(for: reward, in: dataMode)
            return
        }

        guard rewardStampCount(for: reward, habits: habits(for: dataMode)) < reward.stampTarget else { return }

        if reward.stampTarget > 10 {
            bulkStampAmount = ""
            selectedBulkStampRewardID = reward.id
            return
        }

        addManualStamps(to: reward.id, amount: 1, in: dataMode)
    }

    private func removeRewardStamp(_ reward: Reward) {
        let dataMode = currentDataMode

        if reward.linkedHabitID == nil {
            var updatedRewards = rewards(for: dataMode)
            guard let rewardIndex = updatedRewards.firstIndex(where: { $0.id == reward.id }) else { return }
            guard removeOneManualRewardStamp(from: &updatedRewards[rewardIndex]) else { return }
            setRewards(updatedRewards, for: dataMode)
            return
        }

        guard let linkedHabitID = reward.linkedHabitID else { return }
        var updatedHabits = habits(for: dataMode)
        guard let habitIndex = updatedHabits.firstIndex(where: { $0.id == linkedHabitID }) else { return }
        guard removeOneLinkedRewardStamp(from: reward, habit: &updatedHabits[habitIndex]) else { return }
        setHabits(updatedHabits, for: dataMode)
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
        highlightReward(rewardID)
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
        updatedRewards[rewardIndex].startDate = calendar.startOfDay(for: today)
        setRewards(updatedRewards, for: dataMode)
    }

    private func openLinkedRewardLogging(for reward: Reward, in dataMode: DataMode) {
        guard let linkedHabitID = reward.linkedHabitID else { return }
        guard let habit = habits(for: dataMode).first(where: { $0.id == linkedHabitID }) else { return }

        linkedRewardManualInput = ""
        linkedRewardSessionMinutes = 0
        linkedRewardShouldMarkCompleteOnSave = habit.goal == nil
        linkedRewardLoggingSession = RewardLinkedHabitLoggingSession(
            rewardID: reward.id,
            habitID: linkedHabitID,
            dataMode: dataMode
        )
    }

    private func saveLinkedRewardEntry() {
        guard let session = linkedRewardLoggingSession else { return }

        let totalMinutes = linkedRewardTotalMinutes
        guard linkedRewardShouldMarkCompleteOnSave || totalMinutes > 0 else { return }

        var updatedHabits = habits(for: session.dataMode)
        guard let habitIndex = updatedHabits.firstIndex(where: { $0.id == session.habitID }) else { return }

        let todayKey = dayKey(for: today)

        if totalMinutes > 0 {
            updatedHabits[habitIndex].timeEntries.append(
                makeTimeEntry(
                    minutes: totalMinutes,
                    unitLabel: updatedHabits[habitIndex].goal?.unit ?? updatedHabits[habitIndex].trackingUnit,
                    dailyTarget: updatedHabits[habitIndex].goal?.dailyTarget
                )
            )
        }

        if linkedRewardShouldMarkCompleteOnSave && updatedHabits[habitIndex].goal == nil {
            updatedHabits[habitIndex].completedDays.insert(todayKey)
        }

        updateGoalCompletion(for: &updatedHabits[habitIndex], dayKey: todayKey)
        setHabits(updatedHabits, for: session.dataMode)
        resetLinkedRewardLoggingSession()
        highlightReward(session.rewardID)
    }

    private func cancelLinkedRewardLogging() {
        resetLinkedRewardLoggingSession()
    }

    private func linkedRewardClearAction(for session: RewardLinkedHabitLoggingSession) -> (() -> Void)? {
        canClearLinkedRewardProgressToday(for: session) ? { clearLinkedRewardProgressToday(for: session) } : nil
    }

    private func canClearLinkedRewardProgressToday(for session: RewardLinkedHabitLoggingSession) -> Bool {
        guard let habit = habits(for: session.dataMode).first(where: { $0.id == session.habitID }) else { return false }
        let todayKey = dayKey(for: today)
        let progress = habit.timeEntries
            .filter { "\($0.year)-\($0.month)-\($0.day)" == todayKey }
            .reduce(0) { $0 + $1.minutes }
        return progress > 0 || habit.completedDays.contains(todayKey)
    }

    private func clearLinkedRewardProgressToday(for session: RewardLinkedHabitLoggingSession) {
        var updatedHabits = habits(for: session.dataMode)
        guard let habitIndex = updatedHabits.firstIndex(where: { $0.id == session.habitID }) else { return }

        let todayKey = dayKey(for: today)
        updatedHabits[habitIndex].completedDays.remove(todayKey)
        updatedHabits[habitIndex].timeEntries.removeAll { "\($0.year)-\($0.month)-\($0.day)" == todayKey }
        setHabits(updatedHabits, for: session.dataMode)
        resetLinkedRewardLoggingSession()
    }

    private var linkedRewardTotalMinutes: Int {
        let trimmedInput = linkedRewardManualInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let manualMinutes = Int((Double(trimmedInput) ?? 0).rounded())
        return linkedRewardSessionMinutes + max(manualMinutes, 0)
    }

    private func resetLinkedRewardLoggingSession() {
        linkedRewardManualInput = ""
        linkedRewardSessionMinutes = 0
        linkedRewardShouldMarkCompleteOnSave = false
        linkedRewardLoggingSession = nil
    }

    private func loggedQuantityToday(for habit: Habit) -> Int {
        let todayKey = dayKey(for: today)
        return habit.timeEntries
            .filter { "\($0.year)-\($0.month)-\($0.day)" == todayKey }
            .reduce(0) { $0 + $1.minutes }
    }

    private func habitBinding(for habitID: UUID, in dataMode: DataMode) -> Binding<Habit>? {
        guard habits(for: dataMode).contains(where: { $0.id == habitID }) else { return nil }

        return Binding(
            get: {
                habits(for: dataMode).first(where: { $0.id == habitID })!
            },
            set: { updatedHabit in
                var updatedHabits = habits(for: dataMode)
                guard let habitIndex = updatedHabits.firstIndex(where: { $0.id == habitID }) else { return }
                updatedHabits[habitIndex] = updatedHabit
                setHabits(updatedHabits, for: dataMode)
            }
        )
    }

    private func highlightReward(_ rewardID: UUID) {
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
        isShowingReorderHabits = false
        draggedHabitID = nil
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

private struct HabitCardDropDelegate: DropDelegate {
    let destinationHabitID: UUID
    @Binding var habits: [Habit]
    @Binding var draggedHabitID: UUID?

    func dropEntered(info: DropInfo) {
        guard
            let draggedHabitID,
            draggedHabitID != destinationHabitID,
            let sourceIndex = habits.firstIndex(where: { $0.id == draggedHabitID }),
            let destinationIndex = habits.firstIndex(where: { $0.id == destinationHabitID })
        else { return }

        withAnimation(.easeInOut(duration: 0.2)) {
            habits.move(
                fromOffsets: IndexSet(integer: sourceIndex),
                toOffset: destinationIndex > sourceIndex ? destinationIndex + 1 : destinationIndex
            )
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggedHabitID = nil
        return true
    }
}

#Preview {
    ContentView(
        storage: UserDefaults(suiteName: "TimekeeperPreview") ?? .standard,
        developerModeOverride: true,
        usePersistedDatasets: false
    )
}
