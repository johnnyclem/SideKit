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
                .accessibilityLabel("Beat match")
                .accessibilityValue(store.beatMatch ? "On" : "Off")
            }

            Text("Two decks from the phone library. Route each into Sidekick CH1/CH2, or mix in SideKit and send master over USB.")
                .font(.system(size: 11))
                .foregroundStyle(SKTheme.subtle)
                .fixedSize(horizontal: false, vertical: true)

            DeckPanelView(
                ch: 1,
                accent: SKTheme.chA,
                channel: store.ch1,
                track: store.track(1),
                meter: store.meters.ch1,
                isPro: store.iap.isPro,
                loopFlashing: store.loopFlash == 1,
                onToggle: { store.togglePlay(1) },
                onPitch: { p in store.updateChannel(1) { $0.pitch = p } },
                onSeek: { pos in store.seek(1, toFraction: pos) },
                onSync: { store.syncBpm(from: 1) },
                onSetCue: { slot in store.setHotCue(1, slot: slot) },
                onJumpCue: { slot in store.jumpToHotCue(1, slot: slot) },
                onClearCue: { slot in store.clearHotCue(1, slot: slot) },
                onToggleLoop: { store.toggleLoop(1) },
                onNudgeLoop: { doubled in store.nudgeLoopLength(1, doubled: doubled) }
            )
            DeckPanelView(
                ch: 2,
                accent: SKTheme.chB,
                channel: store.ch2,
                track: store.track(2),
                meter: store.meters.ch2,
                isPro: store.iap.isPro,
                loopFlashing: store.loopFlash == 2,
                onToggle: { store.togglePlay(2) },
                onPitch: { p in store.updateChannel(2) { $0.pitch = p } },
                onSeek: { pos in store.seek(2, toFraction: pos) },
                onSync: { store.syncBpm(from: 2) },
                onSetCue: { slot in store.setHotCue(2, slot: slot) },
                onJumpCue: { slot in store.jumpToHotCue(2, slot: slot) },
                onClearCue: { slot in store.clearHotCue(2, slot: slot) },
                onToggleLoop: { store.toggleLoop(2) },
                onNudgeLoop: { doubled in store.nudgeLoopLength(2, doubled: doubled) }
            )
        }
    }
}

struct DeckPanelView: View {
    let ch: Int
    let accent: Color
    let channel: ChannelState
    let track: Track?
    let meter: Double
    let isPro: Bool
    let loopFlashing: Bool
    let onToggle: () -> Void
    let onPitch: (Double) -> Void
    let onSeek: (Double) -> Void
    let onSync: () -> Void
    let onSetCue: (Int) -> Void
    let onJumpCue: (Int) -> Void
    let onClearCue: (Int) -> Void
    let onToggleLoop: () -> Void
    let onNudgeLoop: (Bool) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var maxPitch: Double { isPro ? 16 : 8 }

    /// Real cached peaks for imported files (SK-013); a deterministic procedural pattern
    /// stands in for the bundled demo tracks, which ship with no audio asset yet.
    private var wave: [Double] {
        if let id = track?.id, let peaks = LibraryStore.shared.peaks(for: id), !peaks.isEmpty {
            return downsample(peaks.map(Double.init), to: 48)
        }
        let seed = Double((channel.trackId ?? "x").unicodeScalars.first?.value ?? 1) + Double(ch * 17)
        return (0..<48).map { i in
            let n = abs(sin(seed * 0.7 + Double(i) * 0.55) * cos(Double(i) * 0.31 + seed))
            return 0.15 + n * 0.85
        }
    }

    private func downsample(_ values: [Double], to count: Int) -> [Double] {
        guard values.count > count else { return values }
        let bucket = Double(values.count) / Double(count)
        return (0..<count).map { i in
            let start = Int(Double(i) * bucket)
            let end = min(values.count, Int(Double(i + 1) * bucket) + 1)
            guard start < end else { return 0 }
            return values[start..<end].max() ?? 0
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
                    Text(track.map { "\($0.artist) · \($0.key)\($0.bpmIsEstimated ? " · BPM est." : "")" } ?? "Load from Library")
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
                let loopRange: ClosedRange<Double>? = {
                    guard channel.loopActive, let duration = track?.duration, duration > 0 else { return nil }
                    let start = channel.loopStartSec / duration
                    let end = min(1, (channel.loopStartSec + Tempo.beatsToSeconds(channel.loopLengthBeats, bpm: channel.effectiveBpm)) / duration)
                    return start...max(start, end)
                }()
                ZStack(alignment: .leading) {
                    SKTheme.inset
                    if let loopRange {
                        Rectangle()
                            .fill((loopFlashing ? SKTheme.ok : SKTheme.warn).opacity(0.22))
                            .frame(width: geo.size.width * (loopRange.upperBound - loopRange.lowerBound))
                            .offset(x: geo.size.width * loopRange.lowerBound)
                    }
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
                    ForEach(Array(channel.hotCues.enumerated()), id: \.offset) { idx, cue in
                        if let cue, let duration = track?.duration, duration > 0 {
                            Rectangle()
                                .fill(SKTheme.chB)
                                .frame(width: 2)
                                .offset(x: geo.size.width * (cue / duration))
                            Text("\(idx + 1)")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(SKTheme.bg)
                                .frame(width: 12, height: 12)
                                .background(SKTheme.chB)
                                .clipShape(Circle())
                                .offset(x: geo.size.width * (cue / duration) - 6, y: -18)
                        }
                    }
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
            .accessibilityLabel("Deck \(ch == 1 ? "A" : "B") waveform")
            .accessibilityValue("\(Int(channel.deckPos * 100)) percent")
            .accessibilityAdjustableAction { direction in
                let step = 0.02
                switch direction {
                case .increment: onSeek(min(1, channel.deckPos + step))
                case .decrement: onSeek(max(0, channel.deckPos - step))
                @unknown default: break
                }
            }

            HorizontalMeter(level: meter)

            HStack(spacing: 8) {
                circleBtn("backward.end.fill") { onSeek(0) }
                    .accessibilityLabel("Restart deck \(ch == 1 ? "A" : "B")")
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
                .accessibilityLabel(channel.playing ? "Pause deck \(ch == 1 ? "A" : "B")" : "Play deck \(ch == 1 ? "A" : "B")")
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
                .accessibilityLabel("Sync deck \(ch == 1 ? "A" : "B") to other deck's tempo")
                Image(systemName: "opticaldisc")
                    .font(.system(size: 16))
                    .foregroundStyle(SKTheme.subtle)
                    .frame(width: 40, height: 40)
                    .overlay(Circle().stroke(SKTheme.border, lineWidth: 1))
                    .rotationEffect(.degrees(channel.playing && !reduceMotion ? 360 : 0))
                    .animation(channel.playing && !reduceMotion ? .linear(duration: 3).repeatForever(autoreverses: false) : .default, value: channel.playing)
                    .accessibilityHidden(true)
            }

            HStack(spacing: 8) {
                Text("PITCH")
                    .font(.system(size: 10))
                    .foregroundStyle(SKTheme.subtle)
                    .frame(width: 36, alignment: .leading)
                Slider(
                    value: Binding(get: { channel.pitch }, set: { onPitch(min(maxPitch, max(-maxPitch, $0))) }),
                    in: -maxPitch...maxPitch
                )
                .tint(SKTheme.accent)
                .accessibilityLabel("Pitch, deck \(ch == 1 ? "A" : "B")")
                Button {
                    onPitch(0)
                } label: {
                    Text(String(format: "%@%.1f%%", channel.pitch > 0 ? "+" : "", channel.pitch))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(SKTheme.muted)
                        .frame(width: 48, alignment: .trailing)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Reset pitch to zero")
            }

            HStack(spacing: 6) {
                ForEach(0..<4) { slot in
                    hotCueButton(slot)
                }
                Spacer(minLength: 8)
                Button(action: onToggleLoop) {
                    Text(channel.loopActive ? "LOOP ●" : "LOOP")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(channel.loopActive ? SKTheme.accentFg : SKTheme.muted)
                        .padding(.horizontal, 10)
                        .frame(height: 32)
                        .background(channel.loopActive ? SKTheme.accent : SKTheme.inset)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(SKTheme.border, lineWidth: channel.loopActive ? 0 : 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(channel.loopActive ? "Loop on, \(Formatters.bpm(channel.loopLengthBeats)) beats" : "Loop off")
                if channel.loopActive {
                    Button { onNudgeLoop(false) } label: { Text("½").font(.system(size: 11, weight: .bold)) }
                        .buttonStyle(.plain)
                        .foregroundStyle(SKTheme.muted)
                        .frame(width: 24, height: 32)
                        .accessibilityLabel("Halve loop length")
                    Button { onNudgeLoop(true) } label: { Text("2×").font(.system(size: 10, weight: .bold)) }
                        .buttonStyle(.plain)
                        .foregroundStyle(SKTheme.muted)
                        .frame(width: 24, height: 32)
                        .accessibilityLabel("Double loop length")
                }
            }
            .opacity(isPro ? 1 : 0.45)
            .overlay {
                if !isPro {
                    Text("Hot cues + loops are Pro")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(SKTheme.subtle)
                }
            }
        }
        .padding(12)
        .skPanel()
    }

    private func hotCueButton(_ slot: Int) -> some View {
        let set = channel.hotCues[slot] != nil
        return Button {
            if set { onJumpCue(slot) } else { onSetCue(slot) }
        } label: {
            Text("\(slot + 1)")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(set ? SKTheme.bg : SKTheme.muted)
                .frame(width: 32, height: 32)
                .background(set ? SKTheme.chB : SKTheme.inset)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(SKTheme.border, lineWidth: set ? 0 : 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(set ? "Hot cue \(slot + 1), jump" : "Hot cue \(slot + 1), set")
        .onLongPressGesture {
            if set { onClearCue(slot) }
        }
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
