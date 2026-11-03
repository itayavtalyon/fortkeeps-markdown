import Foundation
import MarkdownCore
@testable import MarkdownViews
import Testing
#if os(macOS)
    import AppKit
#else
    import UIKit
#endif

/// Find and replace (screens §3.6; log 001 › Windows and chrome): Replace All is one undo group.
@MainActor
struct MarkdownViewFindTests {
    @Test
    func `a replace-all is one undo group, and its undo restores every match`() {
        let controller = MarkdownTextController(
            text: "a cat, a cat\n", features: MarkdownFeatures(), presentation: MarkdownPresentation(),
            mode: .editor, maxUTF8Bytes: nil, documentURL: nil
        )
        let host = RecordingHost()
        controller.host = host

        #expect(controller.replaceAll("a dog, a dog\n"))
        #expect(controller.text == "a dog, a dog\n")
        controller.undoManager.undo()

        #expect(controller.text == "a cat, a cat\n")
        #expect(!controller.undoManager.canUndo)
        #expect(host.changes.map(\.reason) == [.edit, .undo])
    }

    @Test
    func `a replace-all over the byte limit changes nothing`() {
        let controller = MarkdownTextController(
            text: "ab\n", features: MarkdownFeatures(), presentation: MarkdownPresentation(),
            mode: .editor, maxUTF8Bytes: 4, documentURL: nil
        )

        #expect(!controller.replaceAll("abcd\n"))
        #expect(controller.text == "ab\n")
    }

    #if os(macOS)
        @Test
        func `the Mac find bar's Replace All is one undo group`() {
            let view = MarkdownView(text: "a cat, a cat\n", host: nil)

            let allowed = view.textView.shouldChangeText(
                inRanges: [
                    NSValue(range: NSRange(location: 2, length: 3)),
                    NSValue(range: NSRange(location: 9, length: 3))
                ],
                replacementStrings: ["dog", "dog"]
            )

            #expect(!allowed)
            #expect(view.text == "a dog, a dog\n")
            #expect(view.textView.string == "a dog, a dog\n")
            view.undoManager?.undo()
            #expect(view.text == "a cat, a cat\n")
            #expect(view.undoManager?.canUndo == false)
        }

        @Test
        func `a single change still goes through the one-range check`() {
            let view = MarkdownView(text: "a\n", isEditable: false, host: nil)

            #expect(!view.textView.shouldChangeText(
                inRanges: [NSValue(range: NSRange(location: 0, length: 1))], replacementStrings: ["b"]
            ))
            #expect(!view.textView.shouldChangeText(
                inRanges: [
                    NSValue(range: NSRange(location: 0, length: 1)),
                    NSValue(range: NSRange(location: 1, length: 0))
                ],
                replacementStrings: ["b", "c"]
            ))
            #expect(view.text == "a\n")
        }

    #else
        /// The find navigator in a key window, so its session can replace.
        func findSession(_ text: String) async throws -> (MarkdownView, UIFindSession) {
            let view = MarkdownView(text: text, host: nil)
            let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 400, height: 400))
            window.addSubview(view)
            view.frame = window.bounds
            window.makeKeyAndVisible()
            _ = view.textView.becomeFirstResponder()
            let interaction = try #require(view.textView.findInteraction)
            interaction.presentFindNavigator(showingReplace: true)
            while interaction.activeFindSession == nil {
                try await Task.sleep(for: .milliseconds(10))
            }
            return try (view, #require(interaction.activeFindSession))
        }

        @Test(.timeLimit(.minutes(1)))
        func `the iOS find panel's Replace All is one undo group`() async throws {
            let (view, session) = try await findSession("cat cat cats\n")
            #expect(session.supportsReplacement)

            session.replaceAll(searchQuery: "cat", replacementString: "dog", options: nil)
            while view.text != "dog dog dogs\n" {
                try await Task.sleep(for: .milliseconds(10))
            }

            #expect(view.textView.text == "dog dog dogs\n")
            view.undoManager?.undo()
            #expect(view.text == "cat cat cats\n")
            #expect(view.undoManager?.canUndo == false)
        }

        @Test(.timeLimit(.minutes(1)))
        func `the Find command shows the find navigator over the text`() async throws {
            let view = MarkdownView(text: "cat\n", host: nil)
            let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 400, height: 400))
            window.addSubview(view)
            view.frame = window.bounds
            window.makeKeyAndVisible()

            view.showFind()

            let interaction = try #require(view.textView.findInteraction)
            while !interaction.isFindNavigatorVisible {
                try await Task.sleep(for: .milliseconds(10))
            }
        }

        @Test(.timeLimit(.minutes(1)))
        func `a find replacement past the byte limit leaves the text as it was`() async throws {
            let view = MarkdownView(text: "cat\n", maxUTF8Bytes: 4, host: nil)
            view.textView.text = "tiger\n"
            view.textViewDidChange(view.textView)
            view.textViewDidChange(view.textView)

            while view.textView.text != "cat\n" {
                try await Task.sleep(for: .milliseconds(10))
            }
            #expect(view.text == "cat\n")
            #expect(view.undoManager?.canUndo == false)
        }
    #endif
}

/// The controller's undo manager and the empty groups of iOS Find.
@MainActor
struct ModelUndoManagerTests {
    final class Target {}

    @Test
    func `an empty group is noted and taken off; a group with an action is kept`() {
        let manager = ModelUndoManager()
        manager.groupsByEvent = false
        let target = Target()

        manager.beginUndoGrouping()
        manager.registerUndo(withTarget: target) { _ in }
        manager.endUndoGrouping()
        #expect(!manager.hasEmptyGroup)
        manager.dropEmptyGroup()
        #expect(manager.canUndo)

        manager.beginUndoGrouping()
        manager.endUndoGrouping()
        #expect(manager.hasEmptyGroup)
        manager.dropEmptyGroup()
        #expect(!manager.hasEmptyGroup)
        manager.undo()
        #expect(!manager.canUndo)
    }
}
