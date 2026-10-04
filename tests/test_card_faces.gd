extends "res://tests/lib/test_case.gd"
## Index-card faces and machined card motion (179): every card is one sheet (RAISED, a CONTROL_BORDER rule, square)
## with a band of its type colour under the name, a hard shadow only when lifted; a hovered card slides up without
## growing, and a dragged one barely tilts. CardViews run in a plain Control tree (a slot and an effects layer).

## One TEST_CARDS card of each type the fixtures have.
const BY_TYPE := {CardDef.ACTION: "bazaar", CardDef.BUILDING: "farm", CardDef.CITY: "capital",
	CardDef.TERRITORY: "grassland", CardDef.EVENT: "famine"}

var _engine: GameEngine


## A root holding a slot and an effects layer, and a CardView of card id set up as kind (in_hand, or a board
## kind, or "" for a tableau face), resting in the slot. Returns {root, slot, layer, view}; free root when done.
func fixture(id: String, in_hand := true, kind := "") -> Dictionary:
	if _engine == null:
		_engine = make_engine({"farm": 10})
	var root := Control.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(root)
	root.size = Vector2(1400, 900)
	var slot := Control.new()
	slot.custom_minimum_size = CardView.HAND_SIZE
	slot.size = CardView.HAND_SIZE
	slot.position = Vector2(500, 300)
	root.add_child(slot)
	var layer := Control.new()
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(layer)
	var view := CardView.new()
	view.setup(CardInstance.new(900, _engine.card_db[id]), _engine.card_db, in_hand, "", kind)
	view.attach(slot)
	return {"root": root, "slot": slot, "layer": layer, "view": view}


func panel(view: CardView) -> StyleBoxFlat:
	return view.get_theme_stylebox("panel") as StyleBoxFlat


## The card's type band, or null.
func band(view: CardView) -> ColorRect:
	return view.find_child("Band", true, false) as ColorRect


## Whether node is, or holds, a Label reading text.
func reads(node: Node, text: String) -> bool:
	if node is Label and (node as Label).text == text:
		return true
	return node.find_children("*", "Label", true, false).any(func(l: Label): return l.text == text)


# --- AC1: one sheet face for every type ---

func test_every_card_at_rest_is_a_raised_sheet_in_a_thin_rule() -> void:
	for type: String in BY_TYPE:
		for in_hand in [true, false]:
			var f := fixture(BY_TYPE[type], in_hand)
			var box := panel(f.view)
			var what := "%s %s" % [type, "hand" if in_hand else "tableau"]
			eq(box.bg_color.to_html(), Palette.RAISED.to_html(), "%s fill" % what)
			eq(box.border_color.to_html(), Palette.CONTROL_BORDER.to_html(), "%s border" % what)
			eq(box.border_width_top, 2, "%s border width" % what)
			eq(box.corner_radius_top_left, 0, "%s corner radius" % what)
			(f.root as Node).free()


func test_a_dimmed_card_uses_the_dim_colours() -> void:
	var f := fixture("farm")
	(f.view as CardView).set_play_error("Not enough food.")
	eq(panel(f.view).bg_color.to_html(), Palette.DIM_BG.to_html(), "dim fill")
	eq(panel(f.view).border_color.to_html(), Palette.DIM_BORDER.to_html(), "dim border")
	(f.root as Node).free()


func test_the_border_shows_hover_drag_warning_and_target() -> void:
	var f := fixture("farm")
	var view: CardView = f.view
	view.mouse_entered.emit()
	eq(panel(view).border_color.to_html(), Palette.TEXT.to_html(), "hovered: TEXT")
	view.mouse_exited.emit()
	view.set_warning(true)
	eq(panel(view).border_color.to_html(), Palette.WARN.to_html(), "a warning: WARN")
	view.set_warning(false)
	view.set_highlight(true)
	eq(panel(view).border_color.to_html(), Palette.GAIN.to_html(), "a target: GAIN")
	eq(panel(view).border_width_top, 3, "a target's border: 3 px")
	view.set_highlight(false)
	view.begin_drag(f.layer, Vector2.ZERO)
	eq(panel(view).border_color.to_html(), Palette.TEXT.to_html(), "dragged: TEXT")
	(f.root as Node).free()


# --- AC2: the type band ---

func test_a_band_of_the_type_colour_sits_under_the_name() -> void:
	for type: String in BY_TYPE:
		for kind in ["hand", "tableau", CardView.BOARD_REALM]:
			var f := fixture(BY_TYPE[type], kind == "hand", kind if kind == CardView.BOARD_REALM else "")
			var b := band(f.view)
			var what := "%s %s" % [type, kind]
			check(b != null, "%s: a Band" % what)
			if b != null:
				eq(b.color.to_html(), CardView.TYPE_COLORS[type].to_html(), "%s band colour" % what)
				eq(b.custom_minimum_size.y, 5.0, "%s band: 5 px" % what)
				var above := b.get_parent().get_child(b.get_index() - 1) if b.get_index() > 0 else null
				check(above != null and reads(above, _engine.card_db[BY_TYPE[type]].name),
					"%s: the band directly follows the name" % what)
			(f.root as Node).free()


func test_a_dimmed_cards_band_is_the_dim_border() -> void:
	var f := fixture("farm")
	(f.view as CardView).set_play_error("Not enough food.")
	var b := band(f.view)
	check(b != null, "a Band")
	if b != null:
		eq(b.color.to_html(), Palette.DIM_BORDER.to_html(), "dimmed band")
	(f.root as Node).free()


func test_a_frontier_territory_has_no_band() -> void:
	var f := fixture("grassland", false, CardView.BOARD_FRONTIER)
	check(band(f.view) == null, "no band on an unsettled frontier card")
	(f.root as Node).free()


# --- AC3: a hard shadow only when lifted ---

func test_a_card_at_rest_has_no_shadow_and_a_lifted_one_a_hard_one() -> void:
	var f := fixture("farm")
	var view: CardView = f.view
	eq(panel(view).shadow_size, 0, "at rest: no shadow")
	view.mouse_entered.emit()
	var box := panel(view)
	eq(box.shadow_color.to_html(), Palette.SHADOW.to_html(), "hovered: SHADOW")
	eq(box.shadow_offset, Vector2(4, 4), "hovered: offset (4, 4)")
	eq(box.shadow_size, 1, "hovered: shadow size 1")
	view.mouse_exited.emit()
	view.begin_drag(f.layer, Vector2.ZERO)
	eq(panel(view).shadow_offset, Vector2(8, 8), "dragged: offset (8, 8)")
	eq(panel(view).shadow_size, 1, "dragged: shadow size 1")
	(f.root as Node).free()


# --- AC4: slide, don't grow; barely tilt ---

func test_a_hovered_hand_card_rises_eight_px_without_growing() -> void:
	await with_reduce_motion(false, func():
		eq(Anim.HOVER_LIFT, 8.0, "Anim.HOVER_LIFT")
		var f := fixture("farm")
		var view: CardView = f.view
		var rest_y := view.position.y
		view.mouse_entered.emit()
		await wait_frames(60)
		check(absf(view.position.y - (rest_y - 8.0)) < 0.5, "risen 8 px: %s → %s" % [rest_y, view.position.y])
		check(view.scale.is_equal_approx(Vector2.ONE), "scale stays 1: %s" % view.scale)
		(f.root as Node).free())


func test_a_dragged_card_keeps_its_size_and_tilts_at_most_three_degrees() -> void:
	await with_reduce_motion(false, func():
		eq(Anim.MAX_TILT, deg_to_rad(3.0), "Anim.MAX_TILT")
		var f := fixture("farm")
		var view: CardView = f.view
		view.begin_drag(f.layer, Vector2.ZERO)
		var most := 0.0
		var grown := 0.0
		for i in 40:  # the cursor flies from side to side, far faster than any real drag
			(f.root as Control).get_viewport().warp_mouse(Vector2(1300 if i % 2 == 0 else 50, 400))
			await wait_frames(1)
			most = maxf(most, absf(view.rotation))
			grown = maxf(grown, view.scale.distance_to(Vector2.ONE))
		check(grown < 0.001, "scale stays 1 while dragged: strays %s" % grown)
		check(most <= deg_to_rad(3.0) + 0.0001, "tilts at most 3°: %s°" % rad_to_deg(most))
		(f.root as Node).free())


# --- AC5: no squash ---

func test_the_squash_is_gone() -> void:
	var view := CardView.new()
	check(not view.has_method("squash"), "CardView.squash is gone")
	view.free()
	check(not CardMotion.new(null).has_method("squash"), "CardMotion.squash is gone")
	var anim: Dictionary = (load("res://ui/anim.gd") as Script).get_script_constant_map()
	for name in ["LAND_SQUASH", "LAND_TIME"]:
		check(not anim.has(name), "Anim.%s is gone" % name)


func test_a_card_bought_on_the_supply_screen_doesnt_squash() -> void:
	await with_reduce_motion(false, func():
		await with_main(make_engine({"scout": 10}, {"supply": {"scout": {"price": 3, "count": 2}}}), func(main: Node):
			Game.engine.resources[GameEngine.WEALTH] = 10
			main.supply.open(Game.engine)
			await (Engine.get_main_loop() as SceneTree).create_timer(Anim.POP_IN_TIME + 0.2).timeout  # piles popped in
			var pile: CardView = main.supply.views()[0]
			main.supply.buy(pile)
			var largest := 0.0
			for i in 30:
				largest = maxf(largest, pile.fx_scale.distance_to(Vector2.ONE))
				await wait_frames(1)
			check(largest < 0.001, "the pile card's scale stays (1, 1): strays %s" % largest)))


# --- 198: card names in bold ---

## The Labels on view's face reading text.
func labels_reading(view: CardView, text: String) -> Array:
	return view.find_children("*", "Label", true, false).filter(func(l: Label): return l.text == text)


func test_the_theme_has_a_semibold_card_title_variation() -> void:
	var t := GameTheme.build()
	eq(t.get_type_variation_base("CardTitle"), &"Label", "CardTitle varies Label")
	eq(t.get_font_size("font_size", "CardTitle"), Tokens.TYPE_BODY, "CardTitle size")
	var font := t.get_font("font", "CardTitle")
	while font is FontVariation:
		font = (font as FontVariation).base_font
	eq(font, GameTheme.LABEL_SEMIBOLD, "CardTitle uses the semibold label face")


func test_every_card_face_names_its_card_in_the_card_title_variation() -> void:
	var cases := [["farm", true, ""], ["farm", false, ""], ["bazaar", true, ""], ["grassland", false, CardView.BOARD_REALM],
		["grassland", false, CardView.BOARD_FRONTIER], ["famine", false, CardView.BOARD_EVENT], ["capital", false, ""]]
	for case in cases:
		var f := fixture(case[0], case[1], case[2])
		var what := "%s (%s)" % [case[0], "hand" if case[1] else case[2] if case[2] != "" else "tableau"]
		var name: String = _engine.card_db[case[0]].name
		var titles := labels_reading(f.view, name)
		eq(titles.size(), 1, "%s: one label names the card" % what)
		for title: Label in titles:
			eq(title.theme_type_variation, &"CardTitle", "%s: its name is a CardTitle" % what)
			check(not title.has_theme_font_override("font"), "%s: no font override on its name" % what)
			check(not title.has_theme_font_size_override("font_size"), "%s: no size override on its name" % what)
		f.root.free()


func test_the_rest_of_a_card_face_keeps_its_font() -> void:
	for case in [["farm", true, ""], ["grassland", false, CardView.BOARD_FRONTIER], ["famine", false, CardView.BOARD_EVENT]]:
		var f := fixture(case[0], case[1], case[2])
		var name: String = _engine.card_db[case[0]].name
		var others: Array[String] = []
		for c in f.view.find_children("*", "Control", true, false):
			if (c is Label or c is RichTextLabel) and not (c is Label and c.text == name):
				if c.theme_type_variation == &"CardTitle":
					others.append(String(c.name))
		eq(others, [] as Array[String], "%s: only the name is a CardTitle" % case[0])
		f.root.free()
