extends RefCounted
## Watches the player's user://settings.cfg across a test run (196). user:// is shared by every checkout and the game,
## so a change may be the player's game saving a setting: the runner warns rather than failing.

const PLAYER_SETTINGS := "user://settings.cfg"


## A warning when the player's settings changed between before and after (the file's bytes, or null for no file),
## else "".
static func settings_change_warning(before: Variant, after: Variant) -> String:
	if before == after:
		return ""
	return "%s changed during the run: a test wrote it (tests must use a temp settings store) or a running game saved a setting" % PLAYER_SETTINGS
