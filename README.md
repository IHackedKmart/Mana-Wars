# Mana Wars

A Roblox battle royale that crosses **old-school Minecraft Survival Games** with **Noita-style spellcrafting**.

Everyone starts in a floating plaza where they can hang out and practise spells for as long as they like. Walking through the portal joins the queue for the next match. Up to 24 mages then vote on a map in a floating library and drop onto pedestals around a cornucopia of chests. When the gong sounds there's a 5-second breather. After that it's a fight, so you can risk the middle for the best loot or run for the hills. More chests are spread across a freshly generated island, and they hold three things:

- **Wands.** Randomly generated, each with its own rarity, spell slots, mana pool, cast delay, recharge time, multicast, spread and perks.
- **Fully made spells.** 69 hand-designed ones such as Fireball, Chain Lightning, Black Hole, Hydra Storm and Doom Turret, plus randomly generated ones.
- **Spell parts.** 74 parts you combine in the **Spellforge** to craft your own spells.

The chests refill halfway through, a Mana Storm closes in, and the last mage standing wins. There are 5 maps to vote on, and 17 kits to start with: a free Apprentice kit, plus 16 more sold in tiers from $0.99 to $25.

## The hub: Arcanum Plaza

Every player spawns here, and nothing pulls you into a match until you choose to go. The plaza is a floating island with:
- a mana fountain, benches, market stalls, wizard towers and floating isles, so there's somewhere to hang out
- the **Practice Range** to the east, with standing training dummies and two that slide along rails so you can practise leading your shots
- a gazebo to the west with the **Class Altar** and **Grimoire** lecterns
- a live **Next Match** board by the spawn, showing the vote countdown, how many mages are queued, and how many are still alive in the current match

- **Join the game.** Walk through the big **portal** at the north end, or press **⚔ JOIN GAME** at the top of the screen. That puts you in the queue and takes you to the library.
- **Spell Lab.** Outside a match you carry a sandbox kit: a practice staff, a twin-cast scepter, showcase spells and 3 copies of **every** spell part. Dummies never die, and practice spells can't hurt other players. The kit is swapped for your real starting kit when a match starts. **♻ Restock Spell Lab** in the Spellbook refills everything.
- **Tutorial.** On your first visit a step-by-step tutorial teaches crafting by doing. You open the Spellbook, forge a spell, slot it into a wand, hit a dummy, then build a spell with a trigger and payload. Each step finishes itself when you do it, and the next button glows.
- **Grimoire.** Press **H**, or use a lectern, to open an in-game encyclopedia. It covers how a match works, how crafting works, how wands work, every Form, Element, Modifier and Trigger, the premade spell library, the kits and their tiers and odds, and the controls. You can also replay the tutorial from it.

## The queue: the Arcane Athenaeum

Joining the game takes you to a library floating above the island. It has towering bookshelves, chandeliers, stained glass, a spinning orrery and floating books, plus a glass scrying window in the floor so you can watch the match below.

- **Map vote.** As soon as someone is queued, a 30-second vote opens: a ballot of 3 maps on the right of the screen (the map just played is left off). Only queued players can vote. Players in the hub get a heads-up and can still join. The most votes wins, ties are broken at random, and the vote is cut to 10 seconds once all 24 pedestals are spoken for.
- **The match** takes everyone in the queue, plus bots if there are fewer than 8 players. People who join mid-match wait here for the next one. They can spectate, or practise on the **Practice Terrace** through the north arch.
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

**How to craft, step by step:** press **B** to open the Spellbook. Click a **Form** part in your bag (the middle column), then optionally an **Element** and some **Modifiers**. Check the preview, then press **Forge Spell**. The new spell lands in your bag, already selected, so just click an empty wand slot to equip it. For a trigger spell, add a Trigger part, click any spell in your bag, and press **Use as payload** before forging.

The full list of every part, spell, map and kit is in **[docs/CATALOG.md](docs/CATALOG.md)**.

## Maps

| | Map | Size | Notes |
|---|---|---|---|
| 🌳 | **Verdant Isle** | radius 450 | rolling hills, lakes and ruins. The classic |
| 🏔️ | **Frostpeak** | radius 420 | snow, frozen lakes, pine forests and tall peaks |
| 🌋 | **Ashen Wastes** | radius 400 | volcanic, and the lava lakes burn |
| 🏜️ | **Sandsea Ruins** | radius 480 | dunes, sandstone ruins and oases. The biggest map |
| 🍄 | **Fungal Hollow** | radius 380 | a glowing night forest of giant mushrooms |

Every match generates a fresh layout of the chosen map. The cornucopia holds 10 chests. Another 24–30 chests are scattered at least 55 studs apart, and a few more sit in landmarks like ruined towers, shrines, camps and watchtowers. That is roughly one chest per 10,000–13,000 square studs, so loot is worth travelling for. The storm starts just outside each map's edge, and bigger maps get a longer storm.

## Controls

| | PC | Mobile | Gamepad |
|---|---|---|---|
| Cast | hold Left Mouse | **Cast** button (aims at screen centre) | R2 |
| Switch wand | 1-4, Q to cycle | tap the hotbar | L1 / R1 |
| Spellbook & Spellforge | **B** | **Bag** button | Y |
| Grimoire (encyclopedia) | **H** | **📜 Grimoire** button | |
| Join the game | walk through the Plaza's portal, or **⚔ JOIN GAME** | **⚔ JOIN GAME** | |
| Leave the queue | the library's portal, or **↩ Leave queue** | **↩ Leave queue** | |
| Open chest | E (hold) | tap the prompt | X |
| Take everything from a chest | F | **Take All** | |
| Potions | Z X C V | tap the potion | |

(Tab is left free for Roblox's player list.)

In the Spellbook:
- **Slot a spell:** click a spell in your bag, then click a wand slot.
- **Unslot a spell:** right-click a spell in a wand, or select it and press Unslot.
- **Craft a spell:** click parts to drop them into the Spellforge, then press **Forge Spell**.
- **Add a payload:** select a bag spell and press *Use as payload*.

## Play it in Roblox Studio

### Easiest way: open the place file
1. Open **`build/ManaWars.rbxlx`** in Roblox Studio (File → Open from File).
2. Press **Play** (F5). You appear in Arcanum Plaza, and the tutorial starts on your first visit. Practise as long as you like. When you're ready, walk through the portal at the north end (or press **⚔ JOIN GAME**). The map vote opens in the library, a match starts when it closes, and bots fill empty spots so you can play solo.

If you change the code in `src/`, rebuild the place file with `rojo build -o build/ManaWars.rbxlx`.

### Developer way: live-sync with Rojo
1. Install [Rokit](https://github.com/rojo-rbx/rokit) and run `rokit install` in this folder. This installs Rojo, StyLua, selene and luau-lsp at the pinned versions.
2. Install the Rojo plugin in Studio.
3. Run `rojo serve`, then click **Connect** in the Studio plugin. Edits to `src/` now sync live.

### Before you publish
- **Server size:** set the place's **Max Players**. You'll find it in Studio under *File → Game Settings → Places* (click the place's ⋯ → Edit), or in the place's settings on the Creator Dashboard. **24** fills every pedestal. Going a little higher (e.g. 30) gives the Plaza a crowd: if more than 24 people queue, the extra players wait in the library for the next round, first come first served.
- **DataStores:** in *Game Settings → Security*, turn on **Enable Studio Access to API Services** so wins, kills and tutorial progress save.
- **Kits for sale:** create one game pass per paid kit on the Creator Dashboard (*your experience → Monetization → Passes*), priced at its tier (see [Kits and tiers](#kits-and-tiers)), and paste each pass id into `src/shared/Config.lua` → `Config.Kits.GamePassIds`. A kit whose id is still `0` shows as "not on sale yet". While you test in Studio, every kit is unlocked (`StudioUnlocksAll`).
- **Streaming** is turned off (`Workspace.StreamingEnabled = false` in `default.project.json`) so every client always sees the whole arena.
- **Sounds:** the game uses sounds that ship with every Roblox client, so it works out of the box. Swap the ids in `src/client/Controllers/Sounds.lua` for Creator Store sounds to make it sound much better.

## Kits and tiers

Every kit (class) gives a starting wand or two, a few spells, some spell parts, potions, and **one random spell part each match**. The Apprentice is free. Every other kit is a one-time game pass, priced by tier:

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

The bonus part is a random reward from a paid item, so the odds are shown in the kit shop and in the Grimoire before anyone buys, which is what Roblox's rules on paid random items ask for.

## Multiplayer

Mana Wars is multiplayer out of the box, like the original survival-games servers. Each Roblox server has its own hub, queue and back-to-back matches:

- Everyone in the server shares the Plaza. Each player decides when to join the queue, and everyone queued votes on the map and is placed on the pedestals together, up to 24 players.
- Anyone can watch a running match from the hub or the library with **👁 Spectate the match**.
- **When does a match start?** As soon as `Config.Bots.MinRealPlayers` players (default 1) are queued, the 30-second vote begins. Everyone else in the server can still join before it closes. On a busy server you may want to raise `MinRealPlayers` (e.g. to 4) so matches wait for a crowd.
- **Bots are only filler.** They top a match up to `Config.Bots.FillTo` (8) participants, so a busy server plays with no bots at all. Set `Config.Bots.Enabled = false` to require real players (`Config.Match.MinPlayers`).
- `Config.Queue.StayQueuedAfterMatch` (on by default) keeps players in the queue between matches. Turn it off to send everyone back to the Plaza after each match.
- **Test multiplayer in Studio:** open the **Test** tab, pick a number of players under **Clients and Servers** (e.g. 3), and press **Start**. Studio opens a server window plus one window per player.

## Tuning the game

Almost every number lives in **`src/shared/Config.lua`**: match timings (the grace period, vote length, storm speed and damage), the queue, how many bots fill a match, chest counts, the Spell Lab kit, inventory limits, spell nesting depth, and the kit game passes.

| Want to... | Edit |
|---|---|
| add or rebalance a spell part | `src/shared/Spells/SpellParts.lua` (each part is a small table with an `apply` function) |
| add a premade spell | `src/shared/Spells/PremadeSpells.lua` |
| change wand generation | `src/shared/WandGenerator.lua` |
| change chest loot odds | `src/shared/LootTables.lua` |
| add or change a kit, its tier, price or bonus odds | `src/shared/Classes.lua` (and its game pass id in `Config.Kits`) |
| add a map, or change a map's size, chests, terrain, colours, weather or lighting | `src/server/Map/MapDefs.lua` (one table per map) |
| change trees, rocks, ruins or the cornucopia | `src/server/Map/Structures.lua` |
| change the hub (Arcanum Plaza) | `src/server/Map/Hub.lua` (shared pieces such as portals, lecterns and signs are in `Props.lua`) |
| change the library | `src/server/Map/Lobby.lua` |
| change the tutorial or Grimoire text | `src/client/Controllers/TutorialController.lua`, `GrimoireController.lua` |

After changing game data, run `lune run tools/gen_docs` to refresh `docs/CATALOG.md`.

## How the code is organised

```
src/
  shared/        (ReplicatedStorage.Shared)  game data + logic used by both sides
    Spells/        SpellParts, SpellBuilder (recipe -> stats), PremadeSpells, SpellNames
    WandGenerator, LootTables, Classes, Items, Consumables, Rarity, ProjectileSim, Remotes
  server/        (ServerScriptService.Server)
    Services/      MatchService (game loop), QueueService (hub <-> queue), VoteService (map vote),
                   CastingService (wand decks + mana),
                   SpellExecutor (forms, impacts, triggers), ProjectileService, ZoneService,
                   DamageService, StatusService, InventoryService (Spellforge), ChestService,
                   PracticeService (training dummies), BotService, ClassService, DataService, MapService
    Map/           MapDefs (the 5 maps), TerrainGen, Structures (trees, ruins, cornucopia, chests),
                   Hub (Arcanum Plaza), Lobby (the library), Props (shared building blocks)
  client/        (StarterPlayerScripts.Client)
    Controllers/   HUD, Spellbook/Spellforge, Grimoire, Tutorial, chest window, lobby (join/leave queue,
                   vote, kit shop, spectate), input, effects, storm, weather
    UI/            small UI toolkit (Create, Widgets, Theme, ItemInfo)
```

The server is authoritative. Clients only send requests like "cast at this point", "open/take from chest", "inventory action", "join/leave the queue" and "vote", and the server validates each one (mana, cooldowns, distance, part counts). Projectiles are simulated on the server. Each client simulates the same motion locally for smooth visuals, and the server corrects anything that depends on the world, such as bounces or homing.

## Tests

The game logic is tested outside Roblox:

```bash
python3 tools/run_tests.py          # unit tests for spells, wands, loot, kits and their odds (needs the `luau` CLI)
lune run tools/sim/combat           # every premade spell, the wild parts (walls, hydra, fractal, swaps, rewinds...), 1500 random spells, Spell Lab rules
lune run tools/sim/client           # real client UI + real server: forge, slot, loot, cast, buy a kit, join/leave the queue, vote, Grimoire, the tutorial
lune run tools/sim/match            # boots the real server: spawn in the hub, walk through the portal, two full matches with bots, leave the queue
lune run tools/sim/maps             # builds the hub and the library and generates all 5 maps, checking chests, spacing and decoration
```

The `tools/sim` scripts run the actual game modules on a small fake engine (`tools/sim/mock.luau`) under [Lune](https://lune-org.github.io/docs). GitHub Actions runs all of these, plus type checking and a Rojo build, on every push.

## Known limitations / ideas for next steps

- **Visuals are built from code.** The plaza, library, trees and ruins are made from parts (the blocky look is an intentional Minecraft nod), icons are emoji, and there are no custom meshes or animations yet. Dropping in Creator Store models for chests, wands and bookshelves would be a big visual upgrade.
- **Bots walk in straight lines and jump when stuck.** They don't pathfind, which is fine on open terrain but clumsy around ruins.
- **Balance is a first pass.** Use `Config.lua`, `MapDefs.lua` and `SpellParts.lua` to tune it once real players are in.
- **One server = one hub and one match at a time.** That's how classic survival-games servers worked. Once the game is popular, a separate hub *place* that queues players from many servers and teleports full groups into match servers (`TeleportService:ReserveServer`) would keep every match at 24.
- **Paid kits.** The top tiers are a real head start (that's the point of them), but the best gear in the game is still in the chests. Check Roblox's current monetization and paid-random-item policies before you publish.
