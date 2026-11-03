#if os(macOS)
    import AppKit
    import MarkdownViews

    /// The document window is the `MarkdownHost` of its view (design log 001 ›
    /// Host interface, Links).
    extension DocumentWindowController {
        nonisolated func image(for request: ImageRequest) async -> ImageResult {
            await images.image(for: request)
        }

        func textDidChange(_ change: TextChange) {
            // A reload clears them too; a quiet reload shows its note after.
            outside.showsNote = false
            outside.keepsMine = false
            outside.keptMine = false
            scrollDocument?.apply(change)
            refreshOutline(after: change.reason == .reload ? .zero : outlinePause)
            update()
        }

        func activateImage(_ activation: ImageActivation) {
            images.activateImage(activation)
        }

        func reloadImage(_ request: ImageRequest) {
            images.reloadImage(request)
        }

        func loadAllImages() {
            images.loadAllImages(in: markdownView.text, documentURL: scrollDocument?.fileURL)
        }

        /// The default browser or mail app, a tab for a sibling file, the
        /// heading of a fragment; any other link beeps.
        func open(_ link: LinkActivation) {
            switch LinkRules.classify(link.destination, documentURL: link.documentURL) {
            case let .browser(url), let .mail(url):
                environment.openURL(url)
            case let .siblingFile(url):
                openSibling(url)
            case let .fragment(slug):
                markdownView.showHeading(fragment: slug)
            case .none:
                environment.beep()
            }
        }

        private func openSibling(_ url: URL) {
            guard environment.access.canRead(url.deletingLastPathComponent()) else {
                showFolderStrip()
                return
            }
            guard FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) else {
                environment.showPopover(ScrollStrings.notInFolder(url.lastPathComponent), markdownView)
                return
            }
            environment.openFile(url)
        }
    }
#endif
