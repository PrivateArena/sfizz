# sfizz Project Architecture Overview

## Purpose

sfizz is an SFZ-compatible sample-based synthesis engine in C/C++.
It parses SFZ instrument definitions, loads audio samples, and renders
real-time audio via a voice-managed synth pipeline. The project includes
a JACK audio client, a C API (sfizz.h), and a C++ API (sfizz.hpp).

---

## Directory Tree

```
sfizz/
|
+-- src/
|   +-- sfizz.h                    C API (1607 lines)
|   +-- sfizz.hpp                  C++ API (1220 lines)
|   +-- sfizz/
|   |   +-- sfizz.cpp              C API implementation
|   |   +-- sfizz_wrapper.cpp      C++ wrapper internals
|   |   +-- sfizz_private.hpp      Internal synth struct
|   |   +-- Synth.h / Synth.cpp    Core synthesizer (2775 lines)
|   |   +-- SynthPrivate.h         Synth internals (458 lines)
|   |   +-- SynthConfig.h          Synth configuration types
|   |   +-- SynthMessaging.cpp     Synth message dispatch
|   |   +-- SynthMessagingHelper.hpp
|   |   +-- Voice.h / Voice.cpp    Per-voice renderer (2301 lines)
|   |   +-- VoiceManager.h/.cpp    Voice pool & lifecycle
|   |   +-- VoiceStealing.h/.cpp   Voice stealing policies
|   |   +-- Region.h / Region.cpp  SFZ region model (1925 lines)
|   |   +-- RegionSet.h/.cpp       Region collection
|   |   +-- RegionStateful.h/.cpp  Runtime region state
|   |   +-- Layer.h / Layer.cpp    Layer within a region
|   |   +-- SisterVoiceRing.h      Sister-voice linked list
|   |   +-- PolyphonyGroup.h/.cpp  Polyphony group tracking
|   |   +-- TriggerEvent.h         MIDI event abstraction
|   |   +-- MidiState.h/.cpp       Per-channel MIDI state (425 lines)
|   |   +-- Opcode.h / Opcode.cpp  SFZ opcode parsing
|   |   +-- OpcodeCleanup.cpp      Opcode normalization (2901 lines)
|   |   +-- Config.h / Config.cpp  Runtime configuration
|   |   +-- Defaults.h/.cpp        Default opcode values
|   |   +-- Resources.h/.cpp       Resource paths
|   |   |
|   |   +-- parser/
|   |   |   +-- Parser.h / .cpp    SFZ file parser
|   |   |   +-- ParserPrivate.h    Parser internals
|   |   |   +-- ParserListener.h   Parser event listener iface
|   |   |
|   |   +-- effects/
|   |   |   +-- Effects.h / .cpp   Effect manager/router
|   |   |   +-- Gain.h / .cpp      Gain effect
|   |   |   +-- Filter.h / .cpp    Filter effect
|   |   |   +-- Eq.h / .cpp        Parametric EQ effect
|   |   |   +-- Compressor.h / .cpp
|   |   |   +-- Limiter.h / .cpp
|   |   |   +-- Gate.h / .cpp      Noise gate
|   |   |   +-- Disto.h / .cpp     Distortion
|   |   |   +-- Lofi.h / .cpp      Lo-fi (bitcrush/downsample)
|   |   |   +-- Fverb.h / .cpp     Freeverb reverb
|   |   |   +-- Apan.h / .cpp      Auto-panner
|   |   |   +-- Strings.h / .cpp   Resonant strings
|   |   |   +-- Width.h / .cpp     Stereo width
|   |   |   +-- Rectify.h / .cpp   Rectifier
|   |   |   +-- Nothing.h / .cpp   Null/through effect
|   |   |   +-- impl/
|   |   |       +-- ResonantArray.h / .cpp
|   |   |       +-- ResonantArraySSE.h / .cpp
|   |   |       +-- ResonantArrayAVX.h / .cpp
|   |   |       +-- ResonantString.h / .cpp
|   |   |       +-- ResonantStringSSE.h / .cpp
|   |   |       +-- ResonantStringAVX.h / .cpp
|   |   |
|   |   +-- modulations/
|   |   |   +-- ModMatrix.h / .cpp       Modulation matrix
|   |   |   +-- ModKey.h / .cpp         Modulation routing key
|   |   |   +-- ModKeyHash.h / .cpp     Hash for ModKey
|   |   |   +-- ModId.h / .cpp          Modulation identifiers & flags
|   |   |   +-- ModGenerator.h          Generator base interface
|   |   |   +-- sources/
|   |   |       +-- LFO.h / .cpp         LFO modulator source
|   |   |       +-- ADSREnvelope.h / .cpp ADSR envelope source
|   |   |       +-- FlexEnvelope.h / .cpp Flexible envelope source
|   |   |       +-- Controller.h / .cpp  MIDI CC source
|   |   |       +-- ChannelAftertouch.h / .cpp
|   |   |       +-- PolyAftertouch.h / .cpp
|   |   |
|   |   +-- import/
|   |   |   +-- sfizz_import.h / .cpp   Instrument import dispatch
|   |   |   +-- ForeignInstrument.h / .cpp
|   |   |   +-- foreign_instruments/
|   |   |       +-- AudioFile.h / .cpp     Raw audio as instrument
|   |   |       +-- DecentSampler.h / .cpp DecentSampler format
|   |   |
|   |   +-- AudioBuffer.h              Multi-channel audio buffer
|   |   +-- AudioSpan.h                Non-owning audio view
|   |   +-- AudioReader.h / .cpp       File -> audio decode
|   |   +-- FilePool.h / .cpp          Sample file cache
|   |   +-- FileId.h / .cpp            File identity (path hashing)
|   |   +-- FileMetadata.h / .cpp      File metadata cache
|   |   +-- Buffer.h / BufferPool.h    Generic buffer pool
|   |   +-- Curve.h / .cpp             Value mapping curves
|   |   +-- Tuning.h / .cpp            Microtuning / Scala files
|   |   +-- BeatClock.h / .cpp         Musical BBT clock
|   |   +-- Metronome.h / .cpp         Metronome tick
|   |   +-- Interpolators.h / .cpp     Sample interpolation
|   |   +-- SIMDConfig.h / SIMDHelpers.h/.cpp
|   |   +-- MathHelpers.h              DSP math routines (767 lines)
|   |   +-- SfzHelpers.h               SFZ utility functions
|   |   +-- ModifierHelpers.h          Envelope/CC helper functions
|   |   +-- OnePoleFilter.h            Single-pole IIR filter
|   |   +-- Panning.h / .cpp           Pan/balance algorithms
|   |   +-- Smoothers.h / .cpp         Parameter smoothing
|   |   +-- Wavetables.h / .cpp        Wavetable oscillator pool
|   |   +-- WindowedSinc.h / .cpp      Sinc interpolation
|   |   +-- Oversampler.h / .cpp       Oversampling
|   |   +-- OversamplerHelpers.h       Oversampling utilities
|   |   +-- SfzFilter.h / .cpp         SVF filter core
|   |   +-- SfzFilterImpls.hpp         Filter type implementations
|   |   +-- PowerFollower.h / .cpp     RMS envelope follower
|   |   +-- ScopedFTZ.h / .cpp         Flush-to-zero scoped guard
|   |   +-- RTSemaphore.h / .cpp       Real-time lock
|   |   +-- HistoricalBuffer.h         Circular history buffer
|   |   +-- Messaging.h / .cpp         Synth event messaging
|   |   +-- Messaging.hpp
|   |   +-- EGDescription.h            Envelope generator params
|   |   +-- EQDescription.h
|   |   +-- EQPool.h / .cpp
|   |   +-- FilterDescription.h
|   |   +-- FilterPool.h / .cpp
|   |   +-- FlexEGDescription.h/.cpp   Flexible EG description
|   |   +-- LFOCommon.h / .hpp         Common LFO definitions
|   |   +-- LFODescription.h / .cpp
|   |   +-- CCMap.h                    CC number mapping
|   |   +-- Range.h                    Numeric range type
|   |   +-- EGDESCRIPTION IMPLEMANTATION
|   |   +-- git-build-id/
|   |       +-- GitBuildId.h           Build timestamp/commit
|   |   +-- railsback/
|   |       +-- 2-1.h, 4-1.h, 4-2.h   Railsback stretch tables
|   |
+-- clients/
|   +-- jack_client.cpp            JACK standalone client (401 lines)
|   +-- sfizz_render.cpp           Offline render tool
|   +-- MidiHelpers.h              MIDI parsing helpers
|
+-- PROJECT_OVERVIEW.md            (this file)
```

---

## Architecture Diagram (Plain-Text)

```
  +-----------+     +--------------+     +------------------+
  | JACK      |     | C/C++ API    |     | sfizz_render     |
  | Client    |---->| (sfizz.h)    |     | (offline render) |
  +-----------+     +--------------+     +------------------+
                          |
                    +-----v------+
                    |   Synth    |  (core orchestrator)
                    +-----+------+
                          |
          +---------------+---------------+
          |               |               |
    +-----v------+  +----v-------+  +----v--------+
    | FilePool   |  | VoiceMgr   |  | Effects     |
    | (samples)  |  | (voices)   |  | (DSP chain) |
    +------------+  +-----+------+  +-------------+
                          |
          +---------------+---------------+
          |               |               |
    +-----v------+  +----v-------+  +----v--------+
    | Voice      |  | Region     |  | ModMatrix   |
    | (render)   |  | (SFZ def)  |  | (mod src -> |
    +------------+  +------------+  |  target)    |
                                    +-------------+
          +---------------+---------------+
          |               |               |
    +-----v------+  +----v-------+  +----v--------+
    | Parser     |  | MidiState  |  | BeatClock   |
    | (SFZ file) |  | (CC/pitch) |  | (tempo/BBT) |
    +------------+  +------------+  +-------------+
```

---

## Component Roles & Key Exports

### API Layer

| File | Role | Key Exports |
|------|------|-------------|
| `src/sfizz.h` | Pure C API (1607 lines). Thin C-compatible interface for hosts. | `sfizz_create_t`, `sfizz_load_file`, `sfizz_process_block`, `sfizz_send_midi` |
| `src/sfizz.hpp` | C++ API (1220 lines). Namespace `sfz::`. RAII wrapper, `Client` class with `SFIZZ_EXPORTED_API`. | `sfz::Client`, `sfz::ProcessMode`, `sfz::CallbackBreakdown` |
| `src/sfizz/sfizz.cpp` | C API implementation. Delegates to `Synth`. | Implements all `sfizz_*` functions |
| `src/sfizz/sfizz_wrapper.cpp` | C++ wrapper internals. Bridges `Synth` to the C++ `Client` API. | |
| `src/sfizz/sfizz_private.hpp` | Internal `sfizz_synth_t` struct. Holds the opaque `Synth` pointer. | `struct sfizz_synth_t` |

### Core Engine

| File | Role | Key Exports |
|------|------|-------------|
| `Synth.h/.cpp` | Central orchestrator (2775 lines). Manages file loading, MIDI dispatch, voice allocation, effect chain, audio output. | `class Synth` (impl in `SynthPrivate.h`), `ProcessMode` enum, `CallbackBreakdown` struct |
| `SynthPrivate.h` | Synth internal state (458 lines). Holds all member fields: voice manager, file pool, effect bank, MIDI state, parser, etc. | `struct RpnParserState` |
| `SynthConfig.h` | Configuration constants for the synth. | |
| `SynthMessaging.cpp` | Message dispatch between synth internals and listeners. | |

### Voice Pipeline

| File | Role | Key Exports |
|------|------|-------------|
| `Voice.h/.cpp` | Per-voice renderer (2301 lines). Handles note lifecycle: start, release, render audio, handle modulation/EG updates. | `struct ExtendedCCValues` |
| `VoiceManager.h/.cpp` | Voice pool. Allocates/recycles voices, manages polyphony limits. | |
| `VoiceStealing.h/.cpp` | Voice stealing policies for when polyphony is exhausted. | |
| `SisterVoiceRing.h` | Linked ring of "sister" voices (round-robin groups). | `struct SisterVoiceRing`, `countSisterVoices()`, `checkRingValidity()` |
| `PolyphonyGroup.h/.cpp` | Groups voices by polyphony group ID for group-level voice stealing. | |
| `TriggerEvent.h` | Normalized MIDI event representation. | `struct TriggerEvent` |

### Region / Layer Model

| File | Role | Key Exports |
|------|------|-------------|
| `Region.h/.cpp` | SFZ region model (1925 lines). Parsed opcodes -> region state. | `struct Region`, `struct Connection` (mod matrix connections) |
| `RegionSet.h/.cpp` | Collection of regions. Hierarchical grouping. | |
| `RegionStateful.h/.cpp` | Runtime mutable state for a region (e.g. currently active EG values). | |
| `Layer.h/.cpp` | Layer within a compound region (for velocity layers, etc.). | `struct Layer`, `struct DelayedRelease` |
| `Opcode.h/.cpp` | Parsed SFZ opcode representation. | `enum OpcodeCategory`, `enum OpcodeScope`, `struct Opcode` |
| `OpcodeCleanup.cpp` | Opcode normalization/normalization (2901 lines). | |

### Parser

| File | Role | Key Exports |
|------|------|-------------|
| `parser/Parser.h/.cpp` | SFZ file parser. Tokenizes header/opcode pairs into region/group/global blocks. | `struct SourceLocation`, `struct SourceRange` |
| `parser/ParserListener.h` | Interface for parser event callbacks. | |
| `parser/ParserPrivate.h` | Parser internal state and helper structures. | |

### Effects System

| File | Role | Key Exports |
|------|------|-------------|
| `Effects.h/.cpp` | Effect manager. Routes audio through the effect chain per-voice or master. | |
| `effects/Gain.h/.cpp` | Simple gain/volume effect. | |
| `effects/Filter.h/.cpp` | State-variable filter. | |
| `effects/Eq.h/.cpp` | Parametric/shelving EQ. | |
| `effects/Compressor.h/.cpp` | Dynamics compressor. | |
| `effects/Limiter.h/.cpp` | Brickwall limiter. | |
| `effects/Gate.h/.cpp` | Noise gate. | |
| `effects/Disto.h/.cpp` | Waveshaping distortion. | |
| `effects/Lofi.h/.cpp` | Bitcrushing + sample-rate reduction. | |
| `effects/Fverb.h/.cpp` | Freeverb algorithmic reverb. | |
| `effects/Apan.h/.cpp` | Auto-panner (LFO-driven pan modulation). | |
| `effects/Strings.h/.cpp` | Resonant string physical model. | |
| `effects/Width.h/.cpp` | Stereo width/balance adjust. | |
| `effects/Rectify.h/.cpp` | Full/half-wave rectifier. | |
| `effects/Nothing.h/.cpp` | Identity/passthrough effect. | |
| `effects/impl/Resonant*.h/.cpp` | SIMD-optimized resonant structures (scalar, SSE4, AVX2). | |

### Modulation System

| File | Role | Key Exports |
|------|------|-------------|
| `modulations/ModMatrix.h/.cpp` | Modulation routing matrix. Maps sources to targets with depth/curve. | |
| `modulations/ModKey.h/.cpp` | Key for modulation routing lookups. | `struct RawParameters` |
| `modulations/ModKeyHash.h/.cpp` | Hash function for `ModKey` in unordered maps. | |
| `modulations/ModId.h/.cpp` | Enumeration of modulation source/target IDs + flags. | `enum ModFlags` |
| `modulations/ModGenerator.h` | Abstract base for modulation generator sources. | |
| `modulations/sources/` | Concrete modulator implementations: LFO, ADSR, flex envelope, MIDI CC, channel/poly aftertouch. | |

### Sample Management

| File | Role | Key Exports |
|------|------|-------------|
| `FilePool.h/.cpp` | Background-loaded sample cache. Manages file discovery, decoding, and eviction. | `struct FileInformation`, `struct FileData`, `struct QueuedFileData` |
| `FileId.h/.cpp` | File identity abstraction using content hashing. | |
| `FileMetadata.h/.cpp` | Metadata cache (sample rate, loop points, etc.). | |
| `AudioBuffer.h` | Multi-channel audio buffer. | `resize()`, `clear()`, `addChannel()`, `channelReader/Writer()` |
| `AudioSpan.h` | Non-owning view into audio buffers. | `fill()`, `applyGain()`, `meanSquared()`, `getNumFrames()` |
| `AudioReader.h/.cpp` | Audio file decoding (libsndfile, etc.). | |
| `Buffer.h` / `BufferPool.h` | Generic reusable buffer pool for scratch memory. | |

### DSP Utilities

| File | Role |
|------|------|
| `Interpolators.h/.cpp` | Sample-rate interpolation modes (linear, sinc, etc.). |
| `SIMDConfig.h` / `SIMDHelpers.h/.cpp` | SIMD-accelerated DSP primitives. |
| `MathHelpers.h` | Math constants, fast functions (767 lines). |
| `SfzFilter.h/.cpp` / `SfzFilterImpls.hpp` | Multi-mode state-variable filter. |
| `OnePoleFilter.h` | 1-pole IIR filter template. |
| `Smoothers.h/.cpp` | Parameter smoothing (ramp/jump). |
| `Wavetables.h/.cpp` | Wavetable pool with `DualTable` for smooth interpolation. |
| `WindowedSinc.h/.cpp` | Windowed sinc interpolation for pitch shifting. |
| `Oversampler.h/.cpp` | 2x/4x oversampling with anti-aliasing filters. |
| `Panning.h/.cpp` | Stereo pan/balance algorithms. |
| `PowerFollower.h/.cpp` | RMS-based envelope follower. |
| `ScopedFTZ.h/.cpp` | RAII flush-to-zero mode for denormal suppression. |
| `RTSemaphore.h/.cpp` | Real-time safe counting semaphore. |
| `HistoricalBuffer.h` | Fixed-size circular buffer for history/analysis. |

### MIDI / Clock

| File | Role | Key Exports |
|------|------|-------------|
| `MidiState.h/.cpp` | Per-channel MIDI event state (pitch bend, CC, aftertouch). | `struct ChannelState` |
| `BeatClock.h/.cpp` | Musical clock with BBT (bar-beat-tick) timekeeping. | `struct TimeSignature`, `struct BBT` |
| `Metronome.h/.cpp` | Audio metronome click generator. | |
| `CCMap.h` | CC number to parameter mapping. | |
| `Curve.h/.cpp` | Value mapping curves (e.g. CC -> parameter). | |
| `Tuning.h/.cpp` | Microtuning table (Scala .scl / .tun import). | |

### Instrument Import

| File | Role |
|------|------|
| `import/sfizz_import.h/.cpp` | Dispatch to import foreign instrument formats. |
| `import/ForeignInstrument.h/.cpp` | Base for foreign instrument import. |
| `import/foreign_instruments/AudioFile.h/.cpp` | Import raw audio file as an instrument. |
| `import/foreign_instruments/DecentSampler.h/.cpp` | Import DecentSampler (.dspreset) format. |

### Clients

| File | Role | Key Exports |
|------|------|-------------|
| `clients/jack_client.cpp` | JACK audio/MIDI client. | `process()`, `loadInstrument()`, `cliThreadProc()` |
| `clients/sfizz_render.cpp` | Offline headless render tool. | |
| `clients/MidiHelpers.h` | Raw MIDI byte parsing. | |

---

## Architectural Patterns

### 1. Layered API (C -> C++ -> Internal)

`sfizz.h` (C API) wraps `Synth` via opaque pointer. `sfizz.hpp` (C++ API) adds RAII
via `sfz::Client` which owns a `Synth`. Both delegate to `Synth` internals.

### 2. Voice as Unit of Rendering

Each active note owns a `Voice`. `VoiceManager` maintains a pool; when polyphony
is exceeded, `VoiceStealing` selects a victim. Each `Voice` references a `Region`
(static SFZ definition) and a `RegionStateful` (runtime state).

### 3. Modulation Matrix

`ModMatrix` connects modulation sources (LFOs, envelopes, MIDI CC) to targets
(volume, pitch, filter cutoff, etc.). Sources implement a `ModGenerator` interface.
Routing is keyed by `ModKey` and the matrix applies depth scaling and curves.

### 4. Effect Chain

Effects are modeled per effect type (Gain, Filter, Eq, ...). `Effects` manager
instantiates and sequences them. Resonant string/reverb use SIMD backends
(scalar/SSE4/AVX2) selected at dispatch.

### 5. File Pool + Background Loading

`FilePool` manages sample file discovery, background decoding (via queued
`QueuedFileData`), and cached `FileData` and `FileMetadata` structures.
`FileId` uses content hashing for identity.

### 6. SFZ Parser -> Opcode -> Region

`Parser` produces raw header/opcode pairs. `Opcode` normalizes them (including
`OpcodeCleanup`). `Defaults` provides default opcode values per `OpcodeFlags`.
`Region` assembles parsed opcodes into a renderable region definition.

### 7. Real-Time Safety

`RTSemaphore` provides lock-free signaling for cross-thread communication.
`ScopedFTZ` controls denormal handling. `Messaging` enables non-blocking
event dispatch between the control thread and audio thread.

### 8. SIMD Abstraction

DSP helpers in `SIMDHelpers.h` provide architecture-optimized paths.
Resonant effect implementations ship scalar, SSE4, and AVX2 variants
selected at compile/runtime.

---

## How Components Connect

```
External Host / JACK
        |
  [sfizz.h / sfizz.hpp]   <-- Public API
        |
  [Synth]                 <-- Central coordinator; owns all subsystems
     |--- [Parser]         Reads .sfz -> Opcode -> Region objects
     |--- [FilePool]       Loads sample audio on demand
     |--- [MidiState]      Tracks per-channel CC/pitch/aftertouch
     |--- [VoiceManager]   Allocates Voice instances per note-on
     |       |--- [Voice]  Renders one voice: reads Region, applies
     |       |       |       Envelopes, Filters, ModMatrix, Effects
     |       |--- [VoiceStealing]  Reclaims voices when full
     |--- [Effects]        Applies master FX bus (reverb, limiter, etc.)
     |--- [ModMatrix]      Routes modulation sources to targets
     |--- [BeatClock]      Tempo-synced timing
     |--- [Messaging]      Thread-safe event bus for params/state
```

`Synth` is the single entry point for all operations: load file, send MIDI,
render audio block. It wires together the parser (for SFZ definitions),
file pool (for samples), voice manager (for note lifecycle), effects
(for DSP processing), and modulation matrix (for dynamic parameter control).
