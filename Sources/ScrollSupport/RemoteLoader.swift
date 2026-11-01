import Foundation
import MarkdownCore
import MarkdownViews

/// One HTTP exchange. A transport follows no redirect and sends no cookie;
/// it reads at most `limit + 1` bytes of the body, so the caller can tell
/// a body over the limit.
public protocol ImageTransport: Sendable {
    func send(_ request: URLRequest, limit: Int) async throws(TransportFailure) -> TransportResponse
}

public struct TransportResponse: Equatable, Sendable {
    public let status: Int
    /// The `Location` header of a redirect.
    public let location: String?
    public let body: Data

    public init(status: Int, location: String?, body: Data) {
        self.status = status
        self.location = location
        self.body = body
    }
}

public enum TransportFailure: Error, Equatable {
    case timedOut
    case network
}

/// Loads a remote image with the rules of design log 001 › Images: at most
/// 5,000,000 bytes, 3 redirects each checked like the first URL, no cookies,
/// and 10 seconds in all.
struct RemoteLoader {
    static let byteLimit = 5_000_000
    static let redirectLimit = 3

    let transport: any ImageTransport
    var timeout: Duration = .seconds(10)

    func load(_ url: URL) async -> ImageResult {
        await withTaskGroup(of: ImageResult.self) { group in
            group.addTask { await follow(url) }
            group.addTask {
                try? await Task.sleep(for: timeout)
                return .failed(reason: .timedOut)
            }
            for await first in group {
                group.cancelAll()
                return first
            }
            return .failed(reason: .timedOut) // coverage:ignore - the group has two tasks
        }
    }

    private func follow(_ url: URL) async -> ImageResult {
        var url = url
        var redirects = 0
        while true {
            var request = URLRequest(url: url)
            request.httpShouldHandleCookies = false
            let response: TransportResponse
            do {
                response = try await transport.send(request, limit: Self.byteLimit)
            } catch {
                return .failed(reason: error == .timedOut ? .timedOut : .network)
            }
            switch response.status {
            case 200 ..< 300:
                guard response.body.count <= Self.byteLimit else { return .failed(reason: .tooLarge) }
                return ImageCheck.check(response.body).map { .failed(reason: $0) } ?? .image(response.body)
            case 300 ..< 400 where response.location != nil:
                guard redirects < Self.redirectLimit else { return .failed(reason: .network) }
                redirects += 1
                guard let next = response.location.flatMap({ URL(string: $0, relativeTo: url)?.absoluteString }),
                      case let .remote(checked) = ImageRules.classify(next, documentURL: nil)
                else { return .refused(reason: nil) }
                url = checked
            default:
                return .failed(reason: .network)
            }
        }
    } // coverage:ignore - the loop leaves only by a return
}
