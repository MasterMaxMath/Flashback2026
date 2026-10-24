import SwiftUI
import SwiftData
import UIKit

// MARK: - Walk the peg list
//
// Replays the pegs in numeric order. The peg number and fixed word are the
// prompt; the item and its bindings stay hidden until the walker reveals them.

struct PegWalkView: View {
    let list: PegList

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \GalleryCard.createdAt, order: .reverse) private var cards: [GalleryCard]

    @State private var index = 0
    @State private var revealed: Set<UUID> = []

    private var slots: [PegSlot] { list.slots }

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

            if slots.isEmpty {
                VStack(spacing: 12) {
                    Text("This peg list is empty.")
                        .font(.headline).foregroundColor(.white)
                    Text("Go back and add at least one peg to walk it.")
                        .font(.subheadline).foregroundColor(.white.opacity(0.7))
                }
                .padding().cardStyle().padding(20)
            } else {
                VStack(spacing: 0) {
                    progressHeader

                    TabView(selection: $index) {
                        ForEach(Array(slots.enumerated()), id: \.element.id) { i, slot in
                            slotPage(slot).tag(i)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))

                    bottomNav
                }
            }
        }
        .navigationTitle(list.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear {
            list.lastWalkedAt = Date()
            try? modelContext.save()
        }
    }

    private var progressHeader: some View {
        VStack(spacing: 8) {
            Text("PEG \(index + 1) OF \(slots.count)")
                .font(.caption.monospaced()).foregroundColor(.white.opacity(0.7))
                .frame(maxWidth: .infinity, alignment: .leading)
            ProgressView(value: Double(index + 1), total: Double(slots.count))
                .tint(.white).opacity(0.9)
        }
        .padding(.horizontal, 32).padding(.top, 10)
    }

    private func slotPage(_ slot: PegSlot) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                VStack(spacing: 4) {
                    Text("PEG \(slot.number)")
                        .font(.caption.monospaced()).rainbow()
                    Text(slot.pegWord)
                        .font(.system(size: 40, weight: .black))
                        .foregroundColor(.white).multilineTextAlignment(.center)
                }
                .padding(.top, 16)

                artView(for: slot)

                if revealed.contains(slot.id) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(slot.fact)
                            .font(.headline).foregroundColor(.white).lineSpacing(3)
                        ForEach(slot.bindings, id: \.self) { b in
                            VStack(alignment: .leading, spacing: 1) {
                                HStack(alignment: .firstTextBaseline, spacing: 8) {
                                    Text(b.digits).font(.caption.monospaced()).rainbow()
                                    Text(b.word).font(.headline).foregroundColor(.white)
                                }
                                if !b.tie.isEmpty {
                                    Text(b.tie).font(.caption).foregroundColor(.white.opacity(0.65))
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16).cardStyle()
                } else {
                    Text("What's hanging on the \(slot.pegWord)? Picture it, then reveal.")
                        .font(.subheadline).foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                }

                Button {
                    Haptics.reveal()
                    if revealed.contains(slot.id) { revealed.remove(slot.id) }
                    else { revealed.insert(slot.id) }
                } label: {
                    Text(revealed.contains(slot.id) ? "Hide" : "Reveal")
                        .font(.subheadline.bold()).foregroundColor(.black)
                        .frame(maxWidth: .infinity).padding(14)
                        .background(Color.white).cornerRadius(12)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 20)
        }
    }

    @ViewBuilder
    private func artView(for slot: PegSlot) -> some View {
        if let data = artByFact[slot.fact], let img = UIImage(data: data) {
            Image(uiImage: img)
                .resizable().scaledToFit()
                .frame(maxHeight: 240).frame(maxWidth: .infinity)
                .cornerRadius(16)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.15)))
        } else {
            PlaceholderImageView(
                label: "SCENE ART: \(slot.bindings.first?.word.lowercased() ?? slot.fact)",
                icon: "photo"
            )
        }
    }

    private var bottomNav: some View {
        HStack {
            Button("Back") {
                guard index > 0 else { return }
                Haptics.tap()
                withAnimation { index -= 1 }
            }
            .disabled(index == 0).foregroundColor(index == 0 ? .gray : .white)
            Spacer()
            HStack(spacing: 5) {
                ForEach(slots.indices, id: \.self) { i in
                    Circle().fill(i == index ? Color.white : Color.white.opacity(0.3))
                        .frame(width: 6, height: 6)
                }
            }
            Spacer()
            if index < slots.count - 1 {
                Button("Next") {
                    Haptics.tap()
                    withAnimation { index += 1 }
                }
                .foregroundColor(.white).bold()
            } else {
                Button("Done") { dismiss() }
                    .foregroundColor(.black).bold()
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(Color.white).cornerRadius(20)
            }
        }
        .padding(.horizontal, 32).padding(.vertical, 16)
    }
}

#Preview {
    NavigationStack {
        PegWalkView(list: PegList(name: "Shopping"))
    }
    .demoModelContainer()
}
