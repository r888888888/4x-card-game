* Add ability to name territories. It should default to a list of historical city names for the civilization.
* Implement the notifications from the MCM specimen
* Style the modals after the MCM specimen. Specfically, modals should have a cancel button and a primary action button in a different color.
* In the card supply, clicking on a card should bring up a modal with details, and from there a button to buy the card.
* In the card supply, clicking outside the supply area should dismiss it.
* Adjust the balance bot script to run at a lower priority such that running a process on every core doesn't affect system responsiveness
* If food production is at +3 per turn or higher, then territories should grow automatically. The largest territories will grow automatically first, followed by the second largest, etc. The auto-growth will stop as soon as food production drops down to +2 per turn. Show a notification when a territory has grown. Then, remove the manual grow button.
* Barbarian raids should only start occurring when the civilizaiton reaches a minimum size (as measured by total value of all territories and buildings and units).
x Devise a formula for large population territories adding to unrest every turn. Try different variations and see which one has the most balance promise.
x Instead of the settle action adding to unrest once, every new territory (beyond the first one) should add 1 unrest per turn.
gaps in terms of realism and/or gameplay.
* Review the current list of technologies and identify any possible additions. I want a focus on realism and techs that genuinely had a meaningful impact on human development. Don't index too heavily on technologies that exist in the game Civilization.
* Remove the Winnow card from the supply.
* Add a hover effect for the techs in the tech tree. Consult MCM specimen for guidance.
* Rethink how wonders are built. They should have a high wealth cost, but players can contribute partially to the wonder every turn.
* When a barbarian raid resolves, there's no indication what the outcome was. Show a modal with a unique sound effect.
* Cities should have size thresholds. 1-3 is a camp, 4-6 is a hamlet, 7-9 is a village, 10-12 is a town, 13-15 is a city, 16+ is a metropolis. These ugprades happen automatically and do not have any cost beyond pop minimums. Each level unlocks additional building slots and housing. Starting at village there is a stacking +1 unrest per turn. So towns have +2 unrest per turn, cities have +3 unrest per turn, metropolis have +4 unrest, etc.
* Buildings can be upgraded but have minimum city size requirements. These ugpraded versions have scaling benefits to make tall strategies worthwhile. 
x Pops that haven't been assigned to a building or military unit are called specialists.
x Rework markets. They should give +1 wealth, +1 per specialist.
x Rework libraries.
x Each government card can support N territories for free, where N is the unrest limit for the government card. Each additional territory gained beyond N inflicts 1 + ((X - N)*(X - N - 1) / 2) unrest per turn, where X is the total number of territories controlled. So the first territory after the Nth territory causes 1 unrest per turn, the second territory causes 2 unrest per turn, the third territory causes 4 unrest per turn, then 7, then 11, then 16, then 22.
* Let's seed the starting deck with a warrior card.
* Adjust the starting deck to only have one scout card.
* Add a notification indicator inside the Knowledge button. Any time the player can purchase a tech, the indicator should light up. The indicator should be dismissed once they open the tech tree. Apply the same logic to the card supply. Generate some designs before commiting to building a spec.
* In the card detail modal in the tech tree, if a tech enables a card, I should be able to see what that card does. Either by clicking on it or embedding it inline, decide what is best. Generate the designs before committing to a spec.
* If I end a turn while in any screen other than realm view (tech tree or territory detail view), I shoudl be navigated back to the realm view.
* When I buy from the card supply, the card should immediately go into my hand rather than my discard. I feel like the gratification from buying a card is too delayed currently and doesn't feel good to play. Critique this design change.
* Rethink how the simulation bot works. Come up with ideas to make its intelligence more generic. State machines? LLM calls?
* Organize the HTML mocks folder. MCM Specimen should be the master document. Make sure it is up to date with the current designs in the app.
* Find a more appealing name than "Mud Bricked HOuses"
* On the tech tree, provide some visual indication of which techs I can afford and which I can't.
* On the tech tree, clicking outside teh tree should dismiss it.
* On the territory detail view, clicking outside of the view should dismiss it.
* Add a hover effect to the building cards (including the empty build slots) in the territory detail view. Play a small subtle sound (consult the sound design guide).
* Make the Build modal larger.
* Make the card heights in the territory detail view consistent.
* Show the settlement tier in the territory detail view.
* When I can't build something because I don't have free pops, explain what is haappening.
* Ending a turn while in the territory detail view or tech tree should dismiss the screen, but also end the turn.
* Find an alternative screen transition for opening the territory detail view. Currently the zoom in looks janky.
* Add flavor text to the action cards. No quotes needed.
* Add flavor text to the building improvements. No quotes needed.
* There are still some screens and modals with white body text in day mode (the seed label when picking a civ in a new game)
* Improve the UX of the scrollbar in the build modal. Add some momentum and smooth scrolling. Increase the gap between bulidings and units. Add some padding between the card and the other sections of the modal. Remove the drop shadow and button bevel effect of selected items; a subtle background color change is sufficient. Update teh design guide as necessary.
* Buttons labeled "Exit" that exit the game should be relabled "Exit Game"
* Purchasing a building should have a little more visual fanfare. Brainstorm some design ideas.
* When I buy a tech card, it appears briefly to be very tall.
* Coastal cities don't have many beneficial cards (fishing huts not as good as farms, no coastal techs). Brainstorm ideas to improve their design.
* The hunt action should only be added after the player builds a Hunters Camp building.
* Think of some action cards to help pad out the starting deck.
* Update the balance bot to enable building upgrades (high priority for tall strategies, lower priority for wide strategies.)
x THe deck should only have 1 scout card, with an extra one added upon researching Animal Husbandry.
* I want to spike on adding images to cards. Just use a placeholder for now. Update the design guide. Generate a list of all the cards, propose a filename, and a description of what kind of art to generate. Overall theme should match the MCM aesthetic, with a focus on MCM print and ad design.
- If a raid is pending on an undefended territory, alert the player that they should build defenses or mobilize units.
* Enable the balance bot to permit tall strategies to build cities (at a low priority), up to 3 cities.
- Build a bot strategy that introduces more randomness into its decision making, to try and search for new maxima.
- Review the current list of territories and identify any missing 
- Review the current slate of civilizations and brainstorm ways of making them feel more unique. Leverage existing mechanics to alter in-game limits and thresholds, or consider inventing new mechanisms to make their play feel more thematic.
- Add some civilization-specific random events.
- Add some other civilizations. Look for inspiration in Asia, the Americas, etc.
* Make quotes less literal about the card they are describing, unless the quote is especially interesting or pithy.
* I should be able to upgrade a building from the building detail modal.
* Add a drawing to the raid repelled modal. Use a placeholder for now, I will replace with a custom image later. Use a different typography for the title.
* Add quotes to wonders.
