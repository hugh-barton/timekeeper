import SwiftUI

struct RewardsView: View {
    @Binding var rewards: [Reward]
    let habits: [Habit]
    let isEditingReward: Bool
    @Binding var isShowingAddReward: Bool
    @Binding var newRewardName: String
    @Binding var newRewardTarget: String
    @Binding var newRewardLinkedHabitID: UUID?
    @Binding var newRewardStartDate: Date
    @Binding var newRewardHasCustomStartDate: Bool
    @Binding var newRewardEndDate: Date
    @Binding var newRewardHasDeadline: Bool
    @Binding var newRewardProgressRule: RewardProgressRule
    @Binding var selectedBulkStampRewardID: UUID?
    @Binding var bulkStampAmount: String
    @Binding var highlightedRewardID: UUID?
    @Binding var celebratingRewardID: UUID?

    let onStartAddingReward: () -> Void
    let onEditReward: (Reward) -> Void
    let onDeleteReward: (UUID) -> Void
    let onCancelRewardModal: () -> Void
    let onSaveReward: () -> Void
    let onRewardTap: (Reward) -> Void
    let onConfirmBulkStamp: () -> Void
    let onClaimReward: (Reward) -> Void
    let onRestoreReward: (Reward) -> Void

    @State private var isShowingRewardHistory = false
    @State private var rewardPendingDeletion: Reward?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black
                    .ignoresSafeArea()

                if activeRewards.isEmpty {
                    ContentUnavailableView(
                        "No Rewards Yet",
                        systemImage: "gift",
                        description: Text("Add a reward to start collecting stamps.")
                    )
                    .foregroundStyle(.white.opacity(0.8))
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(activeRewards) { reward in
                                RewardCard(
                                    reward: reward,
                                    stampCount: rewardStampCount(for: reward, habits: habits),
                                    linkedHabitName: linkedHabitName(for: reward),
                                    isHighlighted: highlightedRewardID == reward.id,
                                    isCelebrating: celebratingRewardID == reward.id,
                                    onTap: { onRewardTap(reward) },
                                    onClaim: { onClaimReward(reward) },
                                    onEdit: { onEditReward(reward) },
                                    onDelete: { rewardPendingDeletion = reward }
                                )
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 20)
                    }
                }
            }
            .navigationTitle("Rewards")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        isShowingRewardHistory = true
                    } label: {
                        Image(systemName: "clock.arrow.circlepath")
                    }
                    .accessibilityLabel("Reward history")
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        onStartAddingReward()
                    } label: {
                        Image(systemName: "plus")
                            .font(.headline)
                    }
                    .accessibilityLabel("Add reward")
                }
            }
            .sheet(isPresented: $isShowingAddReward) {
                AddRewardView(
                    rewardName: $newRewardName,
                    stampTarget: $newRewardTarget,
                    linkedHabitID: $newRewardLinkedHabitID,
                    startDate: $newRewardStartDate,
                    hasCustomStartDate: $newRewardHasCustomStartDate,
                    endDate: $newRewardEndDate,
                    hasDeadline: $newRewardHasDeadline,
                    progressRule: $newRewardProgressRule,
                    habits: habits,
                    title: isEditingReward ? "Edit Reward" : "New Reward",
                    saveButtonTitle: isEditingReward ? "Save" : "Add",
                    onCancel: onCancelRewardModal,
                    onSave: onSaveReward
                )
                .preferredColorScheme(.dark)
            }
            .sheet(
                isPresented: Binding(
                    get: { selectedBulkStampRewardID != nil },
                    set: { isPresented in
                        if !isPresented {
                            bulkStampAmount = ""
                            selectedBulkStampRewardID = nil
                        }
                    }
                )
            ) {
                RewardBulkStampView(
                    amount: $bulkStampAmount,
                    onCancel: {
                        bulkStampAmount = ""
                        selectedBulkStampRewardID = nil
                    },
                    onConfirm: onConfirmBulkStamp
                )
                .preferredColorScheme(.dark)
                .presentationDetents([.height(220)])
            }
            .sheet(isPresented: $isShowingRewardHistory) {
                RewardHistoryView(
                    rewards: rewards,
                    habits: habits,
                    onEdit: onEditReward,
                    onDelete: onDeleteReward,
                    onRestore: onRestoreReward
                )
                .preferredColorScheme(.dark)
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
                    onDeleteReward(rewardPendingDeletion.id)
                    self.rewardPendingDeletion = nil
                }
            }
        }
    }

    private var activeRewards: [Reward] {
        rewards.filter { !$0.isArchived }
    }

    private func linkedHabitName(for reward: Reward) -> String? {
        guard let linkedHabitID = reward.linkedHabitID else { return nil }
        return habits.first(where: { $0.id == linkedHabitID })?.name
    }
}
