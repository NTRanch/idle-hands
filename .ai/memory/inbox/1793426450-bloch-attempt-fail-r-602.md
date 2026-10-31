---
origin_lane: restricted
content_label: nsfw
evidence: default: restricted-origin without positive SFW evidence
---
# Attempt failed — R-602 Clean-environment install and run is verified

last_verified: 2026-10-31
applies_to: 0.1.0
disposition: 
scope: repo_task
subject: R-602

error: bash -c "rm -rf zig-out && PATH=~/workspace/tools/bin:$PATH ~/workspace/tools/odin/odin-linux-amd64-nightly+2026-10-06/odin build src -target:freestanding_wasm32 -build-mode:shared -out:zig-out/idle-hands.wasm && node tools/assemble.mjs && node tools/playtest.mjs": exit code 1
note: 
