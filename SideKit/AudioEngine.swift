import AVFoundation
import Foundation

/// I/O + FX host. Mixer, voices, and transport live in C++ (`SideKitAudio`).
/// Swift only posts params over the lock-free SPSC queue.
final class AudioEngine {
    static let shared = AudioEngine()

    var cppCoreVersion: String { cppBridge.version }

    private let engine = AVAudioEngine()
    private let filter = AVAudioUnitEQ(numberOfBands: 1)
    private let delay = AVAudioUnitDelay()

    private var format: AVAudioFormat!
    private var started = false

    private let cppBridge = SKAudioBridge.shared
    /// Preallocated scratch — never resized on the audio thread.
    private var cppScratch = [Float](repeating: 0, count: 4096)
    private var cppSource: AVAudioSourceNode?

    private init() {
        configureGraph()
    }

    func unlock() async {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setPreferredSampleRate(48_000)
            try session.setActive(true)
        } catch {
            print("SideKit session: \(error)")
        }
        startIfNeeded()
        if engine.isRunning == false {
            try? engine.start()
        }
    }

    func setMaster(_ level: Double) {
        cppBridge.setMaster(Float(max(0, min(1, level))))
        engine.mainMixerNode.outputVolume = 0.95
    }

    func setChannelPlaying(_ ch: Int, _ playing: Bool, _ track: Track?, bpm: Double) {
        let pattern: UInt32
        switch track?.pattern {
        case .kick: pattern = UInt32(SK_PATTERN_KICK)
        case .bass: pattern = UInt32(SK_PATTERN_BASS)
        case .hat: pattern = UInt32(SK_PATTERN_HAT)
        case .synth: pattern = UInt32(SK_PATTERN_SYNTH)
        case .breakbeat: pattern = UInt32(SK_PATTERN_BREAK)
        case .none: pattern = UInt32(SK_PATTERN_KICK)
        }
        cppBridge.setTransport(
            ch: UInt32(ch),
            playing: playing && track != nil,
            pattern: pattern,
            bpm: Float(bpm)
        )
    }

    func applyChannel(_ ch: Int, _ state: ChannelState, xf: Double, master: Double) {
        cppBridge.setChannelMix(
            ch: UInt32(ch),
            gainDb: Float(state.gain),
            fader: Float(state.fader),
            mute: state.mute
        )
        let styleMul: Float = state.eqStyle == .dj ? 18 : state.eqStyle == .studio ? 12 : 15
        cppBridge.setChannelEQ(
            ch: UInt32(ch),
            lo: Float(state.eqLo),
            mid: Float(state.eqMid),
            hi: Float(state.eqHi),
            styleMul: styleMul
        )
        cppBridge.setCrossfader(Float(xf))
        cppBridge.setMaster(Float(master))
        cppBridge.setPitch(ch: UInt32(ch), percent: Float(state.pitch))
    }

    func readMeters() -> (ch1: Double, ch2: Double, master: Double) {
        let info = cppBridge.lastInfo()
        return (Double(info.peak_ch1), Double(info.peak_ch2), Double(info.peak))
    }

    @discardableResult
    func loadDecodedClip(ch: Int, clip: DecodedClip) -> Bool {
        clip.pcm.withUnsafeBufferPointer { ptr in
            guard let base = ptr.baseAddress else { return false }
            return cppBridge.loadClip(ch: UInt32(ch), pcm: base, frames: clip.frames, channels: 2)
        }
    }

    func clearClip(ch: Int) {
        cppBridge.clearClip(ch: UInt32(ch))
    }

    func seekClip(ch: Int, normalized: Double) {
        cppBridge.setClipPosition(ch: UInt32(ch), normalized: Float(min(1, max(0, normalized))))
    }

    func seekFrames(ch: Int, frame: UInt32) {
        cppBridge.seekFrames(ch: UInt32(ch), frame: frame)
    }

    func restart(ch: Int) {
        cppBridge.restart(ch: UInt32(ch))
    }

    func clipPlayhead(ch: Int) -> (pos: Double, duration: Double)? {
        let info = cppBridge.clipInfo(ch: UInt32(ch))
        guard info.loaded != 0, info.frames > 0 else { return nil }
        return (Double(info.playhead) / Double(info.frames), Double(info.frames) / 48_000)
    }

    func transportState(ch: Int) -> SKClipInfo {
        cppBridge.clipInfo(ch: UInt32(ch))
    }

    func decodeFile(url: URL) async throws -> DecodedClip {
        try await Task.detached(priority: .userInitiated) {
            try FileDecoder.decode(url: url)
        }.value
    }

    func applyFx(_ fx: FxId, active: Bool, x: Double, y: Double, depth: Double) {
        if !active {
            filter.bands[0].bypass = true
            delay.wetDryMix = 0
            return
        }
        filter.bands[0].bypass = false
        let wet = Float(15 + depth * 70)

        switch fx {
        case .filter:
            filter.bands[0].filterType = y > 0.5 ? .highPass : .lowPass
            filter.bands[0].frequency = Float(120 + pow(x, 2) * 14_000)
            filter.bands[0].bandwidth = Float(0.5 + y * 3)
            delay.wetDryMix = 0
        case .delay:
            delay.delayTime = 0.08 + x * 0.55
            delay.feedback = Float(15 + y * 60)
            delay.wetDryMix = wet
            filter.bands[0].bypass = true
        case .repeat:
            delay.delayTime = [0.0625, 0.125, 0.1875, 0.25][min(3, Int(x * 3.99))]
            delay.feedback = Float(50 + y * 40)
            delay.wetDryMix = wet
            filter.bands[0].bypass = true
        case .tape:
            filter.bands[0].filterType = .lowPass
            filter.bands[0].frequency = Float(2000 + (1 - y) * 8000)
            delay.delayTime = 0.02 + x * 0.08
            delay.feedback = 18
            delay.wetDryMix = 25
        case .tremolo:
            filter.bands[0].filterType = .parametric
            filter.bands[0].frequency = Float(800 + x * 2000)
            delay.wetDryMix = 8
        case .siren:
            filter.bands[0].filterType = .bandPass
            filter.bands[0].frequency = Float(200 + x * 3000)
            filter.bands[0].bandwidth = Float(0.2 + y * 0.6)
            delay.wetDryMix = 0
        }
    }

    private func configureGraph() {
        format = AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 2)
        filter.bands[0].bypass = true
        filter.bands[0].filterType = .lowPass
        filter.bands[0].frequency = 12_000
        delay.wetDryMix = 0
        delay.delayTime = 0.25
        delay.feedback = 25

        let source = makeCppSource()
        cppSource = source
        engine.attach(source)
        engine.attach(filter)
        engine.attach(delay)
        engine.connect(source, to: filter, format: format)
        engine.connect(filter, to: delay, format: format)
        engine.connect(delay, to: engine.mainMixerNode, format: format)
    }

    private func makeCppSource() -> AVAudioSourceNode {
        AVAudioSourceNode(format: format) { [weak self] _, _, frameCount, ablPtr -> OSStatus in
            guard let self else { return noErr }
            let frames = Int(frameCount)
            let needed = frames * 2
            guard needed <= self.cppScratch.count else { return noErr }
            self.cppScratch.withUnsafeMutableBufferPointer { buf in
                guard let base = buf.baseAddress else { return }
                _ = self.cppBridge.render(into: base, frames: UInt32(frames))
            }
            let abl = UnsafeMutableAudioBufferListPointer(ablPtr)
            if abl.count >= 2,
               let left = abl[0].mData?.assumingMemoryBound(to: Float.self),
               let right = abl[1].mData?.assumingMemoryBound(to: Float.self) {
                for i in 0..<frames {
                    left[i] = self.cppScratch[i * 2]
                    right[i] = self.cppScratch[i * 2 + 1]
                }
            } else if abl.count == 1, let data = abl[0].mData?.assumingMemoryBound(to: Float.self) {
                for i in 0..<needed {
                    data[i] = self.cppScratch[i]
                }
            }
            return noErr
        }
    }

    private func startIfNeeded() {
        guard !started else { return }
        started = true
        let warm = cppBridge.warmup()
        print("SideKit C++ \(cppBridge.version) warmup frames=\(warm.frames_rendered) t=\(warm.sample_time) silent=\(warm.peak == 0)")
        engine.prepare()
        try? engine.start()
    }
}
