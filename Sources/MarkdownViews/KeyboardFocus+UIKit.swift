#if canImport(UIKit)
    import MarkdownCore
    import UIKit

    /// The focus ring around the focused element.
    final class FocusRingView: UIView {
        override init(frame: CGRect) {
            super.init(frame: frame)
            isUserInteractionEnabled = false
            backgroundColor = .clear
            layer.borderWidth = 3
            layer.cornerRadius = 4
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            nil
        }

        override func tintColorDidChange() {
            super.tintColorDidChange()
            layer.borderColor = tintColor.cgColor
        }
    }

    extension MarkdownView {
        /// Scrolls to the focused element and draws the ring around it.
        func showFocus() {
            guard let target = focusedTarget, let layout = textView.textLayoutManager,
                  let rect = layout.rect(for: target, rendered: controller.mode == .rendered)
            else {
                focusRing.removeFromSuperview()
                return
            }
            let inset = textView.textContainerInset
            let frame = rect.offsetBy(dx: inset.left, dy: inset.top)
            textView.scrollRectToVisible(frame.insetBy(dx: 0, dy: -24), animated: false)
            updateBoxes()
            focusRing.frame = frame.insetBy(dx: -4, dy: -3)
            focusRing.layer.borderColor = tintColor.cgColor
            textView.addSubview(focusRing)
        }

        /// Focus leaves the view past its first or last element.
        func leaveFocus(forward _: Bool) {
            textView.resignFirstResponder()
        }

        /// The focus keys in `.rendered` and `.editorLocked`; Ctrl-Tab leaves the editor.
        var focusKeyCommands: [UIKeyCommand] {
            guard controller.mode != .editor else {
                return [UIKeyCommand(
                    input: "\t",
                    modifierFlags: .control,
                    action: #selector(MarkdownUITextView.leaveEditor)
                )]
            }
            // The other keys belong to the text until an element has focus.
            let tabs: [(String, UIKeyModifierFlags)] = [("\t", []), ("\t", .shift)]
            let focused: [(String, UIKeyModifierFlags)] = [
                ("\r", []), (" ", []), (UIKeyCommand.inputLeftArrow, []), (UIKeyCommand.inputRightArrow, []),
                (UIKeyCommand.inputEscape, [])
            ]
            let keys = tabs + (focusedTarget == nil ? [] : focused)
            return keys.map { input, flags in
                let command = UIKeyCommand(
                    input: input,
                    modifierFlags: flags,
                    action: #selector(MarkdownUITextView.focusKey(_:))
                )
                command.wantsPriorityOverSystemBehavior = true
                return command
            }
        }

        static func focusInput(for command: UIKeyCommand) -> FocusInput? {
            switch (command.input, command.modifierFlags.contains(.shift)) {
            case ("\t", false): .tab(forward: true)
            case ("\t", true): .tab(forward: false)
            case ("\r", _): .returnKey
            case (" ", _): .space
            case (UIKeyCommand.inputLeftArrow, _): .left
            case (UIKeyCommand.inputRightArrow, _): .right
            case (UIKeyCommand.inputEscape, _): .escape
            default: nil
            }
        }
    }
#endif
