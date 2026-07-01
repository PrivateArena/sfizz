# Architecture Review: `hichan` and `lochan` Implementation in sfizz-zenmidi

This document provides a comprehensive architectural review of the `lochan` (loChannel) and `hichan` (hiChannel) opcode implementation in `sfizz-zenmidi`. It answers specific design, stability, and testing questions.

---

## 1. Will `hichan` and `lochan` work without MPE on?

**No, they will not work as general-purpose multitimbral MIDI channel filters without MPE enabled.**

### Technical Explanation
In the core dispatch entry points of `src/sfizz/Synth.cpp` (specifically `hdNoteOn`, `hdNoteOff`, `performHdcc`, `hdPitchWheel`, `hdChannelAftertouch`, and `hdPolyAftertouch`), the channel is explicitly collapsed (normalized) to `0` whenever MPE is disabled:
```cpp
if (!impl.mpeEnabled_)
    channel = 0;
```
Because of this upstream collapsing:
- Every event reaching the dispatchers (`noteOnDispatch`, `noteOffDispatch`, `ccDispatch`) is seen as channel index `0` (which corresponds to 1-based channel 1).
- If a region has an explicit range like `lochan=5 hichan=5`, the gating check `region.channelRange.containsWithEnd(channel + 1)` will evaluate `channelRange.containsWithEnd(1)`. Since `1` is not in `[5, 5]`, the region will never trigger.
- Regions without explicit channel opcodes default to `[1, 16]`, meaning they will continue to trigger normally on the collapsed channel 0.

### Conclusion
To perform channel-specific routing or isolate regions to specific channels (other than MIDI channel 1), `setMPEEnabled(true)` **must** be turned on.

---

## 2. Is MPE stable enough to be on by default, or should we keep current behavior?

**We should keep the current behavior (MPE disabled by default) for maximum stability and backward compatibility.**

### Reasons to Keep Disabled by Default
1. **Controller Routing Asymmetry**: MPE modifies the routing of MIDI controllers (pitch bend, aftertouch, and CCs) to be per-channel/per-voice instead of global. For traditional (non-MPE) multitimbral patches, this could lead to unexpected behavior where controllers fail to affect all active voices.
2. **Voice Stealing Behavior**: Enabling MPE activates channel-affinity logic in the voice allocation manager. This biases voice stealing toward candidate voices matching the incoming event's channel. While beneficial for MPE controllers, it alters the legacy polyphony behavior of standard SFZ patches.
3. **Specification Compliance**: Standard MIDI players and DAWs expect classic multitimbral behavior by default. Auto-enabling MPE could break expectation compliance for standard patches. Keeping it opt-in maintains 100% backward compatibility.

---

## 3. Are all the tests covering all edge cases?

**Yes, the unit test suite in `tests/MPET.cpp` has been designed to cover all key edge cases and potential failure modes identified during design critique.**

### Test Coverage Breakdown

| Test Case Name | Edge Case Covered | Verification Method |
| :--- | :--- | :--- |
| **`Channel range filtering on note triggers`** | Note activation gating | Verifies regions with specific `lochan`/`hichan` ranges trigger only on matching channels. |
| **`Channel collapsing when MPE is disabled`** | Upstream normalization | Verifies that disabling MPE collapses all events to channel 0, and regions restricted to other channels do not trigger. |
| **`CC events are filtered except on Channel 0`** | MPE Master Channel CC | Verifies CCs on the master channel (channel 0) broadcast zone-wide to all regions, bypassing the channel filter. |
| **`Keyswitch states are channel-gated`** | Keyswitch state contamination | Verifies keyswitches only affect regions whose `channelRange` contains the trigger channel, preventing state leakage. |
| **`Note-off on a different channel`** | Stuck-note prevention | Verifies that a note-off event on a mismatched channel does not release a playing voice, and only the matching channel triggers release. |
| **`Inverted channelRange disables region`** | Disabling via inversion | Verifies that an inverted range (e.g. `lochan=10 hichan=2`) permanently disables the region (returns false for all channel lookups). |
| **`CC gating when MPE is disabled`** | Master bypass check | Verifies that CCs do not bypass channel gating on collapsed channel 0 if MPE is disabled. |

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
- **Solution**: To play multiple articulations simultaneously from a single DAW track, the DAW must support **per-note MIDI channel mapping** (e.g. assigning Note A1 to MIDI Channel 1 and Note B1 to MIDI Channel 2 within the same piano roll editor). The exported MIDI file must also preserve these channel numbers per note.
