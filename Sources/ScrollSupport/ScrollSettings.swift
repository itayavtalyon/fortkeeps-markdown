import CoreGraphics
import Foundation

/// Settings (screens §3.17; log 004 Round 6), kept in the user defaults for all windows.
struct ScrollSettings {
    enum LineWidth: String, CaseIterable {
        case narrow
        case medium
        case wide

        var points: CGFloat {
            switch self {
            case .narrow: 560
            case .medium: 680
            case .wide: 840
            }
        }

        var title: String {
            switch self {
            case .narrow: ScrollStrings.narrow
            case .medium: ScrollStrings.medium
            case .wide: ScrollStrings.wide
            }
        }
    }

    static let lineWidthKey = "LineWidth"
    static let showsWordCountKey = "ShowsWordCount"
    static let showsSidebarKey = "ShowsSidebar"

    let defaults: UserDefaults

    var lineWidth: LineWidth {
        get { defaults.string(forKey: Self.lineWidthKey).flatMap(LineWidth.init) ?? .medium }
        nonmutating set { defaults.set(newValue.rawValue, forKey: Self.lineWidthKey) }
    }

    /// The Mac status bar's word count.
    var showsWordCount: Bool {
        get { defaults.object(forKey: Self.showsWordCountKey) as? Bool ?? true }
        nonmutating set { defaults.set(newValue, forKey: Self.showsWordCountKey) }
    }

    /// The Mac sidebar of a new window follows the last choice.
    var showsSidebar: Bool {
        get { defaults.bool(forKey: Self.showsSidebarKey) }
        nonmutating set { defaults.set(newValue, forKey: Self.showsSidebarKey) }
    }
}
