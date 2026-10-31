# Idle Hands — task recipes (wired at the v1.0 build, 2026-10-30).
# Odin dev-2026-10 lives in ~/workspace/tools/odin in the sandbox; the
# wasm build also needs a wasm-ld on PATH (~/workspace/tools/bin carries
# a zig wasm-ld shim). Override ODIN/ODIN_PATH as the machine requires.

ODIN := env_var_or_default("ODIN", join(home_dir(), "workspace/tools/odin/odin-linux-amd64-nightly+2026-10-06/odin"))
ODIN_PATH := join(home_dir(), "workspace/tools/bin") + ":" + env_var("PATH")

# Assemble the single-file jam entry: Odin core -> wasm, inlined
build:
    PATH="{{ODIN_PATH}}" {{ODIN}} build src -target:freestanding_wasm32 -build-mode:shared -out:zig-out/idle-hands.wasm
    node tools/assemble.mjs

# Run every gate: core tests, settings/memory bridge, perf, playtest
check:
    {{ODIN}} test src/tests
    PATH="{{ODIN_PATH}}" {{ODIN}} build src -target:freestanding_wasm32 -build-mode:shared -out:zig-out/idle-hands.wasm
    node tools/assemble.mjs
    node tools/settings-check.mjs
    node tools/perf.mjs
    node tools/playtest.mjs

# Render the per-level preview videos from the shipped core (demo mode)
previews:
    node tools/capture.mjs 0 20262
    node tools/capture.mjs 1 20262
    node tools/capture.mjs 2 20262

# Build the planning book
book:
    mdbook build book
