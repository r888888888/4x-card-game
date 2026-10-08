# Build order of closed items

The README's "Planned order" as it stood when the backlog was archived into this folder. Kept for
the sequencing rationale; items 142 and up were still open then and are listed in the README now.

Build in this order; IDs are creation order, not build order. Each item assumes the ones before it are done.

1. 044 repo housekeeping
2. 040 reshuffle test bug
3. 041 shared test helpers, content invariants
4. 042 balance simulator
5. 045 UI smoke test
6. 043 only forecast-safe ops on upkeep
7. 046 table-driven loader tests
8. 047 field readers and constants
9. 048 `create` zones, `changed` once
10. 049 engine queries for UI rules
11. 050 pending-decision model
12. 051 GameState split
13. 039 event deck (after 051: uses the type schema, the upkeep guard and the forecast on a copy)
14. 068 event panel (uses 039)
15. 069 starter event deck (uses 039, 068)
16. 052 split `ui/main.gd`
17. 053 board tidy (Realm, Buy Cards, Knowledge wording, seed in menu)
18. 067 Exit button in the menu (after 053, which also edits the menu)
19. 075 Frontier and Known rows keep their height
20. 076 buildings cost mostly wealth
21. 054 fresh-water start, Farm needs Fresh Water
22. 055 Caravan `trade` op
23. 056 card details modal (the tech tree reuses it)
24. 057 locked supply piles, `unlock` op
25. 058 Stone/Bronze Age tech content (uses 057)
26. 059 tech tree modal (after 058's content, uses 056)
27. 060 Granary famine guard
28. ~~061 weighted explore~~ (wontfix)
29. 062 civilization cards
30. 085 script size limits
31. 086 split `ui/card_view.gd` (after 085)
32. 063 start screen
33. 064 choose civilization (uses 062, 063)
34. 065 government cards (content from 058's techs)
35. 080 five early-game cards (data only)
36. 081 `gain_per_keyword` op, Hunt
37. 082 `trash` op, Winnow
38. 078 wide territory row pushes the side panel off screen (bug: End turn goes off screen in longer games)
39. 088 civilization and government as side-panel lines (fixes End turn off screen at 1080p since 065)
40. 087 collapse territory groups (after 078: both rework `TerritoryGroup` in `ui/tableau_view.gd`)
41. ~~089 unique cards have no supply pile~~ (wontfix)
42. 072 harmful event ops (`lose`, `lose_pop`)
43. 083 Famine replaces starvation (uses 072, 060; the first harm players feel)
44. 090 upkeep-rule rationale, add-effect skill, review rules in CLAUDE.md (docs first: the items below follow them)
45. 091 shared test helpers, one test per Famine behavior (test infrastructure before the items that add tests)
46. 092 research card name from the engine, content tests as invariants (uses 091's helpers)
47. 093 error queries for `choose`, `decline_research`, `discard_card` (logic out of the UI, before engine restructuring)
48. 094 engine queries for the UI's targeting choice, tech eras, open supply piles (same reason as 093)
49. 095 split `ConfigLoader` out of `DataLoader` (677/700 lines; before 084 and 074, which add config)
50. 096 Famine module (before 084, which adds Famine rules)
51. 084 relieve a Famine with wealth (after 095 and 096: its rules and config land in the new files)
52. 074 event decks escalate by era (uses 072; after 095: adds config)
53. 070 event tooltip says how long it lasts (before 079, whose modal shows the event text)
54. 079 modal when a new event is drawn (after 072, so its summary covers losses as well as gains)
55. 071 icons for the tech and event type marks
56. 077 Market earns wealth per city (data only; just before the balance pass)
57. 066 100-turn games, balance pass (last: everything above changes balance)
58. 103 navigation stack for screens (done; before 101, which pushes the territory view on it)
59. 101 territory view (click a territory: its city, buildings and Grow in place of the Realm)
60. 102 territories as plain cards in the Realm (after 101, which gives the buildings somewhere to show)
61. 106 theme cleanup: one palette, theme type variations (the in-house alternative to 097; before 104 and 105,
    which add colours)
62. 104 screen header and transitions for navigated screens (the pattern; after 103)
63. 105 territory view layout (uses 104's header)
64. 107 ancient civilizations: Egypt, Sumer, Phoenicia, Babylon, Greece, Persia (content only, existing ops)
65. 112 drop the basic terms (Upkeep, Slots, Pop) from card details
66. 113 capital slots +4 → +3 (balance; revisit after 111)
67. 125 split effect hooks and internals out of `GameEngine` (694/700 lines; before everything below, which adds
    engine queries)
68. 127 actions per turn: playing a hand card uses 1; the government sets the count (Chiefdom 2, Kingship and
    Theocracy 3)
69. 128 `gain_actions` op: Scout and Barter give +1 action (after 127)
70. 129 standing `modifiers` on permanent cards, first key `actions` (after 127)
71. 108 civilization discounts (Babylon techs, Phoenicia supply, Egypt wonders; after 107 and 125)
72. 109 hand size as a `modifiers` key (Greece; after 129)
73. 110 housing as a `modifiers` key (Sumer; after 129)
74. 111 civilization home territory (after 107; last, since it shifts every civ's start)
75. Balance pass for the action economy (to spec: 127–129 shift the game from resources to tempo)
76. 139 Insight resource: techs cost Insight (research redesign, from `spike/research-insight`)
77. 140 open tech tree: learn any tech whose prereq you have; reveal-2 and passes go (after 139)
78. 141 eurekas (after 140)
79. 142 diffusion: earlier-era techs get cheaper (after 140; independent of 141)
80. 143 Iron Age techs in the deck, research pacing (after 139–142)
81. 144 Unrest resource, government unrest limit (after 139: both add a top-bar counter; from `spike/unrest`)
82. 145 Anarchy at the unrest limit (after 144; once-per-era pacing assumes 143)
83. 146 leaving Anarchy: half-limit government, restore order (after 145)
84. 147 renewal: trash from the discard during Anarchy (after 146)
85. 148 revolution events: choose to revolt (after 147)
86. 154 government deck: choose your next government instead of drawing it (after 148)
87. 169 docs, skills and the review scan in line with the code (project review cleanup, 2026-10-01)
88. 170 shared test fixtures, engines typed `GameEngine` in tests
89. 171 guard tests for state copies and the pending-decision block
90. 172 one pending-decision model (`GameState.pending`)
91. 173 one way to check and pay a price, and to add unrest
92. 174 prerequisite cycles a load error; the renewal modifier key on `Modifiers`
93. 175 the last small rules leave the UI; one action-button class
94. 176 split `main.gd` (`BoardViews`, `BoardLayout`)
95. 155 revolt any time; Anarchy's length follows unrest (governments no longer played from hand)
96. 157 Theocracy slows research: an insight-per-gain modifier
97. 156 Anarchy eats into stored food and wealth
98. 159 the bot chooses governments and revolts by looking ahead (with the balance suite, `scripts/test.sh --balance`)
99. 158 sim metrics for Anarchy, governments and famine
100. 177 counters found by name in tests (mid-century restyle, from `spike/mcm-godot`)
101. 178 Night shift palette, typefaces and machined controls
102. 179 index-card faces and machined card motion
103. 180 resource glyphs and glyph costs (`play_shortfall`)
104. 182 the legend key for Reduce motion
105. 181 odometer counters and +N tags
106. 183 Day mode: the Paper palette, switched at once
107. 192 Palette roles can't be misspelt or frozen (design-system review, for LLM use)
108. 193 spacing and corner radius from the guide's scales (`Tokens`)
109. 195 Day mode saved at launch; the suite runs on a fresh settings store
110. 194 text sizes from the guide's type scale (`Tokens.TYPE_*`, theme variations)
111. 184 sound buses and volume settings
112. 185 sound rows in Settings and the game menu
113. 186 the sound player (`Sfx`), its tokens and placeholder sounds (`docs/design/tools/sound-export.html`)
114. 187 key sounds: buttons, the legend key and End turn
115. 188 counter and card sounds
116. 189 sheet, screen and notice sounds
117. 190 notice priorities, heard as a pattern and seen as a hue bar
118. 191 event sounds for techs, cities, eras and the end of the game (`milestone`)
119. 197 Day-mode card type and keyword lines in `TEXT_DIM`
120. 198 card names in bold (`CardTitle`)
121. 199 settled Realm territory cards without keywords
122. 200 a click outside the territory box closes the view
123. 207 modals as drafting sheets (title block, footer, rise and drop); the menu and game over on the stack
124. 202 the civilization and government in a right sidebar
125. 204 the In Hand heading with the actions count on its line
126. 209 the government choice behind cabinet doors
127. 210 targeting under vellum, the targets lifted above it
128. 211 the era ceremony: a sheet, rings and the era's name
129. 212 the new game screen as a civilization list and a detail pane
130. 213 the title screen as a ledger with large-format keys
131. 206 a Settings modal, from the menu and the title screen
132. 205 Revolt from the civilization modal, after a confirmation
133. 203 End turn as the specimen's key at the sidebar's foot
134. 201 the resource strip: a turn plate, figures and their forecasts
135. 208 Knowledge as a screen of era rows, slid in on its rail
136. 214 the title screen's sun over a hill

Not scheduled: 073 event discard conditions (draft: a behavior question is still open).

## Planned order through 367 (closed by 2026-10-07)

The README's next "Planned order", kept for its sequencing rationale. Every item in it is done, or wontfix where
struck through.

Barbarians and military (units are homed on a territory, using a worker there, and stationed where they defend):
1. 160 unit cards garrisoned on a home territory
2. 161 territory defence from units, walls, cities and terrain
3. 162 barbarian raids, announced a turn ahead
4. 163 move and disband units
5. ~~168 the sim bot meets raids~~: superseded by 314 (the generic bot defends through its value)
6. 164 Barracks training, then 165 veterans, then 166 upgrades
7. 167 era units and era 2–3 raids


Settlement tiers (pop sets a territory's tier, which adds slots; governments tolerate tiers up to one):
1. 281 settlement tiers add building slots, and buildings past the slots go idle
2. 282 governments tolerate territories up to a tier; bigger ones add unrest
3. 283 growth "where needed most" prefers a territory one pop short of its next tier

Build menu (buildings and units leave the deck: techs unlock them, you build them onto a territory):
1. 295 buildings are built from a build menu instead of bought
2. 296 units are recruited from the build menu
3. 299 preview what building an entry on a territory would change
4. 297 Build… on a territory's view: the list-and-forecast modal, and "+ Build" on empty slots
5. ~~298 the sim bot builds, recruits and keeps Settlers~~: superseded by 314 (`build` joins `legal_actions`); then a
   balance item for costs and wealth

Building upgrades (upgrades build onto a building, add to it, and may need a settlement tier; makes tall worth it):
1. 300 upgrades built onto buildings: no slot or worker, they add to their base, stack and chain
2. 301 a building or upgrade may need a tier, and falls back below it (returns by itself)
3. 304 the `gain_per_pop` op (independent; needed by 306)
4. 302 ribbons on the territory view, "+ Upgrade", the Build modal's Upgrades heading (after 297)
5. ~~303 the sim bot builds upgrades~~: superseded by 314
6. 305 rural upgrades and realism fixes, 306 Temple and Library become urban upgrades, 307 new urban chains, 308 gap
   buildings (then a balance item for the whole roster)

Generic sim bot (from `spike/generic-bot`: one value function over every legal action instead of a rule per mechanic):
1. 309 `turn_forecast`, 310 targets from any zone, 311 sample fork (independent engine queries)
2. 312 `legal_actions` with a coverage check
3. 313 `GenericBot` plays as the strategy `generic`
4. 314 it replaces ScriptedBot (generic, wide, tall; rollouts in cheap mode; raids), closing 168, 298 and 303
5. 315 forecast cache (then a balance item re-baselines the sim)

Project review cleanup (2026-10-06 review; build before the military items 165–167 below unless gameplay comes first):
1. 330 docs and housekeeping: PLAN.md and timings brought up to date, the bench file and orphan `.uid` files gone, a
   check that docs name only real paths (first, so later items have less to keep in sync)
2. 331 test files' headers become the source; `docs/testing.md` keeps one line per file (docs, before items add files)
3. 332 bug: the upkeep forecast after a declared revolution (the one player-visible finding, with its missing test)
4. 333 red-phase scaffolding out of the tests, checked (cleans the tests before others are added beside them)
5. 334 shared UI test helpers, `click` split (test infrastructure before items that add UI tests)
6. 335 the suite's critical path: the cache tests share their games, slow files dealt first (compacts the tests 336
   changes)
7. 336 the engine says what a forecast reads; the bot's cache key uses it (a guard before 165 adds unit state)
8. 337 the engine writes the era's "Opens at…" and one shortfall message (logic out of the UI)
9. 340 loader tests as tables: the last one-off rejections and the "loads / defaults to" tests as `check_loads` rows
   (compacts the loader tests before 338 and 339 refactor the loaders; uses 334's shared helpers)
10. 338 DataLoader's per-type fields from one table, `requires` building-only, the `add-card-field` skill (before 166
   adds `upgrades_to`)
11. 339 ConfigLoader split (config_loader.gd is at 680 of 700; before 167 adds content config)

Barbarians and military, continued: 165 veterans, 166 unit upgrades, 167 era units and raids (see the first list).

Coastal cities (fishing stops being a worse Farm, and the coast adds to a territory instead of replacing it):
1. 364 Fishing Huts cost no food and house people; each adds a Net Fishing; Salt Pans (Pottery); Harbor +1 food
2. 365 helpful era-1 coastal events and the Lighthouse of Pharos (content only)
3. 367 `gain_per_tag` learns `per`; Sea Trade (Sailing) and Sailing's insight per 2 ports
4. 366 the sea slot: one extra slot on coastal territories for port buildings (after 339, which makes room in
   `config_loader.gd`)
5. Then a balance item for the coast (per-port payoffs stack: Navigation, the Lighthouse, Sea Trade, the sea slot)

## Planned order through 412 (closed by 2026-10-08)

Order chosen to minimize churn: finish what has red tests, then the three refactors that every later item would
otherwise write against the old shape and then rewrite, then the features in the order their shared pieces appear.

Finish first (red tests already written; 392 renames their calls when it lands):
1. 324 day-mode load-error text (`fix/324-day-mode-load-error-text`, red-review)
2. 384 Interregnum: Anarchy lasts a fixed 3 turns (`feat/384-simpler-anarchy`; redesigned 2026-10-07, so its red
   tests are rewritten before the next red-review)

Refactors (before the features, which would add to what they move):
3. 392 main.gd's test hooks move to a test-side probe. First: 379's red tests already add three hooks to main
   (`breakdown_key`, `breakdown_rows`, `counter`), and every UI item below adds more.
4. 393 GameTheme split into one file per component. Before 379 (the Popover look), 382 (Ledger, FinePrint), 383 (the
   sheet and meter) and 388 (pips) add looks to `game_theme.gd`, already past 500 lines.
5. 394 engine areas, military first. Before 388 adds `unit_veteran_pips` to `Military` (a forward 394 would remove),
   before 400 changes `Military.strength`, and before 385 and 401 add entries to `legal_actions`, whose dispatch 394
   changes.

Anarchy (builds on 384 while its code is fresh):
6. 385 Renewal is a free action during Anarchy (flat count, no unrest)
7. 399 a new government's honeymoon: 3 turns where unrest can't rise and no revolution

Top bar (379 brings the `Popover` that 380 and 383 reuse):
8. 379 click a resource counter for its next-upkeep change by source (`feat/379-resource-breakdown-popover` has its red
   tests; move their main calls to the probe)
9. 380 click Score or Pop for what makes it up

Sim speed (from the 2026-10-08 profile; before the food rebalance, whose balance runs it speeds up):
10. 408 the fallen-back cards in one pass, so `score()` stops dominating bot time (measured −13.5% from one line,
    30–40% expected in all)
11. 409 forecasts fork only the zones they can change (wontfix 2026-10-08: measured ~3–4% of sim time; see its Log)

Card faces and details:
12. 382 one Unlocks line, a ledger of figures and gates as fine print (changes `rules_text` and `upgrade_rules_text`)
13. 383 overflowing text cuts at a whole rule, hover shows the rest (after 381, 382's face and 379's Popover)
14. 387 upgrade a building from its details modal (its rows read `upgrade_rules_text`, which 382 changes)

Military UI:
15. 388 veteran pips on unit cards (after 394, so the query goes on `engine.military`)

Food and building upkeep (after the plan through 412 above):
1. 405 buildings cost wealth upkeep; a shortfall adds unrest (engine; the shipped numbers are 406's)
2. 406 every base building pays ⟳ 1 wealth; a 4-food Farm; Irrigation Canals and Salt Pans stand alone (content)
3. 407 Sumer as the breadbasket: no starting Farm, no +1 housing (content)
