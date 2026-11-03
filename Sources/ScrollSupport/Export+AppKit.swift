#if os(macOS)
    import AppKit
    import MarkdownViews

    /// Export as PDF, Export as HTML, Print, and Copy as Rich Text (screens
    /// §3.16; log 004 Round 6).
    extension DocumentWindowController {
        /// 20 mm, in points.
        static let pageMargin: CGFloat = 20 / 25.4 * 72

        private var fileName: String {
            guard let document = scrollDocument else { return "" } // coverage:ignore - a window has its document
            return document.fileName
        }

        private var baseName: String {
            (fileName as NSString).deletingPathExtension
        }

        @objc func exportPDF(_: Any?) {
            Task { await exportPDF() }
        }

        @objc func exportHTML(_: Any?) {
            Task { await exportHTML() }
        }

        @objc func printText(_: Any?) {
            Task { await printText() }
        }

        @objc func copyAsRichText(_: Any?) {
            markdownView.copyAsRichText(to: environment.pasteboard)
        }

        func printText() async {
            await environment.runPrint(printOperation(), window)
        }

        /// The rendered text in reading type on pages with 20 mm margins and no
        /// header. A remote image shows only when it is already loaded.
        func printOperation() async -> NSPrintOperation {
            let info = NSPrintInfo()
            info.topMargin = Self.pageMargin
            info.bottomMargin = Self.pageMargin
            info.leftMargin = Self.pageMargin
            info.rightMargin = Self.pageMargin
            info.dictionary()[NSPrintInfo.AttributeKey.headerAndFooter] = false
            let width = info.paperSize.width - 2 * Self.pageMargin
            let text = await markdownView.printableText(width: width) { [images] in await images.image(for: $0) }
            let view = NSTextView(usingTextLayoutManager: false)
            view.frame = CGRect(x: 0, y: 0, width: width, height: 1)
            view.textContainerInset = .zero
            view.textContainer?.lineFragmentPadding = 0
            view.textStorage?.setAttributedString(text)
            view.sizeToFit()
            let operation = NSPrintOperation(view: view, printInfo: info)
            operation.jobTitle = fileName
            return operation
        }

        func exportPDF() async {
            guard let url = await environment.chooseExportURL(baseName + ".pdf", window) else { return }
            let operation = await printOperation()
            operation.printInfo.jobDisposition = .save
            operation.printInfo.dictionary()[NSPrintInfo.AttributeKey.jobSavingURL] = url
            operation.showsPrintPanel = false
            operation.showsProgressPanel = false
            // A folder it cannot write still runs: the file tells.
            if !operation.run() || !FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) {
                exportFailed(CocoaError(.fileWriteUnknown))
            }
        }

        /// One page with no script; local images as data, remote ones as links.
        func exportHTML() async {
            guard let url = await environment.chooseExportURL(baseName + ".html", window) else { return }
            let page = HTMLExport.page(
                markdown: markdownView.text,
                title: fileName,
                documentURL: scrollDocument?.fileURL,
                features: MarkdownFeatures()
            ) { try? Data(contentsOf: $0) }
            do {
                try Data(page.utf8).write(to: url, options: .atomic)
            } catch {
                exportFailed(error)
            }
        }

        private func exportFailed(_ error: any Error) {
            let alert = NSAlert()
            alert.messageText = ScrollStrings.exportFailed(fileName, error.localizedDescription)
            alert.addButton(withTitle: ScrollStrings.ok)
            environment.presentAlert(alert, window) { _ in }
        }
    }
#endif
