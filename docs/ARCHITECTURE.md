# SideKit iOS architecture

```
SwiftUI (portrait)
  RootView → Mixer / Decks / FX / Library / Link
       │
       ▼
 MixerStore (@MainActor)
       │  posts via SPSC (never touches the audio thread)
       ▼
 FileDecoder (ExtAudioFile)
   WAV / AIFF / MP3 / AAC / M4A / ALAC
   client format = 48 kHz stereo float32  ← offline resample
       │
       ▼
 SKAudioBridge ──► SideKitAudio (static lib, 48 kHz)
                     consumeCommands()
                     ClipBank × 2  (double-buffered PCM, pointer swap)
                     ChannelVoice × 2  (clip player or pattern sequencer)
                     3-band EQ + equal-power XF + master
                     sk_engine_render()  ← no allocations
       │
       ▼
 AVAudioEngine
   AVAudioSourceNode → filter → delay → output
   (FX only; mixer/voices/clips are C++)
```

SK-001: static lib + hello callback.
SK-004: lock-free params, dual-voice 48 kHz render, silence start/stop, no-alloc render.
SK-010: ExtAudioFile decode, 48 kHz resample, clip slots, unsupported-codec banner.
