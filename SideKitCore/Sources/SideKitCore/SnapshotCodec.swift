import Foundation

/// A saved mixer scene (SK-043). Pure data + pure list operations;
/// persistence (UserDefaults) lives app-side in `SnapshotStore.swift`, which
/// mirrors this type — keep both in sync.
public struct MixerSnapshot: Codable, Equatable, Identifiable {
    public var id: String
    public var name: String
    public var createdAt: TimeInterval
    public var ch1Gain: Double
    public var ch1EqHi: Double
    public var ch1EqMid: Double
    public var ch1EqLo: Double
    public var ch1Fader: Double
    public var ch2Gain: Double
    public var ch2EqHi: Double
    public var ch2EqMid: Double
    public var ch2EqLo: Double
    public var ch2Fader: Double
    public var crossfader: Double
    public var master: Double
    public var fx: String
    public var fxDepth: Double

    public init(
        id: String = UUID().uuidString,
        name: String,
        createdAt: TimeInterval,
        ch1Gain: Double, ch1EqHi: Double, ch1EqMid: Double, ch1EqLo: Double, ch1Fader: Double,
        ch2Gain: Double, ch2EqHi: Double, ch2EqMid: Double, ch2EqLo: Double, ch2Fader: Double,
        crossfader: Double, master: Double, fx: String, fxDepth: Double
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.ch1Gain = ch1Gain; self.ch1EqHi = ch1EqHi; self.ch1EqMid = ch1EqMid; self.ch1EqLo = ch1EqLo; self.ch1Fader = ch1Fader
        self.ch2Gain = ch2Gain; self.ch2EqHi = ch2EqHi; self.ch2EqMid = ch2EqMid; self.ch2EqLo = ch2EqLo; self.ch2Fader = ch2Fader
        self.crossfader = crossfader; self.master = master; self.fx = fx; self.fxDepth = fxDepth
    }
}

public enum SnapshotList {
    public static let maxCount = 16

    /// Insert or replace-by-id, capped at `maxCount` (drops the oldest).
    public static func upserting(_ snapshot: MixerSnapshot, into list: [MixerSnapshot]) -> [MixerSnapshot] {
        var result = list.filter { $0.id != snapshot.id }
        result.append(snapshot)
        if result.count > maxCount {
            result.sort { $0.createdAt < $1.createdAt }
            result.removeFirst(result.count - maxCount)
        }
        return result
    }

    public static func removing(id: String, from list: [MixerSnapshot]) -> [MixerSnapshot] {
        list.filter { $0.id != id }
    }

    public static func moving(id: String, to newIndex: Int, in list: [MixerSnapshot]) -> [MixerSnapshot] {
        guard let idx = list.firstIndex(where: { $0.id == id }) else { return list }
        var copy = list
        let item = copy.remove(at: idx)
        let clampedIndex = min(max(0, newIndex), copy.count)
        copy.insert(item, at: clampedIndex)
        return copy
    }

    public static func encode(_ list: [MixerSnapshot]) -> Data? {
        try? JSONEncoder().encode(list)
    }

    public static func decode(_ data: Data) -> [MixerSnapshot] {
        (try? JSONDecoder().decode([MixerSnapshot].self, from: data)) ?? []
    }
}
