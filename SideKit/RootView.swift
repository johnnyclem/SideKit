import SwiftUI

struct RootView: View {
    @EnvironmentObject private var store: MixerStore

    var body: some View {
        ZStack {
            SKTheme.bg.ignoresSafeArea()
            VStack(spacing: 0) {
                StatusHeader()
                    .padding(.horizontal, 16)
                    .padding(.top, 2)
                    .padding(.bottom, 6)

                if let banner = store.decodeBanner, store.tab != .library {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(SKTheme.warn)
                        Text(banner)
                            .font(.system(size: 11))
                            .foregroundStyle(SKTheme.fg)
                            .lineLimit(2)
                        Spacer(minLength: 0)
                        Button("OK") { store.dismissDecodeBanner() }
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(SKTheme.muted)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 6)
                }

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
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            TabBar(tab: $store.tab)
        }
        .persistentSystemOverlays(.visible)
    }
}

struct StatusHeader: View {
    @EnvironmentObject private var store: MixerStore

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                Circle()
                    .fill(store.linked ? SKTheme.ok : SKTheme.subtle)
                    .frame(width: 6, height: 6)
                Text(store.linked ? "SIDEKICK" : "OFFLINE")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1.2)
                    .foregroundStyle(SKTheme.subtle)
            }
            Spacer()
            Text(Formatters.bpm(store.displayBpm) + " BPM")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(SKTheme.fg)
            if store.linked {
                Text("\(store.battery)%")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(SKTheme.muted)
            }
        }
        .frame(height: 28)
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