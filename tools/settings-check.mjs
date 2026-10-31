// settings-check.mjs — gates the persistence items: the settings bridge
// round-trips, settings are reachable from boot with no progression,
// and the memory bridge (remembered loneliness) visibly shifts the
// actor at the next visit's start.
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { createGame, INPUT } from "../web/game.mjs";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const wasmBytes = readFileSync(join(root, "zig-out/idle-hands.wasm"));
function fail(msg) { console.error(`settings-check: ${msg}`); process.exit(1); }

const game = await createGame(wasmBytes, { seed: 7, level: 0, demo: false });
function steps(n, bits = 0) { for (let i = 0; i < n; i++) game.step(bits); }

if (game.screen() !== 0) fail("boot screen is not the 18+ gate");
game.applySettings(true, false);
if (game.settingsBits() !== 1) fail("apply_settings(calm_room) did not round-trip");
game.applySettings(false, true);
if (game.settingsBits() !== 2) fail("apply_settings(text_large) did not round-trip");
game.applySettings(true, true);

steps(1, INPUT.confirm);
if (game.screen() !== 1) fail("confirm did not leave the gate");
steps(1, INPUT.down); steps(1, INPUT.down);
steps(1, INPUT.confirm);
if (game.screen() !== 5) fail(`settings not reachable from title (screen=${game.screen()})`);
steps(2);
if (!game.frameText().includes("CALM")) fail("settings screen does not show restored CALM motion");
if (!game.frameText().includes("LARGE")) fail("settings screen does not show restored LARGE text");

// Memory bridge: a remembered visit at 0.8 loneliness must greet the
// next visit measurably lonelier than a fresh one.
const fresh = await createGame(wasmBytes, { seed: 7, level: 0, demo: false });
fresh.startLevel(0);
const left = await createGame(wasmBytes, { seed: 7, level: 0, demo: false });
left.applyMemory(2, 800);
left.startLevel(0);
if (!(left.loneliness() > fresh.loneliness())) {
  fail(`remembered loneliness did not shift the actor (fresh ${fresh.loneliness()} vs left ${left.loneliness()})`);
}
console.log(`settings-check: bridge round-trips; settings ungated; memory shifts the actor (fresh ${fresh.loneliness().toFixed(2)} vs remembered ${left.loneliness().toFixed(2)})`);
