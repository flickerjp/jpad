import SwiftUI

/// パフォーマンス PAD 用の経過秒タイムライン。
/// `TimelineView` の初回フレームで原点を確定し、実機で待機演出が止まるのを防ぐ。
struct PerformancePadAnimationTimeline<Content: View>: View {
    @Binding var origin: TimeInterval?
    let minimumInterval: TimeInterval
    @ViewBuilder let content: (TimeInterval) -> Content

    init(
        origin: Binding<TimeInterval?>,
        minimumInterval: TimeInterval = 1.0 / 30.0,
        @ViewBuilder content: @escaping (TimeInterval) -> Content
    ) {
        _origin = origin
        self.minimumInterval = minimumInterval
        self.content = content
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: minimumInterval)) { context in
            let reference = context.date.timeIntervalSinceReferenceDate
            let elapsed = elapsedTime(reference: reference)
            content(elapsed)
                .onChange(of: reference, initial: true) { _, newReference in
                    if origin == nil {
                        origin = newReference
                    }
                }
        }
    }

    private func elapsedTime(reference: TimeInterval) -> TimeInterval {
        guard let origin else { return 0 }
        return max(0, reference - origin)
    }
}
