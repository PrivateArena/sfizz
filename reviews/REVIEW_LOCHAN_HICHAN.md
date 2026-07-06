Commits:
- 5da4159494b1a214b8a84d5a3b7cc9433bbf2007
- a9111308631a55cf6355d7b042afc2b3bf657a08

### What I'd flag before production

**1. It's a global flag, not a per-region one.** `hasChannelRestrictions_` is computed by scanning *every* region in the loaded file. If even one region anywhere uses `lochan`/`hichan`, channel-collapsing is disabled for the *entire instrument* — including regions that never asked for channel isolation. That's a real risk for the exact multi-articulation patches you're targeting: mixing a "generic" region (default 1-16 range) with a couple of channel-locked ones now silently changes how the generic region's controller state resolves, purely because of an unrelated region elsewhere in the file.

**2. Per-channel state isolation doesn't fail loud — it fails quiet.** Once that flag is on and MPE is off, `MidiState::getCCValue(channel, cc)` (and the pitch-bend/aftertouch equivalents) no longer fall back to the master channel when a channel has no CC history. So if your DAW sends mod-wheel/sustain/expression only on channel 1, a region gated to channel 3 will read **0**, not the "global" value, unless that CC is also explicitly sent on channel 3. This is a real workflow implication (you'd need to duplicate global CCs per channel) that isn't called out anywhere in the report or tests.

**3. This is the big one: most CC-driven modulation is still channel-blind.** I grepped every call site of `getCCValue`/`getCCValueAt` outside `MidiState` itself. `FilterPool.cpp`, `LFO.cpp`, `FlexEGDescription.cpp`, `EGDescription.h`, and `RegionStateful.cpp` (filter cutoff CC, amp/pan CC, LFO delay/fade CC, envelope-depth CC — i.e. most `*_cc` opcodes) all use the **single-argument** `getCCValue(ccNumber)` overload, which unconditionally resolves to `masterChannel` (0), completely independent of `hasChannelRestrictions_`. Only crossfade CC ranges (`Voice.cpp:880`) use the channel-aware two-argument version. So: note triggering and CC-gated triggering are correctly per-channel, but if your Harmonic articulation on channel 2 has a `fil_cc74`-style cutoff modulation, it will listen to CC74 on channel 1, not channel 2. For a DAW built around per-channel articulation switching, this asymmetry will bite eventually.

**4. Minor code smell confirming the plumbing is incomplete**: `Layer::updateCCState` gained a `channel` parameter in commit 2 but the body does `UNUSED(channel)` — it's not actually used there. The channel awareness only reaches as far as one comparison inside `registerCC`. Not dangerous by itself, but it's a sign this was patched reactively (note the report's own Q1 answer flips from "No" in commit 1 to "Yes" in commit 2 — the isolation gaps above are what's left after that flip).

**5. Untested territory**: multi-region patches mixing restricted + unrestricted regions, regions spanning a channel range wider than one channel (`lochan=2 hichan=5` — initial CC seeding only uses `channelRange.getStart()`, not the whole range), and any of the modulation-routing behavior in point 3. None of these appear in `MPET.cpp`.

### Bottom line

For the narrow case you described — one channel per articulation, simple note triggering, no per-channel CC-driven filter/LFO/envelope modulation — this works and is tested. I'd trust that path.

I would **not** push it to production as a general-purpose solution yet. The global (not per-region) restriction flag and the master-channel-only modulation routing mean behavior can silently diverge from what a multi-timbral DAW author would reasonably expect the moment patches get more complex than "note on/off per channel." Before shipping, I'd want: (a) an explicit test with mixed restricted/unrestricted regions in the same file, (b) a decision on whether `*_cc` modulation should also become channel-aware (or clearly documented that it isn't), and (c) since this is a private fork of `sfztools/sfizz` and not something upstream has reviewed, a plan for how you'll carry these patches forward as upstream evolves.

Here's a concrete plan, ordered by risk, with the actual files/functions from the review so it maps directly onto the codebase.

## Phase 0 — Decide the semantics first (before touching code)

The root cause of most issues is that "channel restriction" was bolted on as a single global bool rather than designed as a first-class concept. Before writing more code, pin down:

- Should channel isolation be **per-region** (only regions with explicit `lochan`/`hichan` get isolated state) or **instrument-wide** (current behavior)? Given your DAW's use case (mixed generic + channel-locked regions in the same patch), per-region is almost certainly what you want.
- Should CC-driven modulation (`fil_cc`, `amp_cc`, `pan_cc`, LFO/EG `_cc` opcodes) be channel-aware too, or intentionally stay global (e.g., "expression pedal always affects everything, per-channel CCs only gate triggering")? This is a product decision, not just a bug fix — document it either way.

Everything below assumes: **per-region isolation**, and **modulation should follow the same channel the note/CC triggered on**. Adjust if you decide otherwise.

## Phase 1 — Fix the global-flag scoping problem

**Problem:** `hasChannelRestrictions_` in `Synth::Impl` / `MidiState` is one bool for the whole instrument, set in `finalizeSfzLoad()` by scanning all regions (`Synth.cpp` ~line 976).

**Fix:**
- Remove the instrument-wide `hasChannelRestrictions_` bool from the dispatch decision. Instead, keep channel collapsing decisions based on `mpeEnabled_` only for the *routing* layer (whether channel is preserved when entering `hdNoteOn`/`hdNoteOff`/`performHdcc`/etc.) — this part can stay global since MIDI channel is a property of the raw event, not the region.
- Move the *isolation* decision (whether to fall back to master channel) down to `Region`/`Layer` granularity: give `Region` a `bool hasCustomChannelRange` computed at parse time (`channelRange.getStart() != 1 || channelRange.getEnd() != 16`), set once in `Region::parseOpcode` or finalized in `finalizeSfzLoad` per-region instead of per-synth.
- In `Layer::registerCC` / wherever a region reads controller state, use the region's own flag to decide whether to consult the true channel or fall back to master — not a synth-wide bool.

This means `MidiState::getCCValue(channel, cc)` no longer needs a "should I isolate" flag baked into it globally; callers pass whether isolation applies for that specific region.

## Phase 2 — Fix the silent fallback-to-zero issue

**Problem:** Once isolated, a channel with no CC history returns `0.0f` instead of falling back to a sensible master value (`MidiState.cpp` ~lines 215, 263, 284, 317, 336).

**Fix options** (pick one, document it in the SFZ opcode docs):
- **(a) Seed-on-restriction:** When a region is first identified as channel-restricted, seed its channel's state from the current master-channel value at load time (this already exists partially via `finalizeSfzLoad`'s `initChannel` logic — extend it to actually copy master's live CC array, not just re-run `updateCCState` with zeros).
- **(b) Explicit fallback with a decay flag:** Keep falling back to master until the *first* real event arrives on that specific channel, then switch to isolated mode for that (channel, cc) pair. This matches DAW user expectations ("channel hasn't sent its own value yet, so use global") much better than always-isolated.

(b) is more correct for a DAW workflow and only requires a per-(channel, cc) "has this channel received an explicit event" bit — cheap to add to `ChannelState`.

## Phase 3 — Make CC-driven modulation channel-aware (or explicitly not, and document it)

**Problem:** `FilterPool.cpp:45`, `LFO.cpp:88/95`, `FlexEGDescription.cpp:93/101`, `EGDescription.h` (6 call sites), `RegionStateful.cpp` (7 call sites) all call the single-arg `getCCValue(ccNumber)`, which always resolves `masterChannel`, regardless of the triggering voice's channel.

**Fix:**
- Thread the voice's `triggerChannel_` (already available on `Voice`) through to these call sites the same way `Voice.cpp:880` already does for crossfades. Concretely: `RegionStateful.cpp`, `FilterPool.cpp`, `LFO.cpp`, `EGDescription.h`, `FlexEGDescription.cpp` functions need a `channel` (or `const Voice&`/`triggerChannel_`) parameter added to their signatures, mirroring the `registerCC(channel, ...)` pattern from commit 2.
- This is the largest chunk of work in the plan — touches 5 files and ~20 call sites — but it's exactly what's needed for the "Track 2 sends CC74 to shape only the Harmonic articulation" workflow your DAW needs.
- If this turns out to be too invasive for now, ship without it but **document clearly** in your SFZ authoring guide that `_cc` modulation opcodes only respond to the master/channel-1 CC stream, so users don't quietly lose expression data per channel and file it as a confusing bug later.

## Phase 4 — Clean up the incomplete plumbing

- `Layer::updateCCState(int channel, ...)` currently does `UNUSED(channel)`. Either use it (once Phase 1/3 lands, it should feed into per-region isolated state) or remove the parameter until it's actually wired up — a dead parameter that looks functional is worse than no parameter.
- `finalizeSfzLoad()` and `resetAllControllers()` seed initial CC state using only `channelRange.getStart() - 1` (`Synth.cpp` ~line 887, ~line 2483). For a region spanning multiple channels (`lochan=2 hichan=5`), only channel index 1 gets seeded. Fix: loop over `[channelRange.getStart()-1, channelRange.getEnd()-1]` and seed each channel index the region can be triggered from.

## Phase 5 — Test plan additions (target `MPET.cpp` + new file)

Add these before merging further:

1. **Mixed-region regression test**: one SFZ with a default full-range region and a `lochan=2 hichan=2` region in the same instrument. Verify the default region's CC/pitch-bend fallback behavior is unaffected by the presence of the restricted region (this directly tests the Phase 1 fix).
2. **Fallback-before-first-event test**: channel-restricted region, no CC ever sent on its channel, master channel CC sent — verify expected fallback behavior per whatever Phase 2 decision you make.
3. **Modulation-channel test**: region with `lochan=3 hichan=3 fil_cc74=...` (or `amp_cc`), send CC74 on channel 3 vs channel 1, verify filter/amp modulation responds to the correct channel post-Phase-3.
4. **Multi-channel-span seeding test**: `lochan=2 hichan=4`, verify CC/aftertouch/pitch-bend state is correctly seeded/isolated for channels 2, 3, and 4, not just channel 2.
5. **Note-off channel mismatch under restriction**: note-on channel 3, note-off channel 3 vs a different channel, confirm stuck-note prevention still holds with the new dispatch paths.
6. **Reload/thread-safety sanity check**: trigger `finalizeSfzLoad()` (patch reload) while voices are active on restricted channels, confirm no glitches/crashes — the flag flip happens on the main/loader thread but interacts with audio-thread reads; worth an explicit stress test even if you don't expect a bug, since nothing currently covers it.
7. **Performance regression check**: run your existing benchmark suite (`SFIZZ_BENCHMARKS=ON`) before/after to confirm the extra branch in `ccDispatch`/`noteOnDispatch` doesn't measurably regress per-sample dispatch cost — the report claims a perf win but doesn't show numbers.

## Suggested sequencing

1. Phase 1 + Phase 4 (scoping fix + dead-param cleanup) — smallest, highest-value, fixes the "surprising global side effect" risk.
2. Phase 2 (fallback semantics) — pick (b), moderate effort.
3. Test additions #1–#4 to lock in phases 1–2 before touching modulation.
4. Phase 3 (modulation channel-awareness) — largest effort, do it as its own reviewed change since it touches the DSP-facing modulation chain.
5. Tests #5–#7 as a final hardening pass before production.

If you want, I can start drafting the actual code diff for Phase 1 (region-level flag) against your checked-out commits — that's the one I'd fix first regardless of which direction you go on Phase 3.