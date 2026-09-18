import Foundation

/// Public pages App Review expects to find from the paywall.
/// `docs/` is served by GitHub Pages; see docs/APPSTORE.md.
enum Legal {
    static let privacyPolicy = URL(string: "https://exzellenzschmiede.github.io/guitarro/privacy.html")!
    static let support = URL(string: "https://exzellenzschmiede.github.io/guitarro/")!
    /// Apple's standard licence agreement, which App Store Connect uses unless a custom EULA is uploaded.
    static let termsOfUse = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
}
