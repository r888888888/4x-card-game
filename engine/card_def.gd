class_name CardDef
extends RefCounted
## Immutable card definition, parsed from data/cards.json by DataLoader.

const ACTION := "action"  # one-shot: resolves, then goes to the discard
const BUILDING := "building"  # stays in the tableau on a territory slot
const CITY := "city"  # stays in the tableau; one per territory
const TERRITORY := "territory"  # from the territory deck; holds a city, buildings and pop
const TECH := "tech"  # from the research deck; bought with insight (139), never in the main deck
const EVENT := "event"  # from the event deck; drawn at each turn start from turn 2 (237), active until its discard condition
const CIVILIZATION := "civilization"  # the civilization you play as; in its own zone all game, never in a deck
const GOVERNMENT := "government"  # played from the hand to replace the ruling government, which leaves the game
const UNIT := "unit"  # stays in the tableau, homed on a territory where it uses a worker; stationed somewhere (160)
## A project building's line (286): how it is built.
const PROJECT_TEXT := "Built over turns: up to 1 wealth per pop here each turn."
const TYPES: Array[String] = [ACTION, BUILDING, CITY, TERRITORY, TECH, EVENT, CIVILIZATION, GOVERNMENT, UNIT]
## The prefix of a raid effect's line by trigger (162).
const RAID_WARNING := 2  # event phases between a raid being drawn and striking (257)
const RAID_PREFIXES := {"repel": "If repelled: ", "pillage": "If pillaged: "}
## Each modifier key's noun in card text, [singular, plural] (129).
## Each modifier key's line in card text (129, 109, 110): %d is the amount and %s the plural "s" ("%.0s" drops it,
## since "pop" has no plural); [for a gain, for a loss].
const MODIFIER_TEXT := {
	Modifiers.ACTIONS: ["+%d action%s each turn", "−%d action%s each turn"],
	Modifiers.HAND_SIZE: ["Draw up to %d more card%s each turn", "Draw up to %d fewer card%s each turn"],
	Modifiers.HOUSING: ["Every territory houses %d more pop%.0s", "Every territory houses %d less pop%.0s"],
	Modifiers.UNREST_LIMIT: ["Unrest limit +%d%.0s", "Unrest limit −%d%.0s"],
	Modifiers.RENEWAL: ["Renewal trashes %d more card%s", "Renewal trashes %d fewer card%s"],
	Modifiers.INSIGHT_PER_GAIN: ["Each insight gain +%d%.0s", "Each insight gain −%d%.0s"],
	Modifiers.ADMINISTERS: ["Administration cap +%d%.0s", "Administration cap −%d%.0s"],
}

var id: String = ""
var name: String = ""
var type: String = ""  # one of TYPES
var cost: Dictionary = {}  # resource -> int
var cost_per_territory: Dictionary = {}  # resource -> int added to cost per settled territory (320)
var vp: int = 0
var tags: Array[String] = []
var effects: Array[Effect] = []
var slots: int = 0  # territories: building slots
var housing: int = 0  # territories: most pop the territory can hold; buildings: housing added to their territory
var famine_guard: int = 0  # buildings: pop on their territory saved from starving each upkeep, while working
var strength: int = 0  # units: how much it counts in defence (160)
var defense: int = 0  # buildings and cities: defence added to their territory while working (161)
var upgrade_of := ""  # buildings: the id of the building it is built onto (300), or "" for none
var tier := ""  # buildings: the id of the settlement tier its territory needs (301), or "" for none
var tier_name := ""  # buildings: that tier's name, set by ConfigLoader (CardDef has no config)
var project := false  # buildings: built over turns as a site, its wealth cost paid in bit by bit (286)
var training: int = 0  # buildings: strength added to the units stationed on their territory while working (164)
var actions: int = 0  # governments: actions each turn while it rules (127); 0 sets none (unlimited)
var unrest_limit: int = 0  # governments: most unrest while it rules (144); 0 sets none (no limit)
var tolerates: String = ""  # governments: the id of the largest settlement tier it keeps calm (282); "" for any
var tolerates_name: String = ""  # governments: that tier's name, set by ConfigLoader (CardDef has no config)
var administers: int = 0  # governments: the settled territories it holds calmly (319); 0 sets no cap
var modifiers: Dictionary = {}  # standing modifiers while working or active, {key: non-zero int} (129)
var discounts: Array[Dictionary] = []  # civilizations: [{filter, value, amounts: {resource: int}}] (108)
var keywords: Array[String] = []  # territories: keyword ids from config
var requires: Array[String] = []  # buildings: the territory needs any of these keywords
var era := 1  # techs: the era whose research deck holds this tech (see the add_era op)
var prereq: String = ""  # techs: id of the tech that must be researched first (140)
var eureka: Dictionary = {}  # techs: {card | tag, count, off}: off insight while the tableau holds count matches (141)
var discard_turns := 1  # events: upkeeps the event stays active for
var raid: Dictionary = {}  # events: {strength, targets, pop} when the event is a raid (162), else {}
var choices: Array = []  # events: the options a choice event offers (269), each {cost: {resource: n}, effects: Array[Effect]}
var has_discard := false  # events: the card data sets a discard (the Famine card may not, 083)
var text: String = ""  # optional override; otherwise generated from effects
var flavor: String = ""  # civilizations, governments, techs, events: a line of history, shown in the details
var quote_text: String = ""  # civilizations, governments, techs: a quote shown in the details, with quote_by
var quote_by: String = ""  # civilizations, governments, techs: who said quote_text
var home: String = ""  # civilizations: the territory card id the game starts on, or "" for starting.territory (111)
var city_names: Array[String] = []  # civilizations: the names its settled territories take, in order (248)


func is_permanent() -> bool:
	return type != ACTION


## Whether a played copy uses a worker on its territory (a building, or a unit on its home, 160); an upgrade (300)
## takes none.
func uses_worker() -> bool:
	return (type == BUILDING and upgrade_of == "") or type == UNIT


## Whether it is a building's upgrade (300): built onto a building already in play.
func is_upgrade() -> bool:
	return upgrade_of != ""


## An upgrade's first line (300): "Builds on a Farm."
func upgrade_text(card_db: Dictionary) -> String:
	return "Builds on %s." % Population.with_article(card_db[upgrade_of].name)


## Whether one of the card's effects adds an era of techs (such a tech can't be lost).
func adds_era() -> bool:
	return effects.any(func(e): return e.op == "add_era")


func has_tag(tag: String) -> bool:
	return tags.has(tag)


func effects_for(trigger: String) -> Array[Effect]:
	var out: Array[Effect] = []
	for e in effects:
		if e.trigger == trigger:
			out.append(e)
	return out


## Short card text for the card face. Generated from effects so it always matches the data:
## "⟳" marks upkeep, and a keyword bonus joins the line it adds to ("⟳ +1 food (+1 Flood Plain)").
func rules_text(card_db: Dictionary) -> String:
	if text != "":
		return text
	var parts: PackedStringArray = []
	if is_upgrade():
		parts.append(upgrade_text(card_db))
	if tier_name != "":
		parts.append("Needs %s." % Population.with_article(tier_name))
	if type == UNIT:
		parts.append(strength_text())
	if actions > 0:
		parts.append(actions_text())
	if unrest_limit > 0:
		parts.append(unrest_limit_text())
	if tolerates_name != "":
		parts.append(tolerates_text())
	if administers > 0:
		parts.append(administers_text())
	if home != "":
		parts.append("Starts on: %s" % card_db[home].name)
	if not requires.is_empty():
		parts.append("Needs " + "/".join(PackedStringArray(requires.map(func(k): return k.capitalize()))))
	var prev: Effect = null
	for e in effects:
		if prev != null and e.can_merge_with(prev):
			parts[-1] += " (%s %s)" % [e.bonus_text(), e.keyword.capitalize()]
		else:
			var line := e.describe(card_db)
			if e.trigger == "upkeep":
				line = "⟳ " + line
			elif e.trigger == "start":
				line = "Start: " + line
			elif RAID_PREFIXES.has(e.trigger):
				line = RAID_PREFIXES[e.trigger] + line
			if e.keyword != "":
				line = "%s: %s" % [e.keyword.capitalize(), line]
			parts.append(line)
		prev = e
	if not choices.is_empty():
		parts.append(choices_text(card_db))
	if not cost_per_territory.is_empty():
		parts.append(cost_per_territory_text())
	parts.append_array(modifier_lines(false))
	parts.append_array(discount_lines())
	if type == BUILDING and housing > 0:
		parts.append("+%d housing" % housing)
	if famine_guard > 0:
		parts.append("Saves %d pop from famine" % famine_guard)
	if defense > 0:
		parts.append(defense_text())
	if training > 0:
		parts.append(training_text())
	if project:
		parts.append(PROJECT_TEXT)
	if prereq != "":
		parts.append("Needs %s" % card_db[prereq].name)
	if not eureka.is_empty():
		parts.append(eureka_text(card_db))
	if not raid.is_empty():
		parts.insert(0, raid_face_text())
	elif type == EVENT:
		parts.append(lasts_text())
	return "\n".join(parts)


## Full card text for the hover tooltip: one line per effect, spelled out. For a territory, its
## slots, housing and keywords; for an event, how long it lasts (070). Effects whose op is in skip_ops leave out their
## lines (a tech's details show what it gives on their own, 289).
func rules_tooltip(card_db: Dictionary, skip_ops: Array[String] = []) -> String:
	if text != "":
		return text
	var parts: PackedStringArray = []
	if type == TERRITORY:
		return territory_text(keywords)
	if is_upgrade():
		parts.append(upgrade_text(card_db))
	if tier_name != "":
		parts.append("Needs %s." % Population.with_article(tier_name))
	if type == UNIT:
		parts.append(strength_text())
	if actions > 0:
		parts.append(actions_text())
	if unrest_limit > 0:
		parts.append(unrest_limit_text())
	if tolerates_name != "":
		parts.append(tolerates_text())
	if administers > 0:
		parts.append(administers_text())
	if not requires.is_empty():
		parts.append("Requires " + keyword_names(requires))
	for e in effects:
		if skip_ops.has(e.op):
			continue
		var line := e.describe_long(card_db)
		if e.trigger == "upkeep":
			line = "Each upkeep: " + line
		elif e.trigger == "start":
			line = "When the game starts: " + line
		elif RAID_PREFIXES.has(e.trigger):
			line = RAID_PREFIXES[e.trigger] + line
		if e.keyword != "":
			line += " (on %s)" % e.keyword.capitalize()
		parts.append(line)
	if not choices.is_empty():
		parts.append(choices_text(card_db))
	if not cost_per_territory.is_empty():
		parts.append(cost_per_territory_text())
	parts.append_array(modifier_lines(true))
	parts.append_array(discount_lines())
	if type == CITY and slots > 0:
		parts.append("+%d building slots on its territory" % slots)
	if type == BUILDING and housing > 0:
		parts.append("+%d housing on its territory" % housing)
	if famine_guard > 0:
		parts.append("Each upkeep, %d pop here that would starve survives" % famine_guard)
	if defense > 0:
		parts.append(defense_text() + " on its territory")
	if training > 0:
		parts.append(training_text())
	if project:
		parts.append(PROJECT_TEXT)
	if prereq != "":
		parts.append("Needs %s researched first." % card_db[prereq].name)
	if not eureka.is_empty():
		parts.append(eureka_text(card_db) + ".")
	if not raid.is_empty():
		parts.insert(0, raid_text())
	elif type == EVENT:
		parts.append(lasts_text())
	return "\n".join(parts)


## A choice event's line (269): "Choose: pay 2 wealth for +1 VP; or +1 unrest." An option without effects reads
## "pay 4 wealth", or "nothing" when free (270).
func choices_text(card_db: Dictionary) -> String:
	var options: PackedStringArray = []
	for option in choices:
		var does := _option_effects_text(option, card_db)
		if option.cost.is_empty():
			options.append(does if does != "" else "nothing")
		else:
			var pay := "pay %s" % Fields.amounts_text(option.cost)
			options.append(pay if does == "" else "%s for %s" % [pay, does])
	return "Choose: %s." % "; or ".join(options)


## Option i's text (269): "Pay 2 wealth: +1 VP", "+1 unrest"; "Pay 4 wealth" or "Nothing" without effects (270).
func option_text(i: int, card_db: Dictionary) -> String:
	var option: Dictionary = choices[i]
	var does := _option_effects_text(option, card_db)
	if option.cost.is_empty():
		return does if does != "" else "Nothing"
	var pay := "Pay %s" % Fields.amounts_text(option.cost)
	return pay if does == "" else "%s: %s" % [pay, does]


func _option_effects_text(option: Dictionary, card_db: Dictionary) -> String:
	return ", ".join(PackedStringArray(option.effects.map(func(e: Effect): return e.describe(card_db))))


## A tech's eureka line (141): "Eureka: -2 insight with 2 Farms", "Eureka: -2 insight with 2 city cards"; "" without.
func eureka_text(card_db: Dictionary) -> String:
	if eureka.is_empty():
		return ""
	var plural := "" if eureka.count == 1 else "s"
	var what: String = card_db[eureka.card].name + plural if eureka.has("card") else "%s card%s" % [eureka.tag, plural]
	return "Eureka: -%d insight with %d %s" % [eureka.off, eureka.count, what]


## A unit's strength line (160): "Strength 2".
func strength_text() -> String:
	return "Strength %d" % strength


## A raid's line on the card face (162): "Raid 3 (mountain/hills)", or "Raid 3" without targets.
func raid_face_text() -> String:
	if raid.targets.is_empty():
		return "Raid %d" % raid.strength
	return "Raid %d (%s)" % [raid.strength, "/".join(PackedStringArray(raid.targets.map(func(k): return k.replace("_", " "))))]


## A raid's tooltip line (162, 257): "Raid 3: strikes your least defended mountain or hills territory 2 turns after it is
## drawn" (any territory
## without targets).
func raid_text() -> String:
	var names: PackedStringArray = []
	for k in raid.targets:
		names.append(k.replace("_", " "))
	var where := " or ".join(names) + " territory" if not names.is_empty() else "territory"
	return "Raid %d: strikes your least defended %s %d turns after it is drawn" % [raid.strength, where, RAID_WARNING]


## A building's or city's defence line (161): "Defence 2".
func defense_text() -> String:
	return "Defence %d" % defense


## A building's training line (164): "Units here have +1 strength".
func training_text() -> String:
	return "Units here have +%d strength" % training


## A government's actions line (127): "2 actions each turn."
func actions_text() -> String:
	return "%d action%s each turn." % [actions, "" if actions == 1 else "s"]


## A government's unrest limit line (144): "Unrest limit 5."
func unrest_limit_text() -> String:
	return "Unrest limit %d." % unrest_limit


## A government's tolerated tier line (282): "Tolerates up to Village."
func tolerates_text() -> String:
	return "Tolerates up to %s." % tolerates_name


## A government's administration line (319): "Administers up to 3 territories."
func administers_text() -> String:
	return "Administers up to %d territor%s." % [administers, "y" if administers == 1 else "ies"]


## The cost step line (320): "Costs 1 more food for each territory you hold."
func cost_per_territory_text() -> String:
	var steps := PackedStringArray()
	for r in cost_per_territory:
		steps.append("%d more %s" % [cost_per_territory[r], r])
	return "Costs %s for each territory you hold." % " and ".join(steps)


## One line per modifier (129): "+1 action each turn"; long (the tooltip) adds " while active" on an event.
func modifier_lines(long: bool) -> PackedStringArray:
	var out: PackedStringArray = []
	for key in modifiers:
		var n: int = modifiers[key]
		var line: String = MODIFIER_TEXT[key][0 if n > 0 else 1] % [absi(n), "" if absi(n) == 1 else "s"]
		out.append(line + (" while active" if long and type == EVENT else ""))
	return out


## One line per discount (108): "Techs cost 1 less wealth.", "Wonders cost 3 less wealth.", "Supply cards cost …".
func discount_lines() -> PackedStringArray:
	var out: PackedStringArray = []
	for d in discounts:
		var subject: String = "Supply cards"
		if d.filter == "type":
			subject = "Cities" if d.value == CITY else d.value.capitalize() + "s"
		elif d.filter == "tag":
			subject = d.value.capitalize() + "s"
		var amounts: PackedStringArray = []
		for r in d.amounts:
			amounts.append("%d less %s" % [d.amounts[r], r])
		out.append("%s cost %s." % [subject, ", ".join(amounts)])
	return out


## A territory's tooltip for a copy with these keywords (printed, plus any rolled resources).
func territory_text(copy_keywords: Array[String]) -> String:
	var parts: PackedStringArray = ["%d building slot%s, holds up to %d pop" % [slots, "" if slots == 1 else "s", housing]]
	if not copy_keywords.is_empty():
		parts.append("Keywords: " + ", ".join(PackedStringArray(copy_keywords.map(func(k): return k.capitalize()))))
	return "\n".join(parts)


## How long an event stays active: "Lasts 1 turn" / "Lasts 2 turns".
func lasts_text() -> String:
	return "Lasts %d turn%s" % [discard_turns, "" if discard_turns == 1 else "s"]


## Keyword ids for display, joined by " or " ("fresh_water" -> "Fresh Water").
static func keyword_names(ids: Array[String]) -> String:
	var names: PackedStringArray = []
	for k in ids:
		names.append(k.capitalize())
	return " or ".join(names)
