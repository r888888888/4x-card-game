extends "res://tests/lib/test_case.gd"
## Territory names on screen and the naming modal (backlog 248) in the real main scene on the real data (seed 5, Egypt):
## the territory view's title and the territory's card in the Realm show the city name over the land name; the view's
## Rename… (territory_view.rename_button) opens main.rename_modal (field, rename_button, cancel_button) prefilled with
## the name.


## Main on seed 5 as Egypt with the home territory's view open. Free with close_main.
func open_home() -> Node:
	var main := open_main()
	main.start_game(5, "egypt")
	await wait_frames()
	main.territory_view.open(home_uid(Game.engine))
	await wait_frames()
	return main


func home_name() -> String:
	return Game.engine.call("territory_name", home_uid(Game.engine))


func land_name() -> String:
	return Game.engine.zone("tableau").find(home_uid(Game.engine)).def.name


## Opens the naming modal from the territory view's Rename….
func open_rename(main: Node) -> void:
	var rename: Button = main.territory_view.get("rename_button")
	check(rename != null, "the territory view has a Rename… button")
	if rename != null:
		eq(rename.text, "Rename…", "its text")
		rename.pressed.emit()
	await wait_frames()


## Types text into the modal's field, as the player would (text_changed follows).
func type_name(main: Node, text: String) -> void:
	var field: LineEdit = main.rename_modal.field
	field.text = text
	field.text_changed.emit(text)


# --- AC8: the name on screen ---

func test_the_territory_view_and_its_card_show_the_city_name_over_the_land_name() -> void:
	var main: Node = await open_home()
	var city := home_name()
	check(city != land_name(), "Egypt names its home (%s), not its land (%s)" % [city, land_name()])
	var title: String = main.territory_view.title_text()
	check(title.begins_with(city), "the view's title starts with the city name: %s" % title)
	check(title.contains(land_name()), "and shows the land name: %s" % title)
	var face: String = (main.views[home_uid(Game.engine)] as CardView).face_text()
	var lines := face.split("\n")
	check(lines.has(city), "the Realm card shows the city name: %s" % face)
	check(face.find(city) < face.find(land_name()), "over the land name: %s" % face)
	close_main(main)


# --- AC8: the modal ---

func test_rename_opens_the_naming_modal_prefilled_with_the_name() -> void:
	var main: Node = await open_home()
	await open_rename(main)
	eq(main.modals.top(), main.rename_modal, "the naming modal on top")
	eq(main.rename_modal.field.text, home_name(), "prefilled with the name")
	eq(main.rename_modal.footer.get_children().filter(func(b): return b is Button and b.visible).map(func(b): return b.text),
		["Cancel", "Rename"], "Cancel, then Rename at the right")
	close_main(main)


func test_an_invalid_name_disables_rename_with_the_engines_reason() -> void:
	var main: Node = await open_home()
	await open_rename(main)
	var rename: Button = main.rename_modal.rename_button
	for text in ["   ", "x".repeat(25)]:
		type_name(main, text)
		check(rename.disabled, "Rename disabled for '%s'" % text)
		eq(rename.tooltip_text, Game.engine.call("rename_territory_error", home_uid(Game.engine), text), "its reason")
	type_name(main, "Nile Gate")
	check(not rename.disabled, "enabled for a good name")
	close_main(main)


# --- 251: Cancel, then Rename in the signal colour ---

func test_rename_is_the_primary_and_disabled_it_loses_the_accent() -> void:
	var main: Node = await open_home()
	await open_rename(main)
	var rename: Button = main.rename_modal.rename_button
	eq(accent_footer(main.rename_modal), ["Rename"] as Array[String], "Rename is the one primary, Cancel plain")
	type_name(main, "   ")
	check(rename.disabled, "precondition: Rename disabled")
	eq(rename.theme_type_variation, &"AccentButton", "still the primary key")
	var box := rename.get_theme_stylebox("disabled") as StyleBoxFlat
	check(box != null and not box.bg_color.is_equal_approx(Palette.ACCENT), "disabled, it has no ACCENT fill")
	eq(rename.tooltip_text, Game.engine.call("rename_territory_error", home_uid(Game.engine), "   "), "and keeps its reason")
	close_main(main)


func test_enter_renames_the_territory_and_closes_the_modal() -> void:
	var main: Node = await open_home()
	await open_rename(main)
	type_name(main, "  Nile Gate ")
	main.rename_modal.field.text_submitted.emit("  Nile Gate ")
	await wait_frames()
	eq(home_name(), "Nile Gate", "renamed")
	check(not main.rename_modal.is_open(), "the modal closed")
	check(main.territory_view.title_text().begins_with("Nile Gate"), "the view shows the new name")
	close_main(main)


func test_rename_button_renames_and_an_invalid_enter_does_nothing() -> void:
	var main: Node = await open_home()
	var before := home_name()
	await open_rename(main)
	type_name(main, "   ")
	main.rename_modal.field.text_submitted.emit("   ")
	await wait_frames()
	check(main.rename_modal.is_open(), "Enter on a blank name keeps the modal open")
	eq(home_name(), before, "not renamed")
	type_name(main, "Delta")
	main.rename_modal.rename_button.pressed.emit()
	await wait_frames()
	eq(home_name(), "Delta", "Rename renamed it")
	check(not main.rename_modal.is_open(), "and closed the modal")
	close_main(main)


func test_cancel_and_esc_close_without_renaming() -> void:
	var main: Node = await open_home()
	var before := home_name()
	await open_rename(main)
	type_name(main, "Delta")
	main.rename_modal.cancel_button.pressed.emit()
	await wait_frames()
	check(not main.rename_modal.is_open(), "Cancel closed it")
	await open_rename(main)
	type_name(main, "Delta")
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	main.get_viewport().push_input(esc)
	await wait_frames()
	check(not main.rename_modal.is_open(), "Esc closed it")
	eq(home_name(), before, "not renamed")
	check(main.territory_view.is_open(), "the territory view stays open")
	close_main(main)
