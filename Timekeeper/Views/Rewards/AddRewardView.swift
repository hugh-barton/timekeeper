import SwiftUI

struct AddRewardView: View {
    @Binding var rewardName: String
    @Binding var rewardDescription: String
    @Binding var stampTarget: String
    @Binding var linkedHabitID: UUID?
    @Binding var startDate: Date
    @Binding var hasCustomStartDate: Bool
    @Binding var endDate: Date
    @Binding var hasDeadline: Bool
    @Binding var progressRule: RewardProgressRule

    let habits: [Habit]
    let title: String
    let saveButtonTitle: String
    let onCancel: () -> Void
    let onSave: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                TextField("Reward name", text: $rewardName)
                    .textInputAutocapitalization(.words)

                TextField("Short description (optional)", text: $rewardDescription, axis: .vertical)
                    .lineLimit(2...3)

                TextField("Stamp target", text: $stampTarget)
                    .keyboardType(.numberPad)

                Section {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            hasCustomStartDate.toggle()
                        }
                    } label: {
                        Text("I already started working towards this")
                            .foregroundStyle(.blue)
                    }

                    if hasCustomStartDate {
                        DatePicker("Start date", selection: $startDate, displayedComponents: .date)
                    }
                }

                Section {
                    Toggle("Set a deadline", isOn: $hasDeadline)

                    if hasDeadline {
                        DatePicker("Deadline", selection: $endDate, displayedComponents: .date)
                    }
                }

                Picker("Linked habit", selection: $linkedHabitID) {
                    Text("None")
                        .tag(UUID?.none)

                    ForEach(habits) { habit in
                        Text(habit.name)
                            .tag(Optional(habit.id))
                    }
                }

                if let linkedHabit {
                    Section("Linked progress") {
                        Picker("Count", selection: $progressRule) {
                            ForEach(availableProgressRules(for: linkedHabit)) { rule in
                                Text(rule.title)
                                    .tag(rule)
                            }
                        }

                        Text(progressRule.description(for: linkedHabit))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.black)
            .navigationTitle(title)
            .onChange(of: linkedHabitID) { _, _ in
                if !availableProgressRules(for: linkedHabit).contains(progressRule) {
                    progressRule = .automatic
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
        let trimmedName = rewardName.trimmingCharacters(in: .whitespacesAndNewlines)
        let target = Int(stampTarget.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
        return !trimmedName.isEmpty && target > 0
    }

    private var linkedHabit: Habit? {
        guard let linkedHabitID else { return nil }
        return habits.first { $0.id == linkedHabitID }
    }

    private func availableProgressRules(for habit: Habit?) -> [RewardProgressRule] {
        guard let habit else { return [.automatic] }

        var rules: [RewardProgressRule] = [.automatic, .completedDays]
        if habit.isTrackingEnabled {
            rules.insert(.loggedQuantity, at: 1)
        }
        if habit.goal != nil {
            rules.append(.goalMetDays)
        }
        return rules
    }
}
