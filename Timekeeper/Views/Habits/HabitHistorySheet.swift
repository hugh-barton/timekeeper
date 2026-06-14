import SwiftUI

private struct IdentifiableDay: Identifiable {
    let date: Date

    var id: Date { date }
}

struct HabitHistorySheet: View {
    @Binding var habit: Habit

    @Environment(\.dismiss) private var dismiss
    @State private var selectedMonth: Int
    @State private var selectedDay: IdentifiableDay?

    private let calendar = Calendar(identifier: .gregorian)
    private let today: Date

    init(habit: Binding<Habit>, initialMonth: Int) {
        _habit = habit
        _selectedMonth = State(initialValue: initialMonth)
        today = Calendar(identifier: .gregorian).startOfDay(for: Date())
    }

    var body: some View {
        let stats = HabitStatsCalculator(habit: habit, today: today, calendar: calendar)

        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        HStack {
                            Button {
                                selectedMonth -= 1
                            } label: {
                                Image(systemName: "chevron.left")
                                    .font(.headline.weight(.semibold))
                                    .frame(width: 36, height: 36)
                            }
                            .buttonStyle(.bordered)
                            .disabled(selectedMonth == 1)

                            Spacer()

                            VStack(spacing: 4) {
                                Text(stats.monthName(for: selectedMonth, style: .wide))
                                    .font(.title3.weight(.bold))
                                    .foregroundStyle(.white)

                                Text(String(calendar.component(.year, from: today)))
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.white.opacity(0.6))
                            }

                            Spacer()

                            Button {
                                selectedMonth += 1
                            } label: {
                                Image(systemName: "chevron.right")
                                    .font(.headline.weight(.semibold))
                                    .frame(width: 36, height: 36)
                            }
                            .buttonStyle(.bordered)
                            .disabled(selectedMonth == 12)
                        }

                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 8) {
                            ForEach(0..<7, id: \.self) { weekdayIndex in
                                Text(stats.weekdayName(for: weekdayIndex).prefix(3))
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.white.opacity(0.65))
                                    .frame(maxWidth: .infinity)
                            }

                            ForEach(Array(stats.monthGridDays(for: selectedMonth).enumerated()), id: \.offset) { _, date in
                                if let date {
                                    let day = stats.day(for: date)

                                    HabitHeatMapSquare(
                                        habit: habit,
                                        day: day,
                                        squareSize: 40,
                                        isEnabled: !isFutureDay(date)
                                    ) {
                                        guard !isFutureDay(date) else { return }
                                        selectedDay = IdentifiableDay(date: date)
                                    }
                                } else {
                                    Color.clear
                                        .frame(height: 40)
                                }
                            }
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 18)
                                .fill(Color.white.opacity(0.05))
                        )
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 20)
                }
            }
            .navigationTitle(habit.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(item: $selectedDay) { selectedDay in
            HabitDayEditorView(habit: $habit, date: selectedDay.date) { date, quantity, isComplete, isRestDay in
                applyDayEdit(for: date, quantity: quantity, isComplete: isComplete, isRestDay: isRestDay)
            }
            .preferredColorScheme(.dark)
            .presentationDetents([.fraction(0.75)])
        }
    }

    private func applyDayEdit(for date: Date, quantity: Int, isComplete: Bool, isRestDay: Bool) {
        let normalizedDate = calendar.startOfDay(for: date)
        let key = dayKey(for: normalizedDate)

        habit.timeEntries.removeAll { "\($0.year)-\($0.month)-\($0.day)" == key }
        habit.completedDays.remove(key)
        habit.restDays.removeAll { $0.id == key }

        if isRestDay {
            let components = calendar.dateComponents([.year, .month, .day], from: normalizedDate)
            habit.restDays.append(
                RestDay(
                    id: key,
                    markedAt: normalizedDate,
                    year: components.year ?? 0,
                    month: components.month ?? 0,
                    day: components.day ?? 0
                )
            )
            adjustCreatedAtIfNeeded(for: normalizedDate)
            return
        }

        if habit.isTrackingEnabled && quantity > 0 {
            let components = calendar.dateComponents([.year, .month, .day], from: normalizedDate)
            habit.timeEntries.append(
                TimeEntry(
                    loggedAt: normalizedDate,
                    year: components.year ?? 0,
                    month: components.month ?? 0,
                    day: components.day ?? 0,
                    minutes: quantity,
                    unitLabel: habit.goal?.unit ?? habit.trackingUnit,
                    dailyTarget: habit.goal?.dailyTarget
                )
            )
        }

        if isComplete {
            habit.completedDays.insert(key)
        }

        if quantity > 0 || isComplete {
            adjustCreatedAtIfNeeded(for: normalizedDate)
        }
    }

    private func adjustCreatedAtIfNeeded(for date: Date) {
        let normalizedCreatedAt = calendar.startOfDay(for: habit.createdAt)
        if date < normalizedCreatedAt {
            habit.createdAt = date
        }
    }

    private func dayKey(for day: Date) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: day)
        return "\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)"
    }

    private func isFutureDay(_ date: Date) -> Bool {
        calendar.startOfDay(for: date) > today
    }
}

struct HabitDayEditorView: View {
    @Binding var habit: Habit

    let date: Date
    let onSave: (Date, Int, Bool, Bool) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var quantityInput: String
    @State private var isMarkedComplete: Bool
    @State private var isRestDay: Bool

    private let keypadColumns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)
    private let keypadKeys = ["1", "2", "3", "4", "5", "6", "7", "8", "9", ".", "0", "⌫"]

    init(habit: Binding<Habit>, date: Date, onSave: @escaping (Date, Int, Bool, Bool) -> Void) {
        _habit = habit
        self.date = Calendar(identifier: .gregorian).startOfDay(for: date)
        self.onSave = onSave

        let calendar = Calendar(identifier: .gregorian)
        let normalizedDate = calendar.startOfDay(for: date)
        let key = HabitDayEditorView.dayKey(for: normalizedDate, calendar: calendar)
        let quantity = habit.wrappedValue.timeEntries
            .filter { "\($0.year)-\($0.month)-\($0.day)" == key }
            .reduce(0) { $0 + $1.minutes }
        let isRestDay = habit.wrappedValue.restDays.contains { $0.id == key }
        let isMarkedComplete = HabitDayEditorView.completionState(for: habit.wrappedValue, key: key, quantity: quantity)

        _quantityInput = State(initialValue: quantity > 0 ? "\(quantity)" : "0")
        _isMarkedComplete = State(initialValue: isMarkedComplete)
        _isRestDay = State(initialValue: isRestDay)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 14) {
                    Text(date.formatted(date: .long, time: .omitted))
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, alignment: .center)

                    Text(displayValue)
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.white.opacity(0.07))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )

                    if habit.isTrackingEnabled {
                        keypad
                            .layoutPriority(1)
                    }

                    Spacer(minLength: 0)

                    VStack(spacing: 12) {
                        Toggle("Mark as complete", isOn: $isMarkedComplete)
                            .tint(habit.color)
                            .onChange(of: isMarkedComplete) { _, isEnabled in
                                if isEnabled {
                                    isRestDay = false
                                }
                            }

                        Toggle("Mark as rest day", isOn: $isRestDay)
                            .tint(.indigo)
                            .onChange(of: isRestDay) { _, isEnabled in
                                guard isEnabled else { return }
                                isMarkedComplete = false
                                quantityInput = "0"
                            }

                        Button("Clear Day", role: .destructive) {
                            quantityInput = "0"
                            isMarkedComplete = false
                            isRestDay = false
                        }
                        .frame(maxWidth: .infinity)
                        .buttonStyle(.bordered)

                        Button("Save") {
                            saveAndDismiss()
                        }
                        .frame(maxWidth: .infinity)
                        .buttonStyle(.borderedProminent)
                        .tint(habit.color)
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.white.opacity(0.05))
                    )
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }
            .navigationTitle("Edit Day")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        saveAndDismiss()
                    }
                }
            }
        }
    }

    private var quantityValue: Int {
        let trimmedInput = quantityInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let quantity = Double(trimmedInput), quantity > 0 else { return 0 }
        return Int(quantity.rounded())
    }

    private var displayValue: String {
        quantityInput.isEmpty ? "0" : quantityInput
    }

    private var keypad: some View {
        LazyVGrid(columns: keypadColumns, spacing: 12) {
            ForEach(keypadKeys, id: \.self) { key in
                keypadButton(for: key)
            }
        }
    }

    private func keypadButton(for key: String) -> some View {
        Button {
            handleKeypadInput(key)
        } label: {
            Text(key)
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white.opacity(0.08))
                )
        }
        .buttonStyle(.plain)
    }

    private func saveAndDismiss() {
        onSave(date, quantityValue, isMarkedComplete, isRestDay)
        dismiss()
    }

    private func handleKeypadInput(_ key: String) {
        switch key {
        case "⌫":
            if quantityInput.count <= 1 {
                quantityInput = "0"
            } else {
                quantityInput.removeLast()
            }
        case ".":
            guard !quantityInput.contains(".") else { return }
            quantityInput += "."
        default:
            if quantityInput == "0" {
                quantityInput = key
            } else {
                quantityInput += key
            }
        }

        if quantityValue > 0 || quantityInput.contains(".") {
            isRestDay = false
        }
    }

    private static func completionState(for habit: Habit, key: String, quantity: Int) -> Bool {
        habitCompletionState(for: habit, dayKey: key, quantity: quantity)
    }

    private static func dayKey(for day: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: day)
        return "\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)"
    }
}
