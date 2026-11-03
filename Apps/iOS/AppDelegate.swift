import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(
        _: UIApplication,
        didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // The UI tests start from no files.
        if ProcessInfo.processInfo.environment["FK_SCROLL_UI_TEST"] != nil {
            UserDefaults.standard.removeObject(forKey: FileListStore.key)
            try? FileManager.default.removeItem(at: URL.documentsDirectory)
            try? FileManager.default.createDirectory(at: URL.documentsDirectory, withIntermediateDirectories: true)
        }
        ScrollEnvironment.app = .live
        return true
    }
}
