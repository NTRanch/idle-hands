> **Game page:** the full storefront page for this game lives at [docs/GAME-PAGE.md](docs/GAME-PAGE.md).

# Idle Hands

**Nice Thoughts Ranch** · Torogao Jam Program week 2 (Wave A — Animation) · Yui · **Odin**

The companion-idle toy, in her rope room.

An 18+ game built for the weekly Gameotron jam on itch.io (NTRanch), as one
rung of the 14-week Torogao system-validation program (D-333/D-334/D-335/D-336).
The full planning book lives in [`book/`](book/) (mdBook, NTRanch theme);
this repo's bloch roadmap is [`.ai/roadmap.md`](.ai/roadmap.md).

- **Delivery:** one self-contained `index.html` (see `docs` in the book).
- **Cast/art law (D-292):** existing keeper art only; a missing asset is an
  abstract stand-in, logged — never a generation job.
- **Quality bar:** Laplace3D-class animation or the medium's equivalent
  (book chapter: Quality Bar).
- **Audio:** nothing is ever played aloud by an agent; the Owner presses play.

## Play

Open [`web/index.html`](web/index.html) in a browser — it runs fully
offline. She waits, breathes, blinks, and looks at things: the window,
the rope, her hands, you. Click the thing she is looking at (once her
look has settled) to connect. Leave her unseen and loneliness changes
how she sits — and greets your next visit.

- **Level 1 — First Visit:** make 8 connections before loneliness
  fills the room.
- **Level 2 — Rope Practice:** watch the coil order she shows you,
  then click the coils back in order — three sequences together.
- **Level 3 — The Long Quiet:** stay with her for 150 seconds while
  the room pulls her attention thin.

Settings (room motion, text size), your visit count, and the loneliness
she carries away persist in the browser. Settings are reachable before
any play.

## Preview videos (rendered from the shipped core, demo mode)

- [Level 1 — First Visit](docs/previews/level-1-idle-hands.mp4)
- [Level 2 — Rope Practice](docs/previews/level-2-idle-hands.mp4)
- [Level 3 — The Long Quiet](docs/previews/level-3-idle-hands.mp4)

## Build & verify

```sh
just build   # Odin core -> wasm + assemble web/index.html
just check   # 11 core tests, bridges, perf budget, playtest
just previews
```

Status: **v1.0.0** (2026-10-30) — playable, gated, tagged. The seahawk
playtest pass on primo and the live itch.io entry checks (GJ-07) remain
scheduled follow-ups; both are recorded in `docs/BREAKAGE-LOG.md`.
