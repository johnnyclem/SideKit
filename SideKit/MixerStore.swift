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
    @Published var meters: (ch1: Double, ch2: Double, master: Double) = (0, 0, 0)
    @Published var hardwareName: String?
    @Published var mixMode: MixMode = .internalMix
    @Published var loopFlash: Int?
    @Published var showOnboarding: Bool = !UserDefaults.standard.bool(forKey: "sk.onboarded")
    @Published var showPaywall: Bool = false

    enum MixMode: String, CaseIterable, Identifiable {
        case external = "External"
        case internalMix = "Internal"
        case midi = "MIDI"
        var id: String { rawValue }
    }

    private var displayLink: CADisplayLink?
    private let audio = AudioEngine.shared
    private let hardware = HardwareMonitor()
    private let ticker: DisplayTick
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

        hardware.onChange = { [weak self] info in
            Task { @MainActor in
                self?.applyHardware(info)
            }
        }
        hardware.start()
        ticker.store = self
        let link = CADisplayLink(target: ticker, selector: #selector(DisplayTick.tick))
        link.add(to: .main, forMode: .common)
        displayLink = link
        bindAudio()
        bindMIDI()
    }

    var displayBpm: Double {
        if ch1.playing { return ch1.effectiveBpm }
        if ch2.playing { return ch2.effectiveBpm }
        return masterBpm
    }

    func track(_ ch: Int) -> Track? {
        library.track(id: ch == 1 ? ch1.trackId : ch2.trackId)
    }

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

    func togglePlay(_ ch: Int) {
        if ch == 1 { ch1.playing.toggle() } else { ch2.playing.toggle() }
        Task { await audio.unlock() }
        pushAudio()
    }

    /// Free tier: Deck A only (SK-044 "free tier still useful: 1 deck, basic FX, hardware link").
    static let freeFx: Set<FxId> = [.filter, .delay]

    func loadTrack(ch: Int, id: String) {
        guard ch == 1 || iap.isPro else { showPaywall = true; return }
        guard let track = library.track(id: id) else { return }
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
        audio.loadTrack(ch, url: track.fileURL, duration: track.duration)
        if ch == 1 || beatMatch {
            masterBpm = track.bpm
        }
    }

    func seek(_ ch: Int, toFraction fraction: Double) {
        updateChannel(ch) { $0.deckPos = min(1, max(0, fraction)) }
        audio.seek(ch, toFraction: fraction)
    }

    func syncBpm(from ch: Int) {
        let src = ch == 1 ? ch1 : ch2
        let dstBase = ch == 1 ? ch2.bpm : ch1.bpm
        guard src.trackId != nil else { return }
        let target = src.effectiveBpm
        let maxPitch = iap.isPro ? 16.0 : 8.0
        let pitch = max(-maxPitch, min(maxPitch, (target / max(dstBase, 1) - 1) * 100))
        if ch == 1 { ch2.pitch = pitch } else { ch1.pitch = pitch }
        masterBpm = target
        beatMatch = true
        pushAudio()
    }

    // MARK: - Hot cues + loops (SK-034, Pro-gated per SK-046)

    func setHotCue(_ ch: Int, slot: Int) {
        guard iap.isPro || slot == 0 else { showPaywall = true; return }
        let pos = (ch == 1 ? ch1 : ch2).deckPos * (track(ch)?.duration ?? 0)
        updateChannel(ch) { $0.hotCues[slot] = pos }
    }

    func jumpToHotCue(_ ch: Int, slot: Int) {
        guard let duration = track(ch)?.duration, duration > 0 else { return }
        guard let cue = (ch == 1 ? ch1 : ch2).hotCues[slot] else { return }
        seek(ch, toFraction: cue / duration)
    }

    func clearHotCue(_ ch: Int, slot: Int) {
        updateChannel(ch) { $0.hotCues[slot] = nil }
    }

    func toggleLoop(_ ch: Int) {
        guard iap.isPro else { showPaywall = true; return }
        let state = ch == 1 ? ch1 : ch2
        if state.loopActive {
            updateChannel(ch) { $0.loopActive = false }
        } else if let duration = track(ch)?.duration, duration > 0 {
            let startSec = state.deckPos * duration
            updateChannel(ch) {
                $0.loopActive = true
                $0.loopStartSec = startSec
            }
        }
    }

    func nudgeLoopLength(_ ch: Int, doubled: Bool) {
        updateChannel(ch) { state in
            let next = doubled ? state.loopLengthBeats * 2 : state.loopLengthBeats / 2
            state.loopLengthBeats = Tempo.nearestAutoLoopLength(max(0.25, min(32, next)))
        }
    }

    // MARK: - FX pad

    func selectFx(_ item: FxId) {
        guard iap.isPro || Self.freeFx.contains(item) else { showPaywall = true; return }
        fx = item
        pushFx()
    }

    func setFxPad(x: Double, y: Double) {
        fxX = min(1, max(0, x))
        fxY = min(1, max(0, y))
        pushFx()
    }

    func setLinked(_ value: Bool) {
        linked = value
    }

    private func applyHardware(_ info: HardwareMonitor.Info) {
        hardwareName = info.deviceName
        if info.sidekickLikely { linked = true }
    }

    private func bindAudio() {
        audio.onMeters = { [weak self] ch1m, ch2m, master in
            Task { @MainActor in
                self?.meters = (ch1m, ch2m, master)
            }
        }
        audio.onDeckPosition = { [weak self] ch, fraction in
            Task { @MainActor in
                guard let self else { return }
                if ch == 1 { self.ch1.deckPos = fraction } else { self.ch2.deckPos = fraction }
            }
        }
        audio.onForcedPlaybackChange = { [weak self] ch, playing in
            Task { @MainActor in
                guard let self else { return }
                if ch == 1 { self.ch1.playing = playing } else { self.ch2.playing = playing }
            }
        }
        audio.onLoopWrapped = { [weak self] ch in
            Task { @MainActor in
                self?.loopFlash = ch
                try? await Task.sleep(nanoseconds: 150_000_000)
                if self?.loopFlash == ch { self?.loopFlash = nil }
            }
        }
        pushAudio()
        pushFx()
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
        case "xf": crossfader = value; pushAudio()
        case "fx.x": fxX = value; pushFx()
        case "fx.y": fxY = value; pushFx()
        case "fx.depth": fxDepth = value; pushFx()
        case "fx.engage": fxActive.toggle(); pushFx()
        default: break
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

    /// Wall-clock position simulation for **pattern** (demo) decks only — file-backed decks
    /// get real position updates from `AudioEngine.onDeckPosition`.
    func advanceDecks(_ dt: Double) {
        func step(_ ch: inout ChannelState, isFile: Bool) {
            guard ch.playing, !isFile, let track = library.track(id: ch.trackId) else { return }
            let rate = 1 + ch.pitch / 100
            let next = ch.deckPos + (dt * rate) / track.duration
            ch.deckPos = next >= 1 ? 0 : next
        }
        step(&ch1, isFile: track(1)?.isImported ?? false)
        step(&ch2, isFile: track(2)?.isImported ?? false)
    }

    func completeOnboarding() {
        showOnboarding = false
        UserDefaults.standard.set(true, forKey: "sk.onboarded")
    }

    // MARK: - Snapshots (SK-043)

    func saveSnapshot(named name: String) {
        guard iap.isPro else { showPaywall = true; return }
        let snap = MixerSnapshot(
            name: name, createdAt: Date().timeIntervalSince1970,
            ch1Gain: ch1.gain, ch1EqHi: ch1.eqHi, ch1EqMid: ch1.eqMid, ch1EqLo: ch1.eqLo, ch1Fader: ch1.fader,
            ch2Gain: ch2.gain, ch2EqHi: ch2.eqHi, ch2EqMid: ch2.eqMid, ch2EqLo: ch2.eqLo, ch2Fader: ch2.fader,
            crossfader: crossfader, master: master, fx: fx.rawValue, fxDepth: fxDepth
        )
        snapshots.save(snap)
    }

    func recallSnapshot(_ snap: MixerSnapshot) {
        ch1.gain = snap.ch1Gain; ch1.eqHi = snap.ch1EqHi; ch1.eqMid = snap.ch1EqMid; ch1.eqLo = snap.ch1EqLo; ch1.fader = snap.ch1Fader
        ch2.gain = snap.ch2Gain; ch2.eqHi = snap.ch2EqHi; ch2.eqMid = snap.ch2EqMid; ch2.eqLo = snap.ch2EqLo; ch2.fader = snap.ch2Fader
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
