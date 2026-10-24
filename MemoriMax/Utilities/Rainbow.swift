import SwiftUI

// MARK: - Rainbow accent
//
// The old flat green accent is now a slowly cycling rainbow. Every rainbow
// fill on screen runs off the same clock, so all the former greens drift
// through the spectrum together instead of flashing out of sync.

/// A slowly drifting gradient with a narrow, neighboring-hue window. At any
/// instant an element spans only a short arc of the hue wheel (a duotone-ish
/// wash, e.g. teal → blue → violet), and that arc slides through the whole
/// spectrum over `period` seconds — so over minutes you see every color, but
/// an icon never carries the whole rainbow at once.
struct RainbowGradient: View {
    /// Seconds for the hue window to make one full pass of the spectrum.
    /// Slow on purpose: it should read as light shifting, not a screensaver.
    var period: Double = 30
    /// Fraction of the hue wheel a single element spans at any instant.
    /// Small on purpose: keeps each icon inside one hue family.
    var span: Double = 0.2

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 24)) { context in
            let center = context.date.timeIntervalSinceReferenceDate / period
            LinearGradient(
                colors: [0, 0.5, 1].map { fraction in
                    Color(hue: (center + span * fraction).truncatingRemainder(dividingBy: 1),
                          saturation: 0.55, brightness: 0.9)
                },
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

extension View {
    /// Repaints the view's fill with the cycling rainbow while keeping its
    /// exact shape (and its accessibility — the base fill is emptied rather
    /// than hidden). Works on text, SF Symbols, labels, and shapes; color
    /// comes out, form stays.
    func rainbow(period: Double = 10) -> some View {
        foregroundStyle(Color.clear)
            .overlay {
                RainbowGradient(period: period)
                    .mask(self)
                    .allowsHitTesting(false)
            }
    }

    /// Rainbow when `active`, a plain color otherwise — used where the old
    /// code did ternary foreground colors like `selected ? .green : .white`.
    @ViewBuilder
    func rainbow(active: Bool, fallback: Color? = nil, period: Double = 10) -> some View {
        if active {
            self.rainbow(period: period)
        } else if let fallback {
            self.foregroundColor(fallback)
        } else {
            self
        }
    }

    /// Cycling rainbow border. The inactive state keeps the plain white rim
    /// the old ternary strokes used.
    func rainbowRim(cornerRadius: CGFloat,
                    active: Bool = true,
                    lineWidth: CGFloat = 1,
                    inactiveColor: Color = Color.white.opacity(0.2)) -> some View {
        overlay {
            if active {
                RainbowGradient()
                    .mask(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(Color.white, lineWidth: lineWidth)
                    )
                    .allowsHitTesting(false)
            } else {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(inactiveColor, lineWidth: lineWidth)
            }
        }
    }
}

/// Horizontal progress bar with the rainbow fill (replaces the green-tinted
/// ProgressView).
struct RainbowProgressBar: View {
    var value: Double

    var body: some View {
        ZStack(alignment: .leading) {
            Capsule().fill(Color.white.opacity(0.15))
            GeometryReader { geo in
                RainbowGradient()
                    .frame(width: max(0, geo.size.width * min(max(value, 0), 1)))
                    .clipShape(Capsule())
            }
        }
        .frame(height: 4)
    }
}
