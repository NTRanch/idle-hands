// game.mjs — Idle Hands core wrapper. Shared verbatim by the shipped
// page (inlined by tools/assemble.mjs) and the node harnesses.
// The core is the Odin wasm module; this wrapper only moves bytes.

export const PALETTE = [
  "#0d0208", "#ff2e88", "#f8f0ed", "#ac9393", "#540e46",
  "#ec8584", "#eaeaea", "#68636c", "#ffd166", "#1a0510", "#d9a066",
];

export const INPUT = { tap: 1, confirm: 2, back: 4, pause: 8, up: 16, down: 32 };

export async function createGame(wasmBytes, { seed = 1, level = 0, demo = false } = {}) {
  const { instance } = await WebAssembly.instantiate(wasmBytes, {});
  const ex = instance.exports;
  const status = demo ? ex.init_demo(seed >>> 0, level) : ex.init(seed >>> 0, level);
  if (status !== 0) throw new Error(`core init rejected level ${level}`);
  const decoder = new TextDecoder();
  return {
    exports: ex,
    startLevel(l) {
      const s = ex.start_level(l);
      if (s !== 0) throw new Error(`core start_level rejected ${l}`);
    },
    step(inputBits, px = 0, py = 0) {
      ex.step(16, inputBits >>> 0, px | 0, py | 0);
    },
    screen() { return ex.screen(); },
    event() { return ex.event_code(); },
    levelIdx() { return ex.level_idx(); },
    loneliness() { return ex.loneliness_milli() / 1000; },
    applyMemory(visits, rememberedMilli) { ex.apply_memory(visits | 0, rememberedMilli | 0); },
    applySettings(calmRoom, textLarge) { ex.apply_settings(calmRoom ? 1 : 0, textLarge ? 1 : 0); },
    settingsBits() { return ex.settings_bits(); },
    peakLonelinessMilli() { return ex.stat_peak_loneliness_milli(); },
    connections() { return ex.stat_connections(); },
    frameText() {
      const bytes = new Uint8Array(ex.memory.buffer, ex.draw_ptr(), ex.draw_len_export());
      return decoder.decode(bytes);
    },
    frame() {
      return { palette: PALETTE, ops: parseDrawList(this.frameText()) };
    },
  };
}

/// Parse the core's line protocol into raster/canvas ops.
export function parseDrawList(text) {
  const ops = [];
  for (const line of text.split("\n")) {
    if (!line) continue;
    const kind = line[0];
    if (kind === "t") {
      const parts = line.split(" ");
      ops.push(["t", +parts[1], +parts[2], +parts[3], +parts[4], parts.slice(5).join(" ")]);
    } else {
      const parts = line.split(" ").map(Number);
      ops.push([kind, ...parts.slice(1)]);
    }
  }
  return ops;
}
