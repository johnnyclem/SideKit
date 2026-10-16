import AVFoundation
import Foundation

/// Imported-file library index (SK-035/SK-036): which files the user has imported, persisted
/// across launches as `Documents/Imports/library.json`. Decoding, peaks and playback stay in
/// `MixerStore` / `FileDecoder` / `PeakCache` / the C++ core — this type only owns metadata.
/// Demo tracks stay in `DemoLibrary` (Models.swift) and are never written here.
@MainActor
final class LibraryStore: ObservableObject {
    static let shared = LibraryStore()

    @Published private(set) var userTracks: [Track] = []

    private struct StoredTrack: Codable {
        var id: String
        var title: String
        var artist: String
        var bpm: Double
        var key: String
        var duration: Double
        var fileName: String
        var resampled: Bool
        var bpmIsEstimated: Bool
    }

    /// `Documents/Imports`. `PeakCache` writes its `.skpeaks` sidecar next to each file here.
    static var importsDir: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("Imports", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private var indexURL: URL { Self.importsDir.appendingPathComponent("library.json") }

    private init() {
        load()
    }

    func track(id: String?) -> Track? {
        guard let id else { return nil }
        return userTracks.first { $0.id == id }
    }

    func add(_ track: Track) {
        userTracks.removeAll { $0.id == track.id }
        userTracks.insert(track, at: 0)
        persist()
    }

    func update(id: String, _ patch: (inout Track) -> Void) {
        guard let idx = userTracks.firstIndex(where: { $0.id == id }) else { return }
        patch(&userTracks[idx])
        persist()
    }

    /// Deletes the imported file and its peaks sidecar, then drops it from the index.
    func remove(id: String) {
        guard let track = userTracks.first(where: { $0.id == id }) else { return }
        if let url = track.fileURL {
            try? FileManager.default.removeItem(at: url)
            try? FileManager.default.removeItem(at: PeakCache.cacheURL(for: url))
        }
        userTracks.removeAll { $0.id == id }
        persist()
    }

    /// Copies a picked file into `Documents/Imports` under a fresh UUID name.
    static func persistImport(_ url: URL) throws -> URL {
        let ext = url.pathExtension.lowercased()
        let dest = importsDir.appendingPathComponent(UUID().uuidString + (ext.isEmpty ? "" : "." + ext))
        if FileManager.default.fileExists(atPath: dest.path) {
            try FileManager.default.removeItem(at: dest)
        }
        try FileManager.default.copyItem(at: url, to: dest)
        return dest
    }

    private func load() {
        guard let data = try? Data(contentsOf: indexURL),
              let stored = try? JSONDecoder().decode([StoredTrack].self, from: data) else { return }
        let dir = Self.importsDir
        userTracks = stored.compactMap { item in
            let url = dir.appendingPathComponent(item.fileName)
            guard FileManager.default.fileExists(atPath: url.path) else { return nil }
            return Track(
                id: item.id,
                title: item.title,
                artist: item.artist,
                bpm: item.bpm,
                key: item.key,
                duration: item.duration,
                pattern: .kick,
                fileURL: url,
                resampled: item.resampled,
                isImported: true,
                bpmIsEstimated: item.bpmIsEstimated
            )
        }
    }

    private func persist() {
        let stored = userTracks.map {
            StoredTrack(
                id: $0.id,
                title: $0.title,
                artist: $0.artist,
                bpm: $0.bpm,
                key: $0.key,
                duration: $0.duration,
                fileName: $0.fileURL?.lastPathComponent ?? "",
                resampled: $0.resampled,
                bpmIsEstimated: $0.bpmIsEstimated
            )
        }
        guard let data = try? JSONEncoder().encode(stored) else { return }
        try? data.write(to: indexURL, options: .atomic)
    }
}

/// BPM detection for imports (SK-014): embedded ID3 / iTunes tag first, then an
/// energy-envelope onset estimate over the first 60 s of the decoded 48 kHz clip.
enum BPMAnalyzer {
    struct Result {
        var bpm: Double?
        var estimated: Bool
    }

    static func analyze(url: URL, clip: DecodedClip) async -> Result {
        if let tagged = await embeddedBPM(url: url), tagged > 40, tagged < 300 {
            return Result(bpm: tagged, estimated: false)
        }
        let pcm = clip.pcm
        let frames = clip.frames
        let estimated = await Task.detached(priority: .utility) {
            Self.estimate(pcm: pcm, frames: frames)
        }.value
        return Result(bpm: estimated, estimated: estimated != nil)
    }

    static func embeddedBPM(url: URL) async -> Double? {
        let asset = AVURLAsset(url: url)
        let formats: [AVMetadataFormat] = [.id3Metadata, .iTunesMetadata]
        for format in formats {
            guard let items = try? await asset.loadMetadata(for: format) else { continue }
            for item in items {
                let identifier = item.identifier?.rawValue.lowercased() ?? ""
                guard identifier.contains("beatsperminute") || identifier.contains("tempo") else { continue }
                if let value = try? await item.load(.stringValue),
                   let bpm = Double(value.trimmingCharacters(in: .whitespaces)) {
                    return bpm
                }
                if let number = try? await item.load(.numberValue) {
                    return number.doubleValue
                }
            }
        }
        return nil
    }

    /// Interleaved stereo 48 kHz → 10 ms mean-abs envelope → threshold crossings → median IOI.
    static func estimate(pcm: [Float], frames: UInt32, sampleRate: Double = 48_000) -> Double? {
        let window = Int(sampleRate * 0.01)
        let maxFrames = min(Int(frames), Int(sampleRate * 60))
        guard window > 0, maxFrames > window * 8 else { return nil }

        var envelope: [Float] = []
        envelope.reserveCapacity(maxFrames / window + 1)
        var i = 0
        while i + window <= maxFrames {
            var sum: Float = 0
            for f in i..<(i + window) {
                sum += abs(pcm[f * 2])
            }
            envelope.append(sum / Float(window))
            i += window
        }
        guard envelope.count > 8 else { return nil }

        let mean = envelope.reduce(0, +) / Float(envelope.count)
        let threshold = mean * 1.4
        var onsets: [TimeInterval] = []
        var wasAbove = false
        for (idx, v) in envelope.enumerated() {
            let above = v > threshold
            if above && !wasAbove {
                onsets.append(Double(idx) * 0.01)
            }
            wasAbove = above
        }
        return Tempo.estimateBpm(onsetTimes: onsets)
    }
}
