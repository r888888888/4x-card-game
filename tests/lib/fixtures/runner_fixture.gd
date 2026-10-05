extends RefCounted
## A test file for the runner's method selection (284). It lives under tests/lib/, which the runner never scans,
## so its test_helper doesn't fail the real suite. Nothing here is ever called.


func test_plain() -> void:
	pass


func test_helper(_id: String) -> Dictionary:
	return {}


func helper(_id: String) -> void:
	pass


func plain() -> void:
	pass
