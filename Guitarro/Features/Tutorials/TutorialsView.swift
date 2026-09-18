import DesignSystem
import SwiftUI
import Tutorials

/// Progress is a comma-separated list of completed tutorial ids.
enum TutorialProgress {
    static let key = "tutorials.completed"

    static func completed(from raw: String) -> Set<String> {
        Set(raw.split(separator: ",").map(String.init))
    }

    static func raw(from set: Set<String>) -> String {
        set.sorted().joined(separator: ",")
    }
}

struct TutorialsView: View {
    @AppStorage(TutorialProgress.key) private var completedRaw = ""

    private var completed: Set<String> { TutorialProgress.completed(from: completedRaw) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: GuitarroSpacing.large) {
                intro
                ForEach(TutorialLibrary.categories, id: \.self) { category in
                    let tutorials = TutorialLibrary.tutorials(in: category)
                    if !tutorials.isEmpty {
                        VStack(alignment: .leading, spacing: GuitarroSpacing.small) {
                            Text(LocalizedStringKey(category))
                                .font(.guitarroTitle)
                            ForEach(tutorials) { tutorial in
                                NavigationLink(value: tutorial) {
                                    TutorialRow(tutorial: tutorial, isCompleted: completed.contains(tutorial.id))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .padding()
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
        .guitarroScreen(glow: .gold)
        .navigationTitle("tutorials.title")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: GuitarroSpacing.small) {
            HStack(spacing: GuitarroSpacing.medium) {
                GuitarroIconBadge("play.rectangle.on.rectangle", size: 44, palette: .gold)
                VStack(alignment: .leading, spacing: 2) {
                    Text("tutorials.intro.title").font(.guitarroHeadline)
                    Text("tutorials.progress \(completed.count) \(TutorialLibrary.all.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Text("tutorials.intro.body")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .guitarroCard()
    }
}

struct TutorialRow: View {
    let tutorial: Tutorial
    let isCompleted: Bool

    var body: some View {
        HStack(spacing: GuitarroSpacing.medium) {
            GuitarroIconBadge(tutorial.symbol, size: 44, palette: GuitarroPaletteName.palette(for: tutorial.theme))
            VStack(alignment: .leading, spacing: 4) {
                Text(LocalizedStringKey(tutorial.titleKey))
                    .font(.guitarroHeadline)
                    .foregroundStyle(Color.guitarroCream)
                Text(LocalizedStringKey(tutorial.summaryKey))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 8) {
                    Label("tutorials.minutes \(tutorial.minutes)", systemImage: "clock")
                    if tutorial.check != nil {
                        Label("tutorials.hasCheck", systemImage: "mic")
                    }
                }
                .font(.caption2)
                .foregroundStyle(.tertiary)
            }
            Spacer(minLength: 0)
            Image(systemName: isCompleted ? "checkmark.circle.fill" : "chevron.right")
                .foregroundStyle(isCompleted ? Color.guitarroInTune : Color.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .guitarroCard()
    }
}
