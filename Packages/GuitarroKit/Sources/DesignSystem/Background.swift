import SwiftUI

/// The app-wide stage: dark ink gradient, a warm glow and faint string lines.
public struct GuitarroBackground: View {
    public var glow: GuitarroPalette

    public init(glow: GuitarroPalette = .amber) {
        self.glow = glow
    }

    public var body: some View {
        ZStack {
            LinearGradient(colors: [.guitarroInkLight, .guitarroInk], startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [glow.glow.opacity(0.28), .clear], center: UnitPoint(x: 0.85, y: 0.05), startRadius: 0, endRadius: 460)
            RadialGradient(colors: [Color.guitarroFlat.opacity(0.10), .clear], center: UnitPoint(x: 0.1, y: 0.95), startRadius: 0, endRadius: 420)
            StringsPattern()
                .stroke(Color.white.opacity(0.04), lineWidth: 1)
        }
        .ignoresSafeArea()
    }
}

/// Six gently diverging diagonal lines, like strings seen from above.
struct StringsPattern: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        for index in 0..<6 {
            let t = CGFloat(index) / 5
            let startX = rect.width * (0.55 + 0.5 * t)
            let endX = rect.width * (-0.1 + 0.6 * t)
            path.move(to: CGPoint(x: startX, y: rect.minY))
            path.addLine(to: CGPoint(x: endX, y: rect.maxY))
        }
        return path
    }
}

public extension View {
    /// Applies the stage background and hides system list/form backgrounds.
    func guitarroScreen(glow: GuitarroPalette = .amber) -> some View {
        frame(maxWidth: .infinity, maxHeight: .infinity)
            .scrollContentBackground(.hidden)
            .background(GuitarroBackground(glow: glow))
    }
}
