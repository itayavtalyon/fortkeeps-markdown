/// An sRGB color with 8-bit channels and an alpha in 0...1.
public struct SRGBColor: Equatable, Sendable {
    public let red: UInt8
    public let green: UInt8
    public let blue: UInt8
    public let alpha: Double

    public init(red: UInt8, green: UInt8, blue: UInt8, alpha: Double = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }
}

/// One color role with its dark and light appearance values.
public struct ColorToken: Equatable, Sendable {
    public let dark: SRGBColor
    public let light: SRGBColor
}

/// The color tokens of design log 001 › Color.
public enum DesignColors {
    public static let pane = ColorToken(
        dark: SRGBColor(red: 0x16, green: 0x1E, blue: 0x28),
        light: SRGBColor(red: 0xFF, green: 0xFF, blue: 0xFF)
    )
    public static let text = ColorToken(
        dark: SRGBColor(red: 0xED, green: 0xEF, blue: 0xF2),
        light: SRGBColor(red: 0x1C, green: 0x24, blue: 0x30)
    )
    public static let text2 = ColorToken(
        dark: SRGBColor(red: 0xB9, green: 0xC2, blue: 0xCC),
        light: SRGBColor(red: 0x3E, green: 0x47, blue: 0x53)
    )
    public static let text3 = ColorToken(
        dark: SRGBColor(red: 0x97, green: 0xA1, blue: 0xAD),
        light: SRGBColor(red: 0x5C, green: 0x65, blue: 0x70)
    )
    public static let accent = ColorToken(
        dark: SRGBColor(red: 0x93, green: 0xB9, blue: 0xE6),
        light: SRGBColor(red: 0x1B, green: 0x3A, blue: 0x5F)
    )
    public static let pill = ColorToken(
        dark: SRGBColor(red: 255, green: 255, blue: 255, alpha: 0.05),
        light: SRGBColor(red: 0xF4, green: 0xF1, blue: 0xEB)
    )
    public static let line2 = ColorToken(
        dark: SRGBColor(red: 255, green: 255, blue: 255, alpha: 0.12),
        light: SRGBColor(red: 0xDA, green: 0xD3, blue: 0xC7)
    )
}
