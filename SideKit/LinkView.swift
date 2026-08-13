import SwiftUI

struct LinkView: View {
    @EnvironmentObject private var store: MixerStore

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: "cable.connector")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(store.linked ? SKTheme.ok : SKTheme.subtle)
                        .frame(width: 44, height: 44)
                        .background(store.linked ? SKTheme.ok.opacity(0.12) : SKTheme.inset)
                        .clipShape(RoundedRectangle(cornerRadius: SKTheme.radiusMD, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: SKTheme.radiusMD, style: .continuous)
                                .stroke(store.linked ? SKTheme.ok.opacity(0.4) : SKTheme.border, lineWidth: 1)
                        )
                    VStack(alignment: .leading, spacing: 2) {
                        Text(store.linked ? (store.hardwareName ?? "EP-136 K.O. Sidekick") : "No device")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(SKTheme.fg)
                        Text(store.linked ? "USB-C · 8×4 · 48 kHz" : "Connect Sidekick via USB-C")
                            .font(.system(size: 11))
                            .foregroundStyle(SKTheme.muted)
                    }
                    Spacer()
                    Button {
                        store.setLinked(!store.linked)
                    } label: {
                        Text(store.linked ? "Disconnect" : "Connect")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(store.linked ? SKTheme.muted : SKTheme.accentFg)
                            .padding(.horizontal, 12)
                            .frame(height: 32)
                            .background(store.linked ? SKTheme.inset : SKTheme.accent)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(store.linked ? SKTheme.border : Color.clear, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }

                if store.linked {
                    HStack(spacing: 8) {
                        stat("battery.100", "\(store.battery)%", "Battery")
                        stat("waveform", "8×4", "I/O")
                        stat("dot.radiowaves.left.and.right", "USB", "MIDI")
                    }
                }
            }
            .padding(12)
            .skPanel()

            VStack(alignment: .leading, spacing: 4) {
                Text("MIX MODE").skLabel().padding(.bottom, 4)
                SegmentedPills(options: MixerStore.MixMode.allCases, selection: $store.mixMode, title: \.rawValue)
            }
            .padding(12)
            .skPanel()

            VStack(spacing: 6) {
                HStack {
                    Text("CH 1").skLabel()
                    Spacer()
                    Text(store.ch1.source.label)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(SKTheme.fg)
                }
                HStack {
                    Text("CH 2").skLabel()
                    Spacer()
                    Text(store.ch2.source.label)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(SKTheme.fg)
                }
            }
            .padding(12)
            .skPanel()

            Spacer(minLength: 0)

            monitor("CUE MIX", $store.cueMix)
            monitor("PHONES", $store.headphone)
        }
    }

    private func monitor(_ label: String, _ value: Binding<Double>) -> some View {
        HStack(spacing: 8) {
            Text(label).skLabel().frame(width: 56, alignment: .leading)
            Slider(value: value, in: 0...1).tint(SKTheme.accent)
            Text("\(Int(value.wrappedValue * 100))")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(SKTheme.muted)
                .frame(width: 28, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .skPanel()
    }

    private func stat(_ icon: String, _ value: String, _ label: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(SKTheme.subtle)
            Text(value)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(SKTheme.fg)
            Text(label.uppercased())
                .font(.system(size: 9))
                .tracking(0.6)
                .foregroundStyle(SKTheme.subtle)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(SKTheme.inset)
        .clipShape(RoundedRectangle(cornerRadius: SKTheme.radiusSM, style: .continuous))
    }
}