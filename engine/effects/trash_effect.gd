extends Effect
## { "op": "trash" }
## Removes the target card in hand from the game (to the trashed zone). The card being played is never a target.


func apply(engine: GameEngine, source: CardInstance) -> void:
	engine.trash(engine.play_target, source)


func describe(_card_db: Dictionary) -> String:
	return "Remove a card in hand from the game"


func target_zone() -> String:
	return "hand"


func no_target_error() -> String:
	return "There is no other card in hand to trash."


func choose_target_error() -> String:
	return "Choose a card to trash."
