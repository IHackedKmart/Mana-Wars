# Mana Wars

A Roblox battle royale that crosses **old-school Minecraft Survival Games** with **Noita-style spellcrafting**.

Up to 24 mages wait in a floating library, vote on a map, then drop onto pedestals around a cornucopia of chests. When the gong sounds, you can rush the middle for the best loot or run for the hills. More chests are spread across a freshly generated island, and they hold three things:

- **Wands.** Randomly generated, each with its own rarity, spell slots, mana pool, cast delay, recharge time, multicast, spread and perks.
- **Fully made spells.** 49 hand-designed ones such as Fireball, Chain Lightning, Meteor and Singularity, plus randomly generated ones.
- **Spell parts.** 54 parts you combine in the **Spellforge** to craft your own spells.

The chests refill halfway through, a Mana Storm closes in, and the last mage standing wins. There are 5 maps to vote on, and premium players can pick from 9 classes, each with its own starting wand, spells and parts.

## The lobby: the Arcane Athenaeum

Between matches everyone waits in a library floating high above the island. It has towering bookshelves, chandeliers, stained glass, a spinning orrery and floating books, plus a glass scrying window in the floor so you can watch the match below.

- **Map vote.** Before each match a ballot of 3 maps appears on the right of the screen (the map you just played is left off). Click a map to vote. The most votes wins, and ties are broken at random.
- **Spell Lab.** In the lobby you get a sandbox kit: a practice staff, a twin-cast scepter, showcase spells and 3 copies of **every** spell part. Walk through the big arch to the **Practice Terrace** and try spells on the training dummies. Dummies never die. Practice spells can't hurt other players, and the kit is swapped for your real class kit when the match starts. **♻ Restock Spell Lab** in the Spellbook refills everything.
- **Tutorial.** On your first visit a step-by-step tutorial teaches crafting by doing. You open the Spellbook, forge a spell, slot it into a wand, hit a dummy, then build a spell with a trigger and payload. Each step finishes itself when you do it, and the next button glows.
- **Grimoire.** Press **H**, or use one of the lecterns, to open an in-game encyclopedia. It covers how a match works, how crafting works, how wands work, every Form, Element, Modifier and Trigger, the premade spell library, the classes and the controls. You can also replay the tutorial from it.
- **Class Altar.** Use the altar, or the class button on the left, to pick a class.

## Making your own spells

Every spell is built from parts:

| Slot | Choose | Examples |
|---|---|---|
| **Form** (required) | what the spell physically is | Bolt, Spark, Orb, Lance (beam), Nova, Chain, Mine, Grenade, Cloud, Boomerang, Wisp, Meteor, Blink, Aegis... |
| **Element** | what it's made of | Fire burns, Frost slows (3 hits freezes), Lightning arcs, Poison stacks, Void heals you, Earth hits hard, Wind launches, Radiant marks targets through walls, Blood trades HP for power |
| **Modifiers** (up to 4) | how it behaves | Homing, Twin, Triple, Explosive, Bounce, Pierce, Lingering, Orbit, Accelerate, Phasing, Vortex, Shatter, Echo, Overcharge... |
| **Trigger + Payload** | cast a *whole other spell* when this one hits / expires / on a timer / every pulse | Grenade → On Expire → Fire Spray = *Cluster Bomb* |

Payloads can carry their own triggers, up to three layers deep. So a *Seeking Twin Ember Bolt* that bursts into a *Frost Nova*, which then spits *Triple Storm Sparks*, is a real spell you can build. That works out to about **67 million** single-layer spells, and around 10^16 once you add one trigger. Any spell can be **dismantled** back into its parts, so rare premade spells double as rare parts.

Wands work like Noita: a wand casts its slotted spells left to right. Multicast wands fire several at once and shuffle wands fire them in random order. When a wand reaches the end of its spells, it recharges.

**How to craft, step by step:** press **B** to open the Spellbook. Click a **Form** part in your bag (the middle column), then optionally an **Element** and some **Modifiers**. Check the preview, then press **Forge Spell**. The new spell lands in your bag, already selected, so just click an empty wand slot to equip it. For a trigger spell, add a Trigger part, click any spell in your bag, and press **Use as payload** before forging.

The full list of every part, spell, map and class is in **[docs/CATALOG.md](docs/CATALOG.md)**.

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
2. Press **Play** (F5). You appear in the library lobby, and the tutorial starts on your first visit. The map vote opens right away. A match starts when the vote closes, and bots fill empty spots so you can play solo.

If you change the code in `src/`, rebuild the place file with `rojo build -o build/ManaWars.rbxlx`.

### Developer way: live-sync with Rojo
1. Install [Rokit](https://github.com/rojo-rbx/rokit) and run `rokit install` in this folder. This installs Rojo, StyLua, selene and luau-lsp at the pinned versions.
2. Install the Rojo plugin in Studio.
3. Run `rojo serve`, then click **Connect** in the Studio plugin. Edits to `src/` now sync live.

### Before you publish
- **Server size:** set the place's **Max Players to 24** to match the 24 pedestals. You'll find it in Studio under *File → Game Settings → Places* (click the place's ⋯ → Edit), or in the place's settings on the Creator Dashboard.
- **DataStores:** in *Game Settings → Security*, turn on **Enable Studio Access to API Services** so wins, kills and tutorial progress save.
- **Premium classes:** these unlock automatically for Roblox Premium members. To sell them as a game pass instead (or as well), create the pass and put its id in `src/shared/Config.lua` → `Config.Premium.ClassesGamePassId`. While you test in Studio, every class is unlocked (`StudioUnlocksAll`).
- **Streaming** is turned off (`Workspace.StreamingEnabled = false` in `default.project.json`) so every client always sees the whole arena.
- **Sounds:** the game uses sounds that ship with every Roblox client, so it works out of the box. Swap the ids in `src/client/Controllers/Sounds.lua` for Creator Store sounds to make it sound much better.

## Multiplayer

Mana Wars is multiplayer out of the box, like the original survival-games servers. Each Roblox server runs its own lobby and its own back-to-back matches for everyone in it:

- Everyone in the server votes on the map and is placed on the pedestals together, up to 24 players.
- Players who join mid-match wait in the library. They can spectate through the **👁 Spectate the match** button or the scrying window, and practise in the Spell Lab until the next round.
- **Bots are only filler.** They top a match up to `Config.Bots.FillTo` (8) participants, so a busy server plays with no bots at all. Set `Config.Bots.Enabled = false` to require real players (`Config.Match.MinPlayers`).
- **Test multiplayer in Studio:** open the **Test** tab, pick a number of players under **Clients and Servers** (e.g. 3), and press **Start**. Studio opens a server window plus one window per player.

## Tuning the game

Almost every number lives in **`src/shared/Config.lua`**: match timings, vote length, storm speed and damage, how many bots fill a match, chest counts, the Spell Lab kit, inventory limits, spell nesting depth and premium settings.

| Want to... | Edit |
|---|---|
| add or rebalance a spell part | `src/shared/Spells/SpellParts.lua` (each part is a small table with an `apply` function) |
| add a premade spell | `src/shared/Spells/PremadeSpells.lua` |
| change wand generation | `src/shared/WandGenerator.lua` |
| change chest loot odds | `src/shared/LootTables.lua` |
| add or change a class | `src/shared/Classes.lua` |
| add a map, or change a map's size, chests, terrain, colours, weather or lighting | `src/server/Map/MapDefs.lua` (one table per map) |
| change trees, rocks, ruins or the cornucopia | `src/server/Map/Structures.lua` |
| change the lobby library | `src/server/Map/Lobby.lua` |
| change the tutorial or Grimoire text | `src/client/Controllers/TutorialController.lua`, `GrimoireController.lua` |

After changing game data, run `lune run tools/gen_docs` to refresh `docs/CATALOG.md`.

## How the code is organised

```
src/
  shared/        (ReplicatedStorage.Shared)  game data + logic used by both sides
    Spells/        SpellParts, SpellBuilder (recipe -> stats), PremadeSpells, SpellNames
    WandGenerator, LootTables, Classes, Items, Consumables, Rarity, ProjectileSim, Remotes
  server/        (ServerScriptService.Server)
    Services/      MatchService (game loop), VoteService (map vote), CastingService (wand decks + mana),
                   SpellExecutor (forms, impacts, triggers), ProjectileService, ZoneService,
                   DamageService, StatusService, InventoryService (Spellforge), ChestService,
                   PracticeService (training dummies), BotService, ClassService, DataService, MapService
    Map/           MapDefs (the 5 maps), TerrainGen, Structures (trees, ruins, cornucopia, chests), Lobby
  client/        (StarterPlayerScripts.Client)
    Controllers/   HUD, Spellbook/Spellforge, Grimoire, Tutorial, chest window, lobby (vote, classes,
                   spectate), input, effects, storm, weather
    UI/            small UI toolkit (Create, Widgets, Theme, ItemInfo)
```

The server is authoritative. Clients only send requests like "cast at this point", "open/take from chest", "inventory action" and "vote", and the server validates each one (mana, cooldowns, distance, part counts). Projectiles are simulated on the server. Each client simulates the same motion locally for smooth visuals, and the server corrects anything that depends on the world, such as bounces or homing.

## Tests

The game logic is tested outside Roblox:

```bash
python3 tools/run_tests.py          # unit tests for spells, wands, loot and classes (needs the `luau` CLI)
lune run tools/sim/combat           # every premade spell + 1500 random crafted spells + Spell Lab rules, through the real server code
lune run tools/sim/client           # real client UI + real server: forge, slot, loot, cast, vote, Grimoire, the full tutorial
lune run tools/sim/match            # boots the real server and plays two full matches (vote included) with bots
lune run tools/sim/maps             # builds the lobby and generates all 5 maps, checking chests, spacing and decoration
```

The `tools/sim` scripts run the actual game modules on a small fake engine (`tools/sim/mock.luau`) under [Lune](https://lune-org.github.io/docs). GitHub Actions runs all of these, plus type checking and a Rojo build, on every push.

## Known limitations / ideas for next steps

- **Visuals are built from code.** The library, trees and ruins are made from parts (the blocky look is an intentional Minecraft nod), icons are emoji, and there are no custom meshes or animations yet. Dropping in Creator Store models for chests, wands and bookshelves would be a big visual upgrade.
- **Bots walk in straight lines and jump when stuck.** They don't pathfind, which is fine on open terrain but clumsy around ruins.
- **Balance is a first pass.** Use `Config.lua`, `MapDefs.lua` and `SpellParts.lua` to tune it once real players are in.
- **One server = one lobby.** That's how classic survival-games servers worked. Once the game is popular, a hub place that queues players and teleports full groups into match servers (`TeleportService:ReserveServer`) would keep every match at 24.
- **Premium classes.** They give a head start, not a win button: the best gear is always in the chests. Check Roblox's current monetization policies before selling gameplay advantages.
