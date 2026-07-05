import Foundation

func rewardStampCount(for reward: Reward, habits: [Habit]) -> Int {
    let calendar = Calendar(identifier: .gregorian)
    let rewardStartDate = reward.startDate

    guard let linkedHabitID = reward.linkedHabitID else {
        return reward.manualStampEntries.reduce(0) { partialResult, entry in
            entry.stampedAt >= rewardStartDate ? partialResult + entry.amount : partialResult
        }
    }

    return habits.first(where: { $0.id == linkedHabitID }).map {
        linkedRewardProgress(for: $0, startDate: rewardStartDate, rule: reward.linkedProgressRule, calendar: calendar)
    } ?? 0
}

func rewardResolvedProgressRule(for reward: Reward, habit: Habit) -> RewardProgressRule {
    reward.linkedProgressRule == .automatic
        ? (habit.isTrackingEnabled ? .loggedQuantity : .completedDays)
        : reward.linkedProgressRule
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
            entry.loggedAt >= startDate ? partialResult + entry.minutes : partialResult
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

func removeOneManualRewardStamp(
    from reward: inout Reward,
    calendar: Calendar = Calendar(identifier: .gregorian)
) -> Bool {
    let startDate = reward.startDate
    let eligibleIndices = reward.manualStampEntries.indices.filter { index in
        let entry = reward.manualStampEntries[index]
        return entry.stampedAt >= startDate && entry.amount > 0
    }
    guard let latestIndex = eligibleIndices.max(by: { lhs, rhs in
        reward.manualStampEntries[lhs].stampedAt < reward.manualStampEntries[rhs].stampedAt
    }) else {
        return false
    }

    let entry = reward.manualStampEntries[latestIndex]
    if entry.amount <= 1 {
        reward.manualStampEntries.remove(at: latestIndex)
    } else {
        reward.manualStampEntries[latestIndex] = RewardStampEntry(
            id: entry.id,
            stampedAt: entry.stampedAt,
            amount: entry.amount - 1
        )
    }

    return true
}

func removeOneLinkedRewardStamp(
    from reward: Reward,
    habit: inout Habit,
    calendar: Calendar = Calendar(identifier: .gregorian)
) -> Bool {
    let startDate = calendar.startOfDay(for: reward.startDate)

    switch rewardResolvedProgressRule(for: reward, habit: habit) {
    case .automatic:
        return false
    case .loggedQuantity:
        return removeOneLoggedUnit(from: &habit, startDate: startDate, calendar: calendar)
    case .completedDays:
        if habit.goal != nil {
            return removeOneGoalMetStamp(from: &habit, startDate: startDate, calendar: calendar)
        }
        return removeOneCompletedDayStamp(from: &habit, startDate: startDate, calendar: calendar)
    case .goalMetDays:
        return removeOneGoalMetStamp(from: &habit, startDate: startDate, calendar: calendar)
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

private func removeOneLoggedUnit(
    from habit: inout Habit,
    startDate: Date,
    calendar: Calendar
) -> Bool {
    let eligibleIndices = habit.timeEntries.indices.filter { index in
        habit.timeEntries[index].loggedAt >= startDate
    }
    guard let latestIndex = eligibleIndices.max(by: { lhs, rhs in
        habit.timeEntries[lhs].loggedAt < habit.timeEntries[rhs].loggedAt
    }) else {
        return false
    }

    let entry = habit.timeEntries[latestIndex]
    let key = rewardDayKey(for: entry.loggedAt, calendar: calendar)
    if entry.minutes <= 1 {
        habit.timeEntries.remove(at: latestIndex)
    } else {
        habit.timeEntries[latestIndex] = TimeEntry(
            id: entry.id,
            loggedAt: entry.loggedAt,
            year: entry.year,
            month: entry.month,
            day: entry.day,
            minutes: entry.minutes - 1,
            unitLabel: entry.unitLabel,
            dailyTarget: entry.dailyTarget
        )
    }

    updateGoalCompletion(for: &habit, dayKey: key)
    return true
}

private func removeOneCompletedDayStamp(
    from habit: inout Habit,
    startDate: Date,
    calendar: Calendar
) -> Bool {
    let latestEligibleKey = rewardCompletedDayKeys(for: habit)
        .compactMap { key -> (String, Date)? in
            guard let date = rewardDate(from: key, calendar: calendar), date >= startDate else { return nil }
            return (key, date)
        }
        .max { lhs, rhs in lhs.1 < rhs.1 }?
        .0

    guard let latestEligibleKey else { return false }
    habit.completedDays.remove(latestEligibleKey)
    return true
}

private func removeOneGoalMetStamp(
    from habit: inout Habit,
    startDate: Date,
    calendar: Calendar
) -> Bool {
    guard let goal = habit.goal else { return false }

    let quantitiesByDay = Dictionary(grouping: habit.timeEntries) { entry in
        rewardDayKey(for: entry.loggedAt, calendar: calendar)
    }
    let latestEligibleKey = quantitiesByDay.compactMap { key, entries -> (String, Date)? in
        guard
            let date = rewardDate(from: key, calendar: calendar),
            date >= startDate,
            entries.reduce(0, { $0 + $1.minutes }) >= goal.dailyTarget
        else {
            return nil
        }
        return (key, date)
    }
    .max { lhs, rhs in lhs.1 < rhs.1 }?
    .0

    guard let latestEligibleKey else { return false }

    let currentQuantity = quantitiesByDay[latestEligibleKey]?.reduce(0) { $0 + $1.minutes } ?? 0
    let quantityToRemove = currentQuantity - max(goal.dailyTarget - 1, 0)
    guard quantityToRemove > 0 else { return false }

    let didRemove = removeLoggedQuantity(
        quantityToRemove,
        from: &habit,
        on: latestEligibleKey,
        calendar: calendar
    )
    updateGoalCompletion(for: &habit, dayKey: latestEligibleKey)
    return didRemove
}

private func removeLoggedQuantity(
    _ quantityToRemove: Int,
    from habit: inout Habit,
    on dayKey: String,
    calendar: Calendar
) -> Bool {
    var remainingQuantity = quantityToRemove
    let indices = habit.timeEntries.indices
        .filter { index in rewardDayKey(for: habit.timeEntries[index].loggedAt, calendar: calendar) == dayKey }
        .sorted(by: >)

    guard !indices.isEmpty else { return false }

    for index in indices {
        guard remainingQuantity > 0 else { break }

        let entry = habit.timeEntries[index]
        if entry.minutes <= remainingQuantity {
            remainingQuantity -= entry.minutes
            habit.timeEntries.remove(at: index)
        } else {
            habit.timeEntries[index] = TimeEntry(
                id: entry.id,
                loggedAt: entry.loggedAt,
                year: entry.year,
                month: entry.month,
                day: entry.day,
                minutes: entry.minutes - remainingQuantity,
                unitLabel: entry.unitLabel,
                dailyTarget: entry.dailyTarget
            )
            remainingQuantity = 0
        }
    }

    return remainingQuantity == 0
}

private func rewardDayKey(for day: Date, calendar: Calendar) -> String {
    let components = calendar.dateComponents([.year, .month, .day], from: day)
    return "\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)"
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
    let startDate = reward.startDate
    var entries: [RewardHistoryEntry] = reward.manualStampEntries.compactMap { entry in
        guard entry.stampedAt >= startDate else { return nil }
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
                guard entry.loggedAt >= startDate else { return nil }
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
