import SwiftUI

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
    let onReorder: () -> Void
    let onDelete: (UUID) -> Void

    @State private var isShowingTimeEntry = false
    @State private var isShowingHistory = false
    @State private var shouldMarkCompleteOnSave = false
    @State private var sessionMinutes = 0
    @State private var manualTimeInput = ""
    @State private var isCollapsed = false
    @State private var swipeOffset: CGFloat = 0
    @State private var swipeStartOffset: CGFloat = 0

    private let calendar = Calendar(identifier: .gregorian)
    private let swipeActionWidth: CGFloat = 156

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
        ZStack(alignment: .trailing) {
            if swipeOffset < 0 {
                restDaySwipeAction
            }

            cardContent
                .offset(x: swipeOffset)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
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

            Button {
                onReorder()
            } label: {
                Label("Reorder Habits", systemImage: "line.3.horizontal")
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
        .sheet(isPresented: $isShowingHistory) {
            HabitHistorySheet(habit: $habit, initialMonth: calendar.component(.month, from: Date()))
                .preferredColorScheme(.dark)
        }
    }

    private var cardContent: some View {
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
            .simultaneousGesture(cardSwipeGesture)

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
                .simultaneousGesture(cardSwipeGesture)
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
    }

    private var restDaySwipeAction: some View {
        Button {
            toggleTodayRest()
            closeSwipeAction()
        } label: {
            Label(
                isRestToday ? "Unmark Rest Day" : "Mark as Rest Day",
                systemImage: isRestToday ? "moon.fill" : "moon"
            )
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .frame(width: swipeActionWidth)
            .frame(maxHeight: .infinity)
            .background(Color.indigo)
        }
        .buttonStyle(.plain)
    }

    private var cardSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                guard abs(value.translation.width) > abs(value.translation.height) else { return }

                let proposedOffset = swipeStartOffset + value.translation.width
                swipeOffset = min(0, max(-swipeActionWidth, proposedOffset))
            }
            .onEnded { value in
                guard abs(value.translation.width) > abs(value.translation.height) else {
                    swipeStartOffset = swipeOffset
                    return
                }

                let projectedOffset = swipeStartOffset + value.predictedEndTranslation.width
                withAnimation(.easeOut(duration: 0.2)) {
                    swipeOffset = projectedOffset < -(swipeActionWidth / 2) ? -swipeActionWidth : 0
                }
                swipeStartOffset = swipeOffset
            }
    }

    private func closeSwipeAction() {
        withAnimation(.easeOut(duration: 0.2)) {
            swipeOffset = 0
        }
        swipeStartOffset = 0
    }

    private var isCompleteToday: Bool {
        habitCompletionState(for: habit, dayKey: todayKey, quantity: progress(for: todayKey))
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

        if habit.goal != nil {
            if isCompleteToday {
                clearTodayProgress()
            } else {
                shouldMarkCompleteOnSave = true
                isShowingTimeEntry = true
            }
        } else if habit.isTrackingEnabled {
            toggleTodayCompletion()
        } else {
            toggleTodayCompletion()
        }
    }

    private func saveTimeEntry() {
        let minutes = totalTimeEntryMinutes
        guard shouldMarkCompleteOnSave || minutes > 0 else { return }

        if minutes > 0 {
            habit.timeEntries.append(makeTimeEntry(minutes, activeUnitLabel, habit.goal?.dailyTarget))
        }

        if shouldMarkCompleteOnSave, habit.goal == nil {
            habit.completedDays.insert(todayKey)
        }

        updateGoalCompletionForToday()
        resetTimeEntrySession()
        shouldMarkCompleteOnSave = false
        isShowingTimeEntry = false
    }

    private func updateGoalCompletionForToday() {
        guard let goal = habit.goal else { return }

        if progress(for: todayKey) >= goal.dailyTarget {
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
        habitProgressRatio(for: habit, dayKey: key, quantity: progress(for: key))
    }

    private func entries(for key: String) -> [TimeEntry] {
        habit.timeEntries.filter { "\($0.year)-\($0.month)-\($0.day)" == key }
    }

    private func mondayBasedWeekdayIndex(for day: Date) -> Int {
        let weekday = Calendar(identifier: .gregorian).component(.weekday, from: day)
        return (weekday + 5) % 7
    }
}
