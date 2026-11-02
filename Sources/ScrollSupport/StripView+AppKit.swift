#if os(macOS)
    import AppKit

    /// One strip under the toolbar (screens §3.2, §3.12, §3.13, §3.21): an
    /// icon, a line, its buttons, and, when it can be dismissed, ×.
    @MainActor
    final class StripView: NSStackView {
        enum Kind: Equatable {
            case folderAccess
            case deleted
            case readOnly
            case saveFailed
        }

        /// A button sends its action to its target, as an AppKit control does.
        struct Button {
            let title: String
            let target: AnyObject
            let action: Selector
        }

        let kind: Kind

        init(kind: Kind, text: String, buttons: [Button], dismiss: Button? = nil) {
            self.kind = kind
            super.init(frame: .zero)
            let icon = NSImageView()
            icon.image = NSImage(systemSymbolName: "info.circle", accessibilityDescription: nil)
            let label = NSTextField(wrappingLabelWithString: text)
            label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            var views: [NSView] = [icon, label]
            for button in buttons {
                views.append(NSButton(title: button.title, target: button.target, action: button.action))
            }
            if let dismiss {
                let close = NSButton(title: "", target: dismiss.target, action: dismiss.action)
                close.image = NSImage(systemSymbolName: "xmark", accessibilityDescription: ScrollStrings.dismiss)
                close.isBordered = false
                views.append(close)
            }
            setViews(views, in: .leading)
            edgeInsets = NSEdgeInsets(top: 6, left: 12, bottom: 6, right: 12)
            setAccessibilityRole(.group)
            setAccessibilityLabel(text)
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            nil
        }
    }
#endif
