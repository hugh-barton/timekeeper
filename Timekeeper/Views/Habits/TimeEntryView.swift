import SwiftUI

struct TimeEntryView: View {
    let habitName: String
    let unitLabel: String
    let title: String
    let placeholder: String

    @Binding var manualTimeInput: String
    @Binding var sessionMinutes: Int

    let allowsEmptySave: Bool
    let onCancel: () -> Void
    let onSave: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                TextField(placeholder, text: $manualTimeInput)
                    .keyboardType(.numberPad)

                HStack(spacing: 10) {
                    incrementButton(minutes: 5)
                    incrementButton(minutes: 15)
                    incrementButton(minutes: 30)
                }

                HStack {
                    Text("Session total")
                    Spacer()
                    Text("\(displayedTotal) \(unitLabel)")
                        .foregroundStyle(.secondary)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.black)
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
                    .disabled(!allowsEmptySave && displayedTotal <= 0)
                }
            }
        }
    }

    private var manualMinutes: Int {
        let trimmedInput = manualTimeInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let minutes = Int(trimmedInput), minutes > 0 else { return 0 }
        return minutes
    }

    private var displayedTotal: Int {
        sessionMinutes + manualMinutes
    }

    private func incrementButton(minutes: Int) -> some View {
        Button("+\(minutes)") {
            sessionMinutes += minutes
        }
        .buttonStyle(.bordered)
        .frame(maxWidth: .infinity)
    }
}
