class_name ChoiceOverlays
extends RefCounted
## The choice overlay over the dimmed board: Explore (keep one revealed territory), shown while the engine waits for
## that decision. (The Knowledge overlay went with reveal-2 research in 140: techs are learned in the tech tree.)

var reveal: HBoxContainer  # the revealed territories to choose from
var _explore: Control
var _explore_panel: PanelContainer


## Builds the overlay on parent, hidden.
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


## Shows the overlay while engine e waits for an explore choice; e null hides it.
func refresh(e: GameEngine) -> void:
	var pending_kind: String = e.pending().get("kind", "") if e != null else ""
	_explore.visible = pending_kind == GameEngine.PENDING_EXPLORE


## Whether container holds cards to click on while a choice is open.
func is_choice_row(container: Node) -> bool:
	return container == reveal


## The tooltip of a card in choice row container.
func pick_hint(_container: Node) -> String:
	return "Click to keep this territory."


## Where a territory put back in the territory deck flies: the right edge of the Explore panel.
func explore_exit_point() -> Vector2:
	var r := _explore_panel.get_global_rect()
	return Vector2(r.end.x, r.get_center().y)
