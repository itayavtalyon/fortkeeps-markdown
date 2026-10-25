import Foundation
@testable import MarkdownCore
import Testing

/// Reads the expected values from the Color table of the design log, so the
/// constants cannot drift from Design without this test going red.
struct DesignColorsTests {
    static let tokens: [(String, ColorToken)] = [
        ("pane", DesignColors.pane),
        ("text", DesignColors.text),
        ("text2", DesignColors.text2),
        ("text3", DesignColors.text3),
        ("accent", DesignColors.accent),
        ("pill", DesignColors.pill),
        ("line2", DesignColors.line2)
    ]

    @Test
    func `every Design table token has a DesignColors constant`() throws {
        let designNames = try DesignColorTable.load().keys.sorted()

        #expect(designNames == Self.tokens.map(\.0).sorted())
    }

    @Test(arguments: tokens)
    func `each DesignColors token equals its Design dark and light values`(name: String, token: ColorToken) throws {
        let design = try #require(try DesignColorTable.load()[name], "no Design row for \(name)")

        #expect(design == token, "\(name)")
    }
}

struct DesignColorTableTests {
    @Test
    func `parse reads a hex cell and an rgba cell`() throws {
        let log = """
        ## Design

        ### Color

        | `pill` | `rgba(255,255,255,.05)` | `#F4F1EB` |

        ### Fonts
        | `late` | `#000000` | `#000000` |
        """

        let rows = try DesignColorTable.parse(log)

        #expect(rows == ["pill": ColorToken(
            dark: SRGBColor(red: 255, green: 255, blue: 255, alpha: 0.05),
            light: SRGBColor(red: 0xF4, green: 0xF1, blue: 0xEB)
        )])
    }

    @Test(arguments: ["#F4F1E", "#GGGGGG", "rgba(255,255,.05)", "rgba(1,2,3,0.5,9)", "rgba(256,0,0,1)", "red"])
    func `parse rejects a malformed color cell`(cell: String) {
        #expect(throws: DesignColorTable.ParseError.self) {
            try DesignColorTable.parse("\n### Color\n| `pill` | `\(cell)` | `#000000` |\n")
        }
    }

    @Test
    func `parse rejects a log with no Color section`() {
        #expect(throws: DesignColorTable.ParseError.self) {
            try DesignColorTable.parse("### Fonts\n| `pill` | `#000000` | `#000000` |\n")
        }
    }
}
