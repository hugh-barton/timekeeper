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
}
