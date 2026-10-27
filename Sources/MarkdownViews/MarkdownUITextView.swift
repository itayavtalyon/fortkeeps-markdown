#if canImport(UIKit)
    import MarkdownCore
    import UIKit

    /// The text view of `MarkdownView`: checkboxes, copy, paste, Undo, and the shortcuts.
    final class MarkdownUITextView: UITextView {
        weak var owner: MarkdownView?
        /// Copy writes here; tests use a named pasteboard.
        var pasteboard = UIPasteboard.general

        private var controller: MarkdownTextController? {
            owner?.controller
        }

        /// Undo goes through the controller's groups.
        override var undoManager: UndoManager? {
            controller?.undoManager ?? super.undoManager
        }

        /// Toggles the checkbox at a point in container coordinates; false when there is none.
        func clickCheckbox(at point: CGPoint) -> Bool {
            guard let controller, let hit = textLayoutManager?.marker(at: point), case .checkbox = hit.marker.kind
            else { return false }
            if let task = controller.taskIndex(atDisplayOffset: hit.offset) {
                controller.toggleTask(task)
            }
            return true
        }

        /// Rendered mode copies the drawn characters; the editor copies the source.
        override func copy(_: Any?) {
            guard let controller, let range = Range(selectedRange), !range.isEmpty else { return }
            pasteboard.string = controller.copyText(range)
        }

        /// Paste converts HTML when `pasteHtml` is on.
        override func paste(_ sender: Any?) {
            guard let owner, let controller, let range = selectedTextRange else { return super.paste(sender) }
            let pasteboard = UIPasteboard.general
            let html = pasteboard.data(forPasteboardType: "public.html").flatMap { String(data: $0, encoding: .utf8) }
            let text = PasteConverter.pasteText(
                html: html,
                plainText: pasteboard.string ?? "",
                features: controller.features,
                documentURL: controller.documentURL
            )
            owner.nextEvent = .paste
            replace(range, withText: text)
        }

        // MARK: shortcuts

        override var keyCommands: [UIKeyCommand]? {
            FormatAction.allCases.enumerated().map { index, action in
                var flags: UIKeyModifierFlags = []
                if action.shortcut.modifiers.contains(.command) {
                    flags.insert(.command)
                }
                if action.shortcut.modifiers.contains(.shift) {
                    flags.insert(.shift)
                }
                if action.shortcut.modifiers.contains(.option) {
                    flags.insert(.alternate)
                }
                let command = UIKeyCommand(
                    title: action.title,
                    action: #selector(performShortcut(_:)),
                    input: action.shortcut.key,
                    modifierFlags: flags,
                    propertyList: index
                )
                command.wantsPriorityOverSystemBehavior = true
                return command
            }
        }

        @objc func performShortcut(_ sender: UIKeyCommand) {
            guard let owner, controller?.acceptsEdits == true, let index = sender.propertyList as? Int else { return }
            owner.perform(FormatAction.allCases[index])
        }

        // MARK: accessibility

        func checkboxElements(container: UIView) -> [CheckboxElement] {
            guard let controller, let layout = textLayoutManager,
                  let viewport = layout.textViewportLayoutController.viewportRange
            else { return [] }
            var elements: [CheckboxElement] = []
            layout.enumerateTextLayoutFragments(from: viewport.location) { fragment in
                guard let fragment = fragment as? MarkdownLayoutFragment else { return true }
                let start = layout.offset(of: fragment.rangeInElement.location)
                for box in fragment.markerBoxes {
                    guard case .checkbox = box.marker.kind,
                          let task = controller.taskIndex(atDisplayOffset: start + box.offset)
                    else { continue }
                    let rect = box.rect.offsetBy(
                        dx: fragment.layoutFragmentFrame.minX + textContainerInset.left,
                        dy: fragment.layoutFragmentFrame.minY + textContainerInset.top
                    )
                    let element = CheckboxElement(accessibilityContainer: container)
                    element.configure(task: task, controller: controller)
                    // 44 pt hit size.
                    element.accessibilityFrameInContainerSpace = convert(
                        rect.insetBy(dx: -(44 - rect.width) / 2, dy: -(44 - rect.height) / 2),
                        to: container
                    )
                    elements.append(element)
                }
                return fragment.rangeInElement.endLocation.compare(viewport.endLocation) == .orderedAscending
            }
            return elements
        }
    }

    /// A checkbox as VoiceOver reads it: the task text, `done` or `not done`.
    final class CheckboxElement: UIAccessibilityElement {
        private var task = 0
        private weak var controller: MarkdownTextController?

        func configure(task: Int, controller: MarkdownTextController) {
            self.task = task
            self.controller = controller
            let state = controller.checkboxAccessibility(task)
            accessibilityLabel = state.label
            accessibilityValue = state.value
            accessibilityTraits = state.isEnabled ? [.button, .toggleButton] : [.button, .toggleButton, .notEnabled]
        }

        override func accessibilityActivate() -> Bool {
            guard let controller, controller.checkboxAccessibility(task).isEnabled else { return false }
            controller.toggleTask(task)
            configure(task: task, controller: controller)
            return true
        }
    }
#endif
