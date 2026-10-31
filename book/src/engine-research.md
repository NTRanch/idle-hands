# Odin — W2 *Idle Hands* (idle / acting simulation)

**Language:** Odin (the data-oriented systems language; compiler and standard library from https://odin-lang.org/).
**Role in this program:** Pass 1, W2 *Idle Hands* — Yui's companion-idle toy in her rope room: idle acting (breath, blinks, look targets), secondary motion, a fidget vocabulary, click/neglect reactions, and session persistence. Odin was assigned here because an acting sim is arrays of small state updated every tick — data-oriented layout is the week's actual test question.
**Delivery shape:** Odin core compiled to wasm32 (`js_wasm32`), the module base64-inlined into ONE self-contained `index.html`; JS is loader and DOM bridge only. Native desktop build (with hot reload) is the development harness.
**Port-back target:** idle-cycle parameters and the fidget vocabulary list land in lumen-rig-bevy; the Odin sim's struct-of-arrays layout is the evidence for how Torogao's actor data should be shaped in Rust.

**Headline verdict:** Odin is the most *batteries-included* language in the rotation: its official `vendor:` collection ships raylib, SDL2, miniaudio, microui, and stb with the compiler — no package-manager negotiation at all. The web build, however, is a community template rather than a first-class target, and that asymmetry is the whole risk profile of this week: everything is easy except the last mile to the browser, which must be proven in the preflight, not discovered in build week.

---

## Parts matrix

### (a) Windowing / rendering 2D

| Choice | What | License | Maturity |
|---|---|---|---|
| **PRIMARY: `vendor:raylib`** — ships with Odin (https://odin-lang.org/); raylib itself: https://github.com/raysan5/raylib | Officially maintained bindings in Odin's `vendor:` collection: window, input, textures, sprite drawing, camera, text, audio — one import (`import rl "vendor:raylib"`), zero dependency management. The vendored raylib also carries **raygui** (immediate-mode GUI) and rlgl, confirmed working in the web template below. | raylib zlib/libpng; Odin bindings ship under Odin's zlib license | raylib is one of the most battle-tested small game libraries in existence, and the Odin bindings are maintained by the Odin project itself — version-matched to the compiler by construction. This is the lowest-drift dependency in the entire 14-week program. |
| ALT: sokol-odin — https://github.com/floooh/sokol-odin | Official, auto-generated Odin bindings for the sokol headers (https://github.com/floooh/sokol — `sokol_app`, `sokol_gfx`, `sokol_audio`, WebGL2 backend on wasm). Listed as an official binding in sokol's own README. | zlib | Actively auto-updated from the C headers. A credible renderer swap if the raylib web path fights us — sokol's wasm story is more first-class than raylib's — at the cost of writing the sprite/text/audio layers raylib gives free. Keep in the preflight as the documented fallback, not a mid-week improvisation. |
| ALT: `vendor:sdl2` + `vendor:OpenGL` / WebGL bindings | Also vendored with Odin (the homepage lists official bindings for SDL2, GLFW, and graphics APIs including WebGL 1 & 2). | SDL2 zlib; bindings zlib | Fully viable hand-rolled path; strictly more work than raylib for the same result. Not chosen. |
| Native-only note | The desktop harness uses the same `vendor:raylib` — one codebase, two targets, which is precisely what the hot-reload template (h) exploits. | — | — |

### (b) Sprite animation & skeletal / 2.5D rig playback

| Choice | Verdict |
|---|---|
| Sprite-sheet / layered-part playback | **NONE — write it (small), and W2 is where the program writes it best.** No Odin library provides a layered-part character animator. Our playback is a fixed-step evaluator over part arrays (position/rotation/scale/opacity per part) — and in Odin those arrays are struct-of-arrays by idiom (separate `xs`, `ys`, `rotations` slices, or an AoS→SoA layout chosen per system), which is the data-oriented experiment this week exists to run. raylib supplies only the final textured-quad draws. |
| Spine skeletal data | **spine-c via `foreign` imports — conditional, not adopted.** The official Spine Runtimes include a plain-C runtime (`spine-c`) — https://github.com/EsotericSoftware/spine-runtimes — and Odin's C interop is first-class, so binding it is mechanical. **License catch:** distribution requires a Spine editor license held at integration time (Spine Runtimes License Agreement, see the repo README), and no ready-made Odin binding exists — the glue (atlas/texture callbacks into raylib) is ours to write and debug inside a jam week. The estate's lumen-rig format is the rig of record; Spine is recorded as available-and-declined, same as the Zig week. |
| Live2D Cubism | **NONE (practical).** Cubism Core is a proprietary closed-source binary with a C API under the Live2D Proprietary Software License, with a C++ framework on top (https://github.com/pixhaus-app/pixhaus/blob/HEAD/docs/planning/skeletal-animation/Live2D-Cubism.md). No Odin binding exists; hand-binding a proprietary blob for a one-week idle toy is out of scope. |
| Tween/easing | **NONE as a library.** Easing is closed-form functions + keyframe tracks evaluated by the sim. raylib has a handful of easing helpers in its examples tradition but nothing we'd import as a system. |

### (c) Audio playback + reactive sync

W2 is not the program's audio week (that is W5/W8), but idle toys still need ambient sound, reaction barks, and click feedback — and the sync question must be answerable here too.

| Choice | What | License | Maturity |
|---|---|---|---|
| **PRIMARY (in-scope sounds): raylib audio** (in `vendor:raylib`) | `LoadSound`/`PlaySound` for one-shots (clicks, rope creaks, barks), `LoadMusicStream` for the room ambience loop, `GetMusicTimePlayed` for coarse position. Zero extra dependencies. | zlib | raylib's audio is miniaudio-backed and thoroughly proven. Position queries are music-stream grade (tens of ms), **not** a sample clock — fine for W2, and the honest reason W8 is a Zig/sokol week instead. |
| Sample-accurate option: `vendor:miniaudio` — package docs: https://pkg.odin-lang.org/vendor/miniaudio/ | Direct bindings to miniaudio (https://github.com/mackron/miniaudio, v0.11.25 in current Odin): full engine — decoding (WAV/MP3/Ogg Vorbis/FLAC), mixing, and a low-level API where our own render callback counts samples. | miniaudio MIT-0 / public-domain dual; bindings ship with Odin | miniaudio is extremely mature; the Odin bindings are official. If a reaction must land on a sample boundary, drop from raylib audio to miniaudio directly and drive the sim off the callback's frame count — same audio-clock pattern as the Zig week, available here without leaving the vendor collection. |

### (d) UI / text rendering — dialogue boxes, fonts

| Choice | What | License | Maturity |
|---|---|---|---|
| **PRIMARY (dialogue & labels): raylib text** (in `vendor:raylib`) | `LoadFontEx` (TTF → glyph atlas), `DrawTextEx`, `MeasureTextEx`, codepoint-aware drawing. Renders Yui's reaction lines and UI labels. | zlib | Proven at scale. Limits: layout is manual (word-wrap, line-breaking, and dialogue-box pagination are **ours** — a small, well-understood write), and text shaping is basic: no HarfBuzz-class shaping (the vendor collection's `stb/truetype` + fontstash + kb_text_shape pieces — see below — improve rasterization/shaping at the margins, not to full complex-script grade). Latin dialogue: fine, stated honestly. |
| Font plumbing underneath: `vendor:stb/truetype`, fontstash, kb_text_shape | The Odin vendor collection's text/font tier (catalogued in the all-vendor example: https://deepwiki.com/karl-zylinski/kodin/9.2-core-and-vendor-library-examples): stb_truetype rasterizes glyphs (public domain/MIT), fontstash manages the atlas, kb_text_shape does lightweight shaping. Available if raylib's font path needs replacing; normally raylib already wraps this class of machinery. | stb public domain/MIT | Vendored and version-pinned with the compiler. |
| **UI widgets (menus, settings, jam screens): raygui** (bundled with vendored raylib) | Immediate-mode controls — buttons, sliders, panels — in raylib's own style. | zlib | Ships and works in the web template. Look is utilitarian; for the six jam screens (Title/Pause/How to Play/Gameplay/Settings/Game Over) that is acceptable, and the hot-pink restyle is a colour table, not a framework change. |
| ALT widgets: `vendor:microui` | A tiny immediate-mode UI library ported to Odin, vendored officially (ported from rxi/microui, MIT). | MIT | Smaller and more embeddable than raygui; choose it only if raygui's widget set misses something the screens need. Two vendored UI options is a luxury no other week in this program has. |

### (e) State machines / data tables

**No library — Odin's idiom is the library, differently from Zig.**
- Odin has **no comptime table generation** of Zig's kind. The equivalent discipline: state as enums with exhaustive `switch` (Odin requires exhaustiveness handling), actor state in struct-of-arrays, and behaviour tables as plain Odin array literals in a `tables.odin` source file — data you can read in a diff, edited like code.
- Runtime-loaded tables: `core:encoding/json` (in the standard library) parses JSON scene/fidget tables if we want author-editable data without recompiling; for the jam, compile-in literals are preferred (one less runtime parser in the single file, one less failure mode).
- Fidget vocabulary as data: the week's signature structure is a table of fidget entries (trigger conditions, part-animation clip, cooldown, neglect-weight) — rows in an array, evaluated by one small interpreter proc. Adding a fidget is adding a row, which is exactly the property the port-back wants to verify for lumen-rig-bevy.
- Math: `core:math` + `core:math/linalg` ship with the language.

### (f) Persistence (localStorage via JS bridge)

**No library; a small bridge, ours — slightly more hand-work than Zig's.**
- W2's persistence element is canon: *she remembers being left alone, and it shows next visit* — a tiny save struct (visit count, total idle time, neglect flags, last-visit timestamp).
- Serialization: `core:encoding/json` marshal/unmarshal of a typed struct; version field from day one.
- The bridge: on the `js_wasm32` target the Odin program is called from JavaScript (per the web template below), and Odin declares `foreign` procs implemented in the JS shell against `localStorage`. There is no vendored localStorage wrapper — expect ~40 lines across the Odin/JS seam, written once and shared with any later Odin-shaped need. itch-iframe origin partitioning applies exactly as in the Zig chapter: saves live on the embed origin; state that on the page.

### (g) Asset pipeline

| Need | Tool | Notes |
|---|---|---|
| Image decode | raylib's loaders (PNG/JPEG/etc. via its stb_image core) at runtime; `vendor:stb/image` directly for tooling | stb is public domain/MIT; both paths are vendored — no external dependency either way. |
| Texture atlases | `vendor:stb/rect_pack` for packing in a build-time Odin tool; community option: Karl Zylinski's atlas-builder — https://github.com/karl-zylinski/atlas-builder (a small Odin program that packs a folder of textures into an atlas) | Deterministic (sorted) packing for reproducible builds; atlas + manifest emitted at build time, runtime draws from one texture. |
| Audio formats | Ship Ogg Vorbis (ambience loop) + WAV (one-shots); decode via raylib/miniaudio | Same estate format policy as the Zig week. |
| Embedding | `#load` directive / generated `.odin` byte arrays | Odin has no `@embedFile` equivalent as slick as Zig's; the web template's approach is to bake assets into the wasm via `#load` (compile-time file → byte slice) or a generated source file from the atlas tool. Workable, slightly more ceremony — recorded as a real (small) Zig advantage. |
| Keeper art | Estate keeper PNGs only (D-292: no new character generation); missing art = abstract stand-in, logged | The pipeline ingests existing art; it generates none. Rope-prop and room art are the week's real asset load. |

### (h) Build tooling — wasm, single-file inlining, testing, CI

- **Web build (the seam that defines this week):** the community template **odin-raylib-web** — https://github.com/karl-zylinski/odin-raylib-web (MIT, by Karl Zylinski, author of the Odin book) — builds Odin + vendored raylib for the browser. Its current line targets `js_wasm32` and calls the Odin code straight from JavaScript via an `index_template.html`; its sibling hot-reload template (https://github.com/karl-zylinski/odin-raylib-hot-reload-game-template) adds desktop hot reload with release-web support. This is proven, shipped-template infrastructure — and it is still **one maintainer's template, not an Odin-project-supported target**. The W2 preflight exists to build a hello-world through it on day one.
  Known wasm pitfalls from the template's own troubleshooting record and the Odin forum: stack-size defaults that fail only in the browser, allocator behaviour differences under wasm, and `core` procedures that silently no-op on JS targets (e.g. file loading — one jam game's web build died on exactly that; our `#load`-everything rule in (g) is the countermeasure). Forum PSA: https://forum.odin-lang.org/t/psa-having-new-weird-wasm-issues-but-not-with-your-desktop-binary/1229 — "test your WASM export often" is the template author's own advice, adopted here as a daily-build ritual, not a hope.
- **Desktop dev build:** `odin run .` / the hot-reload template — change code, see the toy move, no restart. Within a one-week jam this iteration speed is Odin's biggest practical gift to W2.
- **Single-file inlining:** **ours** — the template emits `index.html` + `.wasm` (+ JS glue); the estate pack step (shared with the Zig weeks) base64-inlines the wasm into the shell. No Odin tool does this off the shelf.
- **Size:** LLVM-level optimization via `odin build -o:size`/`-o:speed` choices, plus Binaryen `wasm-opt -Oz` (https://github.com/WebAssembly/binaryen, Apache-2.0) post-pass, shared with the Zig pipeline.
- **Testing:** `odin test` is built into the toolchain (`core:testing`) — the pure sim (idle scheduler, fidget interpreter, neglect/persistence logic) is renderer-free and headless-testable on the native target, including fixed-step replay determinism checks.
- **CI:** GitHub Actions: install a pinned Odin release, run `odin test`, build native + web targets. Pin the Odin version — vendor bindings are version-matched to the compiler, so a compiler bump is a dependency bump and must be treated as one.

---

## Write-from-scratch register

Nothing below exists as a library in Odin (or, for most, in any language). Each entry: why, which layer, what it rides on.

1. **Face-state system (F-code expressions, gaze/blush channels)**
   Why no library: F-codes are estate canon; no library knows our expression taxonomy, and in W2 the face is one actor among the idle systems, driven by the same tick as everything else.
   Layer: **pure core** (channel values per tick) + thin presentation mapping to part transforms/iris/blush.
   Rides on: the SoA actor arrays (e) and raylib part rendering (a). W2's specific load is small — blinks, look targets, daze/kept expressions — but it must speak the same channel interface as W1's Zig machine, or the port-back comparison is meaningless. That interface (core emits channels; presentation obeys) is designed once and shared by both weeks.

2. **Arousal engine (tiered, exactly-once culmination)**
   Why no library: domain rules engine; W2 touches it only at its lowest tiers (idle warmth, reaction blush coupling), but the register records the full verdict: Odin offers state-machine *idiom* (enums, exhaustive switches, SoA state) and no engine — same as everywhere.
   Layer: **pure core**, fixed-step; W2 instantiates only the low-tier slice, behind the same interface the W6 engine week will exercise whole.
   Rides on: tables as Odin literals (e); testable via `odin test` replay (h).

3. **Sex-scene staging / contact & two-body animation**
   Why no library: the estate's named research problem; single-skeleton runtimes (Spine included) know nothing of two bodies in contact. W2 is a single-character week — the honest Odin verdict is that its contribution here is *indirect*: the SoA part/anchor representation (contact anchors as data on parts) is the shape the W4 two-body week will stress, and W2 proves that shape at idle scale.
   Layer: **presentation** (ordering, anchors, occlusion) over core scene state.
   Rides on: layered-part playback (b) + raylib draws (a).

4. **Lactation / fluid simulation**
   **Not in W2's scope** — recorded so the register is complete across the program: no Odin library provides it (it is a deterministic reservoir/rate model, not a physics sim), and if a later Odin-shaped week needed it, it would sit in the pure core exactly as in the Zig chapter, riding the fixed-step tick and the persistence layer for charting. Nothing about Odin helps or hinders it specifically; the model is arithmetic.

5. **Signature-tool mechanics (W2: the companion-idle toy itself — rope props as fidget instruments)**
   Why no library: the "tool" here is Yui's rope and the fidget vocabulary around it — canon content expressed as data (register (e)): each fidget is a table row naming a prop animation, a trigger (idle duration, neglect level, click history), and a cooldown.
   Layer: core interpreter over the fidget table + presentation clips.
   Rides on: SoA part animation (b) and the persistence struct (neglect state feeds triggers). The week's port-back claim is precisely that a *vocabulary* fell out of a table — if adding a fidget ever requires a code change, the design failed and the breakage log should say so.

6. **Development / exposure ledgers (W2: session persistence — the neglect/visit record)**
   Why no library: ledger semantics are canon (what counts as a visit, what neglect means, what carries forward). A save system stores bytes; meaning is ours.
   Layer: **pure core** (append-only visit entries, derived "how she greets you" state) + persistence (f).
   Rides on: `core:encoding/json` + the JS localStorage bridge. Deliberately the smallest ledger in the program — it is the shape-check for W13's full exposure ledger: if the small one is not clean, the big one will not be either.

7. **Idle/acting scheduler itself (breath, blinks, look targets, secondary motion)** — *W2's core deliverable, listed because it is a system, not a library call.*
   Why no library: "acting" is layered procedural behaviour — a breath oscillator, a blink timer with humanized jitter, a look-target chooser with dwell and saccade steps, damped followers for hair/sleeves/rope ends — composed per character. Engines give you animation *players*; nobody ships *aliveness*.
   Layer: **pure core**, fixed-step, seeded PRNG for jitter (deterministic per seed, replay-testable).
   Rides on: SoA arrays (e) — every layer is a pass over part arrays, which is the data-oriented design the week is testing; presentation is raylib quads (a).

---

## Quality bar — Laplace3D-class minimum, per criterion

The bar (estate-measured): 60 fps presentation; motion on every frame; secondary-motion lag ≤17 ms; humanized timing jitter, never metronomic; expression readability at presentation size; seamless loops (seam ratio ≤1.1); audio/reaction sync ≈ +12 ms ±25 ms; deterministic fixed-step evaluation.

| Criterion | Odin: helps / fights |
|---|---|
| 60 fps presentation | **Helps.** raylib's renderer + Odin's compiled speed make 60 fps at VN complexity undramatic on desktop. Fights (web): the browser build's frame pacing is the template's, not ours — measure on the real itch embed in preflight; a desktop-only fps number is not evidence. |
| Motion on every frame | **Helps — this is W2's home criterion.** The idle scheduler exists precisely to guarantee layered motion (breath + sway + fidgets + followers) on every tick; there is no frame in which the sim emits a static pose unless a table explicitly asks for stillness. |
| Secondary-motion lag ≤17 ms | **Helps.** Followers are damped integrators in the fixed-step core over SoA arrays — lag is a per-part constant in ticks, tuned per part class (hair slower than sleeves), and replay tests can assert the measured lag directly. SoA layout makes per-part-class passes trivial. |
| Humanized jitter, never metronomic | **Helps, with discipline required.** Seeded PRNG in the core gives *reproducible* humanization (same seed → same performance → testable, screenshot-able, gate-able). Fights: blink/breath timers written as plain period counters will metronome; the jitter bands must be in the tables from the first commit, not tuned in later. |
| Expression readability at presentation size | **Neutral.** raylib draws what the art and channel ranges say; nothing in Odin helps or hurts. The §1.7 gaze definition and presentation-size checks are process, not language. |
| Seamless loops (seam ratio ≤1.1) | **Helps.** Loop phase from an integer tick counter; breath/sway are periodic functions of tick, so loop boundaries are continuous by construction. Ambience audio loop is an Ogg with a sample-counted loop point via miniaudio if raylib's stream loop clicks — the fallback is already vendored. |
| Audio/reaction sync ≈ +12 ms ±25 ms | **Adequate for W2, honestly bounded.** Click→bark reactions are event-driven through raylib audio — perceived sync is dominated by browser audio latency, within the ±25 ms window for *reactions*. What Odin/raylib does **not** give is W8-grade sample-clock scheduling without dropping to `vendor:miniaudio`'s callback (available, see (c)) — W2 doesn't need it, and the chapter says so rather than borrowing W8's claim. |
| Deterministic fixed-step evaluation | **Helps, with one named trap.** The sim is ours: fixed-step accumulator, seeded RNG, no wall-clock inside the tick — fully replay-deterministic and `odin test`-able. **Trap:** raylib's own timing (`GetFrameTime`, `GetTime`) is wall-clock and sits within arm's reach; the rule is *raylib time may pace the accumulator, never enter the sim*. One code-review checklist line enforces it. |

---

## Risks / seams (honest)

1. **The web target is a community template, not a language feature.** odin-raylib-web is good, maintained, MIT infrastructure — and it is one person's template around a compiler target that is still settling (`js_wasm32` replaced `freestanding_wasm32` in the template's own history). If it breaks against our pinned Odin version, the fix is ours. Preflight day one builds through it; the sokol-odin fallback (a) is named in advance so a pivot is a decision, not a scramble.
2. **Wasm-only failure modes are real and documented by the community:** stack-size defaults, allocator differences, `core` procedures that no-op on JS targets (file I/O is the classic). Countermeasures are known (test the export daily, `#load` all assets, set stack size deliberately) — but they are countermeasures for failures we *will* meet, not hypothetical ones.
3. **No comptime tables.** Behaviour data lives in source literals or JSON. That is readable and diffable, but nothing type-checks a fidget table's *referential* integrity (a row naming a nonexistent clip fails at runtime, not compile time). Mitigation: a validation pass in `odin test` that walks every table against the clip registry — write it in week one, it is the Odin equivalent of Zig's free comptime check.
4. **Text is the thin layer.** Word-wrap/pagination are ours; shaping is basic. For a dialogue-light idle toy this is fine. A dialogue-heavy Odin week would re-open this line — recorded so W9/W13's Lua choice (a language with the same thinness, chosen for tables) isn't later compared against a fictional Odin text stack.
5. **Hot reload is desktop-only.** The template's own note: web builds are release builds, no hot reload. The iteration loop is desktop-fast and browser-verified-daily; anyone expecting hot reload *in the browser* will be disappointed exactly once.
6. **Vendor pinning cuts both ways.** Zero dependency drift inside a week — and zero upstream fixes without a compiler bump. For a 14-week program that is the right trade; for a long-lived product it would need a policy. The jam takes the trade knowingly.
7. **Port-back is parameters and layout, not code.** lumen-rig-bevy gains idle-cycle constants, the fidget-table format, and evidence that SoA actor layout carries an acting sim. The Odin code is disposable by design — the program's deal, stated here so the repo is never mistaken for a shipping branch.


## How the research applies to Idle Hands

- Language: **Odin** under tiger-style-odin.
- Canon core: The companion-idle toy, in her rope room.
- The parts matrix in the dossier names, for every part of the full game
  (rendering, animation, audio, dialogue/UI, state, persistence, assets,
  build), the library or tool this entry pins — or states plainly that the
  part is written from scratch (see the next chapter).
