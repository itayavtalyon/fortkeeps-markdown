import CoreText
import Foundation
import MarkdownCore
#if os(macOS)
    import AppKit

    typealias PlatformFont = NSFont
    typealias PlatformColor = NSColor
    typealias PlatformImage = NSImage
#else
    import UIKit

    typealias PlatformFont = UIFont
    typealias PlatformColor = UIColor
    typealias PlatformImage = UIImage
#endif

/// The fonts, sizes, and colors of design log 001 › Rendering, Editor,
/// Color, and Accessibility.
@MainActor
struct MarkdownTheme {
    enum Surface {
        case rendered
        case editor
    }

    enum Role {
        case pane, text, text2, text3, accent, pill, line2
    }

    let surface: Surface

    /// Increase Contrast maps `text3` to `text2` and `line2` to `text3`.
    nonisolated static func token(_ role: Role, increaseContrast: Bool) -> ColorToken {
        switch role {
        case .pane: DesignColors.pane
        case .text: DesignColors.text
        case .text2: DesignColors.text2
        case .text3: increaseContrast ? DesignColors.text2 : DesignColors.text3
        case .accent: DesignColors.accent
        case .pill: DesignColors.pill
        case .line2: increaseContrast ? DesignColors.text3 : DesignColors.line2
        }
    }

    /// Registers the shipped Plex files for this process, once.
    private static let fontsRegistered: Bool = {
        let urls = resourceBundle.urls(forResourcesWithExtension: "ttf", subdirectory: "Fonts") ?? []
        CTFontManagerRegisterFontURLs(urls as CFArray, .process, true, nil)
        return true
    }()

    static func plex(_ name: String, size: CGFloat) -> PlatformFont {
        _ = fontsRegistered
        // The fonts ship in the bundle, so a missing name is a packaging bug the font tests catch.
        return PlatformFont(name: name, size: size) ?? .systemFont(ofSize: size)
    }

    // MARK: fonts

    #if os(macOS)
        var bodySize: CGFloat {
            surface == .rendered ? 14.5 : 15
        }

        func bodyFont() -> PlatformFont {
            .systemFont(ofSize: bodySize)
        }

        func strongFont() -> PlatformFont {
            .systemFont(ofSize: bodySize, weight: .semibold)
        }

        func headingFont(level: Int) -> PlatformFont {
            let sizes: [CGFloat] = surface == .rendered ? [20, 15.5] : [22, 16]
            return Self.plex("IBMPlexSans-SemiBold", size: level <= 2 ? sizes[level - 1] : bodySize)
        }

        func codeFont() -> PlatformFont {
            Self.plex("IBMPlexMono-Regular", size: 13)
        }
    #else
        /// Dynamic Type has no cap.
        private static func scaled(_ font: PlatformFont, _ style: UIFont.TextStyle) -> PlatformFont {
            UIFontMetrics(forTextStyle: style).scaledFont(for: font)
        }

        /// The size of a text style at the default content size.
        private static func baseSize(_ style: UIFont.TextStyle) -> CGFloat {
            UIFontDescriptor.preferredFontDescriptor(
                withTextStyle: style,
                compatibleWith: UITraitCollection(preferredContentSizeCategory: .large)
            ).pointSize
        }

        func bodyFont() -> PlatformFont {
            .preferredFont(forTextStyle: .body)
        }

        func strongFont() -> PlatformFont {
            Self.scaled(.systemFont(ofSize: Self.baseSize(.body), weight: .semibold), .body)
        }

        func headingFont(level: Int) -> PlatformFont {
            let style: UIFont.TextStyle = level == 1 ? .title2 : level == 2 ? .title3 : .body
            return Self.scaled(Self.plex("IBMPlexSans-SemiBold", size: Self.baseSize(style)), style)
        }

        func codeFont() -> PlatformFont {
            Self.scaled(Self.plex("IBMPlexMono-Regular", size: Self.baseSize(.callout)), .callout)
        }
    #endif

    static func italic(_ font: PlatformFont) -> PlatformFont {
        #if os(macOS)
            NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask)
        #else
            font.fontDescriptor.withSymbolicTraits(font.fontDescriptor.symbolicTraits.union(.traitItalic))
                .map { UIFont(descriptor: $0, size: 0) } ?? font
        #endif
    }

    // MARK: colors

    nonisolated static func color(_ role: Role) -> PlatformColor {
        #if os(macOS)
            NSColor(name: nil) { appearance in
                let match = appearance.bestMatch(from: [
                    .aqua, .darkAqua, .accessibilityHighContrastAqua, .accessibilityHighContrastDarkAqua
                ])
                let highContrast = match == .accessibilityHighContrastAqua || match ==
                    .accessibilityHighContrastDarkAqua
                let dark = match == .darkAqua || match == .accessibilityHighContrastDarkAqua
                let token = Self.token(role, increaseContrast: highContrast)
                return platformColor(dark ? token.dark : token.light)
            }
        #else
            UIColor { traits in
                let token = Self.token(role, increaseContrast: traits.accessibilityContrast == .high)
                return platformColor(traits.userInterfaceStyle == .dark ? token.dark : token.light)
            }
        #endif
    }

    nonisolated static func platformColor(_ color: SRGBColor) -> PlatformColor {
        PlatformColor(
            red: CGFloat(color.red) / 255,
            green: CGFloat(color.green) / 255,
            blue: CGFloat(color.blue) / 255,
            alpha: color.alpha
        )
    }

    /// Body text has a line height of 1.6.
    func paragraphStyle(direction: TextDirection = .auto, indent: CGFloat = 0) -> NSMutableParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.lineHeightMultiple = 1.6
        style.baseWritingDirection = switch direction {
        case .rtl: .rightToLeft
        case .ltr: .leftToRight
        case .auto: .natural
        }
        style.alignment = .natural
        style.firstLineHeadIndent = indent
        style.headIndent = indent
        return style
    }
}
