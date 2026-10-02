class_name Odometer
extends Control
## A figure whose digits roll like an odometer (181, guide §10.3, §15.5). Each digit is a column of 0–9 and a second 0
## (for rolling on past 9) inside a box one digit tall; a change steps through every value between the old and the new
## one, Anim.ODOMETER_STEP a step, and only the last Anim.ODOMETER_MAX_STEPS steps of a longer change (it jumps to
## the start of those). With Reduce motion it shows the new value at once. It sounds its steps (188, guide §10.3): a
## tick as each digit lands, each a dB quieter than the last, and the last step registers with a gain or a loss instead
## (with Reduce motion, the registration alone). Left-aligned: it grows rightward from
## whatever sits to its left. Its digits use the variation's font (BarStat or Stat: tabular figures, 178), so every
## column is one digit wide.

## Its width changed (a digit came or went): emitted at once, unlike minimum_size_changed, so a row can follow mid-roll.
signal widened

var value := 0  # where it is heading: the new value from the moment set_value is called
var color := Palette.TEXT:  # the digits' colour
	set(c):
		color = c
		if _sign == null:
			return
		for label in _labels():
			label.add_theme_color_override("font_color", c)
var variation := &"BarStat"  # the Label variation whose font and size the digits use

var _at := 0  # the value the columns are at (or rolling to, mid-step)
var _queue: Array[int] = []  # values still to roll through
var _tween: Tween
var _columns: Array[Control] = []  # ones first
var _sign: Label  # "−" for a negative value
var _digit := Vector2.ZERO  # one digit's box


func _init(p_variation := &"BarStat") -> void:
	variation = p_variation
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_sign = _digit_label("−")
	add_child(_sign)


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED or what == NOTIFICATION_ENTER_TREE:
		_measure()


## Shows v at once, without rolling (a new game, an opened screen).
func show_now(v: int) -> void:
	_stop()
	value = v
	_at = v
	_place(v, 0)


## Rolls to v one step at a time, starting after delay; with Reduce motion shows it at once. A call during a roll
## rolls on from where the roll had got to. sound: tick and register (not when a covered bar catches up).
func set_value(v: int, delay := 0.0, sound := true) -> void:
	var from := value
	if UIKit.calm():
		show_now(v)
		if sound and v != from:
			_register(v > from, 0.0)
		return
	value = v
	if v == from:
		return
	if _tween != null:  # mid-roll: carry on from the value the columns show
		from = shown()
		_stop()
		_at = from
		_place(from, 0)
	var step := signi(v - from)
	var n := mini(absi(v - from), Anim.ODOMETER_MAX_STEPS)
	var start := v - step * n
	if start != from:  # a long change: jump to the last steps
		_at = start
		_place(start, 0)
	for k in range(1, n + 1):
		_queue.append(start + step * k)
	if sound and n > 0:
		var sfx := Sfx.find(self)
		for k in range(1, n):
			if sfx != null:
				sfx.play(Sfx.COUNTER_TICK, delay + k * Anim.ODOMETER_STEP, false, -(k - 1))
		_register(step > 0, delay + n * Anim.ODOMETER_STEP)
	_roll(delay)


## The last step lands: the drum locks in, with a gain or a loss.
func _register(up: bool, delay: float) -> void:
	var sfx := Sfx.find(self)
	if sfx != null:
		sfx.play(Sfx.RESOURCE_GAIN if up else Sfx.RESOURCE_LOSS, delay)


## The value the digit columns show right now (each column read at its nearest digit).
func shown() -> int:
	if _digit.y <= 0.0:
		return _at
	var total := 0
	var scale := 1
	for column in _columns:
		if not column.visible:
			break
		total += posmod(roundi(-column.position.y / _digit.y), 10) * scale
		scale *= 10
	return -total if _sign.visible else total


func _stop() -> void:
	_queue.clear()
	if _tween != null:
		_tween.kill()
		_tween = null


## One tween for every queued step (a tween started from another's callback would wait a frame): each step lays the
## columns out for both values, then slides each changed column one digit, Anim.ODOMETER_STEP long.
func _roll(delay := 0.0) -> void:
	_tween = create_tween()
	if delay > 0.0:
		_tween.tween_interval(delay)
	var at := _at
	for next: int in _queue:
		var old := _digits(at)
		var new := _digits(next)
		var used := maxi(old.size(), new.size())
		while _columns.size() < used:
			_add_column()
		var grows := absi(next) > absi(at)  # the magnitude: a negative figure rolls the other way
		var moves := []  # [column, target y, start from the second 0]
		for i in used:
			var o: int = old[i] if i < old.size() else 0
			var d: int = new[i] if i < new.size() else 0
			if o == d:
				continue
			if grows and o == 9 and d == 0:  # on past 9 to the second 0; the next step puts it back on the first
				moves.append([_columns[i], -10.0, false])
			elif not grows and o == 0 and d == 9:  # back below 0: from the second 0 down to 9
				moves.append([_columns[i], -9.0, true])
			else:
				moves.append([_columns[i], -float(d), false])
		_tween.tween_callback(_begin_step.bind(at, used, moves))
		for k in moves.size():  # the step's columns slide together
			var t := _tween.parallel() if k > 0 else _tween
			t.tween_property(moves[k][0], "position:y", moves[k][1] * _digit.y, Anim.ODOMETER_STEP)
		_tween.tween_callback(func(): _at = next)
		at = next
	_queue.clear()
	_tween.tween_callback(func(): _tween = null; _place(_at, 0))


## A step from at begins: the columns on at's digits, room for used of them, and any column rolling back below 0 on
## its second 0.
func _begin_step(at: int, used: int, moves: Array) -> void:
	_place(at, used)
	for move in moves:
		if move[2]:
			(move[0] as Control).position.y = -10 * _digit.y


## Shows v's digits, with room for at least columns of them (more while a step adds or drops a digit).
func _place(v: int, columns: int) -> void:
	var digits := _digits(v)
	var used := maxi(digits.size(), columns)
	while _columns.size() < used:
		_add_column()
	for i in _columns.size():
		_columns[i].position.y = -(digits[i] if i < digits.size() else 0) * _digit.y
	_layout(used, v < 0)


## Lays used columns out left to right (the highest digit first) after the sign, and sizes the odometer to them.
func _layout(used: int, negative: bool) -> void:
	_sign.visible = negative
	var x := _digit.x if negative else 0.0
	_sign.position = Vector2.ZERO
	_sign.size = _digit
	for i in _columns.size():
		_columns[i].visible = i < used
		_columns[i].position.x = x + (used - 1 - i) * _digit.x
	var box := Vector2(x + used * _digit.x, _digit.y)
	if box != custom_minimum_size:
		custom_minimum_size = box
		size = box
		widened.emit()


func _add_column() -> void:
	var column := Control.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for d in 11:
		var label := _digit_label(str(d % 10))
		label.position = Vector2(0, d * _digit.y)
		label.size = _digit
		column.add_child(label)
	add_child(column)
	_columns.append(column)


func _digit_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = variation
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_color", color)
	return label


## One digit's box from the variation's font, and every label and column placed to it.
func _measure() -> void:
	var font := get_theme_font("font", variation)
	var font_size := get_theme_font_size("font_size", variation)
	var box := Vector2(font.get_string_size("0", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x, font.get_height(font_size))
	if box == _digit:
		return
	_digit = box
	for column in _columns:
		for d in column.get_child_count():
			var label := column.get_child(d) as Label
			label.position = Vector2(0, d * _digit.y)
			label.size = _digit
	if _tween == null:
		_place(_at, 0)


func _labels() -> Array[Label]:
	var out: Array[Label] = [_sign]
	for column in _columns:
		for label in column.get_children():
			out.append(label)
	return out


## The digits of v's size, ones first.
static func _digits(v: int) -> Array[int]:
	var out: Array[int] = []
	var x := absi(v)
	while true:
		out.append(x % 10)
		x /= 10
		if x == 0:
			break
	return out
