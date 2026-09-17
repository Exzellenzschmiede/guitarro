import MusicTheory
import SwiftUI

/// Toolbar menu for picking one of the preset tunings.
struct TuningMenu: View {
    @Binding var tuning: Tuning

    var body: some View {
        Menu {
            Picker("tuner.tuning", selection: $tuning) {
                ForEach(Tuning.presets) { preset in
                    Text(Self.nameKey(for: preset)).tag(preset)
                }
            }
        } label: {
            Label(Self.nameKey(for: tuning), systemImage: "guitars")
        }
    }

    /// Builds the key from a plain String; an interpolated literal would become a format key.
    static func nameKey(for tuning: Tuning) -> LocalizedStringKey {
        let key: String = "tuning.\(tuning.id)"
        return LocalizedStringKey(key)
    }
}
