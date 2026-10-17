import Foundation

/// A single MIDI binding: a CC or note number driving one mixer/deck target.
/// Mirrored into the app target by `MIDIManager.swift` — keep both in sync.
public struct MIDIBinding: Codable, Equatable, Identifiable {
    public enum MessageKind: String, Codable { case controlChange, noteOn }

    public var id: String
    public var kind: MessageKind
    public var channel: Int      // 0...15
    public var number: Int       // CC number or note number, 0...127
    public var targetId: String  // e.g. "ch1.gain", "xf", "fx.depth"
    public var bipolar: Bool     // true if target range is -1...1 rather than 0...1

    public init(id: String = UUID().uuidString, kind: MessageKind, channel: Int, number: Int, targetId: String, bipolar: Bool = false) {
        self.id = id
        self.kind = kind
        self.channel = channel
        self.number = number
        self.targetId = targetId
        self.bipolar = bipolar
    }

    /// Scale a raw 0...127 MIDI data byte to the binding's target range.
    public func scale(_ raw: Int) -> Double {
        let clamped = Double(min(127, max(0, raw))) / 127.0
        return bipolar ? clamped * 2 - 1 : clamped
    }
}

/// Original SideKit factory map for the Sidekick hardware surface.
/// Values are illustrative CC assignments — not derived from any third-party map.
public enum FactoryMIDIMap {
    public static func bindings(channel: Int = 0) -> [MIDIBinding] {
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
