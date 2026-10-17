import SwiftUI
import SwiftData

struct Home: View {
    var body: some View {
        ZStack {
            // Background
            Color.black
                .ignoresSafeArea()

            Image("HomeBackground")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            // Content
            VStack {
                VStack(spacing: 16) {
                    Image("brain")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 280, height: 280)

                    Text("“Make your brain smoother, one game at a time.”")
                        .italic()
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .shadow(color: .white, radius: 15)
                }
                .padding(.top, 40)

                Spacer()

                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.black)
                        .frame(width: 200, height: 50)
                        .offset(x: -10, y: 10)

                    NavigationLink(destination: OptionMenu()) {
                        Text("Get Started")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.black)
                            .frame(width: 200, height: 50)
                            .background(Color.white)
                            .cornerRadius(10)
                    }
                }
                .padding(.bottom, 20)
            }
        }
    }
}

#Preview {
    NavigationStack {
        Home()
    }
    .modelContainer(for: GalleryCard.self, inMemory: true)
}
