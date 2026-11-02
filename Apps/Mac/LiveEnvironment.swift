import AppKit

/// The system services of the app; the tests use their own.
extension ScrollEnvironment {
    static let live = ScrollEnvironment(
        transport: URLSessionTransport(),
        access: FolderBookmarks.standard,
        openURL: { NSWorkspace.shared.open($0) },
        openFile: { NSDocumentController.shared.openDocument(withContentsOf: $0, display: true) { _, _, _ in } },
        beep: { NSSound.beep() },
        presentAlert: { alert, window, handler in
            if let window {
                alert.beginSheetModal(for: window, completionHandler: handler)
            } else {
                handler(alert.runModal())
            }
        },
        showPopover: { text, view in
            let popover = NSPopover()
            popover.behavior = .transient
            let controller = NSViewController()
            let label = NSTextField(labelWithString: text)
            let stack = NSStackView(views: [label])
            stack.edgeInsets = NSEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
            controller.view = stack
            popover.contentViewController = controller
            let mouse = view.convert(view.window?.mouseLocationOutsideOfEventStream ?? .zero, from: nil)
            popover.show(
                relativeTo: CGRect(origin: mouse, size: CGSize(width: 1, height: 1)),
                of: view,
                preferredEdge: .maxY
            )
        }
    )
}

extension FolderBookmarks {
    static let standard = FolderBookmarks(defaults: .standard) { folder in
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.directoryURL = folder
        panel.message = ScrollStrings.accessBar(folder.lastPathComponent)
        panel.prompt = ScrollStrings.allowAccess.replacingOccurrences(of: "…", with: "")
        return panel.runModal() == .OK ? panel.url : nil
    }
}
