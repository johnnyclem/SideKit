import SwiftUI

struct LinkView: View {
    @EnvironmentObject private var store: MixerStore

    private let matrix: [(SourceId, String)] = [
        (.usb1, "Deck A L/R out"),
        (.usb2, "Deck B L/R out"),
        (.usb3, "Sidekick return"),
        (.usb4, "Cue / preview"),
        (.usb5, "FX send"),
        (.usb6, "FX return"),
        (.usb7, "Aux record"),
        (.usb8, "Master record"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sidekick Link")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(SKTheme.fg)

            Text("SideKit is the software brain for EP-136 K.O. Sidekick — USB audio hub, dual virtual decks, routing matrix, and remote control surface.")
                .font(.system(size: 11))
                .foregroundStyle(SKTheme.subtle)

            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    Image(systemName: "cable.connector")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(store.linked ? SKTheme.ok : SKTheme.subtle)
                        .frame(width: 48, height: 48)
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
                        Text(store.linked ? "USB-C · 8-in / 4-out · MIDI · 48 kHz" : "Connect Sidekick via USB-C")
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
                            .padding(.horizontal, 14)
                            .frame(height: 36)
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
            .padding(16)
            .skPanel()

            VStack(alignment: .leading, spacing: 4) {
                Text("MIX MODE").skLabel().padding(.bottom, 4)
                SegmentedPills(options: MixerStore.MixMode.allCases, selection: $store.mixMode, title: \.rawValue)
            }
            .padding(12)
            .skPanel()

            VStack(alignment: .leading, spacing: 0) {
                Text("CHANNEL ROUTING").skLabel().padding(.bottom, 8)
                route("iphone", "CH 1 source", store.ch1.source.label)
                route("iphone", "CH 2 source", store.ch2.source.label)
                route("usb.c.circle", "Master out", "Sidekick Mix / USB 7–8")
            }
            .padding(12)
            .skPanel()

            VStack(alignment: .leading, spacing: 6) {
                Text("USB AUDIO MATRIX").skLabel().padding(.bottom, 4)
                ForEach(matrix, id: \.0) { row in
                    HStack {
                        Text(row.0.label)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(SKTheme.fg)
                        Spacer()
                        Text(row.1)
                            .font(.system(size: 10))
                            .foregroundStyle(SKTheme.muted)
                    }
                    .padding(.horizontal, 10)
                    .frame(height: 34)
                    .background(SKTheme.inset)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
            }
            .padding(12)
            .skPanel()

            VStack(alignment: .leading, spacing: 8) {
                Text("ONBOARD INPUTS").skLabel()
                Text("Select iPhone Mic, Device Audio, or Aux as a channel source to fade against virtual decks or Sidekick hardware. Library, decks, routing, and FX live on the phone; Sidekick handles the analog edge.")
                    .font(.system(size: 11))
                    .foregroundStyle(SKTheme.muted)
            }
            .padding(12)
            .skPanel()
        }
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

    private func route(_ icon: String, _ label: String, _ value: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(SKTheme.subtle)
                .frame(width: 18)
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(SKTheme.muted)
            Spacer()
            Text(value)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(SKTheme.fg)
        }
        .padding(.vertical, 8)
        .overlay(alignment: .bottom) {
            Rectangle().fill(SKTheme.border).frame(height: 1)
        }
    }
}
