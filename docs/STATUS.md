# Ticket status vs. docs/SPRINTS.md

Honest status after merging PR #5 (features) with `main` (C++ engine). "Done" means the
code is in this repo and either host-tested (C++ core, `SideKitCore`) or compiled by CI's
`xcodebuild` simulator build. Nothing below has been run on a device by the author of the
merge — treat the Swift side as *compiles, needs a device pass*.

Legend: ✅ done · ◐ partial / UI-only stub · ⛔ not started (needs a human, account or hardware)

## Sprint 0 — Foundation
| Ticket | Status | Notes |
|---|---|---|
| SK-001 Xcode workspace | ✅ | `SideKitAudio` C++ static lib linked into the app. |
| SK-002 CI | ✅ | `.github/workflows/ci.yml`: C++ host tests (ubuntu), SwiftLint strict, `swift test` on `SideKitCore`, `xcodebuild` simulator build. |
| SK-003 Design tokens | ✅ | `Theme.swift`. |
| SK-004 AudioEngine skeleton | ✅ | Lock-free SPSC queue, 48 kHz no-alloc render, dual voices, EQ, XF, master — all in `Engine::render`. |
| SK-005 App Store Connect shell | ⛔ | Needs the Apple Developer / ASC account. |
| SK-006 Trademark screen | ⛔ | Needs a human legal search. |

## Sprint 1 — Decks Core
| Ticket | Status | Notes |
|---|---|---|
| SK-010 File decode | ✅ | `FileDecoder` (ExtAudioFile) → 48 kHz stereo float → C++ clip slots. Unsupported-codec banner. |
| SK-011 Deck A transport | ✅ | 5 ms equal-power fades, frame-accurate seek, restart; playhead mirrored from the engine at 60 fps. |
| SK-012 Pitch ±8 % | ✅ | WSOLA time-stretch, key locked; bit-transparent at 0 %. Engine range is ±16 % (Pro), free tier clamps to ±8 % in Swift. |
| SK-013 Waveform | ✅ | C++ min/max peaks cached as `.skpeaks`, Canvas overview, drag-to-seek, loop band + cue ticks. |
| SK-014 BPM | ✅ (imports) | ID3/iTunes tag read, else onset-interval estimate (shown with `*`). Demo tracks use metadata. |
| SK-015 Background audio + interruption | ✅ | Background mode pre-existing; interruption pauses playing decks and resumes them on `.shouldResume`. Needs a device test with a real call. |
| SK-016 Deck UI shell | ✅ | Single focused deck per screen with A/B switch, hot cue + loop row. |

## Sprint 2 — Mixer + USB
| Ticket | Status | Notes |
|---|---|---|
| SK-020 Dual deck engine | ✅ | Two `ChannelVoice`s in C++. |
| SK-021 Channel strip DSP | ✅ | Gain, 3-band EQ (DJ/Studio/Param multipliers), fader, mute in C++. |
| SK-022 Compressor modes | ◐ | UI picker only — `comp` / `compAmount` reach no DSP. **Not implemented.** |
| SK-023 Crossfader | ✅ | Equal-power in C++. |
| SK-024 Meters | ✅ | Per-channel + master peak from `SKRenderInfo`. |
| SK-025 USB Sidekick discovery | ◐ | Route / port-name match is real; **cannot be QA'd without a Sidekick.** |
| SK-026 Mix modes | ◐ | Segmented control only; mode does not change routing. |
| SK-027 USB matrix | ✅ | Per-mode roles persisted in `USBMatrixStore`, editable from Link (collapsed by default). |
| SK-028 Source selector | ◐ | Selector exists; unavailable sources are not disabled with a reason. |
| SK-029 Mixer tab UI | ✅ | One screen, scenes menu in the header. |

## Sprint 3 — FX + Library
| Ticket | Status | Notes |
|---|---|---|
| SK-030 FX graph | ✅ | Six FX on a shared AVAudioUnitEQ + AVAudioUnitDelay post-mix. |
| SK-031 Force pad | ✅ | Accessibility + Reduce Motion aware. |
| SK-032 Per-channel FX assign + series/parallel | ◐ | Toggles exist; FX bus is a single shared post-mix chain. |
| SK-033 Deck B + Sync | ✅ | Deck B is Pro-gated. |
| SK-034 Hot cues + loops | ✅ | 4 cues (frame-accurate seek), loop in quantized to the beat grid, ½ / 2× lengths, **wrapped on the render thread in C++** (tested). Pro-gated (cue 1 free). |
| SK-035 Library import | ✅ | `.fileImporter`, copies to `Documents/Imports`, persisted index, remove. |
| SK-036 Demo tracks + empty states | ◐ | t1/t2/t6 play 2 s bundled WAV fixtures; t3–t5 are synthesized patterns. No full-length royalty-free demo audio yet. Empty-library state added. |
| SK-037 Demo mode without hardware | ✅ | |

## Sprint 4 — Hardware Brain + Pro
| Ticket | Status | Notes |
|---|---|---|
| SK-040 Core MIDI + detection | ✅ | `MIDIManager`. Untested against hardware. |
| SK-041 Factory MIDI map | ✅ | Original map, auto-applied when a Sidekick MIDI source appears. |
| SK-042 MIDI learn | ✅ | Per-target learn, persisted. |
| SK-043 Snapshots | ✅ | Save / recall / delete from the Mixer header menu, up to 16, Pro. |
| SK-044 StoreKit 2 Pro | ✅ (code) | Needs the `com.johnnyclem.SideKit.pro` product in ASC (or a StoreKit configuration file for local testing). |
| SK-045 Paywall UX | ✅ | Only on gated actions. |
| SK-046 Pitch ±16 % Pro gate | ✅ | Engine clamp widened to ±16 (tested); free tier ±8. |
| SK-047 iPad layout | ✅ | Mixer left, selected tab right, landscape allowed on iPad only. |
| SK-048 Onboarding | ✅ | Skippable; "load a demo" plays t6. |
| SK-049 Accessibility | ◐ | Labels / values / adjustable actions on all custom controls; not audited with VoiceOver on a device. |
| SK-050 Diagnostics export | ✅ | Share sheet. |
| SK-051 Crash / analytics | ✅ | Opt-in MetricKit only. |

## Sprint 5 / 6+
All ⛔ — need an Apple Developer account, a physical device for latency/thermal
measurement, design/video production, or business development.

## Known gaps worth fixing next
1. Compressor (SK-022), mix-mode routing (SK-026) and per-channel FX (SK-032) are UI-only.
2. The WSOLA loop wrap restarts the stretcher at the loop start, which gives a short
   window ramp at the seam. The linear (0 %) path is seamless.
3. Pattern decks (t3–t5) cannot loop or hot-cue — they have no clip. Bundling full-length
   demo audio (SK-036) makes this moot.
4. Deck time display uses the decoded clip length, so the 2 s fixtures show as 0:02 —
   intended, but it makes the demo library look thin until real demo audio ships.
