import UIKit

/// The iPhone home screen, or the iPad document browser (design log 001 ›
/// Windows and chrome, log 002 › iPhone home screen).
final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    /// The scene that opens files from links and from the Files app.
    @MainActor weak static var current: SceneDelegate?

    var window: UIWindow?
    private var home: HomeViewController?
    private var browser: BrowserViewController?

    func scene(_ scene: UIScene, willConnectTo _: UISceneSession, options: UIScene.ConnectionOptions) {
        guard let scene = scene as? UIWindowScene, let environment = ScrollEnvironment.app else { return }
        let session = DocumentSession(store: FileListStore(defaults: .standard), environment: environment)
        let window = UIWindow(windowScene: scene)
        if scene.traitCollection.userInterfaceIdiom == .pad {
            let browser = BrowserViewController(session: session)
            self.browser = browser
            window.rootViewController = browser
            if ProcessInfo.processInfo.environment["FK_SCROLL_UI_TEST"] != nil {
                // The browser starts where it was last; the UI tests start in the app's folder.
                let marker = URL.documentsDirectory.appending(path: "UI test.md")
                try? Data().write(to: marker)
                browser.revealDocument(at: marker, importIfNeeded: false) { _, _ in }
            }
        } else {
            let home = HomeViewController(session: session)
            self.home = home
            let navigation = UINavigationController(rootViewController: home)
            navigation.navigationBar.prefersLargeTitles = true
            navigation.isToolbarHidden = false
            window.rootViewController = navigation
        }
        self.window = window
        Self.current = self
        window.makeKeyAndVisible()
        open(options.urlContexts.map(\.url))
    }

    func scene(_: UIScene, openURLContexts contexts: Set<UIOpenURLContext>) {
        open(contexts.map(\.url))
    }

    func open(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        Task {
            if let browser {
                await browser.open(urls, typing: false)
            }
            for url in urls {
                await home?.show(url)
            }
        }
    }

    func close(_ url: URL) {
        Task {
            await browser?.tabs.close(url)
            await home?.close(url)
        }
    }
}
