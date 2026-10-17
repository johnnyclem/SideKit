import Foundation

/// Pure tempo / beat math. Mirrors `SideKitCore/Sources/SideKitCore/Tempo.swift`,
/// which carries the offline unit tests (SK-002) — keep both copies in sync.
enum Tempo {
    static func equalPowerCrossfade(_ x: Double) -> (a: Double, b: Double) {
        let clamped = min(1, max(0, x))
        return (cos(clamped * .pi / 2), sin(clamped * .pi / 2))
    }

    static func effectiveBpm(_ bpm: Double, pitchPercent: Double) -> Double {
        bpm * (1 + pitchPercent / 100)
    }

    static func beatsToSeconds(_ beats: Double, bpm: Double) -> TimeInterval {
        guard bpm > 0 else { return 0 }
        return beats * (60.0 / bpm)
    }

    static func quantize(_ time: TimeInterval, bpm: Double, origin: TimeInterval = 0) -> TimeInterval {
        guard bpm > 0 else { return time }
        let beatLength = 60.0 / bpm
        let beats = ((time - origin) / beatLength).rounded()
        return origin + beats * beatLength
    }

    static let autoLoopLengths: [Double] = [0.25, 0.5, 1, 2, 4, 8, 16, 32]

    static func nearestAutoLoopLength(_ beats: Double) -> Double {
        autoLoopLengths.min(by: { abs($0 - beats) < abs($1 - beats) }) ?? 1
    }

    static func estimateBpm(onsetTimes: [TimeInterval]) -> Double? {
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
