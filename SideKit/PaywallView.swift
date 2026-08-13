import StoreKit
import SwiftUI

/// SK-045: paywall shown only after a value moment (a gated action), never before first audio.
struct PaywallView: View {
    @ObservedObject private var store = StoreManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var purchasing = false

    private let freeFeatures = ["Deck A playback", "Filter + Delay FX", "Sidekick hardware link", "Library import"]
    private let proFeatures = ["Dual-deck mixing + SYNC", "Hot cues + loops", "All 6 performance FX", "Mixer scenes", "±16% pitch range"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("SideKit Pro")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(SKTheme.fg)
                        Text("One-time unlock. No subscription, no ads.")
                            .font(.system(size: 12))
                            .foregroundStyle(SKTheme.muted)
                    }

                    comparisonColumn(title: "FREE", items: freeFeatures, accent: false)
                    comparisonColumn(title: "PRO", items: proFeatures, accent: true)

                    if let error = store.purchaseError {
                        Text(error).font(.system(size: 11)).foregroundStyle(SKTheme.danger)
                    }

                    Button {
                        purchasing = true
                        Task {
                            await store.purchase()
                            purchasing = false
                            if store.isPro { dismiss() }
                        }
                    } label: {
                        HStack {
                            if purchasing { ProgressView().tint(SKTheme.accentFg) }
                            Text(store.product?.displayPrice.isEmpty == false ? "Unlock Pro — \(store.product!.displayPrice)" : "Unlock Pro")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundStyle(SKTheme.accentFg)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(SKTheme.accent)
                        .clipShape(RoundedRectangle(cornerRadius: SKTheme.radiusMD, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(purchasing || store.product == nil)
                    .accessibilityLabel("Unlock SideKit Pro")

                    Button {
                        Task {
                            await store.restore()
                            if store.isPro { dismiss() }
                        }
                    } label: {
                        Text("Restore purchases")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(SKTheme.muted)
                            .frame(maxWidth: .infinity)
                            .frame(height: 36)
                    }
                    .buttonStyle(.plain)
                }
                .padding(20)
            }
            .background(SKTheme.bg.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private func comparisonColumn(title: String, items: [String], accent: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).skLabel().foregroundStyle(accent ? SKTheme.accent : SKTheme.subtle)
            ForEach(items, id: \.self) { item in
                HStack(spacing: 8) {
                    Image(systemName: accent ? "checkmark.circle.fill" : "checkmark.circle")
                        .foregroundStyle(accent ? SKTheme.ok : SKTheme.muted)
                        .font(.system(size: 13))
                    Text(item).font(.system(size: 13)).foregroundStyle(SKTheme.fg)
                }
            }
        }
        .padding(14)
        .skPanel()
    }
}
