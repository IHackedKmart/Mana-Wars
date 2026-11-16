# Origin: Children of the Luminary (Stellaris mod)

Combines **Mindwardens**, **Post-Apocalyptic** and **Under One Rule** into one origin.

Install: copy this folder to `Documents/Paradox Interactive/Stellaris/mod/children_of_the_luminary/`.
Copy `descriptor.mod` next to that folder as `children_of_the_luminary.mod`, add the line
`path="mod/children_of_the_luminary"` to the copy, then enable the mod in the launcher.

Requires Dictatorial or Imperial authority (not Gestalt or Corporate).
Not tested in game yet: if a key has changed in your game version, check `error.log`.

## Content
- **Prologue** (start of game): The Madness, The Burning, The Conquest of the Ashes, then The Unifying Promise. Each step is a choice with lasting effects.
- **The Unifying Promise**: three timed oaths, checked once a year. Keeping one gives a reward, breaking one gives unrest, and keeping all three unlocks *Starborne Dream*.
- **Situation: The Last Holdouts**: finish the civil war on the homeworld by crushing or reconciling the remnants.
- **Situation: The Whisperers**: keep the mind-wards up. At 100 the Madness returns; at 0 the wards are sealed for good.
- **The Sealed Vaults**: a pre-war vault chain (archives, land reclamation).
- **Situation: The Fading Light**: a succession war if the Luminary dies.
- **The Whisperers Stir**: the original mid-game event.

These chains are written from scratch to fit the lore. They don't copy the base game's scripts.
Check `error.log` for the situation fields (`on_progress_complete`, `on_progress_zero`, approach `on_select`) and for the `GFX_evt_*` picture names.
