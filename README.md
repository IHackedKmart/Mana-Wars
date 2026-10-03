# Mana Wars

A Roblox battle royale that crosses **old-school Minecraft Survival Games** with **Noita-style spellcrafting**.

Everyone spawns on pedestals around a cornucopia packed with chests. When the gong sounds, you can rush the middle for the best loot or run for the woods. Chests are scattered across a freshly generated island, and they hold three things:

- **Wands.** Randomly generated, each with its own rarity, spell slots, mana pool, cast delay, recharge time, multicast, spread and perks.
- **Fully made spells.** 49 hand-designed ones such as Fireball, Chain Lightning, Meteor and Singularity, plus randomly generated ones.
- **Spell parts.** 54 parts you combine in the **Spellforge** to craft your own spells.

The chests refill halfway through, a Mana Storm closes in, and the last mage standing wins. Premium players can pick from 9 classes, each with its own starting wand, spells and parts.

## Making your own spells

Every spell is built from parts:

| Slot | Choose | Examples |
|---|---|---|
| **Form** (required) | what the spell physically is | Bolt, Spark, Orb, Lance (beam), Nova, Chain, Mine, Grenade, Cloud, Boomerang, Wisp, Meteor, Blink, Aegis... |
| **Element** | what it's made of | Fire burns, Frost slows (3 hits freezes), Lightning arcs, Poison stacks, Void heals you, Earth hits hard, Wind launches, Radiant marks targets through walls, Blood trades HP for power |
| **Modifiers** (up to 4) | how it behaves | Homing, Twin, Triple, Explosive, Bounce, Pierce, Lingering, Orbit, Accelerate, Phasing, Vortex, Shatter, Echo, Overcharge... |
| **Trigger + Payload** | cast a *whole other spell* when this one hits / expires / on a timer / every pulse | Grenade → On Expire → Fire Spray = *Cluster Bomb* |

Payloads can carry their own triggers (three layers deep), so a *Seeking Twin Ember Bolt* that bursts into a *Frost Nova* that spits *Triple Storm Sparks* is a real spell you can build. That works out to about **67 million** single-layer spells, and around 10^16 once you add one trigger. Any spell can be **dismantled** back into its parts, so rare premade spells double as rare parts.

Wands work like Noita: a wand casts its slotted spells left to right. Multicast wands fire several at once, shuffle wands fire them in random order, and once the wand reaches the end of its spells it recharges.

The full list of every part, spell and class is in **[docs/CATALOG.md](docs/CATALOG.md)**.

## Controls

| | PC | Mobile | Gamepad |
|---|---|---|---|
| Cast | hold Left Mouse | **Cast** button (aims at screen centre) | R2 |
| Switch wand | 1-4, Q to cycle | tap the hotbar | L1 / R1 |
| Spellbook & Spellforge | Tab or B | **Bag** button | Y |
| Open chest | E (hold) | tap the prompt | X |
| Take everything from a chest | F | **Take All** | |
| Potions | Z X C V | tap the potion | |

In the Spellbook:
- **Slot a spell:** click a spell in your bag, then click a wand slot.
- **Unslot a spell:** right-click a spell in a wand, or select it and press Unslot.
- **Craft a spell:** click parts to drop them into the Spellforge, then press **Forge Spell**.
- **Add a payload:** select a bag spell and press *Use as payload*.

## Play it in Roblox Studio

### Easiest way: open the place file
1. Open **`build/ManaWars.rbxlx`** in Roblox Studio (File → Open from File).
2. Press **Play**. A match starts after a 25-second intermission, and bots fill the empty spots so you can play solo.

If you change the code in `src/`, rebuild the place file with `rojo build -o build/ManaWars.rbxlx`.

### Developer way: live-sync with Rojo
1. Install [Rokit](https://github.com/rojo-rbx/rokit) and run `rokit install` in this folder. This installs Rojo, StyLua, selene and luau-lsp at the pinned versions.
2. Install the Rojo plugin in Studio.
3. Run `rojo serve`, then click **Connect** in the Studio plugin. Edits to `src/` now sync live.

### Before you publish
- **DataStores:** in *Game Settings → Security*, turn on **Enable Studio Access to API Services** so wins and kills save.
- **Premium classes:** these unlock automatically for Roblox Premium members. To sell them as a game pass instead (or as well), create the pass and put its id in `src/shared/Config.lua` → `Config.Premium.ClassesGamePassId`. While you test in Studio, every class is unlocked (`StudioUnlocksAll`).
- **Streaming** is turned off (`Workspace.StreamingEnabled = false` in `default.project.json`) so every client always sees the whole arena. The island is small enough for that.
- **Sounds:** the game uses sounds that ship with every Roblox client, so it works out of the box. Swap the ids in `src/client/Controllers/Sounds.lua` for Creator Store sounds to make it sound much better.

## Tuning the game

Almost every number lives in **`src/shared/Config.lua`**: match timings, storm speed and damage, how many bots fill a match, arena size, chest counts, inventory limits, spell nesting depth and premium settings.

| Want to... | Edit |
|---|---|
| add or rebalance a spell part | `src/shared/Spells/SpellParts.lua` (each part is a small table with an `apply` function) |
| add a premade spell | `src/shared/Spells/PremadeSpells.lua` |
| change wand generation | `src/shared/WandGenerator.lua` |
| change chest loot odds | `src/shared/LootTables.lua` |
| add or change a class | `src/shared/Classes.lua` |
| change the map | `src/server/Map/` (terrain, trees, ruins, cornucopia, lobby) |

After changing game data, run `lune run tools/gen_docs` to refresh `docs/CATALOG.md`.

## How the code is organised

```
src/
  shared/        (ReplicatedStorage.Shared)  game data + logic used by both sides
    Spells/        SpellParts, SpellBuilder (recipe -> stats), PremadeSpells, SpellNames
    WandGenerator, LootTables, Classes, Items, Consumables, Rarity, ProjectileSim, Remotes
  server/        (ServerScriptService.Server)
    Services/      MatchService (game loop), CastingService (wand decks + mana),
                   SpellExecutor (forms, impacts, triggers), ProjectileService, ZoneService,
                   DamageService, StatusService, InventoryService (Spellforge), ChestService,
                   BotService, ClassService, DataService, MapService
    Map/           TerrainGen, Structures (trees, ruins, cornucopia, chests), Lobby
  client/        (StarterPlayerScripts.Client)
    Controllers/   HUD, Spellbook/Spellforge, chest window, lobby + spectate, input, effects, storm
    UI/            small UI toolkit (Create, Widgets, Theme, ItemInfo)
```

The server is authoritative. Clients only send "cast at this point", "open/take from chest" and "inventory action" requests, and the server validates each one (mana, cooldowns, distance, part counts). Projectiles are simulated on the server. Each client simulates the same motion locally for smooth visuals, and the server corrects anything that depends on the world, such as bounces or homing.

## Tests

The game logic is tested outside Roblox:

```bash
python3 tools/run_tests.py          # unit tests for spells, wands, loot and classes (needs the `luau` CLI)
lune run tools/sim/combat           # every premade spell + 1500 random crafted spells through the real server code
lune run tools/sim/client           # real client UI + real server: forge, slot, loot, cast, pick a class
lune run tools/sim/match            # boots the real server and plays two full matches with bots
```

The `tools/sim` scripts run the actual game modules on a small fake engine (`tools/sim/mock.luau`) under [Lune](https://lune-org.github.io/docs). GitHub Actions runs all of these, plus type checking and a Rojo build, on every push.

## Known limitations / ideas for next steps

- **Visuals are built from code.** Trees are blocky (an intentional Minecraft nod), icons are emoji, and there are no custom meshes or animations yet. Dropping in Creator Store models for chests and wands would be a big visual upgrade.
- **Bots walk in straight lines and jump when stuck.** They don't pathfind, which is fine on open terrain but clumsy around ruins.
- **Balance is a first pass.** Use `Config.lua` and `SpellParts.lua` to tune it once real players are in.
- **Premium classes.** They give a head start, not a win button: the best gear is always in the chests. Check Roblox's current monetization policies before selling gameplay advantages.
