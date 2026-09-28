class_name EffectRegistry
extends RefCounted
## Maps effect "op" names in card data to effect scripts.
## To add an effect: create engine/effects/<name>_effect.gd and register it here.

const OPS := {
	"gain": preload("res://engine/effects/gain_effect.gd"),
	"gain_per_tag": preload("res://engine/effects/gain_per_tag_effect.gd"),
	"draw": preload("res://engine/effects/draw_effect.gd"),
	"create": preload("res://engine/effects/create_effect.gd"),
	"score": preload("res://engine/effects/score_effect.gd"),
	"explore": preload("res://engine/effects/explore_effect.gd"),
	"settle": preload("res://engine/effects/settle_effect.gd"),
}


## Builds an effect from data. Returns null if it can't be built; problems go to errors.
static func create(data: Variant, ctx: Dictionary, errors: Array[String], warnings: Array[String]) -> Effect:
	if not (data is Dictionary):
		errors.append("effect must be an object")
		return null
	var op: Variant = data.get("op")
	if not (op is String) or not OPS.has(op):
		errors.append("unknown op '%s' (known: %s)" % [op, ", ".join(PackedStringArray(OPS.keys()))])
		return null
	var effect: Effect = OPS[op].new()
	effect.op = op
	effect.trigger = Effect.read_string(data, "trigger", errors, Effect.TRIGGERS, "play")
	effect.configure(data, ctx, errors)
	for key in data:
		if key != "op" and key != "trigger" and not effect.fields().has(key):
			warnings.append("unknown field '%s' in '%s' effect" % [key, op])
	return effect
