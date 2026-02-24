import SwiftUI

/// A ViewModifier that conditionally applies sensory feedback based on user preference.
/// When haptics are disabled in settings, feedback is silently skipped.
struct ConditionalHapticModifier<T: Equatable>: ViewModifier {
    @AppStorage("wolfwhale_haptics_enabled") private var hapticsEnabled = true
    let feedback: SensoryFeedback
    let trigger: T

    func body(content: Content) -> some View {
        if hapticsEnabled {
            content.sensoryFeedback(feedback, trigger: trigger)
        } else {
            content
        }
    }
}

extension View {
    /// Applies haptic feedback that respects the global haptics setting.
    /// Use this instead of `.sensoryFeedback()` directly.
    func hapticFeedback<T: Equatable>(_ feedback: SensoryFeedback, trigger: T) -> some View {
        modifier(ConditionalHapticModifier(feedback: feedback, trigger: trigger))
    }
}
