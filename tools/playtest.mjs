// playtest.mjs — automated playtest: the demo policy plays every level
// to a terminal screen against the shipped Odin wasm core. Pass =
// victory on all three levels (L3 is a 150 s survival, ~9.4k steps).
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { createGame } from "../web/game.mjs";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const wasmBytes = readFileSync(join(root, "zig-out/idle-hands.wasm"));
const SCREENS = ["gate", "title", "howto", "play", "pause", "settings", "victory", "gameover"];

let failures = 0;
for (let level = 0; level < 3; level++) {
  const game = await createGame(wasmBytes, { seed: 9100 + level, level, demo: true });
  game.startLevel(level);
  let steps = 0;
  const maxSteps = (12 * 60 * 1000) / 16;
  while (game.screen() === 3 && steps < maxSteps) {
    game.step(0);
    steps++;
  }
  const won = game.screen() === 6;
  console.log(`level ${level + 1}: screen=${SCREENS[game.screen()]} steps=${steps} connections=${game.connections()} loneliness=${game.loneliness().toFixed(2)} ${won ? "VICTORY" : "FAIL"}`);
  if (!won) failures++;
}
if (failures) {
  console.error(`playtest: ${failures} level(s) not completed by the demo policy`);
  process.exit(1);
}
console.log("playtest: all 3 levels completed");
