#if canImport(UIKit)
    import MarkdownCore
    @testable import MarkdownViews
    import Testing
    import UIKit

    /// The view as the iOS app hosts it: focus, its VoiceOver name and checkboxes, and Copy.
    extension MarkdownViewIOSTests {
        @Test
        func `each VoiceOver read gets the same checkbox element, so it stays alive`() throws {
            let view = MarkdownView(text: "- [ ] a\n- [x] b\n", host: nil)
            view.frame = CGRect(x: 0, y: 0, width: 400, height: 400)
            view.layoutIfNeeded()

            let first = try #require(view.accessibilityElements)
            let second = try #require(view.accessibilityElements)

            #expect(first.count == 3)
            #expect(zip(first, second).allSatisfy { ($0 as AnyObject) === ($1 as AnyObject) })
            #expect((second[2] as? UIAccessibilityElement)?.accessibilityLabel == "b")
        }

        @Test
        func `the host names the text for VoiceOver`() {
            let view = Self.givenView("")

            view.accessibilityLabel = "a.md"

            #expect(view.textView.accessibilityLabel == "a.md")
            #expect(view.accessibilityLabel == "a.md")
        }

        @Test
        func `focusing the view puts the caret in its text`() {
            let view = Self.givenView("a")
            let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 400, height: 400))
            window.addSubview(view)

            #expect(view.becomeFirstResponder())
            #expect(view.textView.isFirstResponder)
        }

        /// `UITextView(usingTextLayoutManager:)` skips the subclass's property
        /// initializers, so a stored default would be a null pasteboard.
        @Test
        func `copy with no test pasteboard writes the general pasteboard`() {
            let view = Self.givenView("abc")

            let pointer = unsafeBitCast(view.textView.pasteboard, to: UInt.self)

            #expect(pointer == unsafeBitCast(UIPasteboard.general, to: UInt.self))
        }

        /// A host's own Undo button, such as the reload note's, undoes the view's groups.
        @Test
        func `the view's undo manager is its own`() {
            let view = Self.givenView("a\n")

            #expect(view.undoManager === view.controller.undoManager)
        }
    }
#endif
