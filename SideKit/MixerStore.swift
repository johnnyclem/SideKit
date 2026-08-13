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
    @Published var imported: [Track] = []
    @Published var decodeBanner: String?
    @Published var isDecoding = false

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
        Task { await prepareClip(ch: 1) }
    }

    var displayBpm: Double {
        if ch1.playing { return ch1.effectiveBpm }
        if ch2.playing { return ch2.effectiveBpm }
        return masterBpm
    }

    var libraryTracks: [Track] {
        imported + DemoLibrary.tracks
    }

    func track(id: String?) -> Track? {
        guard let id else { return nil }
        return imported.first { $0.id == id } ?? DemoLibrary.track(id: id)
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
        if ch == 1 { ch1.playing.toggle() } else { ch2.playing.toggle() }
        Task {
            await audio.unlock()
            await prepareClip(ch: ch)
            pushAudio()
        }
    }

    func loadTrack(ch: Int, id: String) {
        guard let track = track(id: id) else { return }
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
        Task { await prepareClip(ch: ch) }
    }

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
                let dest = try persistImport(url)
                let clip = try await audio.decodeFile(url: dest)
                let item = Track(
                    id: UUID().uuidString,
                    title: dest.deletingPathExtension().lastPathComponent,
                    artist: clip.resampled ? "Imported · 48 kHz" : "Imported",
                    bpm: 120,
                    key: "—",
                    duration: clip.duration,
                    pattern: .kick,
                    fileURL: dest,
                    resampled: clip.resampled,
                    isImported: true
                )
                imported.insert(item, at: 0)
                selectedTrackId = item.id
                decodeBanner = nil
                loadTrack(ch: loadTarget, id: item.id)
            } catch {
                decodeBanner = error.localizedDescription
            }
        }
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
            if let idx = imported.firstIndex(where: { $0.id == tr.id }) {
                imported[idx].duration = clip.duration
                imported[idx].resampled = clip.resampled
            }
            decodeBanner = nil
        } catch {
            decodeBanner = error.localizedDescription
            audio.clearClip(ch: ch)
        }
    }

    private func persistImport(_ url: URL) throws -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("Imports", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let dest = dir.appendingPathComponent(UUID().uuidString + "." + url.pathExtension.lowercased())
        if FileManager.default.fileExists(atPath: dest.path) {
            try FileManager.default.removeItem(at: dest)
        }
        try FileManager.default.copyItem(at: url, to: dest)
        return dest
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
        pushAudio()
        pushFx()
    }

    func pushAudio() {
        audio.applyChannel(1, ch1, xf: crossfader, master: master)
        audio.applyChannel(2, ch2, xf: crossfader, master: master)
        audio.setMaster(master)
        audio.setChannelPlaying(1, ch1.playing && ch1.source == .deck, track(id: ch1.trackId), bpm: ch1.effectiveBpm)
        audio.setChannelPlaying(2, ch2.playing && ch2.source == .deck, track(id: ch2.trackId), bpm: ch2.effectiveBpm)
        pushFx()
    }

    func pushFx() {
        audio.applyFx(fx, active: fxActive, x: fxX, y: fxY, depth: fxDepth)
    }

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
