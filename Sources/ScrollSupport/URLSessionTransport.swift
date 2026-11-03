import Foundation

/// The `ImageTransport` of the app: an ephemeral session with no cookie
/// store and no cache, which returns a redirect instead of following it.
public final class URLSessionTransport: ImageTransport {
    let session: URLSession

    public init(configuration: URLSessionConfiguration = .ephemeral) {
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.httpCookieAcceptPolicy = .never
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        session = URLSession(configuration: configuration, delegate: RefuseRedirects(), delegateQueue: nil)
    }

    deinit {
        session.invalidateAndCancel()
    }

    public func send(_ request: URLRequest, limit: Int) async throws(TransportFailure) -> TransportResponse {
        do {
            let (bytes, response) = try await session.bytes(for: request)
            guard let http = response as? HTTPURLResponse
            else { throw TransportFailure.network } // coverage:ignore - https answers with HTTPURLResponse
            var body = Data()
            for try await byte in bytes {
                body.append(byte)
                if body.count > limit {
                    break
                }
            }
            return TransportResponse(
                status: http.statusCode,
                location: http.value(forHTTPHeaderField: "Location"),
                body: body
            )
        } catch let error as URLError where error.code == .timedOut {
            throw .timedOut
        } catch {
            throw .network
        }
    }
}

private final class RefuseRedirects: NSObject, URLSessionTaskDelegate {
    func urlSession(
        _: URLSession,
        task _: URLSessionTask,
        willPerformHTTPRedirection _: HTTPURLResponse,
        newRequest _: URLRequest
    ) async -> URLRequest? {
        nil
    }
}
