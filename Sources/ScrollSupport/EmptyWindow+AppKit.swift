#if os(macOS)
    import AppKit

    @MainActor
    protocol EmptyWindowActions: AnyObject {
        func open(_ url: URL)
        func removeRecent(_ url: URL)
    }

    /// The window with no document (screens §3.1): a line, Open… and New
    /// File, and up to 8 recent files.
    @MainActor
    final class EmptyWindowController: NSWindowController {
        static let recentLimit = 8
        private weak var actions: EmptyWindowActions?
        private var urls: [Int: URL] = [:]

        init(recent: [URL], actions: EmptyWindowActions) {
            self.actions = actions
            let window = NSWindow(
                contentRect: CGRect(x: 0, y: 0, width: 560, height: 380),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: true
            )
            // The Window menu and VoiceOver read the title.
            window.title = "Fortkeeps Scroll"
            window.isReleasedWhenClosed = false
            window.tabbingMode = .disallowed
            super.init(window: window)
            build(recent: recent)
            window.center()
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            nil
        }

        /// Builds the window for the current recent files.
        func build(recent: [URL]) {
            urls = [:]
            let recent = Array(recent.prefix(Self.recentLimit))
            let glyph = NSImageView()
            glyph.image = NSImage(systemSymbolName: "doc.text", accessibilityDescription: nil)
            glyph.symbolConfiguration = .init(pointSize: 40, weight: .regular)
            // Open… and New File go up the responder chain to the document controller, as the File menu does.
            let open = NSButton(
                title: ScrollStrings.open, target: nil, action: #selector(NSDocumentController.openDocument(_:))
            )
            open.keyEquivalent = "\r"
            let create = NSButton(
                title: ScrollStrings.newFile, target: nil, action: #selector(NSDocumentController.newDocument(_:))
            )
            let buttons = NSStackView(views: [open, create])
            var views: [NSView] = [glyph, NSTextField(labelWithString: ScrollStrings.emptyLine), buttons]
            if !recent.isEmpty {
                let header = NSTextField(labelWithString: ScrollStrings.recent)
                header.textColor = .secondaryLabelColor
                views.append(header)
                views += recent.enumerated().map { row($1, tag: $0) }
            }
            let stack = NSStackView(views: views)
            stack.orientation = .vertical
            stack.edgeInsets = NSEdgeInsets(top: 32, left: 32, bottom: 32, right: 32)
            window?.contentView = stack
            window?.initialFirstResponder = open
        }

        /// A recent file: its name opens it. A missing file is dimmed, with
        /// Not found and Remove from Recent.
        private func row(_ url: URL, tag: Int) -> NSView {
            urls[tag] = url
            let name = NSButton(title: url.lastPathComponent, target: self, action: #selector(openRecent))
            name.isBordered = false
            name.tag = tag
            let folder = NSTextField(labelWithString: (url.deletingLastPathComponent().path as NSString)
                .abbreviatingWithTildeInPath)
            folder.textColor = .secondaryLabelColor
            folder.lineBreakMode = .byTruncatingMiddle
            folder.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            guard !FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) else {
                return NSStackView(views: [name, folder])
            }
            name.isEnabled = false
            let remove = NSButton(title: ScrollStrings.removeRecent, target: self, action: #selector(removeRecent))
            remove.tag = tag
            return NSStackView(views: [name, folder, NSTextField(labelWithString: ScrollStrings.notFound), remove])
        }

        @objc private func openRecent(_ sender: NSButton) {
            urls[sender.tag].map { actions?.open($0) }
        }

        @objc private func removeRecent(_ sender: NSButton) {
            urls[sender.tag].map { actions?.removeRecent($0) }
        }
    }
#endif
