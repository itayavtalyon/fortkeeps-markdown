#if os(iOS)
    import Foundation

    /// The iOS-only strings; check-ios-coverage.py gates them.
    extension ScrollStrings {
        /// Screens §3.20, log 002 › iPhone home screen.
        static var settings: String {
            String(localized: "more.settings", defaultValue: "Settings")
        }

        static var openFiles: String {
            String(localized: "nav.openFiles", defaultValue: "Open Files")
        }

        static var openSection: String {
            String(localized: "home.open", defaultValue: "Open")
        }

        static var browse: String {
            String(localized: "home.browse", defaultValue: "Browse")
        }

        static var homeEmpty: String {
            String(localized: "home.empty", defaultValue: "Files you open will show up here.")
        }

        static func noMatch(_ query: String) -> String {
            String(localized: "home.noMatch", defaultValue: "No files match “\(query)”.")
        }

        static var missingNote: String {
            String(localized: "home.missing", defaultValue: "Can’t find this file. It may have been moved or deleted.")
        }

        static func missingLabel(_ name: String) -> String {
            String(localized: "home.missing.ax", defaultValue: "\(name), can’t find this file")
        }

        static func cannotFind(_ name: String) -> String {
            String(localized: "home.missing.title", defaultValue: "Can’t find “\(name)”")
        }

        static var findFile: String {
            String(localized: "home.missing.find", defaultValue: "Find File…")
        }

        /// The close control of an iPad tab (log 001 › Windows and chrome).
        static func closeTab(_ name: String) -> String {
            String(localized: "tab.close.ax", defaultValue: "Close \(name)")
        }

        static var closeTabCommand: String {
            String(localized: "tab.close", defaultValue: "Close tab")
        }

        static var previousTab: String {
            String(localized: "tab.previous", defaultValue: "Show previous tab")
        }

        static var nextTab: String {
            String(localized: "tab.next", defaultValue: "Show next tab")
        }
    }
#endif
