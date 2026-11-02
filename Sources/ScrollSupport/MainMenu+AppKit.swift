#if os(macOS)
    import AppKit
    import MarkdownViews

    /// The menu bar (screens §3.18), with the commands of stage 2c (design
    /// log 004, Round 3). Each command goes to the first responder.
    @MainActor
    enum MainMenu {
        static func make() -> NSMenu {
            let menu = NSMenu()
            for (title, submenu) in [
                ("Fortkeeps Scroll", appMenu()), (String(localized: "File"), fileMenu()),
                (String(localized: "Edit"), editMenu()), (String(localized: "Format"), formatMenu()),
                (String(localized: "View"), viewMenu()), (String(localized: "Window"), windowMenu()),
                (String(localized: "Help"), NSMenu())
            ] {
                submenu.title = title
                menu.addItem(withTitle: title, action: nil, keyEquivalent: "").submenu = submenu
            }
            return menu
        }

        private static func item(
            _ title: String,
            _ action: Selector?,
            _ key: String = "",
            _ modifiers: NSEvent.ModifierFlags = .command,
            tag: Int = 0
        ) -> NSMenuItem {
            let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
            item.keyEquivalentModifierMask = key.isEmpty ? [] : modifiers
            item.tag = tag
            return item
        }

        private static func menu(_ title: String, _ items: [NSMenuItem]) -> NSMenuItem {
            let submenu = NSMenu(title: title)
            submenu.items = items
            let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            item.submenu = submenu
            return item
        }

        private static func appMenu() -> NSMenu {
            let services = menu(String(localized: "Services"), [])
            NSApp?.servicesMenu = services.submenu
            let menu = NSMenu()
            menu.items = [
                item(
                    String(localized: "About Fortkeeps Scroll"),
                    #selector(NSApplication.orderFrontStandardAboutPanel(_:))
                ),
                item(String(localized: "Acknowledgements"), #selector(ScrollAppDelegate.showAcknowledgements)),
                .separator(), services, .separator(),
                item(String(localized: "Hide Fortkeeps Scroll"), #selector(NSApplication.hide(_:)), "h"),
                item(
                    String(localized: "Hide Others"),
                    #selector(NSApplication.hideOtherApplications(_:)),
                    "h",
                    [.command, .option]
                ),
                item(String(localized: "Show All"), #selector(NSApplication.unhideAllApplications(_:))),
                .separator(),
                item(String(localized: "Quit Fortkeeps Scroll"), #selector(NSApplication.terminate(_:)), "q")
            ]
            return menu
        }

        private static func fileMenu() -> NSMenu {
            let menu = NSMenu()
            menu.items = [
                item(ScrollStrings.newFile, #selector(NSDocumentController.newDocument(_:)), "n"),
                // AppKit adds Open Recent after Open… at launch.
                item(String(localized: "Open…"), #selector(NSDocumentController.openDocument(_:)), "o"),
                .separator(),
                item(String(localized: "Close Tab"), #selector(NSWindow.performClose(_:)), "w"),
                item(
                    String(localized: "Close Window"),
                    #selector(DocumentWindowController.closeWindow),
                    "w",
                    [.command, .shift]
                ),
                item(String(localized: "Save…"), #selector(DocumentWindowController.saveDocument), "s"),
                item(String(localized: "Duplicate"), #selector(NSDocument.duplicate(_:)), "s", [.command, .shift]),
                item(String(localized: "Rename…"), #selector(NSDocument.rename(_:))),
                item(String(localized: "Move To…"), #selector(NSDocument.move(_:))),
                item(String(localized: "Revert to Saved"), #selector(NSDocument.revertToSaved(_:)))
            ]
            return menu
        }

        private static func editMenu() -> NSMenu {
            let menu = NSMenu()
            menu.items = [
                // The text view's `undo:` and `redo:` are internal to MarkdownViews.
                item(String(localized: "Undo"), NSSelectorFromString("undo:"), "z"),
                item(String(localized: "Redo"), NSSelectorFromString("redo:"), "z", [.command, .shift]),
                .separator(),
                item(String(localized: "Cut"), #selector(NSText.cut(_:)), "x"),
                item(String(localized: "Copy"), #selector(NSText.copy(_:)), "c"),
                item(String(localized: "Paste"), #selector(NSText.paste(_:)), "v"),
                item(
                    String(localized: "Paste and Match Style"),
                    #selector(NSTextView.pasteAsPlainText(_:)),
                    "v",
                    [.command, .option, .shift]
                ),
                item(String(localized: "Select All"), #selector(NSText.selectAll(_:)), "a"),
                .separator(),
                findMenu(),
                self.menu(String(localized: "Spelling"), [
                    item(
                        String(localized: "Check Spelling While Typing"),
                        #selector(NSTextView.toggleContinuousSpellChecking(_:))
                    )
                ]),
                self.menu(String(localized: "Substitutions"), [
                    item(String(localized: "Smart Quotes"), #selector(NSTextView.toggleAutomaticQuoteSubstitution(_:))),
                    item(String(localized: "Smart Dashes"), #selector(NSTextView.toggleAutomaticDashSubstitution(_:)))
                ])
            ]
            return menu
        }

        private static func findMenu() -> NSMenuItem {
            let find = #selector(NSResponder.performTextFinderAction(_:))
            return menu(String(localized: "Find"), [
                item(String(localized: "Find…"), find, "f", tag: NSTextFinder.Action.showFindInterface.rawValue),
                item(
                    String(localized: "Find and Replace…"),
                    find,
                    "f",
                    [.command, .option],
                    tag: NSTextFinder.Action.showReplaceInterface.rawValue
                ),
                item(String(localized: "Find Next"), find, "g", tag: NSTextFinder.Action.nextMatch.rawValue),
                item(
                    String(localized: "Find Previous"),
                    find,
                    "g",
                    [.command, .shift],
                    tag: NSTextFinder.Action.previousMatch.rawValue
                ),
                item(
                    String(localized: "Use Selection for Find"),
                    find,
                    "e",
                    tag: NSTextFinder.Action.setSearchString.rawValue
                )
            ])
        }

        /// The format commands with their shortcuts; Heading holds the levels.
        private static func formatMenu() -> NSMenu {
            func format(_ action: FormatAction) -> NSMenuItem {
                let title = switch action {
                case .link: String(localized: "Link…")
                case .checkbox: String(localized: "Toggle Checkbox")
                default: action.title
                }
                var modifiers: NSEvent.ModifierFlags = .command
                if action.shortcut.modifiers.contains(.shift) {
                    modifiers.insert(.shift)
                }
                if action.shortcut.modifiers.contains(.option) {
                    modifiers.insert(.option)
                }
                let format = item(title, #selector(DocumentWindowController.format), action.shortcut.key, modifiers)
                // The tag is the action's index in `FormatAction.allCases`.
                if let index = FormatAction.allCases.firstIndex(of: action) {
                    format.tag = index
                }
                return format
            }
            let menu = NSMenu()
            menu.items = [
                format(.bold),
                format(.italic),
                format(.link),
                format(.code),
                format(.quote),
                format(.checkbox),
                self.menu(String(localized: "Heading"), [.heading1, .heading2, .heading3, .body].map(format)),
                format(.bulletedList)
            ]
            return menu
        }

        private static func viewMenu() -> NSMenu {
            let menu = NSMenu()
            menu.items = [
                item(String(localized: "Show Format Bar"), #selector(DocumentWindowController.toggleFormatBar)),
                item(String(localized: "Show Status Bar"), #selector(DocumentWindowController.toggleStatusBar)),
                .separator(),
                item(ScrollStrings.lock, #selector(DocumentWindowController.toggleLock), "l", [.command, .option]),
                .separator(),
                item(String(localized: "Actual Size"), #selector(DocumentWindowController.actualSize), "0"),
                item(String(localized: "Zoom In"), #selector(DocumentWindowController.zoomIn), "+"),
                item(String(localized: "Zoom Out"), #selector(DocumentWindowController.zoomOut), "-"),
                .separator(),
                item(
                    String(localized: "Enter Full Screen"),
                    #selector(NSWindow.toggleFullScreen(_:)),
                    "f",
                    [.command, .control]
                )
            ]
            return menu
        }

        private static func windowMenu() -> NSMenu {
            let menu = NSMenu()
            menu.items = [
                item(String(localized: "Minimize"), #selector(NSWindow.performMiniaturize(_:)), "m"),
                item(String(localized: "Zoom"), #selector(NSWindow.performZoom(_:))),
                .separator(),
                item(
                    String(localized: "Show Previous Tab"),
                    #selector(NSWindow.selectPreviousTab(_:)),
                    "[",
                    [.command, .shift]
                ),
                item(
                    String(localized: "Show Next Tab"),
                    #selector(NSWindow.selectNextTab(_:)),
                    "]",
                    [.command, .shift]
                ),
                item(String(localized: "Move Tab to New Window"), #selector(NSWindow.moveTabToNewWindow(_:))),
                item(String(localized: "Merge All Windows"), #selector(NSWindow.mergeAllWindows(_:))),
                .separator(),
                item(String(localized: "Bring All to Front"), #selector(NSApplication.arrangeInFront(_:)))
            ]
            // Command-1 to Command-9 select a tab; the items stay hidden.
            for index in 0 ..< 9 {
                let tab = item(
                    "\(index + 1)",
                    #selector(DocumentWindowController.selectTab),
                    "\(index + 1)",
                    tag: index
                )
                tab.isHidden = true
                tab.allowsKeyEquivalentWhenHidden = true
                menu.addItem(tab)
            }
            return menu
        }
    }
#endif
