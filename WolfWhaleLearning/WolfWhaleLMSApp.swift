import SwiftUI
import UIKit

/// Handles remote-notification device token forwarding.
class AppDelegate: NSObject, UIApplicationDelegate {
    var pushService: PushNotificationService?

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
        // Token registration failed – nothing to store.
    }
}

@main
struct WolfWhaleLMSApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @AppStorage("isDarkMode") private var isDarkMode = false
    @State private var pushService = PushNotificationService()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(isDarkMode ? .dark : .light)
                .task {
                    // Wire the push service into the AppDelegate so it
                    // receives the device token callback.
                    appDelegate.pushService = pushService

                    // Register notification categories (synchronous setup).
                    pushService.registerNotificationCategories()

                    // Request notification permissions and, if granted,
                    // register for remote notifications.
                    await pushService.requestAuthorization()
                }
        }
    }
}
