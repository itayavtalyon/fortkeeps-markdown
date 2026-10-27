import Foundation
import MarkdownCore
#if os(macOS)
    import AppKit
#else
    import UIKit
#endif

/// A key the view routes to keyboard focus (design log 001 › Accessibility).
enum FocusInput {
    case tab(forward: Bool)
    case returnKey
    case space
    case left
    case right
    case escape
}

enum FocusOutcome: Equatable {
    case handled
    /// Tab moved past the last element, or Shift-Tab past the first.
    case leave(forward: Bool)
    case ignored
}

extension NSTextLayoutManager {
    /// The text range of a UTF-16 range in the document.
    func textRange(_ range: Range<Int>) -> NSTextRange? {
        guard let start = location(at: range.lowerBound), let end = location(at: range.upperBound) else { return nil }
        return NSTextRange(location: start, end: end)
    }

    /// The union of the text segments of a range, in container coordinates.
    func segmentsRect(_ range: Range<Int>) -> CGRect? {
        guard let start = location(at: range.lowerBound), let end = location(at: range.upperBound),
              let textRange = NSTextRange(location: start, end: end)
        else { return nil }
        ensureLayout(for: textRange)
        var union: CGRect?
        enumerateTextSegments(in: textRange, type: .standard, options: []) { _, rect, _, _ in
            union = union.map { $0.union(rect) } ?? rect
            return true
        }
        return union
    }

    /// The fragment that holds an offset, laid out.
    private func markdownFragment(at offset: Int) -> MarkdownLayoutFragment? {
        guard let location = location(at: offset) else { return nil }
        ensureLayout(for: NSTextRange(location: location))
        return textLayoutFragment(for: location) as? MarkdownLayoutFragment
    }

    /// The rectangle a focus ring surrounds, in container coordinates.
    func rect(for target: FocusTarget, rendered: Bool) -> CGRect? {
        switch target {
        case let .link(range), let .box(range):
            return segmentsRect(range)
        case let .checkbox(_, offset):
            guard let fragment = markdownFragment(at: offset),
                  let box = fragment.markerBoxes.first(where: { $0.marker.kind != .bullet })
            else { return nil }
            return box.rect.offsetBy(dx: fragment.layoutFragmentFrame.minX, dy: fragment.layoutFragmentFrame.minY)
        case let .card(_, offset):
            if rendered {
                return segmentsRect(offset ..< offset + 1)
            }
            guard let fragment = markdownFragment(at: offset),
                  let box = fragment.editorImageBoxes.first else { return nil }
            return box.rect.offsetBy(dx: fragment.layoutFragmentFrame.minX, dy: fragment.layoutFragmentFrame.minY)
        }
    }

    /// True when the box at a range is wider than the column.
    func isWideBox(_ range: Range<Int>) -> Bool {
        guard let start = location(at: range.lowerBound), let end = location(at: range.upperBound),
              let textRange = NSTextRange(location: start, end: end)
        else { return false }
        return boxes(in: textRange).contains { $0.contentWidth > $0.frame.width + 0.5 }
    }
}

extension MarkdownView {
    /// Routes a key to keyboard focus in `.rendered` and `.editorLocked`.
    func handle(_ input: FocusInput) -> FocusOutcome {
        guard controller.mode != .editor else { return .ignored }
        switch input {
        case let .tab(forward):
            return moveFocus(forward: forward) ? .handled : .leave(forward: forward)
        case .returnKey, .space:
            guard let target = focusedTarget else { return .ignored }
            return controller.activate(target, key: input == .space ? .space : .returnKey) ? .handled : .ignored
        case .left, .right:
            guard case let .box(range)? = focusedTarget,
                  let box = boxViews.values.first(where: { $0.range.contains(range.lowerBound) })
            else { return .ignored }
            box.scroll(by: input == .left ? -40 : 40)
            return .handled
        case .escape:
            guard focusedTarget != nil else { return .ignored }
            focusedTarget = nil
            return .handled
        }
    }

    /// Moves focus to the next or previous element; false past either end.
    func moveFocus(forward: Bool) -> Bool {
        let targets = controller.focusTargets()
        let current = focusedTarget.flatMap { targets.firstIndex(of: $0) }
        var index = current.map { forward ? $0 + 1 : $0 - 1 } ?? (forward ? 0 : targets.count - 1)
        while targets.indices.contains(index) {
            // A box that fits the column takes no focus.
            if case let .box(range) = targets[index], textView.textLayoutManager?.isWideBox(range) != true {
                index += forward ? 1 : -1
                continue
            }
            focusedTarget = targets[index]
            return true
        }
        focusedTarget = nil
        return false
    }
}

extension FocusInput: Equatable {}
