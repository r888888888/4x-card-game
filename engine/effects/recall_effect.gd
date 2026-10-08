extends Effect
## { "op": "recall" }
## Takes a card from the discard pile into the hand (370): several cards are a take decision (GameEngine.take), one
## goes to the hand at once. Can't be played with an empty discard. The card being played is never one of them.


func apply(engine: GameEngine, source: CardInstance) -> void:
	engine.recall(source)


func opens_choice() -> bool:
	return true


func play_block_error(engine: GameEngine, _card: CardInstance) -> String:
	if engine.zone("discard").is_empty():
		return "There is no card in your discard pile to take back."
	return ""


func describe(_card_db: Dictionary) -> String:
	return "Take a card from your discard pile into your hand"
