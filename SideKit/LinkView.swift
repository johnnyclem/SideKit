import SwiftUI

struct LinkView: View {
    @EnvironmentObject private var store: MixerStore
    @ObservedObject private var usbMatrix = USBMatrixStore.shared
    @ObservedObject private var midi = MIDIManager.shared
    @State private var showMatrix = false
    @State private var showMIDI = false

    private let midiTargets: [(String, String)] = [
        ("ch1.gain", "CH1 Gain"), ("ch1.fader", "CH1 Fader"),
        ("ch2.gain", "CH2 Gain"), ("ch2.fader", "CH2 Fader"),
        ("xf", "Crossfader"), ("fx.depth", "FX Depth"), ("fx.engage", "FX Engage"),
    ]

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 8) {
                deviceCard

                VStack(alignment: .leading, spacing: 4) {
                    Text("MIX MODE").skLabel().padding(.bottom, 4)
                    SegmentedPills(options: MixerStore.MixMode.allCases, selection: $store.mixMode, title: \.rawValue)
                }
                .padding(12)
                .skPanel()

                VStack(spacing: 6) {
                    sourceRow("CH 1", store.ch1.source.label)
                    sourceRow("CH 2", store.ch2.source.label)
                    sourceRow("C++ CORE", AudioEngine.shared.cppCoreVersion)
                }
                .padding(12)
                .skPanel()

                collapsible("USB MATRIX — \(store.mixMode.rawValue.uppercased())", isOpen: $showMatrix, trailing: EmptyView()) {
                    matrixRows
                }

                collapsible("MIDI CONTROL", isOpen: $showMIDI, trailing: midiStatus) {
                    midiRows
                }

                monitor("CUE MIX", $store.cueMix)
                monitor("PHONES", $store.headphone)
            }
            .padding(.bottom, 8)
        }
    }

    // MARK: - Device

    private var deviceCard: some View {
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
                    Text(store.linked ? "USB-C · 8×4 · MIDI · 48 kHz" : "Connect Sidekick via USB-C")
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
                .accessibilityLabel(store.linked ? "Disconnect Sidekick" : "Connect Sidekick")
            }

            if store.linked {
                HStack(spacing: 8) {
                    stat("battery.100", "\(store.battery)%", "Battery")
                    stat("waveform", "8×4", "I/O")
                    stat("dot.radiowaves.left.and.right", midi.sidekickConnected ? "ON" : "USB", "MIDI")
                }
            }
        }
        .padding(12)
        .skPanel()
    }

    // MARK: - USB matrix (SK-027)

    private var matrixRows: some View {
        VStack(spacing: 4) {
            ForEach(Array(USBMatrixStore.usbSlots.enumerated()), id: \.offset) { idx, slot in
                let role = usbMatrix.roles(for: store.mixMode.rawValue)[idx]
                let slotLabel = SourceId(rawValue: slot)?.label ?? slot
                Menu {
                    ForEach(USBMatrixStore.roleOptions, id: \.self) { option in
                        Button(option) {
                            usbMatrix.setRole(option, slotIndex: idx, mode: store.mixMode.rawValue)
                        }
                    }
                } label: {
                    HStack {
                        Text(slotLabel)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(SKTheme.fg)
                        Spacer()
                        Text(role)
                            .font(.system(size: 10))
                            .foregroundStyle(SKTheme.muted)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 8))
                            .foregroundStyle(SKTheme.subtle)
                    }
                    .padding(.horizontal, 10)
                    .frame(height: 32)
                    .background(SKTheme.inset)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                .accessibilityLabel("\(slotLabel), routed to \(role)")
            }
        }
    }

    // MARK: - MIDI (SK-040/041/042)

    private var midiStatus: some View {
        HStack(spacing: 5) {
            Circle().fill(midi.sidekickConnected ? SKTheme.ok : SKTheme.subtle).frame(width: 6, height: 6)
            Text(midiStatusText)
                .font(.system(size: 9))
                .foregroundStyle(SKTheme.subtle)
        }
    }

    private var midiStatusText: String {
        if midi.sidekickConnected { return "Sidekick" }
        if midi.sourceNames.isEmpty { return "No sources" }
        return "\(midi.sourceNames.count) source\(midi.sourceNames.count == 1 ? "" : "s")"
    }

    private var midiRows: some View {
        VStack(alignment: .leading, spacing: 6) {
            if midi.sidekickConnected {
                Text("Factory map active — knobs, faders, crossfader and FX pad respond automatically.")
                    .font(.system(size: 10))
                    .foregroundStyle(SKTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            ForEach(midiTargets, id: \.0) { target, label in
                let binding = midi.bindings.first { $0.targetId == target }
                let learning = midi.learningTarget == target
                HStack {
                    Text(label).font(.system(size: 11)).foregroundStyle(SKTheme.fg)
                    Spacer()
                    if let binding {
                        Text(binding.kind == .noteOn ? "Note \(binding.number)" : "CC \(binding.number)")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(SKTheme.muted)
                    }
                    Button {
                        if learning {
                            midi.cancelLearn()
                        } else {
                            midi.learn(target: target)
                        }
                    } label: {
                        Text(learning ? "LISTENING…" : "LEARN")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(learning ? SKTheme.accentFg : SKTheme.muted)
                            .padding(.horizontal, 8)
                            .frame(height: 24)
                            .background(learning ? SKTheme.accent : SKTheme.inset)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(learning ? "Cancel MIDI learn for \(label)" : "Learn MIDI for \(label)")
                }
                .frame(height: 28)
            }

            HStack(spacing: 8) {
                Button {
                    midi.resetToFactoryMap()
                } label: {
                    Text("Factory map")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(SKTheme.muted)
                        .padding(.horizontal, 10)
                        .frame(height: 28)
                        .background(SKTheme.inset)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                Button(role: .destructive) {
                    midi.clearBindings()
                } label: {
                    Text("Clear all")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(SKTheme.danger)
                        .padding(.horizontal, 10)
                        .frame(height: 28)
                        .background(SKTheme.inset)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Pieces

    private func collapsible<Trailing: View, Content: View>(
        _ title: String,
        isOpen: Binding<Bool>,
        trailing: Trailing,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.15)) { isOpen.wrappedValue.toggle() }
            } label: {
                HStack(spacing: 8) {
                    Text(title).skLabel()
                    Spacer()
                    trailing
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(SKTheme.subtle)
                        .rotationEffect(.degrees(isOpen.wrappedValue ? 180 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(title)
            .accessibilityValue(isOpen.wrappedValue ? "Expanded" : "Collapsed")
            if isOpen.wrappedValue {
                content()
            }
        }
        .padding(12)
        .skPanel()
    }

    private func sourceRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).skLabel()
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(SKTheme.fg)
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
