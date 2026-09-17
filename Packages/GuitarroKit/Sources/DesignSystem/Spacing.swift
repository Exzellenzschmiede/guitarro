import SwiftUI

public enum GuitarroSpacing {
    public static let small: CGFloat = 8
    public static let medium: CGFloat = 16
    public static let large: CGFloat = 24
    public static let extraLarge: CGFloat = 32
}

public extension View {
    /// Glass card: translucent fill, hairline gradient border, soft shadow.
    func guitarroCard(cornerRadius: CGFloat = 22) -> some View {
        padding(GuitarroSpacing.medium)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.white.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(colors: [Color.white.opacity(0.16), Color.white.opacity(0.03)], startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: 1
                    )
            )
            .shadow(color: Color.black.opacity(0.35), radius: 18, y: 10)
    }

    /// Hero card: full gradient with a coloured glow.
    func guitarroHeroCard(palette: GuitarroPalette = .amber, cornerRadius: CGFloat = 28) -> some View {
        padding(GuitarroSpacing.large)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(palette.gradient)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.28), lineWidth: 1)
            )
            .shadow(color: palette.glow.opacity(0.45), radius: 28, y: 14)
    }

    /// Row background for Lists and Forms on the stage background.
    func guitarroRow() -> some View {
        listRowBackground(Color.white.opacity(0.06))
    }
}
