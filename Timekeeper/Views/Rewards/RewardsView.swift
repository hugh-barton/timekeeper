import SwiftUI

struct RewardsView: View {
    @Binding var rewards: [Reward]
    let habits: [Habit]
    let isEditingReward: Bool
    @Binding var isShowingAddReward: Bool
    @Binding var newRewardName: String
    @Binding var newRewardDescription: String
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
    let onRemoveStamp: (Reward) -> Void
    let onConfirmBulkStamp: () -> Void
    let onClaimReward: (Reward) -> Void
    let onRestoreReward: (Reward) -> Void

    @State private var selectedTab: RewardsTab = .active
    @State private var rewardPendingDeletion: Reward?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black
                    .ignoresSafeArea()

                VStack(spacing: 20) {
                    Picker("Rewards", selection: $selectedTab) {
                        ForEach(RewardsTab.allCases) { tab in
                            Text(tab.title)
                                .tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)

                    if selectedRewards.isEmpty {
                        ContentUnavailableView(
                            selectedTab.emptyTitle,
                            systemImage: selectedTab.emptySymbol,
                            description: Text(selectedTab.emptyDescription)
                        )
                        .foregroundStyle(.white.opacity(0.8))
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 16) {
                                switch selectedTab {
                                case .active:
                                    ForEach(activeRewards) { reward in
                                        RewardCard(
                                            reward: reward,
                                            habits: habits,
                                            stampCount: rewardStampCount(for: reward, habits: habits),
                                            isHighlighted: highlightedRewardID == reward.id,
                                            isCelebrating: celebratingRewardID == reward.id,
                                            onTap: { onRewardTap(reward) },
                                            onRemoveStamp: { onRemoveStamp(reward) },
                                            onClaim: { onClaimReward(reward) },
                                            onEdit: { onEditReward(reward) },
                                            onDelete: { rewardPendingDeletion = reward }
                                        )
                                    }
                                case .completed:
                                    ForEach(completedRewards) { reward in
                                        CompletedRewardCard(
                                            reward: reward,
                                            linkedHabit: linkedHabit(for: reward),
                                            onReactivate: { onRestoreReward(reward) }
                                        )
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
            }
            .navigationTitle("Rewards")
            .toolbar {
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
                    rewardDescription: $newRewardDescription,
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

    private var completedRewards: [Reward] {
        rewards
            .filter(\.isArchived)
            .sorted { ($0.claimedAt ?? $0.startDate) > ($1.claimedAt ?? $1.startDate) }
    }

    private var selectedRewards: [Reward] {
        switch selectedTab {
        case .active:
            activeRewards
        case .completed:
            completedRewards
        }
    }

    private func linkedHabit(for reward: Reward) -> Habit? {
        guard let linkedHabitID = reward.linkedHabitID else { return nil }
        return habits.first(where: { $0.id == linkedHabitID })
    }
}

private enum RewardsTab: String, CaseIterable, Identifiable {
    case active
    case completed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .active:
            "Active Rewards"
        case .completed:
            "Completed"
        }
    }

    var emptyTitle: String {
        switch self {
        case .active:
            "No Active Rewards"
        case .completed:
            "No Completed Rewards"
        }
    }

    var emptySymbol: String {
        switch self {
        case .active:
            "gift"
        case .completed:
            "checkmark.seal"
        }
    }

    var emptyDescription: String {
        switch self {
        case .active:
            "Add a reward to start collecting stamps."
        case .completed:
            "Claimed rewards will appear here."
        }
    }
}
