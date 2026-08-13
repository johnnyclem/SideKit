# SideKit iOS architecture

```
SwiftUI (portrait)
  RootView → Mixer / Decks / FX / Library / Link
       │
       ▼
 MixerStore (@MainActor, ObservableObject)
       │
       ├── AudioEngine (AVAudioEngine, 48 kHz)
       │     demo players → 3-band EQ → channel mixers ─┐
       │     AVAudioSourceNode → sk_engine_render() ────┴→ filter → delay → main
       └── HardwareMonitor (AVAudioSession route changes)

SideKitAudio (static lib, C++)
  SpscRing<ParamCmd, 128>   UI → audio
  Engine::render()          no alloc, interleaved float32
  C ABI                     sidekit_audio.h
```

Portrait lock is `UISupportedInterfaceOrientations = UIInterfaceOrientationPortrait`.
Device family is iPhone only (`TARGETED_DEVICE_FAMILY = 1`).

SK-001 delivered the static lib + hello callback. SK-004 moves the demo voices into `Engine::render`.
