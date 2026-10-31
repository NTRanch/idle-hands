// perf.mjs — step budget: 10,000 steps (each emitting a full draw
// list) in under 2 s; wasm artefact under 96 KB.
import { readFileSync, statSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { createGame } from "../web/game.mjs";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const wasmPath = join(root, "zig-out/idle-hands.wasm");
const wasmBytes = readFileSync(wasmPath);
const game = await createGame(wasmBytes, { seed: 31, level: 2, demo: true });
game.startLevel(2);
const t0 = performance.now();
for (let i = 0; i < 10_000; i++) game.step(0);
const ms = performance.now() - t0;
const size = statSync(wasmPath).size;
console.log(`perf: 10000 steps in ${ms.toFixed(1)} ms (${(ms / 10000).toFixed(3)} ms/step); wasm ${size} bytes`);
if (ms >= 2000) { console.error("perf: step budget exceeded"); process.exit(1); }
if (size >= 98_304) { console.error("perf: wasm size budget exceeded"); process.exit(1); }
console.log("perf: within budget");
