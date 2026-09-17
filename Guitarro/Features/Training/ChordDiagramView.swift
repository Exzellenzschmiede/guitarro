import DesignSystem
import Fretboard
import MusicTheory
import SwiftUI

/// Compact chord diagram (first four frets) with finger numbers.
struct ChordDiagramView: View {
    let voicing: ChordVoicing
    let noteNaming: NoteNamingStyle
    var isActive = false

    var body: some View {
        VStack(spacing: 6) {
            Text(voicing.chord.symbol(style: noteNaming))
                .font(.title2.bold())
                .foregroundStyle(isActive ? Color.guitarroAccent : Color.primary)
            FretboardView(
                tuning: .standard,
                fretCount: max(4, voicing.highestFret),
                orientation: .vertical,
                markers: markers,
                mutedStrings: voicing.mutedStrings,
                barre: voicing.barre.map { FretboardBarre(fret: $0.fret, fromString: $0.fromString, toString: $0.toString) }
            )
            .frame(width: 150, height: 180)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(isActive ? Color.guitarroAccent.opacity(0.14) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(isActive ? Color.guitarroAccent : Color.clear, lineWidth: 2)
        )
        .animation(.snappy, value: isActive)
    }

    private var markers: [FretboardMarker] {
        voicing.strings.enumerated().compactMap { string, action in
            guard let fret = action.fret else { return nil }
            let position = FretboardPosition(string: string, fret: fret)
            let isRoot = Tuning.standard.pitch(at: position).pitchClass == voicing.chord.root
            let label = action.finger.map { $0 > 0 ? "\($0)" : "0" } ?? "0"
            return FretboardMarker(position: position, label: label, style: isRoot ? .root : .chordTone)
        }
    }
}

#Preview {
    HStack {
        ChordDiagramView(voicing: ChordLibrary.voicing(id: "Am")!, noteNaming: .german, isActive: true)
        ChordDiagramView(voicing: ChordLibrary.voicing(id: "F")!, noteNaming: .german)
    }
    .padding()
}
