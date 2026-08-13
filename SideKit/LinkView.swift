import SwiftUI

struct LinkView: View {
    @EnvironmentObject private var store: MixerStore
    @ObservedObject private var usbMatrix = USBMatrixStore.shared
    @ObservedObject private var midi = MIDIManager.shared

    private let midiTargets: [(String, String)] = [
        ("ch1.gain", "CH1 Gain"), ("ch1.fader", "CH1 Fader"),
        ("ch2.gain", "CH2 Gain"), ("ch2.fader", "CH2 Fader"),
        ("xf", "Crossfader"), ("fx.depth", "FX Depth"), ("fx.engage", "FX Engage"),
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
                    .accessibilityLabel(store.linked ? "Disconnect Sidekick" : "Connect Sidekick")
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
                HStack {
                    Text("USB AUDIO MATRIX — \(store.mixMode.rawValue.uppercased())").skLabel()
                    Spacer()
                    Text("tap to reassign").font(.system(size: 9)).foregroundStyle(SKTheme.subtle)
                }
                .padding(.bottom, 4)
                ForEach(Array(USBMatrixStore.usbSlots.enumerated()), id: \.offset) { idx, slot in
                    Menu {
                        ForEach(USBMatrixStore.roleOptions, id: \.self) { role in
                            Button(role) {
                                usbMatrix.setRole(role, slotIndex: idx, mode: store.mixMode.rawValue)
                            }
                        }
                    } label: {
                        HStack {
                            Text(SourceId(rawValue: slot)?.label ?? slot)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(SKTheme.fg)
                            Spacer()
                            Text(usbMatrix.roles(for: store.mixMode.rawValue)[idx])
                                .font(.system(size: 10))
                                .foregroundStyle(SKTheme.muted)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 8))
                                .foregroundStyle(SKTheme.subtle)
                        }
                        .padding(.horizontal, 10)
                        .frame(height: 34)
                        .background(SKTheme.inset)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                    .accessibilityLabel("\(SourceId(rawValue: slot)?.label ?? slot), routed to \(usbMatrix.roles(for: store.mixMode.rawValue)[idx])")
                }
            }
            .padding(12)
            .skPanel()

            midiSection

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

    private var midiSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("MIDI CONTROL").skLabel()
                Spacer()
                Circle().fill(midi.sidekickConnected ? SKTheme.ok : SKTheme.subtle).frame(width: 6, height: 6)
                Text(midi.sidekickConnected ? "Sidekick detected" : (midi.sourceNames.isEmpty ? "No MIDI sources" : "\(midi.sourceNames.count) source(s)"))
                    .font(.system(size: 9))
                    .foregroundStyle(SKTheme.subtle)
            }

            if midi.sidekickConnected {
                Text("Factory map active — knobs, faders, crossfader, and FX pad respond automatically. No purchase required.")
                    .font(.system(size: 10))
                    .foregroundStyle(SKTheme.muted)
            }

            VStack(spacing: 4) {
                ForEach(midiTargets, id: \.0) { target, label in
                    let binding = midi.bindings.first { $0.targetId == target }
                    HStack {
                        Text(label).font(.system(size: 11)).foregroundStyle(SKTheme.fg)
                        Spacer()
                        if let binding {
                            Text(binding.kind == .noteOn ? "Note \(binding.number)" : "CC \(binding.number)")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(SKTheme.muted)
                        }
                        Button {
                            midi.learningTarget == target ? midi.cancelLearn() : midi.learn(target: target)
                        } label: {
                            Text(midi.learningTarget == target ? "LISTENING…" : "LEARN")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(midi.learningTarget == target ? SKTheme.accentFg : SKTheme.muted)
                                .padding(.horizontal, 8)
                                .frame(height: 24)
                                .background(midi.learningTarget == target ? SKTheme.accent : SKTheme.inset)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Learn MIDI for \(label)")
                    }
                    .padding(.vertical, 4)
                }
            }

            HStack(spacing: 8) {
                Button { midi.resetToFactoryMap() } label: {
                    Text("Reset to factory map")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(SKTheme.muted)
                        .padding(.horizontal, 10)
                        .frame(height: 30)
                        .background(SKTheme.inset)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                Button(role: .destructive) { midi.clearBindings() } label: {
                    Text("Clear all")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(SKTheme.danger)
                        .padding(.horizontal, 10)
                        .frame(height: 30)
                        .background(SKTheme.inset)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
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
