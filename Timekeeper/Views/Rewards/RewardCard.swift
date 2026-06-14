import SwiftUI

struct RewardCard: View {
    let reward: Reward
    let stampCount: Int
    let linkedHabitName: String?
    let isHighlighted: Bool
    let isCelebrating: Bool
    let onTap: () -> Void
    let onClaim: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(reward.name)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)

                    if let endDateText {
                        Text("Deadline: \(endDateText)")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.72))
                    }

                    if let linkedHabitName {
                        Text("Linked to \(linkedHabitName)")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.62))

                        Text(reward.linkedProgressRule.title)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.5))
                    } else {
                        Text("Tap to add stamps")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.62))
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 10) {
                    Menu {
                        Button {
                            onEdit()
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }

                        Button(role: .destructive) {
                            onDelete()
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.title3)
                            .foregroundStyle(.white.opacity(0.75))
                    }

                    if reward.stampTarget > 10 {
                        Text("\(stampCount) / \(reward.stampTarget)")
                            .font(.headline.monospacedDigit())
                            .foregroundStyle(progressColor)
                    }
                }
            }

            if reward.stampTarget <= 10 {
                HStack(spacing: 10) {
                    ForEach(0..<reward.stampTarget, id: \.self) { index in
                        Circle()
                            .fill(index < stampCount ? progressColor : Color.clear)
                            .frame(width: 18, height: 18)
                            .overlay(
                                Circle()
                                    .stroke(index < stampCount ? progressColor : Color.white.opacity(0.25), style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
                            )
                    }
                }
            }

            if isReadyToClaim {
                Button("Claim") {
                    onClaim()
                }
                .buttonStyle(.borderedProminent)
                .tint(.yellow)
            }

            if isCelebrating {
                Text("Congratulations")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.yellow)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(cardFillColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(borderColor, lineWidth: isHighlighted || isCelebrating ? 2 : 1)
        )
        .scaleEffect(isCelebrating ? 1.03 : 1)
        .animation(.easeOut(duration: 0.2), value: isHighlighted)
        .animation(.spring(response: 0.4, dampingFraction: 0.72), value: isCelebrating)
        .contentShape(RoundedRectangle(cornerRadius: 20))
        .onTapGesture {
            onTap()
        }
        .contextMenu {
            Button {
                onEdit()
            } label: {
                Label("Edit", systemImage: "pencil")
            }

            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private var isReadyToClaim: Bool {
        stampCount >= reward.stampTarget
    }

    private var endDateText: String? {
        guard let endDate = reward.endDate else { return nil }
        return endDate.formatted(date: .abbreviated, time: .omitted)
    }

    private var progressColor: Color {
        isReadyToClaim ? .yellow : .white
    }

    private var cardFillColor: Color {
        if isCelebrating {
            return Color.yellow.opacity(0.22)
        }

        if isHighlighted {
            return Color.yellow.opacity(0.16)
        }

        return Color.white.opacity(0.07)
    }

    private var borderColor: Color {
        if isCelebrating || isHighlighted {
            return Color.yellow.opacity(0.88)
        }

        return Color.white.opacity(0.08)
    }
}
