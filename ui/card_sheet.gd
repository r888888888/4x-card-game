class_name CardSheet
extends Container
## A hand-size face below its art plate (383): the text sheet holding the type line, ledger, rules (RulesCut), the foot
## (Over), fine print and VP. The card keeps its size: rules that don't fit are hidden whole and the
## foot counts them ("+N more"; on a hand-row card also "details I"), with a meter along its dashed rule. The sheet can
## rise over the plate just above it (rise, at most cap()) without taking room from anything, on paper with a 1 px ink rule drawn
## at its top; its cut is made for where it is going (target), so a sliding sheet never shows a part of a rule.

const METER := 2.0  # px: the meter's bar over the foot's dashed rule
const DASH := 4.0

var art: Control  # the plate above, which the sheet rises over
var sheet: PanelContainer  # the paper the text sits on
var body: VBoxContainer  # the sheet's content
var rules: RulesCut  # null on a face with no rules
var over: HBoxContainer  # the foot, or null
var rise := 0.0  # px the sheet is up over the plate now
var target := 0.0  # px it is going to
var meter := 0.0  # the foot's meter, 0 to 1

var _paper: SurfaceBox
var _count: Label
var _keys: Array[Label] = []
var _cutting := false


func _init(plate: Control) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	art = plate
	sheet = PanelContainer.new()
	sheet.name = "Sheet"
	sheet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var frame := StyleBoxFlat.new()
	frame.bg_color = Palette.RAISED
	_paper = Surfaces.box(Surfaces.PAPER, frame)
	sheet.add_theme_stylebox_override("panel", StyleBoxEmpty.new())  # at rest it is the card's own paper
	sheet.draw.connect(_draw_top_rule)
	add_child(sheet)
	body = VBoxContainer.new()
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_theme_constant_override("separation", Tokens.SPACE_2)
	sheet.add_child(body)


## Adds the rules (one per line) and the foot under them to the sheet.
func add_rules(lines: PackedStringArray) -> void:
	rules = RulesCut.new(lines)
	rules.resized.connect(recut)
	body.add_child(rules)
	over = HBoxContainer.new()
	over.name = "Over"
	over.mouse_filter = Control.MOUSE_FILTER_IGNORE
	over.add_theme_constant_override("separation", Tokens.SPACE_1)
	over.visible = false
	over.draw.connect(_draw_foot)
	_count = _foot_label("", &"OverCount")
	_count.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_keys = [_foot_label("details", &"OverCount"), _foot_label("I", &"OverKey")]
	for key in _keys:
		key.visible = false
	body.add_child(over)


## Shows "details I" in the foot (a hand-row card) or not.
func show_keys(on: bool) -> void:
	for key in _keys:
		key.visible = on


## The most the sheet can rise: the plate and its gap.
func cap() -> float:
	return art.get_combined_minimum_size().y + Tokens.SPACE_2


## How far the sheet must rise to show every rule, at most cap(); 0 when they all fit at rest.
func need() -> float:
	if rules == null:
		return 0.0
	return clampf(rules.needed() - (_room() - rise), 0.0, cap())


## The rules (or sentences) hidden now, 0 with no foot shown.
func hidden_rules() -> int:
	return rules.left_out if rules != null and over.visible else 0


## Cuts the rules for a sheet at to px up (it is on its way there).
func set_target(to: float) -> void:
	target = to
	recut()
	_lay_out()


## Moves the sheet to px up now, laid out at once.
func set_rise(px: float) -> void:
	rise = px
	sheet.add_theme_stylebox_override("panel", _paper if rise > 0.0 else StyleBoxEmpty.new())
	_lay_out()
	sheet.queue_redraw()


func set_meter(value: float) -> void:
	meter = value
	if over != null:
		over.queue_redraw()


## Greys the sheet's paper with its card.
func set_dimmed(on: bool) -> void:
	_paper.texture = Surfaces.texture(Surfaces.DIMMED_PAPER if on else Surfaces.PAPER)


## Shows the whole rules that fit where the sheet is going, and the foot when some don't.
func recut() -> void:
	if _cutting or rules == null or rules.size.x <= 0.0:
		return
	_cutting = true
	var room := _room() + target - rise
	var was := over.visible
	over.visible = rules.needed() > room + 0.5
	if over.visible:
		_count.text = "+%d more" % rules.fit(room - over.get_combined_minimum_size().y - _gap())
	else:
		rules.fit(room)
	_cutting = false
	if over.visible != was:
		_lay_out()


## The room the rules and the foot share now.
func _room() -> float:
	var foot := over.get_combined_minimum_size().y + _gap() if over.visible else 0.0
	return rules.size.y + foot


func _gap() -> float:
	return body.get_theme_constant("separation")


## Lays the sheet out now rather than at the end of the frame, without cutting again.
func _lay_out() -> void:
	var cutting := _cutting
	_cutting = true
	for container: Container in [self, sheet, body]:
		container.notification(Container.NOTIFICATION_SORT_CHILDREN)
	_cutting = cutting


func _get_minimum_size() -> Vector2:
	return sheet.get_combined_minimum_size()


func _notification(what: int) -> void:
	if what == NOTIFICATION_SORT_CHILDREN:
		fit_child_in_rect(sheet, Rect2(0, -rise, size.x, size.y + rise))  # up over the plate, drawn after it


func _foot_label(text: String, look: StringName) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = look
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	over.add_child(label)
	return label


func _draw_top_rule() -> void:
	if rise > 0.0:
		sheet.draw_line(Vector2.ZERO, Vector2(sheet.size.x, 0), Palette.TEXT, 1.0)


## The foot's dashed rule along its top, with the meter's bar filling it from the left.
func _draw_foot() -> void:
	over.draw_dashed_line(Vector2.ZERO, Vector2(over.size.x, 0), Palette.HAIRLINE, 1.0, DASH)
	if meter > 0.0:
		over.draw_rect(Rect2(0, -METER / 2, over.size.x * meter, METER), Palette.TEXT)
