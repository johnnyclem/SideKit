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
    }

    var displayBpm: Double {
        if ch1.playing { return ch1.effectiveBpm }
        if ch2.playing { return ch2.effectiveBpm }
        return masterBpm
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

    func loadTrack(ch: Int, id: String) {
        guard let track = DemoLibrary.track(id: id) else { return }
        selectedTrackId = id
        updateChannel(ch) { state in
            state.trackId = id
            state.bpm = track.bpm
            state.pitch = 0
            state.deckPos = 0
            state.playing = false
            state.source = .deck
        }
        if ch == 1 || beatMatch {
            masterBpm = track.bpm
        }
    }

    func syncBpm(from ch: Int) {
        let src = ch == 1 ? ch1 : ch2
        let dstBase = ch == 1 ? ch2.bpm : ch1.bpm
        guard src.trackId != nil else { return }
        let target = src.effectiveBpm
        let pitch = max(-8, min(8, (target / max(dstBase, 1) - 1) * 100))
        if ch == 1 { ch2.pitch = pitch } else { ch1.pitch = pitch }
        masterBpm = target
        beatMatch = true
        pushAudio()
    }

    func setFxPad(x: Double, y: Double) {
        fxX = min(1, max(0, x))
        fySet(y)
        pushFx()
    }

    private func fySet(_ y: Double) {
        fxY = min(1, max(0, y))
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
        pushAudio()
        pushFx()
    }

    func pushAudio() {
        audio.applyChannel(1, ch1, xf: crossfader, master: master)
        audio.applyChannel(2, ch2, xf: crossfader, master: master)
        audio.setMaster(master)
        audio.setChannelPlaying(1, ch1.playing && ch1.source == .deck, DemoLibrary.track(id: ch1.trackId), bpm: ch1.effectiveBpm)
        audio.setChannelPlaying(2, ch2.playing && ch2.source == .deck, DemoLibrary.track(id: ch2.trackId), bpm: ch2.effectiveBpm)
        pushFx()
    }

    func pushFx() {
        audio.applyFx(fx, active: fxActive, x: fxX, y: fxY, depth: fxDepth)
    }

    func advanceDecks(_ dt: Double) {
        func step(_ ch: inout ChannelState) {
            guard ch.playing, let track = DemoLibrary.track(id: ch.trackId) else { return }
            let rate = 1 + ch.pitch / 100
            let next = ch.deckPos + (dt * rate) / track.duration
            ch.deckPos = next >= 1 ? 0 : next
        }
        step(&ch1)
        step(&ch2)
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
