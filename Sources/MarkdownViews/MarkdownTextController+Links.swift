import Foundation
import MarkdownCore

/// Links, copy, and images of the controller.
extension MarkdownTextController {
    // MARK: links

    /// In the editor a click places the caret and Command-click follows the
    /// link; in the locked editor and in rendered mode a click follows it.
    /// Returns true when the click followed a link.
    @discardableResult
    func click(atDisplayOffset offset: Int, modifiers: LinkModifiers) -> Bool {
        guard mode != .editor || modifiers.contains(.command),
              let link = link(atDisplayOffset: offset) else { return false }
        open(link.destination, modifiers: modifiers)
        return true
    }

    /// The `Image: {alt}` link of a refused image.
    func openImageLink(_ index: Int, modifiers: LinkModifiers) {
        open(document.rendered.images[index].destination, modifiers: modifiers)
    }

    private func open(_ destination: String, modifiers: LinkModifiers) {
        host?.open(LinkActivation(
            destination: destination,
            resolvedURL: Self.resolvedURL(destination, documentURL: documentURL),
            documentURL: documentURL,
            modifiers: modifiers,
            source: .markdown
        ))
    }

    /// The task whose checkbox is at a display offset: the block's first
    /// character in rendered mode, the marker characters in the editor.
    func taskIndex(atDisplayOffset offset: Int) -> Int? {
        if mode == .rendered {
            return document.rendered.blocks.first { $0.range.lowerBound == offset && $0.taskIndex != nil }?.taskIndex
        }
        return document.tasks.first { abs(utf16Offset(ofSourceByte: $0.byteOffset) - offset) <= 1 }?.index
    }

    func link(atDisplayOffset offset: Int) -> RenderedText.Link? {
        let links = document.rendered.links
        if mode == .rendered {
            return links.first { $0.range.contains(offset) }
        }
        let byte = sourceByte(ofUTF16: offset)
        return links.first { $0.sourceRange.contains(byte) }
    }

    private static func resolvedURL(_ destination: String, documentURL: URL?) -> URL? {
        switch LinkRules.classify(destination, documentURL: documentURL) {
        case let .browser(url), let .mail(url), let .siblingFile(url): url
        case .fragment, .none: nil
        }
    }

    // MARK: copy

    /// Rendered mode copies the drawn characters; the editor copies the source.
    func copyText(_ range: Range<Int>) -> String {
        guard mode == .rendered else {
            return String(decoding: Array(text.utf16)[range], as: UTF16.self)
        }
        let rendered = document.rendered
        let drawnAsText = rendered.images.indices.filter { imageDrawsAsText($0) }
        return rendered.copyText(range, imagesDrawnAsText: Set(drawnAsText))
    }

    /// A refused image draws `Image: {alt}` as a link with the `.link` fallback.
    func imageDrawsAsText(_ index: Int) -> Bool {
        guard case .refused? = imageResult(for: index) else { return false }
        return presentation.imageFallback == .link
    }

    // MARK: images

    /// Requests the images within one viewport above and below the visible
    /// range, and cancels the requests of images that left it.
    func viewportChanged(_ visible: Range<Int>) {
        let near = visible.lowerBound - visible.count ... visible.upperBound + visible.count
        let wanted: Set<String>
        if mode == .rendered {
            let images = document.rendered.images
            wanted = Set(images.indices.filter { near.contains(images[$0].offset) }.map { images[$0].destination })
        } else {
            // The editor parses only the lines near the viewport, not the whole text after each edit.
            let count = text.utf16.count
            let lines = MarkdownStyler.lines(
                touching: min(max(near.lowerBound, 0), count) ..< min(max(near.upperBound, 0), count),
                in: text
            )
            let region = MarkdownDocument(
                text: String(decoding: lines.units, as: UTF16.self),
                features: features,
                presentation: presentation
            )
            wanted = Set(region.rendered.images.map(\.destination))
        }
        for (destination, task) in imageTasks where !wanted.contains(destination) {
            task.cancel()
            imageTasks[destination] = nil
        }
        for destination in wanted where imageResults[destination] == nil && imageTasks[destination] == nil {
            request(destination)
        }
    }

    /// A click on an editor image: true when there is one. A card with a
    /// button activates it.
    func click(_ mark: EditorImageMark?) -> Bool {
        guard let mark else { return false }
        if mark.content.activates {
            activateImage(destination: mark.destination)
        }
        return true
    }

    /// The person activated a card: the view draws the loading card and
    /// tells the host, which refreshes the result when it has one.
    func activateImage(destination: String) {
        guard let card = imageResults[destination] else { return }
        imageTasks[destination]?.cancel()
        imageTasks[destination] = nil
        setImageResult(.loading, for: destination)
        host?.activateImage(ImageActivation(destination: destination, documentURL: documentURL, card: card))
    }

    /// The image items of a context menu: Reload Image on a drawn image, and
    /// Load All Images in This Document while a remote image is not loaded.
    func imageMenuItems(destination: String?) -> [ImageMenuItem] {
        var items: [ImageMenuItem] = []
        if let destination, case .image? = imageResults[destination] {
            items.append(.reload(destination))
        }
        let notLoaded = document.rendered.images.contains { image in
            guard case .remote = ImageRules.classify(image.destination, documentURL: documentURL) else { return false }
            switch imageResults[image.destination] {
            case nil, .remoteNotLoaded?: return true
            default: return false
            }
        }
        if notLoaded {
            items.append(.loadAll)
        }
        return items
    }

    /// The destination of the image whose source holds a display offset.
    func imageDestination(atDisplayOffset offset: Int) -> String? {
        let byte = sourceByte(ofDisplayOffset: offset)
        return document.rendered.images.first { $0.sourceRange.contains(byte) }?.destination
    }

    func perform(_ item: ImageMenuItem) {
        switch item {
        case let .reload(destination):
            host?.reloadImage(ImageRequest(
                destination: destination,
                documentURL: documentURL,
                maxPixelSize: maxImagePixelSize
            ))
        case .loadAll:
            host?.loadAllImages()
        }
    }

    /// The host has a new result for a destination.
    func refreshImage(destination: String) {
        imageResults[destination] = nil
        imageTasks[destination]?.cancel()
        onImageChange?(destination)
        request(destination)
    }

    private func request(_ destination: String) {
        guard let host else { return }
        let request = ImageRequest(destination: destination, documentURL: documentURL, maxPixelSize: maxImagePixelSize)
        lastImageRequest = request
        imageTasks[destination] = Task { [weak self] in
            let result = await host.image(for: request)
            guard !Task.isCancelled else { return }
            self?.imageTasks[destination] = nil
            self?.setImageResult(result, for: destination)
        }
    }

    /// Caches a result for the lifetime of the document.
    func setImageResult(_ result: ImageResult, for destination: String) {
        imageResults[destination] = result
        onImageChange?(destination)
        if case let .image(_, failure?) = result {
            onAnnouncement?(Strings.reloadFailed(failure))
        }
    }

    func imageResult(for index: Int) -> ImageResult? {
        imageResults[document.rendered.images[index].destination]
    }

    /// A gif plays unless Reduce Motion is on.
    func isAnimating(imageIndex: Int) -> Bool {
        guard case let .image(data, _) = imageResult(for: imageIndex) else { return false }
        return data.starts(with: Array("GIF8".utf8)) && !reduceMotion
    }
}

/// An image item of the view's context menu (design log 001 › Images).
enum ImageMenuItem: Equatable {
    case reload(String)
    case loadAll

    var title: String {
        switch self {
        case .reload: String(localized: "img.reload", defaultValue: "Reload Image", bundle: resourceBundle)
        case .loadAll:
            String(localized: "img.loadAll", defaultValue: "Load All Images in This Document", bundle: resourceBundle)
        }
    }
}
