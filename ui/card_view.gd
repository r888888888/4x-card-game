class_name CardView
extends PanelContainer
## Visual for one card. It rests inside a slot Control that a zone's container lays out, and
## animates itself: it lifts on hover, slides when its slot moves, flies between slots on the
## shared effects layer, and follows the cursor while dragged. Hand cards emit drag_requested and
## double_clicked and discard_requested (right-click); pickable cards (a pending choice) emit picked. A single click
## with no second click or drag (or a right-click on a pickable card) emits details_requested. main.gd decides what
## those mean. Its content is a CardFace and its movement a CardMotion (backlog 086); it keeps the panel, tooltip,
## border, focus ring and input.

signal drag_requested(view: CardView, grab_offset: Vector2)
signal double_clicked(view: CardView)
signal discard_requested(view: CardView)
signal picked(view: CardView)
signal details_requested(view: CardView)

enum State { REST, FLYING, DRAGGING, LEAVING }

const GROUP := &"card_views"  # every CardView, restyled when Day mode changes (183)
static var TYPE_COLORS: Dictionary:  # card type -> its colour, as the palette reads now (183)
	get:
		return {
			CardDef.ACTION: Palette.ACTION,
			CardDef.BUILDING: Palette.BUILDING,
			CardDef.CITY: Palette.CITY,
			CardDef.TERRITORY: Palette.TERRITORY,
			CardDef.TECH: Palette.TECH,
			CardDef.EVENT: Palette.EVENT,
		}
const HAND_SIZE := Vector2(264, 320)
const TABLEAU_SIZE := Vector2(245, 175)
const BOARD_SIZE := Vector2(245, 150)  # every card in the Realm's row (138): one line per field, the rest in details
# Board faces (138): what a card in the Realm's row is.
const BOARD_REALM := "realm"
const BOARD_FRONTIER := "frontier"
const BOARD_EVENT := "event"
const DASH := 9.0  # an unsettled territory's dashed border
const HATCH_STEP := 14.0  # the spacing of its diagonal lines
static var WARN_COLOR: Color:
	get:
		return Palette.WARN
static var HIGHLIGHT_COLOR: Color:
	get:
		return Palette.GAIN
# A dimmed card (unplayable, or an idle building) greys its background and border, never its text.
static var DIM_BG: Color:
	get:
		return Palette.DIM_BG
static var DIM_BORDER: Color:
	get:
		return Palette.DIM_BORDER
static var FOCUS_COLOR: Color:  # keyboard focus ring; distinct from gold (target) and red (warning)
	get:
		return Palette.FOCUS
const FOCUS_RING_GAP := 6.0  # px between the card's edge and its focus ring (outside or inside)

var uid := -1
var card_id := ""
var in_hand := false
var board_kind := ""  # a card in the Realm's row: BOARD_REALM, BOARD_FRONTIER or BOARD_EVENT; "" elsewhere
var pickable := false  # an option of a pending choice or a target: a click picks it
var lift_on_hover := false  # lift under the mouse like a hand card (supply cards, which have room)
var state := State.REST
var slot: Control  # where the card rests; laid out by the hand or tableau container
var fx_scale := Vector2.ONE  # tweened for pop-in and shrink; the card's scale

var _style: StyleBoxFlat
var _color: Color
var _face: CardFace
var _hint := ""  # the tooltip's hint after the card text, kept so a new card text can be set under it
var _motion := CardMotion.new(self)
var _warning := false
var _highlight := false
var _above_vellum := false  # lifted above the targeting vellum (210)
var _vellum_outline := false  # and ringed in FOCUS: a target
var _dimmed := false
var _focused := false
var _hover := false
var _pressed := false
var _press_pos := Vector2.ZERO
var _target_size := Vector2.ZERO
var _details_click := 0  # counts clicks; a delayed details request only fires if no click came after it
var _setup_args := []  # the last setup's arguments, and what was shown on the face since (by setter): for restyle
var _replays := {}


## Builds (or rebuilds) the card's content. play_error: "" if playable, otherwise the reason
## (shown on the card and as tooltip). Ignored for tableau cards. kind: a board face for the Realm's row (BOARD_*,
## 138), at BOARD_SIZE; "" for the full face.
func setup(card: CardInstance, card_db: Dictionary, p_in_hand: bool, play_error := "", kind := "") -> void:
	_setup_args = [card, card_db, p_in_hand, play_error, kind]
	_replays = {}
	add_to_group(GROUP)
	board_kind = kind
	uid = card.uid
	card_id = card.def.id
	in_hand = p_in_hand
	pickable = false
	var def := card.def
	_color = type_color(def.type)
	_target_size = HAND_SIZE if in_hand else (BOARD_SIZE if kind != "" else TABLEAU_SIZE)
	custom_minimum_size = _target_size

	if _style == null:
		_style = StyleBoxFlat.new()
		_style.set_border_width_all(2)
		_style.set_corner_radius_all(0)  # an index card, cut square (179)
		_style.set_content_margin_all(Tokens.SPACE_3)
		_style.anti_aliasing = false  # a hard shadow and a crisp rule
		add_theme_stylebox_override("panel", _style)
		mouse_entered.connect(_set_hover.bind(true))
		mouse_exited.connect(_set_hover.bind(false))
		size = _target_size
	_dimmed = false

	if _face != null:
		remove_child(_face)
		_face.queue_free()
	_face = CardFace.new()
	add_child(_face)
	if kind != "":
		_face.build_board(card, card_db, kind, _color)
	else:
		_face.build(card, card_db, in_hand, _color)

	if in_hand:
		set_play_error(play_error)
	else:
		modulate = Color.WHITE
		_set_tip("")
		mouse_default_cursor_shape = Control.CURSOR_ARROW
	_update_border()


## The colour of card type's band (a type with none of its own: grey).
static func type_color(type: String) -> Color:
	return TYPE_COLORS.get(type, Color.GRAY)


## Rebuilds the face in the palette's current colours (183): setup again with the same card, then everything shown on
## the face since (play error, settled line, event and buy info, hint, idle, pickable, shortfall).
func restyle() -> void:
	if _setup_args.is_empty():
		return
	var replays := _replays.duplicate()
	callv("setup", _setup_args)
	for replay: Callable in replays.values():
		replay.call()


## Updates the playable look of a hand card: tooltip, cursor, dimming, and a strip at the bottom
## saying why it can't be played.
func set_play_error(play_error: String) -> void:
	_replays["play_error"] = set_play_error.bind(play_error)
	var playable := play_error == ""
	_set_tip("Drag into the realm (or double-click) to play. Right-click to discard." if playable else play_error)
	mouse_default_cursor_shape = Control.CURSOR_DRAG if playable else Control.CURSOR_FORBIDDEN
	_set_dimmed(not playable, "" if playable else "⊘ " + play_error)


## Shows which of a hand card's cost figures the player is short of (180; GameEngine.play_shortfall).
func set_shortfall(short: Array[String]) -> void:
	_replays["shortfall"] = set_shortfall.bind(short)
	_face.show_shortfall(short)


## Shows a settled territory's face (123): its live line ("▢ 6   ⌂ 2/5   ⚒ 2") and tooltip tip, both from the board.
## Its keywords show in its territory view, not on the card (199).
func show_settled(live: String, tip: String) -> void:
	_replays["settled"] = show_settled.bind(live, tip)
	_face.show_settled(live)
	_face.rules_tip = tip
	_set_tip(_hint)


## Shows how many upkeeps an active event has left ("1 turn left" / "2 turns left"), or its counters when it has
## any ("2 counters", the Famine).
func set_event_info(turns_left: int, counters := 0) -> void:
	_replays["event_info"] = set_event_info.bind(turns_left, counters)
	if counters > 0:  # the Famine: it lasts until pop is fed, so it shows how bad it is (083)
		_face.replace_info("EventInfo", "%d counter%s" % [counters, "" if counters == 1 else "s"])
	else:
		_face.replace_info("EventInfo", "%d turn%s left" % [turns_left, "" if turns_left == 1 else "s"])


## The text set_event_info shows, or "" when it was never called.
func event_info_text() -> String:
	return _face.info_text("EventInfo")


## Shows a supply pile's price and copies left ("2 wealth · 1 left"). error: "" if it can be bought,
## otherwise the reason, which dims the card and leads its tooltip.
func set_buy_info(price: int, left: int, error: String) -> void:
	_replays["buy_info"] = set_buy_info.bind(price, left, error)
	_face.update_info("BuyInfo", "%d wealth · %d left" % [price, left])
	_set_dimmed(error != "", "" if error == "" else "⊘ " + error)
	if error == "":
		_set_tip("Click to buy a copy into your discard.")
	else:
		tooltip_text = error + "\n\n" + _face.rules_tip
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if error == "" else Control.CURSOR_FORBIDDEN


## Ends the tooltip with hint after the card text (137: what an event or a frontier territory in the Realm's row is).
func set_hint(hint: String) -> void:
	_replays["hint"] = set_hint.bind(hint)
	_set_tip(hint)



## Dims a tableau building with no worker and marks it "Idle" (or clears that).
func set_idle(idle: bool) -> void:
	_replays["idle"] = set_idle.bind(idle)
	_set_dimmed(idle, "⊘ Idle: no worker" if idle else "")
	_set_tip("Idle: this territory has more buildings than pop, so this one skips upkeep." if idle else "")


## Makes a non-hand card clickable as a choice option or target (or not). tooltip says what a click does.
func set_pickable(on: bool, tooltip := "") -> void:
	_replays["pickable"] = set_pickable.bind(on, tooltip)
	pickable = on
	if in_hand:
		return
	_set_tip(tooltip if on else "")
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if on else Control.CURSOR_ARROW
	if not on:
		_set_hover(false)


## Shows or hides the keyboard focus ring. A focused hand card also lifts like a hovered one.
func set_focused(on: bool) -> void:
	_focused = on
	if state == State.REST:
		z_index = rest_z()
	queue_redraw()


## Tints the card red while it is held over the play area but can't be played there.
func set_warning(on: bool) -> void:
	_warning = on
	_update_border()


## The z_index the card rests at: over its neighbours while hovered or focused, over the vellum while lifted above it.
func rest_z() -> int:
	return (1 if (_hover or _focused) else 0) + (Vellum.LIFT_Z if _above_vellum else 0)


## Lifts the card above the targeting vellum (210), or lets it back down; outlined: a target, ringed in FOCUS.
func set_above_vellum(on: bool, outlined := false) -> void:
	_above_vellum = on
	_vellum_outline = on and outlined
	if state == State.REST:
		z_index = rest_z()
	_update_border()


## Outlines the card in gold as a valid target for the card being played.
func set_highlight(on: bool) -> void:
	_highlight = on
	_update_border()


## Sets the tooltip: the full card text, a blank line, then hint (either part may be empty).
func _set_tip(hint: String) -> void:
	_hint = hint
	var rules_tip := _face.rules_tip
	if rules_tip == "" or hint == "":
		tooltip_text = rules_tip + hint
	else:
		tooltip_text = rules_tip + "\n\n" + hint


## Greys the card's background and border (not its text) and shows reason in a strip at the
## bottom, or undoes both.
func _set_dimmed(on: bool, reason: String) -> void:
	_dimmed = on
	_face.set_reason(reason)
	_face.set_band_color(DIM_BORDER if on else _color)
	_update_border()


# --- Movement (CardMotion) ---

## Places the card at rest in slot immediately.
func attach(p_slot: Control) -> void:
	_motion.attach(p_slot)


## Starts at rest in slot, growing in from nothing (a card created on the tableau) after delay.
func pop_in(p_slot: Control, delay := 0.0) -> void:
	_motion.pop_in(p_slot, delay)


## Appears at from_point (the deck) on layer, fading in, and after delay flies to slot.
func deal(p_slot: Control, layer: Control, from_point: Vector2, delay: float) -> void:
	_motion.deal(p_slot, layer, from_point, delay)


## Moves onto layer and flies to p_slot, easing its size to the slot's card size.
func fly_to_slot(p_slot: Control, layer: Control) -> void:
	_motion.fly_to_slot(p_slot, layer)


## Flies back to its own slot (after a cancelled or refused drag).
func return_home() -> void:
	_motion.return_home()


## Shakes to say "no": now if resting, otherwise when it lands back in its slot.
## A played card flying to its slot: it pats down as it lands (188).
func place_on_land() -> void:
	_motion.place_on_land = true


func reject() -> void:
	_motion.reject()


func begin_drag(layer: Control, grab_offset: Vector2) -> void:
	_motion.begin_drag(layer, grab_offset)


## Leaves the board: optionally pops (first flying to via, e.g. the card it was played on), then
## shrinks and fades towards point, calls on_arrival (if valid; not with Reduce motion), then frees itself.
func leave(layer: Control, point: Vector2, pop: bool, via: Variant = null, on_arrival := Callable()) -> void:
	_motion.leave(layer, point, pop, via, on_arrival)


## Test hook (087): the text on the card's face, lines joined by newlines.
func face_text() -> String:
	return _face.text() if _face != null else ""


## The size of the slot this card rests in: its nominal size, plus the lift room above a hand card. A card whose
## text needs more room grows its slot once it is at rest.
func slot_size() -> Vector2:
	return _motion.slot_size()


func _process(delta: float) -> void:
	_motion.process(delta)


func _draw() -> void:
	if board_kind == BOARD_FRONTIER:
		_draw_frontier()
	if _focused:
		var ring := StyleBoxFlat.new()
		ring.draw_center = false
		ring.border_color = FOCUS_COLOR
		ring.set_border_width_all(2)
		ring.set_corner_radius_all(0)
		# Outside a hand card; inside any other, where the Realm's scroll box would clip a ring drawn
		# outside it.
		var gap := FOCUS_RING_GAP if in_hand else -FOCUS_RING_GAP
		draw_style_box(ring, Rect2(Vector2.ZERO, size).grow(gap))


# --- Input and hover ---

func _gui_input(event: InputEvent) -> void:
	var button: int = event.button_index if event is InputEventMouseButton else -1
	if pickable and state == State.REST and button in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT] and event.pressed:
		accept_event()
		if button == MOUSE_BUTTON_LEFT:
			picked.emit(self)
		else:
			details_requested.emit(self)
		return
	if not in_hand:  # a realm, frontier, known or event card: a click shows its details
		if state == State.REST and button == MOUSE_BUTTON_LEFT and event.pressed:
			accept_event()
			_details_later()
		return
	if _motion.delay > 0.0 or state == State.DRAGGING or state == State.LEAVING:
		return
	if button == MOUSE_BUTTON_RIGHT and event.pressed:
		accept_event()
		discard_requested.emit(self)
	elif button == MOUSE_BUTTON_LEFT:
		accept_event()
		if not event.pressed:
			if _pressed:
				_details_later()
			_pressed = false
		elif event.double_click:
			_pressed = false
			_details_click += 1
			double_clicked.emit(self)
		else:
			_pressed = true
			_press_pos = event.position
	elif event is InputEventMouseMotion and _pressed:
		if event.position.distance_to(_press_pos) >= Anim.DRAG_START_DISTANCE:
			_pressed = false
			drag_requested.emit(self, _press_pos)


## Asks for the details once the double-click window passes, unless another click came first.
func _details_later() -> void:
	_details_click += 1
	get_tree().create_timer(Anim.DETAILS_CLICK_DELAY).timeout.connect(_on_details_timer.bind(_details_click))


func _on_details_timer(click: int) -> void:
	if click == _details_click and state == State.REST:
		details_requested.emit(self)


func _set_hover(on: bool) -> void:
	_hover = on and (in_hand or pickable) and state == State.REST
	if state == State.REST:
		z_index = rest_z()  # draw over the neighbours while lifted
	_update_border()


## An unsettled territory (138): faint diagonal hatching, like unmapped land, and a dashed border in the colour
## _update_border chose (StyleBoxFlat draws no dashes).
func _draw_frontier() -> void:
	var r := Rect2(Vector2.ONE, size - Vector2.ONE * 2)
	var k := -r.size.y
	while k < r.size.x:  # the lines y = x - k, clipped to r
		var end_x := minf(k + r.size.y, r.size.x)
		draw_line(r.position + Vector2(maxf(k, 0.0), maxf(0.0, -k)), r.position + Vector2(end_x, end_x - k),
			Palette.FRONTIER_HATCH, 2.0)
		k += HATCH_STEP
	var corners := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	for i in 4:
		draw_dashed_line(corners[i], corners[(i + 1) % 4], _style.border_color, 4.0 if _highlight else 2.0, DASH)


## An index card (179): one sheet for every type in a thin rule (its type is the band under the name), standing on a
## hard shadow only while lifted: hovered (4, 4), dragged (8, 8).
func _update_border() -> void:
	_style.shadow_color = Palette.SHADOW
	_style.bg_color = DIM_BG if _dimmed else Palette.RAISED
	if _warning:
		_style.border_color = WARN_COLOR
	elif _hover or state == State.DRAGGING:
		_style.border_color = Palette.TEXT
	elif _vellum_outline:
		_style.border_color = FOCUS_COLOR  # a target above the vellum (210)
	elif _highlight:
		_style.border_color = HIGHLIGHT_COLOR
	else:
		_style.border_color = DIM_BORDER if _dimmed else Palette.CONTROL_BORDER
	var dragged := state == State.DRAGGING
	_style.shadow_size = 1 if (_hover or dragged) else 0
	_style.shadow_offset = Vector2(8, 8) if dragged else Vector2(4, 4)
	_style.set_border_width_all(3 if _highlight and not _vellum_outline else 2)
	if board_kind == BOARD_FRONTIER:  # its border is dashed, drawn in _draw_frontier
		_style.bg_color = Palette.FRONTIER_BG
		_style.set_border_width_all(0)
		queue_redraw()

