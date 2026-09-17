import CoreGraphics
import Foundation
import MusicTheory

public enum FretboardOrientation: Sendable, Hashable {
    /// Nut on the left, highest string at the top (as seen by the player looking down).
    case horizontal
    /// Nut at the top, lowest string on the left (like a chord diagram).
    case vertical
}

/// Maps fretboard positions to points in a view and back.
///
/// The layout works in neck coordinates: `along` runs from the nut (0) towards the body,
/// `across` runs from one edge of the neck to the other. `point(along:across:)` maps
/// those to view coordinates depending on the orientation.
public struct FretboardLayout: Sendable, Hashable {
    public let stringCount: Int
    public let fretCount: Int
    public let orientation: FretboardOrientation
    public let size: CGSize

    /// Room before the nut where open-string and muted markers live.
    public let nutOffset: CGFloat
    /// Room after the last fret.
    public let tailPadding: CGFloat
    /// Room outside the outer strings for markers and fret numbers.
    public let sidePadding: CGFloat
    public let markerRadius: CGFloat

    /// Ratio between the widths of neighbouring frets. Real guitars use 0.944; this is
    /// slightly relaxed so high frets stay usable on a phone screen.
    private static let compression = 0.955

    public init(stringCount: Int, fretCount: Int, orientation: FretboardOrientation, size: CGSize) {
        self.stringCount = max(1, stringCount)
        self.fretCount = max(1, fretCount)
        self.orientation = orientation
        self.size = size

        let along = orientation == .horizontal ? size.width : size.height
        let across = orientation == .horizontal ? size.height : size.width
        let labelRoom: CGFloat = 18

        let provisionalSpacing = (across - 2 * (labelRoom + 10)) / CGFloat(max(1, stringCount - 1))
        var radius = min(provisionalSpacing * 0.44, 17)
        let nutOffset = max(20, radius * 2.6)
        let tailPadding = max(6, radius)
        let neckLength = max(1, along - nutOffset - tailPadding)
        let lastFretWidth = neckLength * (Self.fraction(fretCount, of: fretCount) - Self.fraction(fretCount - 1, of: fretCount))
        radius = min(radius, lastFretWidth * 0.42)

        markerRadius = max(6, radius)
        self.nutOffset = nutOffset
        self.tailPadding = tailPadding
        sidePadding = markerRadius + labelRoom
    }

    public var neckLength: CGFloat {
        let along = orientation == .horizontal ? size.width : size.height
        return max(1, along - nutOffset - tailPadding)
    }

    public var neckWidth: CGFloat {
        let across = orientation == .horizontal ? size.height : size.width
        return max(1, across - 2 * sidePadding)
    }

    public var stringSpacing: CGFloat {
        neckWidth / CGFloat(max(1, stringCount - 1))
    }

    private static func fraction(_ fret: Int, of fretCount: Int) -> CGFloat {
        let r = compression
        return CGFloat((1 - pow(r, Double(fret))) / (1 - pow(r, Double(fretCount))))
    }

    /// Distance from the nut to fret wire `fret` (0 = nut) along the neck.
    public func fretDistance(_ fret: Int) -> CGFloat {
        neckLength * Self.fraction(fret, of: fretCount)
    }

    /// Distance across the neck of a string (0 = lowest string).
    public func stringOffset(_ string: Int) -> CGFloat {
        let t = CGFloat(string) / CGFloat(max(1, stringCount - 1))
        return orientation == .horizontal ? neckWidth * (1 - t) : neckWidth * t
    }

    /// Converts neck coordinates to view coordinates.
    public func point(along: CGFloat, across: CGFloat) -> CGPoint {
        switch orientation {
        case .horizontal: CGPoint(x: nutOffset + along, y: sidePadding + across)
        case .vertical: CGPoint(x: sidePadding + across, y: nutOffset + along)
        }
    }

    /// Centre of the space between two fret wires (or the open-string spot before the nut).
    public func alongCentre(ofFret fret: Int) -> CGFloat {
        fret == 0 ? -nutOffset * 0.5 : (fretDistance(fret - 1) + fretDistance(fret)) / 2
    }

    /// Centre point of the marker for a position.
    public func point(for position: FretboardPosition) -> CGPoint {
        point(along: alongCentre(ofFret: position.fret), across: stringOffset(position.string))
    }

    /// The position under a view point, or `nil` when the point is off the neck.
    public func position(at point: CGPoint) -> FretboardPosition? {
        let along = orientation == .horizontal ? point.x - nutOffset : point.y - nutOffset
        let across = orientation == .horizontal ? point.y - sidePadding : point.x - sidePadding

        let t = across / neckWidth
        let stringT = orientation == .horizontal ? 1 - t : t
        let string = Int((stringT * CGFloat(stringCount - 1)).rounded())
        guard string >= 0, string < stringCount else { return nil }
        guard abs(across - stringOffset(string)) <= stringSpacing * 0.6 else { return nil }

        if along < 0 {
            return along >= -nutOffset ? FretboardPosition(string: string, fret: 0) : nil
        }
        guard along <= neckLength else { return nil }
        for fret in 1...fretCount where along <= fretDistance(fret) {
            return FretboardPosition(string: string, fret: fret)
        }
        return FretboardPosition(string: string, fret: fretCount)
    }
}
