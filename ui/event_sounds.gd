class_name EventSounds
extends Node
## The game's event sounds (191, guide §11.3, §11.6, §16.4): the engine's milestones, raid strikes (271) and builds
## (357) over one action, played as the action's change reaches the board, only the highest of them (an era over a raid
## over a city over a tech over a build; a build's a beat later, with its ceremony). Level 3, on the Game
## bus; the routine sounds of the same action give way to it (Sfx). A Node under main, listening while it is in the tree.

## Milestone kinds, raid outcomes and builds, highest first, and their sounds.
const PILLAGED := &"pillaged"
const REPELLED := &"repelled"
const BUILT := &"built"  # a building or an upgrade built (357)
const RECRUITED := &"recruited"  # a unit recruited (357)
const SOUNDS := [
	[GameEngine.MILESTONE_ERA, Sfx.MILESTONE_ERA],
	[PILLAGED, Sfx.MILESTONE_PILLAGED],
	[REPELLED, Sfx.MILESTONE_REPELLED],
	[GameEngine.MILESTONE_CITY, Sfx.MILESTONE_CITY],
	[GameEngine.MILESTONE_TECH, Sfx.MILESTONE_BREAKTHROUGH],
	[BUILT, Sfx.MILESTONE_BUILD],
	[RECRUITED, Sfx.MILESTONE_RECRUIT],
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
	_engine.built.connect(_built)
	_engine.changed.connect(_play)


func _exit_tree() -> void:
	_engine.milestone.disconnect(_heard)
	_engine.raid_resolved.disconnect(_raided)
	_engine.built.disconnect(_built)
	_engine.changed.disconnect(_play)


func _heard(kind: StringName) -> void:
	_kinds.append(kind)


func _raided(outcome: Dictionary) -> void:
	_kinds.append(REPELLED if outcome.repelled else PILLAGED)


func _built(uid: int) -> void:
	_kinds.append(RECRUITED if _engine.zone("tableau").find(uid).def.type == CardDef.UNIT else BUILT)


func _play() -> void:
	for pair in SOUNDS:
		if _kinds.has(pair[0]):  # a build's sound comes with its ceremony, once the Build sheet has closed (357)
			var late: bool = pair[0] in [BUILT, RECRUITED] and not UIKit.calm()
			_sfx.play(pair[1], Anim.BUILD_DELAY if late else 0.0)
			break
	_kinds.clear()
