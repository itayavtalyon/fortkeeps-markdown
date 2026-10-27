import Foundation
import MarkdownCore

/// One element the keyboard focuses in `.rendered` and `.editorLocked`
/// (design log 001 › Accessibility). Offsets are display offsets.
enum FocusTarget: Equatable {
    case link(Range<Int>)
    case checkbox(task: Int, offset: Int)
    /// A rendered image that is not drawn (a card or the `.link` fallback), or an editor card.
    case card(destination: String, offset: Int)
    /// A rendered code block or table run; the view keeps only the wide ones.
    case box(Range<Int>)

    var offset: Int {
        switch self {
        case let .link(range), let .box(range): range.lowerBound
        case let .checkbox(_, offset), let .card(_, offset): offset
        }
    }
}

/// The keys a focused element answers.
enum FocusKey {
    case returnKey
    case space
}

extension MarkdownTextController {
    /// The focusable elements in reading order. The editor has none: Tab types a tab there.
    func focusTargets() -> [FocusTarget] {
        guard mode != .editor else { return [] }
        let rendered = document.rendered
        var targets: [FocusTarget] = []
        if mode == .rendered {
            targets += rendered.links.map { .link($0.range) }
            targets += rendered.blocks.compactMap { block in
                block.taskIndex.map { .checkbox(task: $0, offset: block.range.lowerBound) }
            }
            targets += rendered.images.indices.compactMap { index in
                if case .image = imageResult(for: index) {
                    return nil
                }
                return .card(destination: rendered.images[index].destination, offset: rendered.images[index].offset)
            }
            targets += boxRanges(rendered.blocks).map { .box($0) }
        } else {
            targets += rendered.links.map { link in
                .link(displayOffset(ofSourceByte: link.sourceRange.lowerBound)
                    ..< displayOffset(ofSourceByte: link.sourceRange.upperBound))
            }
            targets += document.tasks.map { task in
                .checkbox(task: task.index, offset: max(0, displayOffset(ofSourceByte: task.byteOffset) - 1))
            }
            targets += rendered.images.map { image in
                .card(destination: image.destination, offset: displayOffset(ofSourceByte: image.sourceRange.lowerBound))
            }
        }
        return targets.enumerated().sorted { ($0.element.offset, $0.offset) < ($1.element.offset, $1.offset) }
            .map(\.element)
    }

    /// Each code block, and each run of table rows, as one rendered range.
    private func boxRanges(_ blocks: [RenderedText.Block]) -> [Range<Int>] {
        var ranges: [Range<Int>] = []
        var previousWasRow = false
        for block in blocks {
            switch block.kind {
            case .codeBlock:
                ranges.append(block.range)
                previousWasRow = false
            case .tableRow:
                if previousWasRow, let last = ranges.popLast() {
                    ranges.append(last.lowerBound ..< block.range.upperBound)
                } else {
                    ranges.append(block.range)
                }
                previousWasRow = true
            default:
                previousWasRow = false
            }
        }
        return ranges
    }

    /// Return opens a link; Space toggles a checkbox; either activates a
    /// card that has a button. Returns false when the key does nothing.
    func activate(_ target: FocusTarget, key: FocusKey, modifiers: LinkModifiers = []) -> Bool {
        switch (target, key) {
        case let (.link(range), .returnKey):
            return click(atDisplayOffset: range.lowerBound, modifiers: modifiers)
        case let (.checkbox(task, _), .space):
            guard checkboxAccessibility(task).isEnabled else { return false }
            toggleTask(task)
            return true
        case let (.card(destination, _), _):
            return activateCard(destination: destination)
        default:
            return false
        }
    }

    private func activateCard(destination: String) -> Bool {
        let images = document.rendered.images
        guard let index = images.indices.first(where: { images[$0].destination == destination }) else { return false }
        let content = ImageCardContent(
            result: imageResult(for: index),
            alt: images[index].alt,
            fallback: mode == .rendered ? presentation.imageFallback : .text
        )
        if content.kind == .link {
            openImageLink(index, modifiers: [])
            return true
        }
        guard content.activates else { return false }
        activateImage(destination: destination)
        return true
    }
}
