class_name ChoiceOverlays
extends RefCounted
## The choice overlays over the dimmed board: Explore (keep one revealed territory), Take (370: take one offered card
## into the hand) and Government (154: choose one from the government deck when Anarchy ends), each shown
## while the engine waits for that decision. (The Knowledge overlay went with
## reveal-2 research in 140: techs are learned in the tech tree.) The government choice comes and goes behind cabinet
## doors (209), or fades with Reduce motion.

const GOVERNMENT_FADE := 0.12  # the government overlay in and out with Reduce motion (209)

var reveal: HBoxContainer  # the revealed territories to choose from
var government_row: HFlowContainer  # the government deck, to choose from (154)
var government_heading: Label
var take_row: HFlowContainer  # the offered cards, to take one into the hand (370)
var _take: Control
var _explore: Control
var _explore_panel: PanelContainer
var government: Control  # the government overlay (154)
var doors: CabinetDoors  # shut over the board while the government choice comes and goes (209)
var _government_wanted := false  # the engine waits for the government choice: the overlay is (or is going) up
var _fade: Tween


## Builds the overlays on parent, hidden.
func _init(parent: Control) -> void:
	# Explore: a centred panel over the dimmed board, so the board keeps its layout.
	_explore = UIKit.overlay(parent, &"TERRITORY")
	_explore.z_index = 5  # above lifted cards, below the game-over overlay
	_explore_panel = _explore.get_meta("panel")
	var explore_box := _explore.get_meta("box") as VBoxContainer
	explore_box.add_child(UIKit.title("Explore"))
	explore_box.add_child(UIKit.heading("Keep one territory in the frontier; the other goes to the bottom of the territory deck."))
	reveal = HBoxContainer.new()
	reveal.add_theme_constant_override("separation", UIKit.CARD_GAP)
	explore_box.add_child(reveal)

	_take = UIKit.overlay(parent)
	_take.z_index = 5
	var take_box := _take.get_meta("box") as VBoxContainer
	take_box.add_child(UIKit.title("Take a Card"))
	take_box.add_child(UIKit.heading("Take one card into your hand; the others go to the discard pile."))
	take_row = HFlowContainer.new()
	take_row.add_theme_constant_override("h_separation", UIKit.CARD_GAP)
	take_box.add_child(take_row)

	government = UIKit.overlay(parent, &"UNREST")
	government.z_index = 5
	var government_box := government.get_meta("box") as VBoxContainer
	government_box.add_child(UIKit.title("Government"))
	government_heading = UIKit.heading("Order returns: choose your government.")
	government_box.add_child(government_heading)
	government_row = HFlowContainer.new()
	government_row.add_theme_constant_override("h_separation", UIKit.CARD_GAP)
	government_box.add_child(government_row)
	doors = CabinetDoors.new()
	parent.add_child(doors)


## Shows the overlay for the decision engine e waits for (an explore choice, a take or a government; renewal is a modal, 255); e null hides
## them all.
func refresh(e: GameEngine) -> void:
	var pending: Dictionary = e.pending() if e != null else {}
	_explore.visible = pending.get("kind", "") == GameEngine.PENDING_EXPLORE
	_take.visible = pending.get("kind", "") == GameEngine.PENDING_TAKE
	_show_government(pending.get("kind", "") == GameEngine.PENDING_GOVERNMENT, e != null)


## Puts the government overlay up or takes it down: behind the doors, or a fade with Reduce motion; at once when
## animated is false (no game: a new game or leaving one).
func _show_government(wanted: bool, animated: bool) -> void:
	if wanted == _government_wanted and animated:
		return
	_government_wanted = wanted
	if _fade != null and _fade.is_valid():
		_fade.kill()
	if not animated:
		doors.stop()
		government.visible = wanted
		government.modulate.a = 1.0
		return
	if not UIKit.calm():
		doors.close_over(func():
			government.visible = wanted
			government.modulate.a = 1.0)
		return
	government.visible = true
	government.modulate.a = 0.0 if wanted else 1.0
	_fade = government.create_tween()
	_fade.tween_property(government, "modulate:a", 1.0 if wanted else 0.0, GOVERNMENT_FADE)
	if not wanted:
		_fade.tween_callback(government.hide)


## Whether container holds cards to click on while a choice is open.
func is_choice_row(container: Node) -> bool:
	return container == reveal or container == government_row or container == take_row


## The tooltip of a card in choice row container.
func pick_hint(container: Node) -> String:
	if container == government_row:
		return "Click to choose this government."
	if container == take_row:
		return "Click to take this card into your hand."
	return "Click to keep this territory."


## Where a territory put back in the territory deck flies: the right edge of the Explore panel.
func explore_exit_point() -> Vector2:
	var r := _explore_panel.get_global_rect()
	return Vector2(r.end.x, r.get_center().y)
