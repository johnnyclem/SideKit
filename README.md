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

## Project layout

```
SideKit.xcodeproj
SideKit/
  SideKitApp.swift        App entry
  RootView.swift          Portrait chrome + tab bar
  MixerStore.swift        Observable session state
  AudioEngine.swift       AVAudioEngine + pattern voices
  HardwareMonitor.swift   USB / Sidekick route watch
  MixerView.swift         Channel strips
  DecksView.swift         Dual decks
  FXView.swift            Force pad
  LibraryView.swift       Demo library
  LinkView.swift          Device + matrix
  Controls.swift          Knobs, faders, meters
  Theme.swift             Hardware-adjacent tokens
```

## Requirements

- Xcode 16+
- iOS 17.0+
- iPhone (portrait). iPad is not a target in v1.

## Roadmap

Sprint tickets from the App Store PRD (SK-001 … SK-066) live in the conversation / product docs. Next native slices:

- SK-010 file decode (AAC/MP3/ALAC/WAV)
- SK-025/026 real USB 8×4 mix modes
- SK-040 Core MIDI maps
- SK-044 StoreKit Pro unlock

## License

Source in this repo is provided for the SideKit product. Teenage Engineering names and hardware are their trademarks.
