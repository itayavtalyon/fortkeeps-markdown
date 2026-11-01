import Foundation
import ScrollSupport
import Synchronization

/// A transport test double: answers each URL from a table and records every request.
final class FakeTransport: ImageTransport {
    private let answers: Mutex<[String: Result<TransportResponse, TransportFailure>]>
    private let log = Mutex<[(URLRequest, Int)]>([])
    /// A URL with no answer waits until the load is cancelled.
    init(_ answers: [String: Result<TransportResponse, TransportFailure>]) {
        self.answers = Mutex(answers)
    }

    func answer(_ url: String, with answer: Result<TransportResponse, TransportFailure>) {
        answers.withLock { $0[url] = answer }
    }

    var requests: [URLRequest] {
        log.withLock { $0.map(\.0) }
    }

    var limits: [Int] {
        log.withLock { $0.map(\.1) }
    }

    func send(_ request: URLRequest, limit: Int) async throws(TransportFailure) -> TransportResponse {
        log.withLock { $0.append((request, limit)) }
        guard let answer = answers.withLock({ $0[request.url?.absoluteString ?? ""] }) else {
            try? await Task.sleep(for: .seconds(3600))
            throw .network
        }
        let response = try answer.get()
        return TransportResponse(
            status: response.status,
            location: response.location,
            body: response.body.prefix(limit + 1)
        )
    }

    static func ok(_ body: Data) -> Result<TransportResponse, TransportFailure> {
        .success(TransportResponse(status: 200, location: nil, body: body))
    }

    static func redirect(_ location: String, status: Int = 302) -> Result<TransportResponse, TransportFailure> {
        .success(TransportResponse(status: status, location: location, body: Data()))
    }
}
