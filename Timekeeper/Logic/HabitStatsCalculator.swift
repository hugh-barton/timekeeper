import Foundation

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
        habitCompletionState(for: habit, dayKey: key, quantity: quantity)
    }

    private func progressRatio(for key: String, quantity: Int) -> Double {
        habitProgressRatio(for: habit, dayKey: key, quantity: quantity)
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
