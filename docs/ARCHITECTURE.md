# SideKit iOS architecture

```
SwiftUI (portrait)
  RootView → Mixer / Decks / FX / Library / Link
       │
       ▼
 MixerStore (@MainActor)
       │  posts via SPSC (never touches the audio thread)
       ▼
 SKAudioBridge ──► SideKitAudio (static lib, 48 kHz)
                     consumeCommands()
                     ChannelVoice × 2  (pattern sequencer, 6 partials)
                     3-band EQ + equal-power XF + master
                     sk_engine_render()  ← no allocations
       │
       ▼
 AVAudioEngine
   AVAudioSourceNode → filter → delay → output
   (FX only; mixer/voices are C++)
```

SK-001: static lib + hello callback.
SK-004: lock-free params, dual-voice 48 kHz render, silence start/stop, no-alloc render.
