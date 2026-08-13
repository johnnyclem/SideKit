import Foundation
import SwiftUI

enum SourceId: String, CaseIterable, Identifiable, Codable {
    case usb1 = "usb-1"
    case usb2 = "usb-2"
    case usb3 = "usb-3"
    case usb4 = "usb-4"
    case usb5 = "usb-5"
    case usb6 = "usb-6"
    case usb7 = "usb-7"
    case usb8 = "usb-8"
    case onboardMic = "onboard-mic"
    case deviceAudio = "device-audio"
    case aux
    case sidekickCh1 = "sidekick-ch1"
    case sidekickCh2 = "sidekick-ch2"
    case deck

    var id: String { rawValue }

    var label: String {
        switch self {
        case .usb1: return "USB In 1–2"
        case .usb2: return "USB In 3–4"
        case .usb3: return "USB In 5–6"
        case .usb4: return "USB In 7–8"
        case .usb5: return "USB Return A"
        case .usb6: return "USB Return B"
        case .usb7: return "USB Bus C"
        case .usb8: return "USB Bus D"
        case .onboardMic: return "iPhone Mic"
        case .deviceAudio: return "Device Audio"
        case .aux: return "Aux / Session"
        case .sidekickCh1: return "Sidekick CH1"
        case .sidekickCh2: return "Sidekick CH2"
        case .deck: return "Virtual Deck"
        }
    }
}

enum EqStyle: String, CaseIterable, Identifiable, Codable {
    case dj, studio, param
    var id: String { rawValue }
    var title: String { rawValue.uppercased() }
}

enum CompMode: String, CaseIterable, Identifiable, Codable {
    case off, soft, hard, pump
    var id: String { rawValue }
    var title: String {
        switch self {
        case .off: return "Comp Off"
        case .soft: return "Soft"
        case .hard: return "Hard"
        case .pump: return "Pump"
        }
    }
}

enum FxId: String, CaseIterable, Identifiable, Codable {
    case filter, delay, tape, repeat, tremolo, siren
    var id: String { rawValue }
    var short: String {
        switch self {
        case .filter: return "FLT"
        case .delay: return "DLY"
        case .tape: return "TAP"
        case .repeat: return "RPT"
        case .tremolo: return "TRM"
        case .siren: return "SRN"
        }
    }
    var label: String {
        switch self {
        case .filter: return "Filter"
        case .delay: return "Delay"
        case .tape: return "Tape"
        case .repeat: return "Beat Repeat"
        case .tremolo: return "Tremolo"
        case .siren: return "Dub Siren"
        }
    }
}

enum Pattern: String, Codable {
    case kick, bass, hat, synth, breakbeat = "break"
}

enum AppTab: String, CaseIterable, Identifiable {
    case mixer, decks, fx, library, link
    var id: String { rawValue }
    var title: String {
        switch self {
        case .mixer: return "Mixer"
        case .decks: return "Decks"
        case .fx: return "FX"
        case .library: return "Library"
        case .link: return "Link"
        }
    }
    var systemImage: String {
        switch self {
        case .mixer: return "slider.horizontal.3"
        case .decks: return "opticaldisc"
        case .fx: return "sparkles"
        case .library: return "square.stack"
        case .link: return "link"
        }
    }
}

struct Track: Identifiable, Equatable {
    let id: String
    let title: String
    let artist: String
    let bpm: Double
    let key: String
    var duration: Double
    let pattern: Pattern
    var fileURL: URL? = nil
    var resampled: Bool = false
    var isImported: Bool = false
}

struct ChannelState: Equatable {
    var source: SourceId = .deck
    var gain: Double = 0
    var eqHi: Double = 0
    var eqMid: Double = 0
    var eqLo: Double = 0
    var fader: Double = 0.78
    var cue: Bool = false
    var mute: Bool = false
    var solo: Bool = false
    var comp: CompMode = .soft
    var compAmount: Double = 0.35
    var eqStyle: EqStyle = .dj
    var fxAssign: Bool = true
    var bpm: Double = 120
    var pitch: Double = 0
    var playing: Bool = false
    var trackId: String? = nil
    var deckPos: Double = 0

    var effectiveBpm: Double { bpm * (1 + pitch / 100) }
}

enum DemoLibrary {
    static let tracks: [Track] = [
        Track(id: "t1", title: "Side Street", artist: "Field System", bpm: 92, key: "Am", duration: 186, pattern: .kick),
        Track(id: "t2", title: "Plastic Peg", artist: "EP Series", bpm: 110, key: "Dm", duration: 204, pattern: .bass),
        Track(id: "t3", title: "KO Night Bus", artist: "Pocket Unit", bpm: 128, key: "F#m", duration: 172, pattern: .hat),
        Track(id: "t4", title: "Motion Control", artist: "Tape FX", bpm: 140, key: "Em", duration: 198, pattern: .breakbeat),
        Track(id: "t5", title: "Session Aux", artist: "Daisy Chain", bpm: 98, key: "Gm", duration: 220, pattern: .synth),
        Track(id: "t6", title: "Beat Match 01", artist: "SideKit Demo", bpm: 120, key: "Cm", duration: 160, pattern: .kick),
    ]

    static func track(id: String?) -> Track? {
        guard let id else { return nil }
        return tracks.first { $0.id == id }
    }
}

enum Formatters {
    static func bpm(_ value: Double) -> String {
        String(format: "%.1f", value)
    }

    static func time(_ sec: Double) -> String {
        guard sec.isFinite, sec >= 0 else { return "0:00" }
        let m = Int(sec) / 60
        let s = Int(sec) % 60
        return "\(m):\(String(format: "%02d", s))"
    }
}
