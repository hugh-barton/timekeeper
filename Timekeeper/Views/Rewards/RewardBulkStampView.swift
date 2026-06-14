import SwiftUI

struct RewardBulkStampView: View {
    @Binding var amount: String

    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("How many points would you like to add?")
                        .foregroundStyle(.white)

                    TextField("Points", text: $amount)
                        .keyboardType(.numberPad)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.black)
            .navigationTitle("Add Points")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Confirm") {
                        onConfirm()
                    }
                    .disabled((Int(amount.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0) <= 0)
                }
            }
        }
    }
}
