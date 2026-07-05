import SwiftUI

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

            return habitCompletionState(for: habit, dayKey: key, quantity: progress(for: key))
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
