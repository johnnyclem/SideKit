import Foundation

/// Pure tempo / beat math shared by the deck engine and mixer.
/// Mirrored (not imported, to avoid Xcode SPM linkage) into the app target
/// by `DeckPlayer.swift` and `MixerStore.swift` — keep both in sync when editing.
public enum Tempo {
    /// Equal-power crossfade curve. `x` is 0 (full A) ... 1 (full B).
    /// Returns (gainA, gainB), each in 0...1, with gainA^2 + gainB^2 == 1.
    public static func equalPowerCrossfade(_ x: Double) -> (a: Double, b: Double) {
        let clamped = min(1, max(0, x))
        let a = cos(clamped * .pi / 2)
        let b = sin(clamped * .pi / 2)
        return (a, b)
    }

    /// BPM after applying a percentage pitch/time-stretch adjustment (e.g. -8...8 or -16...16).
    public static func effectiveBpm(_ bpm: Double, pitchPercent: Double) -> Double {
        bpm * (1 + pitchPercent / 100)
    }

    /// Seconds for `beats` beats at the given BPM.
    public static func beatsToSeconds(_ beats: Double, bpm: Double) -> TimeInterval {
        guard bpm > 0 else { return 0 }
        return beats * (60.0 / bpm)
    }

    /// Nearest beat boundary (in seconds, from `origin`) to `time`, at the given BPM.
    /// Used to quantize hot-cue / loop points to the beat grid.
    public static func quantize(_ time: TimeInterval, bpm: Double, origin: TimeInterval = 0) -> TimeInterval {
        guard bpm > 0 else { return time }
        let beatLength = 60.0 / bpm
        let beats = ((time - origin) / beatLength).rounded()
        return origin + beats * beatLength
    }

    /// Nearest standard auto-loop length (in beats) not exceeding `maxBeats`.
    /// Standard set matches PRD auto-loop lengths: 1/4, 1/2, 1, 2, 4, 8, 16, 32.
    public static let autoLoopLengths: [Double] = [0.25, 0.5, 1, 2, 4, 8, 16, 32]

    public static func nearestAutoLoopLength(_ beats: Double) -> Double {
        autoLoopLengths.min(by: { abs($0 - beats) < abs($1 - beats) }) ?? 1
    }

    /// Simple onset-interval BPM estimate: median of inter-onset intervals, folded into
    /// a plausible DJ tempo range (70...180 BPM) by doubling/halving. Offline fallback
    /// for files with no embedded BPM tag (SK-014).
    public static func estimateBpm(onsetTimes: [TimeInterval]) -> Double? {
        guard onsetTimes.count >= 4 else { return nil }
        let sorted = onsetTimes.sorted()
        var intervals = [TimeInterval]()
        intervals.reserveCapacity(sorted.count - 1)
        for i in 1..<sorted.count {
            let d = sorted[i] - sorted[i - 1]
            if d > 0.15 && d < 2.0 { intervals.append(d) }
        }
        guard !intervals.isEmpty else { return nil }
        let median = intervals.sorted()[intervals.count / 2]
        guard median > 0 else { return nil }
        var bpm = 60.0 / median
        while bpm < 70 { bpm *= 2 }
        while bpm > 180 { bpm /= 2 }
        return (bpm * 10).rounded() / 10
    }
}
