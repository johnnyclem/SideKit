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
                .accessibilityLabel("Beat match")
                .accessibilityValue(store.beatMatch ? "On" : "Off")
            }

            let ch = store.focusDeck
            DeckPanelView(
                ch: ch,
                accent: ch == 1 ? SKTheme.chA : SKTheme.chB,
                channel: ch == 1 ? store.ch1 : store.ch2,
                meter: ch == 1 ? store.meters.ch1 : store.meters.ch2,
                onToggle: { store.togglePlay(ch) },
                onPitch: { p in store.setPitch(ch, p) },
                onSeek: { pos in store.seekDeck(ch, pos) },
                onRestart: { store.restartDeck(ch) },
                onSync: { store.syncBpm(from: ch) },
                onSetCue: { slot in store.setHotCue(ch, slot: slot) },
                onJumpCue: { slot in store.jumpToHotCue(ch, slot: slot) },
                onClearCue: { slot in store.clearHotCue(ch, slot: slot) },
                onToggleLoop: { store.toggleLoop(ch) },
                onNudgeLoop: { doubled in store.nudgeLoopLength(ch, doubled: doubled) }
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
                if ch == 2 && !store.isPro {
                    Image(systemName: "lock.fill").font(.system(size: 8))
                }
            }
            .foregroundStyle(store.focusDeck == ch ? SKTheme.accentFg : SKTheme.muted)
            .frame(maxWidth: .infinity)
            .frame(height: 32)
            .background(store.focusDeck == ch ? SKTheme.accent : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Deck \(name)")
        .accessibilityAddTraits(store.focusDeck == ch ? .isSelected : [])
    }
}

struct DeckPanelView: View {
    @EnvironmentObject private var store: MixerStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let ch: Int
    let accent: Color
    let channel: ChannelState
    let meter: Double
    let onToggle: () -> Void
    let onPitch: (Double) -> Void
    let onSeek: (Double) -> Void
    let onRestart: () -> Void
    let onSync: () -> Void
    let onSetCue: (Int) -> Void
    let onJumpCue: (Int) -> Void
    let onClearCue: (Int) -> Void
    let onToggleLoop: () -> Void
    let onNudgeLoop: (Bool) -> Void

    private var track: Track? { store.track(id: channel.trackId) }
    private var deckName: String { ch == 1 ? "A" : "B" }
    private var duration: Double { track.map { store.duration(for: $0) } ?? 0 }

    private var loopRange: ClosedRange<Double>? {
        guard channel.loopActive, duration > 0 else { return nil }
        let start = min(1, max(0, channel.loopStartSec / duration))
        let end = min(1, max(start, (channel.loopStartSec + channel.loopLengthSec) / duration))
        return start...end
    }

    private var cueMarks: [Double?] {
        guard duration > 0 else { return [] }
        return channel.hotCues.map { cue in cue.map { $0 / duration } }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("DECK \(deckName)")
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
                    Text(track != nil ? "\(Formatters.time(channel.deckPos * duration)) / \(Formatters.time(duration))" : "0:00")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(SKTheme.muted)
                }
            }

            WaveformOverview(
                peaks: store.peaks(for: channel.trackId),
                playhead: channel.deckPos,
                accent: accent,
                loop: loopRange,
                cues: cueMarks,
                onSeek: onSeek
            )

            HorizontalMeter(level: meter)

            HStack(spacing: 8) {
                circleBtn("backward.end.fill") { onRestart() }
                    .accessibilityLabel("Restart deck \(deckName)")
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
                .accessibilityLabel(channel.playing ? "Pause deck \(deckName)" : "Play deck \(deckName)")
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
                .accessibilityLabel("Sync the other deck to deck \(deckName)")
                Image(systemName: "opticaldisc")
                    .font(.system(size: 16))
                    .foregroundStyle(SKTheme.subtle)
                    .frame(width: 40, height: 40)
                    .overlay(Circle().stroke(SKTheme.border, lineWidth: 1))
                    .rotationEffect(.degrees(channel.playing && !reduceMotion ? 360 : 0))
                    .animation(
                        channel.playing && !reduceMotion ? .linear(duration: 3).repeatForever(autoreverses: false) : .default,
                        value: channel.playing
                    )
                    .accessibilityHidden(true)
            }

            HStack(spacing: 8) {
                Text("PITCH")
                    .font(.system(size: 10))
                    .foregroundStyle(SKTheme.subtle)
                    .frame(width: 36, alignment: .leading)
                Slider(
                    value: Binding(get: { channel.pitch }, set: onPitch),
                    in: -store.maxPitch...store.maxPitch
                )
                .tint(SKTheme.accent)
                .accessibilityLabel("Pitch, deck \(deckName)")
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
                .accessibilityLabel("Reset pitch to zero")
            }

            HStack(spacing: 6) {
                ForEach(0..<4) { slot in
                    hotCueButton(slot)
                }
                Spacer(minLength: 6)
                Button(action: onToggleLoop) {
                    Text(channel.loopActive ? "LOOP \(loopLabel)" : "LOOP")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(channel.loopActive ? SKTheme.accentFg : SKTheme.muted)
                        .padding(.horizontal, 10)
                        .frame(height: 32)
                        .background(channel.loopActive ? SKTheme.accent : SKTheme.inset)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(SKTheme.border, lineWidth: channel.loopActive ? 0 : 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(channel.loopActive ? "Loop on, \(loopLabel) beats" : "Loop off")
                loopNudge("½", doubled: false)
                loopNudge("2×", doubled: true)
                if !store.isPro {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(SKTheme.subtle)
                        .accessibilityLabel("Hot cues and loops are Pro")
                }
            }
        }
        .padding(12)
        .frame(maxHeight: .infinity, alignment: .top)
        .skPanel()
    }

    private var loopLabel: String {
        let beats = channel.loopLengthBeats
        if beats < 1 { return beats == 0.5 ? "½" : "¼" }
        return "\(Int(beats))"
    }

    private func loopNudge(_ title: String, doubled: Bool) -> some View {
        Button {
            onNudgeLoop(doubled)
        } label: {
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(SKTheme.muted)
                .frame(width: 28, height: 32)
                .background(SKTheme.inset)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(SKTheme.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(doubled ? "Double loop length" : "Halve loop length")
    }

    /// Tap: set (empty) or jump (set). Long press: clear. Plain gestures rather than a
    /// `Button` so the long press cancels the tap instead of firing both.
    private func hotCueButton(_ slot: Int) -> some View {
        let isSet = channel.hotCues[slot] != nil
        return Text("\(slot + 1)")
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(isSet ? SKTheme.bg : SKTheme.muted)
            .frame(width: 32, height: 32)
            .background(isSet ? SKTheme.chB : SKTheme.inset)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(SKTheme.border, lineWidth: isSet ? 0 : 1))
            .contentShape(Rectangle())
            .onTapGesture {
                if isSet { onJumpCue(slot) } else { onSetCue(slot) }
            }
            .onLongPressGesture(minimumDuration: 0.5) {
                if isSet { onClearCue(slot) }
            }
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel(isSet ? "Hot cue \(slot + 1), jump. Long press to clear." : "Hot cue \(slot + 1), set")
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
