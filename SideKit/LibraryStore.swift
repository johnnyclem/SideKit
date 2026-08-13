import AVFoundation
import Foundation

/// Imported-file library (SK-035/SK-036): document-picker import, metadata read,
/// cached waveform peaks, persisted across launches under Application Support.
/// Demo tracks stay in `DemoLibrary` (Models.swift) and are never written here.
@MainActor
final class LibraryStore: ObservableObject {
    static let shared = LibraryStore()

    @Published private(set) var userTracks: [Track] = []
    @Published private(set) var importError: String?

    private struct StoredTrack: Codable {
        var id: String
        var title: String
        var artist: String
        var bpm: Double
        var key: String
        var duration: Double
        var fileName: String
        var bpmIsEstimated: Bool
    }

    private let fm = FileManager.default

    private lazy var supportDir: URL = {
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("SideKit", isDirectory: true)
        try? fm.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }()

    private var importsDir: URL {
        let dir = supportDir.appendingPathComponent("Imports", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private var peaksDir: URL {
        let dir = supportDir.appendingPathComponent("Peaks", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private var indexURL: URL { supportDir.appendingPathComponent("library.json") }

    private init() {
        load()
    }

    var allTracks: [Track] { DemoLibrary.tracks + userTracks }

    func track(id: String?) -> Track? {
        guard let id else { return nil }
        return allTracks.first { $0.id == id }
    }

    func peaks(for trackId: String) -> [Float]? {
        let url = peaksDir.appendingPathComponent("\(trackId).json")
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode([Float].self, from: data)
    }

    private func load() {
        guard let data = try? Data(contentsOf: indexURL),
              let stored = try? JSONDecoder().decode([StoredTrack].self, from: data) else { return }
        userTracks = stored.compactMap { s in
            let url = importsDir.appendingPathComponent(s.fileName)
            guard fm.fileExists(atPath: url.path) else { return nil }
            return Track(id: s.id, title: s.title, artist: s.artist, bpm: s.bpm, key: s.key, duration: s.duration, pattern: .kick, fileURL: url, bpmIsEstimated: s.bpmIsEstimated)
        }
    }

    private func persist() {
        let stored = userTracks.map {
            StoredTrack(id: $0.id, title: $0.title, artist: $0.artist, bpm: $0.bpm, key: $0.key, duration: $0.duration, fileName: $0.fileURL?.lastPathComponent ?? "", bpmIsEstimated: $0.bpmIsEstimated)
        }
        guard let data = try? JSONEncoder().encode(stored) else { return }
        try? data.write(to: indexURL, options: .atomic)
    }

    func remove(id: String) {
        guard let track = userTracks.first(where: { $0.id == id }) else { return }
        if let url = track.fileURL { try? fm.removeItem(at: url) }
        try? fm.removeItem(at: peaksDir.appendingPathComponent("\(id).json"))
        userTracks.removeAll { $0.id == id }
        persist()
    }

    /// Copies picked file(s) into app storage, decodes duration/BPM/peaks, appends to the library.
    /// Errors (unsupported codec, unreadable file) surface via `importError` (SK-010 acceptance).
    func importFiles(_ urls: [URL]) async {
        for url in urls {
            await importOne(url)
        }
    }

    private func importOne(_ sourceURL: URL) async {
        let accessed = sourceURL.startAccessingSecurityScopedResource()
        defer { if accessed { sourceURL.stopAccessingSecurityScopedResource() } }

        let id = UUID().uuidString
        let ext = sourceURL.pathExtension.isEmpty ? "audio" : sourceURL.pathExtension
        let destURL = importsDir.appendingPathComponent("\(id).\(ext)")

        do {
            if fm.fileExists(atPath: destURL.path) { try fm.removeItem(at: destURL) }
            try fm.copyItem(at: sourceURL, to: destURL)

            let file = try AVAudioFile(forReading: destURL)
            let duration = Double(file.length) / file.processingFormat.sampleRate
            guard duration > 0.5 else {
                try? fm.removeItem(at: destURL)
                importError = "\(sourceURL.lastPathComponent): file too short or empty."
                return
            }

            let title = sourceURL.deletingPathExtension().lastPathComponent
            var bpm = await readEmbeddedBPM(url: sourceURL)
            var estimated = false
            let peaks = computePeaks(file: file)

            if bpm == nil {
                bpm = estimateBPM(file: file)
                estimated = bpm != nil
            }

            let track = Track(
                id: id,
                title: title,
                artist: "Imported",
                bpm: bpm ?? 120,
                key: "—",
                duration: duration,
                pattern: .kick,
                fileURL: destURL,
                bpmIsEstimated: estimated
            )

            savePeaks(peaks, trackId: id)
            userTracks.append(track)
            persist()
        } catch {
            try? fm.removeItem(at: destURL)
            importError = "\(sourceURL.lastPathComponent): unsupported or unreadable audio file."
        }
    }

    private func savePeaks(_ peaks: [Float], trackId: String) {
        guard let data = try? JSONEncoder().encode(peaks) else { return }
        try? data.write(to: peaksDir.appendingPathComponent("\(trackId).json"), options: .atomic)
    }

    /// Reads ID3 / iTunes-style BPM tags when present (SK-014).
    private func readEmbeddedBPM(url: URL) async -> Double? {
        let asset = AVURLAsset(url: url)
        let formats: [AVMetadataFormat] = [.id3Metadata, .iTunesMetadata]
        for format in formats {
            guard let items = try? await asset.loadMetadata(for: format) else { continue }
            for item in items {
                let identifier = item.identifier?.rawValue.lowercased() ?? ""
                guard identifier.contains("beatsperminute") || identifier.contains("tempo") else { continue }
                if let value = try? await item.load(.stringValue), let bpm = Double(value.trimmingCharacters(in: .whitespaces)) {
                    return bpm
                }
                if let number = try? await item.load(.numberValue) {
                    return number.doubleValue
                }
            }
        }
        return nil
    }

    /// Cached waveform peaks for the deck overview (SK-013): downsample to ~400 buckets of peak-abs amplitude.
    private func computePeaks(file: AVAudioFile, bucketCount: Int = 400) -> [Float] {
        let frameCount = AVAudioFrameCount(file.length)
        guard frameCount > 0, let format = AVAudioFormat(standardFormatWithSampleRate: file.processingFormat.sampleRate, channels: 1) else { return [] }
        let framesPerBucket = max(1, Int(file.length) / bucketCount)
        var peaks: [Float] = []
        peaks.reserveCapacity(bucketCount)

        let chunkFrames: AVAudioFrameCount = 32_768
        guard let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: chunkFrames) else { return [] }
        var bucketAccum: Float = 0
        var bucketFrames = 0
        file.framePosition = 0

        while true {
            do {
                try file.read(into: buffer, frameCount: chunkFrames)
            } catch { break }
            let n = Int(buffer.frameLength)
            if n == 0 { break }
            guard let channelData = buffer.floatChannelData else { break }
            let channelCount = Int(buffer.format.channelCount)
            for i in 0..<n {
                var sample: Float = 0
                for c in 0..<channelCount { sample = max(sample, abs(channelData[c][i])) }
                bucketAccum = max(bucketAccum, sample)
                bucketFrames += 1
                if bucketFrames >= framesPerBucket {
                    peaks.append(bucketAccum)
                    bucketAccum = 0
                    bucketFrames = 0
                }
            }
            if n < Int(chunkFrames) { break }
        }
        if bucketFrames > 0 { peaks.append(bucketAccum) }
        return peaks.isEmpty ? [0] : peaks
    }

    /// Offline onset-interval BPM fallback (SK-014) over the first ~60s of decoded audio.
    private func estimateBPM(file: AVAudioFile) -> Double? {
        let sr = file.processingFormat.sampleRate
        let windowFrames = AVAudioFrameCount(sr * 0.01) // 10ms envelope window
        let maxFrames = AVAudioFramePosition(min(Double(file.length), sr * 60))
        guard windowFrames > 0, maxFrames > 0 else { return nil }

        guard let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: windowFrames) else { return nil }
        file.framePosition = 0
        var envelope: [Float] = []
        var position: AVAudioFramePosition = 0
        while position < maxFrames {
            do { try file.read(into: buffer, frameCount: windowFrames) } catch { break }
            let n = Int(buffer.frameLength)
            if n == 0 { break }
            guard let data = buffer.floatChannelData else { break }
            var sum: Float = 0
            for i in 0..<n { sum += abs(data[0][i]) }
            envelope.append(sum / Float(n))
            position += AVAudioFramePosition(n)
            if n < Int(windowFrames) { break }
        }
        guard envelope.count > 8 else { return nil }

        let mean = envelope.reduce(0, +) / Float(envelope.count)
        let threshold = mean * 1.4
        var onsets: [TimeInterval] = []
        var wasAbove = false
        for (i, v) in envelope.enumerated() {
            let above = v > threshold
            if above && !wasAbove {
                onsets.append(Double(i) * 0.01)
            }
            wasAbove = above
        }
        return Tempo.estimateBpm(onsetTimes: onsets)
    }
}
