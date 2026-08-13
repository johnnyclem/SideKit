import SwiftUI

struct MixerView: View {
    @EnvironmentObject private var store: MixerStore

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
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
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .skPanel()

            HStack(spacing: 8) {
                Text("MASTER").skLabel()
                Slider(value: $store.master, in: 0...1)
                    .tint(SKTheme.accent)
                    .onChange(of: store.master) { _, _ in store.pushAudio() }
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
                .frame(width: 44, maxHeight: .infinity)
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