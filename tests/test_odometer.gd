extends "res://tests/lib/test_case.gd"
## The odometer (181): a figure whose digits roll to a new value one step at a time, every Anim.ODOMETER_STEP, at most
## Anim.ODOMETER_MAX_STEPS steps; with Reduce motion it jumps. Odometers run in the real main scene (for the theme's
## fonts), loaded by path (held as Object) so this file parses before ui/odometer.gd exists; tweens are stepped by hand.

const ODOMETER_PATH := "res://ui/odometer.gd"


## Anim's constant name, read by name so this file parses before it exists (red phase).
func anim(name: String) -> Variant:
	return (load("res://ui/anim.gd") as Script).get_script_constant_map().get(name, 0)


## A new odometer on main showing start at once, or null when the script is missing.
func new_odometer(main: Node, start: int) -> Object:
	check(FileAccess.file_exists(ODOMETER_PATH), "%s exists" % ODOMETER_PATH)
	if not FileAccess.file_exists(ODOMETER_PATH):
		return null
	var o: Control = load(ODOMETER_PATH).new()
	main.add_child(o)
	o.show_now(start)
	await wait_frames()
	return o


## Advances main's tweens one odometer step at a time, n times, returning what o shows after each step.
func roll(main: Node, o: Object, n: int) -> Array:
	var seen := []
	for i in n:
		for tween in main.get_tree().get_processed_tweens():
			tween.custom_step(anim("ODOMETER_STEP"))
		seen.append(o.shown())
	return seen


# --- AC1: one step at a time ---

func test_the_constants() -> void:
	eq(anim("ODOMETER_STEP"), 0.07, "Anim.ODOMETER_STEP")
	eq(anim("ODOMETER_MAX_STEPS"), 8, "Anim.ODOMETER_MAX_STEPS")


func test_rolling_up_shows_each_value_in_turn() -> void:
	await with_reduce_motion(false, func():
		var main := open_main()
		var o: Object = await new_odometer(main, 7)
		if o != null:
			eq(o.shown(), 7, "shows 7")
			o.set_value(10)
			eq(o.value, 10, "value is 10 from the call on")
			eq(o.shown(), 7, "still showing 7")
			eq(roll(main, o, 4), [8, 9, 10, 10], "8, then 9, then 10")
		close_main(main))


func test_rolling_down_shows_each_value_in_turn() -> void:
	await with_reduce_motion(false, func():
		var main := open_main()
		var o: Object = await new_odometer(main, 5)
		if o != null:
			o.set_value(3)
			eq(o.value, 3, "value")
			eq(roll(main, o, 3), [4, 3, 3], "4, then 3")
		close_main(main))


# --- AC2: long changes, changes mid-roll, Reduce motion ---

func test_a_long_change_rolls_only_the_last_eight_steps() -> void:
	await with_reduce_motion(false, func():
		var main := open_main()
		var o: Object = await new_odometer(main, 12)
		if o != null:
			o.set_value(40)
			eq(o.shown(), 32, "12 → 40 jumps to 32")
			eq(roll(main, o, 8), [33, 34, 35, 36, 37, 38, 39, 40], "then rolls 33 … 40")
			o.set_value(12)
			eq(o.shown(), 20, "40 → 12 jumps to 20")
			eq(roll(main, o, 8), [19, 18, 17, 16, 15, 14, 13, 12], "then rolls 19 … 12")
		close_main(main))


func test_a_change_mid_roll_rolls_on_from_where_it_was_heading() -> void:
	await with_reduce_motion(false, func():
		var main := open_main()
		var o: Object = await new_odometer(main, 7)
		if o != null:
			o.set_value(10)
			var first := roll(main, o, 1)
			o.set_value(12)
			eq(o.value, 12, "value")
			eq(first + roll(main, o, 5), [8, 9, 10, 11, 12, 12], "rolls on: 8, 9, 10, 11, 12")
		close_main(main))


func test_with_reduce_motion_the_new_value_shows_at_once() -> void:
	await with_reduce_motion(true, func():
		var main := open_main()
		var o: Object = await new_odometer(main, 7)
		if o != null:
			o.set_value(40)
			eq(o.shown(), 40, "40 at once")
		close_main(main))
