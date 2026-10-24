import SwiftUI
import SwiftData
import UIKit

// MARK: - Daily Review
//
// One active-recall session across every technique: gallery bindings, palace
// stations, and peg slots. Prompt first, reveal second, then a simple
// Again / Good / Easy schedule.

struct ReviewView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \GalleryCard.createdAt, order: .reverse) private var cards: [GalleryCard]
    @Query(sort: \MemoryPalace.createdAt, order: .reverse) private var palaces: [MemoryPalace]
    @Query(sort: \PegList.createdAt, order: .reverse) private var pegLists: [PegList]
    @Query private var records: [ReviewRecord]

    @State private var queue: [ReviewItem] = []
    @State private var index = 0
    @State private var revealed = false
    @State private var reviewed = 0
    @State private var built = false
    /// How many times a card has been pushed back this session. Caps the
    /// "Again" loop at two requeues so a session can still finish.
    @State private var againCounts: [String: Int] = [:]
    /// Records touched this session, so a requeued card updates the same row
    /// even if the @Query hasn't refreshed yet (which would otherwise insert
    /// a duplicate unique key).
    @State private var sessionRecords: [String: ReviewRecord] = [:]

    private enum Rating { case again, good, easy }

    private var allItems: [ReviewItem] {
        ReviewBuilder.items(cards: cards, palaces: palaces, pegLists: pegLists)
    }

    private var recordByKey: [String: ReviewRecord] {
        Dictionary(records.map { ($0.itemKey, $0) }, uniquingKeysWith: { a, _ in a })
    }

    private var artByFact: [String: Data] {
        var map: [String: Data] = [:]
        for card in cards where card.imageData != nil {
            if map[card.fact] == nil { map[card.fact] = card.imageData }
        }
        return map
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            Image("HomeBackground").resizable().scaledToFill().ignoresSafeArea().opacity(0.9)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("DAILY REVIEW")
                        .font(.caption.monospaced()).foregroundColor(.white.opacity(0.7))
                        .padding(.top, 8)

                    content
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
        }
        .navigationTitle("Review")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task {
            if !built { buildQueue() }
        }
    }

    @ViewBuilder
    private var content: some View {
        if !built {
            ProgressView().tint(.white)
                .frame(maxWidth: .infinity).padding().cardStyle()
        } else if allItems.isEmpty {
            emptyCard
        } else if queue.isEmpty {
            caughtUpCard
        } else if index >= queue.count {
            summaryCard
        } else {
            reviewCard(queue[index])
        }
    }

    // MARK: - Cards

    private var emptyCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Nothing to review yet.")
                .font(.subheadline).foregroundColor(.white.opacity(0.9))
            Text("Save a mnemonic, build a palace, or add a peg. Everything shows up here for active recall.")
                .font(.caption).foregroundColor(.white.opacity(0.65))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding().cardStyle()
    }

    private var caughtUpCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("All caught up.")
                .font(.title2.bold()).foregroundColor(.white)
            Text("\(allItems.count) item\(allItems.count == 1 ? "" : "s") in your decks. Come back when a few are due — or review anyway.")
                .font(.subheadline).foregroundColor(.white.opacity(0.7))
            Button {
                buildQueue(forceAll: true)
            } label: {
                Text("Review 20 anyway")
                    .font(.headline).foregroundColor(.black)
                    .frame(maxWidth: .infinity).padding(14)
                    .background(Color.white).cornerRadius(14)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding().cardStyle()
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Session done.")
                .font(.title2.bold()).foregroundColor(.white)
            Text("\(reviewed) recall attempt\(reviewed == 1 ? "" : "s"). Again comes back in 10 minutes; Good in 3 days; Easy in a week.")
                .font(.subheadline).foregroundColor(.white.opacity(0.7))
            Button {
                dismiss()
            } label: {
                Text("Done")
                    .font(.headline).foregroundColor(.black)
                    .frame(maxWidth: .infinity).padding(14)
                    .background(Color.white).cornerRadius(14)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding().cardStyle()
    }

    private func reviewCard(_ item: ReviewItem) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            RainbowProgressBar(value: Double(index) / Double(max(queue.count, 1)))

            HStack(spacing: 8) {
                Label(item.source.title, systemImage: item.source.icon)
                    .font(.caption.monospaced()).rainbow()
                Spacer()
                Text("\(index + 1) OF \(queue.count)")
                    .font(.caption.monospaced()).foregroundColor(.white.opacity(0.5))
            }

            Text(item.prompt)
                .font(item.source == .major
                      ? .system(size: 44, weight: .black, design: .monospaced)
                      : .system(size: 30, weight: .black))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 8)

            if revealed {
                if let fact = item.imageFact,
                   let data = artByFact[fact],
                   let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable().scaledToFit()
                        .frame(maxHeight: 220).frame(maxWidth: .infinity)
                        .cornerRadius(14)
                        .overlay(RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.white.opacity(0.15)))
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(item.answer)
                        .font(.title2.bold()).foregroundColor(.white)
                    if !item.detail.isEmpty {
                        Text(item.detail)
                            .font(.subheadline).foregroundColor(.white.opacity(0.7))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16).cardStyle()

                HStack(spacing: 10) {
                    ratingButton("Again", color: .red.opacity(0.85)) { rate(.again) }
                    ratingButton("Good", color: .green.opacity(0.85), rainbow: true) { rate(.good) }
                    ratingButton("Easy", color: .blue.opacity(0.85)) { rate(.easy) }
                }
            } else {
                Button {
                    Haptics.reveal()
                    withAnimation { revealed = true }
                } label: {
                    Text("Reveal")
                        .font(.headline).foregroundColor(.black)
                        .frame(maxWidth: .infinity).padding(14)
                        .background(Color.white).cornerRadius(14)
                }
                .buttonStyle(.plain)
            }
        }
        .padding().cardStyle()
    }

    private func ratingButton(_ title: String, color: Color, rainbow: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.bold()).foregroundColor(.black)
                .frame(maxWidth: .infinity).padding(.vertical, 12)
                .background {
                    if rainbow { RainbowGradient() } else { color }
                }
                .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Queue and scheduling

    private func buildQueue(forceAll: Bool = false) {
        let due = ReviewBuilder.dueItems(cards: cards, palaces: palaces,
                                         pegLists: pegLists, records: records)
        let source = forceAll ? allItems : due
        queue = Array(source.shuffled().prefix(20))
        index = 0
        revealed = false
        reviewed = 0
        againCounts = [:]
        sessionRecords = [:]
        built = true
    }

    private func rate(_ rating: Rating) {
        guard queue.indices.contains(index) else { return }
        let item = queue[index]

        let record: ReviewRecord
        if let touched = sessionRecords[item.id] {
            record = touched
        } else if let existing = recordByKey[item.id] {
            record = existing
            sessionRecords[item.id] = existing
        } else {
            let fresh = ReviewRecord(itemKey: item.id)
            modelContext.insert(fresh)
            sessionRecords[item.id] = fresh
            record = fresh
        }

        let now = Date()
        record.lastReviewedAt = now
        switch rating {
        case .again:
            record.streak = 0
            record.lapses += 1
            record.dueAt = now.addingTimeInterval(10 * 60)
            Haptics.warning()
        case .good:
            record.streak += 1
            record.dueAt = now.addingTimeInterval(3 * 24 * 60 * 60)
            Haptics.success()
        case .easy:
            record.streak += 1
            record.dueAt = now.addingTimeInterval(7 * 24 * 60 * 60)
            Haptics.success()
        }

        try? modelContext.save()
        reviewed += 1

        // Put "Again" cards back in this session so the second attempt is
        // immediate. Two requeues max keeps the session finite.
        if rating == .again, againCounts[item.id, default: 0] < 2 {
            againCounts[item.id, default: 0] += 1
            withAnimation { queue.append(item) }
        }

        withAnimation {
            index += 1
            revealed = false
        }
        if index >= queue.count, rating == .again { Haptics.success() }
    }
}

#Preview {
    NavigationStack { ReviewView() }
        .demoModelContainer()
}
