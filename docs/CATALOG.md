# Mana Wars catalogue

_Generated from the game data by `lune run tools/gen_docs`. Do not edit by hand._

**74 spell parts** (21 forms, 12 elements, 34 modifiers, 7 triggers). A spell is one form, an optional element, up to 4 modifiers and an optional trigger carrying a whole payload spell (nested up to 3 deep). That is about **376 million** different single-layer spells, and roughly **9.9e+17** once a single trigger payload is added.

## Forms

| | Form | Rarity | Damage | Mana | Cast delay | What it does |
|---|---|---|---|---|---|---|
| 🔹 | **Bolt** | Common | 14 | 10 | 0.12s | A reliable magic bolt. Medium speed, medium damage. |
| 💫 | **Spark** | Common | 6 | 4 | 0.04s | A tiny, very fast spark. Cheap to cast and quick to repeat. |
| 🎆 | **Spray** | Common | 5 | 14 | 0.24s | A short-ranged shotgun burst of five pellets. |
| ↩️ | **Boomerang** | Uncommon | 16 | 15 | 0.20s | A spinning glaive that flies out, then returns to you, cutting through everyone on the way. |
| 💣 | **Grenade** | Uncommon | explosion 26 | 22 | 0.30s | A lobbed bomb that bounces around and explodes when its fuse runs out or it hits someone. |
| 🔮 | **Orb** | Uncommon | 28 | 26 | 0.32s | A slow, heavy sphere that punches through its first target. |
| 👻 | **Wisp** | Uncommon | 11 | 15 | 0.18s | A slow spirit that hunts down the nearest enemy on its own. |
| ⛓️ | **Chain** | Rare | 12 | 18 | 0.20s | Arcs to the nearest enemy in front of you, then jumps to more enemies nearby. |
| ☁️ | **Cloud** | Rare | zone 10 | 28 | 0.35s | A lobbed flask that bursts into a lingering cloud, hurting everyone who stands in it. |
| 🏹 | **Lance** | Rare | 20 | 22 | 0.28s | An instant beam of force. Hits whatever is in your crosshair. |
| 🧨 | **Mine** | Rare | explosion 34 | 20 | 0.25s | A lobbed trap that sticks to the ground, arms itself, and explodes when an enemy walks near. |
| 🌟 | **Nova** | Rare | 18 | 26 | 0.30s | An instant ring of energy that blasts everything around you. |
| 🧱 | **Rampart** | Rare | — | 24 | 0.40s | Raises a solid wall where you aim that blocks movement and spells for 6 seconds. Impact effects go off at its base; expiry triggers fire when it crumbles. |
| 🪚 | **Sawblade** | Rare | 13 | 20 | 0.25s | A whirling sawblade that rolls along the ground and ricochets off walls, cutting through everyone in its path. |
| 🐝 | **Swarm** | Rare | 3.5 | 24 | 0.30s | Releases six angry little sprites that wobble off and hunt down enemies. |
| 🛡️ | **Aegis** | Epic | — | 40 | 0.50s | Wraps you in a shield that absorbs damage for a few seconds. Triggers fire when it ends. |
| ⚫ | **Black Hole** | Epic | explosion 12 | 45 | 0.50s | A tiny black hole drifts forward, dragging everyone nearby into its crushing core, then collapses with a bang. |
| 🌀 | **Blink** | Epic | — | 30 | 0.45s | Teleports you up to 40 studs toward your aim. Triggers fire where you land. |
| ☄️ | **Meteor** | Epic | explosion 30 | 36 | 0.45s | Calls a burning rock down from the sky onto the spot you aim at. |
| 🌪️ | **Tornado** | Epic | zone 9 | 34 | 0.45s | A slow, wandering twister that drags enemies in, tosses them into the air and grinds them up. |
| 🧿 | **Sentry** | Legendary | zone 6 | 50 | 0.50s | Deploys a floating eye that hovers in place for 8 seconds and shoots sparks at the nearest enemy. Its shots inherit its element and modifiers; Pulse and Timer payloads are aimed at enemies too. |

## Elements

| | Part | Rarity | Effect |
|---|---|---|---|
| ✨ | **Arcane** | Common | Pure magic. +10% damage, +10% speed, 15% cheaper. |
| 🔥 | **Fire** | Common | Sets targets ablaze: 4 damage per second for 3 seconds. |
| ❄️ | **Frost** | Common | Chills targets (35% slower). Three chills in a row freeze them solid. 10% slower spell. |
| ⛰️ | **Earth** | Uncommon | Heavy and brutal. +35% damage and big knockback, but slower and affected by gravity. |
| ☠️ | **Poison** | Uncommon | Stacking venom: 1.5 damage per second per stack (up to 5) for 6 seconds. -20% direct damage. |
| 🌪️ | **Wind** | Uncommon | Blows targets away and up into the air. +35% speed, -25% damage. |
| ⚡ | **Lightning** | Rare | Every hit arcs to one more nearby enemy for half damage. +35% speed, -10% damage. |
| 🌌 | **Void** | Rare | Drains life: heals you for 15% of damage dealt. |
| 🩸 | **Blood** | Epic | +50% damage, but every cast costs you 4 health. |
| 🃏 | **Chaos** | Epic | Every hit rolls the dice: anywhere from 25% to 250% damage, plus a random burn, chill or venom. +10% speed. |
| ☀️ | **Radiant** | Epic | Marks targets for 5s: they glow through walls for everyone and take 15% more damage. +15% crit. |
| 🕰️ | **Chrono** | Legendary | Hits rewind the target to where they stood 2 seconds ago and slow them by 50%. -15% damage. |

## Modifiers

| | Part | Rarity | Effect |
|---|---|---|---|
| 🏀 | **Bounce** | Common | Bounces off walls and the ground 3 more times. Beams reflect. |
| 💪 | **Empower** | Common | +35% damage. |
| 🔍 | **Enlarge** | Common | +60% size and +35% area, +20% damage, slightly slower. |
| 🎲 | **Erratic** | Common | Wobbles unpredictably through the air. +15% damage. |
| 📏 | **Extend** | Common | +60% lifetime and +40% range. Zones and shields last longer. |
| ⏩ | **Haste** | Common | +60% projectile speed (beams and chains reach further). |
| 🏋️ | **Heavy** | Common | Arcs downward under gravity. +30% damage and extra knockback. |
| 👊 | **Knockback** | Common | Hits send enemies flying. |
| ⏱️ | **Quicken** | Common | Reduces cast delay by 0.08s and wand recharge by 0.12s. |
| 🚀 | **Accelerate** | Uncommon | Starts slow and speeds up rapidly. +20% damage. |
| 🗡️ | **Critical** | Uncommon | +25% chance to critically hit for double damage. |
| ♻️ | **Efficient** | Uncommon | The whole spell costs 40% less mana. |
| 🎯 | **Homing** | Uncommon | Projectiles steer toward the nearest enemy. |
| 📌 | **Pierce** | Uncommon | Passes through 2 more enemies. Chains jump 2 more times. |
| 🪃 | **Returning** | Uncommon | Flies out, then curves back to you, hitting things both ways. +1 pierce. |
| ⏸️ | **Stasis** | Uncommon | Hangs frozen in the air for 1 second, then flies on. Instant spells go off 1 second late. Stack for traps. |
| 2️⃣ | **Twin** | Uncommon | Casts the spell twice at once. |
| 💥 | **Explosive** | Rare | Explodes on impact, damaging everything nearby. |
| 🦇 | **Leech** | Rare | Heals you for 20% of the damage this spell deals. |
| ♨️ | **Lingering** | Rare | Leaves a pool of its element behind that damages anyone standing in it. |
| 🧲 | **Magnetic** | Rare | While it flies, it drags nearby enemies toward itself. |
| 🔄 | **Orbit** | Rare | Projectiles circle around you as a protective ring instead of flying away. |
| 💎 | **Shatter** | Rare | Bursts into 3 sharp shards of the same element when it hits something. |
| 3️⃣ | **Triple** | Rare | Casts the spell three times at once in a fan. |
| ✴️ | **Barrage** | Epic | Casts the spell five times at once in a wide fan, each at 55% damage. |
| 🐘 | **Gigantic** | Epic | Triples the size of everything: projectiles, explosions, novas and zones. +50% damage, much slower and pricier. |
| 🔋 | **Overcharge** | Epic | +80% damage, but much more mana and a longer cast delay. |
| 👁️ | **Phasing** | Epic | Passes straight through walls and terrain. |
| 🌧️ | **Skyfall** | Epic | The spell comes down from the sky onto your aim point instead of leaving your wand. Novas erupt there, beams strike straight down, blinks land there. |
| 🔀 | **Transpose** | Epic | When it hits an enemy, you swap places with them. |
| 🕳️ | **Vortex** | Epic | On impact, sucks nearby enemies toward the point of impact. |
| 🔁 | **Echo** | Legendary | The spell casts itself again a moment later for free. |
| 🧬 | **Fractal** | Legendary | When it ends, it splits into 3 smaller copies of itself, which split again. Each Fractal adds a generation (up to 3). |
| 🐉 | **Hydra** | Legendary | Every time it bounces, it splits in two. +1 bounce. Pair it with Bounce and watch it get out of hand. |

## Triggers

| | Part | Rarity | Effect |
|---|---|---|---|
| ⌛ | **On Expire** | Rare | Casts the payload spell when this spell ends, however it ends. |
| 🎇 | **On Hit** | Rare | Casts the payload spell wherever this spell hits something. |
| 🏓 | **On Bounce** | Epic | Casts the payload every time this spell bounces (up to 8 times). |
| 📡 | **Proximity** | Epic | A proximity fuse: casts the payload at the first enemy that comes within 9 studs of this spell. |
| ⏲️ | **Timer** | Epic | Casts the payload spell once, half a second after casting, from wherever this spell is. |
| 💀 | **On Kill** | Legendary | Casts the payload from the spot where this spell kills someone. Kill chains! (Knocking a training dummy down to 1 HP counts.) |
| 💓 | **Pulse** | Legendary | Casts the payload spell every 0.6 seconds while this spell is alive (up to 6 times). |

## Premade spells (found in chests)

Every premade spell can be dismantled in the Spellforge to recover its parts.

| Spell | Rarity | Recipe | Mana | |
|---|---|---|---|---|
| **Magic Bolt** | Common | Bolt + Arcane | 9 | _The first spell every apprentice learns._ |
| **Spark Bolt** | Common | Spark + Arcane | 3 | _Weak, cheap and terrifyingly fast in the right wand._ |
| **Firebolt** | Common | Bolt + Fire | 10 | _Sets things on fire. Mostly the intended things._ |
| **Frostbolt** | Common | Bolt + Frost | 10 | _Slows the target. Hit them three times to freeze them solid._ |
| **Pebble Toss** | Common | Bolt + Earth + Heavy | 14 | _A rock. Thrown with magic. Hurts more than you'd think._ |
| **Scattershot** | Common | Spray + Arcane | 12 | _Point it at their face._ |
| **Gust** | Common | Spray + Wind | 14 | _Get out of my personal space._ |
| **Quick Spark** | Common | Spark + Lightning + Quicken | 8 | _Crackles and pops. Shortens the wand's delay._ |
| **Sparkler** | Uncommon | Spark + Fire + Erratic + Twin | 13 | _Two wobbly sparks of fire. Festive and deadly._ |
| **Ice Shard** | Uncommon | Spark + Frost + Pierce | 12 | _Slips through the first two people in line._ |
| **Venom Wisp** | Uncommon | Wisp + Poison | 15 | _It finds you. It always finds you._ |
| **Ricochet Bolt** | Uncommon | Bolt + Arcane + Bounce + Haste | 17 | _Bank shots off the walls._ |
| **Firebomb** | Uncommon | Grenade + Fire | 22 | _Lob, bounce, boom._ |
| **Boulder** | Uncommon | Orb + Earth + Heavy | 30 | _A huge rolling rock that flattens anything in its path._ |
| **Glaive of Gales** | Uncommon | Boomerang + Wind | 15 | _Knocks everyone back, then comes home._ |
| **Twin Sparks** | Uncommon | Spark + Lightning + Twin | 10 | _Two sparks, each arcing to another victim._ |
| **Frost Orb** | Uncommon | Orb + Frost + Enlarge | 32 | _A slow, enormous snowball of doom._ |
| **Fireball** | Rare | Bolt + Fire + Explosive | 24 | _The classic._ |
| **Magic Missile** | Rare | Spark + Arcane + Homing + Triple | 33 | _Three homing darts that never miss._ |
| **Chain Lightning** | Rare | Chain + Lightning | 18 | _Jumps from victim to victim._ |
| **Frost Nova** | Rare | Nova + Frost | 26 | _Everyone near you gets very, very cold._ |
| **Thunder Lance** | Rare | Lance + Lightning + Pierce | 30 | _An instant bolt that goes straight through a crowd._ |
| **Plague Cloud** | Rare | Cloud + Poison | 28 | _Hold your breath._ |
| **Proximity Mine** | Rare | Mine + Fire | 20 | _Leave a little present in the doorway._ |
| **Void Seeker** | Rare | Wisp + Void + Leech | 27 | _A hungry wisp that feeds you the life it steals._ |
| **Shatterbolt** | Rare | Bolt + Frost + Shatter | 25 | _Explodes into icy shards on impact._ |
| **Blood Glaive** | Rare | Boomerang + Blood + Leech | 27 | _Costs blood. Returns more._ |
| **Sunlance** | Rare | Lance + Radiant | 22 | _Lights your target up for the whole lobby to see._ |
| **Bulwark** | Rare | Aegis + Earth + Extend | 45 | _A long-lasting stone shield._ |
| **Escape Step** | Rare | Blink + Wind | 30 | _Ride the wind somewhere safer._ |
| **Tick Bomb** | Rare | Mine + Poison + Lingering | 34 | _A mine that leaves a toxic puddle behind._ |
| **Seeker Swarm** | Rare | Wisp + Arcane + Triple | 32 | _Three wisps, one target._ |
| **Railgun** | Rare | Bolt + Lightning + Accelerate + Pierce | 23 | _Starts slow. Ends fast. Goes through people._ |
| **Ripper** | Rare | Sawblade + Earth + Bounce | 25 | _A stone sawblade that just keeps bouncing._ |
| **The Hive** | Rare | Swarm + Poison | 24 | _Six venomous sprites with a grudge._ |
| **Earthen Rampart** | Rare | Rampart + Earth | 24 | _Hide behind it. Or wall someone in._ |
| **Boomerbomb** | Rare | Grenade + Fire + Returning | 26 | _It comes back. That's the problem._ |
| **Time Bomb** | Rare | Grenade + Arcane + Stasis + Explosive | 36 | _Hangs in the air for a second. Then it doesn't._ |
| **Cluster Bomb** | Epic | Grenade + Fire → **OnExpire** → (Spray + Fire) | 42 | _A bomb full of smaller fire._ |
| **Orbiting Blades** | Epic | Bolt + Arcane + Orbit + Triple | 43 | _Three bolts circle you like a whirling shield._ |
| **Storm Shield** | Epic | Aegis + Lightning → **OnExpire** → (Nova + Lightning) | 72 | _When the shield breaks, it discharges._ |
| **Blink Strike** | Epic | Blink + Void → **OnHit** → (Nova + Void) | 64 | _Teleport in. Detonate._ |
| **Meteor** | Epic | Meteor + Fire | 36 | _Look up._ |
| **Ricochet Rain** | Epic | Spray + Earth + Bounce + Bounce + Explosive | 38 | _Pellets of stone that bounce around and blow up._ |
| **Seeking Inferno** | Epic | Bolt + Fire + Homing + Explosive + Lingering | 48 | _A homing fireball that leaves the ground burning._ |
| **Gravity Well** | Epic | Grenade + Earth + Vortex | 38 | _Pulls everyone together. Then explodes._ |
| **Toxic Comet** | Epic | Meteor + Poison + Lingering | 50 | _A meteor that leaves a poison crater._ |
| **Twister** | Epic | Tornado + Wind + Magnetic | 44 | _Picks people up. Puts them down somewhere else. Hard._ |
| **Black Hole** | Epic | BlackHole + Void | 45 | _Everything goes in. Nothing comes out._ |
| **Arcane Rain** | Epic | Bolt + Arcane + Skyfall + Barrage | 65 | _Five bolts fall out of a clear sky._ |
| **Switcheroo** | Epic | Bolt + Arcane + Transpose + Haste | 30 | _Now you're over there, and they're over here._ |
| **Flak Cannon** | Epic | Bolt + Fire → **Proximity** → (Spray + Fire) | 32 | _Bursts into burning shrapnel next to anyone who gets close._ |
| **Bouncing Betty** | Epic | Grenade + Earth + Bounce → **OnBounce** → (Nova + Fire) | 62 | _Every bounce sets off a blast._ |
| **Chaos Orb** | Epic | Orb + Chaos + Gigantic | 54 | _Nobody knows what it'll do. Including you._ |
| **Starfall** | Legendary | Meteor + Radiant + Triple | 76 | _Three radiant stars crash down at once._ |
| **Hailstorm** | Legendary | Cloud + Frost → **Pulse** → (Spark + Frost + Twin) | 60 | _A freezing cloud that spits ice in every direction._ |
| **Phantom Lance** | Legendary | Lance + Void + Phasing + Overcharge | 65 | _Walls mean nothing._ |
| **Singularity** | Legendary | Orb + Void + Vortex + Enlarge → **OnExpire** → (Nova + Void + Empower) | 88 | _Gather. Collapse. Detonate._ |
| **Echoing Thunder** | Legendary | Chain + Lightning + Echo + Pierce | 44 | _Strikes twice, jumps everywhere._ |
| **Hydra Storm** | Legendary | Bolt + Lightning + Bounce + Hydra | 27 | _One bolt. Then two. Then four. Then eight._ |
| **Fireworks** | Legendary | Spark + Fire + Fractal + Fractal | 36 | _It splits, and splits, and splits again._ |
| **Watchful Eye** | Legendary | Sentry + Radiant | 50 | _A floating eye that shoots at anyone it sees, and makes them glow._ |
| **Rewind Lance** | Legendary | Lance + Chrono | 22 | _Undo the last two seconds of their escape._ |
| **Reaper's Chain** | Legendary | Chain + Void → **OnKill** → (Chain + Void + Pierce) | 50 | _Every death feeds the next._ |
| **Doombringer** | Mythic | Meteor + Blood + Overcharge + Lingering → **OnHit** → (Nova + Fire + Knockback) | 115 | _A blood meteor that erupts in fire where it lands._ |
| **Sunwheel** | Mythic | Orb + Radiant + Orbit → **Pulse** → (Lance + Radiant) | 80 | _A radiant orb circles you, firing lances in every direction._ |
| **Event Horizon** | Mythic | BlackHole + Void + Gigantic → **OnExpire** → (Nova + Void + Empower + Enlarge) | 119 | _A colossal black hole that ends in a void supernova._ |
| **Doom Turret** | Mythic | Sentry + Fire → **Pulse** → (Meteor + Fire) | 108 | _A burning eye that calls meteors down on whoever it sees._ |
| **Kaleidoscope** | Mythic | Spark + Arcane + Fractal + Hydra + Bounce + Bounce | 50 | _Bounces, splits and splits again. Good luck counting them._ |

## Kits

Kits (classes) decide what you start each match with. The Apprentice is free; every other kit is its own game pass, priced by tier. Every kit also gives **one random spell part** each match, rolled with its tier's odds.

| Tier | Price | Bonus part odds |
|---|---|---|
| **Novice** | Free | 100% Common |
| **Copper** | R$80 (about $0.99) | 75% Common · 25% Uncommon |
| **Silver** | R$240 (about $2.99) | 30% Common · 55% Uncommon · 15% Rare |
| **Gold** | R$400 (about $4.99) | 40% Uncommon · 50% Rare · 10% Epic |
| **Arcane** | R$800 (about $9.99) | 55% Rare · 40% Epic · 5% Legendary |
| **Astral** | R$1200 (about $14.99) | 20% Rare · 60% Epic · 20% Legendary |
| **Archmage** | R$2000 (about $24.99) | 55% Epic · 45% Legendary |

| | Kit | Tier | Wands | Starting spells | Parts |
|---|---|---|---|---|---|
| 📖 | **Apprentice** | Novice | Apprentice's Wand (Common) | Spark Bolt, Magic Bolt | Arcane, Bolt, +1 random |
| ❄️ | **Cryomancer** | Copper | Frosted Wand (Common) | Frostbolt, Spark Bolt | Frost, +1 random |
| ⛰️ | **Geomancer** | Copper | Pebble Rod (Common) | Pebble Toss, Magic Bolt | Earth, +1 random |
| 🌪️ | **Windwalker** | Copper | Breeze Wand (Common) | Gust, Spark Bolt | Wind, +1 random |
| 🔥 | **Pyromancer** | Silver | Emberheart Rod (Uncommon) | Firebolt, Firebomb | Fire x2, Heavy, +1 random |
| ☠️ | **Plaguebringer** | Silver | Rotwood Staff (Uncommon) | Venom Wisp, Magic Bolt | Extend, Poison x2, +1 random |
| ⚡ | **Stormcaller** | Silver | Tempest Scepter (Uncommon) | Quick Spark, Twin Sparks | Haste, Lightning, +1 random |
| 🌌 | **Voidwalker** | Gold | Abyssal Focus (Rare) | Void Seeker, Spark Bolt, Magic Bolt | Blink, Leech, Void, +1 random |
| 🩸 | **Bloodmage** | Gold | Sanguine Rod (Rare) | Blood Glaive, Scattershot, Magic Bolt | Blood, Critical, Empower, +1 random |
| ☀️ | **Lightbringer** | Gold | Sunlit Scepter (Rare) | Sunlance, Spark Bolt, Magic Bolt | Critical, Radiant, +1 random |
| 🔧 | **Artificer** | Arcane | Tinkerer's Rod (Rare) | Ripper, Earthen Rampart, Fireball, Pebble Toss | Bounce, Explosive, Rampart, Sawblade, +1 random |
| ⏳ | **Chronomancer** | Arcane | Hourglass Wand (Rare) | Time Bomb, Ice Shard, Switcheroo, Frostbolt | Frost, Quicken, Stasis x2, +1 random |
| 🐝 | **Swarmlord** | Arcane | Hive Staff (Rare) | The Hive, Seeker Swarm, Venom Wisp, Magic Bolt | Homing, Poison x2, Swarm, +1 random |
| ⛈️ | **Stormlord** | Astral | Thunderhead Scepter (Epic) | Hydra Storm, Chain Lightning, Thunder Lance, Twin Sparks | Bounce x2, Lightning x2, Pierce, +1 random |
| 🕳️ | **Void Archon** | Astral | Event Staff (Epic), Phase Focus (Rare) | Black Hole, Void Seeker, Switcheroo, Magic Bolt, Escape Step, Spark Bolt | Leech, Magnetic, Void x2, +1 random |
| 🌟 | **Archmage** | Archmage | Staff of the Archmage (Legendary), Warding Focus (Epic) | Arcane Rain, Fireworks, Starfall, Magic Missile, Escape Step, Bulwark | Arcane x2, Fractal, Skyfall, Triple, +1 random |
| ☄️ | **Harbinger** | Archmage | Harbinger's Rod (Legendary), Chaos Scepter (Epic) | Watchful Eye, Meteor, Seeking Inferno, Fireball, Chaos Orb, Sparkler | Chaos, Explosive x2, Gigantic, Sentry, +1 random |

## Maps

Players vote between 3 random maps in the lobby before every match. Each match generates a fresh layout of the chosen map: terrain, ruins and chest spots are different every time. The cornucopia always holds 10 chests.

| | Map | Radius | Scattered chests | Landmarks | Weather | |
|---|---|---|---|---|---|---|
| 🌳 | **Verdant Isle** | 450 studs | 30 | 10 | Clear | _Rolling green hills, quiet lakes and crumbling ruins. The classic._ |
| 🏔️ | **Frostpeak** | 420 studs | 28 | 9 | Snow | _A snowbound island of frozen lakes, pine forests and towering peaks._ |
| 🌋 | **Ashen Wastes** | 400 studs | 26 | 9 | Ash (lava burns) | _A volcanic wasteland. Black rock, dead trees, and lava lakes that burn._ |
| 🏜️ | **Sandsea Ruins** | 480 studs | 30 | 11 | Dust | _Endless dunes, sandstone ruins and rare oases. The biggest map._ |
| 🍄 | **Fungal Hollow** | 380 studs | 24 | 8 | Spores | _A glowing night forest of giant mushrooms. Small, dark and deadly._ |

## Potions

| | Potion | Key | Rarity | Effect |
|---|---|---|---|---|
| 🧪 | **Healing Draught** | Z | Common | Restores 40 health over 4 seconds. |
| 💧 | **Mana Tonic** | X | Common | Instantly refills the mana of every wand you carry. |
| 👟 | **Swiftness Elixir** | C | Uncommon | +35% movement speed for 12 seconds. |
| 🧱 | **Stoneskin Potion** | V | Rare | Grants a 30 point shield for 10 seconds. |

## Robes, hats and coffers

Matches pay **Enchanted Coins** by finishing place: 12 for 1st, 11 for 2nd ... 1 for 12th (plus the outfit's Fortune bonus). New players get 60 coins and a plain robe and hat. Coins buy **coffers** of robe and hat parts; parts are stitched into garments at the Tailor's Loom, or traded on the auction house (10% fee, listings last 48 hours, 10 at a time).

| | Coffer | Price | Parts | Odds | Only here |
|---|---|---|---|---|---|
| 👝 | **Tattered Satchel** | 50 coins | 1 | 98% Common · 1.8% Uncommon · 0.2% Rare | Patchwork Robe (robe cloth), Straw Hat (hat) |
| 🧰 | **Apprentice's Coffer** | 100 coins | 1 | 70% Common · 24% Uncommon · 5% Rare · 1% Epic | - |
| 🧳 | **Enchanter's Chest** | 300 coins | 2 | 30% Common · 40% Uncommon · 22% Rare · 7% Epic · 1% Legendary | - |
| 🗝️ | **Archmage's Vault** | 500 coins | 2 | 30% Uncommon · 40% Rare · 22% Epic · 7% Legendary · 1% Mythic | - |
| 🌠 | **Celestial Reliquary** | 1000 coins | 3 | 30% Rare · 40% Epic · 24% Legendary · 6% Mythic | Celestial Vestment (robe cloth), Crown (sigil), Crystalweave (robe cloth), Halo (hat), Nova (sigil), Prism (gem), Singularity (gem), Starcrown (hat), Starlit Band (hat band), Starlit Trim (trim) |

A **robe** is a Cloth + Trim + Sigil; a **hat** is a Hat shape + Band + Gem. Each part rolls a design, one of 36 colours, one of 10 materials, 1-3 enchantments by rarity and (Sigils and Gems) one of 20 auras, all gated by rarity and coffer: **145,800** distinct-looking parts in all.

**Resonance and auras:** a garment's resonance is the average rarity rank of its three parts (rounded down). Its aura shines at the aura part's rarity, but never more than one tier above the resonance: visible from Rare strength, with light from Epic, and an extra flourish at Mythic. A robe and hat with the same aura, both at Epic strength or better, leave a trail.

| Slot | Designs (minimum rarity) |
|---|---|
| 👘 Robe cloth | Novice Robe (Common), Patchwork Robe (Common), Bell Robe (Common), Wanderer's Cloak (Uncommon), Monk's Habit (Uncommon), Battlemage Tabard (Rare), Shadow Wrap (Epic), Royal Robe (Epic), Archmage Regalia (Legendary), Crystalweave (Legendary), Celestial Vestment (Mythic) |
| 🧵 Trim | Plain Hem (Common), Double Hem (Common), Fur Trim (Uncommon), Embroidered Trim (Uncommon), Gilded Trim (Rare), Chainmail Trim (Rare), Runic Trim (Epic), Starlit Trim (Mythic) |
| 🔯 Sigil | Star (Common), Moon (Common), Leaf (Common), Sun (Uncommon), Flame (Uncommon), Snowflake (Uncommon), Thunder (Rare), Skull (Rare), Eye (Rare), Balance (Epic), Trident (Legendary), Infinity (Legendary), Crown (Mythic), Nova (Mythic) |
| 🎩 Hat | Pointed Hat (Common), Hood (Common), Straw Hat (Common), Feathered Cap (Uncommon), Top Hat (Uncommon), Witch Hat (Uncommon), Circlet (Rare), Tricorn (Rare), Horned Helm (Epic), Mitre (Epic), Crown (Legendary), Halo (Mythic), Starcrown (Mythic) |
| 🎀 Hat band | Plain Band (Common), Ribbon (Common), Braided Band (Uncommon), Studded Band (Uncommon), Gilded Band (Rare), Runic Band (Epic), Crystal Band (Legendary), Starlit Band (Mythic) |
| 💎 Gem | Bead (Common), Orb (Common), Acorn (Common), Diamond (Uncommon), Star (Rare), Moonstone (Rare), Seeing Eye (Epic), Skull (Epic), Phoenix Heart (Legendary), Prism (Mythic), Singularity (Mythic) |

**Auras:** Embers (Common), Mist (Common), Sparkles (Common), Falling Leaves (Common), Billowing Smoke (Uncommon), Frost (Uncommon), Toxic Fumes (Uncommon), Bubbles (Uncommon), Lightning (Rare), Petals (Rare), Bloodmist (Rare), Shadow (Epic), Void Wisps (Epic), Floating Runes (Epic), Holy Light (Epic), Inferno (Legendary), Storm (Legendary), Stardust (Legendary), Prismatic (Mythic), Eclipse (Mythic).

| Enchantment | Effect | Per part (Common → Mythic) | Outfit cap |
|---|---|---|---|
| **Swiftness** | +N movement speed | 2% / 3% / 4% / 5% / 6% / 8% | +12% movement speed |
| **Vitality** | +N max health | 3 / 5 / 7 / 10 / 13 / 16 | +25 max health |
| **Mana Well** | +N wand mana | 4% / 6% / 8% / 11% / 14% / 18% | +25% wand mana |
| **Flow** | +N mana regeneration | 4% / 6% / 8% / 11% / 14% / 18% | +25% mana regeneration |
| **Celerity** | -N cast delay | 2% / 3% / 4% / 5% / 7% / 9% | -12% cast delay |
| **Quickening** | -N wand recharge | 3% / 4% / 5% / 7% / 9% / 12% | -15% wand recharge |
| **Warding** | -N damage taken | 2% / 3% / 4% / 5% / 6% / 8% | -12% damage taken |
| **Precision** | +N crit chance | 1% / 2% / 3% / 4% / 5% / 6% | +10% crit chance |
| **Leeching** | +N lifesteal | 1% / 1.5% / 2% / 3% / 4% / 5% | +8% lifesteal |
| **Mending** | +N health per second | 0.2 / 0.3 / 0.4 / 0.6 / 0.8 / 1 | +1.5 health per second |
| **Bounding** | +N jump height | 4% / 6% / 8% / 10% / 13% / 16% | +20% jump height |
| **Fortune** | +N Enchanted Coins from matches | 3% / 5% / 7% / 10% / 13% / 16% | +30% Enchanted Coins from matches |
| **Resilience** | -N burn, chill and venom duration | 4% / 6% / 8% / 11% / 14% / 18% | -30% burn, chill and venom duration |
| **Arcane Attunement** | +N Arcane damage | 3% / 4% / 5% / 7% / 9% / 12% | +20% Arcane damage |
| **Fire Attunement** | +N Fire damage | 3% / 4% / 5% / 7% / 9% / 12% | +20% Fire damage |
| **Frost Attunement** | +N Frost damage | 3% / 4% / 5% / 7% / 9% / 12% | +20% Frost damage |
| **Earth Attunement** | +N Earth damage | 3% / 4% / 5% / 7% / 9% / 12% | +20% Earth damage |
| **Wind Attunement** | +N Wind damage | 3% / 4% / 5% / 7% / 9% / 12% | +20% Wind damage |
| **Poison Attunement** | +N Poison damage | 3% / 4% / 5% / 7% / 9% / 12% | +20% Poison damage |
| **Lightning Attunement** | +N Lightning damage | 3% / 4% / 5% / 7% / 9% / 12% | +20% Lightning damage |
| **Void Attunement** | +N Void damage | 3% / 4% / 5% / 7% / 9% / 12% | +20% Void damage |
| **Radiant Attunement** | +N Radiant damage | 3% / 4% / 5% / 7% / 9% / 12% | +20% Radiant damage |
| **Blood Attunement** | +N Blood damage | 3% / 4% / 5% / 7% / 9% / 12% | +20% Blood damage |
| **Chaos Attunement** | +N Chaos damage | 3% / 4% / 5% / 7% / 9% / 12% | +20% Chaos damage |
| **Chrono Attunement** | +N Chrono damage | 3% / 4% / 5% / 7% / 9% / 12% | +20% Chrono damage |
