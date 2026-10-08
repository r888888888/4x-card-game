extends "res://tests/lib/test_case.gd"
## Card art plates (381): a hand-size face carries a CardArt plate named Art right after its type band, the picture at
## CardArt.file_for(id) cropped to the plate from its centre, or until it exists a placeholder in the type's colour with
## one of four motifs; shaded by Palette.ART_SHADE (Night only) under a 1 px EDGE frame. Tableau, Realm-row and
## supply-pile faces carry none. Fixture picture: tests/fixtures/card_art/farm.png (1536 × 1024).

const FIXTURE_DIR := "res://tests/fixtures/card_art/"

var _engine: GameEngine


## A CardView of card id set up as kind (in_hand, or a board kind), out of the tree; free it when done.
func face(id: String, in_hand := true, kind := "") -> CardView:
	if _engine == null:
		_engine = make_engine({"farm": 10})
	var view := CardView.new()
	view.setup(CardInstance.new(900, _engine.card_db[id]), _engine.card_db, in_hand, "", kind)
	return view


## Runs body with CardArt reading pictures from the fixture directory, then puts the real directory back.
func with_fixture_art(body: Callable) -> void:
	var before := CardArt.art_dir
	CardArt.art_dir = FIXTURE_DIR
	await body.call()
	CardArt.art_dir = before


# --- AC1: a placeholder plate after the band ---

func test_a_hand_face_without_a_picture_has_a_placeholder_plate_after_its_band() -> void:
	var view := face("bazaar")
	var plate := art_plate(view)
	eq(view.find_children("*", "CardArt", true, false).size(), 1, "the hand face has one plate")
	eq(plate.get_index(), plate.get_parent().get_node("Band").get_index() + 1, "named Art, directly after the band")
	eq(plate.size_flags_horizontal, Control.SIZE_EXPAND_FILL, "full width")
	eq(plate.custom_minimum_size.y, 96.0, "96 px tall")
	eq(CardArt.HAND_HEIGHT, 96.0, "CardArt.HAND_HEIGHT")
	eq(plate.has_picture(), false, "no picture for bazaar: the placeholder")
	eq(CardArt.file_for("bazaar"), "res://assets/cards/bazaar.png", "where its picture would be")
	view.free()


func test_the_placeholder_prints_no_text() -> void:
	var view := face("bazaar")
	var plate := art_plate(view)
	eq(plate.find_children("*", "Label", true, false).size(), 0, "no label on the plate")
	eq(plate.find_children("*", "RichTextLabel", true, false).size(), 0, "no rich label on the plate")
	check(not view.face_text().contains(".png"), "the face's text names no file: %s" % view.face_text())
	view.free()


# --- AC2: the picture, cropped from its centre ---

func test_a_card_with_a_picture_shows_it_and_one_without_keeps_the_placeholder() -> void:
	await with_fixture_art(func():
		var farm := face("farm")
		var bazaar := face("bazaar")
		eq(art_plate(farm).has_picture(), true, "the Farm's fixture picture")
		eq(art_plate(bazaar).has_picture(), false, "the Bazaar has none")
		farm.free()
		bazaar.free())


func test_the_picture_is_cropped_to_its_middle_band() -> void:
	var region := CardArt.cover_region(Vector2(1536, 1024), Vector2(240, 96))
	eq(region.position.x, 0.0, "the full width")
	eq(region.size.x, 1536.0, "the full width")
	check(is_equal_approx(region.size.y, 614.4), "the middle 60 %%: %s" % region)
	check(is_equal_approx(region.position.y, 204.8), "centred: %s" % region)
	var tall := CardArt.cover_region(Vector2(1536, 1024), Vector2(96, 96))
	check(is_equal_approx(tall.size.x, 1024.0) and is_equal_approx(tall.position.x, 256.0), "a square plate: %s" % tall)


# --- AC3: hand-size faces only ---

func test_tableau_and_realm_row_faces_have_no_plate() -> void:
	var tableau := face("farm", false)
	var board := face("grassland", false, CardView.BOARD_REALM)
	var hand := face("farm")
	check(art_plate(hand) != null, "a hand face has one")
	eq(art_plate(tableau), null, "a tableau face has none")
	eq(art_plate(board), null, "a Realm-row face has none")
	tableau.free()
	board.free()
	hand.free()


func test_the_hand_and_the_details_show_plates_and_the_realm_doesnt() -> void:
	var main: Node = await open_game(true)
	var e := Game.engine
	for view: CardView in main.views_in(main.hand):
		check(art_plate(view) != null, "%s in hand has a plate" % view.card_id)
	for view: CardView in main.views_in(main.tableau.row):
		eq(art_plate(view), null, "%s in the Realm has none" % view.card_id)
	open_details(main, e.zone("hand").cards[0].uid)
	await wait_frames()
	var shown := card_under(main.details.aside)
	check(art_plate(shown) != null, "the details' card has a plate")
	close_game(main)


# --- AC4: the taller hand card ---

func test_a_hand_card_is_264_by_360() -> void:
	eq(CardView.HAND_SIZE, Vector2(264, 360), "HAND_SIZE")


# --- AC5: the shade and the frame ---

func test_the_art_shade_dims_night_and_is_clear_in_day() -> void:
	await with_temp_settings(func():
		Settings.set_day_mode(false)
		eq(Palette.ART_SHADE, Color(0, 0, 0, 0.25), "Night: black at 25 %")
		Settings.set_day_mode(true)
		eq(Palette.ART_SHADE, Color(0, 0, 0, 0), "Day: clear"))


func test_a_rebuilt_face_shades_its_plate_in_the_new_mode() -> void:
	await with_temp_settings(func():
		Settings.set_day_mode(false)
		var view := face("bazaar")
		eq(art_plate(view).shade(), Color(0, 0, 0, 0.25), "Night's shade")
		eq(art_plate(view).frame(), Palette.EDGE, "framed in EDGE")
		Settings.set_day_mode(true)
		view.restyle()
		eq(art_plate(view).shade(), Color(0, 0, 0, 0), "Day's shade after the rebuild")
		eq(art_plate(view).frame(), Palette.EDGE, "Day's EDGE")
		view.free())


# --- AC6: the motif ---

func test_a_cards_motif_is_one_of_four_and_always_the_same() -> void:
	eq(CardArt.Motif.keys(), ["SUN", "RINGS", "SPLIT_DISC", "STEPS"], "the four motifs")
	for id in ["farm", "bazaar", "grassland", "capital", "famine"]:
		var motif := CardArt.motif_for(id)
		check(motif in CardArt.Motif.values(), "%s: a motif (%d)" % [id, motif])
		eq(CardArt.motif_for(id), motif, "%s: the same every call" % id)


# --- AC7: an unplayable card's plate dims ---

func test_an_unplayable_cards_placeholder_prints_in_the_dim_border() -> void:
	var view := face("bazaar")
	var plate := art_plate(view)
	var type_color := CardView.type_color(CardDef.ACTION)
	eq(plate.color(), type_color, "playable: the type's colour")
	view.set_play_error("Not enough food.")
	eq(plate.color(), Palette.DIM_BORDER, "unplayable: the dim border, like its band")
	eq(plate.veil(), Color(Palette.DIM_BG, 0.0), "no veil on a placeholder")
	view.set_play_error("")
	eq(plate.color(), type_color, "playable again: the type's colour")
	view.free()


func test_an_unplayable_cards_picture_is_veiled_in_the_dim_paper() -> void:
	await with_fixture_art(func():
		var view := face("farm")
		var plate := art_plate(view)
		eq(plate.veil().a, 0.0, "playable: no veil")
		view.set_play_error("Not enough food.")
		eq(plate.veil(), Color(Palette.DIM_BG, CardArt.DIM_VEIL), "unplayable: veiled in DIM_BG")
		eq(CardArt.DIM_VEIL, 0.6, "at 0.6")
		view.set_play_error("")
		eq(plate.veil().a, 0.0, "playable again: no veil")
		view.free())
