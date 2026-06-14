# Timekeeper Project Development

## Current State

- Timekeeper is a dark-mode SwiftUI habit tracker.
- The app currently has four tabs: Habits, Stats, Rewards, and Settings.
- The root app coordinator lives in `Timekeeper/ContentView.swift`.
- Models, persistence, calculation logic, and feature views are split into focused files under `Timekeeper/Models`, `Timekeeper/Persistence`, `Timekeeper/Logic`, and `Timekeeper/Views`.
- Habit and reward datasets are JSON-encoded and persisted in `UserDefaults`.
- Developer Mode switches between two separately persisted datasets:
  - Developer Mode on uses the seeded mock dataset.
  - Developer Mode off uses the real dataset, which starts empty.
- Developer Mode defaults to on. Persisted data is loaded before the embedded defaults, so an existing installation may differ from the seed data.

## Source Structure

- `Timekeeper/ContentView.swift`
  - Root `TabView` container
  - App-level state for active dataset selection, add/edit sheets, reward stamping, and persistence triggers
- `Timekeeper/Models/HabitModels.swift`
  - Habit, goal, rest-day, time-entry, reward, reward-history, and reward-progress model types
- `Timekeeper/Models/HabitSymbolOption.swift`
  - SF Symbol option catalog and labels for habits
- `Timekeeper/Persistence/MockData.swift`
  - Deterministic seeded mock habits and rewards
  - `SeededGenerator`
- `Timekeeper/Persistence/StorageModels.swift`
  - `UserDefaults` storage keys
  - Data-mode enum
  - Codable storage DTOs
  - `Color` codable conversion helpers
- `Timekeeper/Logic/RewardProgress.swift`
  - Reward progress aggregation and reward history entry generation
- `Timekeeper/Logic/HabitStatsCalculator.swift`
  - Yearly habit stats data structures and calculation logic
- `Timekeeper/Views/Habits`
  - `HabitRow`, `HabitHistorySheet`, `HabitDayEditorView`, `TimeEntryView`, `AddHabitView`, `SymbolPickerView`
- `Timekeeper/Views/Stats`
  - `StatsView`, stats detail sections, and `StatsHabitCard`
- `Timekeeper/Views/Rewards`
  - `RewardsView`, `RewardCard`, `AddRewardView`, `RewardBulkStampView`, `RewardHistoryView`
- `Timekeeper/Views/Settings/SettingsView.swift`
  - Settings form and Developer Mode toggle

## Habit Features

- The Habits tab displays habit cards sized so four expanded cards fit in the visible area.
- Each habit has:
  - Name
  - SF Symbol
  - Color
  - Creation date
  - Optional progress tracking unit
  - Optional daily goal
  - Completed days
  - Rest days
  - Logged progress entries
- The add/edit habit sheet supports:
  - Habit name
  - Searchable SF Symbol picker
  - Color picker
  - Binary habits
  - Quantity-tracked habits with a custom unit
  - Optional daily goals with a unit and target
- Habit cards show:
  - Habit symbol and name
  - A horizontally scrollable heat map ending at the current week
  - A binary completion control, tracked-progress control, or goal progress ring
  - A separate progress logging button for tracked habits
- Long-pressing a habit card opens a context menu with:
  - Edit
  - Mark or unmark today as a rest day
  - Collapse or expand
  - Delete
- Collapsed habit cards show the five most recent elapsed days.
- Rest days are mutually exclusive with completion and display a moon icon.
- Progress logging accepts manual input and +5, +15, and +30 increments.
- For tracked habits without a goal, any logged quantity counts as completion.
- For goal habits, progress is shown proportionally and reaching the target counts as completion.
- Tapping a habit name or heat map opens its monthly history.
- The history sheet supports navigating through the current calendar year and editing any non-future day.
- Day editing can set a quantity, mark completion, mark a rest day, or clear the day. Editing a date before the habit's creation date moves its creation date back.

## Stats Features

- The Stats tab shows one summary card per habit with consistency and quantity or completion averages.
- Selecting a habit opens detailed analytics for the current calendar year:
  - Total logged quantity for tracked habits
  - Eligible versus completed days
  - Current and longest streaks
  - Consistency percentage
  - Daily and weekly averages
  - Full-year heat map and monthly calendar
  - Per-day tooltip
  - Weekly quantity or completion chart
  - Weekly consistency chart
  - Best weekday, worst weekday, longest gap, and best month
  - Goal target, actual average, and met/partial/missed breakdown
  - Linked reward progress
- Rest days are excluded from eligible-day consistency calculations.
- Stats use each habit's creation date and ignore future days.

## Reward Features

- Rewards can be created with:
  - Name
  - Stamp target
  - Optional historical start date
  - Optional deadline
  - Optional linked habit
- Rewards can be edited or deleted from their card menu. Deletion requires confirmation.
- Manual rewards gain stamps when tapped:
  - Targets of 10 or fewer use one-stamp taps and display individual stamp circles.
  - Targets above 10 open a bulk point-entry sheet.
- Linked rewards calculate progress automatically from the linked habit:
  - Automatic mode counts completed days for binary habits and logged quantity for tracked habits.
  - Linked rewards can instead explicitly count logged quantity, completed days, or goal-met days when supported by the selected habit.
  - Only progress on or after the reward start date counts.
- The Reward History screen shows manual points, linked-habit contributions, and claim events.
- Completed rewards can be claimed and are then archived from the active rewards list.
- Claimed rewards can be restored from Reward History without losing their previous claim events.

## Persistence and Data Modes

- `UserDefaults` stores:
  - The Developer Mode setting
  - The mock habit/reward dataset
  - The real habit/reward dataset
- Stored datasets include habit colors, symbols, goals, completion history, rest days, progress entries, rewards, linked reward progress rules, manual reward stamps, archive state, and claim history.
- Switching Developer Mode resets transient modal and animation state but preserves both datasets.
- There is currently no reset-data or delete-all-data control.

## Embedded Mock Data

- The fallback mock dataset is deterministic and contains four habits:

| Habit | Symbol | Color | Created | Tracking | Goal |
| --- | --- | --- | --- | --- | --- |
| Strength | `dumbbell.fill` | Red | January 12, 2026 | Binary | None |
| Reading | `book.closed.fill` | Green | February 3, 2026 | Pages | None |
| Meditation | `brain.head.profile` | Purple | March 18, 2026 | Binary | None |
| Running | `figure.run` | Yellow | April 7, 2026 | Kilometres (`km`) | 5 km daily |

- Seeded habit history runs from each habit's creation date through June 2, 2026.
- Seeded days deterministically contain completion/progress, rest, or incomplete states.
- Tracked habits receive deterministic quantity entries:
  - Reading logs pages.
  - Running logs kilometres and may contain partial or goal-met days.
- June 3, 2026 onward has no embedded seeded activity.
- The fallback mock rewards are:
  - Fresh Notebook, linked to Reading, target 120
  - Massage Voucher, manual, target 8, with five seeded stamps
  - Race Day Entry, linked to Running goal-met days, target 30

## Calendar and Heat Map Rules

- Habit-card heat maps are fixed to January 1 through December 31, 2026.
- Detailed stats and history use the current calendar year.
- Calendar columns represent weeks, with rows running Monday through Sunday.
- Placeholder cells align the first and last weeks.
- Future days are dimmed and cannot be edited from habit history.
- Habit colors indicate completion or proportional progress.
- Rest days use muted grey with a moon icon.
- Incomplete elapsed days use a dim grey fill.

## Validation and Tests

- `TimekeeperTests` currently has five unit tests covering reward behavior:
  - Binary completion counting from a reward start date
  - Tracked quantity counting from a reward start date
  - Completion-day counting for tracked habits
  - Goal-met-day counting
  - Manual point and claim history
- The UI test target contains only the generated launch and launch-performance scaffolding.
- Most habit behavior, persistence, stats calculations, day editing, and reward interactions do not yet have automated test coverage.

## Known Limitations

- Habit-card heat maps are hard-coded to 2026 while detailed stats use the runtime current year.
- Progress quantities are stored in the model property named `minutes`, even when the unit is pages or kilometres.
- Persistence uses `UserDefaults`; there is no database, cloud sync, migration strategy, or import/export flow.
- There is no reset control for returning persisted mock data to the embedded seed.

## Next Priorities

- Add automated coverage for persistence, habit/day editing, goals, stats calculations, and rewards.
- Replace the fixed 2026 habit heat map with a runtime-year or selectable-year implementation.
- Add dataset reset controls.
- Rename the generic tracked quantity field or introduce a clearer progress-entry model.
