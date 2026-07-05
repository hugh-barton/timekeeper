import SwiftUI

struct TimeEntryView: View {
    let habitName: String
    let unitLabel: String
    let loggedTodayValue: Int
    let title: String
    let placeholder: String

    @Binding var manualTimeInput: String
    @Binding var sessionMinutes: Int

    let allowsEmptySave: Bool
    let onClear: (() -> Void)?
    let onCancel: () -> Void
    let onSave: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 16) {
                    HabitQuantityKeypadView(quantityInput: $manualTimeInput, onInputChanged: nil)

                    HStack(spacing: 10) {
                        incrementButton(minutes: 5)
                        incrementButton(minutes: 15)
                        incrementButton(minutes: 30)
                    }

                    HStack {
                        Text("Session total")
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("\(loggedTodayValue) \(unitLabel) logged today")
                            Text("\(displayValue) \(unitLabel)")
                        }
                        .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 4)

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
            }
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave()
                    }
                    .disabled(!allowsEmptySave && totalValue <= 0)
                }

                if let onClear {
                    ToolbarItem(placement: .bottomBar) {
                        Button("Clear Today", role: .destructive) {
                            onClear()
                        }
                    }
                }
            }
        }
    }

    private var displayValue: String {
        manualTimeInput.isEmpty ? "0" : manualTimeInput
    }

    private var totalValue: Double {
        let trimmedInput = manualTimeInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Double(trimmedInput), value > 0 else { return 0 }
        return value
    }

    private func formattedValue(_ value: Double) -> String {
        if value.rounded() == value {
            return String(Int(value))
        }

        return String(value)
    }

    private func incrementButton(minutes: Int) -> some View {
        Button("+\(minutes)") {
            let updatedValue = totalValue + Double(minutes)
            manualTimeInput = formattedValue(updatedValue)
            sessionMinutes = 0
        }
        .buttonStyle(.bordered)
        .frame(maxWidth: .infinity)
    }
}
