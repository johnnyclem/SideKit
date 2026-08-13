import Foundation

struct PeakOverview: Equatable {
    var mins: [Float]
    var maxs: [Float]
    var frames: UInt32

    var bins: Int { mins.count }
    var isEmpty: Bool { mins.isEmpty || maxs.isEmpty }
}

enum PeakCache {
    static let bins = Int(SK_PEAK_BINS)

    static func build(pcm: [Float], frames: UInt32, channels: UInt32 = 2) -> PeakOverview {
        var mn = [Float](repeating: 0, count: bins)
        var mx = [Float](repeating: 0, count: bins)
        let n = pcm.withUnsafeBufferPointer { ptr -> UInt32 in
            guard let base = ptr.baseAddress else { return 0 }
            return sk_peaks_build(base, frames, channels, &mn, &mx, UInt32(bins))
        }
        if n == 0 {
            return PeakOverview(mins: [], maxs: [], frames: frames)
        }
        return PeakOverview(mins: mn, maxs: mx, frames: frames)
    }

    static func cacheURL(for audio: URL) -> URL {
        let name = audio.deletingPathExtension().lastPathComponent + ".skpeaks"
        if audio.path.contains("/Imports/") {
            return audio.deletingLastPathComponent().appendingPathComponent(name)
        }
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let dir = caches.appendingPathComponent("Peaks", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent(name)
    }

    static func load(from url: URL) -> PeakOverview? {
        var frames: UInt32 = 0
        var count: UInt32 = 0
        var mn = [Float](repeating: 0, count: bins)
        var mx = [Float](repeating: 0, count: bins)
        let ok = url.path.withCString { path in
            mn.withUnsafeMutableBufferPointer { minBuf in
                mx.withUnsafeMutableBufferPointer { maxBuf in
                    sk_peaks_read(path, &frames, minBuf.baseAddress, maxBuf.baseAddress, UInt32(bins), &count)
                }
            }
        }
        guard ok == 1, count > 0 else { return nil }
        return PeakOverview(
            mins: Array(mn.prefix(Int(count))),
            maxs: Array(mx.prefix(Int(count))),
            frames: frames
        )
    }

    static func save(_ peaks: PeakOverview, to url: URL) {
        guard !peaks.isEmpty else { return }
        _ = url.path.withCString { path in
            peaks.mins.withUnsafeBufferPointer { minBuf in
                peaks.maxs.withUnsafeBufferPointer { maxBuf in
                    sk_peaks_write(
                        path,
                        peaks.frames,
                        minBuf.baseAddress,
                        maxBuf.baseAddress,
                        UInt32(peaks.bins)
                    )
                }
            }
        }
    }

    /// Load sidecar if present, otherwise build from PCM and persist.
    static func resolve(audioURL: URL, pcm: [Float], frames: UInt32) -> PeakOverview {
        let sidecar = cacheURL(for: audioURL)
        if let cached = load(from: sidecar), cached.frames == frames {
            return cached
        }
        let built = build(pcm: pcm, frames: frames)
        save(built, to: sidecar)
        return built
    }
}
