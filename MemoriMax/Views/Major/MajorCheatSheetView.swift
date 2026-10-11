import SwiftUI

// MARK: - Standard Major System dictionary / cheatsheet

struct MajorCheatSheetView: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            Image("HomeBackground").resizable().scaledToFill().ignoresSafeArea().opacity(0.9)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    Text("The standard dictionary")
                        .font(.subheadline).foregroundColor(.white.opacity(0.75))
                        .padding(.top, 8)

                    ForEach(MajorSystem.mappings) { m in
                        cheatRow(m)
                    }

                    VStack(spacing: 8) {
                        Text("💡 How to use it")
                            .font(.headline).foregroundColor(.white)
                        Text("Vowels (A E I O U) and W, H, Y are free — they let you turn bare sounds into real words. Example: 39 = M+P → \"map\", \"mop\", \"mob\". 20 = N+S → \"nose\". Chain words to cover long numbers.")
                            .font(.subheadline).foregroundColor(.white.opacity(0.85))
                            .multilineTextAlignment(.center)
                    }
                    .padding().background(Color.white.opacity(0.08)).cornerRadius(16)

                    NavigationLink(destination: MajorGeneratorView()) {
                        Text("✨ Try it on my number →")
                            .font(.headline).foregroundColor(.black)
                            .frame(maxWidth: .infinity).padding()
                            .background(Color.white).cornerRadius(14)
                    }
                    .padding(.bottom, 30)
                }
                .padding(.horizontal, 20)
            }
        }
        .navigationTitle("Cheatsheet")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    private func cheatRow(_ m: MajorMapping) -> some View {
        HStack(spacing: 14) {
            Text(m.digit)
                .font(.system(size: 34, weight: .black, design: .monospaced))
                .foregroundColor(.black)
                .frame(width: 56, height: 56)
                .background(Color.white)
                .cornerRadius(14)
            VStack(alignment: .leading, spacing: 4) {
                Text(m.sounds).font(.headline).foregroundColor(.white)
                Text(m.examples).font(.subheadline).foregroundColor(.white.opacity(0.75))
                Text(m.tip).font(.caption).foregroundColor(.white.opacity(0.6)).italic()
            }
            Spacer()
        }
        .padding(12)
        .background(Color.white.opacity(0.08))
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.15)))
    }
}

#Preview {
    NavigationStack { MajorCheatSheetView() }
}
