# SideKit iOS architecture

```
SwiftUI (portrait iPhone · two-column iPad)
  RootView → Mixer / Decks / FX / Library / Link
       │          + Onboarding (first run) · Paywall (gated action) · Diagnostics sheet
       ▼
 MixerStore (@MainActor, ObservableObject)
       │  owns all session state; posts to the engine over the SPSC queue only
       │
       ├── FileDecoder (ExtAudioFile)      WAV / AIFF / MP3 / AAC / M4A / ALAC
       │     client format = 48 kHz stereo float32  ← offline resample
       ├── PeakCache                       min/max overview, .skpeaks sidecar (C++ build/read/write)
       ├── LibraryStore                    imported-file index, Documents/Imports/library.json
       │     └── BPMAnalyzer               ID3/iTunes BPM tag → onset-interval estimate
       ├── HardwareMonitor                 AVAudioSession route changes → Sidekick USB detection
       ├── MIDIManager                     Core MIDI endpoints, Sidekick detection, factory map, learn
       ├── StoreManager                    StoreKit 2 non-consumable Pro, offline-safe restore
       ├── SnapshotStore                   mixer scenes (UserDefaults)
       ├── USBMatrixStore                  8×4 matrix roles per mix mode (UserDefaults)
       └── CrashReporting                  opt-in on-device MetricKit, no third-party SDK
       │
       ▼
 SKAudioBridge ──► SideKitAudio (static lib, C++17, 48 kHz)
                     SpscRing<ParamCmd, 256>   UI → audio, lock-free
                     consumeCommands()
                     ClipBank × 2   double-buffered PCM, pointer swap on the render thread
                     ChannelVoice × 2
                       clip player: linear read or WSOLA time-stretch (±16 %, key locked)
                       loop region [start, end) wrapped sample-accurately on the render thread
                       5 ms equal-power fades on play / pause / seek
                       pattern sequencer when no clip is attached (demo fallback)
                     3-band EQ + equal-power crossfader + master
                     sk_engine_render()   no allocations
       │
       ▼
 AVAudioEngine
   AVAudioSourceNode → filter (AVAudioUnitEQ) → delay (AVAudioUnitDelay) → output
   (FX host only; mixer, voices, transport, pitch and loops are C++)
```

## Threading

- The render callback never allocates and never takes a lock. Swift posts `ParamCmd`s;
  `Engine::render` drains them at the top of each quantum.
- Clip loads allocate on the UI thread into the *inactive* `ClipBank` slot, then post a
  `LoadClip` command; the render thread swaps the pointer.
- `MixerStore.advanceDecks` runs on a 60 fps `CADisplayLink` and mirrors `SKClipInfo`
  (playhead, playing, loop) back into the published `ChannelState`, so the UI never guesses.
- Core MIDI packets arrive on a CoreMIDI thread and hop to the main actor before touching
  state. Hot cue / loop / MIDI edits all funnel through `MixerStore`.

## Decks

| | Imported file | Bundled demo (t1, t2, t6) | Demo without audio (t3–t5) |
|---|---|---|---|
| Source | ExtAudioFile → clip slot | 2 s WAV fixture → clip slot | C++ pattern sequencer |
| Pitch | WSOLA ±8 % free / ±16 % Pro | same | changes step rate |
| Seek / restart | frame-accurate, 5 ms fade | same | restart only |
| Hot cues (SK-034) | seconds → `sk_engine_seek_frames` | same | — |
| Loop (SK-034) | `sk_engine_set_loop`, beat-quantized in at base BPM | same | — |
| Waveform | real min/max peaks (cached) | real | dashed placeholder |
| BPM | tag → onset estimate (marked `*`) | metadata | metadata |

Loop regions live in **clip** time, so loop length is computed at the track's base BPM —
time-stretch changes how fast the read head moves, not where the beats sit in the file.

## Free / Pro split (SK-044/045/046)

Free: Deck A, Filter + Delay, hardware link, library import, hot cue 1.
Pro (StoreKit 2 non-consumable `com.johnnyclem.SideKit.pro`): Deck B, hot cues 2–4,
loops, all six FX, mixer scenes, ±16 % pitch. The paywall only appears on a gated action.
`MixerStore.isPro` mirrors `StoreManager.isPro` so every view re-renders on purchase.

## Shared pure logic

`SideKitCore/` is a standalone SwiftPM package (tempo / beat math, MIDI map scaling,
snapshot list ops) with `swift test` coverage. It is **not** linked into the Xcode target
to keep the hand-authored `.pbxproj` simple; `SideKit/Tempo.swift`, `MIDIManager.swift`
and `SnapshotStore.swift` carry intentionally mirrored copies with a comment pointing at
the tested source. The C++ core has its own host test (`make -C SideKitAudio test`).

## Layout

iPhone is portrait-only and every tab is one screen (no inner scroll) except Library
(track list) and Link (collapsible matrix / MIDI sections). iPad
(`TARGETED_DEVICE_FAMILY = "1,2"`) allows landscape and shows the mixer in a left column
with the selected tab on the right (SK-047).

## Ticket trail

SK-001 static lib + hello callback · SK-004 lock-free params, dual-voice 48 kHz render ·
SK-010 ExtAudioFile decode + clip slots · SK-011 fades, frame-accurate seek, restart ·
SK-012 WSOLA key-locked pitch · SK-013 cached peaks + 60 fps playhead · SK-014 BPM ·
SK-015 interruption pause/resume · SK-034 hot cues + sample-accurate loops ·
SK-035/036 persisted import library · SK-027 USB matrix · SK-040/041/042 Core MIDI ·
SK-043 scenes · SK-044/045/046 StoreKit Pro · SK-047 iPad · SK-048 onboarding ·
SK-049 accessibility pass · SK-050 diagnostics · SK-051 MetricKit.
