# SideKit — Native App Sprint Backlog
### Swift / C++ / Obj-C → App Store

| Field | Value |
|---|---|
| Version | 1.0 |
| Date | 2026-08-10 |
| Cadence | Sprint 0 = 1 week; Sprints 1–5 = 2 weeks; Sprint 6+ ongoing |
| Total tickets | 55 |
| Total points | 254 |
| Team shape | Audio eng, iOS eng, Design, Product/Founder |

## How to use
- **P0** = must ship for that sprint exit
- **Points** = relative effort (Fibonacci-ish: 1/2/3/5/8)
- **Size** XS–XL for planning conversations
- Pull tickets into Linear/Jira/GitHub Projects with same IDs (`SK-xxx`)
- Do not start a ticket until `dependsOn` are done or explicitly waived

## Capacity guide (indie / small team)
| People | Sustainable pts / 2-week sprint |
|---|---|
| 1 full-stack + audio part-time | 25–35 |
| 2 eng (1 audio-focused) | 45–60 |
| 3 eng + design | 70–90 |

If overloaded, cut P2 first, then defer P1 MIDI learn / iPad polish into Sprint 5 buffer.

## Release train
```
S0 Foundation → S1 Deck A → S2 Mixer+USB → S3 FX+Library → S4 Hardware+Pro → S5 Beta/Store → S6+ Growth
```

---

## Sprint 0 — Foundation

**Goal:** Native project shell, CI, design tokens, and audio engine skeleton ready for feature work.  
**Duration:** 1 week · **Load:** 6 tickets / 21 pts

### Exit criteria
- Xcode project builds on iPhone 15+ simulator + device
- C++ audio engine ring-buffers unit-tested offline
- Design system tokens land in SwiftUI
- ASC app record + TestFlight internal group created

### Tickets

| ID | Title | Epic | Pri | Size | Pts | Owner | Depends |
|---|---|---|---|---|---|---|---|
| SK-001 | Create native Xcode workspace (SwiftUI + C++ target) | Foundation | P0 | M | 5 | Tech lead | — |
| SK-002 | CI: build, unit test, SwiftLint on PR | Foundation | P0 | S | 3 | Eng | SK-001 |
| SK-003 | Design tokens + SwiftUI theme (SideKit chrome) | Design | P0 | S | 3 | Design + Eng | SK-001 |
| SK-004 | AudioEngine skeleton: lock-free param queues + 48 kHz render | Audio | P0 | L | 8 | Audio eng | SK-001 |
| SK-005 | App Store Connect shell + privacy nutrition draft | Compliance | P1 | XS | 1 | Product | — |
| SK-006 | Trademark screen SideKit + alternative names | Legal | P0 | XS | 1 | Founder | — |

#### SK-001 — Create native Xcode workspace (SwiftUI + C++ target)
- **Epic:** Foundation · **PRD:** PRD-01 · **Owner:** Tech lead
- **Priority/Size/Points:** P0 / M / 5
- **Acceptance:**
  - App target iOS 17+, SwiftUI lifecycle
  - C++ static lib linked into app; hello render callback runs
  - Debug + Release schemes; device signing configured

#### SK-002 — CI: build, unit test, SwiftLint on PR
- **Epic:** Foundation · **PRD:** PRD-01 · **Owner:** Eng
- **Priority/Size/Points:** P0 / S / 3
- **Depends on:** SK-001
- **Acceptance:**
  - GitHub Actions (or Xcode Cloud) fails on compile error
  - C++ gtest or Catch2 offline DSP tests run in CI

#### SK-003 — Design tokens + SwiftUI theme (SideKit chrome)
- **Epic:** Design · **PRD:** PRD-07 · **Owner:** Design + Eng
- **Priority/Size/Points:** P0 / S / 3
- **Depends on:** SK-001
- **Acceptance:**
  - Color/type/radius tokens match web prototype language
  - Dark-only v1; Dynamic Type on non-critical labels

#### SK-004 — AudioEngine skeleton: lock-free param queues + 48 kHz render
- **Epic:** Audio · **PRD:** PRD-01 · **Owner:** Audio eng
- **Priority/Size/Points:** P0 / L / 8
- **Depends on:** SK-001
- **Acceptance:**
  - No allocations on audio thread (TSAN/debug asserts)
  - Swift posts transport/params via SPSC ring buffer
  - Silence output validates graph start/stop

#### SK-005 — App Store Connect shell + privacy nutrition draft
- **Epic:** Compliance · **PRD:** PRD-08 · **Owner:** Product
- **Priority/Size/Points:** P1 / XS / 1
- **Acceptance:**
  - Bundle ID reserved; internal TestFlight group exists
  - Draft privacy labels documented (no tracking at launch)

#### SK-006 — Trademark screen SideKit + alternative names
- **Epic:** Legal · **PRD:** PRD-00 · **Owner:** Founder
- **Priority/Size/Points:** P0 / XS / 1
- **Acceptance:**
  - USPTO / EUIPO quick search logged
  - Fallback codename shortlist if conflict

---

## Sprint 1 — Decks Core

**Goal:** One reliable virtual deck with decode, transport, pitch, and waveform — no hardware yet.  
**Duration:** 2 weeks · **Load:** 7 tickets / 34 pts

### Exit criteria
- Play/pause/seek click-free on device
- Pitch ±8% without zipper noise
- Waveform interactive under load
- Background audio survives lock screen

### Tickets

| ID | Title | Epic | Pri | Size | Pts | Owner | Depends |
|---|---|---|---|---|---|---|---|
| SK-010 | File decode path (AAC/MP3/ALAC/WAV/AIFF → float PCM) | Decks | P0 | M | 5 | Audio eng | SK-004 |
| SK-011 | Deck A transport: play, pause, restart, seek | Decks | P0 | M | 5 | Audio eng | SK-010 |
| SK-012 | Pitch ±8% time-stretch (WSOLA or phase vocoder v1) | Decks | P0 | L | 8 | Audio eng | SK-011 |
| SK-013 | Waveform overview + playhead (Deck A) | Decks | P0 | M | 5 | Eng | SK-010 |
| SK-014 | BPM display: tags + simple onset fallback | Decks | P0 | S | 3 | Eng | SK-010 |
| SK-015 | Background audio session + route change handling | Audio | P0 | S | 3 | Eng | SK-004 |
| SK-016 | Deck UI shell (SwiftUI) wired to engine | Decks | P0 | M | 5 | Eng | SK-003, SK-011 |

#### SK-010 — File decode path (AAC/MP3/ALAC/WAV/AIFF → float PCM) ✅
- **Epic:** Decks · **PRD:** PRD-03 · **Owner:** Audio eng
- **Priority/Size/Points:** P0 / M / 5
- **Depends on:** SK-004
- **Acceptance:**
  - ExtAudioFile / AudioToolbox decode to engine buffer
  - Resample non-48k files offline on load
  - Error UI for unsupported codecs

#### SK-011 — Deck A transport: play, pause, restart, seek
- **Epic:** Decks · **PRD:** PRD-03 D-01 · **Owner:** Audio eng
- **Priority/Size/Points:** P0 / M / 5
- **Depends on:** SK-010
- **Acceptance:**
  - Start/stop equal-power fade ≤ 5 ms (no click)
  - Seek lands within 1 frame of target
  - UI state mirrors engine within 1 render quantum

#### SK-012 — Pitch ±8% time-stretch (WSOLA or phase vocoder v1)
- **Epic:** Decks · **PRD:** PRD-03 D-02 · **Owner:** Audio eng
- **Priority/Size/Points:** P0 / L / 8
- **Depends on:** SK-011
- **Acceptance:**
  - Continuous pitch drag without zipper noise
  - CPU < 15% single deck on iPhone 15
  - Reset to 0% on double-tap

#### SK-013 — Waveform overview + playhead (Deck A)
- **Epic:** Decks · **PRD:** PRD-03 D-05 · **Owner:** Eng
- **Priority/Size/Points:** P0 / M / 5
- **Depends on:** SK-010
- **Acceptance:**
  - Cached peaks on import
  - Tap-to-seek on waveform
  - 60 fps scroll/playhead while audio runs

#### SK-014 — BPM display: tags + simple onset fallback
- **Epic:** Decks · **PRD:** PRD-03 D-03 · **Owner:** Eng
- **Priority/Size/Points:** P0 / S / 3
- **Depends on:** SK-010
- **Acceptance:**
  - Reads embedded BPM when present
  - Fallback detection good enough for demo tracks

#### SK-015 — Background audio session + route change handling
- **Epic:** Audio · **PRD:** PRD-01 · **Owner:** Eng
- **Priority/Size/Points:** P0 / S / 3
- **Depends on:** SK-004
- **Acceptance:**
  - audio background mode enabled
  - Interruption (call) pauses and resumes cleanly
  - Route change notification updates UI

#### SK-016 — Deck UI shell (SwiftUI) wired to engine
- **Epic:** Decks · **PRD:** PRD-03 / PRD-07 · **Owner:** Eng
- **Priority/Size/Points:** P0 / M / 5
- **Depends on:** SK-003, SK-011
- **Acceptance:**
  - Play, pitch, seek, BPM visible
  - Touch targets ≥ 44 pt
  - Matches prototype hierarchy

---

## Sprint 2 — Mixer + USB

**Goal:** Dual channels, crossfader, and Sidekick class-compliant USB discovery as primary I/O.  
**Duration:** 2 weeks · **Load:** 10 tickets / 49 pts

### Exit criteria
- Hot-plug Sidekick without crash
- External + internal mix modes work
- EQ styles + meters match PRD
- One-interface rule handled with clear UI

### Tickets

| ID | Title | Epic | Pri | Size | Pts | Owner | Depends |
|---|---|---|---|---|---|---|---|
| SK-020 | Dual deck engine path + independent buffers | Decks | P0 | M | 5 | Audio eng | SK-011, SK-012 |
| SK-021 | Channel strip DSP: gain, 3-band EQ, mute, fader | Mixer | P0 | M | 5 | Audio eng | SK-004 |
| SK-022 | Compressor modes Off/Soft/Hard/Pump | Mixer | P0 | S | 3 | Audio eng | SK-021 |
| SK-023 | Crossfader equal-power + master/cue/phones gains | Mixer | P0 | S | 3 | Audio eng | SK-020, SK-021 |
| SK-024 | Peak/RMS meters on CH1, CH2, master | Mixer | P0 | S | 2 | Eng | SK-021 |
| SK-025 | USB Sidekick discovery (AVAudioSession route + name match) | Hardware | P0 | L | 8 | Eng | SK-015 |
| SK-026 | Mix modes: External mixer vs Internal mix vs MIDI-only | Hardware | P0 | L | 8 | Audio eng | SK-025, SK-023 |
| SK-027 | USB 8×4 channel matrix UI | Hardware | P0 | M | 5 | Eng | SK-025 |
| SK-028 | Source selector per channel (deck/USB/mic/aux/hardware) | Mixer | P0 | M | 5 | Eng | SK-021, SK-026 |
| SK-029 | Mixer tab UI (dual strips, knobs, faders, XF) | Mixer | P0 | M | 5 | Eng | SK-003, SK-021, SK-023 |

#### SK-020 — Dual deck engine path + independent buffers
- **Epic:** Decks · **PRD:** PRD-03 · **Owner:** Audio eng
- **Priority/Size/Points:** P0 / M / 5
- **Depends on:** SK-011, SK-012
- **Acceptance:**
  - Deck A and B play simultaneously
  - No crosstalk when one is muted

#### SK-021 — Channel strip DSP: gain, 3-band EQ, mute, fader
- **Epic:** Mixer · **PRD:** PRD-02 M-01 · **Owner:** Audio eng
- **Priority/Size/Points:** P0 / M / 5
- **Depends on:** SK-004
- **Acceptance:**
  - Gain ±24 dB; EQ styles DJ/Studio/Param curves
  - Parameter smoothing; no zipper

#### SK-022 — Compressor modes Off/Soft/Hard/Pump
- **Epic:** Mixer · **PRD:** PRD-02 M-03 · **Owner:** Audio eng
- **Priority/Size/Points:** P0 / S / 3
- **Depends on:** SK-021
- **Acceptance:**
  - Mode switch realtime
  - Amount 0–1 audible

#### SK-023 — Crossfader equal-power + master/cue/phones gains
- **Epic:** Mixer · **PRD:** PRD-02 M-04 M-05 · **Owner:** Audio eng
- **Priority/Size/Points:** P0 / S / 3
- **Depends on:** SK-020, SK-021
- **Acceptance:**
  - Center = both decks equal power
  - Cue does not leak to master when phones engaged

#### SK-024 — Peak/RMS meters on CH1, CH2, master
- **Epic:** Mixer · **PRD:** PRD-02 M-08 · **Owner:** Eng
- **Priority/Size/Points:** P0 / S / 2
- **Depends on:** SK-021
- **Acceptance:**
  - UI meters @ ~30–60 Hz
  - Soft clip indication near 0 dBFS

#### SK-025 — USB Sidekick discovery (AVAudioSession route + name match)
- **Epic:** Hardware · **PRD:** PRD-06 H-01 H-02 · **Owner:** Eng
- **Priority/Size/Points:** P0 / L / 8
- **Depends on:** SK-015
- **Acceptance:**
  - Detect connect/disconnect on device
  - Linked / offline / partial states in UI
  - Works on iPhone 15+ USB-C; Lightning adapter documented
- **Notes:** Requires physical Sidekick for device QA

#### SK-026 — Mix modes: External mixer vs Internal mix vs MIDI-only
- **Epic:** Hardware · **PRD:** PRD-02 source routing · **Owner:** Audio eng
- **Priority/Size/Points:** P0 / L / 8
- **Depends on:** SK-025, SK-023
- **Acceptance:**
  - External: decks → Sidekick inputs mapping
  - Internal: SideKit sums; Sidekick is output device
  - Mode switch without crash; user confirm on destructive switch

#### SK-027 — USB 8×4 channel matrix UI
- **Epic:** Hardware · **PRD:** PRD-06 H-03 · **Owner:** Eng
- **Priority/Size/Points:** P0 / M / 5
- **Depends on:** SK-025
- **Acceptance:**
  - Map logical roles to in/out pairs
  - Persist last matrix per mode

#### SK-028 — Source selector per channel (deck/USB/mic/aux/hardware)
- **Epic:** Mixer · **PRD:** PRD-02 M-06 M-07 · **Owner:** Eng
- **Priority/Size/Points:** P0 / M / 5
- **Depends on:** SK-021, SK-026
- **Acceptance:**
  - All PRD sources listed
  - Unavailable sources disabled with reason

#### SK-029 — Mixer tab UI (dual strips, knobs, faders, XF)
- **Epic:** Mixer · **PRD:** PRD-02 / PRD-07 · **Owner:** Eng
- **Priority/Size/Points:** P0 / M / 5
- **Depends on:** SK-003, SK-021, SK-023
- **Acceptance:**
  - Portrait usable on 390pt width
  - Vertical faders + knob drag gestures

---

## Sprint 3 — FX + Library

**Goal:** Full six-FX pad, dual decks, and local library load path.  
**Duration:** 2 weeks · **Load:** 8 tickets / 39 pts

### Exit criteria
- Pad engage < 10 ms perceived latency
- All six FX + series/parallel
- Files import + load to A/B
- Demo mode works without Sidekick

### Tickets

| ID | Title | Epic | Pri | Size | Pts | Owner | Depends |
|---|---|---|---|---|---|---|---|
| SK-030 | FX graph: Filter, Delay, Tape, Repeat, Tremolo, Siren | FX | P0 | L | 8 | Audio eng | SK-004, SK-023 |
| SK-031 | Force pad XY + momentary/latch + depth | FX | P0 | M | 5 | Eng | SK-030 |
| SK-032 | Per-channel FX assign + series/parallel bus | FX | P0 | S | 3 | Audio eng | SK-030, SK-021 |
| SK-033 | Deck B full UI + Sync (match pitch to source deck) | Decks | P0 | M | 5 | Eng | SK-020, SK-016 |
| SK-034 | Hot cues (4) + loop in/out + auto-loop lengths | Decks | P1 | M | 5 | Eng | SK-011 |
| SK-035 | Library: Files import, metadata, search, load A/B | Library | P0 | L | 8 | Eng | SK-010 |
| SK-036 | Bundled demo tracks + empty states | Library | P0 | S | 2 | Product + Eng | SK-035 |
| SK-037 | Demo mode without Sidekick (speakers/headphones) | Hardware | P0 | S | 3 | Eng | SK-026, SK-033 |

#### SK-030 — FX graph: Filter, Delay, Tape, Repeat, Tremolo, Siren
- **Epic:** FX · **PRD:** PRD-04 F-01 · **Owner:** Audio eng
- **Priority/Size/Points:** P0 / L / 8
- **Depends on:** SK-004, SK-023
- **Acceptance:**
  - All six FX audible and parameterizable
  - Bypass is click-free

#### SK-031 — Force pad XY + momentary/latch + depth
- **Epic:** FX · **PRD:** PRD-04 F-02 F-03 F-05 · **Owner:** Eng
- **Priority/Size/Points:** P0 / M / 5
- **Depends on:** SK-030
- **Acceptance:**
  - Touch → param < 10 ms to first sample change
  - Hold engage + latch modes
  - Pressure used when available (iPhone 3D not required)

#### SK-032 — Per-channel FX assign + series/parallel bus
- **Epic:** FX · **PRD:** PRD-04 F-03 F-04 · **Owner:** Audio eng
- **Priority/Size/Points:** P0 / S / 3
- **Depends on:** SK-030, SK-021
- **Acceptance:**
  - Assign toggles route correctly
  - Series/parallel switch live

#### SK-033 — Deck B full UI + Sync (match pitch to source deck)
- **Epic:** Decks · **PRD:** PRD-03 D-04 · **Owner:** Eng
- **Priority/Size/Points:** P0 / M / 5
- **Depends on:** SK-020, SK-016
- **Acceptance:**
  - SYNC sets target pitch within ±0.1% of source effective BPM
  - Beat-match toggle state persisted

#### SK-034 — Hot cues (4) + loop in/out + auto-loop lengths
- **Epic:** Decks · **PRD:** PRD-03 D-07 D-08 · **Owner:** Eng
- **Priority/Size/Points:** P1 / M / 5
- **Depends on:** SK-011
- **Acceptance:**
  - Set/jump/clear cues
  - Loop quantize to beat when BPM known

#### SK-035 — Library: Files import, metadata, search, load A/B
- **Epic:** Library · **PRD:** PRD-05 L-01–L-05 · **Owner:** Eng
- **Priority/Size/Points:** P0 / L / 8
- **Depends on:** SK-010
- **Acceptance:**
  - Import via document picker + share sheet
  - BPM/key/duration stored
  - Load target Deck A or B

#### SK-036 — Bundled demo tracks + empty states
- **Epic:** Library · **PRD:** PRD-08 2.1 · **Owner:** Product + Eng
- **Priority/Size/Points:** P0 / S / 2
- **Depends on:** SK-035
- **Acceptance:**
  - ≥ 4 royalty-safe demos ship in bundle
  - Empty library CTA is clear

#### SK-037 — Demo mode without Sidekick (speakers/headphones)
- **Epic:** Hardware · **PRD:** PRD-06 H-07 · **Owner:** Eng
- **Priority/Size/Points:** P0 / S / 3
- **Depends on:** SK-026, SK-033
- **Acceptance:**
  - Full dual-deck mix on device output
  - Banner: connect Sidekick for hardware routing

---

## Sprint 4 — Hardware Brain + Pro

**Goal:** MIDI Control maps, snapshots, StoreKit Pro unlock, and iPad layout.  
**Duration:** 2 weeks · **Load:** 10 tickets / 44 pts

### Exit criteria
- Sidekick MIDI maps for hardware knobs
- Scene snapshot save/recall
- Pro IAP restore works offline
- iPad adaptive layout usable in landscape

### Tickets

| ID | Title | Epic | Pri | Size | Pts | Owner | Depends |
|---|---|---|---|---|---|---|---|
| SK-040 | Core MIDI endpoints + Sidekick MIDI Control detection | Hardware | P0 | M | 5 | Eng | SK-025 |
| SK-041 | Factory MIDI maps for Sidekick knobs/faders/pad | Hardware | P1 | L | 8 | Eng | SK-040, SK-029, SK-031 |
| SK-042 | MIDI learn UI for custom bindings | Hardware | P1 | M | 5 | Eng | SK-040 |
| SK-043 | Mixer snapshots / scenes save-recall | Mixer | P1 | M | 5 | Eng | SK-029, SK-032 |
| SK-044 | StoreKit 2: SideKit Pro non-consumable + restore | Monetization | P0 | M | 5 | Eng | SK-005 |
| SK-045 | Paywall + feature gates UX (no paywall before first audio) | Monetization | P0 | S | 3 | Product + Eng | SK-044 |
| SK-046 | Pitch ±16% + Pro-only deck features gate | Decks | P1 | S | 2 | Eng | SK-012, SK-044 |
| SK-047 | iPad adaptive layout (landscape mixer + decks) | Design | P1 | M | 5 | Eng | SK-029, SK-033 |
| SK-048 | Onboarding ≤ 60s: connect hardware OR load demo | UX | P0 | S | 3 | Eng | SK-037, SK-036 |
| SK-049 | VoiceOver labels + Reduce Motion pass | A11y | P1 | S | 3 | Eng | SK-029, SK-031 |

#### SK-040 — Core MIDI endpoints + Sidekick MIDI Control detection
- **Epic:** Hardware · **PRD:** PRD-06 H-05 · **Owner:** Eng
- **Priority/Size/Points:** P0 / M / 5
- **Depends on:** SK-025
- **Acceptance:**
  - List MIDI sources/destinations
  - Detect Sidekick MIDI Control mode

#### SK-041 — Factory MIDI maps for Sidekick knobs/faders/pad
- **Epic:** Hardware · **PRD:** PRD-06 H-05 / 3.1.4 · **Owner:** Eng
- **Priority/Size/Points:** P1 / L / 8
- **Depends on:** SK-040, SK-029, SK-031
- **Acceptance:**
  - Preset map unlocks on Sidekick connect without IAP
  - Gain, EQ, faders, XF, FX pad mappable
- **Notes:** Community djay maps are reference only — write original maps

#### SK-042 — MIDI learn UI for custom bindings
- **Epic:** Hardware · **PRD:** PRD-02 M-10 · **Owner:** Eng
- **Priority/Size/Points:** P1 / M / 5
- **Depends on:** SK-040
- **Acceptance:**
  - Learn mode captures CC/note
  - Bindings persist

#### SK-043 — Mixer snapshots / scenes save-recall
- **Epic:** Mixer · **PRD:** PRD-02 M-09 · **Owner:** Eng
- **Priority/Size/Points:** P1 / M / 5
- **Depends on:** SK-029, SK-032
- **Acceptance:**
  - Save ≥ 8 scenes
  - Instant recall; name + reorder

#### SK-044 — StoreKit 2: SideKit Pro non-consumable + restore
- **Epic:** Monetization · **PRD:** Monetization / PRD-08 3.1.1 · **Owner:** Eng
- **Priority/Size/Points:** P0 / M / 5
- **Depends on:** SK-005
- **Acceptance:**
  - Purchase + restore offline-safe
  - Pro gates dual-deck advanced, full FX, cues, snapshots
  - Free tier still useful (1 deck, basic FX, hardware link)

#### SK-045 — Paywall + feature gates UX (no paywall before first audio)
- **Epic:** Monetization · **PRD:** Monetization · **Owner:** Product + Eng
- **Priority/Size/Points:** P0 / S / 3
- **Depends on:** SK-044
- **Acceptance:**
  - Paywall only after value moment
  - Clear Free vs Pro comparison
  - No ads

#### SK-046 — Pitch ±16% + Pro-only deck features gate
- **Epic:** Decks · **PRD:** PRD-03 / Monetization · **Owner:** Eng
- **Priority/Size/Points:** P1 / S / 2
- **Depends on:** SK-012, SK-044
- **Acceptance:**
  - Free limited to ±8%
  - Pro unlocks ±16% + hot cues/loops

#### SK-047 — iPad adaptive layout (landscape mixer + decks)
- **Epic:** Design · **PRD:** PRD-07 · **Owner:** Eng
- **Priority/Size/Points:** P1 / M / 5
- **Depends on:** SK-029, SK-033
- **Acceptance:**
  - No horizontal overflow
  - Two-column mixer+decks in landscape

#### SK-048 — Onboarding ≤ 60s: connect hardware OR load demo
- **Epic:** UX · **PRD:** PRD-07 · **Owner:** Eng
- **Priority/Size/Points:** P0 / S / 3
- **Depends on:** SK-037, SK-036
- **Acceptance:**
  - Skipable
  - Completes to first sound in < 60s for new user

#### SK-049 — VoiceOver labels + Reduce Motion pass
- **Epic:** A11y · **PRD:** PRD-07 · **Owner:** Eng
- **Priority/Size/Points:** P1 / S / 3
- **Depends on:** SK-029, SK-031
- **Acceptance:**
  - All controls labeled
  - Non-essential pad animations respect Reduce Motion

---

## Sprint 5 — Beta → App Store

**Goal:** External TestFlight, polish, compliance, 1.0 submission.  
**Duration:** 2 weeks · **Load:** 7 tickets / 26 pts

### Exit criteria
- Crash-free ≥ 99.5% on beta cohort
- App Review assets + privacy labels complete
- Support FAQ + diagnostics export live
- 1.0 submitted (or approved)

### Tickets

| ID | Title | Epic | Pri | Size | Pts | Owner | Depends |
|---|---|---|---|---|---|---|---|
| SK-050 | Diagnostics export (route, SR, device names, build) | Support | P0 | S | 2 | Eng | SK-025 |
| SK-051 | Crash reporting + analytics (opt-in, no ad SDKs) | Foundation | P0 | S | 3 | Eng | SK-001 |
| SK-052 | External TestFlight (200–500 Sidekick owners) | GTM | P0 | M | 5 | Product | SK-044, SK-050 |
| SK-053 | App Store screenshots, preview video, listing copy | GTM | P0 | M | 5 | Design + Product | SK-047 |
| SK-054 | Privacy policy, support URL, ASC compliance checklist | Compliance | P0 | S | 3 | Product + Legal | SK-005 |
| SK-055 | Performance pass: latency budget + thermal | Audio | P0 | M | 5 | Audio eng | SK-030, SK-026 |
| SK-056 | 1.0 App Review submission | GTM | P0 | S | 3 | Product + Eng | SK-052, SK-053, SK-054, SK-055 |

#### SK-050 — Diagnostics export (route, SR, device names, build)
- **Epic:** Support · **PRD:** PRD-09 · **Owner:** Eng
- **Priority/Size/Points:** P0 / S / 2
- **Depends on:** SK-025
- **Acceptance:**
  - Share sheet export
  - No PII beyond device model

#### SK-051 — Crash reporting + analytics (opt-in, no ad SDKs)
- **Epic:** Foundation · **PRD:** PRD-01 / PRD-08 · **Owner:** Eng
- **Priority/Size/Points:** P0 / S / 3
- **Depends on:** SK-001
- **Acceptance:**
  - Crash-free metric visible
  - Analytics off by default or privacy-safe aggregate

#### SK-052 — External TestFlight (200–500 Sidekick owners)
- **Epic:** GTM · **PRD:** PRD-09 · **Owner:** Product
- **Priority/Size/Points:** P0 / M / 5
- **Depends on:** SK-044, SK-050
- **Acceptance:**
  - Hardware matrix covered: USB-C + one Lightning adapter case
  - Feedback form + critical bug = 0 gate

#### SK-053 — App Store screenshots, preview video, listing copy
- **Epic:** GTM · **PRD:** PRD-08 / PRD-09 · **Owner:** Design + Product
- **Priority/Size/Points:** P0 / M / 5
- **Depends on:** SK-047
- **Acceptance:**
  - 6.5" + 12.9" shots
  - 15–30s preview: plug in → decks → FX
  - No unlicensed TE trademarks/logos

#### SK-054 — Privacy policy, support URL, ASC compliance checklist
- **Epic:** Compliance · **PRD:** PRD-08 · **Owner:** Product + Legal
- **Priority/Size/Points:** P0 / S / 3
- **Depends on:** SK-005
- **Acceptance:**
  - Live HTTPS privacy + support pages
  - 3.1.1 / 3.1.4 / 2.5.4 checklist signed off

#### SK-055 — Performance pass: latency budget + thermal
- **Epic:** Audio · **PRD:** PRD-01 · **Owner:** Audio eng
- **Priority/Size/Points:** P0 / M / 5
- **Depends on:** SK-030, SK-026
- **Acceptance:**
  - Round-trip < 12 ms target on supported devices with Sidekick
  - Buffer size preference 128/256/512 exposed
  - 30 min stress: no thermal audio dropouts

#### SK-056 — 1.0 App Review submission
- **Epic:** GTM · **PRD:** PRD-09 · **Owner:** Product + Eng
- **Priority/Size/Points:** P0 / S / 3
- **Depends on:** SK-052, SK-053, SK-054, SK-055
- **Acceptance:**
  - Binary uploaded
  - Review notes mention optional Sidekick hardware

---

## Sprint 6+ — Growth

**Goal:** Post-1.0: automation, Cloud, packs, Ableton Link.  
**Duration:** ongoing · **Load:** 7 tickets / 41 pts

### Exit criteria
- Motion Control automation shipping
- First content pack live
- Cloud sync optional sub behind Pro

### Tickets

| ID | Title | Epic | Pri | Size | Pts | Owner | Depends |
|---|---|---|---|---|---|---|---|
| SK-060 | Motion Control: record pad gestures as BPM-synced automation | FX | P1 | L | 8 | Audio eng | SK-031 |
| SK-061 | Tap-FX 2-bar step sequencer | FX | P1 | M | 5 | Eng | SK-030 |
| SK-062 | Optional Media Library / Apple Music access | Library | P2 | M | 5 | Eng | SK-035 |
| SK-063 | Playlists/crates + iCloud sync (Cloud sub) | Library | P2 | L | 8 | Eng | SK-044, SK-035 |
| SK-064 | First content pack IAP (samples or FX presets) | Monetization | P1 | M | 5 | Product + Eng | SK-044 |
| SK-065 | Ableton Link integration | Decks | P2 | L | 8 | Audio eng | SK-033 |
| SK-066 | TE partnership outreach package | GTM | P1 | S | 2 | Founder | SK-056 |

#### SK-060 — Motion Control: record pad gestures as BPM-synced automation
- **Epic:** FX · **PRD:** PRD-04 F-06 · **Owner:** Audio eng
- **Priority/Size/Points:** P1 / L / 8
- **Depends on:** SK-031
- **Acceptance:**
  - Record/play automation clips
  - Sample-accurate to transport

#### SK-061 — Tap-FX 2-bar step sequencer
- **Epic:** FX · **PRD:** PRD-04 F-07 · **Owner:** Eng
- **Priority/Size/Points:** P1 / M / 5
- **Depends on:** SK-030
- **Acceptance:**
  - 2-bar grid
  - Per-step FX amount

#### SK-062 — Optional Media Library / Apple Music access
- **Epic:** Library · **PRD:** PRD-05 L-02 · **Owner:** Eng
- **Priority/Size/Points:** P2 / M / 5
- **Depends on:** SK-035
- **Acceptance:**
  - Permission in-context
  - Graceful deny

#### SK-063 — Playlists/crates + iCloud sync (Cloud sub)
- **Epic:** Library · **PRD:** PRD-05 L-06 L-07 / Monetization · **Owner:** Eng
- **Priority/Size/Points:** P2 / L / 8
- **Depends on:** SK-044, SK-035
- **Acceptance:**
  - CloudKit or iCloud KVS for crates/cues
  - StoreKit auto-renew $2.99/$19.99

#### SK-064 — First content pack IAP (samples or FX presets)
- **Epic:** Monetization · **PRD:** Monetization · **Owner:** Product + Eng
- **Priority/Size/Points:** P1 / M / 5
- **Depends on:** SK-044
- **Acceptance:**
  - Non-consumable pack
  - Appears in Library after purchase

#### SK-065 — Ableton Link integration
- **Epic:** Decks · **PRD:** PRD-09 1.2 · **Owner:** Audio eng
- **Priority/Size/Points:** P2 / L / 8
- **Depends on:** SK-033
- **Acceptance:**
  - Join/leave Link session
  - Tempo follows Link when enabled

#### SK-066 — TE partnership outreach package
- **Epic:** GTM · **PRD:** PRD-09 / Monetization · **Owner:** Founder
- **Priority/Size/Points:** P1 / S / 2
- **Depends on:** SK-056
- **Acceptance:**
  - One-pager + TestFlight for TE
  - Ask: protocol docs + downloads page link (no revenue share required)

---

## Suggested first 5 tickets to open tomorrow
1. **SK-006** Trademark screen (parallel, founder)
2. **SK-001** Xcode workspace
3. **SK-005** App Store Connect shell
4. **SK-004** AudioEngine skeleton (after SK-001)
5. **SK-003** Design tokens (after SK-001)

## Import tips
- GitHub Projects: create Status (Todo/In Progress/Done), Sprint, Priority custom fields; bulk-create issues from table
- Linear: use `SK-` as identifier prefix; map epics 1:1
- Keep hardware QA (SK-025, SK-026, SK-041) on a device with real EP-136

*Generated from SideKit PRD Suite v1.0*
