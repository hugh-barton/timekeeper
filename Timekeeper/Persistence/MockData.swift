import SwiftUI

struct MockData {
    static let habits: [Habit] = {
        let calendar = Calendar(identifier: .gregorian)
        let specs: [(id: UUID, name: String, symbolName: String, color: Color, createdAt: DateComponents, isTrackingEnabled: Bool, trackingUnit: String, goal: HabitGoal?, seed: UInt64)] = [
            (UUID(uuidString: "11111111-1111-1111-1111-111111111111")!, "Strength", "dumbbell.fill", .red, DateComponents(year: 2026, month: 1, day: 12), false, "", nil, 11),
            (UUID(uuidString: "22222222-2222-2222-2222-222222222222")!, "Reading", "book.closed.fill", .green, DateComponents(year: 2026, month: 2, day: 3), true, "pages", nil, 22),
            (UUID(uuidString: "33333333-3333-3333-3333-333333333333")!, "Meditation", "brain.head.profile", .purple, DateComponents(year: 2026, month: 3, day: 18), false, "", nil, 33),
            (UUID(uuidString: "44444444-4444-4444-4444-444444444444")!, "Running", "figure.run", .yellow, DateComponents(year: 2026, month: 4, day: 7), true, "km", HabitGoal(unit: "km", dailyTarget: 5), 44)
        ]

        guard
            let startDate = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1)),
            let endDate = calendar.date(from: DateComponents(year: 2026, month: 6, day: 2))
        else { return [] }

        return specs.compactMap { spec in
            guard let createdAt = calendar.date(from: spec.createdAt) else { return nil }

            var generator = SeededGenerator(seed: spec.seed)
            var completedDays = Set<String>()
            var restDays: [RestDay] = []
            var timeEntries: [TimeEntry] = []
            var currentDate = max(startDate, createdAt)

            while currentDate <= endDate {
                let components = calendar.dateComponents([.year, .month, .day], from: currentDate)
                let key = dayKey(for: currentDate, calendar: calendar)
                let stateRoll = generator.nextInt(upperBound: 100)

                if stateRoll < 70 {
                    if spec.isTrackingEnabled {
                        let quantity: Int
                        let dailyTarget: Int?

                        if let goal = spec.goal {
                            dailyTarget = goal.dailyTarget

                            if stateRoll < 45 {
                                quantity = goal.dailyTarget + generator.nextInt(upperBound: goal.dailyTarget + 1)
                                completedDays.insert(key)
                            } else {
                                quantity = 1 + generator.nextInt(upperBound: max(goal.dailyTarget - 1, 1))
                            }
                        } else {
                            dailyTarget = nil
                            quantity = 5 + generator.nextInt(upperBound: 26)
                        }

                        timeEntries.append(
                            TimeEntry(
                                id: "\(spec.id.uuidString)-\(key)-time",
                                loggedAt: currentDate,
                                year: components.year ?? 0,
                                month: components.month ?? 0,
                                day: components.day ?? 0,
                                minutes: quantity,
                                unitLabel: spec.goal?.unit ?? spec.trackingUnit,
                                dailyTarget: dailyTarget
                            )
                        )
                    } else {
                        completedDays.insert(key)
                    }
                } else if stateRoll < 80 {
                    restDays.append(
                        RestDay(
                            id: key,
                            markedAt: currentDate,
                            year: components.year ?? 0,
                            month: components.month ?? 0,
                            day: components.day ?? 0
                        )
                    )
                }

                guard let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) else { break }
                currentDate = nextDate
            }

            return Habit(
                id: spec.id,
                name: spec.name,
                symbolName: spec.symbolName,
                color: spec.color,
                createdAt: createdAt,
                isTrackingEnabled: spec.isTrackingEnabled,
                trackingUnit: spec.trackingUnit,
                goal: spec.goal,
                completedDays: completedDays,
                restDays: restDays,
                timeEntries: timeEntries
            )
        }
    }()

    static let rewards: [Reward] = {
        let calendar = Calendar(identifier: .gregorian)

        return [
            Reward(
                id: UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!,
                name: "Fresh Notebook",
                stampTarget: 120,
                linkedHabitID: UUID(uuidString: "22222222-2222-2222-2222-222222222222"),
                startDate: calendar.date(from: DateComponents(year: 2026, month: 2, day: 3)) ?? Date()
            ),
            Reward(
                id: UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")!,
                name: "Massage Voucher",
                stampTarget: 8,
                startDate: calendar.date(from: DateComponents(year: 2026, month: 3, day: 1)) ?? Date(),
                manualStampEntries: [
                    RewardStampEntry(
                        id: UUID(uuidString: "12121212-1212-1212-1212-121212121212")!,
                        stampedAt: calendar.date(from: DateComponents(year: 2026, month: 3, day: 8)) ?? Date(),
                        amount: 2
                    ),
                    RewardStampEntry(
                        id: UUID(uuidString: "34343434-3434-3434-3434-343434343434")!,
                        stampedAt: calendar.date(from: DateComponents(year: 2026, month: 4, day: 9)) ?? Date(),
                        amount: 3
                    )
                ]
            ),
            Reward(
                id: UUID(uuidString: "cccccccc-cccc-cccc-cccc-cccccccccccc")!,
                name: "Race Day Entry",
                stampTarget: 30,
                linkedHabitID: UUID(uuidString: "44444444-4444-4444-4444-444444444444"),
                startDate: calendar.date(from: DateComponents(year: 2026, month: 4, day: 7)) ?? Date(),
                linkedProgressRule: .goalMetDays
            )
        ]
    }()

    private static func dayKey(for day: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: day)
        return "\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)"
    }
}

struct SeededGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func nextInt(upperBound: Int) -> Int {
        state = 6364136223846793005 &* state &+ 1442695040888963407
        return Int(state % UInt64(upperBound))
    }
}
