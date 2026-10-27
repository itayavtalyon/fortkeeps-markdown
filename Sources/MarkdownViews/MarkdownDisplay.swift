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
    /// Above this size the editor restyles only the edited neighborhood.
    static let fullRestyleLimit = 20 * 1024 * 1024

    let controller: MarkdownTextController
    let storage: NSTextStorage
    weak var owner: MarkdownView?
    /// 80% of the viewport height, for drawn images.
    var maxImageHeight: CGFloat = 0
    /// The text column width, for editor thumbnails and cards.
    var columnWidth: CGFloat = 400
    /// The fence state after each line, from the last full restyle.
    private var lineStates: [MarkdownStyler.LineState] = []
    private var restyleTask: Task<Void, Never>?

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
        restyleTask?.cancel()
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
    /// `destination` keeps only the lines that hold that destination.
    private func decorateAllEditorImages(lines: [Range<Int>], destination: String? = nil) {
        let images = controller.document.rendered.images.map { image in
            (
                range: controller.utf16Offset(ofSourceByte: image.sourceRange.lowerBound)
                    ..< controller.utf16Offset(ofSourceByte: image.sourceRange.upperBound),
                image: image
            )
        }
        let lines = destination.map { destination in
            lines.filter { line in
                images.contains { $0.image.destination == destination && line.contains($0.range.lowerBound) }
            }
        } ?? lines
        guard !images.isEmpty, !lines.isEmpty else { return }
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

    /// Restyles the line with `offset` and the line on each side, then the
    /// whole text after 300 ms without an edit.
    func restyle(around offset: Int) {
        guard controller.mode != .rendered else { return }
        let text = controller.text
        let neighborhood = MarkdownStyler.neighborhood(of: min(offset, text.utf16.count), in: text)
        let units = Array(text.utf16)
        let firstLine = units[..<neighborhood.lowerBound].count { $0 == 0x0A }
        let entering = firstLine > 0 && firstLine - 1 < lineStates.count ? lineStates[firstLine - 1] : .init()
        let lineCaret = neighborhood.contains(caret) || neighborhood.upperBound == caret
            ? caret - neighborhood.lowerBound : nil
        let lines = styler.styleText(
            String(decoding: units[neighborhood], as: UTF16.self),
            entering: entering,
            caret: lineCaret
        )
        let shifted = lines.map { line in
            (
                range: line.range.lowerBound + neighborhood.lowerBound ..< line.range.upperBound + neighborhood
                    .lowerBound,
                spans: line.spans
            )
        }
        storage.beginEditing()
        builder.style(shifted, in: storage)
        decorateEditorImages(
            editorImages(in: String(decoding: units[neighborhood], as: UTF16.self), at: neighborhood.lowerBound),
            lines: shifted.map(\.range)
        )
        storage.endEditing()
        scheduleFullRestyle()
    }

    private func scheduleFullRestyle() {
        restyleTask?.cancel()
        guard controller.text.utf8.count <= Self.fullRestyleLimit else { return }
        restyleTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            self?.fullRestyle()
        }
    }

    func fullRestyle() {
        guard controller.mode != .rendered, storage.string == controller.text else { return }
        let lines = styler.styleText(controller.text, caret: caret)
        lineStates = lines.map(\.exiting)
        storage.beginEditing()
        builder.styleEditorLines(lines, in: storage)
        storage.endEditing()
        decorateAllEditorImages(lines: lines.map(\.range))
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
            guard storage.string == controller.text else { return }
            decorateAllEditorImages(lines: lineRanges(of: controller.text), destination: destination)
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
