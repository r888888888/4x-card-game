class_name Sfx
extends Node
## The sound player (186): every sound in the game is one of the style guide's tokens (§14.1), played here and nowhere
## else. Main owns one, like the ModalStack. It knows each token's level, bus and files, and keeps the guide's rules
## (§16.4, §16.8): ticks no closer than TICK_GAP, notifications NOTICE_GAP apart, INTERFACE_VOICES voices on the
## Interface bus (a Level 1 gives way, the oldest Level 1 is stolen for a Level 2), and nothing the system plays talks
## over a Level 3 (the player's own input plays EVENT_DUCK_DB quieter; a system sound the same frame already scheduled
## under it gives way, 191). A sound may be delayed (play's delay, or
## at_contact: when its motion makes contact, §16.5); clock() is the time source, which tests set by hand.

const BUTTON_PRESS := &"ui.button.press"
const BUTTON_RELEASE := &"ui.button.release"
const TOGGLE_ON := &"ui.toggle.on"
const TOGGLE_OFF := &"ui.toggle.off"
const SELECTION := &"ui.selection"
const CARD_LIFT := &"ui.card.lift"
const CARD_PLACE := &"ui.card.place"
const COUNTER_TICK := &"ui.counter.tick"
const HOVER := &"ui.hover"
const FLAP := &"ui.flap"
const RESOURCE_GAIN := &"ui.resource.gain"
const RESOURCE_LOSS := &"ui.resource.loss"
const REJECT_LOCKED := &"ui.reject.locked"
const PANEL_OPEN := &"ui.panel.open"
const PANEL_CLOSE := &"ui.panel.close"
const SHEET_OPEN := &"ui.sheet.open"
const SHEET_CLOSE := &"ui.sheet.close"
const NAV_FORWARD := &"ui.nav.forward"
const NAV_BACK := &"ui.nav.back"
const CABINET_CLOSE := &"ui.cabinet.close"
const CABINET_PART := &"ui.cabinet.part"
const PILE_DEAL := &"ui.pile.deal"
const PILE_GATHER := &"ui.pile.gather"
const CONFIRM := &"ui.confirm"
const REJECT := &"ui.reject"
const NOTIFICATION_INFO := &"ui.notification.info"
const NOTIFICATION_CAUTION := &"ui.notification.caution"
const NOTIFICATION_URGENT := &"ui.notification.urgent"
const ENDTURN_PRESS := &"ui.endturn.press"
const ENDTURN_COMMIT := &"ui.endturn.commit"
const ENDTURN_TURN := &"ui.endturn.turn"
const MILESTONE := &"ui.milestone"
const MILESTONE_BREAKTHROUGH := &"ui.milestone.breakthrough"
const MILESTONE_CITY := &"ui.milestone.city"
const MILESTONE_WONDER := &"ui.milestone.wonder"
const MILESTONE_ACCORD := &"ui.milestone.accord"
const MILESTONE_ERA := &"ui.milestone.era"
const MILESTONE_PILLAGED := &"ui.milestone.pillaged"  # a raid pillaged (271)
const MILESTONE_REPELLED := &"ui.milestone.repelled"  # a raid repelled (271)
const MILESTONE_VICTORY := &"ui.milestone.victory"
const MILESTONE_DEFEAT := &"ui.milestone.defeat"
const MILESTONE_BUILD := &"ui.milestone.build"  # a building or an upgrade built (357)
const MILESTONE_RECRUIT := &"ui.milestone.recruit"  # a unit recruited (357)
## Each token's level (§16.4): 1 micro-feedback and 2 structural on the Interface bus, 3 events on the Game bus.
const TOKENS := {
	BUTTON_PRESS: 1, BUTTON_RELEASE: 1, TOGGLE_ON: 1, TOGGLE_OFF: 1, SELECTION: 1, CARD_LIFT: 1, CARD_PLACE: 1,
	COUNTER_TICK: 1, HOVER: 1, FLAP: 1, RESOURCE_GAIN: 1, RESOURCE_LOSS: 1, REJECT_LOCKED: 1,
	PANEL_OPEN: 2, PANEL_CLOSE: 2, SHEET_OPEN: 2, SHEET_CLOSE: 2, NAV_FORWARD: 2, NAV_BACK: 2, CABINET_CLOSE: 2,
	CABINET_PART: 2, PILE_DEAL: 2, PILE_GATHER: 2, CONFIRM: 2, REJECT: 2, NOTIFICATION_INFO: 2,
	NOTIFICATION_CAUTION: 2, NOTIFICATION_URGENT: 2, ENDTURN_PRESS: 2, ENDTURN_COMMIT: 2, ENDTURN_TURN: 2,
	MILESTONE: 3, MILESTONE_BREAKTHROUGH: 3, MILESTONE_CITY: 3, MILESTONE_WONDER: 3, MILESTONE_ACCORD: 3,
	MILESTONE_ERA: 3, MILESTONE_VICTORY: 3, MILESTONE_DEFEAT: 3, MILESTONE_PILLAGED: 3, MILESTONE_REPELLED: 3, MILESTONE_BUILD: 3, MILESTONE_RECRUIT: 3,
}
const NOTIFICATIONS: Array[StringName] = [NOTIFICATION_INFO, NOTIFICATION_CAUTION, NOTIFICATION_URGENT]
## Two-stage sounds start this early (s), so their last stage lands on contact and the snap just before (§16.5).
const _LEADS := {BUTTON_PRESS: 0.014, ENDTURN_PRESS: 0.014, BUTTON_RELEASE: 0.018, TOGGLE_OFF: 0.018}
const VARIANTS := {1: "abcd", 2: "ab", 3: ""}  # each level's file variants (§16.8, §16.10)
## Tokens whose variants differ from their level's: the end-turn chord walks D, Bm, G, A (246).
const _TOKEN_VARIANTS := {ENDTURN_TURN: "abcd"}
const SOUNDS_DIR := "res://assets/sounds"
const TICK_GAP := 0.035  # s between counter ticks across the bus; a closer one is dropped
const HOVER_GAP := 0.08  # s between hover ticks; a closer one is dropped (245)
const HOVER_DB := -8.0  # a hover tick sits well under a press
const NOTICE_GAP := 0.4  # s between notifications; a closer one waits
const INTERFACE_VOICES := 6
const EVENT_DUCK_DB := -6.0  # the player's input during a Level 3
const L1_PITCH := 1.015  # ±25 cents of jitter on a Level 1
const L1_VOLUME_DB := 1.0  # ±1 dB

const GROUP := &"sfx"  # find() looks the player up by it

static var _streams := {}  # token -> its loaded stream

var _clock := -1.0  # set by set_clock; below 0, the real time
var _played: Array[Dictionary] = []
var _voices: Array[Dictionary] = []  # scheduled or sounding: {token, bus, level, at, end, db, player}
var _ticks: Array[float] = []  # when recent ticks are due
var _last_notice := -INF
var _last_hover := -INF
var _hover_asked := false  # a hover waits for the end of the frame's input, to see whether a button is down
var _mouse_held := false  # a mouse button is down (a hover then belongs to a press or drag, 245)
var _notice_frame := -1  # the frame a notification last played in
var _input_frame := -1  # the frame the player last pressed or released a key or mouse button in


func _init() -> void:
	add_to_group(GROUP)


## Notes the frame of the player's last key or mouse button (before any control handles it), for player_acted.
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_mouse_held = event.pressed or event.button_mask != 0
	elif event is InputEventMouseMotion:
		_mouse_held = event.button_mask != 0
	if event is InputEventKey or event is InputEventMouseButton:
		note_input()


## The player pressed or released a key or button this frame (for a node that takes keys before this player's _input).
func note_input() -> void:
	_input_frame = Engine.get_process_frames()


## Whether the player pressed or released a key or button this frame: a sheet or screen that changes now is their input
## (189).
func player_acted() -> bool:
	return _input_frame == Engine.get_process_frames()


## Whether a notification played this frame (a modal opening with it steps back, 189).
func notified() -> bool:
	return _notice_frame == Engine.get_process_frames()


## The sound player in node's tree (main's), or null when there is none (a component tested on its own).
static func find(node: Node) -> Sfx:
	return node.get_tree().get_first_node_in_group(GROUP) as Sfx if node.is_inside_tree() else null


## token's level: 1, 2 or 3 (0 for an unknown token).
static func level(token: StringName) -> int:
	return TOKENS.get(token, 0)


## The bus token plays on.
static func bus(token: StringName) -> StringName:
	return Settings.GAME if level(token) == 3 else Settings.INTERFACE


## token's files: four variants for Level 1 (ui/ui_button_press_a.wav … _d.wav), two for Level 2 (four chords for
## ui.endturn.turn), one for Level 3 (events/ui_milestone_era.wav).
static func files(token: StringName) -> Array[String]:
	var stem := String(token).replace(".", "_")
	if level(token) == 3:
		return ["%s/events/%s.wav" % [SOUNDS_DIR, stem]]
	var out: Array[String] = []
	for v in _TOKEN_VARIANTS.get(token, VARIANTS.get(level(token), "")):
		out.append("%s/ui/%s_%s.wav" % [SOUNDS_DIR, stem, v])
	return out


## What plays token: Level 1 and 2 through a randomizer over their variants (Level 1 with pitch and volume jitter),
## Level 3 its file. With a variant (0 = a), that variant's file.
static func stream(token: StringName, variant := -1) -> AudioStream:
	if variant >= 0:
		var key := "%s#%d" % [token, variant]
		if not _streams.has(key):
			_streams[key] = load(files(token)[variant])
		return _streams[key]
	if not _streams.has(token):
		var paths := files(token)
		if level(token) == 3:
			_streams[token] = load(paths[0])
		else:
			var r := AudioStreamRandomizer.new()
			r.playback_mode = AudioStreamRandomizer.PLAYBACK_RANDOM_NO_REPEATS
			r.random_pitch = L1_PITCH if level(token) == 1 else 1.0
			r.random_volume_offset_db = L1_VOLUME_DB if level(token) == 1 else 0.0
			for path in paths:
				r.add_stream(-1, load(path))
			_streams[token] = r
	return _streams[token]


## The end-turn chord for ending turn: D, Bm, G, A, then round again from turn 5 (246).
static func turn_variant(turn: int) -> int:
	return posmod(turn - 1, files(ENDTURN_TURN).size())


## How long token sounds (s): its first file's length.
static func length(token: StringName) -> float:
	return (load(files(token)[0]) as AudioStream).get_length()


## How early token starts before its contact (s).
static func lead(token: StringName) -> float:
	return _LEADS.get(token, 0.0)


## Freezes the clock at seconds (tests).
func set_clock(seconds: float) -> void:
	_clock = seconds


## Now, in seconds.
func clock() -> float:
	return _clock if _clock >= 0.0 else Time.get_ticks_usec() / 1000000.0


## Plays token delay seconds from now, gain_db louder or quieter. input: the player's own press or key caused it (it
## plays even during a Level 3). variant: which file (0 = a), or -1 for the token's random choice. Returns whether it
## will play.
func play(token: StringName, delay := 0.0, input := false, gain_db := 0.0, variant := -1) -> bool:
	if not TOKENS.has(token):
		push_error("Sfx: no sound token '%s'" % token)
		return false
	if variant < -1 or variant >= files(token).size():
		push_error("Sfx: '%s' has no variant %d" % [token, variant])
		return false
	var now := clock()
	var at := now + maxf(delay, 0.0)
	var lvl := level(token)
	_voices = _voices.filter(func(v): return v.end > now)
	if lvl < 3 and _during_event(at):
		if not input:
			return false
		gain_db += EVENT_DUCK_DB
	if token == COUNTER_TICK:
		_ticks = _ticks.filter(func(t): return t > now - 1.0)
		if _ticks.any(func(t): return absf(at - t) < TICK_GAP):
			return false
		_ticks.append(at)
	if token == HOVER:
		if absf(at - _last_hover) < HOVER_GAP:
			return false
		_last_hover = at
	if NOTIFICATIONS.has(token):
		at = maxf(at, _last_notice + NOTICE_GAP)
		_last_notice = at
		_notice_frame = Engine.get_process_frames()
	var on := bus(token)
	var sounding := _voices.filter(func(v): return v.bus == on and v.at <= at and at < v.end)
	if on == Settings.INTERFACE and sounding.size() >= INTERFACE_VOICES:
		if lvl == 1:
			return false
		var oldest := sounding.filter(func(v): return v.level == 1)
		if oldest.is_empty():
			return false
		_stop(oldest[0])
	var record := {"token": token, "bus": on, "at": at, "db": gain_db, "input": input, "variant": variant}
	if lvl == 3:
		_give_way(at, at + length(token))
	_voices.append({"token": token, "bus": on, "level": lvl, "at": at, "end": at + length(token), "db": gain_db,
		"player": null, "variant": variant, "input": input, "frame": Engine.get_process_frames(), "record": record})
	_played.append(record)
	_start_due()
	return true


## The mouse entered something clickable: a quiet tick once this frame's input is in, unless a mouse button is down
## (the entry belongs to a press or a drag then), or a button was pressed or released this frame (245).
func hover() -> void:
	_hover_asked = true
	_hover_check.call_deferred()


func _hover_check() -> void:
	if _hover_asked and not _mouse_held and not player_acted():
		play(HOVER, 0.0, false, HOVER_DB)
	_hover_asked = false


## Plays token when a motion of duration on curve makes contact, less its lead (never before now); at once with
## Reduce motion.
func at_contact(token: StringName, duration: float, curve: Vector4, input := false) -> bool:
	var delay := 0.0 if UIKit.calm() else maxf(0.0, Anim.contact(duration, curve) - lead(token))
	return play(token, delay, input)


## Every sound played, in order: {token, bus, at, db, input, variant}.
func played() -> Array[Dictionary]:
	return _played.duplicate(true)


## The tokens scheduled or sounding on bus, oldest first.
func playing(on: StringName) -> Array[StringName]:
	var now := clock()
	var out: Array[StringName] = []
	for v in _voices:
		if v.bus == on and v.end > now:
			out.append(v.token)
	return out


func _process(_delta: float) -> void:
	_start_due()


## The system's Level 1 and 2 sounds this frame scheduled between from and to give way to the Level 3 starting at
## from: an action's counters and notices don't talk over its event, whichever was heard first.
func _give_way(from: float, to: float) -> void:
	var frame := Engine.get_process_frames()
	for v in _voices.filter(func(v): return v.level < 3 and not v.input and v.frame == frame and from <= v.at and v.at < to):
		_stop(v)
		_played.erase(v.record)


func _during_event(at: float) -> bool:
	return _voices.any(func(v): return v.level == 3 and v.at <= at and at < v.end)


func _stop(voice: Dictionary) -> void:
	if voice.player != null:
		(voice.player as AudioStreamPlayer).stop()
	_voices.erase(voice)


## Starts every voice that is due on a free player of its bus.
func _start_due() -> void:
	var now := clock()
	for v in _voices:
		if v.player == null and v.at <= now:
			var player := _free_player(v.bus)
			player.stream = stream(v.token, v.variant)
			player.volume_db = v.db
			player.play()
			v.player = player


func _free_player(on: StringName) -> AudioStreamPlayer:
	for c in get_children():
		var p := c as AudioStreamPlayer
		if p.bus == on and not p.playing and not _voices.any(func(v): return v.player == p):
			return p
	var player := AudioStreamPlayer.new()
	player.bus = on
	add_child(player)
	return player
