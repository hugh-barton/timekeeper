import SwiftUI

struct SymbolPickerView: View {
    @Binding var selection: String
    let accentColor: Color

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private let columns = [
        GridItem(.adaptive(minimum: 68, maximum: 88), spacing: 12)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(filteredOptions) { option in
                        Button {
                            selection = option.name
                            dismiss()
                        } label: {
                            VStack(spacing: 10) {
                                Image(systemName: option.name)
                                    .font(.system(size: 22, weight: .medium))
                                    .foregroundStyle(selection == option.name ? accentColor : .white)
                                    .frame(width: 36, height: 36)

                                Text(option.label)
                                    .font(.caption2.weight(.medium))
                                    .foregroundStyle(.white.opacity(0.88))
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 92)
                            .padding(.horizontal, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color.white.opacity(selection == option.name ? 0.12 : 0.05))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(selection == option.name ? accentColor : Color.white.opacity(0.08), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Choose Symbol")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search symbols")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var filteredOptions: [HabitSymbolOption] {
        let trimmedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSearch.isEmpty else { return HabitSymbolOption.all }

        return HabitSymbolOption.all.filter { option in
            option.label.localizedCaseInsensitiveContains(trimmedSearch)
                || option.name.localizedCaseInsensitiveContains(trimmedSearch)
        }
    }
}

