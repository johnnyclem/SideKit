import Combine
import Foundation
import QuartzCore
import SwiftUI
import UIKit

@MainActor
final class MixerStore: ObservableObject {
    @Published var ch1: ChannelState
    @Published var ch2: ChannelState
    @Published var crossfader: Double = 0.5
    @Published var master: Double = 0.82
    @Published var cueMix: Double = 0.25
    @Published var headphone: Double = 0.70
    @Published var linked: Bool = false
    @Published var battery: Int = 78
    @Published var masterBpm: Double = 120
    @Published var beatMatch: Bool = true
    @Published var fx: FxId = .filter
    @Published var fxActive: Bool = false
    @Published var fxX: Double = 0.5
    @Published var fxY: Double = 0.5
    @Published var fxDepth: Double = 0.65
    @Published var fxSeries: Bool = true
    @Published var eqStyleGlobal: EqStyle = .dj
    @Published var tab: AppTab = .mixer
    @Published var libraryFilter: String = ""
    @Published var selectedTrackId: String? = "t6"
    @Published var loadTarget: Int = 1
    @Published var focusDeck: Int = 1
    @Published var meters: (ch1: Double, ch2: Double, master: Double) = (0, 0, 0)
    @Published var hardwareName: String?
    @Published var mixMode: MixMode = .internalMix
    @Published var decodeBanner: String?
    @Published var isDecoding = false
    @Published var peaksById: [String: PeakOverview] = [:]
    /// Real decoded length per track id. Demo metadata durations are placeholders; the
    /// bundled fixtures are short, so the deck shows what the engine actually has.
    @Published var clipDurations: [String: Double] = [:]
    @Published var showOnboarding: Bool = !UserDefaults.standard.bool(forKey: "sk.onboarded")
    @Published var showPaywall: Bool = false
    /// Mirrors `StoreManager.isPro` so views observing the store re-render on purchase.
    @Published private(set) var isPro: Bool

    enum MixMode: String, CaseIterable, Identifiable {
        case external = "External"
        case internalMix = "Internal"
        case midi = "MIDI"
        var id: String { rawValue }
    }

    /// Free tier (SK-044): Deck A, Filter + Delay, hardware link, library import.
    static let freeFx: Set<FxId> = [.filter, .delay]
    static let freePitchRange = Double(SK_PITCH_FREE_MAX)
    static let proPitchRange = Double(SK_PITCH_MAX)

    var maxPitch: Double { isPro ? Self.proPitchRange : Self.freePitchRange }

    private var displayLink: CADisplayLink?
    private let audio = AudioEngine.shared
    private let hardware = HardwareMonitor()
    private let ticker: DisplayTick
    private var cancellables = Set<AnyCancellable>()
    private var interrupted: Set<Int> = []

    let library = LibraryStore.shared
    let iap = StoreManager.shared
    let snapshots = SnapshotStore.shared
    let midi = MIDIManager.shared
    let usbMatrix = USBMatrixStore.shared

    init() {
        var a = ChannelState()
        a.trackId = "t6"
        a.bpm = 120
        a.fader = 0.78
        var b = ChannelState()
        b.trackId = "t3"
        b.bpm = 128
        b.fader = 0.72
        ch1 = a
        ch2 = b
        ticker = DisplayTick()
        isPro = StoreManager.shared.isPro

        hardware.onChange = { [weak self] info in
            Task { @MainActor in
                self?.applyHardware(info)
            }
        }
        hardware.start()
        ticker.store = self
        let link = CADisplayLink(target: ticker, selector: #selector(DisplayTick.tick))
        link.preferredFramesPerSecond = 60
        link.add(to: .main, forMode: .common)
        displayLink = link
        iap.$isPro
            .receive(on: RunLoop.main)
            .sink { [weak self] value in self?.isPro = value }
            .store(in: &cancellables)
        // Library edits (import / remove) must re-render views that read through the store.
        library.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        bindAudio()
        bindMIDI()
        Task { await prepareClip(ch: 1) }
    }

    // MARK: - Library lookups

    var displayBpm: Double {
        if ch1.playing { return ch1.effectiveBpm }
        if ch2.playing { return ch2.effectiveBpm }
        return masterBpm
    }

    var libraryTracks: [Track] {
        library.userTracks + DemoLibrary.tracks
    }

    func track(id: String?) -> Track? {
        guard let id else { return nil }
        return library.track(id: id) ?? DemoLibrary.track(id: id)
    }

    func track(_ ch: Int) -> Track? {
        track(id: ch == 1 ? ch1.trackId : ch2.trackId)
    }

    /// Decoded clip length when known, else the library metadata.
    func duration(for track: Track) -> Double {
        clipDurations[track.id] ?? track.duration
    }

    func peaks(for trackId: String?) -> PeakOverview? {
        guard let trackId else { return nil }
        return peaksById[trackId]
    }

    // MARK: - Mixer

    func setEqStyle(_ style: EqStyle) {
        eqStyleGlobal = style
        ch1.eqStyle = style
        ch2.eqStyle = style
        pushAudio()
    }

    func updateChannel(_ ch: Int, _ patch: (inout ChannelState) -> Void) {
        if ch == 1 { patch(&ch1) } else { patch(&ch2) }
        pushAudio()
    }

    func setPitch(_ ch: Int, _ percent: Double) {
        let clamped = min(maxPitch, max(-maxPitch, percent))
        updateChannel(ch) { $0.pitch = clamped }
    }

    // MARK: - Transport

    func seekDeck(_ ch: Int, _ pos: Double) {
        let clamped = min(1, max(0, pos))
        if ch == 1 { ch1.deckPos = clamped } else { ch2.deckPos = clamped }
        audio.seekClip(ch: ch, normalized: clamped)
    }

    func restartDeck(_ ch: Int) {
        if ch == 1 { ch1.deckPos = 0 } else { ch2.deckPos = 0 }
        audio.restart(ch: ch)
    }

    func togglePlay(_ ch: Int) {
        guard ch == 1 || isPro else {
            showPaywall = true
            return
        }
        if ch == 1 { ch1.playing.toggle() } else { ch2.playing.toggle() }
        Task {
            await audio.unlock()
            await prepareClip(ch: ch)
            pushAudio()
        }
    }

    func loadTrack(ch: Int, id: String) {
        guard ch == 1 || isPro else {
            showPaywall = true
            return
        }
        guard let track = track(id: id) else { return }
        selectedTrackId = id
        updateChannel(ch) { state in
            state.trackId = id
            state.bpm = track.bpm
            state.pitch = 0
            state.deckPos = 0
            state.playing = false
            state.source = .deck
            state.hotCues = [nil, nil, nil, nil]
            state.loopActive = false
        }
        if ch == 1 || beatMatch {
            masterBpm = track.bpm
        }
        Task { await prepareClip(ch: ch) }
    }

    func syncBpm(from ch: Int) {
        let src = ch == 1 ? ch1 : ch2
        let dstBase = ch == 1 ? ch2.bpm : ch1.bpm
        guard src.trackId != nil else { return }
        let target = src.effectiveBpm
        let pitch = max(-maxPitch, min(maxPitch, (target / max(dstBase, 1) - 1) * 100))
        if ch == 1 { ch2.pitch = pitch } else { ch1.pitch = pitch }
        masterBpm = target
        beatMatch = true
        pushAudio()
    }

    // MARK: - Hot cues + loops (SK-034, Pro-gated per SK-046)

    func setHotCue(_ ch: Int, slot: Int) {
        guard isPro || slot == 0 else {
            showPaywall = true
            return
        }
        let state = ch == 1 ? ch1 : ch2
        guard let tr = track(id: state.trackId) else { return }
        let pos = state.deckPos * duration(for: tr)
        updateChannel(ch) { $0.hotCues[slot] = pos }
    }

    func jumpToHotCue(_ ch: Int, slot: Int) {
        let state = ch == 1 ? ch1 : ch2
        guard let cue = state.hotCues[slot], let tr = track(id: state.trackId) else { return }
        let dur = duration(for: tr)
        guard dur > 0 else { return }
        let pos = min(1, max(0, cue / dur))
        if ch == 1 { ch1.deckPos = pos } else { ch2.deckPos = pos }
        audio.seekSeconds(ch: ch, seconds: cue)
    }

    func clearHotCue(_ ch: Int, slot: Int) {
        updateChannel(ch) { $0.hotCues[slot] = nil }
    }

    /// Loop in at the nearest beat (track BPM grid from clip start), auto length in beats.
    func toggleLoop(_ ch: Int) {
        guard isPro else {
            showPaywall = true
            return
        }
        let state = ch == 1 ? ch1 : ch2
        if state.loopActive {
            updateChannel(ch) { $0.loopActive = false }
            pushLoop(ch)
            return
        }
        guard audio.transportState(ch: ch).loaded != 0, let tr = track(id: state.trackId) else {
            decodeBanner = "Loops need a decoded clip. Load a file or a bundled demo track."
            return
        }
        let dur = duration(for: tr)
        guard dur > 0 else { return }
        var start = Tempo.quantize(state.deckPos * dur, bpm: state.bpm)
        start = max(0, min(start, dur - state.loopLengthSec))
        updateChannel(ch) {
            $0.loopActive = true
            $0.loopStartSec = start
        }
        pushLoop(ch)
    }

    func nudgeLoopLength(_ ch: Int, doubled: Bool) {
        updateChannel(ch) { state in
            let next = doubled ? state.loopLengthBeats * 2 : state.loopLengthBeats / 2
            state.loopLengthBeats = Tempo.nearestAutoLoopLength(max(0.25, min(32, next)))
        }
        pushLoop(ch)
    }

    private func pushLoop(_ ch: Int) {
        let state = ch == 1 ? ch1 : ch2
        audio.setLoop(ch: ch, enabled: state.loopActive, startSec: state.loopStartSec, lengthSec: state.loopLengthSec)
    }

    // MARK: - FX pad

    func selectFx(_ item: FxId) {
        guard isPro || Self.freeFx.contains(item) else {
            showPaywall = true
            return
        }
        fx = item
        pushFx()
    }

    func setFxPad(x: Double, y: Double) {
        fxX = min(1, max(0, x))
        fxY = min(1, max(0, y))
        pushFx()
    }

    // MARK: - Link / hardware

    func setLinked(_ value: Bool) {
        linked = value
    }

    private func applyHardware(_ info: HardwareMonitor.Info) {
        hardwareName = info.deviceName
        if info.sidekickLikely { linked = true }
    }

    // MARK: - Import + decode

    func dismissDecodeBanner() {
        decodeBanner = nil
    }

    func importURLs(_ urls: [URL]) {
        Task { await importURLsAsync(urls) }
    }

    private func importURLsAsync(_ urls: [URL]) async {
        isDecoding = true
        defer { isDecoding = false }
        for url in urls {
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            do {
                if !FileDecoder.isSupported(url: url) {
                    throw FileDecodeError.unsupportedCodec(".\(url.pathExtension.lowercased())")
                }
                let dest = try LibraryStore.persistImport(url)
                let clip = try await audio.decodeFile(url: dest)
                let analysis = await BPMAnalyzer.analyze(url: dest, clip: clip)
                let item = Track(
                    id: UUID().uuidString,
                    title: url.deletingPathExtension().lastPathComponent,
                    artist: clip.resampled ? "Imported · 48 kHz" : "Imported",
                    bpm: analysis.bpm ?? 120,
                    key: "—",
                    duration: clip.duration,
                    pattern: .kick,
                    fileURL: dest,
                    resampled: clip.resampled,
                    isImported: true,
                    bpmIsEstimated: analysis.estimated
                )
                library.add(item)
                peaksById[item.id] = PeakCache.resolve(audioURL: dest, pcm: clip.pcm, frames: clip.frames)
                clipDurations[item.id] = clip.duration
                selectedTrackId = item.id
                decodeBanner = nil
                loadTrack(ch: loadTarget, id: item.id, preDecoded: clip)
            } catch {
                decodeBanner = error.localizedDescription
            }
        }
    }

    func removeTrack(id: String) {
        for ch in [1, 2] where (ch == 1 ? ch1.trackId : ch2.trackId) == id {
            updateChannel(ch) { state in
                state.trackId = nil
                state.playing = false
                state.deckPos = 0
                state.loopActive = false
                state.hotCues = [nil, nil, nil, nil]
            }
            audio.clearClip(ch: ch)
        }
        library.remove(id: id)
        peaksById.removeValue(forKey: id)
        clipDurations.removeValue(forKey: id)
        if selectedTrackId == id { selectedTrackId = nil }
    }

    /// Same as `loadTrack(ch:id:)` but reuses an already decoded clip (import path).
    private func loadTrack(ch: Int, id: String, preDecoded: DecodedClip) {
        guard ch == 1 || isPro else {
            showPaywall = true
            return
        }
        guard let track = track(id: id) else { return }
        updateChannel(ch) { state in
            state.trackId = id
            state.bpm = track.bpm
            state.pitch = 0
            state.deckPos = 0
            state.playing = false
            state.source = .deck
            state.hotCues = [nil, nil, nil, nil]
            state.loopActive = false
        }
        if ch == 1 || beatMatch {
            masterBpm = track.bpm
        }
        _ = audio.loadDecodedClip(ch: ch, clip: preDecoded)
    }

    func prepareClip(ch: Int) async {
        let state = ch == 1 ? ch1 : ch2
        guard let tr = track(id: state.trackId) else { return }
        let url = tr.fileURL ?? BundledAudio.url(for: tr.id)
        guard let url else {
            audio.clearClip(ch: ch)
            return
        }
        isDecoding = true
        defer { isDecoding = false }
        do {
            let clip = try await audio.decodeFile(url: url)
            _ = audio.loadDecodedClip(ch: ch, clip: clip)
            let overview = PeakCache.resolve(audioURL: url, pcm: clip.pcm, frames: clip.frames)
            if tr.isImported {
                library.update(id: tr.id) { item in
                    item.duration = clip.duration
                    item.resampled = clip.resampled
                }
            }
            clipDurations[tr.id] = clip.duration
            peaksById[tr.id] = overview
            decodeBanner = nil
        } catch {
            decodeBanner = error.localizedDescription
            audio.clearClip(ch: ch)
        }
    }

    // MARK: - Audio binding

    private func bindAudio() {
        audio.onInterruption = { [weak self] event in
            Task { @MainActor in
                self?.handleInterruption(event)
            }
        }
        pushAudio()
        pushFx()
    }

    /// SK-015: a call or Siri pauses whatever was playing; `.ended(shouldResume: true)`
    /// brings exactly those decks back.
    private func handleInterruption(_ event: AudioEngine.InterruptionEvent) {
        switch event {
        case .began:
            interrupted = []
            if ch1.playing {
                interrupted.insert(1)
                ch1.playing = false
            }
            if ch2.playing {
                interrupted.insert(2)
                ch2.playing = false
            }
            pushAudio()
        case .ended(let shouldResume):
            if shouldResume {
                if interrupted.contains(1) { ch1.playing = true }
                if interrupted.contains(2) { ch2.playing = true }
                pushAudio()
            }
            interrupted = []
        }
    }

    private func bindMIDI() {
        midi.onControlChange = { [weak self] binding, raw in
            Task { @MainActor in self?.applyMIDI(binding, raw: raw) }
        }
        midi.start()
    }

    private func applyMIDI(_ binding: MIDIBinding, raw: Int) {
        let value = binding.scale(raw)
        switch binding.targetId {
        case "ch1.gain": updateChannel(1) { $0.gain = value * 24 }
        case "ch1.eqHi": updateChannel(1) { $0.eqHi = value }
        case "ch1.eqMid": updateChannel(1) { $0.eqMid = value }
        case "ch1.eqLo": updateChannel(1) { $0.eqLo = value }
        case "ch1.fader": updateChannel(1) { $0.fader = value }
        case "ch2.gain": updateChannel(2) { $0.gain = value * 24 }
        case "ch2.eqHi": updateChannel(2) { $0.eqHi = value }
        case "ch2.eqMid": updateChannel(2) { $0.eqMid = value }
        case "ch2.eqLo": updateChannel(2) { $0.eqLo = value }
        case "ch2.fader": updateChannel(2) { $0.fader = value }
        case "xf":
            crossfader = value
            pushAudio()
        case "fx.x":
            fxX = value
            pushFx()
        case "fx.y":
            fxY = value
            pushFx()
        case "fx.depth":
            fxDepth = value
            pushFx()
        case "fx.engage":
            fxActive.toggle()
            pushFx()
        default:
            break
        }
    }

    func pushAudio() {
        audio.applyChannel(1, ch1, xf: crossfader, master: master)
        audio.applyChannel(2, ch2, xf: crossfader, master: master)
        audio.setMaster(master)
        audio.setChannelPlaying(1, ch1.playing && ch1.source == .deck, track(1), bpm: ch1.effectiveBpm)
        audio.setChannelPlaying(2, ch2.playing && ch2.source == .deck, track(2), bpm: ch2.effectiveBpm)
        pushFx()
    }

    func pushFx() {
        audio.applyFx(fx, active: fxActive, x: fxX, y: fxY, depth: fxDepth)
    }

    /// 60 fps: clip decks mirror the engine playhead; pattern decks simulate position.
    func advanceDecks(_ dt: Double) {
        func step(_ index: Int, _ ch: inout ChannelState) {
            let st = audio.transportState(ch: index)
            if st.loaded != 0, st.frames > 0 {
                ch.deckPos = Double(st.playhead) / Double(st.frames)
                if st.playing == 0 {
                    ch.playing = false
                }
                return
            }
            guard ch.playing, let track = track(id: ch.trackId) else { return }
            let rate = 1 + ch.pitch / 100
            let next = ch.deckPos + (dt * rate) / track.duration
            ch.deckPos = next >= 1 ? 0 : next
        }
        step(1, &ch1)
        step(2, &ch2)
        meters = audio.readMeters()
    }

    // MARK: - Onboarding (SK-048)

    func completeOnboarding() {
        showOnboarding = false
        UserDefaults.standard.set(true, forKey: "sk.onboarded")
    }

    // MARK: - Scenes (SK-043)

    func saveSnapshot(named name: String) {
        guard isPro else {
            showPaywall = true
            return
        }
        let snap = MixerSnapshot(
            name: name,
            createdAt: Date().timeIntervalSince1970,
            ch1Gain: ch1.gain, ch1EqHi: ch1.eqHi, ch1EqMid: ch1.eqMid, ch1EqLo: ch1.eqLo, ch1Fader: ch1.fader,
            ch2Gain: ch2.gain, ch2EqHi: ch2.eqHi, ch2EqMid: ch2.eqMid, ch2EqLo: ch2.eqLo, ch2Fader: ch2.fader,
            crossfader: crossfader,
            master: master,
            fx: fx.rawValue,
            fxDepth: fxDepth
        )
        snapshots.save(snap)
    }

    func recallSnapshot(_ snap: MixerSnapshot) {
        ch1.gain = snap.ch1Gain
        ch1.eqHi = snap.ch1EqHi
        ch1.eqMid = snap.ch1EqMid
        ch1.eqLo = snap.ch1EqLo
        ch1.fader = snap.ch1Fader
        ch2.gain = snap.ch2Gain
        ch2.eqHi = snap.ch2EqHi
        ch2.eqMid = snap.ch2EqMid
        ch2.eqLo = snap.ch2EqLo
        ch2.fader = snap.ch2Fader
        crossfader = snap.crossfader
        master = snap.master
        if let id = FxId(rawValue: snap.fx) { fx = id }
        fxDepth = snap.fxDepth
        pushAudio()
    }
}

final class DisplayTick: NSObject {
    weak var store: MixerStore?
    private var last: CFTimeInterval = CACurrentMediaTime()

    @objc func tick() {
        let now = CACurrentMediaTime()
        let dt = min(0.1, now - last)
        last = now
        Task { @MainActor in
            store?.advanceDecks(dt)
        }
    }
}
