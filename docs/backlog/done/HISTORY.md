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
113. 186 the sound player (`Sfx`), its tokens and placeholder sounds (`docs/design/sound-export.html`)
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

Not scheduled: 073 event discard conditions (draft: a behavior question is still open).
