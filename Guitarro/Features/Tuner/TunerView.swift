import AudioEngine
import DesignSystem
import MusicTheory
import SwiftUI
import UIKit

struct TunerView: View {
    @State private var model = TunerModel()
    @AppStorage(SettingsKeys.noteNaming) private var noteNaming: NoteNamingStyle = .defaultForCurrentLocale
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        NavigationStack {
            ZStack {
                tunerContent
                statusOverlay
            }
            .guitarroScreen(glow: model.isInTune ? .mint : .amber)
            .navigationTitle("tuner.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    tuningMenu
                }
            }
        }
        .task(id: scenePhase) {
            if scenePhase == .active {
                await model.start()
            } else {
                model.stop()
            }
        }
        .sensoryFeedback(.success, trigger: model.isInTune) { _, isInTune in isInTune }
    }

    // MARK: Layout

    /// Fills the screen without scrolling where it fits, and scrolls on small phones.
    private var tunerContent: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: GuitarroSpacing.medium) {
                    Picker("tuner.mode", selection: $model.mode) {
                        Text("tuner.mode.auto").tag(TunerMode.auto)
                        Text("tuner.mode.chromatic").tag(TunerMode.chromatic)
                    }
                    .pickerStyle(.segmented)

                    Spacer(minLength: 0)
                    noteDisplay
                    gauge
                    StringPegsView(
                        tuning: model.tuning,
                        activeIndex: model.activeStringIndex,
                        isInTune: model.isInTune,
                        noteNaming: noteNaming
                    )
                    Spacer(minLength: 0)
                    referenceControl
                }
                .padding()
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity, minHeight: proxy.size.height)
            }
        }
    }

    private var isRegularWidth: Bool { horizontalSizeClass == .regular }
    private var noteFontSize: CGFloat { isRegularWidth ? 140 : 96 }
    private var gaugeHeight: CGFloat { isRegularWidth ? 280 : 190 }

    private var noteDisplay: some View {
        VStack(spacing: GuitarroSpacing.small) {
            Group {
                if let pitch = model.displayedPitch {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(pitch.name(style: noteNaming, includeOctave: false))
                            .font(.guitarroDisplay(noteFontSize))
                        Text(verbatim: "\(pitch.octave)")
                            .font(.guitarroDisplay(noteFontSize * 0.36))
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Image(systemName: "waveform")
                        .font(.system(size: 72, weight: .light))
                        .foregroundStyle(.tertiary)
                        .symbolEffect(.variableColor.iterative, isActive: model.status == .listening)
                }
            }
            .frame(height: noteFontSize + 8)
            .foregroundStyle(noteColor)
            .shadow(color: noteColor.opacity(model.reading == nil ? 0 : 0.55), radius: 28)
            .animation(.easeOut(duration: 0.15), value: model.displayedPitch)

            Text(statusText)
                .font(.title3.weight(.semibold))
                .foregroundStyle(noteColor)

            Text(model.reading.map { $0.frequency.formatted(.number.precision(.fractionLength(1))) + " Hz" } ?? " ")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }

    private var gauge: some View {
        VStack(spacing: 4) {
            TunerGaugeView(cents: model.displayedCents, isInTune: model.isInTune)
                .frame(maxWidth: 520)
                .frame(height: gaugeHeight)
            Text(model.displayedCents.map { String(format: "%+.0f ct", $0) } ?? " ")
                .font(.headline.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }

    private var referenceControl: some View {
        HStack {
            Label("tuner.reference", systemImage: "waveform.path")
            Spacer()
            Stepper(value: $model.referenceA4, in: 415...466, step: 1) {
                Text(verbatim: "\(Int(model.referenceA4)) Hz")
                    .monospacedDigit()
            }
            .fixedSize()
        }
        .guitarroCard(cornerRadius: 16)
    }

    private var tuningMenu: some View {
        TuningMenu(tuning: $model.tuning)
    }

    @ViewBuilder
    private var statusOverlay: some View {
        switch model.status {
        case .permissionDenied:
            ContentUnavailableView {
                Label("tuner.permission.title", systemImage: "mic.slash")
            } description: {
                Text("tuner.permission.denied")
            } actions: {
                Button("tuner.permission.openSettings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        openURL(url)
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            .background(.background)
        case .failed(let message):
            ContentUnavailableView {
                Label("tuner.error.title", systemImage: "exclamationmark.triangle")
            } description: {
                Text(message)
            } actions: {
                Button("common.retry") {
                    Task { await model.start() }
                }
                .buttonStyle(.borderedProminent)
            }
            .background(.background)
        case .idle, .listening:
            EmptyView()
        }
    }

    // MARK: Presentation helpers


    private var statusText: LocalizedStringKey {
        guard model.status == .listening else { return " " }
        guard let cents = model.displayedCents else { return "tuner.status.listening" }
        if abs(cents) <= TunerModel.inTuneTolerance { return "tuner.status.inTune" }
        return cents < 0 ? "tuner.status.flat" : "tuner.status.sharp"
    }

    private var noteColor: Color {
        guard let cents = model.displayedCents else { return .secondary }
        if abs(cents) <= TunerModel.inTuneTolerance { return .guitarroInTune }
        return cents < 0 ? .guitarroFlat : .guitarroSharp
    }
}

/// The open strings of the current tuning, highlighting the one being tuned.
struct StringPegsView: View {
    let tuning: Tuning
    let activeIndex: Int?
    let isInTune: Bool
    let noteNaming: NoteNamingStyle

    var body: some View {
        HStack(spacing: 12) {
            ForEach(Array(tuning.strings.enumerated()), id: \.offset) { index, pitch in
                let isActive = index == activeIndex
                VStack(spacing: 4) {
                    Text(pitch.name(style: noteNaming, includeOctave: false))
                        .font(.guitarroDisplay(isActive ? 22 : 19))
                        .frame(width: 48, height: 48)
                        .background(Circle().fill(pegColor(isActive: isActive)))
                        .foregroundStyle(isActive ? Color.white : Color.primary)
                    Text(verbatim: "\(tuning.stringCount - index)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .animation(.snappy, value: isActive)
            }
        }
    }

    private func pegColor(isActive: Bool) -> Color {
        guard isActive else { return Color.secondary.opacity(0.15) }
        return isInTune ? .guitarroInTune : .guitarroAccent
    }
}

#Preview {
    TunerView()
}
