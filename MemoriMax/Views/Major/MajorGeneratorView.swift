import SwiftUI

// MARK: - Create mnemonics: manual algorithm search + assisted fact flow (UI stub)

struct MajorGeneratorView: View {
    enum Mode: String, CaseIterable { case manual = "Manual"; case assisted = "Assisted" }

    @State private var input = "431050"
    @State private var mode: Mode = .assisted

    private var result: MajorSystem.SearchResult {
        MajorSystem.search(input)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            Image("HomeBackground").resizable().scaledToFill().ignoresSafeArea().opacity(0.9)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    Picker("Mode", selection: $mode) {
                        ForEach(Mode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 4)

                    if mode == .manual {
                        numberField
                        algorithmResults
                    } else {
                        AssistedMnemonicView()
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 30)
            }
        }
        .navigationTitle("Create mnemonic")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    // MARK: - Input

    private var numberField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("YOUR NUMBER").font(.caption.monospaced()).foregroundColor(.white.opacity(0.7))
            TextField("e.g. 431050", text: $input)
                .keyboardType(.numberPad)
                .font(.system(size: 28, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .padding()
                .background(Color.white.opacity(0.1))
                .cornerRadius(14)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.3)))
                .onChange(of: input) { _, v in input = MajorSystem.sanitizedDigits(v) }
            if !result.digits.isEmpty {
                Text("Encoding \(result.digits.count) digits: \(result.digits.map(String.init).joined(separator: " "))")
                    .font(.caption.monospaced()).foregroundColor(.white.opacity(0.6))
            }
        }
    }

    // MARK: - Algorithm (offline search)

    private var algorithmResults: some View {
        VStack(spacing: 14) {
            if result.digits.isEmpty {
                Text("Type digits above to get instant word matches — fully offline.")
                    .font(.subheadline).foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center).padding()
            } else {
                // Chunked story — always works
                resultCard(title: "📖 Easiest story (chunked by 2)") {
                    Text(result.chunkedStory.joined(separator: "  ·  "))
                        .font(.title3.bold()).foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    Text(zip(result.chunkCodes, result.chunkedStory).map { "\($0) → \($1)" }.joined(separator: "   "))
                        .font(.caption.monospaced()).foregroundColor(.green)
                        .multilineTextAlignment(.center)
                    Text("Say it as one scene: “\(result.chunkedStory.joined(separator: " "))”.")
                        .font(.caption).foregroundColor(.white.opacity(0.7)).italic()
                        .multilineTextAlignment(.center)
                }

                // Exact single-word matches
                resultCard(title: "🎯 One-word matches (\(result.exact.count))") {
                    if result.exact.isEmpty {
                        Text("No single word covers all \(result.digits.count) digits. Try the story above or a two-word combo.")
                            .font(.subheadline).foregroundColor(.white.opacity(0.7))
                    } else {
                        chipWrap(result.exact)
                    }
                }

                // Two-word combos
                if !result.combos.isEmpty {
                    resultCard(title: "🔗 Two-word combos") {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(result.combos.prefix(8), id: \.self) { combo in
                                HStack {
                                    Text("“\(combo)”").font(.headline).foregroundColor(.white)
                                    Spacer()
                                    Text(codeLabel(for: combo))
                                        .font(.caption2.monospaced()).foregroundColor(.green)
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func resultCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.headline).foregroundColor(.white)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.white.opacity(0.08))
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.15)))
    }

    private func chipWrap(_ words: [String]) -> some View {
        // Simple flow layout via flexible wrapping VStack/HStack
        VStack(alignment: .leading, spacing: 8) {
            ForEach(words, id: \.self) { w in
                HStack {
                    Text(w).font(.headline.monospaced()).foregroundColor(.black)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(Color.white).cornerRadius(20)
                    Text(MajorSystem.digits(for: w)).font(.caption.monospaced()).foregroundColor(.green)
                }
            }
        }
    }

    private func codeLabel(for phrase: String) -> String {
        phrase.split(separator: " ").map { MajorSystem.digits(for: String($0)) }.joined(separator: "+")
    }
}

#Preview {
    NavigationStack { MajorGeneratorView() }
}
