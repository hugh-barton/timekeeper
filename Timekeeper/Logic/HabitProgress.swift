import Foundation

func habitCompletionState(for habit: Habit, dayKey: String, quantity: Int) -> Bool {
    if let goal = habit.goal {
        return goal.dailyTarget > 0 && quantity >= goal.dailyTarget
    }

    if habit.isTrackingEnabled {
        return habit.completedDays.contains(dayKey)
    }

    return habit.completedDays.contains(dayKey)
}

func habitProgressRatio(for habit: Habit, dayKey: String, quantity: Int) -> Double {
    if let goal = habit.goal {
        guard goal.dailyTarget > 0 else { return 0 }
        return min(Double(quantity) / Double(goal.dailyTarget), 1)
    }

    if habit.isTrackingEnabled {
        return quantity > 0 || habit.completedDays.contains(dayKey) ? 1 : 0
    }

    return habitCompletionState(for: habit, dayKey: dayKey, quantity: quantity) ? 1 : 0
}
