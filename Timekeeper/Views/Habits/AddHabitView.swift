import SwiftUI

struct AddHabitView: View {
    @Binding var habitName: String
    @Binding var symbolName: String
    @Binding var habitColor: Color
    @Binding var isTrackingEnabled: Bool
    @Binding var trackingUnit: String
    @Binding var hasGoal: Bool
    @Binding var goalUnit: String
    @Binding var goalTarget: String
    @Binding var reminder: HabitReminder?

    let title: String
    let saveButtonTitle: String
    let onCancel: () -> Void
    let onSave: () -> Void

    @State private var isShowingSymbolPicker = false

    var body: some View {
        NavigationStack {
            Form {
                TextField("Habit name", text: $habitName)
                    .textInputAutocapitalization(.words)

                Button {
                    isShowingSymbolPicker = true
                } label: {
                    HStack {
                        Text("Symbol")
                            .foregroundStyle(.primary)

                        Spacer()

                        Image(systemName: symbolName)
                            .font(.body.weight(.medium))
                            .foregroundStyle(habitColor)

                        Text(HabitSymbolOption.label(for: symbolName))
                            .foregroundStyle(.secondary)
                    }
                }

                ColorPicker("Habit color", selection: $habitColor, supportsOpacity: false)

                Section("Tracking") {
                    Toggle("Track progress", isOn: $isTrackingEnabled)

                    Toggle("Set a daily goal", isOn: $hasGoal)

                    if hasGoal {
                        TextField("Unit, e.g. pages", text: $goalUnit)
                            .textInputAutocapitalization(.never)

                        TextField("Daily target", text: $goalTarget)
                            .keyboardType(.numberPad)
                    } else if isTrackingEnabled {
                        TextField("Unit, e.g. minutes", text: $trackingUnit)
                            .textInputAutocapitalization(.never)
                    }
                }

                Section("Reminders") {
                    Toggle("Enable reminders", isOn: reminderEnabledBinding)

                    if reminder != nil {
                        Picker("Frequency", selection: reminderFrequencyBinding) {
                            ForEach(HabitReminderFrequency.allCases) { frequency in
                                Text(frequency.title)
                                    .tag(frequency)
                            }
                        }

                        if reminder?.frequency == .weekly {
                            Picker("Day of Week", selection: reminderWeekdayBinding) {
                                ForEach(HabitReminderWeekday.allCases) { weekday in
                                    Text(weekday.title)
                                        .tag(weekday)
                                }
                            }
                        } else if reminder?.frequency == .monthly {
                            Picker("Day of Month", selection: reminderDayOfMonthBinding) {
                                ForEach(1...31, id: \.self) { day in
                                    Text("\(day)")
                                        .tag(day)
                                }
                            }
                        }

                        DatePicker("Time", selection: reminderTimeBinding, displayedComponents: .hourAndMinute)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.black)
            .navigationTitle(title)
            .sheet(isPresented: $isShowingSymbolPicker) {
                SymbolPickerView(selection: $symbolName, accentColor: habitColor)
                    .preferredColorScheme(.dark)
            }
            .onChange(of: hasGoal) { _, newValue in
                if newValue {
                    isTrackingEnabled = true
                }
            }
            .onChange(of: isTrackingEnabled) { _, newValue in
                if !newValue {
                    hasGoal = false
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(saveButtonTitle) {
                        onSave()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }

    private var canSave: Bool {
        let trimmedName = habitName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedTrackingUnit = trackingUnit.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedUnit = goalUnit.trimmingCharacters(in: .whitespacesAndNewlines)
        let target = Int(goalTarget.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0

        return !trimmedName.isEmpty
            && (!isTrackingEnabled || hasGoal || !trimmedTrackingUnit.isEmpty)
            && (!hasGoal || (!trimmedUnit.isEmpty && target > 0))
    }

    private var reminderEnabledBinding: Binding<Bool> {
        Binding(
            get: { reminder != nil },
            set: { isEnabled in
                if isEnabled {
                    reminder = reminder ?? HabitReminder()
                } else {
                    reminder = nil
                }
            }
        )
    }

    private var reminderFrequencyBinding: Binding<HabitReminderFrequency> {
        Binding(
            get: { reminder?.frequency ?? .daily },
            set: { frequency in
                updateReminder { $0.frequency = frequency }
            }
        )
    }

    private var reminderWeekdayBinding: Binding<HabitReminderWeekday> {
        Binding(
            get: { reminder?.weekday ?? .monday },
            set: { weekday in
                updateReminder { $0.weekday = weekday }
            }
        )
    }

    private var reminderDayOfMonthBinding: Binding<Int> {
        Binding(
            get: { reminder?.dayOfMonth ?? 1 },
            set: { dayOfMonth in
                updateReminder { $0.dayOfMonth = dayOfMonth }
            }
        )
    }

    private var reminderTimeBinding: Binding<Date> {
        Binding(
            get: {
                let reminder = reminder ?? HabitReminder()
                return Calendar.current.date(
                    from: DateComponents(hour: reminder.hour, minute: reminder.minute)
                ) ?? Date()
            },
            set: { date in
                let components = Calendar.current.dateComponents([.hour, .minute], from: date)
                updateReminder {
                    $0.hour = components.hour ?? 9
                    $0.minute = components.minute ?? 0
                }
            }
        )
    }

    private func updateReminder(_ update: (inout HabitReminder) -> Void) {
        guard var updatedReminder = reminder else { return }
        update(&updatedReminder)
        reminder = updatedReminder
    }
}
