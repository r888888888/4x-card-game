class_name Sfx
extends Node
## The sound player (186). Stub for the red phase.

const BUTTON_PRESS := &"ui.button.press"
const BUTTON_RELEASE := &"ui.button.release"
const TOGGLE_ON := &"ui.toggle.on"
const TOGGLE_OFF := &"ui.toggle.off"
const SELECTION := &"ui.selection"
const CARD_LIFT := &"ui.card.lift"
const CARD_PLACE := &"ui.card.place"
const COUNTER_TICK := &"ui.counter.tick"
const FLAP := &"ui.flap"
const RESOURCE_GAIN := &"ui.resource.gain"
const RESOURCE_LOSS := &"ui.resource.loss"
const REJECT_LOCKED := &"ui.reject.locked"
const PANEL_OPEN := &"ui.panel.open"
const PANEL_CLOSE := &"ui.panel.close"
const SHEET_OPEN := &"ui.sheet.open"
const SHEET_CLOSE := &"ui.sheet.close"
const NAV_FORWARD := &"ui.nav.forward"
const NAV_BACK := &"ui.nav.back"
const CABINET_CLOSE := &"ui.cabinet.close"
const CABINET_PART := &"ui.cabinet.part"
const PILE_DEAL := &"ui.pile.deal"
const PILE_GATHER := &"ui.pile.gather"
const CONFIRM := &"ui.confirm"
const REJECT := &"ui.reject"
const NOTIFICATION_INFO := &"ui.notification.info"
const NOTIFICATION_CAUTION := &"ui.notification.caution"
const NOTIFICATION_URGENT := &"ui.notification.urgent"
const ENDTURN_PRESS := &"ui.endturn.press"
const ENDTURN_COMMIT := &"ui.endturn.commit"
const ENDTURN_TURN := &"ui.endturn.turn"
const MILESTONE := &"ui.milestone"
const MILESTONE_BREAKTHROUGH := &"ui.milestone.breakthrough"
const MILESTONE_CITY := &"ui.milestone.city"
const MILESTONE_WONDER := &"ui.milestone.wonder"
const MILESTONE_ACCORD := &"ui.milestone.accord"
const MILESTONE_ERA := &"ui.milestone.era"
const MILESTONE_VICTORY := &"ui.milestone.victory"
const MILESTONE_DEFEAT := &"ui.milestone.defeat"
const TOKENS := {}


static func level(_token: StringName) -> int:
	return 0


static func bus(_token: StringName) -> StringName:
	return &""


static func files(_token: StringName) -> Array:
	return []


static func stream(_token: StringName) -> AudioStream:
	return null


static func length(_token: StringName) -> float:
	return 0.0


static func lead(_token: StringName) -> float:
	return -1.0


func set_clock(_seconds: float) -> void:
	pass


func clock() -> float:
	return -1.0


func play(_token: StringName, _delay := 0.0, _input := false, _gain_db := 0.0) -> bool:
	return false


func at_contact(_token: StringName, _duration: float, _curve: Vector4, _input := false) -> bool:
	return false


func played() -> Array[Dictionary]:
	return []


func playing(_bus: StringName) -> Array[StringName]:
	return []
