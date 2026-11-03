#if os(macOS)
    import AppKit
    import MarkdownViews

    /// The progress of a large file in its window (screens §3.14; log 004
    /// Round 6). The text shows and takes edits once it is loaded.
    @MainActor
    final class LargeLoad {
        let view: NSStackView
        let label: NSTextField
        let indicator = NSProgressIndicator()
        let progress = Progress()
        /// The progress showed: after 300 ms, or before the styling, which takes longer.
        private(set) var wasShown = false
        private var observation: NSKeyValueObservation?

        init(name: String) {
            label = NSTextField(labelWithString: ScrollStrings.opening(name))
            indicator.isIndeterminate = false
            indicator.minValue = 0
            indicator.maxValue = 1
            indicator.widthAnchor.constraint(equalToConstant: 240).isActive = true
            view = NSStackView(views: [label, indicator])
            view.orientation = .vertical
            view.edgeInsets = NSEdgeInsets(top: 40, left: 20, bottom: 40, right: 20)
            view.isHidden = true
            observation = progress.observe(\.fractionCompleted) { [indicator] progress, _ in
                let fraction = progress.fractionCompleted
                Task { @MainActor in indicator.doubleValue = max(indicator.doubleValue, fraction * 0.9) }
            }
        }

        func show() {
            wasShown = true
            view.isHidden = false
        }
    }

    extension DocumentWindowController {
        /// The window opens at once; the file loads off the main thread.
        func beginLargeLoad(_ document: ScrollDocument) {
            let load = LargeLoad(name: document.fileName)
            largeLoad = load
            markdownView.isHidden = true
            contentStack.insertArrangedSubview(load.view, at: 1)
            load.view.widthAnchor.constraint(equalTo: contentStack.widthAnchor).isActive = true
            let timer = Task {
                try await Task.sleep(for: .milliseconds(300))
                load.show()
            }
            largeLoadTask = Task {
                do {
                    try await document.loadLargeFile(load.progress)
                } catch {
                    timer.cancel()
                    refuseLargeFile(document)
                    return
                }
                timer.cancel()
                // A window closed while the file loaded leaves its document.
                guard self.document != nil else { return }
                // ponytail: the styling blocks the main thread; lazy styling waits for a library change (Round 6).
                load.show()
                window?.displayIfNeeded()
                markdownView.reload(text: document.text)
                load.indicator.doubleValue = 1
                load.view.removeFromSuperview()
                markdownView.isHidden = false
                largeLoad = nil
                update()
                window?.makeFirstResponder(markdownView)
            }
        }

        private func refuseLargeFile(_ document: ScrollDocument) {
            environment.presentAlert(
                ScrollDocumentController.alert(for: .notUTF8, name: document.fileName), window
            ) { _ in }
            document.close()
        }
    }
#endif
