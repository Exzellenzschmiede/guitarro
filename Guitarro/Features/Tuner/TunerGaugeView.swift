import DesignSystem
import SwiftUI

/// Semi-circular cents gauge with an animated needle.
struct TunerGaugeView: View {
    var cents: Double?
    var isInTune: Bool

    private static let maxCents = 50.0
    private static let halfSweep = 60.0

    var body: some View {
        GeometryReader { geometry in
            let radius = min(geometry.size.width / 2 - 16, geometry.size.height - 24)
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height - 8)
            ZStack {
                Canvas { context, _ in
                    drawScale(in: &context, center: center, radius: radius)
                }
                NeedleShape(angle: Self.angle(for: cents ?? 0), center: center, length: radius - 22)
                    .stroke(needleColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .animation(.spring(duration: 0.18), value: cents)
                Circle()
                    .fill(needleColor)
                    .frame(width: 14, height: 14)
                    .position(center)
            }
        }
        .accessibilityHidden(true)
    }

    private var needleColor: Color {
        guard cents != nil else { return Color.secondary.opacity(0.4) }
        return isInTune ? .guitarroInTune : .guitarroAccent
    }

    static func angle(for cents: Double) -> Double {
        max(-maxCents, min(maxCents, cents)) / maxCents * halfSweep
    }

    private func drawScale(in context: inout GraphicsContext, center: CGPoint, radius: CGFloat) {
        var track = Path()
        track.addArc(
            center: center,
            radius: radius,
            startAngle: .degrees(-90 - Self.halfSweep),
            endAngle: .degrees(-90 + Self.halfSweep),
            clockwise: false
        )
        context.stroke(track, with: .color(Color.secondary.opacity(0.2)), style: StrokeStyle(lineWidth: 12, lineCap: .round))

        var zone = Path()
        zone.addArc(
            center: center,
            radius: radius,
            startAngle: .degrees(-90 + Self.angle(for: -Self.maxCents / 10)),
            endAngle: .degrees(-90 + Self.angle(for: Self.maxCents / 10)),
            clockwise: false
        )
        context.stroke(zone, with: .color(Color.guitarroInTune.opacity(isInTune ? 1 : 0.45)), style: StrokeStyle(lineWidth: 12))

        for value in stride(from: -Self.maxCents, through: Self.maxCents, by: 10) {
            let angle = Angle.degrees(-90 + Self.angle(for: value)).radians
            let isMajor = value == 0 || abs(value) == Self.maxCents
            let inner = radius - (isMajor ? 32 : 26)
            let outer = radius - 16
            var tick = Path()
            tick.move(to: CGPoint(x: center.x + cos(angle) * inner, y: center.y + sin(angle) * inner))
            tick.addLine(to: CGPoint(x: center.x + cos(angle) * outer, y: center.y + sin(angle) * outer))
            context.stroke(tick, with: .color(Color.secondary.opacity(0.5)), lineWidth: isMajor ? 3 : 1.5)
        }

        let labelRadius = radius - 50
        let flatAngle = Angle.degrees(-90 - Self.halfSweep).radians
        let sharpAngle = Angle.degrees(-90 + Self.halfSweep).radians
        context.draw(
            Text("♭").font(.title2.weight(.semibold)).foregroundStyle(.secondary),
            at: CGPoint(x: center.x + cos(flatAngle) * labelRadius, y: center.y + sin(flatAngle) * labelRadius)
        )
        context.draw(
            Text("♯").font(.title2.weight(.semibold)).foregroundStyle(.secondary),
            at: CGPoint(x: center.x + cos(sharpAngle) * labelRadius, y: center.y + sin(sharpAngle) * labelRadius)
        )
    }
}

private struct NeedleShape: Shape {
    var angle: Double
    let center: CGPoint
    let length: CGFloat

    var animatableData: Double {
        get { angle }
        set { angle = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let radians = Angle.degrees(-90 + angle).radians
        var path = Path()
        path.move(to: center)
        path.addLine(to: CGPoint(x: center.x + cos(radians) * length, y: center.y + sin(radians) * length))
        return path
    }
}

#Preview {
    VStack {
        TunerGaugeView(cents: -18, isInTune: false)
        TunerGaugeView(cents: 2, isInTune: true)
        TunerGaugeView(cents: nil, isInTune: false)
    }
    .padding()
}
