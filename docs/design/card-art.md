# Card art list

The art for every card in `data/cards.json`: its file, a brief for the picture and its inks. The style is the guide's
§19 ([mcm-style-guide.md](mcm-style-guide.md#19-card-illustration)): commercial print of 1950–1965, four flat inks on
cream paper, the ancient world drawn the way a mid-century magazine would draw it. 189 cards: civilizations 6,
governments 3, cities 2, units 5, territories 17, wonders 9, buildings 47, actions 19, techs 33, events 48.

**Files.** `assets/cards/<card id>.png`, 1536 × 1024 (3:2), sRGB, no alpha, no border. The game shows the middle 5:2
band (the middle 60 % of the height) at 240 × 96 px, so the subject stays inside it. Until a file exists the card shows
a placeholder plate naming the file.

**Inks.** Every picture is charcoal `#22211F` on cream paper `#F3EBDB`, plus the inks in its row: the first is the card
type's, the dominant colour; the rest are support, used smaller. Never signal orange. Hex values: blue `#8AA7C4`, olive
`#A3AA6A`, ochre `#D9A441`, sage `#9DB592`, teal `#5E9C97`, brick `#C9705C`, plum `#B07D9C`, indigo `#8F88B8`, bronze
`#A97F63`.

**Prompt.** The template in §19.8, with the row's brief as the subject and its inks.

**Upgrades** say so in their brief: they redraw their base's picture from the same viewpoint, grown, so generate the
base first and give it to the generator as a reference.

**Making the pictures.** After changing a brief here, run the `card-art` skill
([SKILL.md](../../.claude/skills/card-art/SKILL.md)): Claude writes the prompt into `assets/card-art-prompts.jsonl`,
draws it with `scripts/card_art.py` once you approve the spend, reviews it, fixes or redraws what fails, and records
each card's state in `assets/card-art-review.jsonl`.

## Civilizations (6)

*Travel posters.*

| File | Card | Brief | Inks |
|---|---|---|---|
| `egypt.png` | Egypt | The Nile as a single teal ribbon curving through ochre desert, three pyramids on the far bank and a felucca's paper-white sail on the water, a low sun disc above. Poster scale, high viewpoint. | plum, ochre, teal |
| `sumer.png` | Sumer | A walled mud-brick city on a mound between two rivers, a stepped temple at its top, reed boats and canal lines running in parallel to the horizon. | plum, ochre, blue |
| `phoenicia.png` | Phoenicia | A tall-prowed merchant ship under a striped square sail leaving a rocky island harbour, cedar-covered mountains behind, a strip of purple cloth streaming from the mast. | plum, blue, sage |
| `babylon.png` | Babylon | The blue-glazed Ishtar Gate seen head-on but off-centre, a striding lion in relief on its wall, a ziggurat and a band of stars beyond. | plum, blue, ochre |
| `greece.png` | Greece | A columned temple on a rocky hilltop above a deep blue bay, olive trees on the slope, an open-air theatre's curved rows cut into the hill below. | plum, blue, olive |
| `persia.png` | Persia | A columned palace terrace with a grand double stair, a winged sun emblem above, and a straight road running away across the plain to the mountains. | plum, ochre, teal |

## Governments (3)

*Emblems.*

| File | Card | Brief | Inks |
|---|---|---|---|
| `chiefdom.png` | Chiefdom | An emblem: a carved wooden staff hung with feathers and a cattle horn, planted in the ground before a ring of seated elders reduced to simple shapes. | indigo, bronze, ochre |
| `kingship.png` | Kingship | An emblem: a tall crown resting on a stepped throne, a single sceptre laid across it, framed by an arch of identical bricks. | indigo, ochre, brick |
| `theocracy.png` | Theocracy | An emblem: a temple's stepped silhouette with an eye-like sun disc above, a sheaf of grain and a sealed jar at its foot, symmetrical. | indigo, ochre, teal |

## Cities (2)

*Skylines.*

| File | Card | Brief | Inks |
|---|---|---|---|
| `capital.png` | Capital | A great walled city seen from outside its gate: tall towers, a temple mound rising behind, banners, smoke from a hundred hearths. Larger and grander than City. | ochre, brick, blue |
| `city.png` | City | A small walled town of flat-roofed mud-brick houses on a low rise, one temple, smoke rising, fields at its foot. | ochre, sage, brick |

## Units (5)

*Silhouettes.*

| File | Card | Brief | Inks |
|---|---|---|---|
| `warriors.png` | Warriors | Four warriors in silhouette marching side-on in step, spears and round hide shields, a low hill behind them. | bronze, brick, ochre |
| `spearmen.png` | Spearmen | A phalanx in silhouette, shields locked and long spears levelled, bronze helmets catching the light. | bronze, brick, ochre |
| `archers.png` | Archers | Three archers in silhouette drawing recurved bows, arrows arcing away in a dotted line. | bronze, olive, ochre |
| `chariots.png` | Chariots | A two-horse chariot at full gallop side-on, a driver and an archer standing in the wicker car. | bronze, brick, ochre |
| `swordsmen.png` | Swordsmen | A rank of swordsmen in silhouette behind tall shields, short iron blades drawn. | bronze, indigo, brick |

## Territories (17)

*Landscapes: land only, no people or buildings, one shared horizon.*

| File | Card | Brief | Inks |
|---|---|---|---|
| `plains.png` | Plains | Open grassland to a flat horizon, long grass in rhythmic stripes, one lone tree, a wide sky with a pale sun. | sage, olive, ochre |
| `river_meadow.png` | River Meadow | Green meadow with a river winding across it in flat blue curves, reeds at its bank, grazing-height grass. | sage, blue, olive |
| `alluvial_plain.png` | Alluvial Plain | A broad river plain in bands: blue river, dark silt bands left by the flood, bright green fields of new growth. | sage, blue, bronze |
| `coastal_plain.png` | Coastal Plain | Grassland running down to a sea edge on one side, a pale beach line, gulls as simple marks. | sage, blue, ochre |
| `dunes.png` | Dunes | Rolling sand dunes as stacked ochre curves, ripple patterns in halftone, a hard blue sky. | sage, ochre, blue |
| `oasis.png` | Oasis | A small pool ringed by date palms in the middle of ochre dunes, the palms drawn as geometric fans. | sage, ochre, blue |
| `desert_floodplain.png` | Desert Floodplain | A ribbon of green and black silt along a river through bare desert, the desert cliffs pale on both sides. | sage, ochre, blue |
| `reed_marsh.png` | Reed Marsh | Tall reed beds in vertical strokes over still water, a heron as a few angular shapes, lily pads as circles. | sage, blue, olive |
| `delta_marsh.png` | Delta Marsh | A river splitting into channels across reed islands toward the sea at the far edge, silt bands between them. | sage, blue, ochre |
| `woodland.png` | Woodland | A forest of stylised trees as stacked triangles and ovals in two greens, a dark band of shade beneath. | sage, olive, bronze |
| `lakeside_woods.png` | Lakeside Woods | Trees standing at the edge of a calm lake, their shapes mirrored in the water as a second row. | sage, blue, olive |
| `cedar_coast.png` | Cedar Coast | Tall layered cedars on a slope down to the sea, a stream running between them to the shore. | sage, blue, olive |
| `hill_country.png` | Hill Country | Rounded hills overlapping in three tones, a few rocks, a winding track over the crest. | sage, olive, ochre |
| `highland_valley.png` | Highland Valley | A green valley between hills, a stream down its middle, terraces of light on the slopes. | sage, blue, olive |
| `coastal_hills.png` | Coastal Hills | Hills ending in cliffs above the sea, a spring falling to a cove, the sea flat and bright. | sage, blue, ochre |
| `mountains.png` | Mountains | A range of sharp peaks as layered triangles, snowcaps left as bare paper, a band of cloud. | sage, blue, indigo |
| `mountain_lake.png` | Mountain Lake | A still blue lake held in a ring of peaks, the peaks reflected as inverted triangles. | sage, blue, indigo |

## Wonders (9)

*Monuments: low viewpoint, the one series that may use a period motif.*

| File | Card | Brief | Inks |
|---|---|---|---|
| `pyramids.png` | Pyramids | Three pyramids at Giza from a low viewpoint, one dominant, a sun disc with radiating rays behind its apex, a line of tiny haulers dragging a block. | olive, ochre, blue |
| `oracle_of_delphi.png` | Oracle of Delphi | A small columned temple on a steep mountain ledge, a thin plume of vapour rising from a cleft, a lone robed priestess seated on a tripod. | olive, teal, ochre |
| `walls_of_uruk.png` | Walls of Uruk | A vast wall of kiln-fired brick with regular towers running out of frame, the brick courses as a rhythmic pattern, a tiny gate for scale. | olive, ochre, brick |
| `great_ziggurat.png` | Great Ziggurat | A stepped brick ziggurat with three converging stairs, a small shrine at the top under a crescent moon, concentric rings behind. | olive, ochre, blue |
| `hanging_gardens.png` | Hanging Gardens | Terraces of trees and trailing vines climbing a palace like a green staircase, a water-lifting wheel at one side. | olive, sage, blue |
| `great_library.png` | Great Library | A colonnade opening onto shelves of scroll cubbyholes, a ship's mast visible through a window, a scholar unrolling a scroll. | olive, ochre, blue |
| `great_harbor_of_tyre.png` | Great Harbor of Tyre | An island city with two harbours, one on each side, ships streaming into both, the mainland across a strait. | olive, blue, plum |
| `lighthouse_of_pharos.png` | Lighthouse of Pharos | A tall three-tiered pale stone tower with a fire at its top, beams drawn as radiating lines over a night sea, a ship approaching. | olive, blue, ochre |
| `royal_road.png` | Royal Road | A straight road running from foreground to horizon across a plain, a relay station with a fresh horse waiting, a rider far off. | olive, ochre, brick |

## Buildings (47)

*Architecture: an upgrade keeps its base's viewpoint, grown.*

| File | Card | Brief | Inks |
|---|---|---|---|
| `farm.png` | Farm | Small fields of wheat and barley in strips beside a river, a farmer with a hoe, a reed hut at the edge. | olive, sage, ochre |
| `palisade.png` | Palisade | A ring of sharpened log stakes and a ditch around a few huts, a crescent moon above. | olive, bronze, indigo |
| `temple.png` | Temple | Upgrade of Shrine. A small mud-brick temple on a raised platform with steps, a robed figure carrying an offering up them. | olive, ochre, teal |
| `great_temple.png` | Great Temple | Upgrade of Temple. The same temple grown into a walled complex: courtyards, granaries and workshops around the raised sanctuary, many figures. | olive, ochre, teal |
| `monument.png` | Monument | A carved standing stone in a town square showing a king's victory in relief, one passer-by walking past without looking. | olive, ochre, brick |
| `pasture.png` | Pasture | Sheep and goats as rounded geometric shapes spread across open grass, a herder with a crook counting them at dusk. | olive, sage, ochre |
| `harbor.png` | Harbor | Upgrade of Fishing Huts. Stone quays and a curved breakwater sheltering a bay, two ships moored, waves outside the wall. | olive, blue, ochre |
| `hunters_camp.png` | Hunters' Camp | A hide tent and drying racks of meat at a forest edge, a small fire, dark trees behind. | olive, bronze, brick |
| `timber_camp.png` | Timber Camp | Upgrade of Hunters' Camp. The hunters' camp grown into a logging site: stacked logs, axemen at work, logs floating down a river. | olive, bronze, blue |
| `irrigation_canals.png` | Irrigation Canals | Upgrade of Farm. A grid of straight canals carrying blue water across green fields, a figure with a shovel clearing silt. | olive, blue, sage |
| `ploughed_fields.png` | Ploughed Fields | Upgrade of Farm. Yoked oxen pulling a wooden plough, furrows in long parallel curves running away to the horizon. | olive, bronze, ochre |
| `weavers_workshop.png` | Weavers' Workshop | Two upright looms with cloth in striped patterns, spindles turning, a weaver at each. | olive, brick, ochre |
| `brewery.png` | Brewery | Great clay jars in a row with foam at their mouths, a brewer stirring with a long paddle. | olive, ochre, bronze |
| `olive_groves.png` | Olive Groves | Rows of silver-green olive trees on a dry slope, gnarled trunks as simple twisting shapes. | olive, sage, ochre |
| `house_of_life.png` | House of Life | Upgrade of Temple. A lamplit hall where scribes copy papyri at low desks, jars of remedies on shelves. | olive, ochre, teal |
| `qanat_channel.png` | Qanat | A cutaway of a hillside showing a tunnel running gently downhill, shafts rising to the surface, green fields where it emerges. | olive, blue, ochre |
| `fishing_huts.png` | Fishing Huts | Reed huts on a shore, nets drying on poles, two small boats out on pewter-grey water. | olive, blue, bronze |
| `salt_pans.png` | Salt Pans | Upgrade of Fishing Huts. Shallow rectangular clay beds of seawater in a grid by the shore, white salt crusting, a worker raking. | olive, blue, ochre |
| `shrine.png` | Shrine | A small stone altar on a high rocky place, a bead and a crust left on it, a mountain beyond. | olive, teal, ochre |
| `mine.png` | Mine | A dark opening in a hillside streaked with green ore, a miner coming out with a basket, a fire at the mouth. | olive, bronze, teal |
| `shaft_mine.png` | Shaft Mine | Upgrade of Mine. The mine grown deep: a cutaway of shafts and galleries under the hill, ladders, tiny lamps. | olive, bronze, teal |
| `forge.png` | Forge | A smith at an anvil with a glowing ingot, bellows behind, sparks as small flat shapes. | olive, brick, ochre |
| `barracks.png` | Barracks | A courtyard where a row of young soldiers drills in step, shields up, an officer to one side. | olive, brick, bronze |
| `market.png` | Market | A square of awnings over stalls of pots, figs and cloth, buyers and sellers as simple figures. | olive, ochre, brick |
| `granary.png` | Granary | Rounded clay storage bins in a row, a worker sealing one with a clay stopper. | olive, ochre, bronze |
| `scribal_school.png` | Scribal School | Children at benches copying signs into clay tablets, a teacher with a stylus. | olive, ochre, teal |
| `library.png` | Library | Upgrade of Scribal School. Shelves of tablets and scroll cubbyholes, a reader at a table by a window. | olive, ochre, teal |
| `stone_circle.png` | Stone Circle | A ring of standing stones on open ground, the midsummer sun rising exactly through a gap. | olive, ochre, indigo |
| `mud_brick_houses.png` | Courtyard Houses | A courtyard house seen from above at an angle: rooms around a shaded yard, a family cooking. | olive, ochre, sage |
| `bathhouse.png` | Bathhouse | Arched pools of warm and cold water, steam as flat curls, bathers talking. | olive, blue, brick |
| `courthouse.png` | Courthouse | A columned hall where a judge on a raised seat hears two figures, a tablet of laws on the wall. | olive, indigo, ochre |
| `aqueduct.png` | Aqueduct | A line of tall stone arches striding across a valley carrying a water channel toward a town. | olive, blue, ochre |
| `palace.png` | Palace | A palace facade of painted columns and a grand doorway, courtiers on the steps. | olive, ochre, plum |
| `shipyard.png` | Shipyard | A hull on the stocks, ribs showing, shipwrights with adzes, stacked timber. | olive, bronze, blue |
| `terraced_fields.png` | Terraced Fields | Stone-walled terraces stepping up a steep slope, each a strip of green. | olive, sage, ochre |
| `reed_works.png` | Reed Works | Bundles of reeds stacked and bound, a reed boat taking shape, mats and baskets drying. | olive, ochre, blue |
| `cistern.png` | Cistern | A cutaway of a rock-cut chamber full of still water, a bucket on a rope lowered from above. | olive, blue, ochre |
| `dye_works.png` | Dye Works | Vats of purple dye, cloth hanging to dry in purple stripes, a heap of sea snail shells. | olive, plum, blue |
| `kiln.png` | Kiln | A domed clay kiln glowing at its mouth on a riverbank, jars and bricks stacked to fire. | olive, brick, ochre |
| `merchant_quarter.png` | Merchant Quarter | Upgrade of Market. A street of warehouses and counting houses, traders in fine robes with bales and scales. | olive, ochre, plum |
| `mint.png` | Mint | Upgrade of Merchant Quarter. A coin die being struck with a hammer, a lion's head on the coin, a small pile of coins. | olive, ochre, bronze |
| `storehouse.png` | Storehouse | Upgrade of Granary. Rows of storerooms full of jars of grain, oil and wine, a scribe tallying with seals. | olive, ochre, bronze |
| `city_walls.png` | City Walls | Upgrade of Palisade. Stone walls with towers and a fortified gate, the palisade's line now grown into masonry. | olive, ochre, indigo |
| `multi_storey_houses.png` | Multi-storey Houses | Upgrade of Courtyard Houses. Courtyard houses grown to three storeys, shops below, laundry on the roofs, a crowded street. | olive, ochre, brick |
| `textile_works.png` | Textile Works | Upgrade of Weavers' Workshop. A long hall of many looms and dyers in rows, cloth carried out in bales by cart. | olive, brick, plum |
| `dockyard.png` | Dockyard | Upgrade of Harbor. The harbour grown into slipways and ropewalks, three hulls on the stocks at once. | olive, blue, bronze |
| `caravanserai.png` | Caravan Station | A walled square courtyard with a well, camels kneeling, merchants by lamplight. | olive, ochre, teal |

## Actions (19)

*People at work, in a frieze.*

| File | Card | Brief | Inks |
|---|---|---|---|
| `settler.png` | Settler | A family walking beside an oxcart loaded with seed grain and jars, toward a distant river. | blue, ochre, sage |
| `scout.png` | Scout | A lone runner on a ridge looking out over unknown land, a river below, thin smoke far away. | blue, ochre, sage |
| `barter.png` | Barter | Two traders at a river ford exchanging a block of salt for a basket of obsidian, each pleased. | blue, ochre, brick |
| `hunt.png` | Hunt | Hunters with spears moving through tall grass behind a herd of aurochs, dusk sky. | blue, ochre, bronze |
| `net_fishing.png` | Net Fishing | Two small boats drawing a net between them across shallows, silver fish as flat shapes in the mesh. | blue, teal, ochre |
| `bread_and_beer.png` | Bread and Beer | A worker receiving a round loaf and a jar of beer from a ration-keeper. | blue, ochre, bronze |
| `land_grants.png` | Land Grants | A ruler's official pacing out a field with a measuring rope, a veteran with a spear waiting, boundary stones. | blue, ochre, sage |
| `feast.png` | Feast | A long table of figures eating together, an ox on a spit, jars being opened. | blue, brick, ochre |
| `runner.png` | Runner | A messenger running across a plain toward a distant town, a sealed tablet in hand. | blue, ochre, sage |
| `tribute.png` | Tribute | A line of figures carrying jars of oil, cloth and silver rings to a seated official. | blue, ochre, plum |
| `assembly_of_elders.png` | Assembly of Elders | Elders seated in a semicircle at a city gate, one standing to speak. | blue, indigo, ochre |
| `slash_and_burn.png` | Slash and Burn | Fire running through brush in flat flame shapes, a farmer with a torch, ash on the ground. | blue, brick, ochre |
| `corvee.png` | Corvée | A long line of labourers hauling a stone block on a sledge with ropes, a canal being dug beside. | blue, ochre, bronze |
| `storyteller.png` | Storyteller | An old storyteller by a fire with listeners around, a flood and a hero rising in the smoke above. | blue, brick, indigo |
| `research.png` | Research | Priests on a temple roof watching the stars while a scribe copies tables onto a tablet. | blue, indigo, ochre |
| `caravan.png` | Caravan | A string of donkeys and camels crossing the desert in silhouette, loads swaying. | blue, ochre, brick |
| `sea_trade.png` | Sea Trade | A merchant ship riding low along a coast, cedar logs on deck, a port ahead. | blue, teal, ochre |
| `precedent.png` | Precedent | Scribes reading a stack of old clay verdicts to two judges. | blue, indigo, ochre |
| `read_the_stars.png` | Read the Stars | An astronomer on a temple roof charting planets, star lines drawn across the sky like a diagram. | blue, indigo, ochre |

## Techs (33)

*Ideas: one object on open ground, with a diagram.*

| File | Card | Brief | Inks |
|---|---|---|---|
| `pottery.png` | Pottery | A coil-built jar on open ground with sherds around it, a ring diagram showing its coils. | teal, brick, ochre |
| `animal_husbandry.png` | Animal Husbandry | A goat, a sheep and an aurochs as geometric shapes inside a corral circle. | teal, ochre, sage |
| `irrigation.png` | Irrigation | A river splitting into a branching diagram of canals that turns desert green. | teal, blue, sage |
| `the_plough.png` | The Plough | A wooden plough share in profile, its furrows radiating behind as straight lines. | teal, bronze, ochre |
| `weaving.png` | Weaving | An upright loom with warp and weft drawn as a grid, a spindle beside. | teal, brick, ochre |
| `clay_tokens.png` | Clay Tokens | Small clay cones, spheres and discs arranged in a row before a sealed clay envelope. | teal, ochre, bronze |
| `fermentation.png` | Fermentation | A clay jar with bubbles rising as circles, a drinking straw, grain at its foot. | teal, ochre, bronze |
| `mining.png` | Mining | A pick and an oil lamp before a cross-section of rock with veins of copper and tin. | teal, bronze, ochre |
| `mysticism.png` | Mysticism | An open hand with an eye on the palm, constellations and dream shapes circling it. | teal, indigo, ochre |
| `the_wheel.png` | The Wheel | A solid wooden wheel with concentric rings around it like an orbit diagram. | teal, bronze, ochre |
| `masonry.png` | Masonry | Cut stone blocks fitted together, a mason's square and plumb line overlaid as a diagram. | teal, ochre, bronze |
| `bronze_working.png` | Bronze Working | A crucible pouring molten bronze into an axe mould, copper and tin as two circles merging. | teal, bronze, brick |
| `archery.png` | Archery | A composite bow on open ground, its layers of horn, wood and sinew drawn apart like a cutaway diagram. | teal, ochre, bronze |
| `writing.png` | Writing | A clay tablet with wedge marks as pattern, a reed stylus, lines leading from it to a sheaf of grain. | teal, ochre, bronze |
| `weights_and_measures.png` | Weights and Measures | A balance scale with silver rings on one pan and a stone weight on the other, a grid behind. | teal, ochre, bronze |
| `olive_and_vine.png` | Olive and Vine | An olive branch and a grapevine crossing, an amphora between them. | teal, sage, plum |
| `medicine.png` | Medicine | A papyrus with remedies as pattern, a mortar and pestle, herbs, a lamp. | teal, sage, ochre |
| `credit.png` | Credit | A clay contract tablet sealed with a cylinder-seal impression, silver rings and barley measures beside. | teal, ochre, plum |
| `sailing.png` | Sailing | A square sail on a mast as a bold shape, wind lines and a coastline diagram behind. | teal, blue, ochre |
| `priesthood.png` | Priesthood | A tall priest's headdress and staff before a temple facade, an altar flame. | teal, indigo, ochre |
| `code_of_laws.png` | Code of Laws | A tall basalt stele with rows of script as pattern and a seated figure carved at its top. | teal, indigo, ochre |
| `calendar.png` | Calendar | A ring of 12 segments around the star Sirius rising over the Nile's flood line. | teal, indigo, blue |
| `chariot.png` | Chariot | A spoked chariot wheel beside a solid one, its spokes drawn as a radial diagram, hoofprints around. | teal, bronze, ochre |
| `philosophy.png` | Philosophy | Two figures in conversation under a plane tree, a geometric diagram drawn in the sand. | teal, olive, ochre |
| `iron_working.png` | Iron Working | An iron blade on an anvil, a bloomery furnace behind, ore lumps scattered. | teal, indigo, brick |
| `mathematics.png` | Mathematics | A geometric proof: a right triangle with squares on its sides, a counting board. | teal, ochre, indigo |
| `coinage.png` | Coinage | A large electrum coin stamped with a lion's head, smaller coins radiating out. | teal, ochre, bronze |
| `bureaucracy.png` | Bureaucracy | Stacked tax tablets, a seal, and a map of provinces linked by courier routes as a network. | teal, indigo, ochre |
| `alphabet.png` | Alphabet | A row of simple letter shapes as abstract marks being cut into a strip of stone, not legible. | teal, ochre, plum |
| `qanat.png` | Qanat | A cross-section diagram of a sloping tunnel under a mountain bringing water to a desert field. | teal, blue, ochre |
| `navigation.png` | Navigation | A ship under stars with a constellation connected to it by a dotted course line across open sea. | teal, blue, indigo |
| `astronomy.png` | Astronomy | A ziggurat roof with an astronomer and the orbits of wandering stars drawn as ellipses above, an eclipse. | teal, indigo, ochre |
| `engineering.png` | Engineering | An arch in elevation with its voussoirs and keystone diagrammed, a straight road running through it. | teal, ochre, blue |

## Events (48)

*Spot illustrations: good ones light, disasters two inks and plain.*

| File | Card | Brief | Inks |
|---|---|---|---|
| `forage.png` | Forage | Young people coming home at dawn with baskets of roots and nuts, one holding a hare. | brick, sage, ochre |
| `anarchy.png` | Anarchy | A broken throne in an empty hall, papers and tablets scattered, a crowd's shapes through the door. | brick, indigo |
| `harvest_festival.png` | Harvest Festival | Villagers carrying the last sheaf home in a procession with drums and garlands. | brick, ochre, sage |
| `envoys_from_the_hills.png` | Envoys from the Hills | Hill chieftains bowing at a city gate, offering furs and honey jars. | brick, ochre, bronze |
| `plague.png` | Plague | An empty street at dusk, shuttered doors, a single healer burning herbs, smoke curling. | brick |
| `granary_fire.png` | Granary Fire | A granary at night, smoke and flame rising from its roof, a tipped lamp in the foreground. | brick, ochre |
| `drought.png` | Drought | Cracked earth in a polygon pattern, a dry riverbed, a herd walking far off under a white sun. | brick, ochre |
| `silt_flood.png` | Silt Flood | A river over its banks leaving a broad band of rich black mud across fields, a farmer looking on. | brick, blue, sage |
| `bumper_harvest.png` | Bumper Harvest | Heavy ears of grain bending stalks, a barn full to the rafters, children on the sheaves. | brick, ochre, sage |
| `busy_harbours.png` | Busy Harbours | A bay crowded with sails of many colours, quays full of traders. | brick, blue, ochre |
| `visiting_scholar.png` | Visiting Scholar | A stranger with a scroll case and a lamp at a doorway, stars overhead. | brick, indigo, ochre |
| `labour_shortage.png` | Labour Shortage | Empty fields with tools left standing in the soil, one old figure in the distance. | brick, ochre |
| `tax_revolt.png` | Tax Revolt | Tax collectors retreating from a village with empty baskets, villagers standing together. | brick, ochre, indigo |
| `wandering_smiths.png` | Wandering Smiths | Travelling smiths with a portable forge at a city gate, sparks, a mule with packs. | brick, bronze, ochre |
| `pestilence.png` | Pestilence | Crowded rooftops under a sickly sky, a column of smoke from a pyre. | brick |
| `library_burns.png` | Library Burns | Shelves of scrolls in flame, burning pages rising into a night sky as flat sparks. | brick, ochre |
| `debased_coin.png` | Debased Coin | A merchant weighing a coin on a balance, a coin split open to show a lead core. | brick, ochre, indigo |
| `storm_at_sea.png` | Storm at Sea | Gale waves in heavy stacked curves, a broken mast and wreckage on a dark sea. | brick, blue |
| `golden_age.png` | Golden Age | A city in full sun: full granaries, a temple, artisans at work, children playing. | brick, ochre, sage |
| `school_of_philosophers.png` | School of Philosophers | Teachers arguing under plane trees, students writing on wax tablets. | brick, olive, ochre |
| `succession_crisis.png` | Succession Crisis | An empty throne with three figures facing it from different sides, each with an armed follower. | brick, indigo, plum |
| `mercenaries_offer.png` | Mercenaries' Offer | Hard-faced soldiers with foreign shields waiting patiently at a city gate, one bowing. | brick, bronze, indigo |
| `solstice_rites.png` | Solstice Rites | Bonfires on every hilltop at night, elders on a hill watching the east. | brick, ochre, indigo |
| `traveling_bards.png` | Traveling Bards | Two bards with lyres playing by a fire to listeners, a giant king rising in their song's smoke. | brick, ochre, plum |
| `comet_sighted.png` | Comet Sighted | A long-tailed comet over dark fields, priests on a roof pointing in two directions. | brick, indigo, ochre |
| `distant_drums.png` | Distant Drums | A night sky over black hills, drum beats drawn as concentric rings rising beyond them. | brick, indigo |
| `wild_berries.png` | Wild Berries | Children with purple hands picking berries from heavy hedges in long gold evening light. | brick, plum, ochre |
| `tuna_run.png` | Tuna Run | A waterline cutaway: a dense shoal of tuna as rhythmic silver shapes below the surface, a few breaking it, one empty skiff with a heaped net riding above. | brick, blue, ochre |
| `beached_whale.png` | Beached Whale | A great whale on the sand at dawn, townspeople with baskets around it, small against it. | brick, blue, ochre |
| `shipwreck_salvage.png` | Shipwreck Salvage | Amphorae, timber and coils of rope strewn along a beach below a reef, morning light. | brick, blue, ochre |
| `wandering_trader.png` | Wandering Trader | A lone trader leading a laden donkey into a town square, holding up a string of beads. | brick, ochre, teal |
| `local_legend.png` | Local Legend | A shepherd wrestling a lion, drawn heroic like a frieze, a second lion's ghost outline behind. | brick, ochre, olive |
| `mild_spring.png` | Mild Spring | Early blossom on a tree, a gently risen river, people walking in light. | brick, sage, blue |
| `famine.png` | Famine | An empty granary's open door, a single seed jar on its side. | brick |
| `market_day.png` | Market Day | A square full of stalls, haggling figures, coins passing between hands. | brick, ochre, teal |
| `good_omens.png` | Good Omens | An eagle circling a citadel three times in a dotted spiral, augurs looking up. | brick, ochre, blue |
| `grumbling.png` | Grumbling | Figures muttering at a well, heads together, a palace in the distance. | brick, indigo, ochre |
| `omen_of_doom.png` | Omen of Doom | A red moon rising over a field, a soothsayer turning away. | brick, indigo |
| `bandit_raids.png` | Bandit Raids | Masked riders on a road at dusk, an overturned cart. | brick, indigo |
| `raiders.png` | Raiders | Dust on the horizon: riders from the steppe in silhouette coming over the rise toward fields. | brick, ochre |
| `sea_raiders.png` | Sea Raiders | Long ships beached in the night below a harbour, empty storehouses with open doors. | brick, blue |
| `hill_tribes.png` | Hill Tribes | Clansmen coming down from high valleys along a path toward farmland. | brick, olive, ochre |
| `horse_raiders.png` | Horse Raiders | Riders at full gallop across grassland, carts overturned behind them, an alarm drum on a wall. | brick, ochre, sage |
| `pirates.png` | Pirates | A fleet of ships off a headland at dawn, a port's smoke rising behind the harbour wall. | brick, blue, ochre |
| `barbarian_horde.png` | Barbarian Horde | A long column of wagons, herds and walking people crossing a plain from the north. | brick, indigo, ochre |
| `calls_for_reform.png` | Calls for Reform | Petitioners crowding palace steps holding up tablets, a guard at the door. | brick, indigo, ochre |
| `peasant_uprising.png` | Peasant Uprising | Farmers with pitchforks and torches in silhouette, a steward's house aflame behind. | brick, ochre |
| `radical_thinkers.png` | Radical Thinkers | A teacher in an agora speaking to rapt young listeners, a temple and a palace in the background. | brick, olive, indigo |
