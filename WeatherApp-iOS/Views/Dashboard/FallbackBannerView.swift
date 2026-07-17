import SwiftUI

/// Shown only when the weather response's `provider` isn't the primary
/// ("open-meteo") — i.e. the backend's primary provider call failed and it
/// fell back to a secondary one. This is the fallback event the whole app
/// exists to surface, so it's a full-width warning banner, not a subtle pill.
struct FallbackBannerView: View {
    let provider: String

    var body: some View {
        Label {
            Text("Provider principal indisponível — a usar alternativa (\(provider))")
                .font(.footnote.weight(.medium))
        } icon: {
            Image(systemName: "exclamationmark.triangle.fill")
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.yellow.opacity(0.22), in: RoundedRectangle(cornerRadius: 10))
        .foregroundStyle(.orange)
    }
}

#Preview {
    FallbackBannerView(provider: "open-weather-map")
        .padding()
}
