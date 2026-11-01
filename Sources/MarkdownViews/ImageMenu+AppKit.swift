#if os(macOS)
    import AppKit

    extension MarkdownView {
        /// Puts the image items of the controller at the top of a context menu.
        func addImageItems(to menu: NSMenu, destination: String?) {
            let items = controller.imageMenuItems(destination: destination)
            guard !items.isEmpty else { return }
            for (index, item) in items.enumerated() {
                menu.insertItem(ImageMenuAction(item, controller: controller), at: index)
            }
            menu.insertItem(.separator(), at: items.count)
        }
    }

    /// A menu item that performs one `ImageMenuItem`.
    @MainActor
    final class ImageMenuAction: NSMenuItem {
        private let item: ImageMenuItem
        private weak var controller: MarkdownTextController?

        init(_ item: ImageMenuItem, controller: MarkdownTextController) {
            self.item = item
            self.controller = controller
            super.init(title: item.title, action: #selector(choose), keyEquivalent: "")
            target = self
        }

        @available(*, unavailable)
        required init(coder _: NSCoder) {
            fatalError("ImageMenuAction is built in code")
        }

        @objc private func choose() {
            controller?.perform(item)
        }
    }
#endif
