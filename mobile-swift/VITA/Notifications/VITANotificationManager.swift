import Foundation
#if os(iOS)
import UserNotifications
#endif
import CausalityEngine

/// Manages local iOS notifications for causal explanations.
/// Category `CAUSAL_EXPLANATION` carries deep-link payload to FullStoryView.
final class VITANotificationManager: NSObject, Sendable {
    static let shared = VITANotificationManager()
    static let categoryIdentifier = "CAUSAL_EXPLANATION"

    private override init() {
        super.init()
    }

    /// Request notification permission. Call during onboarding.
    func requestPermission() async -> Bool {
        #if os(iOS)
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])

            if granted {
                await registerCategories()
            }

            return granted
        } catch {
            #if DEBUG
            print("[VITANotificationManager] Permission request failed: \(error)")
            #endif
            return false
        }
        #else
        return false
        #endif
    }

    /// Schedule a local notification for a causal explanation (Tier 2).
    /// Fires immediately (1s delay) with deep-link userInfo.
    func scheduleFullStoryNotification(
        for explanation: CausalExplanation,
        counterfactuals: [Counterfactual]
    ) {
        #if os(iOS)
        let content = UNMutableNotificationContent()
        content.title = "VITA Insight"
        content.body = explanation.narrative
        content.sound = .default
        content.categoryIdentifier = Self.categoryIdentifier

        // Deep-link payload
        content.userInfo = [
            "symptom": explanation.symptom,
            "confidence": explanation.confidence,
            "causalChain": explanation.causalChain,
            "narrative": explanation.narrative,
            "type": "full_story"
        ]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "causal_\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            #if DEBUG
            if let error {
                print("[VITANotificationManager] Failed to schedule: \(error)")
            }
            #endif
        }
        #endif
    }

    private func registerCategories() async {
        #if os(iOS)
        let viewAction = UNNotificationAction(
            identifier: "VIEW_FULL_STORY",
            title: "View Full Story",
            options: [.foreground]
        )

        let category = UNNotificationCategory(
            identifier: Self.categoryIdentifier,
            actions: [viewAction],
            intentIdentifiers: [],
            options: []
        )

        UNUserNotificationCenter.current().setNotificationCategories([category])
        #endif
    }
}
