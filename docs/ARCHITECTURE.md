# SideKit iOS architecture

```
SwiftUI (portrait)
  RootView → Mixer / Decks / FX / Library / Link
       │
       ▼
 MixerStore (@MainActor, ObservableObject)
       │
       ├── AudioEngine (AVAudioEngine, 48 kHz)
       │     players → 3-band EQ → channel mixers → filter → delay → main
       │     16th-note pattern scheduler (demo voices)
       └── HardwareMonitor (AVAudioSession route changes)
```

Portrait lock is `UISupportedInterfaceOrientations = UIInterfaceOrientationPortrait`.
Device family is iPhone only (`TARGETED_DEVICE_FAMILY = 1`).

C++ DSP (PRD-01) is not in this first commit. `AudioEngine.swift` is the Swift stand-in; swap the render path when SK-004 lands.
