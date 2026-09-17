import SwiftUI

public extension Font {
    /// Large rounded display type used for note names and headline numbers.
    static func guitarroDisplay(_ size: CGFloat) -> Font {
        .system(size: size, weight: .bold, design: .rounded)
    }

    static let guitarroTitle = Font.system(.title, design: .rounded).weight(.bold)
    static let guitarroLargeTitle = Font.system(.largeTitle, design: .rounded).weight(.heavy)
    static let guitarroHeadline = Font.system(.headline, design: .rounded)
}

/// Section heading with an optional trailing action.
public struct GuitarroSectionTitle: View {
    let title: LocalizedStringKey

    public init(_ title: LocalizedStringKey) {
        self.title = title
    }

    public var body: some View {
        Text(title)
            .font(.guitarroTitle)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
