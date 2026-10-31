# Changelog — Idle Hands

All notable changes, newest first. Format: Keep a Changelog.

## [1.0.0] — 2026-10-30

First playable release: the full W2 mechanism group, built and gated in
the sandbox under the Owner's v1.0 jam directive.

- **Idle actor simulation** (Odin, freestanding wasm32): breath loop,
  loneliness-modulated blink timing, look targets with spring-lag gaze
  (full-disc centres), and secondary motion — hair and sleeves chase
  the breath and gaze with lag; the hanging rope sways on her breath.
- **Fidget vocabulary**: six fidgets (coil rope, tug sleeve, glance at
  the door, hum, shift seat, touch hair) — her step-1 Descent trace as
  ambient behaviour, scheduled from room quiet.
- **Attention gameplay**: click what she is looking at to connect (a
  look must settle 900 ms first, and a connection consumes it); three
  levels — First Visit (8 connections), Rope Practice (coil-order
  sequences together), The Long Quiet (150 s of staying).
- **Neglect made visible**: loneliness sinks her posture, slows her
  blinks, and — through the shell's persistence bridge — greets the
  NEXT visit: she remembers being left alone.
- **Screens**: 18+ gate, title with level picker, how-to, gameplay,
  pause, settings (room motion, text size), victory, game over.
- **Audio**: generated WebAudio cues answering player input only.
- **Previews**: `docs/previews/level-{1,2,3}-idle-hands.mp4`, rendered
  from the shipped core in demo mode.
- **Gates**: 11 core tests (validation + adversarial), settings/memory
  bridge check, performance budget (0.027 ms/step, 40.5 KB wasm),
  scripted playtest completing all three levels.

## [0.1.0] — 2026-10-30

- Repo scaffolded 2026-10-30: bloch roadmap (kind=game, lane=restricted),
  planning, per-game skill, baseline Odin config, NTRanch-themed mdBook,
  brand assets (header + icon).
