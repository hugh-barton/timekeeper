import SwiftUI
import Charts

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
