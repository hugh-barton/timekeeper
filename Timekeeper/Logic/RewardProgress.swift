import Foundation

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
    let quantitiesByDay = Dictionary(grouping: habit.timeEntries) {
        "\($0.year)-\($0.month)-\($0.day)"
    }
    let candidateKeys = habit.completedDays
        .union(quantitiesByDay.keys)
        .subtracting(restDayKeys)

    return Set(
        candidateKeys.filter { key in
            let quantity = quantitiesByDay[key]?.reduce(0) { $0 + $1.minutes } ?? 0
            return habitCompletionState(for: habit, dayKey: key, quantity: quantity)
        }
    )
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
