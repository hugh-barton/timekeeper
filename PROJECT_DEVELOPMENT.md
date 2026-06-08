# Timekeeper Project Development

## Current State

- The app is a dark-mode SwiftUI habit tracker prototype.
- `ContentView.swift` contains tab navigation, the homepage, habit creation sheet, habit rows, binary completion state, time entry logging, Stats page, and 2026 heat map rendering.
- Habits are initialized from deterministic embedded mock data and stored in local `@State`. Persistence has not been added.

## Built Features

- Homepage has a top-right plus button.
- Homepage navigation title uses inline display mode so `Timekeeper` stays centered in the fixed navigation bar.
- Tapping plus opens a modal with:
  - Habit name text input
  - Habit color picker
- Created habits appear as rows with:
  - Habit name text at the top left
  - A horizontally scrollable heat map strip below the name
  - A circular checkbox at the right end of the heat map row
  - A time logging plus button below the checkbox
- Tapping a habit's time logging plus button opens a modal with:
  - Manual minutes text input
  - +5, +15, and +30 increment buttons
  - Save confirmation button
- Habit cards use viewport-based sizing so four cards fit in the visible home screen area.
- Habit cards are contained in rounded dark-grey rectangles with subtle borders.
- Tapping the checkbox toggles the current day's completion state.
- Long-pressing a habit card opens a native context menu with:
  - Edit
  - Mark Day as Rest or Unmark Rest Day, depending on today's rest state
  - Delete
- Edit opens the habit modal pre-filled with the habit's current name and color.
- Mark Day as Rest marks today as a rest day for that habit, clears completion for today, and disables the checkbox for today.
- Unmark Rest Day clears today's rest day state and returns today's heat map square to the default incomplete state.
- Delete removes the habit and all associated habit-owned data.
- Completed days render in the habit's assigned color.
- Rest days render in muted grey.
- Incomplete and future days render as dim unfilled squares.
- Heat maps default their horizontal scroll position so the current week column is the rightmost visible column.
- Saved time entries are stored on each habit with:
  - Logged timestamp
  - Year
  - Month
  - Day
  - Minutes
- A Stats tab displays saved time entries grouped by habit, showing date and minutes logged per entry.
- Development mock data loads on every launch:
  - Four habits: Strength, Reading, Meditation, Running
  - Assigned colors: red, green, purple, blue
  - Deterministic completion/rest/incomplete states from January 1, 2026 through June 2, 2026
  - Deterministic time entries between 10 and 90 minutes for completed days only
  - June 3, 2026 starts blank with no seeded completion, rest, or time entries

## Heat Map Rules

- Heat maps cover January 1, 2026 through December 31, 2026.
- Calendar columns represent weeks, with rows running Monday through Sunday.
- Days before January 1 and after December 31 are invisible placeholders so the 2026 days align to weekday rows.
- The current day is derived from `Date()` at runtime and normalized to the start of the day.

## Recent Decisions

- No persistence was added because it was not requested.
- Mock data is generated from fixed seeds so visible habit history and time values are stable across launches.
- Mock data intentionally stops at yesterday so today starts blank for user input.
- No extra creation toggles or habit settings were added.
- The checkbox represents binary completion for the current day.
- Habit row layout was adjusted so the heat map expands between the left-aligned habit content and the right-aligned completion checkbox.
- Habit card visual sizing was adjusted with larger heat map squares, checkbox, and time controls while preserving the existing content order.
- Goals functionality was removed at the user's request.
- Time entries are structured with date components to support future day, month, and year filtering without data migration.
- Time logging modal increments accumulate into a session total; manually typed minutes are added to that total on save.
- Stats display is read-only and does not include filters, tab switching logic, or calculated aggregates.
- Rest days are stored on each habit with a day key, marked timestamp, and date components.
- Rest day state is mutually exclusive with completion for the same habit and date.
- Heat map default scrolling uses the existing week columns and only changes initial scroll position.
- June 2, 2026 is a Tuesday; Monday of that week is June 1, 2026. The implementation follows actual Gregorian calendar weekday alignment.

## Validation

- `Timekeeper/ContentView.swift` live diagnostics: no issues.
- Xcode project build: successful.

## Next

- Add persistence only when requested.
- Add per-day editing only when requested.
- Add tests when behavior expands beyond this prototype state.
