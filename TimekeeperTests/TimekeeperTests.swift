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

        #expect(rewardStampCount(for: reward, habits: [habit]) == 3)
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

    private func date(_ year: Int, _ month: Int, _ day: Int, _ calendar: Calendar) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }
}
