import SwiftUI

struct MixerView: View {
    @EnvironmentObject private var store: MixerStore

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                ScenesMenu()
                Spacer()
                SegmentedPills(
                    options: EqStyle.allCases,
                    selection: Binding(
                        get: { store.eqStyleGlobal },
                        set: { store.setEqStyle($0) }
                    ),
                    title: \.title
                )
                .frame(width: 168)
            }

            HStack(alignment: .top, spacing: 8) {
                ChannelStripView(label: "CH 1", accent: SKTheme.chA, channel: $store.ch1, meter: store.meters.ch1)
                ChannelStripView(label: "CH 2", accent: SKTheme.chB, channel: $store.ch2, meter: store.meters.ch2)
            }
            .frame(maxHeight: .infinity)
            .onChange(of: store.ch1) { _, _ in store.pushAudio() }
            .onChange(of: store.ch2) { _, _ in store.pushAudio() }

            VStack(spacing: 6) {
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
                    .accessibilityLabel("Crossfader")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .skPanel()

            HStack(spacing: 8) {
                Text("MASTER").skLabel()
                Slider(value: $store.master, in: 0...1)
                    .tint(SKTheme.accent)
                    .onChange(of: store.master) { _, _ in store.pushAudio() }
                    .accessibilityLabel("Master level")
                Text("\(Int(store.master * 100))")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(SKTheme.muted)
                    .frame(width: 28, alignment: .trailing)
                HorizontalMeter(level: store.meters.master)
                    .frame(width: 40)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .skPanel()
        }
    }
}

/// Mixer scenes save/recall (SK-043), Pro-gated (SK-046). Compact menu so the Mixer tab
/// stays a single screen.
struct ScenesMenu: View {
    @EnvironmentObject private var store: MixerStore
    @ObservedObject private var snapshots = SnapshotStore.shared
    @State private var naming = false
    @State private var newName = ""

    var body: some View {
        Group {
            if store.isPro {
                Menu {
                    if snapshots.snapshots.isEmpty {
                        Text("No saved scenes")
                    } else {
                        ForEach(snapshots.snapshots) { snap in
                            Button(snap.name) { store.recallSnapshot(snap) }
                        }
                    }
                    Divider()
                    Button {
                        newName = ""
                        naming = true
                    } label: {
                        Label("Save current as scene…", systemImage: "plus")
                    }
                    if !snapshots.snapshots.isEmpty {
                        Menu("Delete") {
                            ForEach(snapshots.snapshots) { snap in
                                Button(role: .destructive) {
                                    snapshots.remove(id: snap.id)
                                } label: {
                                    Text(snap.name)
                                }
                            }
                        }
                    }
                } label: {
                    label
                }
            } else {
                Button {
                    store.showPaywall = true
                } label: {
                    label
                }
                .buttonStyle(.plain)
            }
        }
        .accessibilityLabel("Mixer scenes")
        .alert("Save scene", isPresented: $naming) {
            TextField("Scene name", text: $newName)
            Button("Save") {
                let name = newName.trimmingCharacters(in: .whitespaces)
                store.saveSnapshot(named: name.isEmpty ? "Scene \(snapshots.snapshots.count + 1)" : name)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Saves gains, EQ, faders, crossfader, master and FX depth.")
        }
    }

    private var label: some View {
        HStack(spacing: 5) {
            Image(systemName: store.isPro ? "square.stack.3d.down.right" : "lock.fill")
                .font(.system(size: 10, weight: .semibold))
            Text(store.isPro ? "SCENES" : "SCENES · PRO")
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.6)
        }
        .foregroundStyle(SKTheme.muted)
        .padding(.horizontal, 10)
        .frame(height: 28)
        .background(SKTheme.inset)
        .clipShape(RoundedRectangle(cornerRadius: SKTheme.radiusSM, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: SKTheme.radiusSM, style: .continuous)
                .stroke(SKTheme.border, lineWidth: 1)
        )
    }
}

struct ChannelStripView: View {
    let label: String
    let accent: Color
    @Binding var channel: ChannelState
    var meter: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
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
                VStack(spacing: 6) {
                    HStack(spacing: 6) {
                        KnobView(label: "GAIN", value: $channel.gain, rangeMin: -24, rangeMax: 24, size: 32, bipolar: true)
                        KnobView(label: "HI", value: $channel.eqHi, size: 32)
                    }
                    HStack(spacing: 6) {
                        KnobView(label: "MID", value: $channel.eqMid, size: 32)
                        KnobView(label: "LO", value: $channel.eqLo, size: 32)
                    }
                }
                VStack(spacing: 6) {
                    HStack(alignment: .bottom, spacing: 6) {
                        LevelMeter(level: meter, width: 8)
                        VerticalFader(value: $channel.fader)
                    }
                    .frame(maxHeight: .infinity)
                    Text("\(Int(channel.fader * 100))")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(SKTheme.subtle)
                }
                .frame(width: 44)
                .frame(maxHeight: .infinity)
            }
            .frame(maxHeight: .infinity)

            HStack(spacing: 4) {
                ToggleChip(label: "CUE", systemImage: "headphones", isOn: $channel.cue)
                ToggleChip(label: "MUTE", systemImage: "speaker.slash", danger: true, isOn: $channel.mute)
                ToggleChip(label: "FX", systemImage: "circle", isOn: $channel.fxAssign)
            }

            CompactMenu(title: "Comp", options: CompMode.allCases, selection: $channel.comp, label: \.title)
        }
        .padding(8)
        .skPanel()
    }
}
