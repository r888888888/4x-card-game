class_name RestoreOrderButton
extends RefCounted
## The Restore order button below the Realm, beside Relieve famine (146): shown while Anarchy rules and order can be
## bought, disabled with the reason it can't pay.

var button: Button


func _init(parent: Control) -> void:
	button = UIKit.button("", func(): Game.engine.restore_order())
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	parent.add_child(button)


func refresh(e: GameEngine) -> void:
	var relief := e.order_relief()
	button.visible = e.anarchy() != -1 and not relief.is_empty()
	button.text = "Restore order (%s)" % CardFace.cost_text(relief)
	var error := e.restore_order_error()
	button.disabled = error != ""
	button.tooltip_text = error if error != "" else "Pay to end the Anarchy now: your fallback government rules."
