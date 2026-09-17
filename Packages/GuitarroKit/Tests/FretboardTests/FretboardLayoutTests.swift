import CoreGraphics
import Testing
import MusicTheory
@testable import Fretboard

@Suite struct FretboardLayoutTests {
    private let orientations: [FretboardOrientation] = [.horizontal, .vertical]

    @Test func fretsGetNarrowerTowardsTheBody() {
        let layout = FretboardLayout(stringCount: 6, fretCount: 12, orientation: .horizontal, size: CGSize(width: 800, height: 240))
        #expect(layout.fretDistance(0) == 0)
        #expect(abs(layout.fretDistance(12) - layout.neckLength) < 0.001)
        var previousWidth = CGFloat.greatestFiniteMagnitude
        for fret in 1...12 {
            let width = layout.fretDistance(fret) - layout.fretDistance(fret - 1)
            #expect(width < previousWidth)
            previousWidth = width
        }
    }

    @Test func hitTestRoundTrips() {
        for orientation in orientations {
            let size = orientation == .horizontal ? CGSize(width: 800, height: 240) : CGSize(width: 360, height: 480)
            let layout = FretboardLayout(stringCount: 6, fretCount: 12, orientation: orientation, size: size)
            for string in 0..<6 {
                for fret in 0...12 {
                    let position = FretboardPosition(string: string, fret: fret)
                    #expect(layout.position(at: layout.point(for: position)) == position, "\(orientation) \(position)")
                }
            }
        }
    }

    @Test func stringOrderMatchesOrientation() {
        let horizontal = FretboardLayout(stringCount: 6, fretCount: 12, orientation: .horizontal, size: CGSize(width: 800, height: 240))
        // Lowest string at the bottom when horizontal.
        #expect(horizontal.point(for: FretboardPosition(string: 0, fret: 1)).y > horizontal.point(for: FretboardPosition(string: 5, fret: 1)).y)

        let vertical = FretboardLayout(stringCount: 6, fretCount: 12, orientation: .vertical, size: CGSize(width: 360, height: 480))
        // Lowest string on the left when vertical, nut at the top.
        #expect(vertical.point(for: FretboardPosition(string: 0, fret: 1)).x < vertical.point(for: FretboardPosition(string: 5, fret: 1)).x)
        #expect(vertical.point(for: FretboardPosition(string: 0, fret: 1)).y < vertical.point(for: FretboardPosition(string: 0, fret: 5)).y)
    }

    @Test func pointsOutsideTheNeckAreIgnored() {
        let layout = FretboardLayout(stringCount: 6, fretCount: 12, orientation: .horizontal, size: CGSize(width: 800, height: 240))
        #expect(layout.position(at: CGPoint(x: -50, y: 120)) == nil)
        #expect(layout.position(at: CGPoint(x: 400, y: -20)) == nil)
        #expect(layout.position(at: CGPoint(x: 400, y: 260)) == nil)
    }
}
