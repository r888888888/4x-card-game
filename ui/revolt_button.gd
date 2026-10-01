class_name RevoltButton
extends RefCounted
## The Revolt button below the Realm (148): shown while a revolutionary event lets you start Anarchy now.

var button: Button


func _init(parent: Control) -> void:
	button = UIKit.button("Revolt", func(): Game.engine.revolt())
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	button.tooltip_text = "Start Anarchy now: your government falls into your deck, and you trash cards from your discard. Play a government the people accept to end it."
	parent.add_child(button)


func refresh(e: GameEngine) -> void:
	button.visible = e.revolt_error() == ""
