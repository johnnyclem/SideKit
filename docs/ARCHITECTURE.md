# SideKit iOS architecture

```
SwiftUI (portrait iPhone / adaptive iPad landscape)
  RootView → Mixer / Decks / FX / Library / Link
       │
       ▼
 MixerStore (@MainActor, ObservableObject)
       │
       ├── AudioEngine (AVAudioEngine, 48 kHz)
       │     ch1/ch2 players → AVAudioUnitVarispeed (pitch/tempo) → 3-band EQ
       │       → channel mixers → filter → delay → main
       │     Two playback modes per channel, chosen when a track loads:
       │       • pattern  — synthesized step-sequenced demo voices (no bundled audio yet)
       │       • file     — real AVAudioFile via scheduleSegment, real seek/loop/hot cues
       │     25 ms scheduler tick drives both pattern note scheduling and file-deck
       │     loop wrap / position reporting.
       ├── LibraryStore (imported-file metadata, peaks cache, persisted under
       │     Application Support)
       ├── HardwareMonitor (AVAudioSession route changes → Sidekick USB detection)
       ├── MIDIManager (Core MIDI endpoints, Sidekick MIDI Control detection,
       │     factory map, MIDI learn, persisted bindings)
       ├── StoreManager (StoreKit 2 Pro non-consumable, offline-safe restore)
       ├── SnapshotStore (mixer scene save/recall, UserDefaults-backed)
       ├── USBMatrixStore (8x4 matrix role persistence per mix mode)
       └── CrashReporting (opt-in, on-device MetricKit only — no third-party SDKs)
```

Portrait lock (`UISupportedInterfaceOrientations = UIInterfaceOrientationPortrait`) applies
to iPhone only. iPad (`TARGETED_DEVICE_FAMILY = "1,2"`) allows landscape and gets a
two-column mixer+decks layout in `RootView` (SK-047).

## Audio engine notes

- **Pitch/tempo (SK-012)**: `AVAudioUnitVarispeed` per channel — vinyl-style, pitch and
  tempo move together, matching the classic DJ pitch-fader behavior the tickets describe
  (SYNC sets a target *pitch*, not an independent time-stretch).
- **Seek / hot cues / loops (SK-011/034)**: file decks track position as
  `startFrame/sampleRate + elapsed*rate` and re-`scheduleSegment` on seek. Loop wrap is
  detected on the 25 ms scheduler tick and re-seeks to the loop start — not sample-accurate
  (a real DJ engine would double-buffer for a click-free wrap), but functionally correct
  and quantizes to the beat grid via `Tempo.quantize`/`nearestAutoLoopLength`.
- **Waveform peaks (SK-013)**: computed once at import time (400-bucket peak-abs
  downsample) and cached to disk; the deck view further downsamples for display.
- **BPM (SK-014)**: reads ID3/iTunes BPM tags first; falls back to a simple energy-based
  onset detector + median inter-onset interval, folded into a 70–180 BPM range.
- **No C++ engine yet**: PRD-01 asks for a C++ DSP core; this build stays Swift/AVFoundation
  end-to-end (as the original prototype already committed to) rather than a partial,
  unverifiable C++ bridge. `SideKitCore/` is a small **standalone** Swift package that holds
  the pure tempo/MIDI-map/snapshot math with real `swift test` coverage (SK-002) — it is not
  linked into the Xcode target (to keep the hand-authored `.pbxproj` simple/low-risk); the
  app target carries an intentionally-mirrored copy (`SideKit/Tempo.swift` etc.) with a
  comment pointing at the tested source.

## What's simulated vs. real

| Area | Demo library tracks | User-imported tracks |
|---|---|---|
| Playback | Synthesized step patterns (no bundled audio asset ships yet — SK-036 gap) | Real `AVAudioFile` decode/playback |
| Waveform | Procedural placeholder shape | Real cached peaks |
| BPM | Fixed metadata | Tag read + onset fallback |
| Pitch/loop/cues | UI works, but there's no real audio to loop/cue precisely | Fully real |

## Free / Pro split (SK-044/045/046)

Free: Deck A, Filter + Delay FX, hardware link, library import. Pro (non-consumable,
StoreKit 2): Deck B, hot cues, loops, all 6 FX, mixer scenes, ±16% pitch. Paywall only
triggers on a gated action — never before first audio.
