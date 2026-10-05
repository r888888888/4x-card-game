class_name EventSounds
extends Node
## The game's event sounds (191, guide §11.3, §11.6, §16.4): the engine's milestones and raid strikes (271) over one
## action, played as the action's change reaches the board, only the highest of them (an era over a raid over a city
## over a tech). Level 3, on the Game
## bus; the routine sounds of the same action give way to it (Sfx). A Node under main, listening while it is in the tree.

## Milestone kinds and raid outcomes, highest first, and their sounds.
const PILLAGED := &"pillaged"
const REPELLED := &"repelled"
const SOUNDS := [
	[GameEngine.MILESTONE_ERA, Sfx.MILESTONE_ERA],
	[PILLAGED, Sfx.MILESTONE_PILLAGED],
	[REPELLED, Sfx.MILESTONE_REPELLED],
	[GameEngine.MILESTONE_CITY, Sfx.MILESTONE_CITY],
	[GameEngine.MILESTONE_TECH, Sfx.MILESTONE_BREAKTHROUGH],
]

var _engine: GameEngine
var _sfx: Sfx
var _kinds: Array[StringName] = []  # the milestones heard since the last change


## Plays engine's milestones on sfx.
func _init(engine: GameEngine, sfx: Sfx) -> void:
	_engine = engine
	_sfx = sfx


func _enter_tree() -> void:
	_engine.milestone.connect(_heard)
	_engine.raid_resolved.connect(_raided)
	_engine.changed.connect(_play)


func _exit_tree() -> void:
	_engine.milestone.disconnect(_heard)
	_engine.raid_resolved.disconnect(_raided)
	_engine.changed.disconnect(_play)


func _heard(kind: StringName) -> void:
	_kinds.append(kind)


func _raided(outcome: Dictionary) -> void:
	_kinds.append(REPELLED if outcome.repelled else PILLAGED)


func _play() -> void:
	for pair in SOUNDS:
		if _kinds.has(pair[0]):
			_sfx.play(pair[1])
			break
	_kinds.clear()
