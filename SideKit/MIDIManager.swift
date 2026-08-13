import CoreMIDI
import Foundation

/// A single MIDI binding. Mirrors `SideKitCore/Sources/SideKitCore/MIDIMap.swift`
/// (which carries the offline tests) — keep both in sync.
struct MIDIBinding: Codable, Equatable, Identifiable {
    enum MessageKind: String, Codable { case controlChange, noteOn }

    var id: String = UUID().uuidString
    var kind: MessageKind
    var channel: Int
    var number: Int
    var targetId: String
    var bipolar: Bool = false

    func scale(_ raw: Int) -> Double {
        let clamped = Double(min(127, max(0, raw))) / 127.0
        return bipolar ? clamped * 2 - 1 : clamped
    }
}

enum FactoryMIDIMap {
    static func bindings(channel: Int = 0) -> [MIDIBinding] {
        [
            MIDIBinding(kind: .controlChange, channel: channel, number: 20, targetId: "ch1.gain", bipolar: true),
            MIDIBinding(kind: .controlChange, channel: channel, number: 21, targetId: "ch1.eqHi", bipolar: true),
            MIDIBinding(kind: .controlChange, channel: channel, number: 22, targetId: "ch1.eqMid", bipolar: true),
            MIDIBinding(kind: .controlChange, channel: channel, number: 23, targetId: "ch1.eqLo", bipolar: true),
            MIDIBinding(kind: .controlChange, channel: channel, number: 24, targetId: "ch1.fader"),
            MIDIBinding(kind: .controlChange, channel: channel, number: 30, targetId: "ch2.gain", bipolar: true),
            MIDIBinding(kind: .controlChange, channel: channel, number: 31, targetId: "ch2.eqHi", bipolar: true),
            MIDIBinding(kind: .controlChange, channel: channel, number: 32, targetId: "ch2.eqMid", bipolar: true),
            MIDIBinding(kind: .controlChange, channel: channel, number: 33, targetId: "ch2.eqLo", bipolar: true),
            MIDIBinding(kind: .controlChange, channel: channel, number: 34, targetId: "ch2.fader"),
            MIDIBinding(kind: .controlChange, channel: channel, number: 40, targetId: "xf"),
            MIDIBinding(kind: .controlChange, channel: channel, number: 41, targetId: "fx.x"),
            MIDIBinding(kind: .controlChange, channel: channel, number: 42, targetId: "fx.y"),
            MIDIBinding(kind: .controlChange, channel: channel, number: 43, targetId: "fx.depth"),
            MIDIBinding(kind: .noteOn, channel: channel, number: 44, targetId: "fx.engage"),
        ]
    }
}

/// Core MIDI endpoint discovery + Sidekick MIDI Control detection (SK-040), factory map
/// (SK-041, unlocked without IAP once hardware connects), and MIDI learn (SK-042).
@MainActor
final class MIDIManager: ObservableObject {
    static let shared = MIDIManager()

    @Published private(set) var sourceNames: [String] = []
    @Published private(set) var sidekickConnected = false
    @Published private(set) var bindings: [MIDIBinding] = []
    @Published var learningTarget: String?

    var onControlChange: ((MIDIBinding, Int) -> Void)?

    private var client = MIDIClientRef()
    private var inputPort = MIDIPortRef()
    private var started = false
    private let bindingsKey = "sk.midi.bindings.v1"

    private init() {
        loadBindings()
    }

    func start() {
        guard !started else { return }
        started = true

        var midiClient = MIDIClientRef()
        MIDIClientCreateWithBlock("SideKit" as CFString, &midiClient) { [weak self] _ in
            Task { @MainActor in self?.refreshSources() }
        }
        client = midiClient

        var port = MIDIPortRef()
        MIDIInputPortCreateWithBlock(client, "SideKit In" as CFString, &port) { [weak self] packetListPtr, _ in
            let bytes = Self.extractBytes(packetListPtr)
            Task { @MainActor in self?.handleIncoming(bytes) }
        }
        inputPort = port

        refreshSources()
    }

    func learn(target: String) {
        learningTarget = target
    }

    func cancelLearn() {
        learningTarget = nil
    }

    func clearBindings() {
        bindings = []
        persistBindings()
    }

    func resetToFactoryMap() {
        bindings = FactoryMIDIMap.bindings()
        persistBindings()
    }

    private func refreshSources() {
        var names: [String] = []
        let count = MIDIGetNumberOfSources()
        for i in 0..<count {
            let source = MIDIGetSource(i)
            MIDIPortConnectSource(inputPort, source, nil)
            var cfName: Unmanaged<CFString>?
            if MIDIObjectGetStringProperty(source, kMIDIPropertyDisplayName, &cfName) == noErr, let cfName {
                names.append(cfName.takeRetainedValue() as String)
            }
        }
        sourceNames = names
        sidekickConnected = names.contains { name in
            let n = name.lowercased()
            return n.contains("sidekick") || n.contains("ep-136") || n.contains("ep136") || n.contains("ko")
        }
        if sidekickConnected, bindings.isEmpty {
            bindings = FactoryMIDIMap.bindings()
            persistBindings()
        }
    }

    private static func extractBytes(_ packetListPtr: UnsafePointer<MIDIPacketList>) -> [[UInt8]] {
        var messages: [[UInt8]] = []
        var packet = packetListPtr.pointee.packet
        let count = packetListPtr.pointee.numPackets
        for _ in 0..<count {
            let length = Int(packet.length)
            let data = withUnsafeBytes(of: packet.data) { raw -> [UInt8] in
                Array(raw.prefix(length))
            }
            if !data.isEmpty { messages.append(data) }
            packet = MIDIPacketNext(&packet).pointee
        }
        return messages
    }

    private func handleIncoming(_ messages: [[UInt8]]) {
        for bytes in messages where bytes.count >= 3 {
            let status = bytes[0]
            let kindNibble = status & 0xF0
            let channel = Int(status & 0x0F)
            let number = Int(bytes[1])
            let value = Int(bytes[2])

            let kind: MIDIBinding.MessageKind
            if kindNibble == 0xB0 { kind = .controlChange }
            else if kindNibble == 0x90 && value > 0 { kind = .noteOn }
            else { continue }

            if let target = learningTarget {
                let bipolar = target.contains("gain") || target.contains("eq")
                let binding = MIDIBinding(kind: kind, channel: channel, number: number, targetId: target, bipolar: bipolar)
                bindings.removeAll { $0.targetId == target }
                bindings.append(binding)
                persistBindings()
                learningTarget = nil
                continue
            }

            if let binding = bindings.first(where: { $0.kind == kind && $0.channel == channel && $0.number == number }) {
                onControlChange?(binding, value)
            }
        }
    }

    private func loadBindings() {
        guard let data = UserDefaults.standard.data(forKey: bindingsKey),
              let decoded = try? JSONDecoder().decode([MIDIBinding].self, from: data) else { return }
        bindings = decoded
    }

    private func persistBindings() {
        guard let data = try? JSONEncoder().encode(bindings) else { return }
        UserDefaults.standard.set(data, forKey: bindingsKey)
    }
}
