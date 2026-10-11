import SwiftUI
import UIKit

// MARK: - Assisted mnemonic flow
// Five states matching the wireframe: entry → fact → candidates →
// scene review (Again/Good) → gallery. Apple Intelligence proposes the
// words; every word is re-checked on-device, and any AI failure falls
// back to guaranteed algorithmic candidates. A debug log panel records
// each step. Debug lines append to /tmp/memorydebug.log.
// Scene art: one Gemini illustration per chosen scene (manual trigger,
// dev key required); otherwise a placeholder slot.

struct MockCandidate: Identifiable, Hashable {
    let word: String
    let tie: String
    var id: String { word }
}

struct SavedMnemonicCard: Identifiable {
    let id = UUID()
    let fact: String
    let digits: String
    let word: String
    let tie: String
    let imageData: Data?
}

struct AssistedMnemonicView: View {
    enum Step { case entry, fact, candidates, scene, gallery }

    static let demoFact = "The boiling point of water is 212 fahrenheit"

    /// The 212 trio from the wireframe. All three re-encode to 212
    /// (W/H/Y + vowels skipped: W-N-T-N, N-D-N, N-T-N).
    static let demoCandidates: [MockCandidate] = [
        MockCandidate(word: "Wonton", tie: "Boiling in water"),
        MockCandidate(word: "Undine", tie: "An undine is a water spirit from folklore"),
        MockCandidate(word: "Antoine", tie: "The Antoine equation gives a liquid's vapor pressure")
    ]

    @State private var factText = demoFact
    @State private var step: Step = .entry
    @State private var candidates: [MockCandidate] = []
    @State private var selected: MockCandidate? = nil
    @State private var artVariant = 1
    @State private var gallery: [SavedMnemonicCard] = []
    @State private var aiLoading = false
    @State private var aiError: String? = nil
    @State private var sceneImageData: Data? = nil
    @State private var imageLoading = false
    @State private var imageError: String? = nil
    @State private var imageAttempted = false
    @State private var aiAttemptedDigits: String? = nil
    @State private var candidateSource = "none yet"

    /// File debug log: appends timestamped lines to /tmp/memorydebug.log
    /// (falls back to the app temp dir if /tmp is unwritable) + console.
    private func dlog(_ message: String) {
        let time = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        let line = "[\(time)] \(message)\n"
        print("[AssistedAI] \(message)")
        let fm = FileManager.default
        var url = URL(fileURLWithPath: "/tmp/memorydebug.log")
        if !fm.fileExists(atPath: "/tmp/memorydebug.log") && !fm.createFile(atPath: "/tmp/memorydebug.log", contents: nil) {
            url = fm.temporaryDirectory.appendingPathComponent("memorydebug.log")
        }
        if let handle = try? FileHandle(forWritingTo: url) {
            handle.seekToEndOfFile()
            handle.write(line.data(using: .utf8) ?? Data())
            try? handle.close()
        }
    }

    private var digits: String {
        // First run of digits in the fact, e.g. "…212…" → "212".
        let pattern = "\\d+"
        guard let range = factText.range(of: pattern, options: .regularExpression) else { return "" }
        return String(factText[range])
    }

    var body: some View {
        VStack(spacing: 16) {
            switch step {
            case .entry: entryStep
            case .fact: factStep
            case .candidates: candidatesStep
            case .scene: sceneStep
            case .gallery: galleryStep
            }
        }
    }

    // MARK: - 1: Entry (empty card slot + fact field)

    private var entryStep: some View {
        VStack(spacing: 16) {
            PlaceholderImageView(
                label: "FACT CARD: your fact appears here once you type it below",
                icon: "text.bubble"
            )

            VStack(alignment: .leading, spacing: 8) {
                Text("YOUR FACT").font(.caption.monospaced()).foregroundColor(.white.opacity(0.7))
                TextField("e.g. The boiling point of water is 212 fahrenheit", text: $factText, axis: .vertical)
                    .font(.body).foregroundColor(.white)
                    .padding().background(Color.white.opacity(0.1)).cornerRadius(14)
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.3)))
                    .lineLimit(3...6)
            }

            Button("Continue") { step = .fact }
                .disabled(factText.trimmingCharacters(in: .whitespaces).isEmpty)
                .font(.headline).foregroundColor(.black)
                .frame(maxWidth: .infinity).padding()
                .background(factText.trimmingCharacters(in: .whitespaces).isEmpty ? Color.gray : Color.white)
                .cornerRadius(12)
        }
    }

    // MARK: - 2: Fact confirm

    private var factStep: some View {
        VStack(spacing: 16) {
            factCard

            Button("Find words") {
                candidates = candidatesFor(digits: digits)
                dlog("Find words tapped — fact has digits '\(digits)'; showing \(candidates.count) from \(candidateSource).")
                step = .candidates
            }
            .font(.headline).foregroundColor(.black)
            .frame(maxWidth: .infinity).padding()
            .background(Color.white).cornerRadius(12)

            Button("Edit fact") { step = .entry }
                .font(.subheadline.bold()).foregroundColor(.white.opacity(0.7))
        }
    }

    // MARK: - 3: Candidates (fact pinned, word bubbles)

    private var candidatesStep: some View {
        VStack(spacing: 16) {
            factCard

            aiStatusRow

            if candidates.isEmpty {
                VStack(spacing: 8) {
                    Text("No words for “\(digits)” yet — not from Apple Intelligence, not from the built-in search.")
                        .font(.subheadline).foregroundColor(.white.opacity(0.75))
                        .multilineTextAlignment(.center)
                    Text("The demo fact (212) has Wonton, Undine and Antoine ready.")
                        .font(.caption).foregroundColor(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                    Button("Use demo fact") {
                        factText = Self.demoFact
                        candidates = Self.demoCandidates
                        candidateSource = "demo trio"
                        dlog("User switched to demo fact; showing demo trio.")
                    }
                    .font(.subheadline.bold()).foregroundColor(.black)
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(Color.white).cornerRadius(10)
                }
                .padding().cardStyle()
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    Text("PICK A WORD FOR \(digits) · VIA \(candidateSource.uppercased())")
                        .font(.caption.monospaced()).foregroundColor(.white.opacity(0.7))
                    ForEach(candidates) { c in
                        Button {
                            selected = c
                            artVariant = 1
                            dlog("Selected '\(c.word)' for scene review.")
                            step = .scene
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(c.word).font(.headline).foregroundColor(.white)
                                Text(c.tie).font(.caption).foregroundColor(.white.opacity(0.65))
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding().background(Color.white.opacity(0.08)).cornerRadius(14)
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.25)))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Button("Back to fact") { step = .fact }
                .font(.subheadline.bold()).foregroundColor(.white.opacity(0.7))
        }
        .onAppear {
            // Apple Intelligence writes the words for the user's own fact.
            // Art stays a placeholder slot — one scene image per arbitrary
            // word is not something we can pre-make.
            dlog("Candidates shown for '\(digits)'. AI available: \(MajorLLMService.isAppleIntelligenceAvailable). Reason: '\(MajorLLMService.unavailableReason)'.")
            if (MajorLLMService.isAppleIntelligenceAvailable || GeminiService.hasKey) && aiAttemptedDigits != digits {
                Task { await runAICandidates() }
            } else if !MajorLLMService.isAppleIntelligenceAvailable && !GeminiService.hasKey {
                dlog("Skipping AI (none available) — algorithmic candidates stand.")
            }
        }
    }

    // MARK: - Apple Intelligence candidates (words only, locally verified)

    @ViewBuilder
    private var aiStatusRow: some View {
        if MajorLLMService.isAppleIntelligenceAvailable || GeminiService.hasKey {
            if aiLoading {
                HStack(spacing: 10) {
                    ProgressView().tint(.white)
                    Text("Asking AI for words…")
                        .font(.subheadline).foregroundColor(.white.opacity(0.8))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding().cardStyle()
            } else {
                if let err = aiError {
                    Text(err).font(.caption).foregroundColor(.orange)
                        .multilineTextAlignment(.center)
                }
                Button(aiAttemptedDigits == nil ? "Suggest words with AI" : "Regenerate suggestions") {
                    Task { await runAICandidates() }
                }
                .font(.subheadline.bold()).foregroundColor(.black)
                .frame(maxWidth: .infinity).padding(12)
                .background(Color.white).cornerRadius(12)
            }
        } else {
            Text("No AI available here (Apple Intelligence off, no Gemini key) — showing built-in words.")
                .font(.caption).foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
        }
    }

    /// Checks provider-proposed words on-device: single word only, and its
    /// code (bundled CMU phonetics first, naive encoder as backup) must
    /// equal the target digits exactly. Returns at most 3 survivors.
    private func verify(_ raw: [(word: String, tie: String)], against target: String) -> [MockCandidate] {
        var valid: [MockCandidate] = []
        for c in raw {
            let trimmed = c.word.trimmingCharacters(in: .whitespaces)
            let single = !trimmed.contains(" ")
            // Real CMU phonetics first; naive encoder only when the
            // bundled database does not know the word at all.
            let code = MajorTools.digits(for: trimmed) ?? MajorSystem.digits(for: trimmed)
            let via = MajorTools.digits(for: trimmed) == nil ? "naive" : "db"
            if single && code == target {
                dlog("ACCEPT '\(c.word)' via \(via) — code \(code) matches \(target).")
                valid.append(MockCandidate(word: c.word, tie: c.tie))
            } else {
                dlog("REJECT '\(c.word)' via \(via) — single=\(single), code '\(code)' vs '\(target)'.")
            }
            if valid.count == 3 { break }
        }
        return valid
    }

    /// Provider chain: Apple Intelligence → Gemini (dev key) →
    /// bundled-database algorithmic (always works). Every proposed word
    /// is verified on-device; failures fall through with debug logging.
    private func runAICandidates() async {
        let target = digits
        guard !target.isEmpty else {
            dlog("AI fetch skipped — no digits in fact.")
            return
        }
        dlog("AI fetch started — fact: '\(factText.prefix(60))', digits: '\(target)'. Apple available: \(MajorLLMService.isAppleIntelligenceAvailable). Gemini key: \(GeminiService.hasKey ? "present" : "absent").")
        aiLoading = true
        aiError = nil
        defer { aiLoading = false }

        // Each provider is verified independently: if Apple returns words
        // but none survive on-device checking, Gemini still gets a turn
        // before the algorithmic fallback.
        var valid: [MockCandidate] = []
        var provider = "none"
        if MajorLLMService.isAppleIntelligenceAvailable {
            do {
                let raw = try await MajorLLMService.generateCandidates(fact: factText, digits: target).map { (word: $0.word, tie: $0.tie) }
                dlog("Apple Intelligence returned \(raw.count): \(raw.map(\.word).joined(separator: ", ")).")
                valid = verify(raw, against: target)
                if !valid.isEmpty { provider = "Apple Intelligence" }
                else { dlog("Apple Intelligence gave nothing usable — trying next provider.") }
            } catch {
                dlog("Apple Intelligence threw: \(error.localizedDescription). Trying next provider.")
            }
        } else {
            dlog("Apple Intelligence unavailable: '\(MajorLLMService.unavailableReason)'.")
        }
        if valid.isEmpty && GeminiService.hasKey {
            do {
                let raw = try await GeminiService.generateCandidates(fact: factText, digits: target).map { (word: $0.word, tie: $0.tie) }
                dlog("Gemini returned \(raw.count): \(raw.map(\.word).joined(separator: ", ")).")
                valid = verify(raw, against: target)
                if !valid.isEmpty { provider = "Gemini (\(GeminiService.defaultModel))" }
                else { dlog("Gemini gave nothing usable — falling back to algorithm.") }
            } catch {
                dlog("Gemini threw: \(error.localizedDescription). Falling back to algorithm.")
            }
        } else if valid.isEmpty {
            dlog("Gemini skipped (no API key in Config/Secrets.xcconfig).")
        }

        aiAttemptedDigits = target
        if valid.isEmpty {
            candidates = algorithmicCandidates(digits: target)
            let tried = provider == "none" ? "no AI provider ran" : "\(provider) gave nothing usable"
            aiError = "\(tried.prefix(1).uppercased() + tried.dropFirst()) — fell back to built-in search (\(candidates.count) word(s))."
            dlog("0 valid from AI — algorithmic fallback engaged (\(candidateSource), \(candidates.count)).")
        } else {
            candidates = valid
            candidateSource = "\(provider) (\(valid.count) verified)"
            dlog("Showing \(valid.count) \(provider) word(s), all verified on-device.")
        }
    }

    // MARK: - 4: Scene review (Again / Good)

    private var sceneStep: some View {
        VStack(spacing: 16) {
            factCard

            if let c = selected {
                VStack(alignment: .leading, spacing: 2) {
                    Text(c.word).font(.headline).foregroundColor(.white)
                    Text(c.tie).font(.caption).foregroundColor(.white.opacity(0.65))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding().background(Color.white.opacity(0.08)).cornerRadius(14)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.green.opacity(0.6)))

                sceneArtView(for: c)

                HStack(spacing: 12) {
                    Button("Again") {
                        artVariant += 1
                        if GeminiService.hasKey {
                            Task { await runSceneImage(for: c) }
                        }
                    }
                        .font(.headline).foregroundColor(.white)
                        .frame(maxWidth: .infinity).padding()
                        .background(Color.white.opacity(0.12)).cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.3)))
                    Button("Good") {
                        gallery.append(SavedMnemonicCard(fact: factText, digits: digits, word: c.word, tie: c.tie, imageData: sceneImageData))
                        step = .gallery
                    }
                    .font(.headline).foregroundColor(.black)
                    .frame(maxWidth: .infinity).padding()
                    .background(Color.white).cornerRadius(12)
                }

                Button("Pick another word") {
                    selected = nil
                    sceneImageData = nil
                    imageError = nil
                    imageAttempted = false
                    step = .candidates
                }
                    .font(.subheadline.bold()).foregroundColor(.white.opacity(0.7))
            }
        }
    }

    // MARK: - Scene art (one Gemini illustration per chosen scene)

    @ViewBuilder
    private func sceneArtView(for c: MockCandidate) -> some View {
        if let data = sceneImageData, let img = UIImage(data: data) {
            Image(uiImage: img)
                .resizable().scaledToFit()
                .cornerRadius(14)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.green.opacity(0.6)))
        } else if imageLoading {
            HStack(spacing: 10) {
                ProgressView().tint(.white)
                Text("Illustrating this scene…")
                    .font(.subheadline).foregroundColor(.white.opacity(0.8))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding().cardStyle()
        } else if GeminiService.hasKey {
            VStack(spacing: 6) {
                if let err = imageError {
                    Text(err).font(.caption).foregroundColor(.orange)
                        .multilineTextAlignment(.center)
                }
                Button(imageAttempted ? "Regenerate illustration" : "Illustrate this scene") {
                    Task { await runSceneImage(for: c) }
                }
                .font(.subheadline.bold()).foregroundColor(.black)
                .frame(maxWidth: .infinity).padding(12)
                .background(Color.white).cornerRadius(12)
                Text("One AI picture per scene — needs network + quota.")
                    .font(.caption2).foregroundColor(.white.opacity(0.5))
            }
        } else {
            PlaceholderImageView(
                label: "SCENE ART v\(artVariant): \(c.word.lowercased()) scene for “\(factText.prefix(40))…”",
                icon: "photo"
            )
        }
    }

    /// Manual image fetch: one picture per scene, stale art cleared first.
    private func runSceneImage(for c: MockCandidate) async {
        dlog("Scene image requested — word: '\(c.word)', fact: '\(factText.prefix(50))'.")
        imageLoading = true
        imageError = nil
        imageAttempted = true
        sceneImageData = nil
        defer { imageLoading = false }
        do {
            sceneImageData = try await GeminiService.generateSceneImage(fact: factText, word: c.word, tie: c.tie)
            dlog("Scene image ready — \(sceneImageData?.count ?? 0) bytes.")
        } catch {
            imageError = "Illustration failed (\(error.localizedDescription)) — you can still tap Good."
            dlog("Scene image failed: \(error.localizedDescription).")
        }
    }

    // MARK: - 5: Gallery

    private var galleryStep: some View {
        VStack(spacing: 16) {
            Text("GALLERY")
                .font(.caption.monospaced()).foregroundColor(.white.opacity(0.7))
                .frame(maxWidth: .infinity, alignment: .leading)

            if gallery.isEmpty {
                Text("Nothing saved yet — tap Good on a scene to keep it here.")
                    .font(.subheadline).foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center).padding().cardStyle()
            } else {
                ForEach(gallery) { card in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(card.fact).font(.subheadline).foregroundColor(.white.opacity(0.9))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(card.word).font(.headline).foregroundColor(.white)
                            Text(card.tie).font(.caption).foregroundColor(.white.opacity(0.65))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10).background(Color.black.opacity(0.4)).cornerRadius(10)
                        if let data = card.imageData, let img = UIImage(data: data) {
                            Image(uiImage: img)
                                .resizable().scaledToFit()
                                .cornerRadius(10)
                        } else {
                            PlaceholderImageView(
                                label: "SAVED ART: \(card.word.lowercased()) scene",
                                icon: "photo"
                            )
                        }
                    }
                    .padding().cardStyle()
                }
            }

            Button("New fact") {
                factText = ""
                candidates = []
                selected = nil
                sceneImageData = nil
                imageError = nil
                imageAttempted = false
                step = .entry
            }
            .font(.headline).foregroundColor(.black)
            .frame(maxWidth: .infinity).padding()
            .background(Color.white).cornerRadius(12)
        }
    }

    // MARK: - Pieces

    private var factCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(factText.isEmpty ? "…" : factText)
                .font(.headline).foregroundColor(.white).lineSpacing(3)
            if !digits.isEmpty {
                Text(digits.map(String.init).joined(separator: " "))
                    .font(.caption.monospaced()).foregroundColor(.green)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding().background(Color.white.opacity(0.08)).cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.25)))
    }

    /// Guaranteed algorithmic fallback. Never empty for non-empty digits:
    /// exact single-word matches first, then per-chunk peg words (the
    /// chunked story always succeeds). Sets `candidateSource` + debug log.
    private func candidatesFor(digits target: String) -> [MockCandidate] {
        algorithmicCandidates(digits: target)
    }

    private func algorithmicCandidates(digits target: String) -> [MockCandidate] {
        guard !target.isEmpty else {
            candidateSource = "none (no digits)"
            dlog("Algorithmic fallback: no digits — nothing to offer.")
            return []
        }
        if target == "212" {
            candidateSource = "built-in demo trio"
            dlog("Algorithmic fallback: 212 → demo trio (Wonton/Undine/Antoine, all verified 212).")
            return Self.demoCandidates
        }
        let exact = MajorTools.to_words(target, limit: 3)
        if !exact.isEmpty {
            candidateSource = "bundled database (\(exact.count) exact)"
            dlog("Algorithmic fallback: \(exact.count) exact match(es): \(exact.map(\.word).joined(separator: ", ")). DB available: \(MajorTools.isAvailable).")
            return exact.map {
                MockCandidate(word: $0.word, tie: "Covers \(target) exactly — verified on-device")
            }
        }
        let result = MajorSystem.search(target)
        var seen = Set<String>()
        var pegs: [MockCandidate] = []
        for (chunk, word) in zip(result.chunkCodes, result.chunkedStory) {
            guard seen.insert(word).inserted else { continue }
            pegs.append(MockCandidate(word: word, tie: "Covers \(chunk) — pair it into a scene"))
            if pegs.count == 3 { break }
        }
        candidateSource = "bundled database (none) + peg story"
        dlog("Algorithmic fallback: no exact match in DB — chunked pegs: \(pegs.map(\.word).joined(separator: ", ")).")
        return pegs
    }
}

#Preview {
    NavigationStack { MajorGeneratorView() }
}
