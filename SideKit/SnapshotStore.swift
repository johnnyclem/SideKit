import Foundation

/// Persisted mixer snapshots (SK-043). Mirrors the list ops in
/// `SideKitCore/Sources/SideKitCore/SnapshotCodec.swift` (which carries the offline tests).
final class SnapshotStore: ObservableObject {
    static let shared = SnapshotStore()

    @Published private(set) var snapshots: [MixerSnapshot] = []

    private let key = "sk.snapshots.v1"
    private let maxCount = 16

    private init() {
        load()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([MixerSnapshot].self, from: data) else { return }
        snapshots = decoded
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(snapshots) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    func save(_ snapshot: MixerSnapshot) {
        var result = snapshots.filter { $0.id != snapshot.id }
        result.append(snapshot)
        if result.count > maxCount {
            result.sort { $0.createdAt < $1.createdAt }
            result.removeFirst(result.count - maxCount)
        }
        snapshots = result
        persist()
    }

    func remove(id: String) {
        snapshots.removeAll { $0.id == id }
        persist()
    }

    func rename(id: String, to name: String) {
        guard let idx = snapshots.firstIndex(where: { $0.id == id }) else { return }
        snapshots[idx].name = name
        persist()
    }

    func move(id: String, to newIndex: Int) {
        guard let idx = snapshots.firstIndex(where: { $0.id == id }) else { return }
        let item = snapshots.remove(at: idx)
        snapshots.insert(item, at: min(max(0, newIndex), snapshots.count))
        persist()
    }
}

/// Mirrors `SideKitCore`'s `MixerSnapshot` (kept Codable-compatible; not literally shared
/// via SPM to keep the hand-authored .pbxproj simple — see SideKitCore/README notes).
struct MixerSnapshot: Codable, Equatable, Identifiable {
    var id: String = UUID().uuidString
    var name: String
    var createdAt: TimeInterval
    var ch1Gain: Double
    var ch1EqHi: Double
    var ch1EqMid: Double
    var ch1EqLo: Double
    var ch1Fader: Double
    var ch2Gain: Double
    var ch2EqHi: Double
    var ch2EqMid: Double
    var ch2EqLo: Double
    var ch2Fader: Double
    var crossfader: Double
    var master: Double
    var fx: String
    var fxDepth: Double
}
