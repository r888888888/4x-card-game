class_name ChoiceOverlays
extends RefCounted
## The choice overlays over the dimmed board: Explore (keep one revealed territory), Renewal (147: trash cards from
## the discard under Anarchy) and Government (154: choose one from the government deck when Anarchy ends), each shown
## while the engine waits for that decision. (The Knowledge overlay went with
## reveal-2 research in 140: techs are learned in the tech tree.)

var reveal: HBoxContainer  # the revealed territories to choose from
var renewal_row: HFlowContainer  # the discard pile, to trash from (147)
var government_row: HFlowContainer  # the government deck, to choose from (154)
var government_heading: Label
var _explore: Control
var _explore_panel: PanelContainer
var _renewal: Control
var _renewal_heading: Label
var _government: Control


## Builds the overlays on parent, hidden.
func _init(parent: Control) -> void:
	# Explore: a centred panel over the dimmed board, so the board keeps its layout.
	_explore = UIKit.overlay(parent, CardView.TYPE_COLORS.territory)
	_explore.z_index = 5  # above lifted cards, below the game-over overlay
	_explore_panel = _explore.get_meta("panel")
	var explore_box := _explore.get_meta("box") as VBoxContainer
	explore_box.add_child(UIKit.title("Explore"))
	explore_box.add_child(UIKit.heading("Keep one territory in the frontier; the other goes to the bottom of the territory deck."))
	reveal = HBoxContainer.new()
	reveal.add_theme_constant_override("separation", UIKit.CARD_GAP)
	explore_box.add_child(reveal)

	_renewal = UIKit.overlay(parent, Palette.UNREST)
	_renewal.z_index = 5
	var renewal_box := _renewal.get_meta("box") as VBoxContainer
	renewal_box.add_child(UIKit.title("Renewal"))
	_renewal_heading = UIKit.heading("")
	renewal_box.add_child(_renewal_heading)
	renewal_row = HFlowContainer.new()
	renewal_row.add_theme_constant_override("h_separation", UIKit.CARD_GAP)
	renewal_row.add_theme_constant_override("v_separation", UIKit.CARD_GAP)
	renewal_row.custom_minimum_size.x = 900  # wraps a long discard pile
	renewal_box.add_child(renewal_row)

	_government = UIKit.overlay(parent, Palette.UNREST)
	_government.z_index = 5
	var government_box := _government.get_meta("box") as VBoxContainer
	government_box.add_child(UIKit.title("Government"))
	government_heading = UIKit.heading("Order returns: choose your government.")
	government_box.add_child(government_heading)
	government_row = HFlowContainer.new()
	government_row.add_theme_constant_override("h_separation", UIKit.CARD_GAP)
	government_box.add_child(government_row)


## Shows the overlay for the decision engine e waits for (an explore choice, renewal or a government); e null hides
## them all.
func refresh(e: GameEngine) -> void:
	var pending: Dictionary = e.pending() if e != null else {}
	_explore.visible = pending.get("kind", "") == GameEngine.PENDING_EXPLORE
	_renewal.visible = pending.get("kind", "") == GameEngine.PENDING_RENEWAL
	_government.visible = pending.get("kind", "") == GameEngine.PENDING_GOVERNMENT
	if _renewal.visible:
		_renewal_heading.text = "Anarchy tears down the old ways: trash %d card%s from your discard pile. Each one calms 1 %s." % [
			pending.count, "" if pending.count == 1 else "s", GameEngine.UNREST]


## Whether container holds cards to click on while a choice is open.
func is_choice_row(container: Node) -> bool:
	return container == reveal or container == renewal_row or container == government_row


## The tooltip of a card in choice row container.
func pick_hint(container: Node) -> String:
	if container == government_row:
		return "Click to choose this government."
	return "Click to trash this card." if container == renewal_row else "Click to keep this territory."


## Where a territory put back in the territory deck flies: the right edge of the Explore panel.
func explore_exit_point() -> Vector2:
	var r := _explore_panel.get_global_rect()
	return Vector2(r.end.x, r.get_center().y)
