extends Effect
## { "op": "add_era", "era": 2 }
## Shuffles the techs of that era into the research deck. Works once per era: a later copy does nothing.

var era: int


func fields() -> Array[String]:
	return ["era"]


func configure(data: Dictionary, _ctx: Dictionary, errors: Array[String]) -> void:
	era = Fields.read_int(data, "era", errors, 2)


func apply(engine: GameEngine, source: CardInstance) -> void:
	engine.add_era(era, source)



func terms() -> Array[String]:
	var out := super()
	out.append_array(["Era"])
	return out

func describe(_card_db: Dictionary) -> String:
	return "Adds era %d techs" % era
