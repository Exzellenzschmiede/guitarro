import DesignSystem
import MusicTheory
import SwiftUI

/// A marker drawn on a fretboard position.
public struct FretboardMarker: Hashable, Sendable, Identifiable {
    public enum Style: Sendable, Hashable {
        /// The chord's root: strong accent colour.
        case root
        /// Another chord tone.
        case chordTone
        /// A tone the user tapped or selected.
        case tone
        /// A note currently being heard through the microphone.
        case live
        /// Background note label, barely visible.
        case faint
    }

    public var position: FretboardPosition
    public var label: String
    public var style: Style

    public var id: FretboardPosition { position }

    public init(position: FretboardPosition, label: String, style: Style) {
        self.position = position
        self.label = label
        self.style = style
    }
}

public struct FretboardBarre: Hashable, Sendable {
    public var fret: Int
    public var fromString: Int
    public var toString: Int

    public init(fret: Int, fromString: Int, toString: Int) {
        self.fret = fret
        self.fromString = fromString
        self.toString = toString
    }
}

/// An interactive guitar fretboard.
public struct FretboardView: View {
    public var tuning: Tuning
    public var fretCount: Int
    public var orientation: FretboardOrientation
    public var isMirrored: Bool
    public var markers: [FretboardMarker]
    public var mutedStrings: Set<Int>
    public var barre: FretboardBarre?
    public var onTap: ((FretboardPosition) -> Void)?

    public init(
        tuning: Tuning,
        fretCount: Int = 12,
        orientation: FretboardOrientation,
        isMirrored: Bool = false,
        markers: [FretboardMarker] = [],
        mutedStrings: Set<Int> = [],
        barre: FretboardBarre? = nil,
        onTap: ((FretboardPosition) -> Void)? = nil
    ) {
        self.tuning = tuning
        self.fretCount = fretCount
        self.orientation = orientation
        self.isMirrored = isMirrored
        self.markers = markers
        self.mutedStrings = mutedStrings
        self.barre = barre
        self.onTap = onTap
    }

    public var body: some View {
        GeometryReader { geometry in
            let layout = FretboardLayout(
                stringCount: tuning.stringCount,
                fretCount: fretCount,
                orientation: orientation,
                isMirrored: isMirrored,
                size: geometry.size
            )
            ZStack(alignment: .topLeading) {
                Canvas { context, _ in
                    FretboardPainter(layout: layout, mutedStrings: mutedStrings, barre: barre)
                        .draw(in: &context)
                }
                ForEach(markers) { marker in
                    FretboardMarkerView(marker: marker, radius: layout.markerRadius)
                        .position(layout.point(for: marker.position))
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { location in
                if let position = layout.position(at: location) {
                    onTap?(position)
                }
            }
            .animation(.snappy(duration: 0.25), value: markers)
        }
    }
}

// MARK: - Painting

struct FretboardPainter {
    let layout: FretboardLayout
    let mutedStrings: Set<Int>
    let barre: FretboardBarre?

    private static let inlayFrets: Set<Int> = [3, 5, 7, 9, 15, 17, 19, 21]
    private static let doubleInlayFrets: Set<Int> = [12, 24]

    private let woodDark = Color(red: 0.24, green: 0.16, blue: 0.12)
    private let woodLight = Color(red: 0.36, green: 0.24, blue: 0.17)
    private let fretColor = Color(white: 0.78)
    private let nutColor = Color(red: 0.95, green: 0.91, blue: 0.82)
    private let inlayColor = Color(red: 0.95, green: 0.91, blue: 0.82).opacity(0.32)
    private let woundString = Color(red: 0.86, green: 0.72, blue: 0.46)
    private let plainString = Color(white: 0.88)

    func draw(in context: inout GraphicsContext) {
        let l = layout
        // Keep the neck edge inside the side padding so fret numbers stay visible.
        let margin = min(l.stringSpacing * 0.5, l.sidePadding * 0.55)

        // Neck, including the headstock area before the nut where open-string markers sit.
        let neck = rect(alongFrom: -l.nutOffset, alongTo: l.neckLength + l.tailPadding * 0.6, acrossFrom: -margin, acrossTo: l.neckWidth + margin)
        context.fill(
            Path(roundedRect: neck, cornerRadius: 6),
            with: .linearGradient(
                Gradient(colors: [woodLight, woodDark]),
                startPoint: neck.origin,
                endPoint: CGPoint(x: neck.maxX, y: neck.maxY)
            )
        )
        let headstock = rect(alongFrom: -l.nutOffset, alongTo: 0, acrossFrom: -margin, acrossTo: l.neckWidth + margin)
        context.fill(Path(headstock), with: .color(Color.black.opacity(0.28)))

        // Inlays
        let inlayRadius = l.stringSpacing * 0.2
        for fret in 1...l.fretCount {
            let along = l.alongCentre(ofFret: fret)
            if Self.inlayFrets.contains(fret) {
                dot(at: l.point(along: along, across: l.neckWidth / 2), radius: inlayRadius, in: &context)
            } else if Self.doubleInlayFrets.contains(fret) {
                dot(at: l.point(along: along, across: l.neckWidth * 0.25), radius: inlayRadius, in: &context)
                dot(at: l.point(along: along, across: l.neckWidth * 0.75), radius: inlayRadius, in: &context)
            }
        }

        // Fret wires
        for fret in 1...l.fretCount {
            let path = line(along: l.fretDistance(fret), acrossFrom: -margin, acrossTo: l.neckWidth + margin)
            context.stroke(path, with: .color(fretColor), lineWidth: 2.5)
        }

        // Nut
        context.stroke(line(along: 0, acrossFrom: -margin, acrossTo: l.neckWidth + margin), with: .color(nutColor), lineWidth: 7)

        // Strings
        for string in 0..<l.stringCount {
            let t = CGFloat(string) / CGFloat(max(1, l.stringCount - 1))
            let thickness = 3.4 - 2.3 * t
            let wound = string < l.stringCount / 2
            let path = line(across: l.stringOffset(string), alongFrom: -l.nutOffset * 0.15, alongTo: l.neckLength + l.tailPadding * 0.6)
            context.stroke(path, with: .color(wound ? woundString : plainString), lineWidth: thickness)
        }

        // Barre
        if let barre {
            let from = l.point(for: FretboardPosition(string: barre.fromString, fret: barre.fret))
            let to = l.point(for: FretboardPosition(string: barre.toString, fret: barre.fret))
            var path = Path()
            path.move(to: from)
            path.addLine(to: to)
            context.stroke(path, with: .color(Color.guitarroAccent.opacity(0.85)), style: StrokeStyle(lineWidth: l.markerRadius * 1.7, lineCap: .round))
        }

        // Muted strings
        for string in mutedStrings {
            let point = l.point(for: FretboardPosition(string: string, fret: 0))
            context.draw(
                Text("×").font(.system(size: l.markerRadius * 1.8, weight: .semibold, design: .rounded)).foregroundStyle(.secondary),
                at: point
            )
        }

        // Fret numbers
        for fret in [3, 5, 7, 9, 12, 15, 17, 19, 21] where fret <= l.fretCount {
            let across = l.orientation == .horizontal ? l.neckWidth + margin + 9 : -margin - 9
            let point = l.point(along: l.alongCentre(ofFret: fret), across: across)
            context.draw(
                Text(verbatim: "\(fret)").font(.system(size: 11, weight: .medium, design: .rounded)).foregroundStyle(.secondary),
                at: point
            )
        }
    }

    private func dot(at point: CGPoint, radius: CGFloat, in context: inout GraphicsContext) {
        let rect = CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)
        context.fill(Path(ellipseIn: rect), with: .color(inlayColor))
    }

    private func line(along: CGFloat, acrossFrom: CGFloat, acrossTo: CGFloat) -> Path {
        var path = Path()
        path.move(to: layout.point(along: along, across: acrossFrom))
        path.addLine(to: layout.point(along: along, across: acrossTo))
        return path
    }

    private func line(across: CGFloat, alongFrom: CGFloat, alongTo: CGFloat) -> Path {
        var path = Path()
        path.move(to: layout.point(along: alongFrom, across: across))
        path.addLine(to: layout.point(along: alongTo, across: across))
        return path
    }

    private func rect(alongFrom: CGFloat, alongTo: CGFloat, acrossFrom: CGFloat, acrossTo: CGFloat) -> CGRect {
        let a = layout.point(along: alongFrom, across: acrossFrom)
        let b = layout.point(along: alongTo, across: acrossTo)
        return CGRect(x: min(a.x, b.x), y: min(a.y, b.y), width: abs(a.x - b.x), height: abs(a.y - b.y))
    }
}

// MARK: - Marker

struct FretboardMarkerView: View {
    let marker: FretboardMarker
    let radius: CGFloat

    @State private var pulse = false

    var body: some View {
        ZStack {
            if marker.style == .live {
                Circle()
                    .stroke(Color.guitarroInTune, lineWidth: 2)
                    .scaleEffect(pulse ? 1.9 : 1)
                    .opacity(pulse ? 0 : 0.9)
                    .onAppear {
                        withAnimation(.easeOut(duration: 0.9).repeatForever(autoreverses: false)) {
                            pulse = true
                        }
                    }
            }
            Circle()
                .fill(fill)
                .overlay(Circle().strokeBorder(Color.black.opacity(marker.style == .faint ? 0 : 0.18), lineWidth: 1))
            Text(marker.label)
                .font(.system(size: radius * 1.05, weight: .bold, design: .rounded))
                .foregroundStyle(textColor)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .padding(2)
        }
        .frame(width: radius * 2, height: radius * 2)
        .transition(.scale.combined(with: .opacity))
        .accessibilityLabel(Text(marker.label))
    }

    private var fill: Color {
        switch marker.style {
        case .root: .guitarroAccent
        case .chordTone: Color(red: 0.96, green: 0.93, blue: 0.86)
        case .tone: Color.white.opacity(0.92)
        case .live: .guitarroInTune
        case .faint: Color.white.opacity(0.17)
        }
    }

    private var textColor: Color {
        switch marker.style {
        case .root, .live: .white
        case .chordTone, .tone: Color(red: 0.16, green: 0.11, blue: 0.08)
        case .faint: Color.white.opacity(0.85)
        }
    }
}

#Preview("Horizontal") {
    FretboardView(
        tuning: .standard,
        fretCount: 15,
        orientation: .horizontal,
        markers: [
            FretboardMarker(position: FretboardPosition(string: 0, fret: 0), label: "E", style: .root),
            FretboardMarker(position: FretboardPosition(string: 1, fret: 2), label: "B", style: .chordTone),
            FretboardMarker(position: FretboardPosition(string: 2, fret: 2), label: "E", style: .root),
            FretboardMarker(position: FretboardPosition(string: 3, fret: 1), label: "G♯", style: .chordTone),
            FretboardMarker(position: FretboardPosition(string: 4, fret: 0), label: "B", style: .chordTone),
            FretboardMarker(position: FretboardPosition(string: 5, fret: 0), label: "E", style: .root),
            FretboardMarker(position: FretboardPosition(string: 3, fret: 9), label: "E", style: .live),
        ]
    )
    .frame(height: 260)
    .padding()
}

#Preview("Vertical") {
    FretboardView(
        tuning: .standard,
        orientation: .vertical,
        markers: [
            FretboardMarker(position: FretboardPosition(string: 0, fret: 1), label: "1", style: .root),
            FretboardMarker(position: FretboardPosition(string: 1, fret: 3), label: "3", style: .chordTone),
            FretboardMarker(position: FretboardPosition(string: 2, fret: 3), label: "4", style: .root),
            FretboardMarker(position: FretboardPosition(string: 3, fret: 2), label: "2", style: .chordTone),
            FretboardMarker(position: FretboardPosition(string: 4, fret: 1), label: "1", style: .chordTone),
            FretboardMarker(position: FretboardPosition(string: 5, fret: 1), label: "1", style: .root),
        ],
        barre: FretboardBarre(fret: 1, fromString: 0, toString: 5)
    )
    .frame(width: 360, height: 480)
    .padding()
}
