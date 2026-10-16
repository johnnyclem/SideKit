# SideKit

Native **SwiftUI** iPhone / iPad app — the software brain for [Teenage Engineering EP-136 K.O. Sidekick](https://teenage.engineering/products/ep-136).

Dual virtual decks on a C++ audio core, mixer, performance FX pad, library, MIDI control and USB link surface.

**Not an official Teenage Engineering product.** Descriptive companion for Sidekick hardware.

## Open in Xcode

1. Clone this repo on a Mac
2. Open `SideKit.xcodeproj`
3. Select your **Team** under Signing & Capabilities (bundle id `com.johnnyclem.SideKit`)
4. Run on an **iPhone** or **iPad** (USB-C, iOS 17+) or Simulator

First tap Play to unlock the audio session. Deck A loads a bundled 48 kHz WAV fixture. Import your own WAV/AIFF/MP3/AAC/M4A/ALAC from Library.

## What's in this build

| Tab | Native behavior |
|---|---|
| **Mixer** | Dual channel strips, gain / 3-band EQ knobs, faders, cue / mute / FX, compressor menu (UI only), DJ·Studio·Param EQ styles, crossfader, master, saved scenes (Pro) |
| **Decks** | Focused deck with A/B switch, real waveform + 60 fps playhead, seek/restart with 5 ms fades, WSOLA key-locked pitch (±8 % free, ±16 % Pro), SYNC, 4 hot cues + beat-quantized loops (Pro) |
| **FX** | Six punch-in FX (filter, delay free; tape, repeat, tremolo, siren Pro), force pad X/Y, depth, series/parallel |
| **Library** | Files import, BPM tag read + onset estimate, persisted library, remove, search, load → Deck A/B, codec error banner |
| **Link** | USB route watch for Sidekick / EP-136 / class-compliant USB, mix mode, editable 8×4 matrix, Core MIDI detection + factory map + learn, cue mix / phones |

Plus: first-run onboarding, StoreKit 2 Pro unlock, diagnostics export, opt-in on-device MetricKit crash counting, iPad two-column layout, interruption pause/resume.

Audio is **AVAudioEngine** (48 kHz I/O + FX) pulling a C++ render callback. Decoded files play from double-buffered clip slots; demo patterns fill decks that have no audio.

## C++ audio core (`SideKitAudio`)

Static library linked into the app. Host check without Xcode: `make -C SideKitAudio test`.

- C ABI in `SideKitAudio/include/sidekit_audio.h`
- Lock-free SPSC command queue (`RingBuffer.hpp`) so the UI thread never touches the render callback
- Dual-voice pattern sequencer + clip players + 3-band EQ + XF/master in `Engine::render`, no allocations
- File clips: ExtAudioFile (device) / WAV+resample (host) → 48 kHz stereo float, double-buffered load
- Transport: 5 ms equal-power fades, frame-accurate seek, restart, playhead mirrored to the UI
- Pitch ±16 % WSOLA time-stretch (key lock); 0 % is bit-transparent
- Loop region `[start, end)` in clip frames, wrapped on the render thread
- Waveform overview from cached min/max peaks

On first Play, the console prints:

`SideKit C++ 0.7.0-sk034 warmup frames=64 t=64 silent=true`

Signing: **Automatic** / Apple Development. `DEVELOPMENT_TEAM` is left blank on purpose.

Shared scheme: `SideKit.xcodeproj/xcshareddata/xcschemes/SideKit.xcscheme`. Builds `libSideKitAudio.a` first.

## Project layout

```
SideKit.xcodeproj
SideKit/
  SideKitApp.swift         App entry
  RootView.swift           iPhone / iPad chrome, tab bar, sheets
  MixerStore.swift         Observable session state; the only thing that talks to the engine
  AudioEngine.swift        AVAudioEngine host: C++ source node → filter → delay
  SKAudioBridge.swift      Swift face of the C++ static lib
  FileDecoder.swift        ExtAudioFile → 48 kHz stereo float
  PeakCache.swift          .skpeaks sidecar via the C++ peaks API
  LibraryStore.swift       Imported-file index + BPM analyzer
  Tempo.swift              Beat math (mirrors SideKitCore, tested there)
  MIDIManager.swift        Core MIDI, factory map, learn
  SnapshotStore.swift      Mixer scenes
  StoreManager.swift       StoreKit 2 Pro unlock
  USBMatrixStore.swift     USB 8×4 matrix persistence
  HardwareMonitor.swift    USB / Sidekick route watch
  CrashReporting.swift     Opt-in MetricKit
  MixerView / DecksView / FXView / LibraryView / LinkView
  WaveformView.swift       Canvas overview with loop band + cue ticks
  OnboardingView / PaywallView / DiagnosticsView
  Controls.swift, Theme.swift
  Audio/*.wav              bundled decode fixtures
SideKitAudio/              C++17 static lib
  include/sidekit_audio.h  C ABI
  src/Engine.cpp           render + command drain
  src/Voice.hpp            clip player, loop, fades, pattern sequencer
  src/Wsola.hpp            time-stretch
  src/Decode.hpp           WAV + linear resample (host)
  src/Peaks.hpp            min/max overview + sidecar
  tests/hello_render_test.cpp
SideKitCore/               Standalone SwiftPM package: tempo / MIDI-map / snapshot math + tests
docs/                      SPRINTS.md (backlog), STATUS.md (ticket status), ARCHITECTURE.md
```

## Testing

- `make -C SideKitAudio test` — C++ host tests: silence, fades, seek, WSOLA ratio + key lock, loops, peaks (Linux/macOS).
- `cd SideKitCore && swift test` — tempo / crossfade math, MIDI scaling, snapshot list ops.
- `xcodebuild build -project SideKit.xcodeproj -scheme SideKit -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO` — compile check.

All of the above plus SwiftLint (strict) run in CI on every PR.

## Requirements

- Xcode 16+
- iOS 17.0+
- iPhone (portrait) or iPad (portrait + landscape)

Sprint tickets: `docs/SPRINTS.md`. Honest ticket-by-ticket status, including what is still UI-only: `docs/STATUS.md`.

## License

Source in this repo is provided for the SideKit product. Teenage Engineering names and hardware are their trademarks.
