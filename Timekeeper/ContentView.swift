import SwiftUI
import UniformTypeIdentifiers

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
