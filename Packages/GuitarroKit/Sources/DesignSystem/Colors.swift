import SwiftUI

public extension Color {
    /// Warm amber brand accent.
    static let guitarroAccent = Color(red: 0.98, green: 0.62, blue: 0.20)
    static let guitarroAmberLight = Color(red: 1.0, green: 0.78, blue: 0.38)
    static let guitarroAmberDeep = Color(red: 0.93, green: 0.40, blue: 0.11)
    static let guitarroInTune = Color(red: 0.24, green: 0.86, blue: 0.59)
    static let guitarroFlat = Color(red: 0.44, green: 0.66, blue: 1.0)
    static let guitarroSharp = Color(red: 1.0, green: 0.45, blue: 0.40)

    /// Stage-dark backgrounds.
    static let guitarroInk = Color(red: 0.05, green: 0.045, blue: 0.075)
    static let guitarroInkLight = Color(red: 0.11, green: 0.095, blue: 0.15)
    static let guitarroCream = Color(red: 0.97, green: 0.95, blue: 0.91)
    static let guitarroMuted = Color(red: 0.68, green: 0.65, blue: 0.63)
}

public extension ShapeStyle where Self == LinearGradient {
    /// Amber gradient used for primary actions, heroes and icon badges.
    static var guitarroAccentGradient: LinearGradient {
        LinearGradient(colors: [.guitarroAmberLight, .guitarroAmberDeep], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

/// Colour pairs for themed icon badges and story chapters.
public struct GuitarroPalette: Sendable, Hashable {
    public let colors: [Color]

    public init(_ colors: [Color]) {
        self.colors = colors
    }

    public static let amber = GuitarroPalette([.guitarroAmberLight, .guitarroAmberDeep])
    public static let mint = GuitarroPalette([Color(red: 0.45, green: 0.95, blue: 0.75), Color(red: 0.10, green: 0.62, blue: 0.45)])
    public static let sky = GuitarroPalette([Color(red: 0.55, green: 0.78, blue: 1.0), Color(red: 0.20, green: 0.40, blue: 0.90)])
    public static let violet = GuitarroPalette([Color(red: 0.75, green: 0.55, blue: 1.0), Color(red: 0.40, green: 0.20, blue: 0.80)])
    public static let rose = GuitarroPalette([Color(red: 1.0, green: 0.55, blue: 0.65), Color(red: 0.80, green: 0.15, blue: 0.40)])
    public static let gold = GuitarroPalette([Color(red: 1.0, green: 0.90, blue: 0.55), Color(red: 0.85, green: 0.60, blue: 0.10)])
    public static let ocean = GuitarroPalette([Color(red: 0.30, green: 0.75, blue: 0.85), Color(red: 0.05, green: 0.30, blue: 0.55)])

    public var gradient: LinearGradient {
        LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    public var glow: Color { colors.last ?? .guitarroAccent }
}
