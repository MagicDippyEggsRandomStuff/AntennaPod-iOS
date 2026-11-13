import SwiftUI
import UIKit

@main
struct AntennaPodApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = AppModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
                .onChange(of: scenePhase) { phase in
                    model.handleScenePhase(phase)
                }
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    var backgroundCompletionHandler: (() -> Void)?

    func application(_ application: UIApplication,
                     handleEventsForBackgroundURLSession identifier: String,
                     completionHandler: @escaping () -> Void) {
        guard identifier == DownloadManager.sessionIdentifier else { return }
        backgroundCompletionHandler = completionHandler
    }
}
