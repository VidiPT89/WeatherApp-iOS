import Foundation

/// Pure formatting logic for the cache badge's "served from cache Xs/Xmin/Xh
/// ago" copy. Kept free of any view/view-model state so it's trivially testable.
enum CacheAgeFormatter {
    /// Formats the age between `observedAt` and `now` as a compact Portuguese
    /// string: seconds under a minute, minutes under an hour, hours beyond that.
    static func formattedAge(observedAt: Date, now: Date) -> String {
        let seconds = max(0, now.timeIntervalSince(observedAt))

        if seconds < 60 {
            return "\(Int(seconds))s"
        }
        let minutes = Int(seconds / 60)
        if minutes < 60 {
            return "\(minutes)min"
        }
        let hours = Int(seconds / 3600)
        return "\(hours)h"
    }
}
