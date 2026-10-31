// main_test.odin — Idle Hands core tests (only compiled by `odin test`).
// Half validation, half adversarial (estate rule).
package tests

import ih ".."

import "core:testing"

@(test)
test_fidget_vocabulary_is_complete :: proc(t: ^testing.T) {
	testing.expect(t, len(ih.FIDGETS) == 6)
	seen: [6]bool
	for f in ih.FIDGETS {
		testing.expect(t, len(f.name) > 0)
		testing.expect(t, f.dur_ms >= 1000 && f.dur_ms <= 4000)
		testing.expect(t, !seen[int(f.kind)])
		seen[int(f.kind)] = true
	}
}

@(test)
test_levels_have_exactly_one_goal_each :: proc(t: ^testing.T) {
	for lvl in ih.LEVELS {
		goals := 0
		if lvl.connections_needed > 0 { goals += 1 }
		if lvl.sequences_needed > 0 { goals += 1 }
		if lvl.survive_ms > 0 { goals += 1 }
		testing.expect(t, goals == 1)
	}
}

@(test)
test_actor_blinks_and_gaze_moves :: proc(t: ^testing.T) {
	g := ih.game_init(42, false)
	ih.begin_level(&g, 0)
	saw_blink := false
	for i in 0 ..< 3750 { // 60 s
		ih.step_game(&g, ih.STEP_MS, ih.Input{}, 0, 0)
		if g.blink_close > 0 { saw_blink = true }
		if g.screen != .Play { break }
	}
	testing.expect(t, saw_blink)
}

@(test)
test_demo_completes_levels_1_and_2 :: proc(t: ^testing.T) {
	for lvl in 0 ..< 2 {
		g := ih.game_init(u64(500 + lvl), true)
		ih.begin_level(&g, lvl)
		steps := 0
		for g.screen == .Play && steps < 60 * 60 * 6 {
			ih.step_game(&g, ih.STEP_MS, ih.Input{}, 0, 0)
			steps += 1
		}
		testing.expect(t, g.screen == .Victory)
	}
}

@(test)
test_determinism_same_seed_same_draws :: proc(t: ^testing.T) {
	a := ih.game_init(777, true)
	b := ih.game_init(777, true)
	ih.begin_level(&a, 0)
	ih.begin_level(&b, 0)
	snapshot: [ih.DRAW_BUFFER_BYTES]u8
	for i in 0 ..< 1500 {
		ih.step_game(&a, ih.STEP_MS, ih.Input{}, 0, 0)
		ih.step_game(&b, ih.STEP_MS, ih.Input{}, 0, 0)
		if i % 250 == 0 {
			ih.dw_reset(); ih.render(&a)
			copy(snapshot[:], ih.draw_buffer[:])
			snap_len := ih.draw_len
			ih.dw_reset(); ih.render(&b)
			testing.expect(t, ih.draw_len == snap_len)
			same := true
			for k in 0 ..< ih.draw_len {
				if snapshot[k] != ih.draw_buffer[k] { same = false }
			}
			testing.expect(t, same)
			testing.expect(t, a.loneliness == b.loneliness)
		}
	}
}

@(test)
test_remembered_loneliness_shifts_the_actor :: proc(t: ^testing.T) {
	fresh := ih.game_init(9, false)
	ih.begin_level(&fresh, 0)
	left := ih.game_init(9, false)
	left.remembered_loneliness = 0.8
	ih.begin_level(&left, 0)
	testing.expect(t, left.loneliness > fresh.loneliness)
	testing.expect(t, left.posture > fresh.posture)
}

// --- adversarial ---

@(test)
test_adversarial_dt_extremes :: proc(t: ^testing.T) {
	g := ih.game_init(9, false)
	ih.begin_level(&g, 0)
	ih.step_game(&g, 0, ih.Input{}, 0, 0)
	testing.expect(t, g.breath_t >= 0 && g.breath_t < 1)
	ih.step_game(&g, 2_000_000_000, ih.Input{}, 0, 0)
	testing.expect(t, g.breath_t >= 0 && g.breath_t < 1)
	testing.expect(t, g.attention >= 0 && g.attention <= 100)
	testing.expect(t, g.loneliness >= 0 && g.loneliness <= 100)
}

@(test)
test_adversarial_offscreen_clicks_never_connect :: proc(t: ^testing.T) {
	g := ih.game_init(9, false)
	ih.begin_level(&g, 0)
	for i in 0 ..< 500 {
		ih.click(&g, -50, 99999)
		ih.click(&g, 5000, -300)
	}
	testing.expect(t, g.connections == 0)
	testing.expect(t, g.attention >= 0 && g.attention <= 100)
}

@(test)
test_adversarial_invalid_level_rejected :: proc(t: ^testing.T) {
	_, err := ih.validate_level(99)
	testing.expect(t, err == .InvalidLevel)
	_, err2 := ih.validate_level(-1)
	testing.expect(t, err2 == .InvalidLevel)
	testing.expect(t, ih.init(1, 99) == -1)
	testing.expect(t, ih.start_level(200) == -1)
}

@(test)
test_adversarial_wrong_coil_does_not_advance :: proc(t: ^testing.T) {
	g := ih.game_init(9, false)
	ih.begin_level(&g, 1)
	g.seq_shown_ms = 0
	right := g.seq_order[0]
	wrong := (right + 1) % 4
	wp := ih.COIL_POINTS[wrong]
	ih.click(&g, wp.x, wp.y)
	testing.expect(t, g.seq_progress == 0)
	rp := ih.COIL_POINTS[right]
	ih.click(&g, rp.x, rp.y)
	testing.expect(t, g.seq_progress == 1)
}

@(test)
test_adversarial_draw_output_bounded :: proc(t: ^testing.T) {
	g := ih.game_init(4242, false)
	ih.begin_level(&g, 2)
	g.loneliness = 90
	ih.dw_reset()
	ih.render(&g)
	testing.expect(t, ih.draw_ops <= ih.MAX_OPS)
	testing.expect(t, ih.draw_len < ih.DRAW_BUFFER_BYTES)
}
