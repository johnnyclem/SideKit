import SwiftUI

struct MixerView: View {
    @EnvironmentObject private var store: MixerStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Mixer")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(SKTheme.fg)
                Spacer()
                SegmentedPills(
                    options: EqStyle.allCases,
                    selection: Binding(
                        get: { store.eqStyleGlobal },
                        set: { store.setEqStyle($0) }
                    ),
                    title: \.title
                )
                .frame(width: 176)
            }

            HStack(alignment: .top, spacing: 8) {
                ChannelStripView(label: "CH 1", accent: SKTheme.chA, channel: $store.ch1, meter: store.meters.ch1)
                ChannelStripView(label: "CH 2", accent: SKTheme.chB, channel: $store.ch2, meter: store.meters.ch2)
            }
            .onChange(of: store.ch1) { _, _ in store.pushAudio() }
            .onChange(of: store.ch2) { _, _ in store.pushAudio() }

            VStack(spacing: 8) {
                HStack {
                    Text("A").skLabel()
                    Spacer()
                    Text("CROSSFADER").skLabel()
                    Spacer()
                    Text("B").skLabel()
                }
                Slider(value: $store.crossfader, in: 0...1)
                    .tint(SKTheme.accent)
                    .onChange(of: store.crossfader) { _, _ in store.pushAudio() }
            }
            .padding(12)
            .skPanel()

            HStack(spacing: 8) {
                MasterSlider(label: "MASTER", value: $store.master, meter: store.meters.master)
                    .onChange(of: store.master) { _, _ in store.pushAudio() }
                MasterSlider(label: "CUE MIX", value: $store.cueMix)
                MasterSlider(label: "PHONES", value: $store.headphone)
            }

            SnapshotsPanel()
        }
        .padding(.bottom, 8)
    }
}

/// Mixer scenes save/recall (SK-043), Pro-gated (SK-046).
struct SnapshotsPanel: View {
    @EnvironmentObject private var store: MixerStore
    @ObservedObject private var snapshots = SnapshotStore.shared
    @State private var newName = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("SCENES").skLabel()
                Spacer()
                if !store.iap.isPro {
                    Image(systemName: "lock.fill").font(.system(size: 9)).foregroundStyle(SKTheme.subtle)
                }
            }

            HStack(spacing: 6) {
                TextField("Scene name", text: $newName)
                    .font(.system(size: 12))
                    .foregroundStyle(SKTheme.fg)
                    .padding(.horizontal, 10)
                    .frame(height: 32)
                    .background(SKTheme.inset)
                    .clipShape(RoundedRectangle(cornerRadius: SKTheme.radiusSM, style: .continuous))
                Button {
                    let name = newName.isEmpty ? "Scene \(snapshots.snapshots.count + 1)" : newName
                    store.saveSnapshot(named: name)
                    newName = ""
                } label: {
                    Text("Save").font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(SKTheme.accentFg)
                        .padding(.horizontal, 12)
                        .frame(height: 32)
                        .background(SKTheme.accent)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Save current mixer state as a scene")
            }

            if snapshots.snapshots.isEmpty {
                Text("No saved scenes yet.")
                    .font(.system(size: 11))
                    .foregroundStyle(SKTheme.subtle)
            } else {
                VStack(spacing: 4) {
                    ForEach(snapshots.snapshots) { snap in
                        HStack {
                            Text(snap.name).font(.system(size: 12)).foregroundStyle(SKTheme.fg)
                            Spacer()
                            Button("Recall") { store.recallSnapshot(snap) }
                                .buttonStyle(.plain)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(SKTheme.muted)
                            Button {
                                snapshots.remove(id: snap.id)
                            } label: {
                                Image(systemName: "trash").font(.system(size: 10))
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(SKTheme.danger)
                            .accessibilityLabel("Delete scene \(snap.name)")
                        }
                        .padding(.horizontal, 10)
                        .frame(height: 32)
                        .background(SKTheme.inset)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                }
            }
        }
        .padding(12)
        .skPanel()
        .opacity(store.iap.isPro ? 1 : 0.55)
        .overlay {
            if !store.iap.isPro {
                Button {
                    store.showPaywall = true
                } label: {
                    Color.clear
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct ChannelStripView: View {
    let label: String
    let accent: Color
    @Binding var channel: ChannelState
    var meter: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(label)
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(1.4)
                    .foregroundStyle(accent)
                Spacer()
                Text(String(format: "%@%.0f dB", channel.gain > 0 ? "+" : "", channel.gain))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(SKTheme.subtle)
            }

            CompactMenu(title: "Source", options: SourceId.allCases, selection: $channel.source, label: \.label)

            HStack(alignment: .top, spacing: 8) {
                VStack(spacing: 8) {
                    KnobView(label: "GAIN", value: $channel.gain, rangeMin: -24, rangeMax: 24, size: 40, bipolar: true)
                    KnobView(label: "HI", value: $channel.eqHi, size: 36)
                    KnobView(label: "MID", value: $channel.eqMid, size: 36)
                    KnobView(label: "LO", value: $channel.eqLo, size: 36)
                }
                VStack(spacing: 6) {
                    HStack(alignment: .bottom, spacing: 8) {
                        LevelMeter(level: meter, width: 10)
                            .frame(height: 148)
                        VerticalFader(value: $channel.fader, height: 148)
                    }
                    Text("\(Int(channel.fader * 100))")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(SKTheme.subtle)
                }
                .frame(maxWidth: .infinity)
            }

            HStack(spacing: 4) {
                ToggleChip(label: "CUE", systemImage: "headphones", isOn: $channel.cue)
                ToggleChip(label: "MUTE", systemImage: "speaker.slash", danger: true, isOn: $channel.mute)
                ToggleChip(label: "FX", systemImage: "circle", isOn: $channel.fxAssign)
            }

            CompactMenu(title: "Comp", options: CompMode.allCases, selection: $channel.comp, label: \.title)
        }
        .padding(10)
        .skPanel()
    }
}

struct MasterSlider: View {
    let label: String
    @Binding var value: Double
    var meter: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(label).skLabel()
                Spacer()
                Text("\(Int(value * 100))")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(SKTheme.muted)
            }
            Slider(value: $value, in: 0...1).tint(SKTheme.accent)
            if let meter {
                HorizontalMeter(level: meter)
            }
        }
        .padding(10)
        .skPanel()
    }
}
