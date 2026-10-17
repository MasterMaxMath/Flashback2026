import SwiftUI

// MARK: - Save-to-gallery tag picker
//
// Shown when the user accepts a scene ("Good"). They pick an existing group
// (always including "default") or create a new one; the chosen tag is written
// onto the saved card so the gallery can group mnemonics.

struct SaveTagSheet: View {
    let word: String
    let fact: String
    /// Tags already in use (may be empty). "default" is always offered.
    let existingTags: [String]
    let onSave: (String) -> Void
    /// Sheet heading (defaults to the save-at-acceptance wording).
    var header: String = "SAVE MNEMONIC"
    /// Label for the confirm button; defaults to "Save to "\(selected)"".
    var confirmLabel: String? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var tags: [String] = ["default"]
    @State private var selected: String = "default"
    @State private var newTag = ""
    @FocusState private var newTagFocused: Bool

    private var trimmedNew: String {
        newTag.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    Text(header)
                        .font(.caption.monospaced()).foregroundColor(.white.opacity(0.7))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(word).font(.title2.bold()).foregroundColor(.white)
                        Text(fact).font(.caption).foregroundColor(.white.opacity(0.6))
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding().cardStyle()

                    Text("CHOOSE A GROUP")
                        .font(.caption.monospaced()).foregroundColor(.white.opacity(0.7))

                    VStack(spacing: 8) {
                        ForEach(tags, id: \.self) { t in
                            Button { selected = t } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: selected == t ? "largecircle.fill.circle" : "circle")
                                        .foregroundColor(selected == t ? .green : .white.opacity(0.5))
                                    Text(t).font(.body).foregroundColor(.white)
                                    Spacer()
                                }
                                .padding().frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.white.opacity(selected == t ? 0.14 : 0.06))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(selected == t ? Color.green.opacity(0.7) : Color.white.opacity(0.2))
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Text("CREATE A NEW GROUP")
                        .font(.caption.monospaced()).foregroundColor(.white.opacity(0.7))

                    HStack(spacing: 10) {
                        TextField("e.g. History", text: $newTag)
                            .font(.body).foregroundColor(.white)
                            .focused($newTagFocused)
                            .padding().background(Color.white.opacity(0.1)).cornerRadius(12)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.3)))
                            .submitLabel(.done)
                            .onSubmit(createTag)
                        Button("Add", action: createTag)
                            .font(.subheadline.bold()).foregroundColor(.black)
                            .padding(.horizontal, 16).padding(.vertical, 12)
                            .background(trimmedNew.isEmpty ? Color.gray : Color.white)
                            .cornerRadius(12)
                            .disabled(trimmedNew.isEmpty)
                    }

                    Button(confirmLabel ?? "Save to “\(selected)”") {
                        onSave(selected)
                        dismiss()
                    }
                    .font(.headline).foregroundColor(.black)
                    .frame(maxWidth: .infinity).padding()
                    .background(Color.white).cornerRadius(12)

                    Button("Cancel") { dismiss() }
                        .font(.subheadline.bold()).foregroundColor(.white.opacity(0.7))
                        .frame(maxWidth: .infinity)
                }
                .padding(20)
            }
        }
        .presentationDetents([.medium, .large])
        .preferredColorScheme(.dark)
        .onAppear {
            // "default" first, then any existing groups alphabetically.
            let others = Set(existingTags).subtracting(["default"]).sorted()
            tags = ["default"] + others
        }
    }

    /// Adds the typed group (if new) and selects it. A name already in the
    /// list is simply selected.
    private func createTag() {
        let name = trimmedNew
        guard !name.isEmpty else { return }
        if !tags.contains(name) { tags.append(name) }
        selected = name
        newTag = ""
        newTagFocused = false
    }
}

#Preview {
    SaveTagSheet(
        word: "Remote",
        fact: "The Peloponnesian War began in 431 BC",
        existingTags: ["History", "Science"],
        onSave: { _ in }
    )
}
