import SwiftUI
import UIKit

/// Handles remote-notification device token forwarding and silent push.
class AppDelegate: NSObject, UIApplicationDelegate {
    var pushService: PushNotificationService?

    /// A callback the app scene sets so we can trigger a data refresh
    /// from the AppDelegate when a silent push arrives.
    var onBackgroundRefresh: (() -> Void)?

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        pushService?.handleDeviceToken(deviceToken)
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        pushService?.handleRegistrationError(error)
    }

    /// Handle silent push notifications (`content-available: 1`) to
    /// trigger a background data refresh.
    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        guard let pushService else {
            completionHandler(.noData)
            return
        }

        Task { @MainActor in
            let isSilent = pushService.handleSilentPush(userInfo: userInfo)
            if isSilent {
                onBackgroundRefresh?()
                completionHandler(.newData)
            } else {
                // Visible push while app is open -- route to the correct view.
                pushService.handleRemoteNotification(userInfo: userInfo)
                completionHandler(.noData)
            }
        }
    }
}

@main
struct WolfWhaleLMSApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @AppStorage("colorSchemePreference") private var colorSchemePreference: String = "system"
    @State private var pushService: PushNotificationService?

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(
                    colorSchemePreference == "dark" ? .dark :
                    colorSchemePreference == "light" ? .light : nil
                )
                .task {
                    // Lazily create push service to avoid crash without
                    // APNs entitlements / Apple Developer provisioning.
                    let service = PushNotificationService()
                    pushService = service

                    // Wire the push service into the AppDelegate so it
                    // receives the device token callback.
                    appDelegate.pushService = service

                    // Register notification categories (synchronous setup).
                    service.registerNotificationCategories()

                    // TODO: Re-enable when ready to prompt for notifications.
                    // await service.requestAuthorization()
                }
        }
    }
}
