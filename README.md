# SideKit

Native **SwiftUI** iPhone app — the software brain for [Teenage Engineering EP-136 K.O. Sidekick](https://teenage.engineering/products/ep-136).

Portrait-only. Dual virtual decks, mixer, performance FX pad, library, and USB link surface.

**Not an official Teenage Engineering product.** Descriptive companion for Sidekick hardware.

## Open in Xcode

1. Clone this repo on a Mac
2. Open `SideKit.xcodeproj`
3. Select your **Team** under Signing & Capabilities (bundle id `com.johnnyclem.SideKit`)
4. Run on an **iPhone** (USB-C, iOS 17+) or Simulator

First tap Play to unlock the audio session. Demo patterns play until file decode (SK-010) lands.

## What shipped in this first native cut

| Tab | Native behavior |
|---|---|
| **Mixer** | Dual channel strips, gain / 3-band EQ knobs, faders, cue / mute / FX, compressor menu, DJ·Studio·Param EQ styles, crossfader, master / cue / phones |
| **Decks** | Dual virtual decks, waveform + seek, pitch ±8%, SYNC, beat-match, playhead |
| **FX** | Six punch-in FX (filter, delay, tape, repeat, tremolo, siren), force pad X/Y, depth, series/parallel |
| **Library** | Six demo tracks, search, load → Deck A/B |
| **Link** | USB route watch for Sidekick / EP-136 / class-compliant USB, mix mode, 8×4 matrix |

Audio is **AVAudioEngine** (48 kHz) with a step sequencer that mirrors the web prototype’s kick / bass / hat / break / synth patterns, plus EQ and delay/filter FX.

Hardware detection uses `AVAudioSession` route changes. Plug in a Sidekick over USB-C and Link should flip to connected when the port name matches.

## C++ audio core (SK-001 / SK-004)

`SideKitAudio` is a static library linked into the app.

- C ABI in `SideKitAudio/include/sidekit_audio.h`
- Lock-free SPSC command queue (`RingBuffer.hpp`) so the UI thread never touches the render callback
- Dual-voice pattern sequencer + 3-band EQ + XF/master in `Engine::render`
- Swift posts transport/mix/EQ over the SPSC queue only
- Host check: `make -C SideKitAudio test` (silence, kick energy, mute, no-alloc)

On first Play, the console should print:

`SideKit C++ 0.2.0-sk004 warmup frames=64 t=64 silent=true`

Signing: **Automatic** / Apple Development. Select your Team in Xcode (Signing & Capabilities). `DEVELOPMENT_TEAM` is left blank on purpose.

Shared scheme: `SideKit.xcodeproj/xcshareddata/xcschemes/SideKit.xcscheme` (Debug run, Release profile/archive). Builds `libSideKitAudio.a` first.

## Project layout

```
SideKit.xcodeproj
SideKit/
  SideKitApp.swift
  SKAudioBridge.swift      C++ bridge
  AudioEngine.swift        AVAudioEngine + C++ source node
  ...
SideKitAudio/
  include/sidekit_audio.h  C ABI
  src/Engine.cpp           render callback
  src/RingBuffer.hpp       SPSC param queue
  tests/hello_render_test.cpp
```

## Requirements

- Xcode 16+
- iOS 17.0+
- iPhone (portrait). iPad is not a target in v1.

## Roadmap

Sprint tickets: `docs/SPRINTS.md`. **SK-001 and SK-004 are done.** Next:

- SK-010 file decode (AAC/MP3/ALAC/WAV)
- SK-025/026 real USB 8×4 mix modes
- SK-040 Core MIDI maps
- SK-044 StoreKit Pro unlock

## License

Source in this repo is provided for the SideKit product. Teenage Engineering names and hardware are their trademarks.
