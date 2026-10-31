// idle-hands/src/main.odin — Idle Hands core (Odin, wasm32).
// Tiger Style (tiger-style-odin): explicit contracts, bounded work,
// disciplined manual memory. Data-oriented actor simulation; fixed-step.
package main

// One fixed simulation step, called by the shell at 60 Hz.
@(export)
step :: proc() {}
