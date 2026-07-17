import SwiftUI

/// The cache badge: green "Dados frescos" when the response wasn't cached,
/// amber "Servido da cache há Xs/Xmin/Xh" (ticking live once a second) when it was.
/// Uses `TimelineView` rather than a ViewModel timer so the age recomputation
/// stays purely a view concern, backed by the pure `CacheAgeFormatter`.
struct CacheBadgeView: View {
    let fromCache: Bool
    let observedAt: Date

    var body: some View {
        if fromCache {
            TimelineView(.periodic(from: .now, by: AppConstants.cacheAgeTickInterval)) { context in
                badge(
                    text: "Servido da cache há \(CacheAgeFormatter.formattedAge(observedAt: observedAt, now: context.date))",
                    color: .orange,
                    systemImage: "clock.arrow.circlepath"
                )
            }
        } else {
            badge(text: "Dados frescos", color: .green, systemImage: "checkmark.circle.fill")
        }
    }

    private func badge(text: String, color: Color, systemImage: String) -> some View {
        Label(text, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(color.opacity(0.18), in: Capsule())
            .foregroundStyle(color)
            .accessibilityIdentifier(fromCache ? "dashboard.cacheBadge.cached" : "dashboard.cacheBadge.fresh")
    }
}

#Preview {
    VStack(spacing: 12) {
        CacheBadgeView(fromCache: false, observedAt: .now)
        CacheBadgeView(fromCache: true, observedAt: .now.addingTimeInterval(-620))
    }
}
