#if os(macOS)
    import AppKit
    @testable import ScrollSupport

    /// AppKit's open path asks `NSDocumentController.shared`, and the first
    /// controller made becomes it. Every test that makes a document calls
    /// this first, so the shared controller is the app's.
    @MainActor
    enum TestApp {
        static let controller: ScrollDocumentController = {
            let controller = ScrollDocumentController()
            precondition(NSDocumentController.shared === controller, "a test touched the shared controller first")
            return controller
        }()
    }
#endif
