import SwiftUI
import SwiftData
import UIKit

// MARK: - Saved mnemonics gallery (persistent, shared)
//
// The gallery is organised by tag group. The landing screen lists one row per
// group showing the group name, how many mnemonics it holds, and the latest
// image added to it; tapping a group opens its cards. Cards live in SwiftData;
// art bytes use external storage. `GalleryScreen` adds the app chrome (dark
// background, scrolling, title) for menu entry; the assisted flow embeds
// `GalleryView` directly (already inside the flow's ScrollView).

// MARK: Group model

struct GalleryGroup: Identifiable {
    let tag: String
    let cards: [GalleryCard]        // newest first
    var id: String { tag }
    var count: Int { cards.count }
    var latest: GalleryCard? { cards.first }
}

extension Array where Element == GalleryCard {
    /// Buckets cards by tag (empty → "default"), newest group first.
    func groupedByTag() -> [GalleryGroup] {
        Dictionary(grouping: self) { $0.tag.isEmpty ? "default" : $0.tag }
            .map { GalleryGroup(tag: $0.key, cards: $0.value.sorted { $0.createdAt > $1.createdAt }) }
            .sorted { ($0.latest?.createdAt ?? .distantPast) > ($1.latest?.createdAt ?? .distantPast) }
    }
}

// MARK: Standalone screen (menu entry) — adds app chrome

struct GalleryScreen: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            Image("HomeBackground").resizable().scaledToFill().ignoresSafeArea().opacity(0.9)

            ScrollView(showsIndicators: false) {
                GalleryView()
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 30)
            }
        }
        .navigationTitle("Gallery")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }
}

// MARK: Group landing

struct GalleryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \GalleryCard.createdAt, order: .reverse) private var cards: [GalleryCard]

    private var groups: [GalleryGroup] { cards.groupedByTag() }

    var body: some View {
        VStack(spacing: 16) {
            Text("GALLERY")
                .font(.caption.monospaced()).foregroundColor(.white.opacity(0.7))
                .frame(maxWidth: .infinity, alignment: .leading)

            if groups.isEmpty {
                Text("Nothing saved yet — tap Good on a scene to keep it here, on this device.")
                    .font(.subheadline).foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center).padding().cardStyle()
                Button("Restore demo cards") {
                    Self.seedIfNeeded(context: modelContext)
                }
                .font(.subheadline.bold()).foregroundColor(.white.opacity(0.7))
            } else {
                ForEach(groups) { group in
                    NavigationLink(destination: GalleryGroupView(tag: group.tag)) {
                        groupRow(group)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(group.tag), \(group.count) mnemonic\(group.count == 1 ? "" : "s")")
                }
            }
        }
        .onAppear { Self.seedIfNeeded(context: modelContext) }
    }

    private func groupRow(_ group: GalleryGroup) -> some View {
        HStack(spacing: 14) {
            thumbnail(from: group.latest?.imageData, size: 64)

            VStack(alignment: .leading, spacing: 3) {
                Text(group.tag).font(.headline).foregroundColor(.white)
                Text("\(group.count) mnemonic\(group.count == 1 ? "" : "s")")
                    .font(.caption).foregroundColor(.white.opacity(0.65))
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.subheadline.bold()).foregroundColor(.white.opacity(0.5))
        }
        .padding(12).cardStyle()
    }

    /// Demo content (tutorial dates). For now these are ALWAYS present:
    /// every visit re-inserts any missing ones, so the gallery never
    /// sits empty during development and judging.
    static func seedIfNeeded(context: ModelContext) {
        let demos = [
            ("The Peloponnesian War began in 431 BC",
             "431", "remote", "Remote lands clashed — 431 opens the war"),
            ("The Peloponnesian War ended in 404 BC",
             "404", "razor", "Decided on a razor's edge — 404 closes the war")
        ]
        let existingFacts = Set((try? context.fetch(FetchDescriptor<GalleryCard>()))?.map(\.fact) ?? [])
        var added = 0
        for (fact, digits, word, tie) in demos where !existingFacts.contains(fact) {
            context.insert(GalleryCard(fact: fact, digits: digits, word: word, tie: tie, tag: "default"))
            added += 1
        }
        if added > 0 { try? context.save() }
        AIDebugLog.write("Gallery demo check — re-added \(added) card(s).")
    }
}

// MARK: Group detail — every card in one tag

struct GalleryGroupView: View {
    let tag: String
    @Environment(\.modelContext) private var modelContext
    @Query private var cards: [GalleryCard]

    init(tag: String) {
        self.tag = tag
        let predicate = #Predicate<GalleryCard> { $0.tag == tag }
        _cards = Query(
            filter: predicate,
            sort: [SortDescriptor(\GalleryCard.createdAt, order: .reverse)]
        )
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            Image("HomeBackground").resizable().scaledToFill().ignoresSafeArea().opacity(0.9)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    if cards.isEmpty {
                        Text("This group is empty.")
                            .font(.subheadline).foregroundColor(.white.opacity(0.7))
                            .padding().cardStyle()
                    } else {
                        ForEach(cards) { card in
                            VStack(alignment: .leading, spacing: 8) {
                                MnemonicCardView(card: card)
                                Button("Remove", role: .destructive) {
                                    modelContext.delete(card)
                                    try? modelContext.save()
                                }
                                .font(.caption).foregroundColor(.red.opacity(0.85))
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 30)
            }
        }
        .navigationTitle(tag)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }
}

// MARK: Card + thumbnail

/// One saved mnemonic rendered as a card (fact, word/tie, illustration).
struct MnemonicCardView: View {
    let card: GalleryCard

    var body: some View {
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
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding().cardStyle()
    }
}

/// Small square preview of a card's art (latest image in a group), with a
/// placeholder when there is no art.
@ViewBuilder
func thumbnail(from data: Data?, size: CGFloat) -> some View {
    Group {
        if let data, let img = UIImage(data: data) {
            Image(uiImage: img).resizable().scaledToFill()
        } else {
            Color.white.opacity(0.08)
                .overlay(Image(systemName: "photo").foregroundColor(.white.opacity(0.5)))
        }
    }
    .frame(width: size, height: size)
    .clipped()
    .cornerRadius(10)
    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.15)))
}

#Preview {
    NavigationStack { GalleryScreen() }
        .modelContainer(for: GalleryCard.self, inMemory: true)
}
