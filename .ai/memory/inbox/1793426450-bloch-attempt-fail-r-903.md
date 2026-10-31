---
origin_lane: restricted
content_label: nsfw
evidence: default: restricted-origin without positive SFW evidence
---
# Attempt failed — R-903 Single-file index.html assembles and runs offline with all screens

last_verified: 2026-10-31
applies_to: 0.1.0
disposition: 
scope: repo_task
subject: R-903

error: bash -c "node tools/assemble.mjs && grep -q IDLE web/index.html": exit code 1
note: 
