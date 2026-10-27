import SwiftUI
import UIKit

// MARK: - Anthropic-style palette (adaptive)
//
// The app's scheme, in the manner of Anthropic/Claude's design language,
// with both schemes in one token set:
//
//   Light: warm ivory paper, near-black charcoal ink, hairline rules.
//   Dark:  deep charcoal ground, ivory ink, the same hairlines lifted, the
//          same clay accent slightly brightened to hold contrast.
//
// Everything is flat — rules instead of shadows, no ornament, serif display
// type over a quiet sans body.
//
// (Modifier names keep the previous `manuscript` prefix only so existing
// call sites don't churn.)

extension Color {
    /// A dynamic color that follows the system appearance.
    private static func adaptive(light: UIColor, dark: UIColor) -> Color {
        Color(UIColor { trait in
            trait.userInterfaceStyle == .dark ? dark : light
        })
    }

    /// Page ground: warm ivory `#F0EEE6` / deep charcoal `#1F1E1D`.
    static let paper = adaptive(
        light: UIColor(red: 0.941, green: 0.933, blue: 0.902, alpha: 1),
        dark: UIColor(red: 0.122, green: 0.118, blue: 0.114, alpha: 1))
    /// Lifted surface for cards and panels: `#FAF9F5` / `#2A2926`.
    static let paperLift = adaptive(
        light: UIColor(red: 0.980, green: 0.976, blue: 0.961, alpha: 1),
        dark: UIColor(red: 0.165, green: 0.161, blue: 0.149, alpha: 1))
    /// Hairline rule and divider tone: `#E3DED3` / `#3D3B37`.
    static let rule = adaptive(
        light: UIColor(red: 0.890, green: 0.870, blue: 0.826, alpha: 1),
        dark: UIColor(red: 0.239, green: 0.231, blue: 0.216, alpha: 1))
    /// Primary text ink: warm near-black `#141413` / ivory `#F0EEE6`.
    static let charcoal = adaptive(
        light: UIColor(red: 0.078, green: 0.078, blue: 0.073, alpha: 1),
        dark: UIColor(red: 0.941, green: 0.933, blue: 0.902, alpha: 1))
    /// The Claude terracotta — the app's one saturated accent: `#D97757`,
    /// brightened to `#DD8768` in dark mode so it holds against charcoal.
    static let clay = adaptive(
        light: UIColor(red: 0.851, green: 0.467, blue: 0.341, alpha: 1),
        dark: UIColor(red: 0.867, green: 0.529, blue: 0.408, alpha: 1))
    /// Muted sage — success / Good: `#7A906F` / `#97A98D`.
    static let sage = adaptive(
        light: UIColor(red: 0.478, green: 0.565, blue: 0.439, alpha: 1),
        dark: UIColor(red: 0.592, green: 0.663, blue: 0.553, alpha: 1))
    /// Muted brick — Again, errors, destructive: `#B4533A` / `#CE7560`.
    static let rust = adaptive(
        light: UIColor(red: 0.706, green: 0.325, blue: 0.227, alpha: 1),
        dark: UIColor(red: 0.808, green: 0.459, blue: 0.376, alpha: 1))
    /// Muted slate blue — informational accents: `#6B8A9E` / `#85A3B5`.
    static let slate = adaptive(
        light: UIColor(red: 0.420, green: 0.541, blue: 0.620, alpha: 1),
        dark: UIColor(red: 0.522, green: 0.639, blue: 0.710, alpha: 1))

    /// Text ink at partial strength — caption and secondary text tones.
    static func charcoal(_ opacity: Double) -> Color { .charcoal.opacity(opacity) }
}

extension View {
    /// The full-page ground: flat paper carrying two diagonal color washes —
    /// a clay glow entering from the top-left, a slate wash from the
    /// bottom-right. A middle ground between the flat reference-style paper
    /// and the original design's strong gradient: clearly a gradient, still
    /// composed. Replaces the dark `HomeBackground` image on every screen.
    func manuscriptBackground() -> some View {
        Color.paper
            .overlay(
                LinearGradient(colors: [.clay.opacity(0.35), .clear],
                               startPoint: .topLeading, endPoint: UnitPoint(x: 0.85, y: 0.55))
            )
            .overlay(
                LinearGradient(colors: [.slate.opacity(0.28), .clear],
                               startPoint: .bottomTrailing, endPoint: UnitPoint(x: 0.12, y: 0.45))
            )
            .overlay(
                RadialGradient(colors: [.clay.opacity(0.12), .clear],
                               center: UnitPoint(x: 0.5, y: 1.15), startRadius: 0, endRadius: 520)
            )
            .ignoresSafeArea()
    }

    /// The card surface: a lifted panel on the paper ground, edged with a
    /// single hairline rule and the faintest shadow. Anthropic's UI carries
    /// its structure in these rules, not in elevation. Replaces
    /// `cardStyle()`.
    func manuscriptPanel(radius: CGFloat = 14) -> some View {
        background(Color.paperLift)
            .clipShape(RoundedRectangle(cornerRadius: radius))
            .overlay(RoundedRectangle(cornerRadius: radius)
                .strokeBorder(Color.rule, lineWidth: 1))
            .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
    }
}
