import SwiftUI

/// Filled amber capsule with glow and press feedback.
public struct GuitarroPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    public var palette: GuitarroPalette

    public init(palette: GuitarroPalette = .amber) {
        self.palette = palette
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.guitarroHeadline)
            .foregroundStyle(Color.guitarroInk)
            .padding(.vertical, 14)
            .padding(.horizontal, 22)
            .frame(maxWidth: .infinity)
            .background(Capsule().fill(palette.gradient))
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.3), lineWidth: 1))
            .shadow(color: palette.glow.opacity(configuration.isPressed ? 0.2 : 0.5), radius: 16, y: 8)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(isEnabled ? 1 : 0.45)
            .animation(.snappy(duration: 0.2), value: configuration.isPressed)
    }
}

/// Glass capsule for secondary actions.
public struct GuitarroSecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.guitarroHeadline)
            .foregroundStyle(Color.guitarroCream)
            .padding(.vertical, 12)
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity)
            .background(Capsule().fill(Color.white.opacity(configuration.isPressed ? 0.14 : 0.08)))
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.18), lineWidth: 1))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(isEnabled ? 1 : 0.45)
            .animation(.snappy(duration: 0.2), value: configuration.isPressed)
    }
}

public extension ButtonStyle where Self == GuitarroPrimaryButtonStyle {
    static var guitarroPrimary: GuitarroPrimaryButtonStyle { GuitarroPrimaryButtonStyle() }
    static func guitarroPrimary(_ palette: GuitarroPalette) -> GuitarroPrimaryButtonStyle { GuitarroPrimaryButtonStyle(palette: palette) }
}

public extension ButtonStyle where Self == GuitarroSecondaryButtonStyle {
    static var guitarroSecondary: GuitarroSecondaryButtonStyle { GuitarroSecondaryButtonStyle() }
}

/// Symbol on a glowing gradient disc.
public struct GuitarroIconBadge: View {
    let systemName: String
    var size: CGFloat
    var palette: GuitarroPalette

    public init(_ systemName: String, size: CGFloat = 48, palette: GuitarroPalette = .amber) {
        self.systemName = systemName
        self.size = size
        self.palette = palette
    }

    public var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(Circle().fill(palette.gradient))
            .overlay(Circle().strokeBorder(Color.white.opacity(0.3), lineWidth: 1))
            .shadow(color: palette.glow.opacity(0.5), radius: size * 0.22, y: size * 0.1)
    }
}

/// Small rounded pill for statuses and tags.
public struct GuitarroPill: View {
    let text: LocalizedStringKey
    var tint: Color

    public init(_ text: LocalizedStringKey, tint: Color = .guitarroAccent) {
        self.text = text
        self.tint = tint
    }

    public var body: some View {
        Text(text)
            .font(.caption.bold())
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(Capsule().fill(tint.opacity(0.18)))
            .overlay(Capsule().strokeBorder(tint.opacity(0.35), lineWidth: 1))
            .foregroundStyle(tint)
    }
}
