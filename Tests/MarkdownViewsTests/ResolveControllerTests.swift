import MarkdownCore
@testable import MarkdownViews
import Testing

/// Screens §3.11: the compare view's commands, labels, and announcements,
/// shared by the Mac and iOS views.
@MainActor
struct ResolveControllerTests {
    final class Record {
        var applied: [String] = []
        var cancels = 0
        var announcements: [String] = []
        var changes = 0
    }

    static func given(_ record: Record) -> ResolveController {
        let controller = ResolveController(
            mine: "a\nmine\nb\nmine 2\n", theirs: "a\ntheirs\nb\ntheirs 2\n"
        )
        controller.onApply = { record.applied.append($0) }
        controller.onCancel = { record.cancels += 1 }
        controller.onAnnouncement = { record.announcements.append($0) }
        controller.onChange = { record.changes += 1 }
        return controller
    }

    @Test
    func `a choice announces itself and moves on; Apply waits for every change`() {
        let record = Record()
        let controller = Self.given(record)
        #expect(controller.count == "0 of 2 resolved")
        #expect(!controller.canApply)

        controller.choose(.theirs)
        controller.apply()
        #expect(record.applied.isEmpty)
        controller.choose(.both)
        controller.apply()

        #expect(record.announcements == [
            "Change 1 resolved, using theirs. 1 left.",
            "Change 2 resolved, using both. 0 left."
        ])
        #expect(controller.count == "2 of 2 resolved")
        #expect(record.applied == ["a\ntheirs\nb\nmine 2\ntheirs 2\n"])
        #expect(record.changes == 2)
    }

    @Test
    func `each change has its state line and its VoiceOver label`() {
        let controller = Self.given(Record())
        #expect(controller.state(0) == "Not resolved")
        #expect(controller.accessibilityLabel(0) == "Change 1 of 2, not resolved. Mine: mine. Theirs: theirs.")

        controller.choose(.mine, change: 1)

        #expect(controller.state(1) == "✓ Mine")
        #expect(controller.accessibilityLabel(1)
            == "Change 2 of 2, resolved, using mine. Mine: mine 2. Theirs: theirs 2.")
        controller.choose(.both, change: 0)
        #expect(controller.state(0) == "✓ Both")
        controller.choose(.theirs, change: 0)
        #expect(controller.state(0) == "✓ Theirs")
    }

    @Test
    func `the keys pick, move, apply, and cancel`() {
        let record = Record()
        let controller = Self.given(record)

        #expect(controller.handleKey(.next))
        #expect(controller.model.current == 1)
        #expect(controller.handleKey(.previous))
        #expect(controller.handleKey(.mine))
        #expect(controller.handleKey(.theirs))
        #expect(controller.handleKey(.apply))
        #expect(record.applied.count == 1)
        #expect(controller.handleKey(.both))
        #expect(controller.handleKey(.cancel))
        #expect(record.cancels == 1)
    }

    @Test
    func `a move and an undo redraw; undo with nothing to undo is the system's`() {
        let record = Record()
        let controller = Self.given(record)
        #expect(!controller.handleKey(.undo))

        _ = controller.handleKey(.next)
        #expect(record.changes == 1)
        controller.choose(.mine)
        #expect(controller.handleKey(.undo))

        #expect(controller.model.choice(1) == nil)
        #expect(record.changes == 3)
    }

    @Test
    func `return does nothing until every change is resolved`() {
        let controller = Self.given(Record())

        #expect(!controller.handleKey(.apply))
    }

    @Test
    func `the buttons and the collapsed runs have their titles`() {
        #if os(macOS)
            #expect(ResolveStrings.choiceTitles == ["Use Mine", "Use Theirs", "Use Both"])
        #else
            #expect(ResolveStrings.choiceTitles == ["Use mine", "Use theirs", "Use both"])
        #endif
        #expect(ResolveStrings.unchanged(3) == "3 unchanged lines")
        #expect(ResolveStrings.unchanged(1) == "1 unchanged line")
        #expect(ResolveStrings.show == "Show")
        #expect(ResolveStrings.apply == "Apply")
        #expect(ResolveStrings.cancel == "Cancel")
    }
}
