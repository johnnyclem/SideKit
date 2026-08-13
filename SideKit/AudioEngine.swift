import AVFoundation
import Foundation
import QuartzCore

/// Dual-deck engine + mixer / FX graph (AVAudioEngine).
///
/// Two playback modes per channel:
///  - **Pattern** (demo library tracks, no bundled audio assets shipped yet): synthesized
///    step-sequenced hits, unchanged from the original prototype.
///  - **File** (SK-010/011/012/013/015, user-imported tracks): real `AVAudioFile` playback
///    scheduled via `scheduleSegment`, with `AVAudioUnitVarispeed` driving the vinyl-style
///    pitch/tempo fader (SK-012) and a 25 ms scheduler tick handling seek-based looping (SK-034).
///
/// A third source, the C++ `SideKitAudio` static lib (SK-001), is pulled every render
/// quantum via an `AVAudioSourceNode` mixed into `dryMixer` alongside the two decks —
/// today it renders silence (hello callback / warmup only); SK-004 will move real DSP
/// into it.
final class AudioEngine {
    static let shared = AudioEngine()

    var onMeters: ((Double, Double, Double) -> Void)?
    /// Fires ~40 Hz with the real playback position (0...1) for file-backed decks only.
    var onDeckPosition: ((Int, Double) -> Void)?
    /// Fires when a loop wraps (SK-034), so the UI can flash the loop indicator.
    var onLoopWrapped: ((Int) -> Void)?
    /// Fires when an interruption (SK-015, e.g. a phone call) forces a channel to pause
    /// or resume, so the UI transport button can mirror the engine's real state.
    var onForcedPlaybackChange: ((Int, Bool) -> Void)?
    var cppCoreVersion: String { cppBridge.version }

    private let engine = AVAudioEngine()
    private let ch1Player = AVAudioPlayerNode()
    private let ch2Player = AVAudioPlayerNode()
    private let ch1Varispeed = AVAudioUnitVarispeed()
    private let ch2Varispeed = AVAudioUnitVarispeed()
    private let ch1Mixer = AVAudioMixerNode()
    private let ch2Mixer = AVAudioMixerNode()
    private let dryMixer = AVAudioMixerNode()
    private let filter = AVAudioUnitEQ(numberOfBands: 1)
    private let delay = AVAudioUnitDelay()
    private let ch1EQ = AVAudioUnitEQ(numberOfBands: 3)
    private let ch2EQ = AVAudioUnitEQ(numberOfBands: 3)

    private var format: AVAudioFormat!
    private var started = false
    private let queue = DispatchQueue(label: "com.sidekit.audio", qos: .userInteractive)

    private enum DeckMode { case pattern, file }

    private struct Voice {
        var active = false
        var pattern: Pattern = .kick
        var bpm: Double = 120
        var nextNote: Double = 0
        var step: Int = 0
    }

    private struct FileDeck {
        var file: AVAudioFile?
        var sampleRate: Double = 48_000
        var totalFrames: AVAudioFramePosition = 0
        var duration: Double = 0
        var playing = false
        var rate: Double = 1
        var startFrame: AVAudioFramePosition = 0
        var startHost: CFTimeInterval = 0
        var loopActive = false
        var loopStartSec: Double = 0
        var loopLenSec: Double = 0

        func currentSeconds(now: CFTimeInterval) -> Double {
            guard duration > 0 else { return 0 }
            let sec = Double(startFrame) / sampleRate + (playing ? (now - startHost) * rate : 0)
            return min(duration, max(0, sec))
        }
    }

    private var mode1: DeckMode = .pattern
    private var mode2: DeckMode = .pattern
    private var v1 = Voice()
    private var v2 = Voice()
    private var d1 = FileDeck()
    private var d2 = FileDeck()
    private var timer: DispatchSourceTimer?
    private var meter1: Double = 0
    private var meter2: Double = 0
    private var meterM: Double = 0

    private var interruptedChannels: Set<Int> = []

    private let cppBridge = SKAudioBridge.shared
    private var cppScratch = [Float](repeating: 0, count: 4096)
    private var cppSource: AVAudioSourceNode?

    private init() {
        configureGraph()
        observeInterruptions()
    }

    /// SK-015: "Interruption (call) pauses and resumes cleanly." Route-change UI updates
    /// are handled separately by `HardwareMonitor`.
    private func observeInterruptions() {
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification, object: nil, queue: .main
        ) { [weak self] note in
            guard let self,
                  let info = note.userInfo,
                  let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }
            switch type {
            case .began:
                self.handleInterruptionBegan()
            case .ended:
                let optionsValue = info[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
                let shouldResume = AVAudioSession.InterruptionOptions(rawValue: optionsValue).contains(.shouldResume)
                self.handleInterruptionEnded(shouldResume: shouldResume)
            @unknown default:
                break
            }
        }
    }

    /// All reads/writes of `mode1/2`, `d1/2`, `v1/2` are confined to `queue` — these two
    /// handlers hop onto it explicitly since the interruption notification fires on `.main`.
    private func handleInterruptionBegan() {
        queue.async { [weak self] in
            guard let self else { return }
            for ch in [1, 2] {
                let mode = ch == 1 ? self.mode1 : self.mode2
                let playing = mode == .file ? (ch == 1 ? self.d1.playing : self.d2.playing) : (ch == 1 ? self.v1.active : self.v2.active)
                guard playing else { continue }
                self.interruptedChannels.insert(ch)
                if mode == .file {
                    self.pauseFile(ch)
                } else {
                    if ch == 1 { self.v1.active = false } else { self.v2.active = false }
                }
                DispatchQueue.main.async { self.onForcedPlaybackChange?(ch, false) }
            }
        }
    }

    private func handleInterruptionEnded(shouldResume: Bool) {
        try? AVAudioSession.sharedInstance().setActive(true)
        queue.async { [weak self] in
            guard let self else { return }
            guard shouldResume else { self.interruptedChannels.removeAll(); return }
            for ch in self.interruptedChannels {
                let mode = ch == 1 ? self.mode1 : self.mode2
                if mode == .file {
                    self.playFile(ch)
                } else {
                    var voice = ch == 1 ? self.v1 : self.v2
                    voice.active = true
                    voice.nextNote = CACurrentMediaTime() + 0.05
                    if ch == 1 { self.v1 = voice } else { self.v2 = voice }
                    self.startScheduler()
                }
                DispatchQueue.main.async { self.onForcedPlaybackChange?(ch, true) }
            }
            self.interruptedChannels.removeAll()
        }
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
        engine.mainMixerNode.outputVolume = Float(max(0, min(1, level * 0.9)))
    }

    // MARK: - Load / mode switch

    /// Called when a track loads into a deck (SK-010/011). Switches the channel between
    /// pattern and file playback and resets transport state.
    func loadTrack(_ ch: Int, url: URL?, duration: Double) {
        queue.async { [weak self] in
            guard let self else { return }
            self.stopChannel(ch)
            if let url, let file = try? AVAudioFile(forReading: url) {
                var deck = FileDeck()
                deck.file = file
                deck.sampleRate = file.processingFormat.sampleRate
                deck.totalFrames = file.length
                deck.duration = duration > 0 ? duration : Double(file.length) / deck.sampleRate
                if ch == 1 { self.d1 = deck; self.mode1 = .file } else { self.d2 = deck; self.mode2 = .file }
            } else {
                if ch == 1 { self.mode1 = .pattern } else { self.mode2 = .pattern }
            }
        }
    }

    private func stopChannel(_ ch: Int) {
        let player = ch == 1 ? ch1Player : ch2Player
        player.stop()
        if ch == 1 { d1.playing = false; v1.active = false } else { d2.playing = false; v2.active = false }
    }

    // MARK: - Transport (pattern + file, unified entry points from MixerStore)

    func setChannelPlaying(_ ch: Int, _ playing: Bool, _ track: Track?, bpm: Double) {
        queue.async { [weak self] in
            guard let self else { return }
            let isFile = ch == 1 ? self.mode1 == .file : self.mode2 == .file
            if isFile {
                if playing { self.playFile(ch) } else { self.pauseFile(ch) }
                return
            }
            var voice = ch == 1 ? self.v1 : self.v2
            voice.active = playing && track != nil
            voice.pattern = track?.pattern ?? .kick
            voice.bpm = bpm
            if playing {
                voice.nextNote = CACurrentMediaTime() + 0.05
                voice.step = 0
                self.startScheduler()
            }
            if ch == 1 { self.v1 = voice } else { self.v2 = voice }
        }
    }

    /// Seek as a 0...1 fraction of track duration. No-op for pattern decks.
    func seek(_ ch: Int, toFraction fraction: Double) {
        queue.async { [weak self] in
            guard let self else { return }
            let duration = ch == 1 ? self.d1.duration : self.d2.duration
            guard duration > 0 else { return }
            self.seekFileSeconds(ch, min(duration, max(0, fraction * duration)))
        }
    }

    func setRate(_ ch: Int, ratePercent pitch: Double) {
        let rate = 1 + pitch / 100
        queue.async { [weak self] in
            guard let self else { return }
            let isFile = ch == 1 ? self.mode1 == .file : self.mode2 == .file
            guard isFile else { return }
            let now = CACurrentMediaTime()
            if ch == 1 {
                let sec = self.d1.currentSeconds(now: now)
                self.d1.startFrame = AVAudioFramePosition(sec * self.d1.sampleRate)
                self.d1.startHost = now
                self.d1.rate = rate
            } else {
                let sec = self.d2.currentSeconds(now: now)
                self.d2.startFrame = AVAudioFramePosition(sec * self.d2.sampleRate)
                self.d2.startHost = now
                self.d2.rate = rate
            }
            DispatchQueue.main.async {
                (ch == 1 ? self.ch1Varispeed : self.ch2Varispeed).rate = Float(max(0.25, min(4, rate)))
            }
        }
    }

    func setLoop(_ ch: Int, active: Bool, startSec: Double, lengthSec: Double) {
        queue.async { [weak self] in
            guard let self else { return }
            if ch == 1 {
                self.d1.loopActive = active; self.d1.loopStartSec = startSec; self.d1.loopLenSec = lengthSec
            } else {
                self.d2.loopActive = active; self.d2.loopStartSec = startSec; self.d2.loopLenSec = lengthSec
            }
        }
    }

    private func playFile(_ ch: Int) {
        var deck = ch == 1 ? d1 : d2
        guard let file = deck.file, deck.totalFrames > 0 else { return }
        let player = ch == 1 ? ch1Player : ch2Player
        let startFrame = min(deck.startFrame, deck.totalFrames - 1)
        let remaining = AVAudioFrameCount(max(0, deck.totalFrames - startFrame))
        guard remaining > 0 else { return }
        player.stop()
        player.scheduleSegment(file, startingFrame: startFrame, frameCount: remaining, at: nil, completionCallbackType: .dataPlayedBack) { [weak self] _ in
            self?.queue.async {
                guard let self else { return }
                let stillPlaying = ch == 1 ? self.d1.playing : self.d2.playing
                let loop = ch == 1 ? self.d1.loopActive : self.d2.loopActive
                if stillPlaying && !loop {
                    if ch == 1 { self.d1.playing = false } else { self.d2.playing = false }
                }
            }
        }
        startIfNeeded()
        player.play()
        deck.playing = true
        deck.startHost = CACurrentMediaTime()
        if ch == 1 { d1 = deck } else { d2 = deck }
        startScheduler()
    }

    private func pauseFile(_ ch: Int) {
        let now = CACurrentMediaTime()
        let player = ch == 1 ? ch1Player : ch2Player
        var deck = ch == 1 ? d1 : d2
        let sec = deck.currentSeconds(now: now)
        player.stop()
        deck.startFrame = AVAudioFramePosition(sec * deck.sampleRate)
        deck.playing = false
        if ch == 1 { d1 = deck } else { d2 = deck }
    }

    private func seekFileSeconds(_ ch: Int, _ seconds: Double) {
        var deck = ch == 1 ? d1 : d2
        deck.startFrame = AVAudioFramePosition(seconds * deck.sampleRate)
        deck.startHost = CACurrentMediaTime()
        let wasPlaying = deck.playing
        if ch == 1 { d1 = deck } else { d2 = deck }
        if wasPlaying { playFile(ch) }
    }

    func applyChannel(_ ch: Int, _ state: ChannelState, xf: Double, master: Double) {
        let x = ch == 1 ? (1 - xf) : xf
        let (xfGain, _) = Tempo.equalPowerCrossfade(1 - x)
        let mute = state.mute ? 0.0 : 1.0
        let lin = pow(10.0, state.gain / 20.0)
        let level = state.fader * lin * xfGain * mute * 0.55

        let mixer = ch == 1 ? ch1Mixer : ch2Mixer
        mixer.outputVolume = Float(max(0, level))

        let styleMul: Double = state.eqStyle == .dj ? 18 : state.eqStyle == .studio ? 12 : 15
        let eq = ch == 1 ? ch1EQ : ch2EQ
        eq.bands[0].gain = Float(state.eqLo * styleMul)
        eq.bands[1].gain = Float(state.eqMid * styleMul * 0.7)
        eq.bands[2].gain = Float(state.eqHi * styleMul)

        queue.async {
            if ch == 1 { self.v1.bpm = state.effectiveBpm } else { self.v2.bpm = state.effectiveBpm }
        }
        setRate(ch, ratePercent: state.pitch)
        setLoop(ch, active: state.loopActive, startSec: state.loopStartSec, lengthSec: Tempo.beatsToSeconds(state.loopLengthBeats, bpm: state.effectiveBpm))
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

        configureEQ(ch1EQ)
        configureEQ(ch2EQ)
        filter.bands[0].bypass = true
        filter.bands[0].filterType = .lowPass
        filter.bands[0].frequency = 12_000
        delay.wetDryMix = 0
        delay.delayTime = 0.25
        delay.feedback = 25
        dryMixer.outputVolume = 1
        ch1Varispeed.rate = 1
        ch2Varispeed.rate = 1

        [ch1Player, ch2Player, ch1Varispeed, ch2Varispeed, ch1Mixer, ch2Mixer, dryMixer, filter, delay, ch1EQ, ch2EQ]
            .forEach { engine.attach($0) }

        let source = makeCppSource()
        cppSource = source
        engine.attach(source)

        engine.connect(ch1Player, to: ch1Varispeed, format: format)
        engine.connect(ch1Varispeed, to: ch1EQ, format: format)
        engine.connect(ch1EQ, to: ch1Mixer, format: format)
        engine.connect(ch2Player, to: ch2Varispeed, format: format)
        engine.connect(ch2Varispeed, to: ch2EQ, format: format)
        engine.connect(ch2EQ, to: ch2Mixer, format: format)
        engine.connect(ch1Mixer, to: dryMixer, format: format)
        engine.connect(ch2Mixer, to: dryMixer, format: format)
        engine.connect(source, to: dryMixer, format: format)
        engine.connect(dryMixer, to: filter, format: format)
        engine.connect(filter, to: delay, format: format)
        engine.connect(delay, to: engine.mainMixerNode, format: format)

        installMeter(ch1Mixer, slot: 1)
        installMeter(ch2Mixer, slot: 2)
        installMeter(engine.mainMixerNode, slot: 0)
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

    private func configureEQ(_ eq: AVAudioUnitEQ) {
        eq.bands[0].filterType = .lowShelf
        eq.bands[0].frequency = 250
        eq.bands[0].bypass = false
        eq.bands[1].filterType = .parametric
        eq.bands[1].frequency = 1000
        eq.bands[1].bandwidth = 1.0
        eq.bands[1].bypass = false
        eq.bands[2].filterType = .highShelf
        eq.bands[2].frequency = 4000
        eq.bands[2].bypass = false
    }

    private func installMeter(_ node: AVAudioNode, slot: Int) {
        node.installTap(onBus: 0, bufferSize: 256, format: format) { [weak self] buffer, _ in
            guard let data = buffer.floatChannelData?[0] else { return }
            let n = Int(buffer.frameLength)
            var sum: Float = 0
            for i in 0..<n {
                let v = data[i]
                sum += v * v
            }
            let rms = Double(sqrt(sum / Float(max(n, 1)))) * 3.2
            let clipped = min(1, rms)
            DispatchQueue.main.async {
                guard let self else { return }
                switch slot {
                case 1: self.meter1 = clipped
                case 2: self.meter2 = clipped
                default: self.meterM = clipped
                }
                self.onMeters?(self.meter1, self.meter2, self.meterM)
            }
        }
    }

    private func startIfNeeded() {
        guard !started else { return }
        started = true
        let warm = cppBridge.warmup()
        print("SideKit C++ \(cppBridge.version) warmup frames=\(warm.frames_rendered) t=\(warm.sample_time)")
        engine.prepare()
        try? engine.start()
        ch1Player.play()
        ch2Player.play()
    }

    private func startScheduler() {
        if timer != nil { return }
        let t = DispatchSource.makeTimerSource(queue: queue)
        t.schedule(deadline: .now(), repeating: .milliseconds(25))
        t.setEventHandler { [weak self] in
            self?.tick()
        }
        t.resume()
        timer = t
    }

    private func tick() {
        let now = CACurrentMediaTime()
        scheduleVoice(&v1, player: ch1Player, now: now)
        scheduleVoice(&v2, player: ch2Player, now: now)
        tickFileDeck(1, now: now)
        tickFileDeck(2, now: now)
    }

    private func tickFileDeck(_ ch: Int, now: CFTimeInterval) {
        var deck = ch == 1 ? d1 : d2
        guard deck.playing, deck.duration > 0 else { return }
        let sec = deck.currentSeconds(now: now)

        if deck.loopActive, deck.loopLenSec > 0 {
            let loopEnd = deck.loopStartSec + deck.loopLenSec
            if sec >= loopEnd {
                seekFileSeconds(ch, deck.loopStartSec)
                DispatchQueue.main.async { [weak self] in self?.onLoopWrapped?(ch) }
                return
            }
        }
        if sec >= deck.duration - 0.02 {
            deck.playing = false
            if ch == 1 { d1 = deck } else { d2 = deck }
        }

        let fraction = deck.duration > 0 ? sec / deck.duration : 0
        DispatchQueue.main.async { [weak self] in self?.onDeckPosition?(ch, fraction) }
    }

    private func scheduleVoice(_ voice: inout Voice, player: AVAudioPlayerNode, now: Double) {
        guard voice.active else { return }
        let spb = 60.0 / max(40, voice.bpm) / 4.0
        let look: Double = 0.12
        while voice.nextNote < now + look {
            playStep(voice.pattern, step: voice.step % 16, player: player)
            voice.nextNote += spb
            voice.step += 1
        }
    }

    private func playStep(_ pattern: Pattern, step: Int, player: AVAudioPlayerNode) {
        func hit(_ freq: Double, dur: Double, gain: Double, noise: Bool = false, wave: OscillatorKind = .sine) {
            guard let buf = makeHit(freq: freq, dur: dur, gain: gain, noise: noise, kind: wave) else { return }
            player.scheduleBuffer(buf, completionHandler: nil)
        }

        switch pattern {
        case .kick:
            if step % 4 == 0 { hit(55, dur: 0.22, gain: 0.55) }
            if step == 4 || step == 12 { hit(180, dur: 0.08, gain: 0.18, noise: true, wave: .tri) }
            if step % 2 == 1 { hit(8000, dur: 0.03, gain: 0.04, noise: true) }
        case .bass:
            if step % 4 == 0 || step == 6 || step == 10 {
                let notes = [55.0, 55, 65.4, 73.4, 82.4, 55, 73.4, 65.4]
                hit(notes[step % 8], dur: 0.18, gain: 0.22, wave: .saw)
            }
            if step % 8 == 4 { hit(90, dur: 0.12, gain: 0.15) }
        case .hat:
            if step % 2 == 0 { hit(9000, dur: 0.04, gain: 0.08, noise: true) }
            if step % 4 == 2 { hit(12000, dur: 0.03, gain: 0.05, noise: true) }
            if step == 0 || step == 8 { hit(60, dur: 0.18, gain: 0.35) }
        case .breakbeat:
            if [0, 3, 6, 8, 11, 14].contains(step) { hit(50, dur: 0.16, gain: 0.45) }
            if [4, 12].contains(step) { hit(200, dur: 0.10, gain: 0.25, noise: true, wave: .tri) }
            if step % 2 == 1 { hit(7000, dur: 0.025, gain: 0.06, noise: true) }
        case .synth:
            if [0, 3, 7, 10, 12].contains(step) {
                let chord = [220.0, 277, 330, 392]
                hit(chord[step % 4], dur: 0.25, gain: 0.14, wave: .tri)
            }
            if step % 8 == 0 { hit(55, dur: 0.2, gain: 0.3) }
        }
    }

    private enum OscillatorKind { case sine, saw, tri }

    private func makeHit(freq: Double, dur: Double, gain: Double, noise: Bool, kind: OscillatorKind) -> AVAudioPCMBuffer? {
        guard let format else { return nil }
        let sr = format.sampleRate
        let frames = AVAudioFrameCount(max(32, dur * sr))
        guard let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames) else { return nil }
        buf.frameLength = frames
        let n = Int(frames)
        guard let l = buf.floatChannelData?[0], let r = buf.floatChannelData?[1] else { return nil }
        for i in 0..<n {
            let t = Double(i) / sr
            let env = exp(-t / max(0.02, dur * 0.45))
            var s: Double
            if noise {
                s = Double.random(in: -1...1)
            } else {
                let ph = 2 * Double.pi * freq * t
                switch kind {
                case .sine: s = sin(ph)
                case .saw: s = 2 * ((freq * t).truncatingRemainder(dividingBy: 1)) - 1
                case .tri: s = abs(2 * ((freq * t).truncatingRemainder(dividingBy: 1)) - 1) * 2 - 1
                }
                if freq < 100 {
                    let drop = freq * (1 - 0.6 * min(1, t / dur))
                    s = sin(2 * Double.pi * drop * t)
                }
            }
            let v = Float(s * env * gain)
            l[i] = v
            r[i] = v
        }
        return buf
    }
}
