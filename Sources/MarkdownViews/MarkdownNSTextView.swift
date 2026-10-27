#if os(macOS)
    import AppKit
    import MarkdownCore

    /// The text view of `MarkdownView`: clicks on links and checkboxes, copy,
    /// paste, link hover, and the checkbox accessibility elements.
    final class MarkdownNSTextView: NSTextView {
        weak var owner: MarkdownView?
        private var hoveredLink: NSTextRange?

        private var controller: MarkdownTextController? {
            owner?.controller
        }

        private func containerPoint(_ event: NSEvent) -> CGPoint {
            let point = convert(event.locationInWindow, from: nil)
            return CGPoint(x: point.x - textContainerOrigin.x, y: point.y - textContainerOrigin.y)
        }

        /// Activates the editor image card at a point in container coordinates;
        /// false when there is none, or when the card has no button.
        func clickEditorImage(at point: CGPoint) -> Bool {
            guard let controller, controller.mode != .rendered, let mark = textLayoutManager?.editorImage(at: point)
            else { return false }
            if mark.content.activates {
                controller.activateImage(destination: mark.destination)
            }
            return true
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

        override func mouseDown(with event: NSEvent) {
            guard let controller else { return super.mouseDown(with: event) }
            if clickCheckbox(at: containerPoint(event)) || clickEditorImage(at: containerPoint(event)) {
                return
            }
            let offset = characterIndexForInsertion(at: convert(event.locationInWindow, from: nil))
            if controller.click(atDisplayOffset: offset, modifiers: LinkModifiers(event.modifierFlags)) {
                return
            }
            super.mouseDown(with: event)
        }

        override func updateTrackingAreas() {
            super.updateTrackingAreas()
            for area in trackingAreas where area.owner === self && area.options.contains(.mouseMoved) {
                removeTrackingArea(area)
            }
            addTrackingArea(NSTrackingArea(
                rect: .zero,
                options: [.mouseMoved, .activeInKeyWindow, .inVisibleRect],
                owner: self
            ))
        }

        /// A link underlines on hover.
        override func mouseMoved(with event: NSEvent) {
            super.mouseMoved(with: event)
            guard let controller, let layout = textLayoutManager else { return }
            let offset = characterIndexForInsertion(at: convert(event.locationInWindow, from: nil))
            let link = controller.link(atDisplayOffset: offset)
            let range: Range<Int>? = link.map { link in
                controller.mode == .rendered ? link.range
                    : controller.displayOffset(ofSourceByte: link.sourceRange.lowerBound)
                    ..< controller.displayOffset(ofSourceByte: link.sourceRange.upperBound)
            }
            if let hoveredLink {
                layout.removeRenderingAttribute(.underlineStyle, for: hoveredLink)
            }
            hoveredLink = range.flatMap { range in
                layout.location(at: range.lowerBound).flatMap { start in
                    layout.location(at: range.upperBound).flatMap { NSTextRange(location: start, end: $0) }
                }
            }
            if let hoveredLink {
                layout.addRenderingAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, for: hoveredLink)
            }
        }

        /// Rendered mode copies the drawn characters; the editor copies the source.
        override func writeSelection(to pboard: NSPasteboard, types _: [NSPasteboard.PasteboardType]) -> Bool {
            guard let controller, let range = Range(selectedRange()), !range.isEmpty else { return false }
            pboard.declareTypes([.string], owner: nil)
            return pboard.setString(controller.copyText(range), forType: .string)
        }

        /// Paste converts HTML when `pasteHtml` is on.
        override func paste(_ sender: Any?) {
            guard let owner, let controller else { return super.paste(sender) }
            let pasteboard = NSPasteboard.general
            let text = PasteConverter.pasteText(
                html: pasteboard.string(forType: .html),
                plainText: pasteboard.string(forType: .string) ?? "",
                features: controller.features,
                documentURL: controller.documentURL
            )
            owner.nextEvent = .paste
            insertText(text, replacementRange: selectedRange())
        }

        // MARK: accessibility

        /// The checkboxes of the laid-out text, after the text's own children.
        override func accessibilityChildren() -> [Any]? {
            (super.accessibilityChildren() ?? []) + checkboxElements()
        }

        private func checkboxElements() -> [CheckboxElement] {
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
                        dx: fragment.layoutFragmentFrame.minX + textContainerOrigin.x,
                        dy: fragment.layoutFragmentFrame.minY + textContainerOrigin.y
                    )
                    elements.append(CheckboxElement(task: task, rect: rect, textView: self))
                }
                return fragment.rangeInElement.endLocation.compare(viewport.endLocation) == .orderedAscending
            }
            return elements
        }

        func toggleTask(_ task: Int) {
            controller?.toggleTask(task)
        }

        func checkboxAccessibility(_ task: Int) -> CheckboxState? {
            controller?.checkboxAccessibility(task)
        }
    }

    /// A checkbox as VoiceOver reads it: the task text, `done` or `not done`.
    final class CheckboxElement: NSAccessibilityElement {
        let task: Int
        private weak var textView: MarkdownNSTextView?
        private let rect: CGRect

        init(task: Int, rect: CGRect, textView: MarkdownNSTextView) {
            self.task = task
            self.rect = rect
            self.textView = textView
            super.init()
            setAccessibilityRole(.checkBox)
            setAccessibilityParent(textView)
        }

        /// Accessibility queries the element on the main thread.
        private var state: CheckboxState? {
            nonisolated(unsafe) let element = self
            return MainActor.assumeIsolated { element.textView?.checkboxAccessibility(element.task) }
        }

        override func accessibilityLabel() -> String? {
            state?.label
        }

        override func accessibilityValue() -> Any? {
            state?.value
        }

        override func isAccessibilityEnabled() -> Bool {
            state?.isEnabled ?? false
        }

        override func accessibilityFrame() -> CGRect {
            guard let textView else { return .zero }
            return NSAccessibility.screenRect(fromView: textView, rect: rect)
        }

        override func accessibilityPerformPress() -> Bool {
            guard isAccessibilityEnabled() else { return false }
            nonisolated(unsafe) let element = self
            MainActor.assumeIsolated { element.textView?.toggleTask(element.task) }
            return true
        }
    }
#endif
