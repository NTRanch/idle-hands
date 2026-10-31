# Planning — Idle Hands

- **Program:** Torogao Jam Program (D-333), week 2 of 14, Wave A — Animation
- **Cast:** Yui
- **Language:** Odin (tiger-style-odin)
- **Canon core:** The companion-idle toy, in her rope room.

## Mechanism group (D-334: primary + coupled + persistence/revelation + feel)

- Idle acting (breath, blinks, look targets)
- Secondary motion (rope props, hair, sleeves)
- Fidget vocabulary — she coils rope without thinking: her step-1 Descent trace played as behaviour, not text
- Click / neglect reactions
- Session persistence — she remembers being left alone, and it shows next visit

## Validates

Sprite acting at jam scale, and whether a Descent trace works as ambient characterisation.

## Port-back

Idle-cycle parameters for lumen-rig-bevy; the fidget vocabulary list; Odin verdict (data-oriented layout for actor sims).

## Delivery

Compile to wasm32, inline the module (base64) in the single index.html; JS is loader and DOM bridge only. Toolchain home: sandbox.

## Open preflight items

- GJ-06-class start gate for this week's toolchain (later weeks gate their
  own preflight; only W1's gate covers the program start).
- GJ-07: 18+ flag, content warnings listed, itch ToS screen — verified live
  at entry (the NSFW allowance clause is Owner-reported; re-verify on page).
- Engine-research chapter in the book: confirm the pinned library versions
  before the first build commit.
