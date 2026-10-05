# Mana Wars

A Roblox battle royale that crosses **old-school Minecraft Survival Games** with **Noita-style spellcrafting**.

Everyone starts in a floating plaza where they can hang out and practise spells for as long as they like. Press **▶️ PLAY** (or walk through the portal) to pick a game mode: **Survival Games**, a **1v1 Duel** or a 50-mage **Battle Royale** (see [Game modes](#game-modes)). In Survival Games, up to 12 mages vote on a map in a floating library and drop onto pedestals around a cornucopia of chests. When the gong sounds there's a 5-second breather. After that it's a fight, so you can risk the middle for the best loot or run for the hills. More chests are spread across a freshly generated island, and they hold three things:

- **Wands.** Randomly generated, each with its own rarity, spell slots, mana pool, cast delay, recharge time, multicast, spread and perks.
- **Fully made spells.** 69 hand-designed ones such as Fireball, Chain Lightning, Black Hole, Hydra Storm and Doom Turret, plus randomly generated ones.
- **Spell parts.** 74 parts you combine in the **Spellforge** to craft your own spells.

The chests refill halfway through, a Mana Storm closes in, and the last mage standing wins. There are 5 maps to vote on, and 17 kits to start with: a free Apprentice kit, plus 16 more sold in tiers from $0.99 to $25.

Every match also pays out **Enchanted Coins** by finishing place. Spend them on **coffers** of robe and hat parts, stitch your own outfit at the **Tailor's Loom** (with auras like billowing smoke, trailing lightning and stardust on the rarest pieces), collect **familiars** that follow you around, and trade parts, outfits or familiars with other players at the **auction house**.

## Game modes

**▶️ PLAY** (or the Plaza's portal) opens the mode menu. Picking a mode joins its queue and takes you to the library. To switch, press **🔄 Queued for … · change** under the Leave button any time before your match starts.

| | Mode | Players | How it plays |
|---|---|---|---|
| ⚔️ | **Survival Games** | up to 12 | The classic: vote on one of five islands, start on a pedestal around the cornucopia, loot, and outlast the Mana Storm. |
| 🤺 | **1v1 Duel** | 2 | A floating arena high above everything, with cover pillars and low walls. Both duelists get the same wand with **one random spell** and **one random potion**. There are no chests. Your kit, your outfit's bonuses and your familiar's powers don't count here (you still look the part), so every duel is a fair fight. After a 3-second countdown you fight. At 75 seconds the arena starts burning you both (sudden death), and at 2:30 the mage with more health wins. The winner earns 10 coins and the loser 2. A duel starts as soon as two mages are queued, or a bot steps in after 15 seconds alone. You stay queued afterwards, so the next opponent comes along on their own. Up to 6 duels run at once. |
| 🧞 | **Battle Royale** | up to 50 | Ride a **magic carpet** across an enormous island of five realms, jump off wherever you like, glide down, loot villages, castles and ruins, and outlast the shrinking storm circles. See below. |

Survival Games and Battle Royale take turns in the main arena. Whichever queue's first player has waited longest goes next. Duels run at the same time as either of them.

### Battle Royale: the Sundered Realms

- **The island.** It has a radius of 1,000 studs, about five times the area of the biggest Survival map, and is generated fresh every match. The Heartland meadows sit in the middle, with four realms around them, each with its own ground, decoration, landmarks and weather:
  - the snowy **Frostlands** to the north, with mountain ridges
  - the **Ashlands** to the east, with a smoking volcano
  - the **Sunscar Desert** to the south, with stepped mesas
  - the dark **Wildwood** to the west, a forest of oaks, pines and giant mushrooms
- **Nine named places, joined by roads:**
  - **Spellcaster's Square**, a town in the middle with a mage tower and a market
  - **Frostfang Hold** and **Ashfall Keep**, castles with walls, towers and a keep
  - **Rimeholm**, **Dunewatch** and **Mossbrook**, villages of cottages around a well (Mossbrook has a windmill)
  - **Cinderforge**, a forge town near the volcano
  - **Sunscar Bazaar**, an oasis market with a pyramid
  - **Glowcap Hollow**, a fairy glade
  
  There are also 23 smaller landmarks spread across the realms.
- **About 200 chests.** Roughly 150 are dotted over the island. The rest are in cottage cupboards, shrines, towers and castles.
- **The magic carpet.**
  - The queue stays open for 30 seconds while the island is built. Bots top the match up to 20 mages.
  - Everyone then boards one huge flying carpet. It crosses the island in a straight line, 330 studs up, on a different path every match. While you ride, the names of the places float over them.
  - Press **SPACE**, **🧞 JUMP OFF** or the jump button on a phone or gamepad to jump off. You glide down on a little rug of your own, steering with your movement keys. Anyone still aboard after 50 seconds is tipped off at the far end.
  - Until you land, you can't cast and nobody can hurt you.
- **Storm circles.**
  - The storm starts around the whole island and closes in five times.
  - Each next circle shows as a faint white wall, and the HUD counts down to when the storm moves. Then the wall moves in, its centre sliding over to the new circle.
  - Each circle sits inside the last one. Being outside hurts more at every stage, from 2 up to 15 damage a second.
  - The chests refill after 5 minutes.
- **Coins** count real players only, so bots never inflate them. With N players in the match, the best-placed player earns N coins, the next N − 1, and so on down to 1 (plus your outfit's Fortune bonus). A full 50-player match pays 50 for 1st down to 1 for 50th. The HUD shows which realm you're in.
- **Your kit, outfit and familiar come with you**, exactly as in Survival Games.

Tune the modes in `Config.Duel` and `Config.Royale`, and the island itself in `MapDefs.Royale`.

## The hub: Arcanum Plaza

Every player spawns here, and nothing pulls you into a match until you choose to go. The plaza is a floating island with:
- a mana fountain, benches, market stalls, wizard towers and floating isles, so there's somewhere to hang out
- the **Practice Range** to the east, with standing training dummies and two that slide along rails so you can practise leading your shots
- a gazebo to the west with the **Class Altar** and **Grimoire** lecterns
- a live **Next Match** board by the spawn, showing the vote countdown, how many mages are queued, and how many are still alive in the current match
- two market stalls flanking the spawn: the **Tailor's Loom** (craft and wear robes and hats) and the **Coffer** merchant (spend Enchanted Coins on loot boxes)
- the **Gilded Gavel**, an auction house pavilion in the south-west, where players buy and sell robe and hat parts or finished outfits

- **Join the game.** Walk through the big **portal** at the north end, or press **▶️ PLAY** at the top of the screen, then pick a game mode. That puts you in its queue and takes you to the library.
- **Spell Lab.** Outside a match you carry a sandbox kit: a practice staff, a twin-cast scepter, showcase spells and 3 copies of **every** spell part. Dummies never die, and practice spells can't hurt other players. The kit is swapped for your real starting kit when a match starts. **♻ Restock Spell Lab** in the Spellbook refills everything.
- **Tutorial.** On your first visit a step-by-step tutorial teaches crafting by doing. You open the Spellbook, forge a spell, slot it into a wand, hit a dummy, then build a spell with a trigger and payload. Each step finishes itself when you do it, and the next button glows.
- **Grimoire.** Press **H**, or use a lectern, to open an in-game encyclopedia. It covers how a match works, how crafting works, how wands work, every Form, Element, Modifier and Trigger, the premade spell library, the kits and their tiers and odds, coins, coffers and outfits, and the controls. You can also replay the tutorial from it.
- **👘 Wardrobe & Coffers / ⚖ Auction House** buttons on the left of the screen open the same windows as the stalls. Your coin count is shown under them.

## The queue: the Arcane Athenaeum

Joining the game takes you to a library floating above the island. It has towering bookshelves, chandeliers, stained glass, a spinning orrery and floating books, plus a glass scrying window in the floor so you can watch the match below.

- **Map vote (Survival Games).** As soon as someone is queued, a 30-second vote opens: a ballot of 3 maps on the right of the screen (the map just played is left off). Only queued players can vote. Players in the hub get a heads-up and can still join. The most votes wins, ties are broken at random, and the vote is cut to 10 seconds once all 12 pedestals are spoken for.
- **The match** takes everyone in the mode's queue, plus bots if there are fewer than 8 players (20 in a Battle Royale). People who join mid-match wait here for the next one. They can spectate, or practise on the **Practice Terrace** through the north arch.
- **After a match** you come back here, still queued, so the next round starts on its own. To take a break, use the portal on the south wall or press **↩ Leave queue** to return to the Plaza.

## Making your own spells

Every spell is built from parts:

| Slot | Choose | Examples |
|---|---|---|
| **Form** (required) | what the spell physically is | Bolt, Spark, Orb, Lance (beam), Nova, Chain, Mine, Grenade, Cloud, Boomerang, Wisp, Meteor, Blink, Aegis, Sawblade, Swarm, Rampart (a wall), Tornado, Black Hole, Sentry (a turret)... |
| **Element** | what it's made of | Fire burns, Frost slows (3 hits freezes), Lightning arcs, Poison stacks, Void heals you, Earth hits hard, Wind launches, Radiant marks targets through walls, Blood trades HP for power, Chaos rolls the dice, Chrono rewinds time |
| **Modifiers** (up to 4) | how it behaves | Homing, Twin, Triple, Barrage, Explosive, Bounce, Pierce, Lingering, Orbit, Phasing, Vortex, Shatter, Echo, Skyfall, Stasis, Returning, Magnetic, Gigantic, Transpose, Hydra, Fractal... |
| **Trigger + Payload** | cast a *whole other spell* on hit / on expiry / on a timer / every pulse / on every bounce / near an enemy / on a kill | Grenade → On Expire → Fire Spray = *Cluster Bomb* |

Payloads can carry their own triggers, up to three layers deep. So a *Seeking Twin Ember Bolt* that bursts into a *Frost Nova*, which then spits *Triple Storm Sparks*, is a real spell you can build. That works out to about **376 million** single-layer spells, and around 10^18 once you add one trigger. Any spell can be **dismantled** back into its parts, so rare premade spells double as rare parts.

### The really crazy parts

| Part | What it does | Try |
|---|---|---|
| 🧬 **Fractal** (Legendary) | when it ends it splits into 3 smaller copies of itself, which split again; stack it for 1 → 3 → 9 → 27 | Spark + Fire + Fractal + Fractal = *Fireworks* |
| 🐉 **Hydra** (Legendary) | splits in two every time it bounces | Bolt + Lightning + Bounce + Hydra = *Hydra Storm* |
| 🧿 **Sentry** (Legendary form) | a floating eye that hovers for 8s and shoots the nearest enemy; its shots inherit the eye's element and modifiers, and Pulse payloads are aimed at enemies | Sentry + Pulse → Meteor = *Doom Turret* |
| ⚫ **Black Hole** (Epic form) | drifts forward dragging everyone in, crushes them, then collapses with a bang | Black Hole + Void + Gigantic + On Expire → Nova = *Event Horizon* |
| 🌪️ **Tornado** (Epic form) | a wandering twister that sucks enemies in and tosses them into the air | Tornado + Wind + Magnetic = *Twister* |
| 🧱 **Rampart** (Rare form) | raises a solid wall that blocks movement and spells for 6s; expiry triggers fire when it crumbles | Rampart + Earth |
| 🌧️ **Skyfall** (Epic) | the spell comes down from the sky onto your aim point; novas erupt there, beams strike down, blinks land there | Bolt + Skyfall + Barrage = *Arcane Rain* |
| 🔀 **Transpose** (Epic) | you swap places with whoever it hits | Bolt + Transpose + Haste = *Switcheroo* |
| 🕰️ **Chrono** (Legendary element) | hits rewind the target to where they stood 2 seconds ago | Lance + Chrono = *Rewind Lance* |
| 🃏 **Chaos** (Epic element) | every hit does 25%–250% damage plus a random burn, chill or venom | Orb + Chaos + Gigantic = *Chaos Orb* |
| ⏸️ **Stasis** | hangs frozen in the air for a second before flying (instant spells go off late), perfect for traps | Grenade + Stasis + Explosive = *Time Bomb* |
| 💀 **On Kill** / 🏓 **On Bounce** / 📡 **Proximity** | new triggers: chain reactions on every kill, a payload on every bounce, and a proximity fuse | Chain + On Kill → Chain = *Reaper's Chain* |

Swaps, pulls, rewinds and walls follow the same rules as damage: nothing works during the grace period, and Spell Lab practice spells only affect training dummies.

Wands work like Noita: a wand casts its slotted spells left to right. Multicast wands fire several at once and shuffle wands fire them in random order. When a wand reaches the end of its spells, it recharges.

**How to craft, step by step:** press **B** to open the Spellbook. Open the **Parts** tab of your bag (the middle column) and click a **Form** part, then optionally an **Element** and some **Modifiers**. Check the preview, then press **Forge Spell**. The new spell lands in your bag, already selected, so just click an empty wand slot to equip it. For a trigger spell, add a Trigger part, click any spell in your bag, and press **Use as payload** before forging.

The full list of every part, spell, map and kit is in **[docs/CATALOG.md](docs/CATALOG.md)**.

## Maps

| | Map | Size | What makes it different |
|---|---|---|---|
| 🌳 | **Verdant Isle** | radius 450 | flower meadows, autumn trees, a winding river with wooden bridges, snow-capped mountains, a **windmill** and the glowing **Ancient Oak**. The classic |
| 🏔️ | **Frostpeak** | radius 420 | snowfields at dusk under an **aurora**, frozen rivers you can walk on, glowing ice crystals, snowmen, a giant **Ice Spire** and a cosy **hunter's lodge** |
| 🌋 | **Ashen Wastes** | radius 400 | a smoking **volcano**, lava rivers (roads cross on raised causeways), obsidian, basalt columns, ember vents, a **dwarven forge** and an **obsidian gate**. The lava burns |
| 🏜️ | **Sandsea Ruins** | radius 480 | stepped mesas and striped canyon walls, palm oases ringed with grass, hoodoos, a **step pyramid** with the chest on top and a colourful **bazaar**. The biggest map |
| 🍄 | **Fungal Hollow** | radius 380 | a glowing night forest of giant mushrooms, glowing flowers and fireflies, a **fairy ring** and a hollow **giant stump** |

Every match generates a fresh layout of the chosen map: hills, rivers and lakes, ten landmarks (the classic ruined tower, shrine, camp and watchtower, restyled for each map, plus the map's own two), and dirt or stone roads from the plaza out to each landmark. Each map has its own colour grading, clouds, lighting and weather (pollen, snow, ash, dust or spores).

**The spawn is spread out.** The 12 pedestals stand 72 studs from the centre, about 38 studs apart, around a 100-stud-wide plaza that's patterned and decorated in the map's colours (flower planters, ice crystals, braziers, obelisks or glowing mushrooms). The cornucopia holds 10 chests: 6 on the dais around the Mana Spire and 4 out on the plaza. Another 24–30 chests are scattered at least 55 studs apart, and more sit in the landmarks. That is roughly one chest per 10,000–13,500 square studs, so loot is worth travelling for. The storm starts just outside each map's edge, and bigger maps get a longer storm.

## Controls

| | PC | Mobile | Gamepad |
|---|---|---|---|
| Cast | hold Left Mouse | **Cast** button (aims at screen centre) | R2 |
| Switch wand | 1-4, Q to cycle | tap the hotbar | L1 / R1 |
| Spellbook & Spellforge | **B** | **📖 Spellbook** (left), or **Bag** | Y |
| Grimoire (encyclopedia) | **H** | **📜 Grimoire** (left) | |
| 🛠 Dev panel (Studio and the game's owner only) | **`** | **🛠 Dev** button | |
| Join the game | walk through the Plaza's portal, or **▶️ PLAY**, then pick a mode | **▶️ PLAY** | |
| Switch game mode | **🔄 Queued for … · change** (in the library) | the same | |
| Leave the queue | the library's portal, or **↩ Leave queue** | **↩ Leave queue** | |
| Jump off the magic carpet | **Space**, or **🧞 JUMP OFF** | the jump button | A |
| Steer a glide | W A S D | the thumbstick | left stick |
| Open chest | E (hold) | tap the prompt | X |
| Take everything from a chest | F | **Take All** | |
| Potions | Z X C V | tap the potion | |
| Coffers, Tailor's Loom, wardrobe | the Plaza's stalls, or **👘 Wardrobe** (left) | the same | |
| Auction house | the Gilded Gavel pavilion, or **⚖️ Auction House** (left) | the same | |
| Achievements and daily streak | **🏆 Achievements** (left, in the Plaza or the library) | the same | |
| Chat | **/** | the chat button | |
| Close any window | **✕** in its corner | the same | |

(Tab is left free for Roblox's player list.)

**Balance.** Spells hit for 60% of their listed power (`Config.Combat.SpellDamageMultiplier`; the numbers in tooltips already include it), so fights last long enough to react. Chests hold only 1–4 items each (`rolls` in `src/shared/LootTables.lua`), and most also hold a **Healing Draught** (50–80% of chests, by type), so your bag doesn't overflow and you can recover between fights. The menu buttons (Spellbook, Grimoire, Class, Spectate, Wardrobe, Auction House and your coins) sit in one column on the left, and they tuck away while a window is open.

The Spellbook has three columns: your **wands** on the left (each card shows its mana, cast delay, recharge and perks as chips, and its slots underneath), your **bag** in the middle (tabs for **Spells**, **Parts** and **Potions**, grouped by type with a name under every icon), and the **Spellforge** on the right with a live preview of the spell you're building. Hover anything for its full details.
- **Slot a spell:** click a spell in your bag, then click a wand slot.
- **Unslot a spell:** right-click a spell in a wand, or select it and press Unslot.
- **Craft a spell:** click parts to drop them into the Spellforge, then press **Forge Spell**.
- **Add a payload:** select a bag spell and press *Use as payload*.

## Play it in Roblox Studio

### Easiest way: open the place file
1. Open **`build/ManaWars.rbxlx`** in Roblox Studio (File → Open from File).
2. Press **Play** (F5). You appear in Arcanum Plaza, and the tutorial starts on your first visit. Practise as long as you like. When you're ready, walk through the portal at the north end (or press **▶️ PLAY**) and pick a mode. For Survival Games the map vote opens in the library and a match starts when it closes. A Battle Royale takes off after 30 seconds, and a duel starts with a bot after 15 seconds alone. Bots fill empty spots, so you can play every mode solo.

If you change the code in `src/`, rebuild the place file with `rojo build -o build/ManaWars.rbxlx`.

### Developer way: live-sync with Rojo
1. Install [Rokit](https://github.com/rojo-rbx/rokit) and run `rokit install` in this folder. This installs Rojo, StyLua, selene and luau-lsp at the pinned versions.
2. Install the Rojo plugin in Studio.
3. Run `rojo serve`, then click **Connect** in the Studio plugin. Edits to `src/` now sync live.

### Test everything for free: the 🛠 Dev panel
Press **`** (the backquote key, left of 1) or click **🛠 Dev** at the top right. It shows up for everyone in Studio play tests. In your published game it shows up only for you (the experience's owner) and any user ids you add to `Config.Dev.AdminUserIds` (add yours there if the game belongs to a group). The server checks every request, so nobody else can use it.

- **⭐ Unlock everything** (one click): every kit, +100,000 Enchanted Coins, free coffers, one part for every robe/hat design, a Mythic sigil and gem for every aura, a finished outfit at every rarity (and a matched Mythic one put on you), every familiar species plus a Shiny Mythic of each (a Mythic Dragonling summoned), and a full loadout in every match: Mythic and Legendary wands, a bag of premade spells, 20 of every spell part and every potion. Press it again later and it just tops up the coins.
- **Coins & coffers:** add coins, reset to 0, free coffers on or off.
- **Cosmetics:** pick a rarity (and Shiny), then give 6 parts, wear a whole outfit, or get every familiar at that rarity.
- **Kits:** unlock every kit, back to normal, or **lock** them to test the kit shop as a new player would see it.
- **Fighting:** full loadout, god mode, infinite mana, a wand of any rarity, or any of the 69 premade spells into your bag.
- **Match:** start a Survival match right now (skips the vote), start a Battle Royale (skips the gathering), queue for a duel, skip the countdown or grace period, jump the clock 60s ahead (chest refill, storm circles), end the match, choose how many bots fill a Survival match, knock out the bots, refill every chest.
- **Market & profile:** put items up for sale from a "Test Merchant" so you can test buying on your own, or reset your profile to a brand new player's (it asks twice).

Things to know:
- **Studio play tests save to separate test data** (`Config.Dev.SeparateStudioData`), so coins and items you give yourself in Studio never show up in the live game.
- **Items from the dev panel can't be sold** on the auction house, so test items never reach real players.
- **Testing a kit purchase:** set the game pass ids first (see below), press **Lock (test the shop)**, then buy a kit in Studio. Studio purchases are test purchases and don't charge Robux. Note that `Config.Kits.StudioUnlocksAll` already unlocks every kit in Studio while you aren't locked.
- **Testing with more players:** in Studio's **Test** tab, choose a number of players under **Clients and Servers** and press **Start**. Every test player gets the panel.
- To turn the panel off in live servers entirely, set `Config.Dev.Enabled = false`. It always works in Studio.

### Before you publish
- **Server size:** set the place's **Max Players**. You'll find it in Studio under *File → Game Settings → Places* (click the place's ⋯ → Edit), or in the place's settings on the Creator Dashboard. **50** lets a Battle Royale fill up. Survival Games still takes 12 per match, and anyone beyond that waits in the library for the next round, first come first served. Duels run alongside, two players at a time. If you'd rather keep servers small, 12 to 16 works too, and bots fill the Battle Royale.
- **DataStores and MemoryStore:** in *Game Settings → Security*, turn on **Enable Studio Access to API Services** so coins, outfits, wins, kills and tutorial progress save while you test in Studio. Published games always have access. The auction house uses MemoryStoreService for the shared market. Without API access it falls back to a market for the current server only, and nothing is saved.
- **Kits for sale:** create one game pass per paid kit on the Creator Dashboard (*your experience → Monetization → Passes*), priced at its tier (see [Kits and tiers](#kits-and-tiers)), and paste each pass id into `src/shared/Config.lua` → `Config.Kits.GamePassIds`. A kit whose id is still `0` shows as "not on sale yet". While you test in Studio, every kit is unlocked (`StudioUnlocksAll`).
- **Voice chat (optional):** turn it on under *Game Settings → Communication* (**Enable Microphone**). Roblox voice is spatial, so players hear mages near them and voices fade with distance. It matches proximity text chat with no extra code. Only players who have verified voice on their accounts can use it.
- **Badges (optional):** create one per achievement you want as a badge (*Engagement → Badges*) and paste the ids into `Config.Achievements.BadgeIds`. See [Daily reward, achievements and the leaderboard](#daily-reward-achievements-and-the-leaderboard).
- **Streaming** is turned off (`Workspace.StreamingEnabled = false` in `default.project.json`) so every client always sees the whole arena.
- **Sounds:** the game uses sounds that ship with every Roblox client, so it works out of the box. Swap the ids in `src/client/Controllers/Sounds.lua` for Creator Store sounds to make it sound much better.

## Kits and tiers

Every kit (class) gives a starting wand or two, a few spells, some spell parts, potions, and **one random spell part each match**, in Survival Games and the Battle Royale (duels hand out their own random loadout instead). The kit you pick at the Class Altar is saved with your profile, so it's still picked next time you play. The Apprentice is free. Every other kit is a one-time game pass, priced by tier:

| Tier | Price | Kits | Random bonus part each match |
|---|---|---|---|
| Novice | free | 📖 Apprentice | 100% Common |
| Copper | R$80 (~$0.99) | ❄️ Cryomancer, ⛰️ Geomancer, 🌪️ Windwalker | 75% Common · 25% Uncommon |
| Silver | R$240 (~$2.99) | 🔥 Pyromancer, ☠️ Plaguebringer, ⚡ Stormcaller | 30% Common · 55% Uncommon · 15% Rare |
| Gold | R$400 (~$4.99) | 🌌 Voidwalker, 🩸 Bloodmage, ☀️ Lightbringer | 40% Uncommon · 50% Rare · 10% Epic |
| Arcane | R$800 (~$9.99) | 🔧 Artificer, ⏳ Chronomancer, 🐝 Swarmlord | 55% Rare · 40% Epic · 5% Legendary |
| Astral | R$1200 (~$14.99) | ⛈️ Stormlord, 🕳️ Void Archon | 20% Rare · 60% Epic · 20% Legendary |
| Archmage | R$2000 (~$24.99) | 🌟 Archmage, ☄️ Harbinger | 55% Epic · 45% Legendary |

- **Copper** kits are flavour: a Common wand like the Apprentice's with a small elemental bonus, themed spells and one part.
- **Silver** and **Gold** kits get Uncommon and Rare wands with perks and a third spell.
- **Arcane** kits are built around the new spells (sawblades and walls, time bombs, swarms).
- **Astral** and **Archmage** kits get Epic and Legendary wands, a second wand, and Legendary spells and parts.

Everything in a kit (contents, tier, price, odds) lives in `src/shared/Classes.lua`. Dollar amounts assume the standard ~80 Robux per $0.99; you set the actual Robux price on each game pass. Roblox Premium members get every Copper kit free (`Config.Kits.PremiumFreeTier`, 0 turns it off). Bots only ever pick kits up to Gold.

The bonus part is a random reward from a paid item, so the odds are shown in the kit shop and in the Grimoire before anyone buys, which is what Roblox's rules on paid random items ask for. Some regions don't allow paid random items at all: the game asks Roblox (`PolicyService`) when each player joins, and where they're restricted, paid kits leave the random bonus part out and the kit shop says "not offered in your region" before anyone buys. The free Apprentice kit's bonus part isn't paid, so everyone gets it.

## Enchanted Coins, robes and the auction house

**Coins.** Every match pays coins, so everyone earns something:

| Mode | Coins |
|---|---|
| Survival Games | by finishing place: 12 for 1st, 11 for 2nd ... 1 for 12th |
| Battle Royale | by place among real players only: N coins for the best of N players, down to 1 (50 down to 1 in a full match) |
| 1v1 Duel | 10 for a win, 2 for a loss |

Outfits with the **Fortune** enchantment add a bonus on top of placement coins (not in duels). The amounts live in `Config.Economy.CoinsForFirst`, `Config.Royale.CoinsForFirst`, and `Config.Duel.WinCoins` / `LoseCoins`.

New players start with 60 coins and a plain starter robe and hat. Coins can't be bought with Robux. They're only earned by playing.

**Coffers** (the Coffer stall, or 👘 Wardrobe & Coffers → Coffers) hold robe and hat parts. Pricier coffers roll rarer parts, and some designs only come from one coffer:

| | Coffer | Price | Items | Odds | Familiar chance per item |
|---|---|---|---|---|---|
| 👝 | Tattered Satchel | 50 | 1 | 98% Common · 1.8% Uncommon · 0.2% Rare | 3% |
| 🧰 | Apprentice's Coffer | 100 | 1 | 70% Common · 24% Uncommon · 5% Rare · 1% Epic | 5% |
| 🧳 | Enchanter's Chest | 300 | 2 | 30% Common · 40% Uncommon · 22% Rare · 7% Epic · 1% Legendary | 8% |
| 🗝️ | Archmage's Vault | 500 | 2 | 30% Uncommon · 40% Rare · 22% Epic · 7% Legendary · 1% Mythic | 10% |
| 🌠 | Celestial Reliquary | 1000 | 3 | 30% Rare · 40% Epic · 24% Legendary · 6% Mythic (halos, starcrowns, crystalweave, celestial robes, Star Whales and Eclipse Cats only drop here) | 15% |

**The Tailor's Loom.** A **robe** is stitched from a Cloth, a Trim and a Sigil. A **hat** is a Hat shape, a Band and a Gem. Every part rolls its own design (65 across the six slots), one of 36 colours, one of 10 materials (wool up to radiant neon and ethereal forcefield), 1–3 enchantments, and, on Sigils and Gems, one of 20 auras. That's about 146,000 distinct-looking parts, and a finished outfit is any six of them. Garments can be unpicked back into parts, and unwanted parts salvaged for coins.

**Auras and mixed rarities.** The rarest Sigils and Gems give off effects: embers, frost, lightning, billowing smoke, void wisps, holy light, inferno, storm, stardust, prismatic, eclipse and more. When parts of different rarities are stitched together:
- a garment's **resonance** is the average rarity of its three parts (rounded down)
- its aura shines at the aura part's own rarity, but **never more than one tier above the resonance**. A Legendary gem on a Common hat glows faintly. On Epic-or-better parts it shines at full strength
- auras are visible from Rare strength, and add a second, faster flourish at Mythic. The glowing ones (frost, lightning, void, runes, holy light, inferno, storm, stardust, prismatic, eclipse) also light up the area around you from Epic strength
- a robe and a hat with the **same aura**, both at Epic strength or better, leave a **trail** of it behind you as you move

So mixing rarities always works, but a matched set looks the best.

**Enchantments** are small, capped bonuses that apply in matches: movement speed, max health, wand mana and regen, cast delay, recharge, damage reduction, crit, lifesteal, health regen, jump, coin Fortune, shorter burns and chills, and +damage for one element. Rarer parts carry more and bigger ones, but every stat has a cap (e.g. +12% speed, +25 health), so a full Mythic outfit is an edge, not an auto-win. Outfits are locked in once a match starts. The full tables are in [docs/CATALOG.md](docs/CATALOG.md#robes-hats-and-coffers).

**Familiars.** Any item from a coffer can turn out to be a **familiar** instead (see the last column above). It rolls its rarity from the same odds, and 1 in 40 is **Shiny** (golden sparkles). Summon one from **👘 Wardrobe & Coffers → 🐾 Familiars** and it follows you around the Plaza and into matches. Fliers hover by your shoulder and walkers trot at your heels. Everyone sees everyone's familiar.
- **21 species** across every rarity, each with 2–4 colours. From Common: Dust Bunny, Pebble Toad, Candle Mouse, Wisp. From Uncommon: Lucky Tabby, Paper Crane, Gel Slime, Luna Moth. From Rare: Ember Fox, Frost Owl, Tome Mimic, Sky Eel. From Epic: Crystal Golemling, Void Jelly, Storm Raven, Hex Skull. From Legendary: Dragonling, Phoenix Chick, Thunder Kirin. Mythic only: Star Whale and Eclipse Cat. A species can roll at its own rarity or higher, so there are 532 distinct familiars to collect.
- **Common and Uncommon familiars are purely visual.** From **Rare** up, each species has one minor power that grows a little with rarity:

  | Power | Rare → Mythic | Who has it |
  |---|---|---|
  | Quickpaw | +2% → +5% movement speed | Dust Bunny, Thunder Kirin |
  | Springheel | +4% → +10% jump height | Pebble Toad |
  | Mana Sip | +3% → +6% mana regen | Wisp |
  | Lucky Charm | +4% → +10% coins from matches | Lucky Tabby, Star Whale |
  | Guardian | −2% → −5% damage taken | Gel Slime, Crystal Golemling |
  | Mend | +0.2 → +0.5 health per second | Luna Moth |
  | Attuned | +3% → +6% damage of its element | Paper Crane (Wind), Tome Mimic (Arcane), Sky Eel (Lightning), Hex Skull (Blood) |
  | Keen Nose | outlines the nearest unopened chest within 30 → 60 studs | Candle Mouse, Storm Raven |
  | Night Eyes | every 12s, briefly outlines the nearest enemy within 50 → 80 studs (only you see it) | Frost Owl |
  | Nip | every 8s, darts at an enemy within 14 studs for 2 → 5 damage | Ember Fox, Void Jelly, Dragonling, Eclipse Cat |
  | Last Ember | when you fall, bursts for 8 → 20 fire damage around you | Phoenix Chick |

  Familiars follow the normal damage rules: no nipping during the grace period, and in the Spell Lab they only nip training dummies.
- **Rarer familiars look grander:** Rare ones glow, Epic ones sparkle and get glowing eyes, Legendary ones carry an elemental aura (flames, frost, sparks, smoke…), and Mythic ones also leave a trail.
- Familiars are built from parts and animated on each player's own computer (flapping wings, wagging tails, swaying tentacles, orbiting crystal shards), so they cost no network traffic. About a third of bots bring a humble familiar along too.

**The auction house (the Gilded Gavel).** List any loose part, unworn robe or hat, or familiar that isn't following you, for a price in coins (up to 10 listings at once). Other players browse by type, rarity and price, and buy with a click and a confirm. The house keeps 10%. Unsold items come back after 48 hours, and you can take a listing back any time before it sells.
- The market is **shared by every server**. Listings live in a MemoryStore sorted map, so a player in another server can buy your item.
- Items are held in escrow while listed, buying is atomic (two buyers can never get the same item), and sellers who are offline or in another server are paid through a DataStore mailbox the next time they play.
- Profiles (coins, wardrobe, listings, stats) are saved with a session lock, so joining two servers at once can't duplicate items.

## Daily reward, achievements and the leaderboard

- **Daily reward.** The first time you play each day (days start at midnight UTC) you get **3 Enchanted Coins** (`Config.Rewards.DailyCoins`). Come back on consecutive days to build a streak. If you're still online at midnight, the next day's reward arrives without rejoining.
- **Achievements.** 19 lifetime goals, each paying coins once (345 in all): first kill, 25 and 100 kills, first win, 10 and 50 wins, 5 duel wins, a Battle Royale win, a top-3 finish, 25 matches, forging 10 spells, opening 100 chests and 10 coffers, stitching a robe or hat, finding 5 familiars or a Shiny one, a first auction sale and a 7-day streak. Open them with **🏆 Achievements** in the Plaza or the library to see your progress bars. The full list is in [docs/CATALOG.md](docs/CATALOG.md#achievements). Stats players had before this update count, so veterans unlock theirs the first time they join.
- **Roblox badges (optional).** Every achievement can also award a real badge that shows on players' profiles. Create the badges on the Creator Dashboard (*your experience → Engagement → Badges*) and paste each id into `Config.Achievements.BadgeIds` under the achievement's id (e.g. `Victor = 2150000001`). Players who already unlocked the achievement get the badge the next time they join.
- **The Hall of Champions.** A gilded board behind the spawn in the Plaza has a global leaderboard for each game mode: the **top 10 by Survival Games wins, Battle Royale wins and duel wins**, plus a fourth column for **kills in every mode**, across every server, all time. Scores are saved after each match or duel and when a player leaves, and each server re-reads the lists every 2 minutes (`Config.Leaderboard`). It needs DataStores, so turn on API access to see it in Studio.

### Analytics

The game reports to Roblox's built-in analytics (*Creator Dashboard → your experience → Analytics*), so you can see where new players drop off and how coins flow:

- **Onboarding funnel:** Joined → Finished the tutorial → Joined the queue → Finished a match → Opened a coffer. Each step is logged once per player. Players from before this update aren't counted as new.
- **Economy:** every Enchanted Coin earned (placements, daily reward, achievements, salvage, auction sales) and spent (each coffer, auction purchases), with the balance after it. Coins from the Dev panel are left out.
- **Custom events:** `MatchFinished` (value = finishing place, broken down by map, kit and mode), `MatchKills`, `DuelFinished` (won or lost, against a player or a bot), `ModeQueued` (which modes players pick), `KitPicked`, `KitPurchased`, `AchievementUnlocked` and `DailyStreak`.

Set `Config.Analytics.Enabled = false` to turn it all off. Analytics can never break the game: every call is wrapped so a failure is just skipped.

## Spell effects

Every spell is drawn on each client from small server events (`src/client/Controllers/FXController.lua`, with the building blocks in `VFX.lua`), and each element has its own look:
- **Projectiles** have a white-hot core, a glow halo, a hot inner streak and a coloured trail, plus the element's own particles: flames for Fire, falling snow for Frost, arcs leaping off Lightning bolts, motes sucked inward for Void, dust for Earth, and so on. A bright light travels with each one.
- **Impacts** flash, throw a shock ring, burst into element particles and sparks, and light up the area.
- **Explosions** are layered: a white flash, a fireball, a forcefield shell, a shockwave racing across the ground with a dust ring, sparks that arc down, smoke for burning elements, a big light flash and camera shake. Earth throws rock chunks, Frost throws ice shards, Lightning crackles, Radiant fires light rays, Void implodes, Chrono spins clock rings and Chaos bursts in random colours.
- **Novas** send out two rings and radial streaks. **Beams** have a spiralling sheath, particles all along their length and flashes at both ends (Lightning beams are jagged bolts). **Chain lightning** forks and flickers twice. **Zones** boil with element particles inside a pulsing rim. **Vortexes** suck particles in, and **blinks** leave a swirling column. Every cast also flashes a magic circle at the wand tip.

All of it uses particle textures that ship with Roblox, so no uploads are needed. When lots of spells go off at once, particle counts scale down automatically to keep the frame rate up.

## Multiplayer

Mana Wars is multiplayer out of the box, like the original survival-games servers. Each Roblox server has its own hub, queues and back-to-back matches:

- Everyone in the server shares the Plaza. Each player decides when to join a queue, and for which mode. Everyone queued for Survival Games votes on the map and is placed on the pedestals together, up to 12 players. A Battle Royale takes up to 50. Survival Games and Battle Royale take turns in the main arena, while duels run at the same time in their own floating arenas.
- Anyone can watch a running match from the hub or the library with **👁 Spectate the match**.
- **When does a match start?** As soon as `Config.Bots.MinRealPlayers` players (default 1) are queued for Survival Games, the 30-second vote begins (for a Battle Royale, `Config.Royale.MinRealPlayers` starts the 30-second gathering). Everyone else in the server can still join before it closes. On a busy server you may want to raise `MinRealPlayers` (e.g. to 4) so matches wait for a crowd.
- **Bots are only filler.** They top a match up to `Config.Bots.FillTo` (8) participants, or `Config.Royale.FillTo` (20) in a Battle Royale, so a busy server plays with no bots at all. A lonely duelist gets a bot after `Config.Duel.BotAfter` seconds. Set `Config.Bots.Enabled = false` to require real players (`Config.Match.MinPlayers`).
- `Config.Queue.StayQueuedAfterMatch` (on by default) keeps players in the queue between matches. Turn it off to send everyone back to the Plaza after each match.
- **Proximity chat.** Text chat only reaches mages within **70 studs** of whoever is talking (`Config.Chat.Range`), and chat bubbles fade at the same distance. Hub chatter stays in the hub, the queue in the library talks among itself, and in a match you only talk to whoever is close, so nobody can call out positions from across the map. Eliminated players respawn far from the arena, so they can't whisper to the living. Set `Config.Chat.Proximity = false` for one server-wide chat. The server applies the filter (`ChatService`), so clients can't get around it.
- **Test multiplayer in Studio:** open the **Test** tab, pick a number of players under **Clients and Servers** (e.g. 3), and press **Start**. Studio opens a server window plus one window per player.

## Tuning the game

Almost every number lives in **`src/shared/Config.lua`**: match timings (the grace period, vote length, storm speed and damage), duels (`Config.Duel`) and the Battle Royale (`Config.Royale`: carpet height, speed and glide, the storm circles, bot fill), the queue, how many bots fill a match, chest counts, the Spell Lab kit, inventory limits, spell nesting depth, and the kit game passes.

| Want to... | Edit |
|---|---|
| add or rebalance a spell part | `src/shared/Spells/SpellParts.lua` (each part is a small table with an `apply` function) |
| add a premade spell | `src/shared/Spells/PremadeSpells.lua` |
| change wand generation | `src/shared/WandGenerator.lua` |
| change chest loot odds | `src/shared/LootTables.lua` |
| add or change a kit, its tier, price or bonus odds | `src/shared/Classes.lua` (and its game pass id in `Config.Kits`) |
| add a map, or change a map's size, terrain (rivers, mesas, volcano), colours, decoration, landmarks, clouds, colour grading, weather or lighting | `src/server/Map/MapDefs.lua` (one table per map) |
| change the Battle Royale island: its realms, named places, chest count, decoration | `MapDefs.Royale` in `src/server/Map/MapDefs.lua` (layout in `RealmGen.lua`, terrain in `TerrainGen.makeRealmLand`) |
| change the towns, villages and castles | `village`, `town`, `castle` and friends in `src/server/Map/Landmarks.lua` |
| change the duel arenas | `src/server/Map/DuelArena.lua` |
| change the magic carpet's look | `src/client/Controllers/CarpetController.lua` (its path and rules are in `CarpetService.lua`) |
| change the game mode menu's names and descriptions | `src/shared/Modes.lua` |
| change trees, rocks, flowers and other decoration | `src/server/Map/Decor.lua` |
| change or add landmarks (ruins, the windmill, the pyramid...) | `src/server/Map/Landmarks.lua` (list a new one in a map's `pois`) |
| change bridges, the volcano's smoke or the aurora | `src/server/Map/Scenery.lua` |
| change the cornucopia, chests or satchels | `src/server/Map/Structures.lua` (and the spawn ring's size in `Config.Arena`) |
| change the daily reward | `Config.Rewards.DailyCoins` |
| change Battle Royale or duel coins | `Config.Royale.CoinsForFirst`, `Config.Duel.WinCoins` / `LoseCoins` |
| add or change achievements (goals, coin rewards, icons) | `src/shared/Achievements.lua` (and badge ids in `Config.Achievements`) |
| change the leaderboard's size or refresh rate | `Config.Leaderboard` |
| change spell damage overall | `Config.Combat.SpellDamageMultiplier` |
| change how much is in a chest, or the healing potion odds | `Tiers` in `src/shared/LootTables.lua` |
| change the hub (Arcanum Plaza) | `src/server/Map/Hub.lua` (shared pieces such as portals, lecterns and signs are in `Props.lua`) |
| change the library | `src/server/Map/Lobby.lua` |
| change the tutorial or Grimoire text | `src/client/Controllers/TutorialController.lua`, `GrimoireController.lua` |
| change coin payouts, starting coins, the auction fee or listing limits | `Config.Economy` in `src/shared/Config.lua` |
| add robe/hat designs, colours, materials, auras or enchantments, or change coffer prices and odds | `src/shared/Cosmetics.lua` |
| add a familiar species or colour, change powers, familiar odds or the shiny chance | `src/shared/Familiars.lua` (and its body in `src/client/Controllers/FamiliarBuilder.lua`) |
| change how outfits and auras are built on characters | `src/shared/OutfitBuilder.lua` |
| change chat range, or turn proximity chat off | `Config.Chat` in `src/shared/Config.lua` |
| re-colour the UI, or change fonts | `src/client/UI/Theme.lua` (every screen uses these colours) |
| change the window frame, cards, tabs or buttons | `src/client/UI/Widgets.lua` |
| change spell effects | `src/client/Controllers/FXController.lua` (what each spell draws) and `VFX.lua` (element styles and building blocks) |

After changing game data, run `lune run tools/gen_docs` to refresh `docs/CATALOG.md`.

## How the code is organised

```
src/
  shared/        (ReplicatedStorage.Shared)  game data + logic used by both sides
    Spells/        SpellParts, SpellBuilder (recipe -> stats), PremadeSpells, SpellNames
    WandGenerator, LootTables, Classes, Items, Consumables, Rarity, ProjectileSim, Remotes
    Cosmetics (robe/hat parts, coffers, resonance, enchantments), OutfitBuilder (dressing characters),
    Familiars (species, powers, coffer rolls), Modes (the game modes on the Play menu)
  server/        (ServerScriptService.Server)
    Services/      MatchService (the main arena's game loop: Survival Games and Battle Royale), QueueService
                   (hub <-> per-mode queues), VoteService (map vote), DuelService (1v1 duels),
                   CarpetService (the Battle Royale's magic carpet and gliding), StormCircles (its storm circles),
                   CastingService (wand decks + mana),
                   SpellExecutor (forms, impacts, triggers), ProjectileService, ZoneService,
                   DamageService, StatusService, InventoryService (Spellforge), ChestService,
                   PracticeService (training dummies), BotService, ClassService, MapService,
                   DevService (the 🛠 Dev panel's tools, admins only),
                   AchievementService, DailyRewardService, LeaderboardService (the Hall of Champions),
                   AnalyticsTracker (Roblox analytics), Events (the bus they all listen on),
                   ChatService (proximity chat), DataService (session-locked profiles), WardrobeService (coins, coffers, crafting,
                   outfits), FamiliarService (Nip, Last Ember), AuctionService (the cross-server auction house)
    Map/           MapDefs (the 5 maps + the Battle Royale island), TerrainGen (hills, rivers, mesas, volcano,
                   roads, and the realm island's blended biomes), RealmGen (the Battle Royale island's layout),
                   DuelArena (floating duel arenas), Decor (trees, rocks, flowers), Landmarks (points of interest,
                   towns, villages, castles), Scenery (bridges, volcano smoke, aurora, floating place names),
                   Structures (cornucopia, chests), Hub (Arcanum Plaza), Lobby (the library), Props (shared building blocks)
  client/        (StarterPlayerScripts.Client)
    Controllers/   HUD, Spellbook/Spellforge, Grimoire, Tutorial, chest window, lobby (join/leave queue,
                   vote, kit shop, spectate), the Play menu (ModeMenuController), the magic carpet and gliding
                   (CarpetController), Wardrobe (coffers, Tailor's Loom, familiars), Auction house,
                   familiars (FamiliarController + FamiliarBuilder), the 🛠 Dev panel (DevController),
                   Achievements window (AchievementsController), chat note (ChatController), input, effects (FXController + VFX),
                   storm, weather
    UI/            small UI toolkit: Theme (colours, fonts), Widgets (window frame, tabs, cards, item rows,
                   buttons, tooltips), Dock (the menu column), Create, ItemInfo, CosmeticInfo
```

The server is authoritative. Clients only send requests like "cast at this point", "open/take from chest", "inventory action", "join/leave the queue" and "vote", and the server validates each one (mana, cooldowns, distance, part counts). Projectiles are simulated on the server. Each client simulates the same motion locally for smooth visuals, and the server corrects anything that depends on the world, such as bounces or homing.

## Tests

The game logic is tested outside Roblox:

```bash
python3 tools/run_tests.py          # unit tests for spells, wands, loot, kits, coffers, crafting, auras and familiars (needs the `luau` CLI)
lune run tools/sim/combat           # every premade spell, the wild parts (walls, hydra, fractal, swaps, rewinds...), 1500 random spells, Spell Lab rules
lune run tools/sim/client           # real client UI + real server: forge, slot, loot, cast, buy a kit, the Play menu, join/leave the queue, vote, Grimoire, the tutorial,
                                    #   open coffers, stitch and wear a robe, outfits on R15/R6 bodies, sell/buy/cancel on the auction house,
                                    #   saving and rejoining, every spell effect in every element (drawn and cleaned up), and
                                    #   familiars: every species at every rarity, summoning, each kind of power, trading, saving,
                                    #   the dev panel (Unlock Everything, switches, strangers locked out, profile reset),
                                    #   proximity chat (near/far/between lives, the off switch), and the daily reward streak,
                                    #   achievements (unlocks, coins, badges, the window), the global leaderboard and analytics events,
                                    #   switching modes, the duel HUD, the magic carpet (riding, jump button, glide, place names) and storm circles
lune run tools/sim/match            # boots the real server: spawn in the hub, walk through the portal, pick Survival Games, two full matches
                                    #   with bots (distinct finishing places, exact coin payouts, saved profile), leave the queue,
                                    #   start / skip / end a match from the dev panel, the Hall of Champions board, then a whole
                                    #   Battle Royale (20 mages board the carpet, jump, glide, land, storm circles) and a duel against a bot
lune run tools/sim/maps             # builds the hub and the library and generates all 5 maps and the Battle Royale island, checking chests,
                                    #   spacing, decoration, named places and that storm circles always nest
lune run tools/sim/glyphs           # fails on any symbol or emoji Roblox would draw as a square (✦, ✕, ⚔ without U+FE0F, 💰...)
```

**Screenshots of every screen, without opening Studio.** The client sim can save each screen it opens (HUD, Spellbook, chest, kit shop, wardrobe, coffers, Tailor's Loom, auction house, dev panel...) and a small Chromium script draws them as PNGs:

```bash
MANA_SHOTS=build/ui lune run tools/sim/client   # saves build/ui/*.json, one per screen
node tools/ui/render.cjs build/ui/*.json        # draws build/ui/*.png (needs Node and Playwright)
```

The PNGs are approximate: they use stand-in fonts and estimate how text wraps. They're good for checking layout and colours. Check the finer details in Studio.

**Pictures of the maps and outfits** work the same way. `mapshot` generates arenas with the real map code and saves what it built, and `maprender` draws an aerial view, the cornucopia, every landmark and a ground-level vista of each (or a line-up of mannequins wearing every robe and hat):

```bash
lune run tools/sim/mapshot build/maps                  # every arena (add map ids to pick, Royale for the Battle Royale island, Hub for the hub + library, Outfits for the line-up)
node tools/ui/maprender.cjs build/maps/*.json          # needs Node, Playwright and three (npm install three playwright)
```

These have no Roblox textures, terrain grass or shadows, so the game looks better than they do.

The `tools/sim` scripts run the actual game modules on a small fake engine (`tools/sim/mock.luau`) under [Lune](https://lune-org.github.io/docs). GitHub Actions runs all of these, plus type checking and a Rojo build, on every push.

## Known limitations / ideas for next steps

- **Visuals are built from code.** The plaza, library, trees and ruins are made from parts (the blocky look is an intentional Minecraft nod), icons are emoji, and there are no custom meshes or animations yet. Dropping in Creator Store models for chests, wands and bookshelves would be a big visual upgrade.
- **Bots walk in straight lines and jump when stuck.** They don't pathfind, which is fine on open terrain but clumsy around ruins.
- **Balance is a first pass.** Use `Config.lua`, `MapDefs.lua` and `SpellParts.lua` to tune it once real players are in.
- **One server = one hub and one big match at a time** (Survival Games or a Battle Royale, plus any number of duels alongside). That's how classic survival-games servers worked. Once the game is popular, a separate hub *place* that queues players from many servers and teleports full groups into match servers (`TeleportService:ReserveServer`) would let both big modes run at once and keep every Battle Royale full.
- **The Battle Royale island is big.** It takes a Roblox server several seconds to build, which is why the carpet waits for the 30-second gathering. There's no minimap yet. The floating place names and the storm walls are how you find your way.
- **Paid kits.** The top tiers are a real head start (that's the point of them), but the best gear in the game is still in the chests. Check Roblox's current monetization and paid-random-item policies before you publish.
- **Coffers are earned, not bought.** Coffers cost Enchanted Coins, which only come from playing, so they aren't paid random items. Their odds are still shown on every coffer. If you ever sell coins for Robux, the coffers become paid random items, and Roblox's rules for those (disclosed odds, age and region limits) apply.
- **The auction house shows the newest 200 listings.** That's plenty at launch. A busy market would want server-side search and paging (more sorted maps keyed by type and price).
- **Outfits are built from parts** (like everything else). Swapping the robe and hat shapes for Creator Store meshes would make them look far fancier. The auras, colours, materials and enchantments would carry over unchanged.
