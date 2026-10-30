import Foundation
import MarkdownCore
#if os(macOS)
    import AppKit
#else
    import UIKit
#endif

/// A key the view routes to keyboard focus (design log 001 › Accessibility).
enum FocusInput: Equatable {
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
        guard let textRange = textRange(range) else { return nil }
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
        textRange(range).map { boxes(in: $0).contains(where: \.isWide) } ?? false
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
            return controller.activate(target, key: input) ? .handled : .ignored
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

    /// Places a box view over each laid-out box wider than the column, in rendered mode.
    func updateBoxes() {
        guard controller.mode == .rendered, let layout = textView.textLayoutManager,
              let range = layout.textRange(firstVisibleOffset ..< min(display.storage.length, lastVisibleOffset + 1))
        else {
            boxViews.values.forEach { $0.removeFromSuperview() }
            boxViews = [:]
            return
        }
        let wide = layout.boxes(in: range).filter(\.isWide)
        for (id, view) in boxViews where !wide.contains(where: { $0.mark.id == id }) {
            view.removeFromSuperview()
            boxViews[id] = nil
        }
        for geometry in wide {
            let view = boxViews[geometry.mark.id] ?? BoxView(mark: geometry.mark)
            boxViews[geometry.mark.id] = view
            if view.superview == nil {
                textView.addSubview(view)
            }
            let content = display.storage.attributedSubstring(from: NSRange(geometry.range))
            view.update(content: content, geometry: geometry, origin: containerOrigin)
        }
        mirrorSelection()
    }

    /// The main selection shows inside each box view too.
    func mirrorSelection() {
        let selection = controller.selection
        for view in boxViews.values {
            let lower = max(selection.lowerBound, view.range.lowerBound)
            let upper = min(selection.upperBound, view.range.upperBound)
            let start = view.range.lowerBound
            view.showSelection(lower < upper ? lower - start ..< upper - start : 0 ..< 0)
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
