import Foundation
import HWANGTODOCore
import WidgetKit

/// Timeline entry shared by every glance widget: one immutable snapshot of
/// everything a widget may render, so all placed widgets agree with each other.
struct GlanceEntry: TimelineEntry {
    let date: Date
    let snapshot: GlanceSnapshot
}

/// The one provider behind every home and lock-screen widget.
///
/// `GlanceSnapshot.make()` is MainActor (it reads `SharedStore`); this target
/// is nonisolated-by-default, so async provider methods hop with `await`.
/// The synchronous `placeholder(in:)` must not touch the store — it renders
/// `GlanceSnapshot.placeholder`.
struct GlanceProvider: TimelineProvider {
    func placeholder(in context: Context) -> GlanceEntry {
        GlanceEntry(date: .now, snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping @Sendable (GlanceEntry) -> Void) {
        // Gallery previews must render instantly and never leak real data.
        guard !context.isPreview else {
            completion(GlanceEntry(date: .now, snapshot: .placeholder))
            return
        }
        Task {
            let snapshot = await GlanceSnapshot.make()
            completion(GlanceEntry(date: snapshot.date, snapshot: snapshot))
        }
    }

    func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<GlanceEntry>) -> Void) {
        Task {
            let snapshot = await GlanceSnapshot.make()
            let entry = GlanceEntry(date: snapshot.date, snapshot: snapshot)
            // Repository writes reload timelines immediately; 15 minutes is
            // only a safety net for day rollover and cross-process staleness.
            let refresh = Calendar.current.date(byAdding: .minute, value: 15, to: .now)
                ?? .now.addingTimeInterval(15 * 60)
            completion(Timeline(entries: [entry], policy: .after(refresh)))
        }
    }
}
