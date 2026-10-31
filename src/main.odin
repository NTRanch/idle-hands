// idle-hands/src/main.odin — Idle Hands core (Odin, freestanding wasm32).
//
// Tiger Style (tiger-style-odin): explicit contracts, bounded work,
// disciplined manual memory — this core allocates NOTHING after init:
// fixed buffers, fixed tables, one seeded RNG stream. Data-oriented
// actor simulation at a fixed step; the shell calls step() at 60 Hz and
// the core never reads a wall clock.
//
// Game: a companion-idle toy. Yui waits in her rope room. The game IS
// her idle acting — breath, blinks, look targets, secondary motion in
// hair/sleeves/rope, and a fidget vocabulary that plays her step-1
// Descent trace as behaviour. The player attends: click what she looks
// at to connect; neglect her and loneliness changes how she idles —
// including on the NEXT visit, through the shell's persistence bridge.
package idle_hands

// ---------------------------------------------------------------------------
// Domain constants
// ---------------------------------------------------------------------------

CANVAS_PX :: 960
MAX_OPS :: 1024
DRAW_BUFFER_BYTES :: 65536
STEP_MS :: 16

// Palette indices (shared with the shell + rasteriser; 0 = background).
PAL_BG :: 0 // #0d0208
PAL_PINK :: 1 // #ff2e88
PAL_SKIN :: 2 // #f8f0ed
PAL_MAUVE :: 3 // #ac9393
PAL_PLUM :: 4 // #540e46
PAL_ROSE :: 5 // #ec8584
PAL_PAPER :: 6 // #eaeaea
PAL_DIM :: 7 // #68636c
PAL_GOLD :: 8 // #ffd166
PAL_DEEP :: 9 // #1a0510
PAL_ROPE :: 10 // #d9a066 rope tan

// ---------------------------------------------------------------------------
// Public types
// ---------------------------------------------------------------------------

Screen :: enum u8 {
	Gate,
	Title,
	HowTo,
	Play,
	Pause,
	Settings,
	Victory,
	GameOver,
}

Input :: struct {
	tap:     bool, // pointer press this step (with px/py)
	confirm: bool,
	back:    bool,
	pause:   bool,
	up:      bool,
	down:    bool,
}

Event :: enum u8 {
	None,
	Connection,
	Startle,
	Miss,
	SequenceDone,
	Victory,
	GameOver,
	UiMove,
	FidgetStart,
}

LookTarget :: enum u8 {
	Viewer,
	Window,
	Rope,
	Hands,
	Away,
}

// Where each look target lives on the canvas (click + gaze geometry).
LOOK_POINTS := [LookTarget][2]int{
	.Viewer = {480, 470},
	.Window = {145, 580},
	.Rope   = {770, 690},
	.Hands  = {480, 640},
	.Away   = {830, 200},
}

FidgetKind :: enum u8 {
	CoilRope,
	TugSleeve,
	GlanceAway,
	HumNotes,
	ShiftSeat,
	TouchHair,
}

Fidget :: struct {
	name:   string,
	kind:   FidgetKind,
	dur_ms: int,
}

// THE FIDGET VOCABULARY (port-back artifact): her step-1 Descent trace
// played as behaviour. Order is the canonical rotation seed order.
FIDGETS := [6]Fidget{
	{"COILS THE ROPE, NOT THINKING", .CoilRope, 3400},
	{"TUGS HER SLEEVE STRAIGHT", .TugSleeve, 1800},
	{"GLANCES AT THE DOOR", .GlanceAway, 2200},
	{"HUMS, THREE NOTES", .HumNotes, 2600},
	{"SHIFTS IN HER SEAT", .ShiftSeat, 1600},
	{"TOUCHES HER HAIR, ABSENT", .TouchHair, 2000},
}

Level :: struct {
	name:               string,
	attention_decay:    f32, // per second
	loneliness_rate:    f32, // per second while unattended
	connections_needed: int, // L1 goal (0 = not the goal)
	sequences_needed:   int, // L2 goal (0 = not the goal)
	survive_ms:         int, // L3 goal (0 = not the goal)
	look_min_ms:        int,
	look_max_ms:        int,
}

LEVELS := [3]Level{
	{"LEVEL 1 - FIRST VISIT", 1.05, 0.85, 8, 0, 0, 3400, 5600},
	{"LEVEL 2 - ROPE PRACTICE", 0.80, 0.60, 0, 3, 0, 4200, 6400},
	{"LEVEL 3 - THE LONG QUIET", 1.60, 1.35, 0, 0, 150_000, 5200, 8200},
}

COIL_POINTS := [4][2]int{{690, 640}, {790, 600}, {720, 740}, {830, 700}}

// ---------------------------------------------------------------------------
// Validation
// ---------------------------------------------------------------------------

CoreError :: enum {
	None,
	InvalidLevel,
}

validate_level :: proc(level: int) -> (idx: int, err: CoreError) {
	if level < 0 || level >= len(LEVELS) {
		return 0, .InvalidLevel
	}
	return level, .None
}

// ---------------------------------------------------------------------------
// Private leaf work: RNG, easing, springs
// ---------------------------------------------------------------------------

Rng :: struct {
	state: u64,
}

rng_init :: proc(seed: u64) -> Rng {
	return Rng{state = seed | 1}
}

rng_next :: proc(r: ^Rng) -> u64 {
	r.state += 0x9E3779B97F4A7C15
	z := r.state
	z = (z ~ (z >> 30)) * 0xBF58476D1CE4E5B9
	z = (z ~ (z >> 27)) * 0x94D049BB133111EB
	return z ~ (z >> 31)
}

rng_unit :: proc(r: ^Rng) -> f32 {
	return f32(rng_next(r) >> 40) / 16777216.0
}

rng_range :: proc(r: ^Rng, lo, hi: int) -> int {
	assert(hi > lo)
	return lo + int(rng_next(r) % u64(hi - lo))
}

clamp01 :: proc(x: f32) -> f32 {
	return clamp(x, 0.0, 1.0)
}

clamp100 :: proc(x: f32) -> f32 {
	return clamp(x, 0.0, 100.0)
}

lerp :: proc(a, b, t: f32) -> f32 {
	return a + (b - a) * t
}

// A lag chase for secondary motion: the value approaches its target
// exponentially; the lag IS the acting. Unconditionally stable, and the
// value is clamped to a sane band so no input can blow it up.
Spring :: struct {
	value: f32,
}

spring_step :: proc(s: ^Spring, target: f32, dt_s: f32, stiffness: f32) {
	k := clamp(dt_s * stiffness, 0.0, 1.0)
	s.value += (target - s.value) * k
	s.value = clamp(s.value, -40.0, 40.0)
}

// ---------------------------------------------------------------------------
// Game state and the step
// ---------------------------------------------------------------------------

Game :: struct {
	screen:     Screen,
	level_idx:  int,
	seed:       u64,
	demo:       bool,
	frame:      u64,
	screen_ms:  int,
	elapsed_ms: int, // play clock

	// Actor performance state
	breath_t:    f32, // 0..1 loop
	blink_t_ms:  int, // time until next blink
	blink_close: int, // >0 while eyelids are closing/closed (ms left)
	gaze_x:      Spring,
	gaze_y:      Spring,
	look:        LookTarget,
	look_ms:     int, // time until the next look change
	look_age_ms: int, // how long the current look has been held
	hair_sway:   Spring,
	sleeve_l:    Spring,
	sleeve_r:    Spring,
	posture:     f32, // 0 upright .. 1 sunk (loneliness made visible)

	// Fidget playback
	fidget_idx:  int, // -1 = none
	fidget_ms:   int,
	fidget_seen: bool, // clicked during this fidget ("noticed")
	idle_ms:     int, // time since the last click

	// Meters and goals
	attention:      f32, // 0..100
	loneliness:     f32, // 0..100
	connections:    int,
	seq_order:      [4]int, // L2: the shown coil order
	seq_shown_ms:   int, // >0 while the order is being shown
	seq_progress:   int,
	sequences_done: int,
	event:          Event,
	caption:        string, // transient reaction caption
	caption_ms:     int,

	// Persistence bridge (shell-owned storage, core-visible state)
	visits:               int,
	remembered_loneliness: f32, // 0..1, from previous sessions
	peak_loneliness:      f32, // this session, for the shell to store

	// Settings (session + bridge)
	calm_room:  bool,
	text_large: bool,
	cursor:     int,

	// Ambient field: fixed at init, motion is a pure function of time
	motes: [28][2]int,
	rng:   Rng,
}

game_init :: proc(seed: u64, demo: bool) -> Game {
	g := Game{seed = seed, demo = demo, screen = .Gate, fidget_idx = -1, look = .Viewer}
	g.rng = rng_init(seed ~ 0x1D1E)
	for i in 0 ..< len(g.motes) {
		g.motes[i] = {rng_range(&g.rng, 0, 960), rng_range(&g.rng, 0, 960)}
	}
	g.blink_t_ms = rng_range(&g.rng, 1800, 3600)
	g.look_ms = 2600
	return g
}

level_of :: proc(g: ^Game) -> Level {
	return LEVELS[g.level_idx]
}

begin_level :: proc(g: ^Game, idx: int) {
	g.level_idx = idx
	g.attention = 62
	// Remembered loneliness greets you at the door: she starts the visit
	// already a little sunk if she was left alone last time.
	g.loneliness = g.remembered_loneliness * 34.0
	g.posture = g.remembered_loneliness * 0.4
	g.connections = 0
	g.sequences_done = 0
	g.seq_progress = 0
	g.elapsed_ms = 0
	g.idle_ms = 0
	g.fidget_idx = -1
	g.peak_loneliness = g.loneliness
	g.caption = ""
	g.caption_ms = 0
	g.screen = .Play
	g.screen_ms = 0
	if LEVELS[idx].sequences_needed > 0 {
		new_sequence(g)
	}
}

goto_screen :: proc(g: ^Game, s: Screen) {
	g.screen = s
	g.screen_ms = 0
	g.cursor = 0
}

new_sequence :: proc(g: ^Game) {
	// A fresh permutation of the four coils (Fisher-Yates on the stream).
	g.seq_order = {0, 1, 2, 3}
	for i := 3; i > 0; i -= 1 {
		j := rng_range(&g.rng, 0, i + 1)
		g.seq_order[i], g.seq_order[j] = g.seq_order[j], g.seq_order[i]
	}
	g.seq_progress = 0
	g.seq_shown_ms = 2400
}

set_caption :: proc(g: ^Game, text: string) {
	g.caption = text
	g.caption_ms = 2100
}

look_point :: proc(g: ^Game) -> [2]int {
	return LOOK_POINTS[g.look]
}

pick_look :: proc(g: ^Game) {
	lvl := level_of(g)
	roll := rng_unit(&g.rng)
	switch {
	case roll < 0.34:
		g.look = .Viewer
	case roll < 0.55:
		g.look = .Rope
	case roll < 0.72:
		g.look = .Window
	case roll < 0.88:
		g.look = .Hands
	case:
		g.look = .Away
	}
	g.look_ms = rng_range(&g.rng, lvl.look_min_ms, lvl.look_max_ms)
	g.look_age_ms = 0
}

start_fidget :: proc(g: ^Game) {
	g.fidget_idx = rng_range(&g.rng, 0, len(FIDGETS))
	g.fidget_ms = 0
	g.fidget_seen = false
	g.event = .FidgetStart
}

near_point :: proc(p: [2]int, px, py, r: int) -> bool {
	dx := px - p.x
	dy := py - p.y
	return dx * dx + dy * dy <= r * r
}

// Register a click at (px, py). Pure geometry + the level's rules.
click :: proc(g: ^Game, px, py: int) {
	if g.screen != .Play {
		return
	}
	g.idle_ms = 0
	lvl := level_of(g)
	near := near_point
	// L2 coil sequences take their clicks first.
	if lvl.sequences_needed > 0 && g.seq_shown_ms <= 0 {
		for c in 0 ..< 4 {
			if near(COIL_POINTS[c], px, py, 58) {
				if c == g.seq_order[g.seq_progress] {
					g.seq_progress += 1
					g.attention = clamp100(g.attention + 6)
					set_caption(g, "SHE NODS - THAT ONE")
					if g.seq_progress >= 4 {
						g.sequences_done += 1
						g.event = .SequenceDone
						set_caption(g, "THE WHOLE PATTERN, TOGETHER")
						if g.sequences_done >= lvl.sequences_needed {
							win(g)
						} else {
							new_sequence(g)
						}
					}
				} else {
					g.loneliness = clamp100(g.loneliness + 4)
					g.event = .Miss
					set_caption(g, "NO - SHE SHAKES HER HEAD, GENTLE")
					g.seq_progress = 0
				}
				return
			}
		}
	}
	// Clicking the thing she is looking at = a connection. A connection
	// CONSUMES the look — she looks elsewhere next, so one look can
	// never be farmed for repeated connections.
	lp := look_point(g)
	if near(lp, px, py, 130) && g.look_age_ms >= 900 {
		g.connections += 1
		g.attention = clamp100(g.attention + 18)
		g.loneliness = clamp100(g.loneliness - 6)
		g.event = .Connection
		set_caption(g, "SHE LOOKS UP - YOU SAW IT TOO")
		// During a fidget, this click is also a "noticed".
		if g.fidget_idx >= 0 && !g.fidget_seen {
			g.fidget_seen = true
			g.loneliness = clamp100(g.loneliness - 5)
			set_caption(g, "YOU NOTICED. SHE KNOWS YOU NOTICED")
		}
		if lvl.connections_needed > 0 && g.connections >= lvl.connections_needed {
			win(g)
			return
		}
		pick_look(g)
		return
	}
	// Clicking her directly: a startle, a blink, a small warmth.
	if near({480, 470}, px, py, 170) {
		g.blink_close = 140
		g.look = .Viewer
		g.look_ms = 2400
		g.attention = clamp100(g.attention + 4)
		g.event = .Startle
		set_caption(g, "A STARTLE - THEN SHE SETTLES")
		return
	}
	// Clicking anywhere else: she glances at the click.
	g.event = .UiMove
	set_caption(g, "HER EYES FOLLOW THE SOUND")
}

win :: proc(g: ^Game) {
	g.event = .Victory
	goto_screen(g, .Victory)
}

lose :: proc(g: ^Game) {
	g.event = .GameOver
	goto_screen(g, .GameOver)
}

// Demo policy: clicks the look target when it changes, plays coil
// sequences in order, auto-confirms menus.
demo_click :: proc(g: ^Game) -> (fire: bool, px, py: int) {
	switch g.screen {
	case .Gate:
		return g.screen_ms > 600, 0, 0
	case .Title:
		return g.screen_ms > 700, 0, 0
	case .Victory, .GameOver:
		return g.screen_ms > 1500, 0, 0
	case .HowTo, .Pause, .Settings:
		return false, 0, 0
	case .Play:
		lvl := level_of(g)
		if lvl.sequences_needed > 0 {
			if g.seq_shown_ms > 0 {
				return false, 0, 0
			}
			// One coil every ~500 ms, in the shown order.
			if g.frame % 30 == 0 {
				p := COIL_POINTS[g.seq_order[g.seq_progress]]
				return true, p.x, p.y
			}
			return false, 0, 0
		}
		// Connect once the look has settled (mirrors the 900 ms rule).
		if g.look_age_ms >= 1000 {
			p := look_point(g)
			return true, p.x, p.y
		}
		return false, 0, 0
	}
	return false, 0, 0
}

step_game :: proc(g: ^Game, dt_raw: int, input: Input, px, py: int) {
	g.event = .None
	dt := clamp(dt_raw, 0, 250)
	inp := input
	cx, cy := px, py
	if g.demo {
		fire, dx, dy := demo_click(g)
		if fire {
			if g.screen == .Play {
				inp.tap = true
				cx, cy = dx, dy
			} else {
				inp.confirm = true
			}
		}
	}
	g.frame += 1
	g.screen_ms += dt

	switch g.screen {
	case .Gate:
		if inp.confirm { goto_screen(g, .Title) }
	case .Title:
		step_title(g, inp)
	case .HowTo:
		if inp.confirm || inp.back { goto_screen(g, .Title) }
	case .Settings:
		step_settings(g, inp)
	case .Pause:
		step_pause(g, inp)
	case .Play:
		if inp.pause {
			goto_screen(g, .Pause)
			return
		}
		if inp.tap { click(g, cx, cy) }
		step_play(g, dt)
	case .Victory, .GameOver:
		if inp.confirm { goto_screen(g, .Title) }
	}
}

step_title :: proc(g: ^Game, inp: Input) {
	if inp.down {
		g.cursor = min(g.cursor + 1, 3)
		g.event = .UiMove
	}
	if inp.up {
		g.cursor = max(g.cursor - 1, 0)
		g.event = .UiMove
	}
	if g.cursor == 3 {
		if inp.tap || inp.confirm {
			g.level_idx = (g.level_idx + 1) % len(LEVELS)
			g.event = .UiMove
		}
		return
	}
	if inp.confirm {
		switch g.cursor {
		case 0: begin_level(g, g.level_idx)
		case 1: goto_screen(g, .HowTo)
		case 2: goto_screen(g, .Settings)
		}
	}
}

step_settings :: proc(g: ^Game, inp: Input) {
	if inp.down { g.cursor = min(g.cursor + 1, 1); g.event = .UiMove }
	if inp.up { g.cursor = max(g.cursor - 1, 0); g.event = .UiMove }
	if inp.confirm {
		if g.cursor == 0 { g.calm_room = !g.calm_room } else { g.text_large = !g.text_large }
		g.event = .UiMove
	}
	if inp.back { goto_screen(g, .Title) }
}

step_pause :: proc(g: ^Game, inp: Input) {
	if inp.down { g.cursor = min(g.cursor + 1, 2); g.event = .UiMove }
	if inp.up { g.cursor = max(g.cursor - 1, 0); g.event = .UiMove }
	if inp.confirm {
		switch g.cursor {
		case 0: goto_screen(g, .Play)
		case 1: begin_level(g, g.level_idx)
		case 2: goto_screen(g, .Title)
		}
	}
}

step_play :: proc(g: ^Game, dt: int) {
	lvl := level_of(g)
	dt_s := f32(dt) / 1000.0
	g.elapsed_ms += dt
	g.idle_ms += dt

	// Breath: a 3.8 s loop, always running — she is alive between inputs.
	g.breath_t += dt_s / 3.8
	if g.breath_t >= 1.0 { g.breath_t -= 1.0 }

	// Blinks.
	if g.blink_close > 0 {
		g.blink_close -= dt
	} else {
		g.blink_t_ms -= dt
		if g.blink_t_ms <= 0 {
			g.blink_close = 130
			// A lonely actor blinks slower; company quickens her.
			base := f32(rng_range(&g.rng, 2400, 5200))
			g.blink_t_ms = int(base * (1.0 + g.loneliness / 100.0))
		}
	}

	// Look targets.
	g.look_ms -= dt
	g.look_age_ms += dt
	if g.look_ms <= 0 { pick_look(g) }

	// Gaze chases the look target (full-disc centre offsets).
	lp := look_point(g)
	spring_step(&g.gaze_x, clamp(f32(lp.x - 480) / 300.0, -1, 1), dt_s, 6.0)
	spring_step(&g.gaze_y, clamp(f32(lp.y - 430) / 300.0, -1, 1), dt_s, 6.0)

	// Secondary motion: hair and sleeves chase the breath + gaze with lag.
	breath := breath_amount(g)
	spring_step(&g.hair_sway, g.gaze_x.value * 10.0 + breath * 4.0, dt_s, 3.2)
	spring_step(&g.sleeve_l, -breath * 7.0 - g.gaze_x.value * 3.0, dt_s, 2.6)
	spring_step(&g.sleeve_r, -breath * 7.0 + g.gaze_x.value * 3.0, dt_s, 2.6)

	// Fidgets: her trace plays when the room has been quiet a while.
	if g.fidget_idx >= 0 {
		g.fidget_ms += dt
		if g.fidget_ms >= FIDGETS[g.fidget_idx].dur_ms {
			g.fidget_idx = -1
			g.idle_ms = 3000 // a shorter quiet before the next one
		}
	} else if g.idle_ms > 6000 {
		start_fidget(g)
	}

	// Meters.
	g.attention = clamp100(g.attention - lvl.attention_decay * dt_s)
	if g.attention < 30 {
		g.loneliness = clamp100(g.loneliness + lvl.loneliness_rate * dt_s)
	} else {
		g.loneliness = clamp100(g.loneliness - 0.5 * dt_s)
	}
	g.peak_loneliness = max(g.peak_loneliness, g.loneliness)

	// Posture sinks as loneliness rises (slow spring — posture is acting).
	target_posture := g.loneliness / 100.0 * 0.85 + g.remembered_loneliness * 0.15
	g.posture = lerp(g.posture, target_posture, dt_s * 0.7)

	if g.caption_ms > 0 { g.caption_ms -= dt }
	if g.seq_shown_ms > 0 { g.seq_shown_ms -= dt }

	if g.loneliness >= 100 {
		lose(g)
		return
	}
	if lvl.survive_ms > 0 && g.elapsed_ms >= lvl.survive_ms {
		win(g)
		return
	}
}

breath_amount :: proc(g: ^Game) -> f32 {
	// Smooth in-out over the loop.
	t := g.breath_t
	if t < 0.45 {
		x := t / 0.45
		return x * x * (3 - 2 * x)
	}
	if t < 0.58 { return 1.0 }
	x := (t - 0.58) / 0.42
	return 1.0 - x * x * (3 - 2 * x)
}

// ---------------------------------------------------------------------------
// Draw-list emission (bounded writer over a static buffer, hand-formatted)
// ---------------------------------------------------------------------------

draw_buffer: [DRAW_BUFFER_BYTES]u8
draw_len: int
draw_ops: int
draw_dropped: int

dw_reset :: proc() {
	draw_len = 0
	draw_ops = 0
	draw_dropped = 0
}

dw_bytes :: proc(s: string) {
	if draw_len + len(s) >= DRAW_BUFFER_BYTES {
		draw_dropped += 1
		return
	}
	copy(draw_buffer[draw_len:], s)
	draw_len += len(s)
}

dw_int :: proc(v: int) {
	if v == 0 {
		dw_bytes("0")
		return
	}
	neg := v < 0
	u := v
	if neg { u = -v }
	tmp: [24]u8
	n := 0
	for u > 0 {
		tmp[n] = u8('0' + u % 10)
		n += 1
		u /= 10
	}
	if neg { dw_bytes("-") }
	for i := n - 1; i >= 0; i -= 1 {
		draw_buffer[draw_len] = tmp[i]
		draw_len += 1
	}
}

dw_op :: proc(kind: string, nums: []int) {
	if draw_ops >= MAX_OPS {
		draw_dropped += 1
		return
	}
	dw_bytes(kind)
	for n in nums {
		dw_bytes(" ")
		dw_int(n)
	}
	dw_bytes("\n")
	draw_ops += 1
}

dw_rect :: proc(x, y, w, h, c: int) { dw_op("r", []int{x, y, w, h, c}) }
dw_circle :: proc(x, y, r, c: int) { dw_op("c", []int{x, y, r, c}) }
dw_line :: proc(x1, y1, x2, y2, w, c: int) { dw_op("l", []int{x1, y1, x2, y2, w, c}) }
dw_tri :: proc(x1, y1, x2, y2, x3, y3, c: int) { dw_op("p", []int{x1, y1, x2, y2, x3, y3, c}) }

dw_text :: proc(x, y, size, c: int, s: string) {
	// Sanitise to the shared printable subset (uppercase-normalised).
	if draw_ops >= MAX_OPS {
		draw_dropped += 1
		return
	}
	if draw_len + len(s) + 24 >= DRAW_BUFFER_BYTES {
		draw_dropped += 1
		return
	}
	dw_bytes("t ")
	dw_int(x); dw_bytes(" ")
	dw_int(y); dw_bytes(" ")
	dw_int(size); dw_bytes(" ")
	dw_int(c); dw_bytes(" ")
	for i in 0 ..< len(s) {
		ch := s[i]
		out: u8 = '?'
		switch {
		case ch >= 'a' && ch <= 'z': out = ch - 32
		case (ch >= 'A' && ch <= 'Z') || (ch >= '0' && ch <= '9'): out = ch
		case ch == ' ' || ch == '-' || ch == '.' || ch == ':' || ch == '+' ||
			ch == '!' || ch == '?' || ch == '/' || ch == '(' || ch == ')' ||
			ch == '%' || ch == '&' || ch == ',' || ch == '\'':
			out = ch
		}
		draw_buffer[draw_len] = out
		draw_len += 1
	}
	dw_bytes("\n")
	draw_ops += 1
}

fi :: proc(x: f32) -> int {
	return int(x + (0.5 if x >= 0 else -0.5))
}

// Scratch integer strings for HUD numbers: 4 rotating buffers, each
// valid until the next 4 calls — far beyond one frame's HUD needs.
num_scratch: [4][24]u8
num_slot: int

num_str :: proc(v: int) -> string {
	slot := num_slot
	num_slot = (num_slot + 1) % 4
	buf := &num_scratch[slot]
	neg := v < 0
	u := v
	if neg { u = -v }
	tmp: [24]u8
	n := 0
	if u == 0 {
		tmp[n] = '0'
		n += 1
	}
	for u > 0 {
		tmp[n] = u8('0' + u % 10)
		n += 1
		u /= 10
	}
	w := 0
	if neg {
		buf[w] = '-'
		w += 1
	}
	for i := n - 1; i >= 0; i -= 1 {
		buf[w] = tmp[i]
		w += 1
	}
	return string(buf[:w])
}

text_size :: proc(g: ^Game, base: int) -> int {
	return base * 14 / 10 if g.text_large else base
}

// ---------------------------------------------------------------------------
// Rendering
// ---------------------------------------------------------------------------

render :: proc(g: ^Game) {
	dw_rect(0, 0, CANVAS_PX, CANVAS_PX, PAL_BG)
	switch g.screen {
	case .Gate: render_gate(g)
	case .Title: render_title(g)
	case .HowTo: render_howto(g)
	case .Settings: render_settings(g)
	case .Play, .Pause:
		render_scene(g)
		if g.screen == .Pause { render_pause(g) }
	case .Victory: render_end(g, true)
	case .GameOver: render_end(g, false)
	}
}

render_gate :: proc(g: ^Game) {
	dw_text(320, 300, text_size(g, 64), PAL_PINK, "IDLE HANDS")
	dw_text(300, 420, text_size(g, 30), PAL_PAPER, "A COMPANION, WAITING")
	dw_text(240, 540, text_size(g, 28), PAL_ROSE, "THIS GAME IS FOR ADULTS ONLY (18+)")
	dw_text(280, 600, text_size(g, 24), PAL_DIM, "CONTAINS BONDAGE-ADJACENT ROOM DRESSING")
	if (g.frame / 30) % 2 == 0 {
		dw_text(330, 720, text_size(g, 28), PAL_PAPER, "PRESS CONFIRM TO ENTER")
	}
}

render_title :: proc(g: ^Game) {
	render_room(g, true)
	dw_text(300, 120, text_size(g, 72), PAL_PINK, "IDLE HANDS")
	dw_text(310, 210, text_size(g, 24), PAL_DIM, "YUI - ATTENTION IS THE GAME")
	labels := [3]string{"START", "HOW TO PLAY", "SETTINGS"}
	for label, i in labels {
		y := 380 + i * 80
		c := PAL_PAPER
		if i == g.cursor { c = PAL_PINK; dw_text(240, y, text_size(g, 34), PAL_PINK, ">") }
		dw_text(290, y, text_size(g, 34), c, label)
	}
	lvl := LEVELS[g.level_idx]
	if g.cursor == 3 { dw_text(240, 640, text_size(g, 26), PAL_PINK, ">") }
	lc := PAL_GOLD
	if g.cursor == 3 { lc = PAL_PINK }
	dw_text(290, 640, text_size(g, 26), lc, lvl.name)
	dw_text(290, 690, text_size(g, 20), PAL_DIM, "UP/DOWN CHOOSES - CONFIRM STARTS")
	if g.visits > 0 {
		dw_text(290, 760, text_size(g, 22), PAL_ROSE, "SHE REMEMBERS YOUR LAST VISIT")
	}
}

render_howto :: proc(g: ^Game) {
	dw_text(240, 130, text_size(g, 44), PAL_PINK, "HOW TO PLAY")
	lines := [10]string{
		"SHE WAITS. SHE BREATHES. SHE LOOKS",
		"AT THINGS - THE WINDOW, THE ROPE,",
		"HER HANDS, YOU.",
		"",
		"CLICK THE THING SHE IS LOOKING AT",
		"TO CONNECT. CONNECTIONS WARM HER.",
		"LEAVE HER UNSEEN AND LONELINESS",
		"CHANGES HOW SHE SITS, HOW SHE BLINKS.",
		"",
		"SHE REMEMBERS BEING LEFT ALONE.",
	}
	for ln, i in lines {
		dw_text(180, 230 + i * 52, text_size(g, 20), PAL_PAPER, ln)
	}
	if (g.frame / 30) % 2 == 0 {
		dw_text(300, 830, text_size(g, 24), PAL_DIM, "CONFIRM TO RETURN")
	}
}

render_settings :: proc(g: ^Game) {
	dw_text(300, 160, text_size(g, 44), PAL_PINK, "SETTINGS")
	rows := [2][2]string{
		{"ROOM MOTION", "CALM" if g.calm_room else "FULL"},
		{"TEXT SIZE", "LARGE" if g.text_large else "NORMAL"},
	}
	for row, i in rows {
		y := 320 + i * 90
		c := PAL_PAPER
		if i == g.cursor { c = PAL_PINK; dw_text(150, y, text_size(g, 30), PAL_PINK, ">") }
		// Label + value drawn as two ops (no fmt in the core).
		dw_text(200, y, text_size(g, 30), c, row[0])
		dw_text(560, y, text_size(g, 30), c, row[1])
	}
	dw_text(260, 700, text_size(g, 22), PAL_DIM, "CONFIRM TOGGLES - BACK RETURNS")
}

render_pause :: proc(g: ^Game) {
	dw_rect(180, 240, 600, 440, PAL_DEEP)
	dw_text(360, 290, text_size(g, 40), PAL_PINK, "PAUSED")
	labels := [3]string{"RESUME", "RESTART", "QUIT TO TITLE"}
	for label, i in labels {
		y := 390 + i * 80
		c := PAL_PAPER
		if i == g.cursor { c = PAL_PINK; dw_text(280, y, text_size(g, 30), PAL_PINK, ">") }
		dw_text(330, y, text_size(g, 30), c, label)
	}
}

render_end :: proc(g: ^Game, won: bool) {
	render_room(g, false)
	if won {
		dw_text(240, 280, text_size(g, 40), PAL_PINK, "SHE STAYS A WHILE")
		dw_text(330, 380, text_size(g, 30), PAL_PAPER, "THE VISIT ENDS WARM")
	} else {
		dw_text(160, 280, text_size(g, 40), PAL_MAUVE, "THE ROOM GOES QUIET")
		dw_text(300, 380, text_size(g, 30), PAL_PAPER, "LONELINESS FILLED THE ROOM")
	}
	if (g.frame / 30) % 2 == 0 {
		dw_text(310, 800, text_size(g, 24), PAL_DIM, "CONFIRM FOR TITLE")
	}
}

// The room: window + moon, hanging rope, floor. Motes drift; calm_room
// halves ambient motion (settings).
render_room :: proc(g: ^Game, calm: bool) {
	t := f32(g.elapsed_ms + g.screen_ms) / 1000.0
	// Window (left-middle: clear of the HUD and the figure)
	dw_rect(60, 470, 170, 220, PAL_DEEP)
	dw_circle(120, 545, 30, PAL_PAPER)
	dw_circle(133, 536, 26, PAL_DEEP)
	dw_rect(60, 470, 170, 8, PAL_PLUM)
	// Hanging rope: sway follows her breath — the room breathes with her.
	breath := breath_amount(g)
	sway := breath * 10.0 + g.hair_sway.value * 0.6
	x0 := 850
	dw_line(x0, 60, x0 + fi(sway), 300, 7, PAL_ROPE)
	dw_line(x0 + fi(sway), 300, x0 + fi(sway * 1.4), 470, 7, PAL_ROPE)
	dw_circle(x0 + fi(sway * 1.4), 490, 16, PAL_ROPE)
	// Floor line
	dw_line(0, 800, 960, 800, 3, PAL_PLUM)
	// Coil pile
	for p, i in COIL_POINTS {
		dw_circle(p.x, p.y, 40, PAL_PLUM)
		dw_circle(p.x, p.y, 30, PAL_ROPE)
		dw_circle(p.x, p.y, 18, PAL_PLUM)
		_ = i
	}
	// Motes
	n := len(g.motes)
	if g.calm_room || calm { n = n / 2 }
	for i in 0 ..< n {
		base := g.motes[i]
		x := (f32(base.x) + t * 11.0)
		y := (f32(base.y) - t * 7.0)
		dw_circle(fi(mod_f(x, 960)), fi(mod_f(y, 960)), 3, PAL_ROSE)
	}
}

mod_f :: proc(x, m: f32) -> f32 {
	r := x - f32(int(x / m)) * m
	if r < 0 { r += m }
	return r
}

render_scene :: proc(g: ^Game) {
	render_room(g, false)
	render_actor(g)
	render_hud(g)
}

// The actor: posture (sink), breath (chest + shoulders), gaze (disc
// centres), blinks (lids), secondary motion (hair, sleeves), fidgets
// (hands in motion), drawn as an abstract seated figure.
render_actor :: proc(g: ^Game) {
	p := g.posture
	breath := breath_amount(g)
	sink := fi(p * 34.0)
	cx := 480
	head_y := 420 + sink + fi(breath * 5.0)
	// Skirt / seat mass
	dw_tri(330, 800, 630, 800, 480, 610 + sink, PAL_PLUM)
	// Torso
	dw_tri(400, 640 + sink, 560, 640 + sink, 480, 470 + sink, PAL_ROSE)
	// Sleeves (lag springs move the cuffs)
	sl := fi(g.sleeve_l.value)
	sr := fi(g.sleeve_r.value)
	dw_line(415, 540 + sink, 350, 660 + sink + sl, 16, PAL_ROSE)
	dw_line(545, 540 + sink, 610, 660 + sink + sr, 16, PAL_ROSE)
	// Hands: fidgets move them; the coil fidget orbits a coil.
	hx_l, hy_l := 350, 672 + sink + sl
	hx_r, hy_r := 610, 672 + sink + sr
	if g.fidget_idx >= 0 {
		f := FIDGETS[g.fidget_idx]
		prog := f32(g.fidget_ms) / f32(f.dur_ms)
		switch f.kind {
		case .CoilRope:
			a := prog * 6.2832 * 3.0
			hx_r = 735 + fi(cos_f(a) * 34.0)
			hy_r = 665 + fi(sin_f(a) * 22.0)
		case .TugSleeve:
			hy_l -= fi(sin_f(prog * 3.1416) * 26.0)
		case .TouchHair:
			hy_r = head_y - 130 + fi(prog * 20.0)
			hx_r = 560
		case .ShiftSeat, .GlanceAway, .HumNotes:
		}
	}
	dw_circle(hx_l, hy_l, 17, PAL_SKIN)
	dw_circle(hx_r, hy_r, 17, PAL_SKIN)
	// Head + hair (hair mass chases with sway lag)
	hair_x := cx + fi(g.hair_sway.value)
	dw_circle(hair_x - 105, head_y - 30, 96, PAL_PLUM)
	dw_circle(hair_x + 105, head_y - 30, 96, PAL_PLUM)
	dw_circle(hair_x, head_y - 70, 128, PAL_PLUM)
	dw_circle(cx, head_y, 138, PAL_SKIN)
	dw_tri(cx - 138, head_y - 50, cx + 138, head_y - 50, cx, head_y - 168, PAL_PLUM)
	// Blush deepens with attention warmth.
	if g.attention > 45 {
		dw_circle(cx - 78, head_y + 52, 24, PAL_ROSE)
		dw_circle(cx + 78, head_y + 52, 24, PAL_ROSE)
	}
	// Eyes: white, iris disc (centre = gaze), lids by blink.
	blink := g.blink_close > 0
	for dx in ([2]int{-58, 58}) {
		ex := cx + dx
		ey := head_y - 6
		dw_circle(ex, ey, 24, PAL_PAPER)
		gx := ex + fi(g.gaze_x.value * 10.0)
		gy := ey + fi(g.gaze_y.value * 10.0)
		dw_circle(gx, gy, 12, PAL_PLUM)
		dw_circle(gx, gy, 5, PAL_BG)
		if blink {
			dw_rect(ex - 26, ey - 12, 52, 14, PAL_SKIN)
		}
		dw_line(ex - 24, ey - 42, ex + 24, ey - 44, 4, PAL_PLUM)
	}
	// Mouth: small line; opens a little when a fidget hums.
	if g.fidget_idx >= 0 && FIDGETS[g.fidget_idx].kind == .HumNotes {
		dw_circle(cx, head_y + 78, 9, PAL_PLUM)
		// Note pips rise from her.
		prog := f32(g.fidget_ms) / f32(FIDGETS[g.fidget_idx].dur_ms)
		dw_circle(cx + 90, head_y - fi(prog * 90.0), 6, PAL_GOLD)
		dw_circle(cx + 130, head_y - fi(prog * 130.0), 5, PAL_GOLD)
	} else {
		dw_line(cx - 16, head_y + 78, cx + 16, head_y + 78, 4, PAL_PLUM)
	}
	// Look-target glow: a dotted ring around the thing she is looking
	// at (dots, not filled circles — a filled ring over the Viewer
	// target would erase her face).
	lp := look_point(g)
	if g.screen == .Play && g.seq_shown_ms <= 0 {
		rr := 52.0 + breath * 5.0
		for k in 0 ..< 12 {
			a := f32(k) / 12.0 * 6.2832
			dw_circle(lp.x + fi(cos_f(a) * rr), lp.y + fi(sin_f(a) * rr), 5, PAL_PINK)
		}
	}
	// L2 sequence show/playback markers.
	lvl := level_of(g)
	if lvl.sequences_needed > 0 {
		if g.seq_shown_ms > 0 {
			shown := 4 - g.seq_shown_ms / 600
			for k in 0 ..< shown {
				p := COIL_POINTS[g.seq_order[k]]
				dw_circle(p.x, p.y, 48, PAL_GOLD)
				dw_circle(p.x, p.y, 42, PAL_PLUM)
			}
			dw_text(330, 130, text_size(g, 26), PAL_GOLD, "WATCH THE ORDER")
		} else {
			for k in 0 ..< g.seq_progress {
				p := COIL_POINTS[g.seq_order[k]]
				dw_circle(p.x, p.y, 46, PAL_PINK)
				dw_circle(p.x, p.y, 40, PAL_PLUM)
			}
			dw_text(310, 130, text_size(g, 20), PAL_PAPER, "NOW TOGETHER - CLICK THE COILS IN ORDER")
		}
	}
}

sin_f :: proc(x: f32) -> f32 {
	// Bounded polynomial sine (period 2pi via caller scaling is NOT
	// assumed; callers pass small angles or full turns scaled to radians
	// already wrapped by construction: prog in 0..1 * turns).
	return sin_approx(x)
}

cos_f :: proc(x: f32) -> f32 {
	return sin_approx(x + 1.5707963)
}

// Bhaskara I sine approximation, |x| wrapped to [-pi, pi] by callers via
// fidget progress construction (angles stay within 3 turns = 6pi; wrap
// here to be safe).
sin_approx :: proc(x_in: f32) -> f32 {
	PI :: 3.14159265
	x := x_in
	for x > PI { x -= 2 * PI }
	for x < -PI { x += 2 * PI }
	return (16 * x * (PI - abs_f(x))) / (5 * PI * PI - 4 * abs_f(x) * (PI - abs_f(x)))
}

abs_f :: proc(x: f32) -> f32 {
	return x if x >= 0 else -x
}

render_hud :: proc(g: ^Game) {
	lvl := level_of(g)
	dw_text(36, 36, text_size(g, 22), PAL_DIM, lvl.name)
	// Attention + loneliness meters.
	dw_text(36, 72, text_size(g, 20), PAL_PAPER, "ATTENTION")
	dw_rect(36, 102, 260, 14, PAL_DEEP)
	dw_rect(36, 102, fi(260.0 * g.attention / 100.0), 14, PAL_PINK)
	dw_text(36, 128, text_size(g, 20), PAL_PAPER, "LONELINESS")
	dw_rect(36, 158, 260, 14, PAL_DEEP)
	dw_rect(36, 158, fi(260.0 * g.loneliness / 100.0), 14, PAL_MAUVE)
	// Goal line per level (numbers via the scratch formatter; spacing
	// measured against the raster font's advance so nothing collides).
	if lvl.connections_needed > 0 {
		dw_text(596, 36, text_size(g, 20), PAL_GOLD, "CONNECTIONS")
		dw_text(848, 36, text_size(g, 20), PAL_PINK, num_str(g.connections))
		dw_text(874, 36, text_size(g, 20), PAL_GOLD, "/")
		dw_text(894, 36, text_size(g, 20), PAL_PINK, num_str(lvl.connections_needed))
	} else if lvl.sequences_needed > 0 {
		dw_text(640, 36, text_size(g, 20), PAL_GOLD, "SEQUENCES")
		dw_text(848, 36, text_size(g, 20), PAL_PINK, num_str(g.sequences_done))
		dw_text(874, 36, text_size(g, 20), PAL_GOLD, "/")
		dw_text(894, 36, text_size(g, 20), PAL_PINK, num_str(lvl.sequences_needed))
	} else if lvl.survive_ms > 0 {
		remain := max(0, (lvl.survive_ms - g.elapsed_ms) / 1000)
		dw_text(700, 36, text_size(g, 20), PAL_GOLD, "STAY")
		dw_text(790, 36, text_size(g, 20), PAL_PINK, num_str(remain))
		dw_text(856, 36, text_size(g, 20), PAL_GOLD, "S")
	}
	if g.fidget_idx >= 0 {
		dw_text(300, 850, text_size(g, 22), PAL_GOLD, FIDGETS[g.fidget_idx].name)
	} else if g.caption_ms > 0 && len(g.caption) > 0 {
		dw_text(240, 850, text_size(g, 22), PAL_ROSE, g.caption)
	} else if lvl.survive_ms > 0 {
		dw_text(380, 850, text_size(g, 22), PAL_DIM, "STAY WITH HER")
	}
}

// ---------------------------------------------------------------------------
// Public orchestration: the wasm boundary
// ---------------------------------------------------------------------------

game: Game

@(export)
init :: proc(seed: u32, level: int) -> int {
	idx, err := validate_level(level)
	if err != .None {
		game = game_init(u64(seed), false)
		return -1
	}
	game = game_init(u64(seed), false)
	game.level_idx = idx
	return 0
}

@(export)
init_demo :: proc(seed: u32, level: int) -> int {
	idx, err := validate_level(level)
	if err != .None {
		game = game_init(u64(seed), true)
		return -1
	}
	game = game_init(u64(seed), true)
	game.level_idx = idx
	return 0
}

/// Persistence bridge in: the shell reports what previous sessions left
/// behind (visit count, remembered loneliness 0..1000 milli).
@(export)
apply_memory :: proc(visits: int, remembered_loneliness_milli: int) {
	game.visits = max(0, visits)
	game.remembered_loneliness = clamp01(f32(max(0, remembered_loneliness_milli)) / 1000.0)
}

@(export)
start_level :: proc(level: int) -> int {
	idx, err := validate_level(level)
	if err != .None { return -1 }
	begin_level(&game, idx)
	return 0
}

@(export)
step :: proc(dt_ms: int, input_bits: int, px: int, py: int) {
	inp := Input{
		tap     = input_bits & 1 != 0,
		confirm = input_bits & 2 != 0,
		back    = input_bits & 4 != 0,
		pause   = input_bits & 8 != 0,
		up      = input_bits & 16 != 0,
		down    = input_bits & 32 != 0,
	}
	step_game(&game, dt_ms, inp, px, py)
	dw_reset()
	render(&game)
}

@(export)
draw_ptr :: proc() -> rawptr {
	return &draw_buffer[0]
}

@(export)
draw_len_export :: proc() -> int {
	return draw_len
}

@(export)
screen :: proc() -> int {
	return int(game.screen)
}

@(export)
event_code :: proc() -> int {
	return int(game.event)
}

@(export)
level_idx :: proc() -> int {
	return game.level_idx
}

/// Persistence bridge: settings out (bit0 calm_room, bit1 text_large).
@(export)
settings_bits :: proc() -> int {
	bits := 0
	if game.calm_room { bits |= 1 }
	if game.text_large { bits |= 2 }
	return bits
}

@(export)
apply_settings :: proc(calm_room: int, text_large: int) {
	game.calm_room = calm_room != 0
	game.text_large = text_large != 0
}

/// Session stats out, for the shell to persist: the loneliness she
/// carries away from this visit (milli) and the connection count.
@(export)
stat_peak_loneliness_milli :: proc() -> int {
	return fi(game.peak_loneliness * 10.0) // peak is 0..100 -> milli of 0..1 = x10
}

@(export)
stat_connections :: proc() -> int {
	return game.connections
}

@(export)
loneliness_milli :: proc() -> int {
	return fi(game.loneliness * 10.0)
}
