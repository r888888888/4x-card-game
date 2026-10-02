class_name Sfx
extends Node
## The sound player (186): every sound in the game is one of the style guide's tokens (§14.1), played here and nowhere
## else. Main owns one, like the ModalStack. It knows each token's level, bus and files, and keeps the guide's rules
## (§16.4, §16.8): ticks no closer than TICK_GAP, notifications NOTICE_GAP apart, INTERFACE_VOICES voices on the
## Interface bus (a Level 1 gives way, the oldest Level 1 is stolen for a Level 2), and nothing the system plays talks
## over a Level 3 (the player's own input plays EVENT_DUCK_DB quieter). A sound may be delayed (play's delay, or
## at_contact: when its motion makes contact, §16.5); clock() is the time source, which tests set by hand.

const BUTTON_PRESS := &"ui.button.press"
const BUTTON_RELEASE := &"ui.button.release"
const TOGGLE_ON := &"ui.toggle.on"
const TOGGLE_OFF := &"ui.toggle.off"
const SELECTION := &"ui.selection"
const CARD_LIFT := &"ui.card.lift"
const CARD_PLACE := &"ui.card.place"
const COUNTER_TICK := &"ui.counter.tick"
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
const MILESTONE_VICTORY := &"ui.milestone.victory"
const MILESTONE_DEFEAT := &"ui.milestone.defeat"
## Each token's level (§16.4): 1 micro-feedback and 2 structural on the Interface bus, 3 events on the Game bus.
const TOKENS := {
	BUTTON_PRESS: 1, BUTTON_RELEASE: 1, TOGGLE_ON: 1, TOGGLE_OFF: 1, SELECTION: 1, CARD_LIFT: 1, CARD_PLACE: 1,
	COUNTER_TICK: 1, FLAP: 1, RESOURCE_GAIN: 1, RESOURCE_LOSS: 1, REJECT_LOCKED: 1,
	PANEL_OPEN: 2, PANEL_CLOSE: 2, SHEET_OPEN: 2, SHEET_CLOSE: 2, NAV_FORWARD: 2, NAV_BACK: 2, CABINET_CLOSE: 2,
	CABINET_PART: 2, PILE_DEAL: 2, PILE_GATHER: 2, CONFIRM: 2, REJECT: 2, NOTIFICATION_INFO: 2,
	NOTIFICATION_CAUTION: 2, NOTIFICATION_URGENT: 2, ENDTURN_PRESS: 2, ENDTURN_COMMIT: 2, ENDTURN_TURN: 2,
	MILESTONE: 3, MILESTONE_BREAKTHROUGH: 3, MILESTONE_CITY: 3, MILESTONE_WONDER: 3, MILESTONE_ACCORD: 3,
	MILESTONE_ERA: 3, MILESTONE_VICTORY: 3, MILESTONE_DEFEAT: 3,
}
const NOTIFICATIONS: Array[StringName] = [NOTIFICATION_INFO, NOTIFICATION_CAUTION, NOTIFICATION_URGENT]
## Two-stage sounds start this early (s), so their last stage lands on contact and the snap just before (§16.5).
const _LEADS := {BUTTON_PRESS: 0.014, ENDTURN_PRESS: 0.014, BUTTON_RELEASE: 0.018, TOGGLE_OFF: 0.018}
const VARIANTS := {1: "abcd", 2: "ab", 3: ""}  # each level's file variants (§16.8, §16.10)
const SOUNDS_DIR := "res://assets/sounds"
const TICK_GAP := 0.035  # s between counter ticks across the bus; a closer one is dropped
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


func _init() -> void:
	add_to_group(GROUP)


## The sound player in node's tree (main's), or null when there is none (a component tested on its own).
static func find(node: Node) -> Sfx:
	return node.get_tree().get_first_node_in_group(GROUP) as Sfx if node.is_inside_tree() else null


## token's level: 1, 2 or 3 (0 for an unknown token).
static func level(token: StringName) -> int:
	return TOKENS.get(token, 0)


## The bus token plays on.
static func bus(token: StringName) -> StringName:
	return Settings.GAME if level(token) == 3 else Settings.INTERFACE


## token's files: four variants for Level 1 (ui/ui_button_press_a.wav … _d.wav), two for Level 2, one for Level 3
## (events/ui_milestone_era.wav).
static func files(token: StringName) -> Array[String]:
	var stem := String(token).replace(".", "_")
	if level(token) == 3:
		return ["%s/events/%s.wav" % [SOUNDS_DIR, stem]]
	var out: Array[String] = []
	for v in VARIANTS.get(level(token), ""):
		out.append("%s/ui/%s_%s.wav" % [SOUNDS_DIR, stem, v])
	return out


## What plays token: Level 1 and 2 through a randomizer over their variants (Level 1 with pitch and volume jitter),
## Level 3 its file.
static func stream(token: StringName) -> AudioStream:
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
## plays even during a Level 3). Returns whether it will play.
func play(token: StringName, delay := 0.0, input := false, gain_db := 0.0) -> bool:
	if not TOKENS.has(token):
		push_error("Sfx: no sound token '%s'" % token)
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
	if NOTIFICATIONS.has(token):
		at = maxf(at, _last_notice + NOTICE_GAP)
		_last_notice = at
	var on := bus(token)
	if on == Settings.INTERFACE and playing(on).size() >= INTERFACE_VOICES:
		if lvl == 1:
			return false
		var oldest := _voices.filter(func(v): return v.bus == on and v.level == 1)
		if oldest.is_empty():
			return false
		_stop(oldest[0])
	_voices.append({"token": token, "bus": on, "level": lvl, "at": at, "end": at + length(token), "db": gain_db,
		"player": null})
	_played.append({"token": token, "bus": on, "at": at, "db": gain_db, "input": input})
	_start_due()
	return true


## Plays token when a motion of duration on curve makes contact, less its lead (never before now); at once with
## Reduce motion.
func at_contact(token: StringName, duration: float, curve: Vector4, input := false) -> bool:
	var delay := 0.0 if UIKit.calm() else maxf(0.0, Anim.contact(duration, curve) - lead(token))
	return play(token, delay, input)


## Every sound played, in order: {token, bus, at, db, input}.
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
			player.stream = stream(v.token)
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
