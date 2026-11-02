#if os(macOS)
    import AppKit
    import MarkdownViews

    /// Opens Markdown files and refuses the rest with an alert (design log
    /// 001 › Files). It keeps one document per path, as `NSDocumentController` does.
    @MainActor
    final class ScrollDocumentController: NSDocumentController {
        /// A document was added or removed: the empty window follows.
        var onDocumentsChange: (() -> Void)?

        override func addDocument(_ document: NSDocument) {
            super.addDocument(document)
            onDocumentsChange?()
        }

        override func removeDocument(_ document: NSDocument) {
            super.removeDocument(document)
            onDocumentsChange?()
        }

        /// Shows a refusal alert; the tests record it instead.
        var presentRefusal: (NSAlert) -> Void = { $0.runModal() } // coverage:ignore - a modal alert

        override var defaultType: String? {
            ScrollDocument.typeName
        }

        override func documentClass(forType _: String) -> AnyClass? {
            ScrollDocument.self
        }

        override func typeForContents(of _: URL) throws -> String {
            ScrollDocument.typeName
        }

        override func openDocument(
            withContentsOf url: URL,
            display displayDocument: Bool,
            completionHandler: @escaping (NSDocument?, Bool, (any Error)?) -> Void
        ) {
            guard DocumentFile.accepts(url) else {
                refuse(.wrongExtension, url, completionHandler)
                return
            }
            super.openDocument(withContentsOf: url, display: displayDocument) { document, wasOpen, error in
                MainActor.assumeIsolated {
                    // NSDocument wraps the error that `read(from:ofType:)` throws.
                    let underlying = (error as NSError?)?.userInfo[NSUnderlyingErrorKey]
                    if let refusal = (underlying as? any Error) as? OpenRefusal {
                        self.refuse(refusal, url, completionHandler)
                    } else {
                        completionHandler(document, wasOpen, error)
                    }
                }
            }
        }

        /// Shows the alert; the system shows nothing more, as for a cancel.
        private func refuse(
            _ refusal: OpenRefusal,
            _ url: URL,
            _ completionHandler: (NSDocument?, Bool, (any Error)?) -> Void
        ) {
            presentRefusal(Self.alert(for: refusal, name: url.lastPathComponent))
            completionHandler(nil, false, CocoaError(.userCancelled))
        }

        static func alert(for refusal: OpenRefusal, name: String) -> NSAlert {
            let alert = NSAlert()
            alert.messageText = ScrollStrings.cannotOpen(name)
            alert.informativeText = switch refusal {
            case .wrongExtension: ScrollStrings.wrongExtension
            case .notUTF8: ScrollStrings.notUTF8
            }
            alert.addButton(withTitle: ScrollStrings.ok)
            return alert
        }
    }
#endif
