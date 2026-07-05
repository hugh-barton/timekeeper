//
//  TimekeeperTests.swift
//  TimekeeperTests
//
//  Created by Hugh Barton on 1/6/2026.
//

import Foundation
import SwiftUI
import Testing
@testable import Timekeeper

struct TimekeeperTests {
    @MainActor @Test func linkedRewardUsesCompletionsFromStartDateForward() async throws {
        let habitID = UUID()
        let habit = Habit(
            id: habitID,
            name: "Reading",
            color: .green,
            completedDays: ["2026-6-1", "2026-6-2", "2026-6-3", "2026-6-4"]
        )
        let reward = Reward(
            name: "New Book",
            stampTarget: 10,
            linkedHabitID: habitID,
            startDate: Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: 6, day: 3))!
        )

        #expect(rewardStampCount(for: reward, habits: [habit]) == 2)
    }

    @MainActor @Test func linkedRewardUsesLoggedQuantityFromStartDateForward() async throws {
        let calendar = Calendar(identifier: .gregorian)
        let habitID = UUID()
        let habit = Habit(
            id: habitID,
            name: "Reading",
            color: .green,
            isTrackingEnabled: true,
            trackingUnit: "pages",
            timeEntries: [
                TimeEntry(
                    loggedAt: calendar.date(from: DateComponents(year: 2026, month: 6, day: 7))!,
                    year: 2026,
                    month: 6,
                    day: 7,
                    minutes: 50,
                    unitLabel: "pages"
                ),
                TimeEntry(
                    loggedAt: calendar.date(from: DateComponents(year: 2026, month: 6, day: 8))!,
                    year: 2026,
                    month: 6,
                    day: 8,
                    minutes: 25,
                    unitLabel: "pages"
                )
            ]
        )
        let reward = Reward(
            name: "Buy a Novel",
            stampTarget: 100,
            linkedHabitID: habitID,
            startDate: calendar.date(from: DateComponents(year: 2026, month: 6, day: 8))!
        )

        #expect(rewardStampCount(for: reward, habits: [habit]) == 25)
    }

    @MainActor @Test func linkedRewardCanCountCompletedDaysForTrackedHabit() async throws {
        let calendar = Calendar(identifier: .gregorian)
        let habitID = UUID()
        let habit = Habit(
            id: habitID,
            name: "Reading",
            color: .green,
            isTrackingEnabled: true,
            trackingUnit: "pages",
            completedDays: ["2026-6-7", "2026-6-8"],
            timeEntries: [
                TimeEntry(
                    loggedAt: calendar.date(from: DateComponents(year: 2026, month: 6, day: 8))!,
                    year: 2026,
                    month: 6,
                    day: 8,
                    minutes: 50,
                    unitLabel: "pages"
                ),
                TimeEntry(
                    loggedAt: calendar.date(from: DateComponents(year: 2026, month: 6, day: 9))!,
                    year: 2026,
                    month: 6,
                    day: 9,
                    minutes: 10,
                    unitLabel: "pages"
                )
            ]
        )
        let reward = Reward(
            name: "Buy a Novel",
            stampTarget: 10,
            linkedHabitID: habitID,
            startDate: calendar.date(from: DateComponents(year: 2026, month: 6, day: 1))!,
            linkedProgressRule: .completedDays
        )

        #expect(rewardStampCount(for: reward, habits: [habit]) == 2)
    }

    @MainActor @Test func linkedRewardCanCountGoalMetDays() async throws {
        let calendar = Calendar(identifier: .gregorian)
        let habitID = UUID()
        let habit = Habit(
            id: habitID,
            name: "Running",
            color: .yellow,
            isTrackingEnabled: true,
            trackingUnit: "km",
            goal: HabitGoal(unit: "km", dailyTarget: 5),
            timeEntries: [
                TimeEntry(loggedAt: date(2026, 6, 7, calendar), year: 2026, month: 6, day: 7, minutes: 2, unitLabel: "km"),
                TimeEntry(loggedAt: date(2026, 6, 7, calendar), year: 2026, month: 6, day: 7, minutes: 3, unitLabel: "km"),
                TimeEntry(loggedAt: date(2026, 6, 8, calendar), year: 2026, month: 6, day: 8, minutes: 4, unitLabel: "km")
            ]
        )
        let reward = Reward(
            name: "Race Entry",
            stampTarget: 10,
            linkedHabitID: habitID,
            startDate: date(2026, 6, 1, calendar),
            linkedProgressRule: .goalMetDays
        )

        #expect(rewardStampCount(for: reward, habits: [habit]) == 1)
    }

    @MainActor @Test func goalHabitIgnoresStaleCompletionFlagUntilTargetIsMet() {
        let calendar = Calendar(identifier: .gregorian)
        let habitID = UUID()
        let partialKey = "2026-6-7"
        let completeKey = "2026-6-8"
        let habit = Habit(
            id: habitID,
            name: "Running",
            color: .yellow,
            isTrackingEnabled: true,
            trackingUnit: "km",
            goal: HabitGoal(unit: "km", dailyTarget: 5),
            completedDays: [partialKey, completeKey],
            timeEntries: [
                TimeEntry(loggedAt: date(2026, 6, 7, calendar), year: 2026, month: 6, day: 7, minutes: 4, unitLabel: "km"),
                TimeEntry(loggedAt: date(2026, 6, 8, calendar), year: 2026, month: 6, day: 8, minutes: 5, unitLabel: "km")
            ]
        )
        let stats = HabitStatsCalculator(habit: habit, today: date(2026, 6, 8, calendar), calendar: calendar)
        let reward = Reward(
            name: "Race Entry",
            stampTarget: 10,
            linkedHabitID: habitID,
            startDate: date(2026, 6, 1, calendar),
            linkedProgressRule: .completedDays
        )

        #expect(!habitCompletionState(for: habit, dayKey: partialKey, quantity: 4))
        #expect(abs(habitProgressRatio(for: habit, dayKey: partialKey, quantity: 4) - 0.8) < 0.0001)
        #expect(habitCompletionState(for: habit, dayKey: completeKey, quantity: 5))
        #expect(habitProgressRatio(for: habit, dayKey: completeKey, quantity: 5) == 1)
        #expect(!stats.day(for: date(2026, 6, 7, calendar)).isCompleted)
        #expect(abs(stats.day(for: date(2026, 6, 7, calendar)).progressRatio - 0.8) < 0.0001)
        #expect(rewardStampCount(for: reward, habits: [habit]) == 1)
    }

    @MainActor @Test func trackedHabitWithoutGoalKeepsBinaryCompletionFallback() {
        let key = "2026-6-7"
        let habit = Habit(
            name: "Reading",
            color: .green,
            isTrackingEnabled: true,
            trackingUnit: "pages",
            completedDays: [key]
        )

        #expect(habitCompletionState(for: habit, dayKey: key, quantity: 0))
        #expect(habitProgressRatio(for: habit, dayKey: key, quantity: 0) == 1)
    }

    @MainActor @Test func trackedHabitWithoutGoalDoesNotAutoCompleteFromLoggedQuantity() {
        let calendar = Calendar(identifier: .gregorian)
        let key = "2026-6-7"
        let habit = Habit(
            name: "Reading",
            color: .green,
            isTrackingEnabled: true,
            trackingUnit: "pages",
            timeEntries: [
                TimeEntry(
                    loggedAt: date(2026, 6, 7, calendar),
                    year: 2026,
                    month: 6,
                    day: 7,
                    minutes: 12,
                    unitLabel: "pages"
                )
            ]
        )

        #expect(!habitCompletionState(for: habit, dayKey: key, quantity: 12))
        #expect(habitProgressRatio(for: habit, dayKey: key, quantity: 12) == 1)
    }

    @MainActor @Test func rewardHistoryIncludesPointsAndClaim() async throws {
        let calendar = Calendar(identifier: .gregorian)
        let reward = Reward(
            name: "Massage",
            stampTarget: 5,
            startDate: date(2026, 6, 1, calendar),
            manualStampEntries: [
                RewardStampEntry(stampedAt: date(2026, 6, 2, calendar), amount: 3)
            ],
            isArchived: true,
            claimedAt: date(2026, 6, 3, calendar)
        )

        let history = rewardHistoryEntries(for: reward, habits: [], calendar: calendar)

        #expect(history.count == 2)
        #expect(history.first?.detail == "Reward claimed")
        #expect(history.last?.amount == 3)
    }

    @Test func manualRewardStampRemovalUsesLatestEligibleEntry() {
        let calendar = Calendar(identifier: .gregorian)
        var reward = Reward(
            name: "Massage",
            stampTarget: 5,
            startDate: date(2026, 6, 2, calendar),
            manualStampEntries: [
                RewardStampEntry(
                    id: UUID(uuidString: "10101010-1010-1010-1010-101010101010")!,
                    stampedAt: date(2026, 6, 1, calendar),
                    amount: 3
                ),
                RewardStampEntry(
                    id: UUID(uuidString: "20202020-2020-2020-2020-202020202020")!,
                    stampedAt: date(2026, 6, 4, calendar),
                    amount: 2
                )
            ]
        )

        #expect(removeOneManualRewardStamp(from: &reward, calendar: calendar))
        #expect(reward.manualStampEntries.count == 2)
        #expect(reward.manualStampEntries.last?.amount == 1)
        #expect(rewardStampCount(for: reward, habits: []) == 1)
    }

    @Test func linkedLoggedQuantityStampRemovalReducesLatestEntry() {
        let calendar = Calendar(identifier: .gregorian)
        let habitID = UUID()
        var habit = Habit(
            id: habitID,
            name: "Reading",
            color: .green,
            isTrackingEnabled: true,
            trackingUnit: "pages",
            timeEntries: [
                TimeEntry(loggedAt: date(2026, 6, 7, calendar), year: 2026, month: 6, day: 7, minutes: 4, unitLabel: "pages"),
                TimeEntry(loggedAt: date(2026, 6, 8, calendar), year: 2026, month: 6, day: 8, minutes: 3, unitLabel: "pages")
            ]
        )
        let reward = Reward(
            name: "Buy a Novel",
            stampTarget: 10,
            linkedHabitID: habitID,
            startDate: date(2026, 6, 1, calendar)
        )

        #expect(removeOneLinkedRewardStamp(from: reward, habit: &habit, calendar: calendar))
        #expect(rewardStampCount(for: reward, habits: [habit]) == 6)
        #expect(habit.timeEntries.last?.minutes == 2)
    }

    @Test func linkedCompletedDayStampRemovalUnmarksLatestEligibleDay() {
        let calendar = Calendar(identifier: .gregorian)
        let habitID = UUID()
        var habit = Habit(
            id: habitID,
            name: "Stretching",
            color: .blue,
            completedDays: ["2026-6-2", "2026-6-3", "2026-6-4"]
        )
        let reward = Reward(
            name: "Coffee",
            stampTarget: 5,
            linkedHabitID: habitID,
            startDate: date(2026, 6, 2, calendar),
            linkedProgressRule: .completedDays
        )

        #expect(removeOneLinkedRewardStamp(from: reward, habit: &habit, calendar: calendar))
        #expect(!habit.completedDays.contains("2026-6-4"))
        #expect(rewardStampCount(for: reward, habits: [habit]) == 2)
    }

    @Test func linkedGoalMetStampRemovalBreaksLatestGoalDay() {
        let calendar = Calendar(identifier: .gregorian)
        let habitID = UUID()
        var habit = Habit(
            id: habitID,
            name: "Running",
            color: .yellow,
            isTrackingEnabled: true,
            trackingUnit: "km",
            goal: HabitGoal(unit: "km", dailyTarget: 5),
            completedDays: ["2026-6-7", "2026-6-8"],
            timeEntries: [
                TimeEntry(loggedAt: date(2026, 6, 7, calendar), year: 2026, month: 6, day: 7, minutes: 5, unitLabel: "km"),
                TimeEntry(loggedAt: date(2026, 6, 8, calendar), year: 2026, month: 6, day: 8, minutes: 6, unitLabel: "km")
            ]
        )
        let reward = Reward(
            name: "Race Entry",
            stampTarget: 5,
            linkedHabitID: habitID,
            startDate: date(2026, 6, 1, calendar),
            linkedProgressRule: .goalMetDays
        )

        #expect(removeOneLinkedRewardStamp(from: reward, habit: &habit, calendar: calendar))
        #expect(rewardStampCount(for: reward, habits: [habit]) == 1)
        #expect(!habit.completedDays.contains("2026-6-8"))
        #expect(habit.timeEntries.reduce(0) { $0 + $1.minutes } == 9)
    }

    @Test func reminderFrequencyBuildsExpectedNotificationComponents() {
        let daily = HabitNotificationScheduler.dateComponents(
            for: HabitReminder(frequency: .daily, hour: 8, minute: 30)
        )
        #expect(daily.hour == 8)
        #expect(daily.minute == 30)
        #expect(daily.weekday == nil)
        #expect(daily.day == nil)

        let weekly = HabitNotificationScheduler.dateComponents(
            for: HabitReminder(frequency: .weekly, hour: 18, minute: 15, weekday: .friday)
        )
        #expect(weekly.hour == 18)
        #expect(weekly.minute == 15)
        #expect(weekly.weekday == HabitReminderWeekday.friday.rawValue)
        #expect(weekly.day == nil)

        let monthly = HabitNotificationScheduler.dateComponents(
            for: HabitReminder(frequency: .monthly, hour: 7, minute: 0, dayOfMonth: 21)
        )
        #expect(monthly.hour == 7)
        #expect(monthly.minute == 0)
        #expect(monthly.weekday == nil)
        #expect(monthly.day == 21)
    }

    @MainActor @Test func storedHabitWithoutReminderStillDecodes() throws {
        let storedHabit = StoredHabit(Habit(name: "Reading", color: .green))
        let encodedHabit = try JSONEncoder().encode(storedHabit)
        var legacyObject = try #require(JSONSerialization.jsonObject(with: encodedHabit) as? [String: Any])
        legacyObject.removeValue(forKey: "reminder")
        let legacyData = try JSONSerialization.data(withJSONObject: legacyObject)

        let decodedHabit = try JSONDecoder().decode(StoredHabit.self, from: legacyData)

        #expect(decodedHabit.value.reminder == nil)
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ calendar: Calendar) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }
}
