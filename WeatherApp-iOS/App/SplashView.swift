import SwiftUI

/// Brief branded splash shown at cold launch while the session restores,
/// with a minimum on-screen duration set by `RootView` so it never just
/// flashes by on a fast Keychain read. Reuses the "clear sky" gradient from
/// `WeatherConditionStyle` so the background matches the app icon's own
/// sky-to-sea palette instead of introducing a second set of brand colors.
struct SplashView: View {
    @State private var logoAppeared = false
    @State private var textAppeared = false
    @State private var isPulsing = false

    private var skyGradient: [Color] {
        WeatherConditionStyle.style(for: "clear sky").gradient
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: skyGradient, startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            TimelineView(.animation) { context in
                let time = context.date.timeIntervalSinceReferenceDate
                WaveShape(phase: time * 0.6, amplitude: 10, wavelength: 220)
                    .fill(Color.white.opacity(0.14))
                    .frame(height: 140)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                WaveShape(phase: time * 0.6 + 1.4, amplitude: 14, wavelength: 260)
                    .fill(Color.white.opacity(0.10))
                    .frame(height: 110)
                    .frame(maxHeight: .infinity, alignment: .bottom)
            }
            .ignoresSafeArea()

            VStack(spacing: 18) {
                Spacer()

                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.25))
                        .frame(width: 150, height: 150)
                        .blur(radius: 20)
                        .scaleEffect(isPulsing ? 1.12 : 0.92)

                    Image("LaunchLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 108, height: 108)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .shadow(color: .black.opacity(0.25), radius: 14, y: 8)
                }
                .scaleEffect(logoAppeared ? 1 : 0.6)
                .opacity(logoAppeared ? 1 : 0)

                VStack(spacing: 4) {
                    Text("WeatherApp")
                        .font(.title.weight(.bold))
                    Text("Sol, marés e o que mais precisares de saber")
                        .font(.subheadline)
                        .opacity(0.85)
                }
                .foregroundStyle(.white)
                .opacity(textAppeared ? 1 : 0)
                .offset(y: textAppeared ? 0 : 10)

                Spacer()

                VStack(spacing: 2) {
                    Text("Criado por David Arsénio Martins")
                    Text("ividi.dev")
                    Text("github.com/VidiPT89")
                }
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.75))
                .padding(.bottom, 32)
                .opacity(textAppeared ? 1 : 0)
            }
        }
        .onAppear {
            // Delays nudged slightly later than the original 1.4s-duration
            // splash now that `minimumSplashDuration` (RootView) is ~2.3s --
            // keeps the entrance from finishing with a long stretch of dead
            // time before the screen dismisses.
            withAnimation(.spring(response: 0.6, dampingFraction: 0.65)) {
                logoAppeared = true
            }
            withAnimation(.easeOut(duration: 0.5).delay(0.35)) {
                textAppeared = true
            }
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true).delay(0.6)) {
                isPulsing = true
            }
        }
    }
}

/// A single horizontal sine wave, used to echo the app icon's sea motif with
/// gentle continuous motion in the splash background.
private struct WaveShape: Shape {
    var phase: Double
    let amplitude: Double
    let wavelength: Double

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let midHeight = rect.height * 0.35
        path.move(to: CGPoint(x: 0, y: midHeight))

        let step = 4.0
        var x = 0.0
        while x <= rect.width {
            let angle = (x / wavelength) * 2 * .pi + phase
            let y = midHeight + sin(angle) * amplitude
            path.addLine(to: CGPoint(x: x, y: y))
            x += step
        }

        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.addLine(to: CGPoint(x: 0, y: rect.height))
        path.closeSubpath()
        return path
    }
}

#Preview {
    SplashView()
}
