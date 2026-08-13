import SwiftUI

struct DecksView: View {
    @EnvironmentObject private var store: MixerStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Virtual Decks")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(SKTheme.fg)
                Spacer()
                Button {
                    store.beatMatch.toggle()
                } label: {
                    Text(store.beatMatch ? "BEAT MATCH ON" : "BEAT MATCH OFF")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(0.6)
                        .foregroundStyle(store.beatMatch ? SKTheme.accentFg : SKTheme.muted)
                        .padding(.horizontal, 12)
                        .frame(height: 32)
                        .background(store.beatMatch ? SKTheme.accent : SKTheme.inset)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(SKTheme.border, lineWidth: store.beatMatch ? 0 : 1))
                }
                .buttonStyle(.plain)
            }

            Text("Two decks from the phone library. Route each into Sidekick CH1/CH2, or mix in SideKit and send master over USB.")
                .font(.system(size: 11))
                .foregroundStyle(SKTheme.subtle)
                .fixedSize(horizontal: false, vertical: true)

            DeckPanelView(
                ch: 1,
                accent: SKTheme.chA,
                channel: store.ch1,
                meter: store.meters.ch1,
                onToggle: { store.togglePlay(1) },
                onPitch: { p in store.updateChannel(1) { $0.pitch = p } },
                onSeek: { pos in store.seekDeck(1, pos) },
                onSync: { store.syncBpm(from: 1) }
            )
            DeckPanelView(
                ch: 2,
                accent: SKTheme.chB,
                channel: store.ch2,
                meter: store.meters.ch2,
                onToggle: { store.togglePlay(2) },
                onPitch: { p in store.updateChannel(2) { $0.pitch = p } },
                onSeek: { pos in store.seekDeck(2, pos) },
                onSync: { store.syncBpm(from: 2) }
            )
        }
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
    let onSync: () -> Void

    private var track: Track? { store.track(id: channel.trackId) }

    private var wave: [Double] {
        let seed = Double((channel.trackId ?? "x").unicodeScalars.first?.value ?? 1) + Double(ch * 17)
        return (0..<48).map { i in
            let n = abs(sin(seed * 0.7 + Double(i) * 0.55) * cos(Double(i) * 0.31 + seed))
            return 0.15 + n * 0.85
        }
    }

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

            GeometryReader { geo in
                let bars = wave
                ZStack(alignment: .leading) {
                    SKTheme.inset
                    HStack(alignment: .bottom, spacing: 1) {
                        ForEach(bars.indices, id: \.self) { i in
                            let passed = Double(i) / Double(bars.count) <= channel.deckPos
                            Capsule()
                                .fill(passed ? SKTheme.accent.opacity(0.8) : SKTheme.borderStrong.opacity(0.7))
                                .frame(height: 36 * bars[i])
                        }
                    }
                    .padding(.horizontal, 4)
                    .padding(.vertical, 6)
                    Rectangle()
                        .fill(SKTheme.accent)
                        .frame(width: 1)
                        .offset(x: geo.size.width * channel.deckPos)
                }
                .clipShape(RoundedRectangle(cornerRadius: SKTheme.radiusSM, style: .continuous))
                .contentShape(Rectangle())
                .gesture(
                    SpatialTapGesture()
                        .onEnded { event in
                            onSeek(min(1, max(0, event.location.x / geo.size.width)))
                        }
                )
            }
            .frame(height: 48)

            HorizontalMeter(level: meter)

            HStack(spacing: 8) {
                circleBtn("backward.end.fill") { onSeek(0) }
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
