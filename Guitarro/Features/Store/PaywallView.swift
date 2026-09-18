import DesignSystem
import StoreKit
import SwiftUI

struct PaywallView: View {
    @Environment(StoreManager.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var selected: StoreManager.ProductID = .yearly

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: GuitarroSpacing.large) {
                    header
                    features
                    offers
                    purchaseButton
                    footer
                }
                .padding()
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            .guitarroScreen(glow: .gold)
            .navigationTitle("pro.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.close") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
        .task { await store.load() }
        .onChange(of: store.hasPro) { _, hasPro in
            if hasPro { dismiss() }
        }
    }

    private var header: some View {
        VStack(spacing: GuitarroSpacing.small) {
            GuitarroIconBadge("crown.fill", size: 80, palette: .gold)
            Text("pro.headline")
                .font(.guitarroLargeTitle)
                .multilineTextAlignment(.center)
            Text("pro.subheadline")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top)
    }

    private var features: some View {
        VStack(alignment: .leading, spacing: GuitarroSpacing.small) {
            ProFeature(symbol: "book.pages", text: "pro.feature.story")
            ProFeature(symbol: "music.note.list", text: "pro.feature.songs")
            ProFeature(symbol: "music.mic", text: "pro.feature.ownSongs")
            ProFeature(symbol: "camera.viewfinder", text: "pro.feature.camera")
            ProFeature(symbol: "sparkles", text: "pro.feature.ai")
            ProFeature(symbol: "arrow.down.circle", text: "pro.feature.updates")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .guitarroCard()
    }

    @ViewBuilder
    private var offers: some View {
        if store.products.isEmpty {
            VStack(spacing: GuitarroSpacing.small) {
                if store.isLoading {
                    ProgressView()
                } else {
                    Text("pro.unavailable")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button("common.retry") { Task { await store.load() } }
                        .buttonStyle(.guitarroSecondary)
                        .frame(maxWidth: 200)
                }
            }
            .frame(maxWidth: .infinity)
            .guitarroCard()
        } else {
            VStack(spacing: GuitarroSpacing.small) {
                ForEach(StoreManager.ProductID.allCases, id: \.self) { id in
                    if let product = store.product(id) {
                        OfferCard(product: product, id: id, isSelected: selected == id, isBestValue: id == .yearly) {
                            withAnimation(.snappy) { selected = id }
                        }
                    }
                }
            }
        }
    }

    private var purchaseButton: some View {
        Button {
            guard let product = store.product(selected) else { return }
            Task { _ = await store.purchase(product) }
        } label: {
            if store.purchaseInProgress {
                ProgressView().tint(Color.guitarroInk)
            } else {
                Label("pro.buy", systemImage: "crown.fill")
            }
        }
        .buttonStyle(.guitarroPrimary(.gold))
        .disabled(store.product(selected) == nil || store.purchaseInProgress)
    }

    private var footer: some View {
        VStack(spacing: GuitarroSpacing.small) {
            Button("pro.restore") { Task { await store.restore() } }
                .font(.subheadline)
            if let error = store.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(Color.guitarroSharp)
                    .multilineTextAlignment(.center)
            }
            Text("pro.legal")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
            HStack(spacing: GuitarroSpacing.medium) {
                Link("pro.terms", destination: Legal.termsOfUse)
                Link("pro.privacy", destination: Legal.privacyPolicy)
            }
            .font(.caption2)
        }
    }
}

private struct ProFeature: View {
    let symbol: String
    let text: LocalizedStringKey

    var body: some View {
        HStack(spacing: GuitarroSpacing.medium) {
            Image(systemName: symbol)
                .foregroundStyle(GuitarroPalette.gold.gradient)
                .frame(width: 28)
            Text(text)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Image(systemName: "checkmark")
                .font(.caption.bold())
                .foregroundStyle(Color.guitarroInTune)
        }
    }
}

private struct OfferCard: View {
    let product: Product
    let id: StoreManager.ProductID
    let isSelected: Bool
    let isBestValue: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(product.displayName)
                            .font(.guitarroHeadline)
                        if isBestValue {
                            GuitarroPill("pro.bestValue", tint: .guitarroInTune)
                        }
                    }
                    Text(periodKey)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(product.displayPrice)
                    .font(.guitarroDisplay(22))
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.guitarroAccent : Color.secondary)
            }
            .padding(GuitarroSpacing.medium)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.white.opacity(isSelected ? 0.12 : 0.06)))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(isSelected ? Color.guitarroAccent : Color.white.opacity(0.1), lineWidth: isSelected ? 2 : 1))
        }
        .buttonStyle(.plain)
    }

    private var periodKey: LocalizedStringKey {
        switch id {
        case .monthly: "pro.period.monthly"
        case .yearly: "pro.period.yearly"
        case .lifetime: "pro.period.lifetime"
        }
    }
}

/// Shows `content` for Pro players, otherwise a locked card that opens the paywall.
struct ProGate<Content: View>: View {
    let feature: LocalizedStringKey
    @ViewBuilder let content: () -> Content

    @Environment(StoreManager.self) private var store
    @State private var showsPaywall = false

    var body: some View {
        if store.hasPro {
            content()
        } else {
            VStack(spacing: GuitarroSpacing.medium) {
                GuitarroIconBadge("lock.fill", size: 72, palette: .gold)
                Text("pro.locked.title")
                    .font(.guitarroTitle)
                Text(feature)
                    .foregroundStyle(.secondary)
                Text("pro.locked.body")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button {
                    showsPaywall = true
                } label: {
                    Label("pro.unlock", systemImage: "crown.fill")
                }
                .buttonStyle(.guitarroPrimary(.gold))
            }
            .frame(maxWidth: 420)
            .guitarroCard()
            .padding()
            .guitarroScreen(glow: .gold)
            .sheet(isPresented: $showsPaywall) { PaywallView() }
        }
    }
}
