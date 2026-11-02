import Foundation
import MarkdownCore

/// The compare view's behavior, shared by the Mac and iOS `ResolveView`
/// (screens §3.11, design log 004 › Outside changes): the choices, the keys,
/// Apply and Cancel, and what VoiceOver reads.
@MainActor
final class ResolveController {
    enum Key {
        case next
        case previous
        case mine
        case theirs
        case both
        case apply
        case cancel
        case undo
    }

    private(set) var model: ResolveModel
    var onApply: ((String) -> Void)?
    var onCancel: (() -> Void)?
    /// A message VoiceOver reads without moving focus.
    var onAnnouncement: ((String) -> Void)?
    /// Called after a choice or a move, so the view redraws.
    var onChange: (() -> Void)?

    init(mine: String, theirs: String) {
        model = ResolveModel(mine: mine, theirs: theirs)
    }

    var count: String {
        ResolveStrings.count(model.resolvedCount, of: model.changeCount)
    }

    var canApply: Bool {
        model.merged != nil
    }

    func choose(_ choice: LineDiff.Choice, change: Int? = nil) {
        let index = change ?? model.current
        model.choose(choice, change: index)
        onAnnouncement?(ResolveStrings.resolved(
            index + 1, using: choice, left: model.changeCount - model.resolvedCount
        ))
        onChange?()
    }

    func apply() {
        guard let merged = model.merged else { return }
        onApply?(merged)
    }

    /// Option-Down and Option-Up move; Command-Option-Left, Right, and B
    /// choose; Return applies once every change is resolved; Esc cancels; ⌘Z
    /// takes back a choice.
    /// False when the key does nothing, so the system handles it.
    func handleKey(_ key: Key) -> Bool {
        switch key {
        case .next, .previous:
            model.move(key == .next ? 1 : -1)
            onChange?()
        case .mine: choose(.mine)
        case .theirs: choose(.theirs)
        case .both: choose(.both)
        case .apply:
            guard canApply else { return false }
            apply()
        case .cancel: onCancel?()
        case .undo:
            guard model.undoChoice() else { return false }
            onChange?()
        }
        return true
    }

    func state(_ change: Int) -> String {
        ResolveStrings.state(model.choice(change))
    }

    func accessibilityLabel(_ change: Int) -> String {
        ResolveStrings.changeLabel(
            change + 1,
            of: model.changeCount,
            choice: model.choice(change),
            mine: model.mine(change),
            theirs: model.theirs(change)
        )
    }
}

/// The compare view's strings, in the library's catalog (DRAFT until WAIT-3).
enum ResolveStrings {
    /// Use Mine, Use Theirs, Use Both, in sentence case on iOS.
    static var choiceTitles: [String] {
        #if os(macOS)
            [
                String(localized: "res.useMine", defaultValue: "Use Mine", bundle: resourceBundle),
                String(localized: "res.useTheirs", defaultValue: "Use Theirs", bundle: resourceBundle),
                String(localized: "res.useBoth", defaultValue: "Use Both", bundle: resourceBundle)
            ]
        #else
            [
                String(localized: "res.useMine", defaultValue: "Use mine", bundle: resourceBundle),
                String(localized: "res.useTheirs", defaultValue: "Use theirs", bundle: resourceBundle),
                String(localized: "res.useBoth", defaultValue: "Use both", bundle: resourceBundle)
            ]
        #endif
    }

    static let choices: [LineDiff.Choice] = [.mine, .theirs, .both]

    static func count(_ resolved: Int, of total: Int) -> String {
        String(localized: "res.count", defaultValue: "\(resolved) of \(total) resolved", bundle: resourceBundle)
    }

    static func unchanged(_ lines: Int) -> String {
        lines == 1 ? String(localized: "res.unchanged.one", defaultValue: "1 unchanged line", bundle: resourceBundle)
            : String(localized: "res.unchanged", defaultValue: "\(lines) unchanged lines", bundle: resourceBundle)
    }

    static var show: String {
        String(localized: "res.show", defaultValue: "Show", bundle: resourceBundle)
    }

    static var apply: String {
        String(localized: "res.apply", defaultValue: "Apply", bundle: resourceBundle)
    }

    static var cancel: String {
        String(localized: "res.cancel", defaultValue: "Cancel", bundle: resourceBundle)
    }

    static func state(_ choice: LineDiff.Choice?) -> String {
        switch choice {
        case .mine: String(localized: "res.state.mine", defaultValue: "✓ Mine", bundle: resourceBundle)
        case .theirs: String(localized: "res.state.theirs", defaultValue: "✓ Theirs", bundle: resourceBundle)
        case .both: String(localized: "res.state.both", defaultValue: "✓ Both", bundle: resourceBundle)
        case nil: String(localized: "res.state.none", defaultValue: "Not resolved", bundle: resourceBundle)
        }
    }

    /// `mine`, `theirs`, or `both`, inside a sentence.
    private static func side(_ choice: LineDiff.Choice) -> String {
        switch choice {
        case .mine: String(localized: "res.side.mine", defaultValue: "mine", bundle: resourceBundle)
        case .theirs: String(localized: "res.side.theirs", defaultValue: "theirs", bundle: resourceBundle)
        case .both: String(localized: "res.side.both", defaultValue: "both", bundle: resourceBundle)
        }
    }

    static func resolved(_ change: Int, using choice: LineDiff.Choice, left: Int) -> String {
        let side = side(choice)
        return String(
            localized: "res.ax.resolved",
            defaultValue: "Change \(change) resolved, using \(side). \(left) left.",
            bundle: resourceBundle
        )
    }

    static func changeLabel(
        _ change: Int, of total: Int, choice: LineDiff.Choice?, mine: String, theirs: String
    ) -> String {
        let state = choice.map { choice in
            let side = side(choice)
            return String(localized: "res.ax.using", defaultValue: "resolved, using \(side)", bundle: resourceBundle)
        } ?? String(localized: "res.ax.none", defaultValue: "not resolved", bundle: resourceBundle)
        return String(
            localized: "res.ax.change",
            defaultValue: "Change \(change) of \(total), \(state). Mine: \(mine). Theirs: \(theirs).",
            bundle: resourceBundle
        )
    }
}
