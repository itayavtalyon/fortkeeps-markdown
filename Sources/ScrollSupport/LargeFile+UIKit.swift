#if os(iOS)
    import MarkdownViews
    import UIKit

    /// The progress of a large file on its screen (screens §3.14; log 004
    /// Round 6): "Opening “{name}”…" and a bar, shown after 300 ms.
    @MainActor
    final class LargeLoadView: UIStackView {
        let label = UILabel()
        let bar = UIProgressView(progressViewStyle: .default)
        /// The progress showed: after 300 ms, or before the styling, which takes longer.
        private(set) var wasShown = false

        init(name: String) {
            super.init(frame: .zero)
            label.text = ScrollStrings.opening(name)
            label.font = .preferredFont(forTextStyle: .body)
            label.adjustsFontForContentSizeCategory = true
            label.numberOfLines = 0
            bar.widthAnchor.constraint(equalToConstant: 240).isActive = true
            addArrangedSubview(label)
            addArrangedSubview(bar)
            axis = .vertical
            alignment = .center
            spacing = 12
            isHidden = true
        }

        @available(*, unavailable)
        required init(coder _: NSCoder) {
            fatalError("never built from a nib") // coverage:ignore - never built from a nib
        }

        func show() {
            wasShown = true
            isHidden = false
        }
    }

    extension DocumentViewController {
        /// The screen shows at once; the file reads off the main thread.
        func beginLargeLoad() {
            loadViewIfNeeded()
            let load = LargeLoadView(name: document.fileName)
            largeLoad = load
            markdownView.isHidden = true
            load.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(load)
            NSLayoutConstraint.activate([
                load.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                load.centerYAnchor.constraint(equalTo: view.centerYAnchor),
                load.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, constant: -40)
            ])
            let timer = Task {
                try await Task.sleep(for: .milliseconds(300))
                load.show()
            }
            largeLoadTask = Task {
                let opened = await document.openOnMain()
                timer.cancel()
                // A screen closed while the file loaded.
                guard !Task.isCancelled else { return }
                guard opened else {
                    load.removeFromSuperview()
                    largeLoad = nil
                    onLargeRefusal?()
                    return
                }
                // ponytail: the read is quick and the styling is not; the bar shows the read
                // done, and the styling blocks the main thread until a library change (Round 6).
                load.show()
                load.bar.progress = 0.9
                try? await Task.sleep(for: .milliseconds(50))
                markdownView.reload(text: document.text)
                load.bar.progress = 1
                load.removeFromSuperview()
                largeLoad = nil
                markdownView.isHidden = false
                view.setNeedsLayout() // a relaunch's place applies to the loaded text
                update()
            }
        }
    }
#endif
