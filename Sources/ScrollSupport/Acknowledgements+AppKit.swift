#if os(macOS)
    import AppKit

    /// One shipped dependency (design log 001 › Product), from
    /// `Acknowledgements/acknowledgements.json` in the app bundle.
    struct Acknowledgement: Decodable, Equatable {
        let name: String
        let license: String
        let file: String
        var text = ""

        private enum CodingKeys: String, CodingKey {
            case name, license, file
        }

        /// The entries with their license texts; none when the folder is missing.
        static func load(from folder: URL?) -> [Acknowledgement] {
            guard let folder,
                  let data = try? Data(contentsOf: folder.appending(path: "acknowledgements.json")),
                  let entries = try? JSONDecoder().decode([Acknowledgement].self, from: data)
            else { return [] }
            return entries.map { entry in
                var entry = entry
                entry.text = (try? String(contentsOf: folder.appending(path: entry.file), encoding: .utf8)) ?? ""
                return entry
            }
        }
    }

    /// Fortkeeps Scroll › Acknowledgements: each name and license, then its full text.
    @MainActor
    final class AcknowledgementsWindowController: NSWindowController {
        let textView = NSTextView()

        init(entries: [Acknowledgement]) {
            let window = NSWindow(
                contentRect: CGRect(x: 0, y: 0, width: 560, height: 600),
                styleMask: [.titled, .closable, .resizable, .miniaturizable],
                backing: .buffered,
                defer: true
            )
            window.title = String(localized: "Acknowledgements")
            window.tabbingMode = .disallowed
            super.init(window: window)
            let text = NSMutableAttributedString()
            for entry in entries {
                text.append(NSAttributedString(string: "\(entry.name) — \(entry.license)\n\n", attributes: [
                    .font: NSFont.boldSystemFont(ofSize: NSFont.systemFontSize), .foregroundColor: NSColor.labelColor
                ]))
                text.append(NSAttributedString(string: entry.text + "\n\n", attributes: [
                    .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize), .foregroundColor: NSColor.labelColor
                ]))
            }
            textView.textStorage?.setAttributedString(text)
            textView.isEditable = false
            textView.textContainerInset = NSSize(width: 16, height: 16)
            textView.autoresizingMask = [.width]
            let scroll = NSScrollView()
            scroll.hasVerticalScroller = true
            scroll.documentView = textView
            window.contentView = scroll
            window.center()
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            nil
        }
    }
#endif
