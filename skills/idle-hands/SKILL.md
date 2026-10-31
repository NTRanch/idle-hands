---
name: idle-hands
description: Build and validate Idle Hands (Torogao Jam Program week 2, Odin). Use when working on the Idle Hands jam entry — its mechanism group, Odin build chain, single-file delivery, and port-back.
---

# Idle Hands — week 2 jam entry

**Canon core:** The companion-idle toy, in her rope room.
**Cast:** Yui · **Language:** Odin (tiger-style-odin)

## Mechanism group

- Idle acting (breath, blinks, look targets)
- Secondary motion (rope props, hair, sleeves)
- Fidget vocabulary — she coils rope without thinking: her step-1 Descent trace played as behaviour, not text
- Click / neglect reactions
- Session persistence — she remembers being left alone, and it shows next visit

## Build

- Delivery: Compile to wasm32, inline the module (base64) in the single index.html; JS is loader and DOM bridge only. Toolchain home: sandbox.
- Planning book: `book/` (mdBook; `mdbook build book`).
- Engine/library pins: book chapter "Engine Research" — read before adding
  any dependency; the from-scratch register (book chapter "Write From
  Scratch") names what must NOT be replaced by a library.

## Gates

1. bloch: start the roadmap item before work; `bloch task done` earns green.
2. Single-file assembly runs offline with all ≥6 screens.
3. Seahawk playtest pass; breakage filed to bloch.
4. Visual gate (D-221) against the Laplace3D quality bar (book chapter).
5. Port-back note + language verdict + §9 filing (book chapter "Port-Back").

## Standing law

D-292 keeper art only · audio silence (metrics only, Owner presses play) ·
18+ surfaces flagged (GJ-07) · restricted lane.
