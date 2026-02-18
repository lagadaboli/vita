import SwiftUI
import VITACore
import CausalityEngine
#if os(iOS)
import UserNotifications
#endif

@main
struct VITAApp: App {
    @State private var appState = AppState()
    @State private var notificationSymptom: String?

    var body: some Scene {
        WindowGroup {
            ContentView(appState: appState)
                .onAppear {
                    #if os(iOS)
                    UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
                    NotificationDelegate.shared.onFullStoryTap = { userInfo in
                        if let symptom = userInfo["symptom"] as? String {
                            notificationSymptom = symptom
                        }
                    }

                    // Request notification permission
                    Task {
                        _ = await VITANotificationManager.shared.requestPermission()
                    }
                    #endif
                }
        }
    }
}

/// Handles notification delegate callbacks for deep-linking.
#if os(iOS)
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()
    var onFullStoryTap: (([AnyHashable: Any]) -> Void)?

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo

        if response.notification.request.content.categoryIdentifier == VITANotificationManager.categoryIdentifier {
            onFullStoryTap?(userInfo)
        }

        completionHandler()
    }

    // Show notification even when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
#endif
