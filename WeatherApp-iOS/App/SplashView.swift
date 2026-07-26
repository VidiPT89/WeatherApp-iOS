import SwiftUI

/// Brief branded splash shown at cold launch while the session restores,
/// with a minimum on-screen duration set by `RootView` so it never just
/// flashes by on a fast Keychain read.
struct SplashView: View {
    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "cloud.sun.fill")
                .font(.system(size: 64))
                .foregroundStyle(.blue.gradient)

            Text("WeatherApp")
                .font(.title.weight(.semibold))

            Spacer()

            VStack(spacing: 2) {
                Text("Criado por David Arsénio Martins")
                Text("ividi.dev")
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
            .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color("Background"))
    }
}

#Preview {
    SplashView()
}
