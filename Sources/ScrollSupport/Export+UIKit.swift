#if os(iOS)
    import MarkdownViews
    import UIKit

    /// The ⋯ menu (screens §3.20), its Export submenu (§3.16; log 004 Round 6),
    /// and Share: the system share sheet for the file itself.
    extension DocumentViewController {
        /// 20 mm, in points.
        static let pageMargin: CGFloat = 20 / 25.4 * 72

        /// US Letter where the region measures in inches, else A4.
        static var paperSize: CGSize {
            Locale.current.measurementSystem == .us ? CGSize(width: 612, height: 792) : CGSize(width: 595, height: 842)
        }

        private var baseName: String {
            (document.fileName as NSString).deletingPathExtension
        }

        func moreMenu() -> UIMenu {
            var items: [UIMenuElement] = [UIAction(title: ScrollStrings.find) { [weak self] _ in
                self?.markdownView.showFind()
            }]
            if !isReadOnly {
                let title = markdownView.mode == .editorLocked ? ScrollStrings.unlock : ScrollStrings.lock
                items.append(UIAction(title: title) { [weak self] _ in self?.toggleLock() })
            }
            items.append(UIMenu(title: ScrollStrings.export, children: [
                UIAction(title: ScrollStrings.exportPDF) { [weak self] _ in Task { await self?.exportPDF() } },
                UIAction(title: ScrollStrings.exportHTML) { [weak self] _ in self?.exportHTML() },
                UIAction(title: ScrollStrings.print) { [weak self] _ in Task { await self?.printText() } },
                UIAction(title: ScrollStrings.copyRichText) { [weak self] _ in
                    guard let self else { return } // coverage:ignore - the menu goes with its screen
                    markdownView.copyAsRichText(to: environment.pasteboard)
                }
            ]))
            items.append(UIAction(title: ScrollStrings.settings) { [weak self] _ in self?.showSettings() })
            return UIMenu(children: items)
        }

        func share() {
            let sheet = UIActivityViewController(activityItems: [document.fileURL], applicationActivities: nil)
            sheet.popoverPresentationController?.sourceItem = navigationItem.rightBarButtonItems?[1]
            environment.present(sheet, self)
        }

        /// One page with no script; local images as data, remote ones as links.
        @discardableResult
        func exportHTML() -> URL? {
            let page = HTMLExport.page(
                markdown: markdownView.text,
                title: document.fileName,
                documentURL: document.fileURL,
                features: MarkdownFeatures()
            ) { try? Data(contentsOf: $0) }
            return export(Data(page.utf8), baseName + ".html")
        }

        @discardableResult
        func exportPDF() async -> URL? {
            let renderer = PageRenderer(paper: Self.paperSize)
            await renderer.addPrintFormatter(printFormatter(), startingAtPageAt: 0)
            let data = UIGraphicsPDFRenderer(bounds: renderer.paperRect).pdfData { context in
                renderer.prepare(forDrawingPages: NSRange(location: 0, length: renderer.numberOfPages))
                for page in 0 ..< renderer.numberOfPages {
                    context.beginPage()
                    renderer.drawPage(at: page, in: renderer.paperRect)
                }
            }
            return export(data, baseName + ".pdf")
        }

        func printText() async {
            let printer = UIPrintInteractionController.shared
            let info = UIPrintInfo.printInfo()
            info.jobName = document.fileName
            printer.printInfo = info
            printer.printFormatter = await printFormatter()
            environment.runPrint(printer, self)
        }

        /// The Files export sheet; unlike Save As, the copy does not open.
        private func export(_ data: Data, _ name: String) -> URL? {
            do {
                let url = try temporaryFile(name, data)
                environment.present(UIDocumentPickerViewController(forExporting: [url], asCopy: true), self)
                return url
            } catch {
                showError(error) // coverage:ignore - the app's temporary folder is always writable
                return nil // coverage:ignore - as above
            } // coverage:ignore - as above
        }

        /// The rendered text in reading type, 20 mm from each edge of the page. A
        /// remote image shows only when it is already loaded.
        private func printFormatter() async -> UIPrintFormatter {
            let width = Self.paperSize.width - 2 * Self.pageMargin
            let text = await markdownView.printableText(width: width) { [images] in await images.image(for: $0) }
            let view = UITextView(usingTextLayoutManager: false)
            view.frame = CGRect(x: 0, y: 0, width: width, height: 1)
            view.textContainerInset = .zero
            view.textContainer.lineFragmentPadding = 0
            view.attributedText = text
            let formatter = view.viewPrintFormatter()
            let margin = Self.pageMargin
            formatter.perPageContentInsets = UIEdgeInsets(top: margin, left: margin, bottom: margin, right: margin)
            return formatter
        }
    }

    /// Pages of one size for the PDF; the print sheet gives its own paper.
    private final class PageRenderer: UIPrintPageRenderer {
        private let paper: CGRect

        init(paper: CGSize) {
            self.paper = CGRect(origin: .zero, size: paper)
        }

        override var paperRect: CGRect {
            paper
        }

        override var printableRect: CGRect {
            paper
        }
    }
#endif
