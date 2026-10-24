import SwiftUI
import SwiftData

struct OptionMenu: View {
    @Query(sort: \GalleryCard.createdAt, order: .reverse) private var cards: [GalleryCard]
    @Query(sort: \MemoryPalace.createdAt, order: .reverse) private var palaces: [MemoryPalace]
    @Query(sort: \PegList.createdAt, order: .reverse) private var pegLists: [PegList]
    @Query private var records: [ReviewRecord]

    private var reviewDue: Int {
        ReviewBuilder.dueItems(cards: cards, palaces: palaces,
                               pegLists: pegLists, records: records).count
    }

    private var reviewTotal: Int {
        ReviewBuilder.items(cards: cards, palaces: palaces, pegLists: pegLists).count
    }

    private var reviewBadge: String? {
        guard reviewTotal > 0 else { return nil }
        return reviewDue > 0 ? "\(reviewDue) due" : "Clear"
    }

    var body: some View {
        ZStack {
            // Background Layer
            Color.black.ignoresSafeArea()
            Image("HomeBackground").resizable().scaledToFill().ignoresSafeArea()

            // Scrollable Content
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    // Page Title
                    Text("Select Mode")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.top, 20)
                        .shadow(color: .white, radius: 25, x: 0, y: 0)

                    GradientNavLink(
                        title: "Review",
                        subtitle: "Active recall across every technique",
                        systemImage: "arrow.triangle.2.circlepath",
                        badge: reviewBadge,
                        destination: ReviewView()
                    )

                    // Techniques -> router for memory techniques (Major System,
                    // Peg System, Memory Palace, …). Uses a NavigationLink styled
                    // as a menu card (no nested Button, so the whole card is
                    // tappable and VoiceOver-safe).
                    GradientNavLink(
                        title: "Techniques",
                        subtitle: "Learn the Major, Peg, and Palace systems",
                        systemImage: "brain.head.profile",
                        destination: TechniquesView()
                    )

                    GradientNavLink(
                        title: "Gallery",
                        subtitle: "Your scenes, routes, and peg lists",
                        systemImage: "square.grid.2x2",
                        destination: GalleryScreen()
                    )

                    GradientNavLink(
                        title: "Practice",
                        subtitle: "Quiz, walk, and drill",
                        systemImage: "figure.run",
                        destination: PracticeScreen()
                    )
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle("MemoriMax")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }
}

/// The menu's large card link: gradient drop shadow with a black face. The
/// icon, subtitle, and badge are optional so the same component works for the
/// menu, the techniques list, and the practice hub.
struct GradientNavLink<Destination: View>: View {
    let title: String
    var subtitle: String? = nil
    var systemImage: String? = nil
    var badge: String? = nil
    let destination: Destination

    var shadowStartColor: Color = .white
    var shadowEndColor: Color = .black

    var body: some View {
        NavigationLink(destination: destination) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [shadowStartColor, shadowEndColor]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(maxWidth: .infinity)
                    .frame(height: 110)
                    .offset(x: -8, y: 8)

                HStack(spacing: 14) {
                    if let systemImage {
                        Image(systemName: systemImage)
                            .font(.title3)
                            .foregroundColor(.green)
                            .frame(width: 44, height: 44)
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(12)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.system(size: 22, weight: .bold).monospaced())
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                        if let subtitle {
                            Text(subtitle)
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.6))
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    Spacer(minLength: 6)

                    if let badge {
                        Text(badge.uppercased())
                            .font(.caption2.bold().monospaced())
                            .foregroundColor(.black)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(Color.green)
                            .clipShape(Capsule())
                    }

                    Image(systemName: "chevron.right")
                        .font(.subheadline.bold())
                        .foregroundColor(.white.opacity(0.4))
                }
                .padding(.horizontal, 18)
                .frame(maxWidth: .infinity, minHeight: 110, alignment: .leading)
                .background(Color.black)
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(shadowStartColor, lineWidth: 1)
                )
            }
            .padding(.leading, 10)
            .padding(.bottom, 10)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        var parts = ["Open \(title)"]
        if let subtitle { parts.append(subtitle) }
        if let badge { parts.append(badge) }
        return parts.joined(separator: ". ")
    }
}

#Preview {
    NavigationStack {
        OptionMenu()
    }
    .demoModelContainer()
}
