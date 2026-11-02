import Foundation
import MarkdownViews

/// The sandbox's access to the folders of documents. The app keeps a
/// security-scoped bookmark per folder (design log 001 › Folder access).
public protocol FolderAccess: Sendable {
    func canRead(_ folder: URL) -> Bool
    /// Asks the person for the folder; true when they granted it.
    @MainActor func request(_ folder: URL) async -> Bool
}

/// The image methods of the app's `MarkdownHost` for one document
/// (design log 001 › Images, log 002 › Host interface). A remote image
/// loads only after a click or Load All Images; a loaded image is cached.
@MainActor
public final class DocumentImages {
    /// The untitled-document card (design log 002, Round 3), from the app's string catalog.
    nonisolated static var saveToShow: String {
        String(localized: "img.untitled", defaultValue: "Save the document to show local images.")
    }

    private let loader: RemoteLoader
    private let cache: ImageCache
    private let access: any FolderAccess
    /// The results of fetches in this session, by destination. They are not
    /// remembered after the document closes.
    private var results: [String: ImageResult] = [:]
    private var fetching: Set<String> = []
    /// The destinations that showed the folder-access card.
    private var needAccess: Set<String> = []

    /// The result of a destination changed; the app calls the view's `refreshImage(destination:)`.
    public var onRefresh: ((String) -> Void)?

    public convenience init(transport: any ImageTransport, access: any FolderAccess) {
        self.init(loader: RemoteLoader(transport: transport), cache: .standard, access: access)
    }

    init(loader: RemoteLoader, cache: ImageCache, access: any FolderAccess) {
        self.loader = loader
        self.cache = cache
        self.access = access
    }

    /// Never fetches: a remote image comes from this session or the cache.
    public nonisolated func image(for request: ImageRequest) async -> ImageResult {
        switch (ImageRules.classify(request.destination, documentURL: request.documentURL), request.documentURL) {
        case (.localInUntitled, _):
            return .refused(reason: Self.saveToShow)
        case let (.remote(url), _):
            if let result = await results[request.destination] {
                return result
            }
            return cached(url)
        case let (.local(file), document?):
            let result = local(file, in: document.deletingLastPathComponent())
            if result == .needsAccess {
                await noteNeedsAccess(request.destination)
            }
            return result
        default:
            return .refused(reason: nil)
        }
    }

    private func noteNeedsAccess(_ destination: String) {
        needAccess.insert(destination)
    }

    public func activateImage(_ activation: ImageActivation) {
        switch ImageRules.classify(activation.destination, documentURL: activation.documentURL) {
        case let .remote(url):
            fetch(activation.destination, url, old: nil)
        case .local where activation.card == .needsAccess:
            guard let folder = activation.documentURL?.deletingLastPathComponent() else { return }
            needAccess.insert(activation.destination)
            Task { await requestAccess(folder) }
        default:
            break
        }
    }

    /// Asks for the document's folder. When granted, every card that needed
    /// it refreshes, not only the one clicked.
    @discardableResult
    public func requestAccess(_ folder: URL) async -> Bool {
        guard await access.request(folder) else { return false }
        for destination in needAccess {
            onRefresh?(destination)
        }
        needAccess = []
        return true
    }

    /// A remote image not fetched in this session: the cached copy, or the card.
    /// Synchronous: these lines, after an `await` in `image(for:)`, went uncounted
    /// in 2 of 5 coverage runs (2026-11-02).
    private nonisolated func cached(_ url: URL) -> ImageResult {
        if let data = cache.image(for: url) {
            return .image(data)
        }
        // classify gives .remote only with a host.
        guard let host = url.host() else { return .refused(reason: nil) }
        return .remoteNotLoaded(host: host)
    }

    /// Fetches a fresh copy. On failure the old copy stays, with the reason.
    /// A local image is read again.
    public func reloadImage(_ request: ImageRequest) {
        guard case let .remote(url) = ImageRules.classify(request.destination, documentURL: request.documentURL) else {
            onRefresh?(request.destination)
            return
        }
        var old: Data?
        if case let .image(data, _) = results[request.destination] {
            old = data
        }
        fetch(request.destination, url, old: old ?? cache.image(for: url))
    }

    /// Loads each remote image of `text` that this session has no result for,
    /// this time only.
    public func loadAllImages(in text: String, documentURL: URL?) {
        let document = MarkdownDocument(text: text, features: MarkdownFeatures(), presentation: MarkdownPresentation())
        for image in document.rendered.images where results[image.destination] == nil {
            if case let .remote(url) = ImageRules.classify(image.destination, documentURL: documentURL) {
                fetch(image.destination, url, old: nil)
            }
        }
    }

    /// One fetch per destination at a time. A first load shows `.loading`;
    /// a reload keeps the old image until it ends.
    private func fetch(_ destination: String, _ url: URL, old: Data?) {
        guard fetching.insert(destination).inserted else { return }
        if old == nil {
            results[destination] = .loading
            onRefresh?(destination)
        }
        Task {
            let result = await download(url)
            fetching.remove(destination)
            if case let .failed(reason) = result, let old {
                results[destination] = .image(old, reloadFailure: reason)
            } else {
                results[destination] = result
            }
            onRefresh?(destination)
        }
    }

    private nonisolated func download(_ url: URL) async -> ImageResult {
        let result = await loader.load(url)
        if case let .image(data, _) = result {
            cache.store(data, for: url)
        }
        return result
    }

    /// A regular file inside `folder` after symlinks resolve, at most
    /// 5,000,000 bytes, in an allowed format.
    private nonisolated func local(_ file: URL, in folder: URL) -> ImageResult {
        guard access.canRead(folder) else { return .needsAccess }
        let real = file.resolvingSymlinksInPath()
        let base = folder.resolvingSymlinksInPath().pathComponents
        // The folder itself is not a regular file. A FIFO or a device would block the read.
        guard real.pathComponents.starts(with: base),
              (try? real.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile == true,
              let handle = try? FileHandle(forReadingFrom: real)
        else { return .refused(reason: nil) }
        defer { try? handle.close() }
        // Reads one byte past the limit, so a large file is never read whole. An empty file reads nil.
        guard let data = try? handle.read(upToCount: RemoteLoader.byteLimit + 1) else {
            return .failed(reason: .unsupported)
        }
        guard data.count <= RemoteLoader.byteLimit else { return .failed(reason: .tooLarge) }
        return ImageCheck.check(data).map { .failed(reason: $0) } ?? .image(data)
    }
}
