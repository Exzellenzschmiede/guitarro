import DesignSystem
import MusicTheory
import SwiftUI

/// Explains a chord: its tones, their intervals, and why it sounds the way it does.
struct ChordInfoView: View {
    let voicing: ChordVoicing
    let noteNaming: NoteNamingStyle
    let onPlay: () -> Void

    private var chord: Chord { voicing.chord }

    var body: some View {
        VStack(alignment: .leading, spacing: GuitarroSpacing.medium) {
            HStack {
                Text(MusicText.chordTitle(chord, noteNaming: noteNaming))
                    .font(.title2.bold())
                Spacer()
                Button(action: onPlay) {
                    Label("fretboard.play", systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
            }

            HStack(alignment: .top, spacing: GuitarroSpacing.medium) {
                ForEach(Array(chord.intervals.enumerated()), id: \.offset) { _, interval in
                    let pitchClass = PitchClass(semitone: chord.root.rawValue + interval.semitones)
                    VStack(spacing: 6) {
                        Text(pitchClass.name(style: noteNaming))
                            .font(.guitarroDisplay(20))
                            .frame(width: 48, height: 48)
                            .background(Circle().fill(interval == .unison ? Color.guitarroAccent : Color(red: 0.96, green: 0.93, blue: 0.86)))
                            .foregroundStyle(interval == .unison ? Color.white : Color(red: 0.16, green: 0.11, blue: 0.08))
                        Text(MusicText.intervalName(interval))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .frame(width: 72)
                    }
                }
            }

            Text(MusicText.hint(for: chord.quality))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .guitarroCard()
    }
}
