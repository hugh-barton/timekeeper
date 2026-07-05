import SwiftUI

private enum RewardCardKind {
    case dailyStreak
    case goalCounter
    case selfManaged

    var title: String {
        switch self {
        case .dailyStreak:
            "Daily Streak"
        case .goalCounter:
            "Goal Counter"
        case .selfManaged:
            "Self-Managed"
        }
    }
}

private struct RewardProgressDay: Identifiable {
    let date: Date
    let isFilled: Bool

    var id: Date { date }
}

struct RewardCard: View {
    let reward: Reward
    let habits: [Habit]
    let stampCount: Int
    let isHighlighted: Bool
    let isCelebrating: Bool
    let onTap: () -> Void
    let onRemoveStamp: () -> Void
    let onClaim: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    private let calendar = Calendar(identifier: .gregorian)

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            progressContent
            footer

            if isReadyToClaim {
                Button("Claim") {
                    onClaim()
                }
                .frame(maxWidth: .infinity)
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
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(cardFillColor)
        )
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 22)
                .fill(accentColor)
                .frame(width: 6)
                .padding(.vertical, 1)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(borderColor, lineWidth: isHighlighted || isCelebrating ? 2 : 1)
        )
        .scaleEffect(isCelebrating ? 1.02 : 1)
        .animation(.easeOut(duration: 0.2), value: isHighlighted)
        .animation(.spring(response: 0.4, dampingFraction: 0.72), value: isCelebrating)
        .contentShape(RoundedRectangle(cornerRadius: 22))
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

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 10) {
                Text(kind.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(accentColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(accentColor.opacity(0.18))
                    )

                VStack(alignment: .leading, spacing: 6) {
                    Text(reward.name)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)

                    if !reward.description.isEmpty {
                        Text(reward.description)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.68))
                            .lineLimit(2)
                    }
                }
            }

            Spacer(minLength: 12)

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
                        .foregroundStyle(.white.opacity(0.72))
                }

                VStack(alignment: .trailing, spacing: 3) {
                    Text("Reward")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.white.opacity(0.52))

                    HStack(spacing: 6) {
                        Image(systemName: "gift.fill")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(.white)

                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white.opacity(0.45))
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var progressContent: some View {
        switch kind {
        case .dailyStreak:
            VStack(alignment: .leading, spacing: 10) {
                Text("Last 5 Days")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)

                HStack(spacing: 12) {
                    ForEach(recentDayProgress) { day in
                        VStack(spacing: 8) {
                            Circle()
                                .fill(day.isFilled ? accentColor : Color.clear)
                                .frame(width: 18, height: 18)
                                .overlay(
                                    Circle()
                                        .stroke(day.isFilled ? accentColor : Color.white.opacity(0.22), lineWidth: 1.5)
                                )

                            Text(shortDateText(for: day.date))
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.white.opacity(0.62))
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        case .goalCounter:
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Progress")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)

                    Spacer()

                    Text(goalCounterText)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.86))
                }

                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.08))

                        Capsule()
                            .fill(accentColor)
                            .frame(width: max(proxy.size.width * goalProgressRatio, goalProgressRatio > 0 ? 8 : 0))
                    }
                }
                .frame(height: 12)
            }
        case .selfManaged:
            VStack(alignment: .leading, spacing: 10) {
                Text("Recent Stamps")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)

                HStack(spacing: 12) {
                    ForEach(0..<5, id: \.self) { index in
                        VStack(spacing: 8) {
                            if let stampDate = manualStampDisplayDates[safe: index] {
                                Button {
                                    onRemoveStamp()
                                } label: {
                                    Circle()
                                        .fill(accentColor)
                                        .frame(width: 18, height: 18)
                                        .overlay(
                                            Circle()
                                                .stroke(accentColor, lineWidth: 1.5)
                                        )
                                }
                                .buttonStyle(.plain)

                                Text(shortDateText(for: stampDate))
                                    .font(.caption2.weight(.medium))
                                    .foregroundStyle(.white.opacity(0.62))
                            } else {
                                Circle()
                                    .fill(Color.clear)
                                    .frame(width: 18, height: 18)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white.opacity(0.22), lineWidth: 1.5)
                                    )

                                Text("--/--")
                                    .font(.caption2.weight(.medium))
                                    .foregroundStyle(.white.opacity(0.28))
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }

    private var footer: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                if let linkedHabit {
                    Text(linkedHabit.name)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.58))
                }

                if let endDateText {
                    Text("Deadline \(endDateText)")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.48))
                }
            }

            Spacer()

            if stampCount > 0 {
                Button("Remove 1") {
                    onRemoveStamp()
                }
                .buttonStyle(.plain)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.72))
            }
        }
    }

    private var linkedHabit: Habit? {
        guard let linkedHabitID = reward.linkedHabitID else { return nil }
        return habits.first(where: { $0.id == linkedHabitID })
    }

    private var kind: RewardCardKind {
        guard let linkedHabit else { return .selfManaged }

        switch rewardResolvedProgressRule(for: reward, habit: linkedHabit) {
        case .completedDays:
            return .dailyStreak
        case .loggedQuantity, .goalMetDays:
            return .goalCounter
        case .automatic:
            return linkedHabit.goal != nil || linkedHabit.isTrackingEnabled ? .goalCounter : .dailyStreak
        }
    }

    private var isReadyToClaim: Bool {
        stampCount >= reward.stampTarget
    }

    private var accentColor: Color {
        linkedHabit?.color ?? .yellow
    }

    private var endDateText: String? {
        guard let endDate = reward.endDate else { return nil }
        return endDate.formatted(date: .abbreviated, time: .omitted)
    }

    private var cardFillColor: Color {
        if isCelebrating {
            return Color.yellow.opacity(0.2)
        }

        if isHighlighted {
            return accentColor.opacity(0.12)
        }

        return Color.white.opacity(0.06)
    }

    private var borderColor: Color {
        if isCelebrating || isHighlighted {
            return accentColor.opacity(0.88)
        }

        return Color.white.opacity(0.08)
    }

    private var goalProgressRatio: Double {
        guard reward.stampTarget > 0 else { return 0 }
        return min(Double(stampCount) / Double(reward.stampTarget), 1)
    }

    private var goalCounterText: String {
        let unit = linkedHabit?.goal?.unit ?? linkedHabit?.trackingUnit ?? "points"
        return "\(stampCount) / \(reward.stampTarget) \(unit)"
    }

    private var recentDayProgress: [RewardProgressDay] {
        guard let linkedHabit else { return [] }

        let today = calendar.startOfDay(for: Date())
        let startDate = calendar.startOfDay(for: reward.startDate)
        let completedKeys = rewardCompletedDayKeys(for: linkedHabit)

        return (-4...0).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: today) else { return nil }
            let key = dayKey(for: date)
            let isFilled = date >= startDate && completedKeys.contains(key)
            return RewardProgressDay(date: date, isFilled: isFilled)
        }
    }

    private var manualStampDisplayDates: [Date] {
        let startDate = calendar.startOfDay(for: reward.startDate)
        let dates = reward.manualStampEntries
            .flatMap { entry in
                Array(repeating: entry.stampedAt, count: max(entry.amount, 0))
            }
            .filter { calendar.startOfDay(for: $0) >= startDate }
            .sorted()

        return Array(dates.suffix(5))
    }

    private func dayKey(for day: Date) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: day)
        return "\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)"
    }

    private func shortDateText(for date: Date) -> String {
        date.formatted(.dateTime.day(.twoDigits).month(.twoDigits))
    }
}

struct CompletedRewardCard: View {
    let reward: Reward
    let linkedHabit: Habit?
    let onReactivate: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            RoundedRectangle(cornerRadius: 8)
                .fill((linkedHabit?.color ?? .yellow).opacity(0.9))
                .frame(width: 5)

            VStack(alignment: .leading, spacing: 6) {
                Text(reward.name)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)

                Text(completionText)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.64))
            }

            Spacer()

            Button("Reactivate") {
                onReactivate()
            }
            .buttonStyle(.plain)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(linkedHabit?.color ?? .yellow)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private var completionText: String {
        let date = reward.claimedAt ?? reward.claimDates.last ?? reward.startDate
        return "Completed \(date.formatted(date: .abbreviated, time: .omitted))"
    }
}

private extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
