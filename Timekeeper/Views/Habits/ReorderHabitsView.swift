import SwiftUI

struct ReorderHabitsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var habits: [Habit]

    let onSave: ([Habit]) -> Void

    init(habits: [Habit], onSave: @escaping ([Habit]) -> Void) {
        _habits = State(initialValue: habits)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(habits) { habit in
                    HStack(spacing: 12) {
                        Image(systemName: habit.symbolName)
                            .font(.body.weight(.medium))
                            .foregroundStyle(habit.color)
                            .frame(width: 24)

                        Text(habit.name)
                            .foregroundStyle(.primary)
                    }
                }
                .onMove(perform: moveHabits)
            }
            .environment(\.editMode, .constant(.active))
            .navigationTitle("Reorder Habits")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onSave(habits)
                        dismiss()
                    }
                }
            }
        }
    }

    private func moveHabits(from source: IndexSet, to destination: Int) {
        habits.move(fromOffsets: source, toOffset: destination)
    }
}
