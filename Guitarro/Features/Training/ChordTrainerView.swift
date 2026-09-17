import DesignSystem
import MusicTheory
import SwiftData
import SwiftUI
import Training

/// Overview of chord changes: what to practise now, what is due, and overall progress.
struct ChordTrainerView: View {
    @Query private var progress: [ChordChangeProgress]
    @AppStorage(SettingsKeys.noteNaming) private var noteNaming: NoteNamingStyle = .defaultForCurrentLocale

    private let curriculum = ChordChangeCurriculum.beginner

    private var states: [ChordPair: SkillState] { progress.skillStates }
    private var recommended: ChordPair? { ChordChangeScheduler.next(from: states, curriculum: curriculum) }
    private var due: [ChordPair] { ChordChangeScheduler.dueChanges(from: states) }

    var body: some View {
        List {
            if let recommended {
                Section("trainer.recommended") {
                    NavigationLink(value: recommended) {
                        RecommendedRow(pair: recommended, state: states[recommended], noteNaming: noteNaming)
                    }
                    .guitarroRow()
                }
            }
            if !due.isEmpty {
                Section("trainer.due") {
                    ForEach(due) { pair in
                        NavigationLink(value: pair) {
                            ChordPairRow(pair: pair, state: states[pair], noteNaming: noteNaming)
                        }
                        .guitarroRow()
                    }
                }
            }
            Section("trainer.all") {
                ForEach(curriculum) { pair in
                    NavigationLink(value: pair) {
                        ChordPairRow(pair: pair, state: states[pair], noteNaming: noteNaming)
                    }
                    .guitarroRow()
                }
            }
        }
        .guitarroScreen()
        .navigationTitle("trainer.title")
    }
}

private struct RecommendedRow: View {
    let pair: ChordPair
    let state: SkillState?
    let noteNaming: NoteNamingStyle

    var body: some View {
        VStack(alignment: .leading, spacing: GuitarroSpacing.small) {
            PairTitle(pair: pair, noteNaming: noteNaming)
                .font(.title2.bold())
            Text("trainer.instructions")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if let state, !state.isNew {
                ProgressSummary(state: state)
            } else {
                Text("trainer.new")
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.guitarroAccent.opacity(0.2)))
            }
        }
        .padding(.vertical, 4)
    }
}

private struct ChordPairRow: View {
    let pair: ChordPair
    let state: SkillState?
    let noteNaming: NoteNamingStyle

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                PairTitle(pair: pair, noteNaming: noteNaming)
                    .font(.headline)
                if let state, !state.isNew {
                    ProgressSummary(state: state)
                } else {
                    Text("trainer.new")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if let state, !state.isNew {
                RatingStars(rating: ChordChangeScheduler.rating(changesPerMinute: state.last))
            }
        }
    }
}

struct PairTitle: View {
    let pair: ChordPair
    let noteNaming: NoteNamingStyle

    var body: some View {
        HStack(spacing: 6) {
            Text(pair.fromVoicing?.chord.symbol(style: noteNaming) ?? pair.from)
            Image(systemName: "arrow.right")
                .foregroundStyle(.secondary)
            Text(pair.toVoicing?.chord.symbol(style: noteNaming) ?? pair.to)
        }
    }
}

private struct ProgressSummary: View {
    let state: SkillState

    var body: some View {
        HStack(spacing: 4) {
            Text("trainer.best \(state.best)")
            Text(verbatim: "·")
            if state.isDue(on: .now) {
                Text("trainer.dueNow")
            } else {
                Text("trainer.dueAt \(state.due, format: .relative(presentation: .named))")
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}

struct RatingStars: View {
    let rating: Int

    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...5, id: \.self) { star in
                Image(systemName: star <= rating ? "star.fill" : "star")
                    .font(.caption)
                    .foregroundStyle(star <= rating ? Color.guitarroAccent : Color.secondary.opacity(0.4))
            }
        }
        .accessibilityLabel(Text(verbatim: "\(rating)/5"))
    }
}
