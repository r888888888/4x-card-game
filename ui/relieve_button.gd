class_name ReliefButton
extends RefCounted
## The Relieve button below the Realm (084; on its own since 137, when the active events joined the Realm's row):
## shown while a Famine can be relieved, disabled with the reason it can't pay.

var button: Button


func _init(parent: Control) -> void:
	button = UIKit.button("", func(): Game.engine.relieve_famine())
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	parent.add_child(button)


func refresh(e: GameEngine) -> void:
	var relief := e.famine_relief()
	button.visible = e.famine_counters() > 0 and not relief.is_empty()
	button.text = "Relieve famine (%s)" % CardFace.cost_text(relief)
	var error := e.relieve_famine_error()
	button.disabled = error != ""
	button.tooltip_text = error if error != "" else "Pay to end the famine now. A later hungry upkeep brings a new one."
