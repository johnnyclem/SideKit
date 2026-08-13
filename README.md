# SideKit

Native **SwiftUI** iPhone/iPad app — the software brain for [Teenage Engineering EP-136 K.O. Sidekick](https://teenage.engineering/products/ep-136).

Dual virtual decks, mixer, performance FX pad, library, MIDI control, and USB link surface.

**Not an official Teenage Engineering product.** Descriptive companion for Sidekick hardware.

## Open in Xcode

1. Clone this repo on a Mac
2. Open `SideKit.xcodeproj`
3. Select your **Team** under Signing & Capabilities (bundle id `com.johnnyclem.SideKit`)
4. Run on an **iPhone** or **iPad** (USB-C, iOS 17+) or Simulator

First tap Play to unlock the audio session. Demo library tracks still play synthesized
patterns (no bundled audio asset ships yet); import your own files (Library → Import)
for real playback.

## What's in this build

| Tab | Native behavior |
|---|---|
| **Mixer** | Dual channel strips, gain / 3-band EQ knobs, faders, cue / mute / FX, DJ·Studio·Param EQ styles, crossfader, master / cue / phones, saved scenes (Pro) |
| **Decks** | Real file playback for imported tracks (AVAudioFile + `AVAudioUnitVarispeed` pitch/tempo), waveform + seek, hot cues + loops (Pro), SYNC, beat-match |
| **FX** | Six punch-in FX (filter, delay, tape, repeat, tremolo, siren — filter/delay free, rest Pro), force pad X/Y, depth, series/parallel |
| **Library** | Import via document picker (AAC/MP3/ALAC/WAV/AIFF), cached waveform peaks, BPM tag read + onset fallback, 6 demo tracks, search, load → Deck A/B |
| **Link** | USB route watch for Sidekick / EP-136 / class-compliant USB, mix mode, editable + persisted 8×4 matrix, Core MIDI detection + learn + factory map |

Plus: onboarding, StoreKit 2 Pro unlock (Deck B, hot cues/loops, all 6 FX, scenes, ±16%
pitch), a diagnostics export sheet, opt-in on-device crash/analytics (MetricKit, no
third-party SDK), and an iPad two-column landscape layout.

Audio is **AVAudioEngine** (48 kHz). See `docs/ARCHITECTURE.md` for the signal graph and
`docs/STATUS.md` for an honest, ticket-by-ticket status against the sprint backlog —
including what's still a UI-only stub (compressor DSP, mix-mode routing, per-channel FX
bus) and what needs a human (App Store Connect, a physical Sidekick, legal/trademark,
marketing assets).

## Project layout

```
SideKit.xcodeproj
SideKit/
  SideKitApp.swift        App entry
  RootView.swift           Portrait/iPad chrome + tab bar
  MixerStore.swift         Observable session state
  AudioEngine.swift        AVAudioEngine: pattern voices + real file playback
  LibraryStore.swift       Import, metadata, peaks cache, persistence
  FileImportManager.swift  Document picker wrapper
  Tempo.swift              Pure tempo/beat math (mirrors SideKitCore, tested there)
  MIDIManager.swift        Core MIDI, factory map, learn mode
  SnapshotStore.swift      Mixer scene save/recall
  StoreManager.swift       StoreKit 2 Pro unlock
  USBMatrixStore.swift     USB 8x4 matrix persistence
  HardwareMonitor.swift    USB / Sidekick route watch
  CrashReporting.swift     Opt-in on-device MetricKit
  MixerView.swift          Channel strips + scenes
  DecksView.swift          Dual decks, hot cues, loops
  FXView.swift             Force pad
  LibraryView.swift        Import + demo library
  LinkView.swift           Device, matrix, MIDI
  OnboardingView.swift     First-run flow
  PaywallView.swift        Pro upsell
  DiagnosticsView.swift    Diagnostics export
  Controls.swift           Knobs, faders, meters
  Theme.swift              Hardware-adjacent tokens
SideKitCore/               Standalone SwiftPM package: pure tempo/MIDI-map/snapshot
                            math with `swift test` coverage (not linked into the Xcode
                            target — see ARCHITECTURE.md)
```

## Requirements

- Xcode 16+
- iOS 17.0+
- iPhone (portrait) or iPad (portrait + landscape)

## Testing

- `cd SideKitCore && swift test` — offline logic tests (tempo/crossfade math, MIDI CC
  scaling, snapshot list ops).
- `xcodebuild build -project SideKit.xcodeproj -scheme SideKit -destination 'platform=iOS Simulator,name=iPhone 15'`
  — compile check. Both run in CI on every PR.

## License

Source in this repo is provided for the SideKit product. Teenage Engineering names and
hardware are their trademarks.
