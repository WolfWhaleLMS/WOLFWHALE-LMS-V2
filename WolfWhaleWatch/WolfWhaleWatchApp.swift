import SwiftUI

// ---------------------------------------------------------------
// IMPORTANT: Xcode Target Setup Required
// ---------------------------------------------------------------
// This watch app requires a dedicated watchOS target in Xcode.
// To add it:
//   1. Open WolfWhaleLearning.xcodeproj (or WolfWhaleLMS.xcodeproj) in Xcode.
//   2. File > New > Target...
//   3. Select watchOS > App (Watch App for existing iOS App).
//   4. Set the product name to "WolfWhaleWatch".
//   5. Ensure the "Embed in Companion Application" dropdown points
//      to the main WolfWhaleLearning iOS target.
//   6. Set deployment target to watchOS 11.0.
//   7. Remove any auto-generated Swift files Xcode creates
//      (ContentView, App) since they already exist here.
//   8. Drag this WolfWhaleWatch folder into the new target's
//      file group, or configure the target's
//      PBXFileSystemSynchronizedRootGroup to point here.
//   9. In the iOS target's "Frameworks, Libraries, and Embedded
//      Content" section, ensure WatchConnectivity.framework is
//      linked. Also add WatchConnectivity.framework to the
//      watchOS target.
//  10. Build & run on a paired Apple Watch simulator or device.
// ---------------------------------------------------------------

@main
struct WolfWhaleWatchApp: App {
    @State private var connectivityService = WatchConnectivityService()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(connectivityService)
        }
    }
}
