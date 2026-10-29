import Foundation
import MarkdownCore
#if os(macOS)
    import AppKit
#else
    import UIKit
#endif

/// Keeps a text storage in step with the controller: the styled source in
/// the editors, the rendered text in rendered mode (design log 001 › Editor,
/// Rendering). Shared by the Mac and iOS views.
@MainActor
final class MarkdownDisplay {
    let controller: MarkdownTextController
    let storage: NSTextStorage
    weak var owner: MarkdownView?
    /// 80% of the viewport height, for drawn images.
    var maxImageHeight: CGFloat = 0
    /// The text column width, for editor thumbnails and cards.
    var columnWidth: CGFloat = 400
    /// The fence state after each line of the editor text; nil for a line
    /// an edit added that no restyle has reached yet.
    private var lineStates: [MarkdownStyler.LineState?] = []

    init(controller: MarkdownTextController, storage: NSTextStorage) {
        self.controller = controller
        self.storage = storage
    }

    var builder: MarkdownAttributedText {
        MarkdownAttributedText(
            theme: MarkdownTheme(surface: controller.mode == .rendered ? .rendered : .editor),
            features: controller.features
        )
    }

    private var styler: MarkdownStyler {
        MarkdownStyler(features: controller.features)
    }

    private var caret: Int {
        controller.selection.lowerBound
    }

    /// Replaces the whole display.
    func rebuild() {
        let string: NSAttributedString
        if controller.mode == .rendered {
            let document = controller.document
            string = builder.rendered(document.rendered, tasks: document.tasks) { attachment($0) }
        } else {
            let lines = styler.styleText(controller.text, caret: caret)
            lineStates = lines.map(\.exiting)
            let styled = NSMutableAttributedString(string: controller.text, attributes: builder.baseAttributes())
            builder.styleEditorLines(lines, in: styled)
            string = styled
        }
        storage.setAttributedString(string)
        if controller.mode != .rendered {
            decorateAllEditorImages(lines: lineRanges(of: controller.text))
        }
    }

    /// Every line's UTF-16 range, without its line ending.
    private func lineRanges(of text: String) -> [Range<Int>] {
        var start = 0
        return text.split(separator: "\n", omittingEmptySubsequences: false).map { line in
            defer { start += line.utf16.count + 1 }
            return start ..< start + line.utf16.count
        }
    }

    /// Decorates `lines` with the images of the whole text, from the controller's model.
    private func decorateAllEditorImages(lines: [Range<Int>]) {
        let images = controller.document.rendered.images.map { image in
            (
                range: controller.utf16Offset(ofSourceByte: image.sourceRange.lowerBound)
                    ..< controller.utf16Offset(ofSourceByte: image.sourceRange.upperBound),
                image: image
            )
        }
        guard !images.isEmpty else { return }
        storage.beginEditing()
        decorateEditorImages(images, lines: lines)
        storage.endEditing()
    }

    /// Brings the display to the controller's text after the controller
    /// changed it: the changed stretch in the editor, all of it in rendered mode.
    func sync() {
        guard controller.mode != .rendered else {
            rebuild()
            return
        }
        let old = Array(storage.string.utf16)
        let new = Array(controller.text.utf16)
        let prefix = zip(old, new).prefix { $0 == $1 }.count
        let limit = min(old.count, new.count) - prefix
        let suffix = zip(old.reversed(), new.reversed()).prefix(limit).prefix { $0 == $1 }.count
        if prefix != old.count || prefix != new.count {
            storage.replaceCharacters(
                in: NSRange(location: prefix, length: old.count - prefix - suffix),
                with: String(decoding: new[prefix ..< new.count - suffix], as: UTF16.self)
            )
        }
        restyle(around: prefix)
    }

    /// Restyles the line with `offset` and the line on each side, then each
    /// following line while the fence state it leaves differs from the one
    /// stored for it: a fence typed or removed restyles every line it changes,
    /// and an edit that changes none restyles three lines. An edit that
    /// starts on the line of `offset` adds or removes lines after that line.
    func restyle(around offset: Int) {
        guard controller.mode != .rendered else { return }
        let text = controller.text
        let utf16 = text.utf16
        let neighborhood = MarkdownStyler.neighborhood(of: min(offset, utf16.count), in: text)
        let lower = utf16.index(utf16.startIndex, offsetBy: neighborhood.lowerBound)
        var end = utf16.index(lower, offsetBy: neighborhood.count)
        let firstLine = Self.newlines(in: text, before: lower)
        // ponytail: counts every line feed on each restyle, O(text) at memory speed;
        // pass the edit's line delta from the text views if a larger text needs it.
        let lineCount = Self.newlines(in: text, before: text.endIndex) + 1
        let offsetIndex = utf16.index(utf16.startIndex, offsetBy: min(offset, utf16.count))
        let editLine = firstLine + utf16[lower ..< offsetIndex].count { $0 == 0x0A }
        // The edit's lines start at `editLine`; the states of the lines after them move with them.
        let delta = lineCount - lineStates.count
        if delta > 0 {
            lineStates.insert(contentsOf: repeatElement(nil, count: delta), at: min(editLine, lineStates.count))
        } else if delta < 0 {
            lineStates.removeSubrange(editLine ..< editLine - delta)
        }
        let entering = firstLine > 0 ? lineStates[firstLine - 1] ?? .init() : .init()
        let base = neighborhood.lowerBound
        let styled = styler.styleText(String(text[lower ..< end]), entering: entering, caret: lineCaret(neighborhood))
        var lines = styled.map { line in
            (
                range: line.range.lowerBound + base ..< line.range.upperBound + base,
                spans: line.spans,
                exiting: line.exiting
            )
        }
        while let last = lines.last, firstLine + lines.count < lineCount {
            guard lineStates[firstLine + lines.count - 1] != last.exiting else { break }
            lineStates[firstLine + lines.count - 1] = last.exiting
            let start = utf16.index(after: end)
            end = utf16[start...].firstIndex(of: 0x0A) ?? utf16.endIndex
            let range = last.range.upperBound + 1 ..< last.range.upperBound + 1 + utf16.distance(from: start, to: end)
            let line = styler.styleLine(String(text[start ..< end]), entering: last.exiting, caret: lineCaret(range))
            lines.append((range, line.spans, line.exiting))
        }
        lineStates.replaceSubrange(firstLine ..< firstLine + lines.count, with: lines.map(\.exiting))
        // The region is parsed alone, so its code lines are blanked: a fence that
        // opens or closes outside the region cannot change what reads as an image.
        var units = Array(utf16[lower ..< end])
        for (index, line) in lines.enumerated() {
            let entersFence = (index == 0 ? entering : lines[index - 1].exiting).isInFence
            guard entersFence || line.exiting.isInFence else { continue }
            let local = line.range.lowerBound - base ..< line.range.upperBound - base
            units.replaceSubrange(local, with: repeatElement(0x20, count: local.count))
        }
        let images = editorImages(in: String(decoding: units, as: UTF16.self), at: base)
        storage.beginEditing()
        builder.style(lines.map { ($0.range, $0.spans) }, in: storage)
        decorateEditorImages(images, lines: lines.map(\.range))
        storage.endEditing()
    }

    /// The caret's offset in a range of lines, or nil when it is outside them.
    private func lineCaret(_ lines: Range<Int>) -> Int? {
        lines.contains(caret) || lines.upperBound == caret ? caret - lines.lowerBound : nil
    }

    /// The line feeds before `index`.
    /// ponytail: O(text) at memory speed, 5 ms per 10 MB on an M1 Max in a release
    /// build; keep a line-start table if a larger text needs it.
    static func newlines(in text: String, before index: String.Index) -> Int {
        let end = text.utf8.distance(from: text.utf8.startIndex, to: index)
        // A plain loop over the buffer; `count(where:)` on a slice of it ran about 50 times slower.
        return text.utf8.withContiguousStorageIfAvailable { bytes in
            var count = 0
            for offset in 0 ..< end where bytes[offset] == 0x0A {
                count += 1
            }
            return count
        } ?? text.utf8[..<index].count { $0 == 0x0A }
    }

    // MARK: images

    func attachment(_ index: Int) -> ImageAttachment {
        let image = controller.document.rendered.images[index]
        return ImageAttachment(
            index: index,
            destination: image.destination,
            content: ImageCardContent(
                result: controller.imageResult(for: index),
                alt: image.alt,
                fallback: controller.presentation.imageFallback,
                isUntitled: controller.documentURL == nil
            ),
            animating: controller.isAnimating(imageIndex: index),
            maxHeight: maxImageHeight,
            owner: owner
        )
    }

    /// Redraws the images of one destination after its result changed.
    func refreshImages(destination: String) {
        guard controller.mode == .rendered else {
            // Only the lines whose marks show that destination change; each is parsed alone.
            var lines: [Range<Int>] = []
            let all = NSRange(location: 0, length: storage.length)
            storage.enumerateAttribute(.markdownEditorImages, in: all) { value, range, _ in
                if let marks = value as? [EditorImageMark], marks.contains(where: { $0.destination == destination }) {
                    lines.append(range.location ..< NSMaxRange(range))
                }
            }
            let text = storage.string as NSString
            storage.beginEditing()
            for line in lines {
                decorateEditorImages(
                    editorImages(in: text.substring(with: NSRange(line)), at: line.lowerBound),
                    lines: [line]
                )
            }
            storage.endEditing()
            return
        }
        let images = controller.document.rendered.images
        storage.beginEditing()
        for index in images.indices where images[index].destination == destination {
            storage.addAttribute(
                .attachment,
                value: attachment(index),
                range: NSRange(location: images[index].offset, length: 1)
            )
        }
        storage.endEditing()
    }
}

/// The edit a text view is applying, from its should-change callback to its did-change callback.
struct PendingEdit {
    let range: Range<Int>
    let replacement: String
    let event: UndoGrouping.Event
}
