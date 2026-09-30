extends "res://tests/lib/test_case.gd"
## The board's section order and game words (backlog 053): Realm on top, then Frontier, Known and Hand; Buy Cards,
## Knowledge and Insight; no seed in the top bar and no "tableau" on screen. Runs the real main scene. Test hook:
## main.section_headings() lists the play area's headings top to bottom as {text, tooltip}.


## Every Control under node.
func controls_in(node: Node) -> Array[Control]:
	var out: Array[Control] = []
	out.assign(node.find_children("*", "Control", true, false))
	return out


## The text the player can read on c: its label, button or log text, and its tooltip.
func texts_of(c: Control) -> Array[String]:
	var out: Array[String] = [c.tooltip_text]
	if c is Label or c is Button or c is LineEdit:
		out.append(c.text)
	elif c is RichTextLabel:
		out.append(c.get_parsed_text())
	return out


## The first Label under node whose text is exactly text, or null.
func label_with_text(node: Node, text: String) -> Label:
	for c in controls_in(node):
		if c is Label and c.text == text:
			return c
	return null


func heading_texts(main: Node) -> Array[String]:
	var out: Array[String] = []
	for h in main.section_headings():
		out.append(h.text)
	return out


# --- AC1: section order ---

func test_realm_frontier_known_and_hand_are_stacked_in_that_order() -> void:
	var main := open_main()
	main.start_game(1)
	var order: Array[String] = []
	for text in heading_texts(main):
		for name in ["Realm", "Frontier", "Known", "Hand"]:
			if text == name or text.begins_with(name + " "):
				order.append(name)
	eq(order, ["Realm", "Frontier", "Known", "Hand"] as Array[String], "section order in %s" % [heading_texts(main)])
	close_main(main)


# --- AC2: Realm ---

func test_the_tableau_section_is_headed_realm_and_the_hand_hint_says_realm() -> void:
	var main := open_main()
	main.start_game(1)
	var texts := heading_texts(main)
	check(texts.has("Realm"), "a Realm heading in %s" % [texts])
	var hand := texts.filter(func(t): return t.begins_with("Hand"))
	check(not hand.is_empty() and hand[0].contains("drag a card into the realm"), "hand hint says realm: %s" % [hand])
	close_main(main)


func test_no_text_on_screen_says_tableau() -> void:
	var main := open_main()
	main.start_game(1)
	var found: Array[String] = []
	for c in controls_in(main):
		for text in texts_of(c):
			if text.to_lower().contains("tableau"):
				found.append("%s: '%s'" % [c.get_class(), text])
	eq(found, [] as Array[String], "UI text mentioning tableau")
	close_main(main)


# --- AC3: Frontier ---

func test_frontier_heading_is_one_word_with_the_explanation_as_its_tooltip() -> void:
	var main := open_main()
	main.start_game(1)
	var frontier := {}
	for h in main.section_headings():
		if h.text.begins_with("Frontier"):
			frontier = h
	eq(frontier.get("text"), "Frontier", "Frontier heading")
	check(str(frontier.get("tooltip")).contains("discovered, not yet settled"), "tooltip: '%s'" % frontier.get("tooltip"))
	close_main(main)


# --- AC4: seed ---

func test_top_bar_shows_no_seed() -> void:
	var main := open_main()
	main.start_game(1)
	var found: Array[String] = []
	for c in controls_in(main):
		if c is Label and c.text.begins_with("Seed ") and c.is_visible_in_tree():
			found.append(c.text)
	eq(found, [] as Array[String], "visible seed labels on the board")
	close_main(main)


func test_menu_seed_field_shows_the_current_seed() -> void:
	var main := open_main()
	main.start_game(4242)
	press_key(main, KEY_ESCAPE)  # nothing focused: opens the menu
	# 063: the hidden start screen has a seed field too, so only the visible ones count.
	var fields := main.find_children("*", "LineEdit", true, false).filter(func(f): return f.is_visible_in_tree())
	check(fields.size() == 1, "the menu's seed field is the one showing")
	eq(fields[0].text if fields.size() == 1 else "", "4242", "seed field")
	close_main(main)


# --- AC5: Buy Cards ---

func test_supply_button_reads_buy_cards_and_s_opens_the_supply_screen() -> void:
	var main := open_main()
	main.start_game(1)
	var labels: Array[String] = []
	for c in controls_in(main):
		if c is Button:
			labels.append(c.text)
	check(labels.has("Buy Cards (S)"), "a Buy Cards (S) button in %s" % [labels])
	check(not labels.has("Supply (S)"), "no Supply (S) button")
	var title := label_with_text(main, "Supply")
	check(title != null and not title.is_visible_in_tree(), "the Supply screen starts closed")
	press_key(main, KEY_S)
	check(title != null and title.is_visible_in_tree(), "S opens the Supply screen")
	press_key(main, KEY_S)
	check(title != null and not title.is_visible_in_tree(), "S closes it again")
	close_main(main)


# --- AC6: Knowledge ---

func test_research_choice_is_titled_knowledge_and_the_researched_row_known() -> void:
	var main := open_main()
	main.start_game(1)
	check(label_with_text(main, "Knowledge") != null, "a Knowledge title")
	check(label_with_text(main, "Research") == null, "no Research title")
	check(heading_texts(main).has("Known"), "a Known heading in %s" % [heading_texts(main)])
	close_main(main)
