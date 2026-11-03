import Foundation
import MarkdownCore
#if os(macOS)
    import AppKit
#else
    import UIKit
#endif

/// Design log 004 › Outside changes: a reload Undo can reverse, and Resolve Apply.
extension MarkdownTextController {
    /// The outside version as one undo group named `undoActionName` (design
    /// log 004 › Outside changes). Only the changed span is replaced, so the
    /// caret stays on its text. Reports `reload`; its undo reports `groupReason` `reload`.
    func reload(text newText: String, undoActionName: String) {
        replaceChangedSpan(with: newText, reason: .reload, event: .reload, actionName: undoActionName)
    }

    /// A Resolve Apply: one undo group with reason `edit`, named `undoActionName` when given.
    func replaceText(_ newText: String, undoActionName: String? = nil) {
        replaceChangedSpan(with: newText, reason: .edit, event: .resolveApply, actionName: undoActionName)
    }

    /// Find's Replace All (screens §3.6): the whole new text as one undo group
    /// with reason `edit`. False, with no change, when it would pass `maxUTF8Bytes`.
    func replaceAll(_ newText: String) -> Bool {
        guard maxUTF8Bytes.map({ newText.utf8.count <= $0 }) ?? true else { return false }
        replaceChangedSpan(with: newText, reason: .edit, event: .replaceAll)
        return true
    }

    /// Copy as Rich Text (log 001 › Windows and chrome): the selected Markdown,
    /// or all of it with nothing selected, parsed alone, as rendered text and
    /// as HTML. A rendered selection takes the hidden syntax at its ends with it.
    func richText() -> (rendered: NSAttributedString, html: String) {
        var markdown = text
        if !selection.isEmpty {
            let start = utf16Offset(ofSourceByte: sourceByte(
                ofDisplayOffset: selection.lowerBound,
                affinity: .backward
            ))
            let end = utf16Offset(ofSourceByte: sourceByte(ofDisplayOffset: selection.upperBound, affinity: .forward))
            markdown = String(decoding: Array(text.utf16)[start ..< max(start, end)], as: UTF16.self)
        }
        let part = MarkdownDocument(text: markdown, features: features, presentation: presentation)
        let rendered = MarkdownAttributedText(theme: MarkdownTheme(surface: .rendered), features: features)
            .rendered(part.rendered, tasks: part.tasks) { _ in NSTextAttachment() }
        let html = HTMLExport.body(markdown: markdown, documentURL: documentURL, features: features) { _ in nil }
        return (rendered, html)
    }

    /// The whole text, rendered, with each image `image` gives; an image
    /// wider than `width` is scaled to fit. One with no image takes no room.
    func printableText(width: CGFloat, image: (ImageRequest) async -> ImageResult) async -> NSAttributedString {
        let document = document
        var pictures: [Int: PlatformImage] = [:]
        for (index, item) in document.rendered.images.enumerated() {
            let request = ImageRequest(
                destination: item.destination, documentURL: documentURL, maxPixelSize: maxImagePixelSize
            )
            if case let .image(data, _) = await image(request), let picture = PlatformImage(data: data) {
                pictures[index] = picture
            }
        }
        return MarkdownAttributedText(theme: MarkdownTheme(surface: .rendered), features: features)
            .rendered(document.rendered, tasks: document.tasks) { index in
                let attachment = NSTextAttachment()
                if let picture = pictures[index] {
                    let scale = min(1, width / picture.size.width)
                    attachment.image = picture
                    attachment.bounds.size = CGSize(
                        width: picture.size.width * scale, height: picture.size.height * scale
                    )
                }
                return attachment
            }
    }

    private func replaceChangedSpan(
        with newText: String,
        reason: TextChange.Reason,
        event: UndoGrouping.Event,
        actionName: String? = nil
    ) {
        let old = Array(text.utf16)
        let new = Array(newText.utf16)
        // Whole characters only: the span starts and ends outside a surrogate pair.
        var prefix = zip(old, new).prefix { $0 == $1 }.count
        if prefix > 0, UTF16.isLeadSurrogate(old[prefix - 1]) {
            prefix -= 1
        }
        var suffix = zip(old[prefix...].reversed(), new[prefix...].reversed()).prefix { $0 == $1 }.count
        if suffix > 0, UTF16.isTrailSurrogate(old[old.count - suffix]) {
            suffix -= 1
        }
        let span = prefix ..< old.count - suffix
        guard !span.isEmpty || new.count != old.count else { return }
        let replacement = String(decoding: new[prefix ..< new.count - suffix], as: UTF16.self)
        let delta = new.count - old.count
        // A bound after the span moves with it; one inside it goes to the span's new end.
        let moved = { (bound: Int) in
            bound <= span.lowerBound ? bound : bound >= span.upperBound ? bound + delta
                : min(bound, span.lowerBound + replacement.utf16.count)
        }
        let kept = moved(selection.lowerBound) ..< moved(selection.upperBound)
        let edit = TextEdit(range: span, replacement: replacement, selection: kept)
        apply(edit, reason: reason, event: event, time: 0, actionName: actionName)
        selection = kept
        onDisplayChange?()
    }

    // MARK: the model off the main thread

    /// The model of the current text, built off the main thread when needed.
    func loadDocument() async -> MarkdownDocument {
        if let cachedDocument {
            return cachedDocument
        }
        let (text, features, presentation) = (text, features, presentation)
        let built = await Task.detached {
            MarkdownDocument(text: text, features: features, presentation: presentation)
        }.value
        keep(built, for: text)
        return built
    }

    /// A model built for `source` is kept only while the text is still `source`.
    func keep(_ document: MarkdownDocument, for source: String) {
        if source == text {
            cachedDocument = document
        }
    }
}
