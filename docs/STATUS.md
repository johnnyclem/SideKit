# Ticket status vs. SideKit_Sprint_Tickets.md

Honest status after this PR. "Done" means real, working code shipped in this repo —
none of it has been compiled or run (no macOS/Xcode toolchain in the environment that
produced it), so treat it as *ready for a first Xcode build + device test pass*, not
as verified. Legal, App Store Connect, physical-hardware QA, and marketing/business
tickets were **not attempted** — they need a human with the relevant accounts, a real
Sidekick unit, and legal authority, none of which an engineering PR can provide.

Legend: ✅ done this PR · ➖ pre-existing (before this PR) · ◐ partial/UI-only stub · ⛔ not started (needs a human/account/hardware)

## Sprint 0 — Foundation
| Ticket | Status | Notes |
|---|---|---|
| SK-001 Xcode workspace | ➖ | Pre-existing. |
| SK-002 CI | ✅ | `.github/workflows/ci.yml`: SwiftLint, `swift test` on `SideKitCore`, `xcodebuild build`. Added the shared scheme this needed. |
| SK-003 Design tokens | ➖ | Pre-existing `Theme.swift`. |
| SK-004 AudioEngine skeleton | ◐ | Swift/AVAudioEngine, not C++. Real, functional, tested informally by inspection only — see ARCHITECTURE.md. |
| SK-005 App Store Connect shell | ⛔ | Needs a real Apple Developer / ASC account. |
| SK-006 Trademark screen | ⛔ | Needs a human legal search; not something to fabricate. |

## Sprint 1 — Decks Core
| Ticket | Status | Notes |
|---|---|---|
| SK-010 File decode | ✅ | `LibraryStore.swift`, real `AVAudioFile` decode on import. |
| SK-011 Deck A transport | ✅ | Real play/pause/seek/restart via `AudioEngine` file mode. Fade is `pause()`-based, not a verified ≤5ms equal-power ramp. |
| SK-012 Pitch ±8% | ✅ | `AVAudioUnitVarispeed`, vinyl-style (pitch+tempo together). |
| SK-013 Waveform | ✅ (imports) / ➖ (demo) | Real cached peaks for imported files; demo tracks still use the original procedural placeholder (no bundled audio asset). |
| SK-014 BPM | ✅ (imports) / ➖ (demo) | ID3/iTunes tag read + onset-interval fallback. |
| SK-015 Background audio + interruption | ✅ | Background mode + route-change UI were pre-existing; interruption pause/resume added this PR. |
| SK-016 Deck UI shell | ➖/✅ | Pre-existing, extended with hot cues/loop UI this PR. |

## Sprint 2 — Mixer + USB
| Ticket | Status | Notes |
|---|---|---|
| SK-020 Dual deck engine | ➖/✅ | Pre-existing pattern engine; file-mode dual playback added. |
| SK-021 Channel strip DSP | ➖ | Pre-existing. |
| SK-022 Compressor modes | ◐ | UI picker only — `comp`/`compAmount` are not wired to any DSP node. **Not implemented.** |
| SK-023 Crossfader | ➖/✅ | Pre-existing; refactored onto tested `Tempo.equalPowerCrossfade`. |
| SK-024 Meters | ➖ | Pre-existing. |
| SK-025 USB Sidekick discovery | ◐ | Route/name-match detection is real software; **cannot be QA'd without a physical Sidekick.** |
| SK-026 Mix modes | ◐ | Segmented control exists; switching mode does not yet change audio routing. **UI-only stub**, same as before this PR. |
| SK-027 USB matrix | ✅ | Persisted per mode in `USBMatrixStore`, editable via menu. |
| SK-028 Source selector | ◐ | Selector exists; "unavailable sources disabled with reason" not implemented. |
| SK-029 Mixer tab UI | ➖ | Pre-existing. |

## Sprint 3 — FX + Library
| Ticket | Status | Notes |
|---|---|---|
| SK-030 FX graph | ➖ | Pre-existing, all 6 FX. |
| SK-031 Force pad | ➖/✅ | Pre-existing; accessibility + Reduce Motion added this PR. |
| SK-032 Per-channel FX assign + series/parallel | ◐ | Toggles exist in state/UI; the FX bus is still a single shared filter/delay, not truly per-channel routable. |
| SK-033 Deck B + Sync | ➖ | Pre-existing. |
| SK-034 Hot cues + loops | ✅ | 4 cues, loop in + auto-length (½/2×), beat quantized, Pro-gated. |
| SK-035 Library import | ✅ | Document picker, metadata, search, load A/B. |
| SK-036 Demo tracks + empty states | ◐ | 6 demo tracks ship as metadata + synth patterns (no bundled royalty-free **audio asset**, same gap as before this PR); user-library empty state added this PR. |
| SK-037 Demo mode without hardware | ➖ | Pre-existing — app is fully usable with no Sidekick. |

## Sprint 4 — Hardware Brain + Pro
| Ticket | Status | Notes |
|---|---|---|
| SK-040 Core MIDI + detection | ✅ | `MIDIManager.swift`. |
| SK-041 Factory MIDI map | ✅ | Original map (`FactoryMIDIMap`), free once Sidekick MIDI is detected. |
| SK-042 MIDI learn | ✅ | Per-target learn mode, persisted bindings. |
| SK-043 Snapshots | ✅ | Save/recall, named, up to 16, Pro-gated. |
| SK-044 StoreKit 2 Pro | ✅ | Code-complete non-consumable + offline restore. **Needs a real ASC product (`com.johnnyclem.SideKit.pro`) configured before it can actually purchase.** |
| SK-045 Paywall UX | ✅ | Shown only on a gated action, never before first audio. |
| SK-046 Pitch ±16% Pro gate | ✅ | Free capped at ±8%. |
| SK-047 iPad layout | ✅ | Two-column landscape, `TARGETED_DEVICE_FAMILY = "1,2"`. |
| SK-048 Onboarding | ✅ | Skippable, connect-hardware-or-load-demo. |
| SK-049 Accessibility | ◐ | Meaningful VoiceOver label/value + Reduce Motion pass added; not a full audited pass on a real device with VoiceOver running. |
| SK-050 Diagnostics export | ✅ | Share-sheet export, no PII beyond device model. |
| SK-051 Crash/analytics | ✅ | On-device MetricKit only, opt-in, no third-party SDK. |

## Sprint 5 — Beta → App Store
All ⛔ not started — every ticket here needs an Apple Developer/ASC account, a physical
device for measurement, or design/video production:
SK-052 (external TestFlight), SK-053 (screenshots/preview video/listing copy), SK-054
(hosted privacy policy + support URL + compliance sign-off — `PrivacyInfo.xcprivacy` was
added this PR as a head start), SK-055 (latency/thermal measurement on real hardware),
SK-056 (App Review submission).

## Sprint 6+ — Growth
All ⛔ not started: SK-060 Motion Control, SK-061 Tap-FX sequencer, SK-062 Apple Music
access, SK-063 Playlists/iCloud sync, SK-064 content pack IAP, SK-065 Ableton Link,
SK-066 TE partnership outreach (business development, not engineering).

## Next steps for a human
1. Open in Xcode, resolve any build errors (this was authored without a macOS toolchain
   available to compile-check it).
2. Get a real Sidekick unit for SK-025/026/041 hardware QA.
3. Wire SK-022 (compressor DSP) and SK-026/032 (real per-mode/per-channel routing) —
   flagged above as UI-only stubs.
4. Bundle real royalty-free demo audio (SK-036) so the demo library isn't synthesized.
5. Set up App Store Connect, the Pro IAP product, privacy/support pages, and run the
   Sprint 5 business/compliance tickets.
