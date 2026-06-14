import SwiftUI

struct RewardHistoryView: View {
    let rewards: [Reward]
    let habits: [Habit]
    let onEdit: (Reward) -> Void
    let onDelete: (UUID) -> Void
    let onRestore: (Reward) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var rewardPendingDeletion: Reward?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                if rewards.isEmpty {
                    ContentUnavailableView(
                        "No Reward History",
                        systemImage: "clock.arrow.circlepath",
                        description: Text("Reward activity will appear here.")
                    )
                } else {
                    List {
                        ForEach(sortedRewards) { reward in
                            Section {
                                let entries = rewardHistoryEntries(for: reward, habits: habits)

                                if entries.isEmpty {
                                    Text("No activity yet")
                                        .foregroundStyle(.secondary)
                                } else {
                                    ForEach(entries) { entry in
                                        HStack(spacing: 12) {
                                            VStack(alignment: .leading, spacing: 3) {
                                                Text(entry.detail)
                                                    .foregroundStyle(.primary)

                                                Text(entry.date.formatted(date: .abbreviated, time: .shortened))
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }

                                            Spacer()

                                            if entry.amount > 0 {
                                                Text("+\(entry.amount)")
                                                    .font(.headline.monospacedDigit())
                                                    .foregroundStyle(.yellow)
                                            }
                                        }
                                    }
                                }

                                if reward.isArchived {
                                    Button("Restore Reward") {
                                        onRestore(reward)
                                    }
                                }
                            } header: {
                                HStack {
                                    Text(reward.name)
                                    Spacer()
                                    Text(reward.isArchived ? "Claimed" : "\(rewardStampCount(for: reward, habits: habits)) / \(reward.stampTarget)")
                                }
                            }
                            .contextMenu {
                                Button {
                                    dismiss()
                                    DispatchQueue.main.async {
                                        onEdit(reward)
                                    }
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }

                                Button(role: .destructive) {
                                    rewardPendingDeletion = reward
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Reward History")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .confirmationDialog(
                "Delete \(rewardPendingDeletion?.name ?? "Reward")?",
                isPresented: Binding(
                    get: { rewardPendingDeletion != nil },
                    set: { if !$0 { rewardPendingDeletion = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Delete Reward", role: .destructive) {
                    guard let rewardPendingDeletion else { return }
                    onDelete(rewardPendingDeletion.id)
                    self.rewardPendingDeletion = nil
                }
            }
        }
    }

    private var sortedRewards: [Reward] {
        rewards.sorted {
            ($0.claimedAt ?? $0.startDate) > ($1.claimedAt ?? $1.startDate)
        }
    }
}
