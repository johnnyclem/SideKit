import SwiftUI

struct RootView: View {
    @EnvironmentObject private var store: MixerStore
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @State private var showDiagnostics = false

    private var isRegularWidth: Bool { hSizeClass == .regular }

    var body: some View {
        ZStack {
            SKTheme.bg.ignoresSafeArea()
            if isRegularWidth {
                // SK-047: iPad landscape — two-column mixer+decks, no horizontal overflow.
                HStack(spacing: 0) {
                    VStack(spacing: 0) {
                        StatusHeader(showDiagnostics: $showDiagnostics)
                            .padding([.horizontal, .top], 16)
                            .padding(.bottom, 8)
                        ScrollView(.vertical, showsIndicators: false) {
                            MixerView().padding(16)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    Divider().overlay(SKTheme.border)
                    ScrollView(.vertical, showsIndicators: false) {
                        Group {
                            switch store.tab {
                            case .mixer, .decks: DecksView()
                            case .fx: FXView()
                            case .library: LibraryView()
                            case .link: LinkView()
                            }
                        }
                        .padding(16)
                    }
                    .frame(maxWidth: .infinity)
                }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    TabBar(tab: $store.tab)
                }
            } else {
                VStack(spacing: 0) {
                    StatusHeader(showDiagnostics: $showDiagnostics)
                        .padding(.horizontal, 16)
                        .padding(.top, 4)
                        .padding(.bottom, 8)

                    ScrollView(.vertical, showsIndicators: false) {
                        Group {
                            switch store.tab {
                            case .mixer: MixerView()
                            case .decks: DecksView()
                            case .fx: FXView()
                            case .library: LibraryView()
                            case .link: LinkView()
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.bottom, 96)
                    }
                }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    TabBar(tab: $store.tab)
                }
            }
        }
        .persistentSystemOverlays(.visible)
        .fullScreenCover(isPresented: $store.showOnboarding) {
            OnboardingView()
        }
        .sheet(isPresented: $store.showPaywall) {
            PaywallView()
        }
        .sheet(isPresented: $showDiagnostics) {
            DiagnosticsView()
        }
    }
}

struct StatusHeader: View {
    @EnvironmentObject private var store: MixerStore
    @Binding var showDiagnostics: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                HStack(spacing: 6) {
                    Circle()
                        .fill(store.linked ? SKTheme.ok : SKTheme.subtle)
                        .frame(width: 6, height: 6)
                    Text(store.linked ? "LINKED" : "OFFLINE")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(1.4)
                        .foregroundStyle(SKTheme.subtle)
                }
                Spacer()
                Text(Formatters.bpm(store.displayBpm) + " BPM")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(SKTheme.muted)
                if store.linked {
                    Text("\(store.battery)%")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(SKTheme.muted)
                        .padding(.leading, 8)
                }
                Button {
                    showDiagnostics = true
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 12))
                        .foregroundStyle(SKTheme.subtle)
                        .padding(.leading, 10)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Diagnostics and settings")
            }

            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("TE COMPANION")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(2.4)
                        .foregroundStyle(SKTheme.subtle)
                    Text("SideKit")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(SKTheme.fg)
                }
                Spacer()
                if !store.iap.isPro {
                    Button { store.showPaywall = true } label: {
                        Text("GO PRO")
                            .font(.system(size: 10, weight: .bold))
                            .tracking(0.6)
                            .foregroundStyle(SKTheme.accentFg)
                            .padding(.horizontal, 10)
                            .frame(height: 26)
                            .background(SKTheme.accent)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Upgrade to SideKit Pro")
                } else {
                    Text("Brain for\nK.O. Sidekick")
                        .font(.system(size: 10))
                        .foregroundStyle(SKTheme.muted)
                        .multilineTextAlignment(.trailing)
                }
            }
        }
    }
}

struct TabBar: View {
    @Binding var tab: AppTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases) { item in
                Button {
                    tab = item
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: item.systemImage)
                            .font(.system(size: 16, weight: .medium))
                            .frame(width: 28, height: 28)
                            .background(tab == item ? SKTheme.accent.opacity(0.15) : Color.clear)
                            .clipShape(Circle())
                        Text(item.title)
                            .font(.system(size: 8, weight: .medium))
                    }
                    .foregroundStyle(tab == item ? SKTheme.fg : SKTheme.subtle)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 48)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(item.title)
                .accessibilityAddTraits(tab == item ? .isSelected : [])
            }
        }
        .padding(.top, 6)
        .padding(.bottom, 10)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Rectangle().fill(SKTheme.border).frame(height: 1)
        }
    }
}

#Preview {
    RootView().environmentObject(MixerStore())
}
