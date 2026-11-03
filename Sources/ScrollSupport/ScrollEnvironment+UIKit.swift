#if os(iOS)
    import UIKit

    /// What a document screen asks of the system. The tests record it instead.
    @MainActor
    struct ScrollEnvironment {
        var transport: any ImageTransport
        var access: any FolderAccess
        /// A web or mail link: the default browser or mail app.
        var openURL: (URL) -> Void
        /// A sibling Markdown file: its tab, or the screen of that file.
        var openFile: (URL) -> Void
        /// Close on the deleted strip: the tab or the screen of the file goes.
        var closeFile: (URL) -> Void
        /// Presents a sheet or an alert over a screen.
        var present: (UIViewController, UIViewController) -> Void
        /// On My iPhone › FK Scroll: where New File and Duplicate write (log 004, Round 4).
        var appFolder: URL
        /// Print in the ⋯ menu: the system print sheet.
        var runPrint: (UIPrintInteractionController, UIViewController) -> Void
        /// Settings (screens §3.17), kept for every screen.
        var defaults: UserDefaults
        /// Copy as rich text.
        var pasteboard: UIPasteboard
        /// The remote images on disk; Settings clears it.
        var cache: ImageCache

        /// The app's services; the app delegate sets them before the first scene.
        static var app: ScrollEnvironment?

        /// A new file in the app's folder, under a name the folder does not have yet.
        func newAppFile(_ data: Data, name: ([String]) -> String) throws -> URL {
            let taken = (try? FileManager.default.contentsOfDirectory(atPath: appFolder.path(percentEncoded: false)))
            let url = appFolder.appending(path: name(taken ?? []))
            try FileManager.default.createDirectory(at: appFolder, withIntermediateDirectories: true)
            try data.write(to: url, options: .withoutOverwriting)
            return url
        }
    }
#endif
