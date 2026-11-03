import Foundation
@testable import MarkdownViews

/// A host test double: records every call and answers images from a table.
@MainActor
final class RecordingHost: MarkdownHost {
    var opened: [LinkActivation] = []
    var changes: [TextChange] = []
    var requested: [String] = []
    var cancelled: [String] = []
    var activations: [ImageActivation] = []
    var activated: [String] {
        activations.map(\.destination)
    }

    /// Destinations without an entry wait until cancelled.
    var results: [String: ImageResult] = [:]

    nonisolated func image(for request: ImageRequest) async -> ImageResult {
        await record(request.destination)
        if let result = await results[request.destination] {
            return result
        }
        await withTaskCancellationHandler {
            try? await Task.sleep(for: .seconds(3600))
        } onCancel: {
            Task { @MainActor in self.cancelled.append(request.destination) }
        }
        return .loading
    }

    private func record(_ destination: String) {
        requested.append(destination)
    }

    func open(_ link: LinkActivation) {
        opened.append(link)
    }

    func textDidChange(_ change: TextChange) {
        changes.append(change)
    }

    func activateImage(_ activation: ImageActivation) {
        activations.append(activation)
    }

    var reloaded: [ImageRequest] = []
    var loadAllCount = 0

    func reloadImage(_ request: ImageRequest) {
        reloaded.append(request)
    }

    func loadAllImages() {
        loadAllCount += 1
    }
}

/// Waits for main-actor work started by the code under test, without a clock.
@MainActor
func settle(until condition: () -> Bool) async {
    for _ in 0 ..< 10000 where !condition() {
        await Task.yield()
    }
}
