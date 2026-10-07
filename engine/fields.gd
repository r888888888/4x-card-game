class_name Fields
extends RefCounted
## Readers for JSON fields shared by the loader and effects: each appends a message to errors on a bad value
## and returns a safe default, so a loader can report every problem in one pass.


## Why resource can't be paid, or "": unrest (144) is only gained and lost, so no cost, discount, relief or trade
## names it.
static func unpayable(resource: String) -> String:
	return "%s can't be paid (it is only gained and lost)" % resource if resource == GameEngine.UNREST else ""


## A price ({resource: amount}) as text, in its order: "5 wealth", "2 food, 5 wealth" (173).
static func amounts_text(cost: Dictionary) -> String:
	return ", ".join(PackedStringArray(cost.keys().map(func(r): return "%d %s" % [cost[r], r])))


## JSON numbers are floats; accept whole numbers as ints. Returns null otherwise.
static func as_int(v: Variant) -> Variant:
	if v is int:
		return v
	if v is float and is_finite(v) and v == floorf(v):
		return int(v)
	return null


## data[key] as an int >= min_value. Missing: default_value, or an error if there is none.
static func read_int(data: Dictionary, key: String, errors: Array[String], min_value := 0, default_value: Variant = null) -> int:
	if not data.has(key):
		if default_value == null:
			errors.append("missing '%s'" % key)
			return 0
		return default_value
	var v: Variant = as_int(data[key])
	if typeof(v) != TYPE_INT or v < min_value:
		errors.append("'%s' must be an integer >= %d, not %s" % [key, min_value, JSON.stringify(data[key])])
		return 0
	return v


## data[key] as a bool. Missing: default_value.
static func read_bool(data: Dictionary, key: String, errors: Array[String], default_value := false) -> bool:
	if not data.has(key):
		return default_value
	if not (data[key] is bool):
		errors.append("'%s' must be true or false, not %s" % [key, JSON.stringify(data[key])])
		return default_value
	return data[key]


## data[key] as a String, one of allowed when given. Missing: default_value, or an error if there is none.
static func read_string(data: Dictionary, key: String, errors: Array[String], allowed: Array = [], default_value: Variant = null) -> String:
	if not data.has(key):
		if default_value == null:
			errors.append("missing '%s'" % key)
			return ""
		return default_value
	var v: Variant = data[key]
	if not (v is String):
		errors.append("'%s' must be a string" % key)
		return ""
	if not allowed.is_empty() and not allowed.has(v):
		errors.append("'%s' must be one of: %s (got '%s')" % [key, ", ".join(PackedStringArray(allowed)), v])
		return ""
	return v
