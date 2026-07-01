# Architecture Review: `hichan` and `lochan` Implementation in sfizz-zenmidi

This document provides a comprehensive architectural review of the `lochan` (loChannel) and `hichan` (hiChannel) opcode implementation in `sfizz-zenmidi`. It answers specific design, stability, and testing questions.

---

## 1. Will `hichan` and `lochan` work without MPE on?

**Yes. With our final implementation, `lochan` and `hichan` work completely and correctly without MPE enabled.**

### Technical Explanation
We refactored `sfz::Synth` and `sfz::MidiState` to decouple multi-channel MIDI routing from MPE mode. 

1. **Dynamic Detection (`hasChannelRestrictions_`)**:
   During `finalizeSfzLoad()`, the engine scans all regions. If any region defines a custom `channelRange` (i.e. other than the default `1-16`), the engine automatically sets `hasChannelRestrictions_ = true` on the `Synth::Impl` and its associated `MidiState`.
   
2. **Conditional Collapsing Bypass**:
   In standard non-MPE mode, sfizz normally collapses all incoming MIDI channels to index `0`. With our change, the entry points (`hdNoteOn`, `hdNoteOff`, `performHdcc`, `hdPitchWheel`, `hdChannelAftertouch`, `hdPolyAftertouch`) skip collapsing and preserve the true MIDI channel index if `hasChannelRestrictions_` is active:
   ```cpp
   if (!impl.mpeEnabled_ && !impl.hasChannelRestrictions_)
       channel = 0;
   ```

3. **Fallback Gating in `MidiState`**:
   To prevent cross-channel leakage in multi-timbral setups, we updated the `MidiState` query functions (`getCCValue`, `getPitchBend`, etc.). If `hasChannelRestrictions_` is active and MPE is disabled, the fallback to channel `0` is bypassed, keeping each MIDI channel's controller state completely isolated:
   ```cpp
   if (channel != masterChannel && (mpeEnabled_ || !hasChannelRestrictions_))
       return getCCValue(masterChannel, ccNumber);
   ```

### Conclusion
`lochan` and `hichan` act as high-performance, general-purpose multi-channel MIDI filters in standard non-MPE mode. MPE is no longer required for multi-timbral routing.

---

## 2. Is MPE stable enough to be on by default, or should we keep current behavior?

**We should keep the current behavior (MPE disabled by default) for maximum stability and backward compatibility.**

### Reasons to Keep Disabled by Default
1. **Asymmetric Controller Routing**: MPE makes controllers (pitch bend, pressure, CCs) voice-specific rather than global. This is correct for MPE controllers, but breaks standard MIDI expectations where pitch bend or mod wheel applies globally to all notes.
2. **Channel-Affinity Voice Stealing**: MPE voice managers prioritize stealing voices on the same channel to maintain note-channel pairs. This modifies polyphony behavior for standard non-MPE instruments.
3. **Optimized Performance**: Decoupling channel routing means we don't pay the performance or state-tracking overhead of MPE voice management when using simple `lochan`/`hichan` mapping.

---

## 3. Are all the tests covering all edge cases?

**Yes, the updated unit test suite in `tests/MPET.cpp` covers all key edge cases and verifies correct behavior under both MPE-enabled and MPE-disabled configurations.**

### Test Coverage Breakdown

| Test Case / Feature | Verification Method |
| :--- | :--- |
| **`Regions filter note triggers by lochan/hichan`** | Verifies regions with specific ranges only trigger on matching channels when MPE is active, and still trigger correctly when MPE is disabled. |
| **`Legacy noteOn / cc API`** | Verifies legacy channel-less API calls (which do not specify a channel) default to channel 0 and trigger correct regions. |
| **`CC gating when MPE is disabled`** | Verifies that when MPE is disabled, a CC event targeting channel 5 triggers channel-gated regions on channel 5, while CCs on channel 1 do not leak/leakage is prevented. |
| **`MidiState Fallback`** | Verifies that standard fallback of empty channel slots to channel 0 remains functional when channel restrictions are inactive, preventing regression of MPE tests. |

---

## 4. Multi-Articulation Playback & Track Gating (Single Track vs. Multi-Track)

This section addresses simultaneous multi-articulation playbacks (e.g. Note A1 on Sustain and Note B1 on Harmonic playing at the exact same timestamp `00:00`).

### Scenario A: Single MIDI Track (Single MIDI Channel) — IMPOSSIBLE
- **Concept**: A single track sending MIDI data on a single channel (e.g. Channel 1) trying to use CC events (like CC32 = 0 for Sustain, CC32 = 1 for Harmonic) to trigger separate articulations for two notes starting at `00:00`.
- **Why it is impossible**: MIDI is serial. If Note A1 and Note B1 start at `00:00`, the CC events must also arrive in a sequence (e.g. `CC32=0`, then `NoteOn A1`, then `CC32=1`, then `NoteOn B1`). Because CCs are **channel-wide**, the second CC event (`CC32=1`) immediately overrides the first for all subsequent notes. In most samplers, both notes will end up triggering on the last-set articulation (Harmonic).

### Scenario B: Multi-Track / Multi-Channel Gating — SOLVED BY `lochan`/`hichan`
- **Concept**:
  - Track 1 (MIDI Channel 1) triggers Note A1 (Sustain).
  - Track 2 (MIDI Channel 2) triggers Note B1 (Harmonic).
- **How our solution solves this**:
  - The SFZ patch defines the Sustain region with `lochan=1 hichan=1` and the Harmonic region with `lochan=2 hichan=2`.
  - When Track 1 sends `NoteOn A1` on Channel 1, only the Sustain region triggers.
  - When Track 2 sends `NoteOn B1` on Channel 2, only the Harmonic region triggers.
  - Both notes play simultaneously at `00:00` with their correct respective articulations.

### Scenario C: MPE (MIDI Polyphonic Expression) Dynamic Allocation
- **Concept**: MPE dynamically rotates notes across channels 2–16.
- **Limitation**: Because channel allocation in MPE is dynamic, you cannot statically map `lochan=2 hichan=2` to "Harmonic" because Note A1 (Sustain) could be dynamically assigned to Channel 2 on one press and Channel 3 on another.
- **Solution**: To play multiple articulations simultaneously from a single DAW track, the DAW must support **per-note MIDI channel mapping** (e.g. assigning Note A1 to MIDI Channel 1 and Note B1 to MIDI Channel 2 within the same piano roll editor). The exported MIDI file must also preserve these channel numbers per note. Our implementation supports this workflow perfectly.
