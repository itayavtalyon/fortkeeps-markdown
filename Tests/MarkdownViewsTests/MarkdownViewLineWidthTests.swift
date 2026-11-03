import CoreGraphics
@testable import MarkdownViews
import Testing

/// Settings › Line width (screens §3.17; log 004 Round 6): the text column is
/// at most the host's width, centred, with at least the platform's edge.
@MainActor
struct MarkdownViewLineWidthTests {
    @Test
    func `the side inset centres a column no wider than the line width`() {
        #expect(MarkdownView.sideInset(width: 1000, maxLineWidth: 680, minimum: 16) == 160)
        #expect(MarkdownView.sideInset(width: 700, maxLineWidth: 680, minimum: 16) == 16)
        #expect(MarkdownView.sideInset(width: 1000, maxLineWidth: nil, minimum: 12) == 12)
    }

    #if os(macOS)
        @Test
        func `the Mac text column follows the line width and the view's width`() {
            let view = MarkdownView(text: "a\n", host: nil)
            view.frame = CGRect(x: 0, y: 0, width: 1000, height: 400)
            view.layoutSubtreeIfNeeded()
            let width = view.textView.bounds.width

            view.maxLineWidth = 680
            #expect(view.textView.textContainerInset.width == (width - 680) / 2)
            view.frame.size.width = 600
            view.layoutSubtreeIfNeeded()
            #expect(view.textView.textContainerInset.width == 16)
            view.maxLineWidth = nil
            #expect(view.textView.textContainerInset.width == 16)
        }

    #else
        @Test
        func `the iOS text column follows the line width and the view's width`() {
            let view = MarkdownView(text: "a\n", host: nil)
            view.frame = CGRect(x: 0, y: 0, width: 1000, height: 400)
            view.layoutIfNeeded()
            let inset = view.textView.textContainerInset

            view.maxLineWidth = 680
            view.layoutIfNeeded()
            #expect(view.textView.textContainerInset.left == 160)
            #expect(view.textView.textContainerInset.right == 160)
            #expect(view.textView.textContainerInset.top == inset.top)
            view.frame.size.width = 600
            view.layoutIfNeeded()
            #expect(view.textView.textContainerInset.left == 12)
        }
    #endif
}
