import SwiftUI

/// SK-048: onboarding ≤60s — connect hardware OR load a demo track, skippable throughout.
struct OnboardingView: View {
    @EnvironmentObject private var store: MixerStore

    var body: some View {
        ZStack {
            SKTheme.bg.ignoresSafeArea()
            VStack(spacing: 24) {
                Spacer()
                VStack(spacing: 8) {
                    Text("SideKit")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(SKTheme.fg)
                    Text("The software brain for EP-136 K.O. Sidekick")
                        .font(.system(size: 13))
                        .foregroundStyle(SKTheme.muted)
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: 12) {
                    optionCard(
                        icon: "cable.connector",
                        title: "Connect Sidekick",
                        subtitle: "Plug in over USB-C for hardware I/O and MIDI control.",
                        action: {
                            store.tab = .link
                            store.completeOnboarding()
                        }
                    )
                    optionCard(
                        icon: "opticaldisc",
                        title: "Load a demo track",
                        subtitle: "Skip hardware for now — mix with the built-in demo library.",
                        action: {
                            store.loadTrack(ch: 1, id: "t6")
                            store.togglePlay(1)
                            store.tab = .decks
                            store.completeOnboarding()
                        }
                    )
                }
                .padding(.horizontal, 20)

                Spacer()

                Button("Skip") { store.completeOnboarding() }
                    .buttonStyle(.plain)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(SKTheme.subtle)
                    .padding(.bottom, 24)
                    .accessibilityLabel("Skip onboarding")
            }
        }
    }

    private func optionCard(icon: String, title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(SKTheme.accent)
                    .frame(width: 48, height: 48)
                    .background(SKTheme.inset)
                    .clipShape(RoundedRectangle(cornerRadius: SKTheme.radiusMD, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.system(size: 15, weight: .semibold)).foregroundStyle(SKTheme.fg)
                    Text(subtitle).font(.system(size: 11)).foregroundStyle(SKTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 12)).foregroundStyle(SKTheme.subtle)
            }
            .padding(14)
            .skPanel()
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(subtitle)")
    }
}
