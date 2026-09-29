class_name ChoiceOverlays
extends RefCounted
## The two choice overlays over the dimmed board: Explore (keep one revealed territory) and Knowledge (buy one
## revealed tech, or decline). Each shows while the engine waits for that decision.

var reveal: HBoxContainer  # the revealed territories to choose from
var research_row: HBoxContainer  # the revealed techs
var _explore: Control
var _explore_panel: PanelContainer
var _research: Control


## Builds both overlays on parent, hidden.
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

	_research = UIKit.overlay(parent, CardView.TYPE_COLORS.tech)
	_research.z_index = 5
	var research_box := _research.get_meta("box") as VBoxContainer
	research_box.add_child(UIKit.title("Knowledge"))
	research_box.add_child(UIKit.heading("Buy one tech with wealth, or decline both. The others go back into the tech deck."))
	research_row = HBoxContainer.new()
	research_row.add_theme_constant_override("separation", UIKit.CARD_GAP)
	research_box.add_child(research_row)
	research_box.add_child(UIKit.button("Decline", func(): Game.engine.decline_research()))


## Shows the overlay for pending_kind (GameEngine.PENDING_*), hides the other.
func refresh(pending_kind: String) -> void:
	_explore.visible = pending_kind == GameEngine.PENDING_EXPLORE
	_research.visible = pending_kind == GameEngine.PENDING_RESEARCH


## Whether container holds cards to click on while a choice is open.
func is_choice_row(container: Node) -> bool:
	return container == reveal or container == research_row


## The tooltip of a card in choice row container.
func pick_hint(container: Node) -> String:
	return "Click to buy this tech." if container == research_row else "Click to keep this territory."


## Where a territory put back in the territory deck flies: the right edge of the Explore panel.
func explore_exit_point() -> Vector2:
	var r := _explore_panel.get_global_rect()
	return Vector2(r.end.x, r.get_center().y)
