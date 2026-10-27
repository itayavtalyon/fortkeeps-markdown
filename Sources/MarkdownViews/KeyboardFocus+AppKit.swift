#if os(macOS)
    import AppKit
    import MarkdownCore

    /// The system focus ring around the focused element.
    final class FocusRingView: NSView {
        override func draw(_: NSRect) {
            NSColor.keyboardFocusIndicatorColor.setStroke()
            let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 1.5, dy: 1.5), xRadius: 4, yRadius: 4)
            path.lineWidth = 3
            path.stroke()
        }

        override func hitTest(_: NSPoint) -> NSView? {
            nil
        }
    }

    extension MarkdownView {
        /// Scrolls to the focused element and draws the ring around it. A
        /// focused link underlines.
        func showFocus() {
            guard let layout = textView.textLayoutManager else { return }
            if let focusedLink {
                layout.removeRenderingAttribute(.underlineStyle, for: focusedLink)
                self.focusedLink = nil
            }
            guard let target = focusedTarget,
                  let rect = layout.rect(for: target, rendered: controller.mode == .rendered)
            else {
                focusRing.removeFromSuperview()
                return
            }
            let frame = rect.offsetBy(dx: textView.textContainerOrigin.x, dy: textView.textContainerOrigin.y)
            textView.scrollToVisible(frame.insetBy(dx: 0, dy: -24))
            updateBoxes()
            if case let .link(range) = target, let textRange = layout.textRange(range) {
                layout.addRenderingAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, for: textRange)
                focusedLink = textRange
            }
            focusRing.frame = frame.insetBy(dx: -4, dy: -3)
            textView.addSubview(focusRing, positioned: .above, relativeTo: nil)
            focusRing.needsDisplay = true
        }

        /// The key view loop continues past the view's first or last element.
        func leaveFocus(forward: Bool) {
            if forward {
                window?.selectKeyView(following: textView)
            } else {
                window?.selectKeyView(preceding: textView)
            }
        }

        /// ⌃F6 moves focus into the visible format bar.
        func focusFormatBar() -> Bool {
            guard !formatBar.isHidden, let window else { return false }
            return window.makeFirstResponder(formatBar.firstButton)
        }

        static func focusInput(for event: NSEvent) -> FocusInput? {
            let flags = event.modifierFlags.intersection([.command, .option, .control, .shift])
            switch (event.keyCode, flags) {
            case (48, []): return .tab(forward: true)
            case (48, [.shift]): return .tab(forward: false)
            case (36, []), (76, []): return .returnKey
            case (49, []): return .space
            case (123, []): return .left
            case (124, []): return .right
            case (53, []): return .escape
            default: return nil
            }
        }
    }
#endif
