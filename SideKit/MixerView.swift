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
        }
        .padding(.bottom, 8)
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
