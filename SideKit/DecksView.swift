import SwiftUI

struct DecksView: View {
    @EnvironmentObject private var store: MixerStore

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                HStack(spacing: 0) {
                    deckSwitch(1, "A", playing: store.ch1.playing)
                    deckSwitch(2, "B", playing: store.ch2.playing)
                }
                .padding(2)
                .background(SKTheme.inset)
                .clipShape(RoundedRectangle(cornerRadius: SKTheme.radiusSM, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: SKTheme.radiusSM, style: .continuous)
                        .stroke(SKTheme.border, lineWidth: 1)
                )

                Button {
                    store.beatMatch.toggle()
                } label: {
                    Text(store.beatMatch ? "SYNC ON" : "SYNC OFF")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(0.6)
                        .foregroundStyle(store.beatMatch ? SKTheme.accentFg : SKTheme.muted)
                        .padding(.horizontal, 10)
                        .frame(height: 32)
                        .background(store.beatMatch ? SKTheme.accent : SKTheme.inset)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(SKTheme.border, lineWidth: store.beatMatch ? 0 : 1))
                }
                .buttonStyle(.plain)
            }

            let ch = store.focusDeck
            DeckPanelView(
                ch: ch,
                accent: ch == 1 ? SKTheme.chA : SKTheme.chB,
                channel: ch == 1 ? store.ch1 : store.ch2,
                meter: ch == 1 ? store.meters.ch1 : store.meters.ch2,
                onToggle: { store.togglePlay(ch) },
                onPitch: { p in store.updateChannel(ch) { $0.pitch = p } },
                onSeek: { pos in store.seekDeck(ch, pos) },
                onRestart: { store.restartDeck(ch) },
                onSync: { store.syncBpm(from: ch) }
            )
            .frame(maxHeight: .infinity)
        }
    }

    private func deckSwitch(_ ch: Int, _ name: String, playing: Bool) -> some View {
        Button {
            store.focusDeck = ch
        } label: {
            HStack(spacing: 5) {
                Text("DECK \(name)")
                    .font(.system(size: 11, weight: .semibold))
                if playing {
                    Circle()
                        .fill(store.focusDeck == ch ? SKTheme.accentFg.opacity(0.8) : SKTheme.ok)
                        .frame(width: 6, height: 6)
                }
            }
            .foregroundStyle(store.focusDeck == ch ? SKTheme.accentFg : SKTheme.muted)
            .frame(maxWidth: .infinity)
            .frame(height: 32)
            .background(store.focusDeck == ch ? SKTheme.accent : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct DeckPanelView: View {
    @EnvironmentObject private var store: MixerStore
    let ch: Int
    let accent: Color
    let channel: ChannelState
    let meter: Double
    let onToggle: () -> Void
    let onPitch: (Double) -> Void
    let onSeek: (Double) -> Void
    let onRestart: () -> Void
    let onSync: () -> Void

    private var track: Track? { store.track(id: channel.trackId) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("DECK \(ch == 1 ? "A" : "B")")
                            .font(.system(size: 10, weight: .semibold))
                            .tracking(1.4)
                            .foregroundStyle(accent)
                        if channel.playing {
                            Circle().fill(SKTheme.ok).frame(width: 6, height: 6)
                        }
                    }
                    Text(track?.title ?? "No track")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(SKTheme.fg)
                    Text(track.map { "\($0.artist) · \($0.key)" } ?? "Load from Library")
                        .font(.system(size: 11))
                        .foregroundStyle(SKTheme.muted)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(Formatters.bpm(channel.effectiveBpm))
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(SKTheme.fg)
                    if let track {
                        Text("\(Formatters.time(channel.deckPos * track.duration)) / \(Formatters.time(track.duration))")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(SKTheme.muted)
                    } else {
                        Text("0:00")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(SKTheme.muted)
                    }
                }
            }

            WaveformOverview(
                peaks: store.peaks(for: channel.trackId),
                playhead: channel.deckPos,
                accent: accent,
                onSeek: onSeek
            )

            HorizontalMeter(level: meter)

            HStack(spacing: 8) {
                circleBtn("backward.end.fill") { onRestart() }
                Button(action: onToggle) {
                    Image(systemName: channel.playing ? "pause.fill" : "play.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(channel.playing ? SKTheme.accentFg : SKTheme.fg)
                        .frame(width: 48, height: 48)
                        .background(channel.playing ? SKTheme.accent : SKTheme.chrome)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(SKTheme.borderStrong, lineWidth: 1))
                }
                .buttonStyle(.plain)
                Button(action: onSync) {
                    Label("SYNC", systemImage: "link")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(SKTheme.muted)
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background(SKTheme.inset)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(SKTheme.border, lineWidth: 1))
                }
                .buttonStyle(.plain)
                Image(systemName: "opticaldisc")
                    .font(.system(size: 16))
                    .foregroundStyle(SKTheme.subtle)
                    .frame(width: 40, height: 40)
                    .overlay(Circle().stroke(SKTheme.border, lineWidth: 1))
                    .rotationEffect(.degrees(channel.playing ? 360 : 0))
                    .animation(channel.playing ? .linear(duration: 3).repeatForever(autoreverses: false) : .default, value: channel.playing)
            }

            HStack(spacing: 8) {
                Text("PITCH")
                    .font(.system(size: 10))
                    .foregroundStyle(SKTheme.subtle)
                    .frame(width: 36, alignment: .leading)
                Slider(
                    value: Binding(get: { channel.pitch }, set: onPitch),
                    in: -8...8
                )
                .tint(SKTheme.accent)
                .simultaneousGesture(
                    TapGesture(count: 2).onEnded { onPitch(0) }
                )
                Button {
                    onPitch(0)
                } label: {
                    Text(String(format: "%@%.1f%%", channel.pitch > 0 ? "+" : "", channel.pitch))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(SKTheme.muted)
                        .frame(width: 48, alignment: .trailing)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .frame(maxHeight: .infinity, alignment: .top)
        .skPanel()
    }

    private func circleBtn(_ name: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: name)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(SKTheme.muted)
                .frame(width: 40, height: 40)
                .background(SKTheme.inset)
                .clipShape(Circle())
                .overlay(Circle().stroke(SKTheme.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}