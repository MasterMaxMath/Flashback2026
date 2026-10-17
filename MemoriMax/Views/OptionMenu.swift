import SwiftUI
import SwiftData

struct GradientButton: View {
    let title: String

    // Gradient
    var shadowStartColor: Color = Color.white
    var shadowEndColor: Color = Color.black

    let action: () -> Void

    var body: some View {
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

            Button(action: action) {
                Text(title)
                    .font(.system(size: 24, weight:    .bold).monospaced())
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 110)
                    .background(Color.black)
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(shadowStartColor, lineWidth: 1)
                    )
            }
        }
        .padding(.leading, 10)
        .padding(.bottom, 10)
    }
}

struct OptionMenu: View {
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

                    GradientButton(title: "Memory Cards") {
                        print("Memory Cards selected")
                    }

                    // Major System -> guided slideshow. Uses a NavigationLink
                    // styled identically to GradientButton (no nested Button,
                    // so the whole card is tappable and VoiceOver-safe).
                    GradientNavLink(title: "Major System", destination: MajorIntroView())

                    GradientNavLink(title: "Gallery", destination: GalleryScreen())

                    GradientNavLink(title: "Practice", destination: PracticeScreen())
                }
                .padding(.horizontal, 50)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle("Select Mode")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }
}

/// Navigation variant of GradientButton: identical visuals, but the whole
/// card is a NavigationLink label (avoids a Button nested in a link,
/// which swallows taps and breaks accessibility).
struct GradientNavLink<Destination: View>: View {
    let title: String
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

                Text(title)
                    .font(.system(size: 24, weight: .bold).monospaced())
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 110)
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
        .accessibilityLabel("Open \(title)")
    }
}

#Preview {
    NavigationStack {
        OptionMenu()
    }
    .modelContainer(for: GalleryCard.self, inMemory: true)
}
