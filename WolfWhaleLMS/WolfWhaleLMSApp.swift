import SwiftUI

@main
struct WolfWhaleLMSApp: App {
    @AppStorage("isDarkMode") private var isDarkMode = false
    @State private var notificationService = PushNotificationService()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(isDarkMode ? .dark : .light)
                .task {
                    notificationService.registerNotificationCategories()
                    await notificationService.requestAuthorization()
                }
        }
    }
}
