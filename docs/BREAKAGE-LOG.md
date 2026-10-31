# Breakage log — Idle Hands

Every breakage found in playtest or build lands here with: what broke, the
evidence, the bloch attempt id, and the fix or the filed finding. Copied to
bloch at the week's close (the log is the input, bloch is the record).

## 2026-10-30 — v1.0 build (sandbox)

- **B-1: Connections could be farmed.** First playtest: L1 victory in
  8 steps / 8 connections; L3 logged 9,340 connections. The demo (and
  any player) could click the look target every step. Two-part fix: a
  connection consumes the look (she picks a new target), and a look
  must settle 900 ms before it can be met. After: L1 = 505 steps,
  L3 = 148 connections across 150 s of perfect play.
- **B-2: Test file broke the wasm build.** `odin build src` for
  freestanding wasm32 failed inside `core/os` — the same-directory
  `main_test.odin`'s `core:testing` import is resolved by normal
  builds in this Odin nightly. Fix: tests moved to `src/tests/` as
  their own package importing the core (`import ih ".."`); wasm build
  targets `src` alone. Lesson filed for the estate's Odin work.
- **B-3: Look-glow ring erased her face.** The glow was two filled
  circles; over the Viewer target the inner circle painted background
  across her features (visible in the first D-221 frame). Fix: dotted
  ring (12 dots on the circumference). Re-inspected PASS.
- **B-4: HUD collisions.** The goal counter overlapped its label in
  the raster font's advance, and the room's window sat behind the
  meter block. Fix: counter spacing measured to the font advance;
  window moved to the left-middle wall; its look-target point moved
  with it. Re-inspected PASS.
- **B-5 (held, not a defect): seahawk playtest pass not run.** Primo
  unreachable tonight (tunnel outage since 03:15 PDT). The sandbox
  automated playtest is the record of the moment; R-905's verify
  names it for this reason.
- **B-6 (held, by design of the jam): GJ-07 live itch checks open.**
  Verified live at entry time; no entry is being submitted tonight.
  R-904 stays open. The game's own 18+ gate ships first regardless.
- **B-7 (design ruling): persistence scope.** What persists (shell
  localStorage): settings + visit count + carried-away loneliness.
  There is no mid-visit save; a visit is one sitting. Recorded here
  rather than silently narrowing R-202/R-203.
- **B-8: menu/end-screen text clipped in the raster (post-tag fix).**
  The estate-wide raster-advance audit (Exposure B-4) flagged the
  how-to lines, both end titles, and the L2 sequence banner: set at
  sizes whose raster advance runs past the right edge of the rendered
  surface. Fix: how-to and banner at size 20, end titles at 40 with
  adjusted placement; audit CLEAN on all screens; previews
  re-captured. Fix commit on top of v1.0.0 before any push; the tag
  moves with it.
