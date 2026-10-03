# Mana Wars catalogue

_Generated from the game data by `lune run tools/gen_docs`. Do not edit by hand._

**54 spell parts** (15 forms, 10 elements, 25 modifiers, 4 triggers). A spell is one form, an optional element, up to 4 modifiers and an optional trigger carrying a whole payload spell (nested up to 3 deep). That is about **67 million** different single-layer spells, and roughly **1.8e+16** once a single trigger payload is added.

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
| 🛡️ | **Aegis** | Epic | — | 40 | 0.50s | Wraps you in a shield that absorbs damage for a few seconds. Triggers fire when it ends. |
| 🌀 | **Blink** | Epic | — | 30 | 0.45s | Teleports you up to 40 studs toward your aim. Triggers fire where you land. |
| ☄️ | **Meteor** | Epic | explosion 30 | 36 | 0.45s | Calls a burning rock down from the sky onto the spot you aim at. |

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
| ☀️ | **Radiant** | Epic | Marks targets for 5s: they glow through walls for everyone and take 15% more damage. +15% crit. |

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
| 2️⃣ | **Twin** | Uncommon | Casts the spell twice at once. |
| 💥 | **Explosive** | Rare | Explodes on impact, damaging everything nearby. |
| 🦇 | **Leech** | Rare | Heals you for 20% of the damage this spell deals. |
| ♨️ | **Lingering** | Rare | Leaves a pool of its element behind that damages anyone standing in it. |
| 🔄 | **Orbit** | Rare | Projectiles circle around you as a protective ring instead of flying away. |
| 💎 | **Shatter** | Rare | Bursts into 3 sharp shards of the same element when it hits something. |
| 3️⃣ | **Triple** | Rare | Casts the spell three times at once in a fan. |
| 🔋 | **Overcharge** | Epic | +80% damage, but much more mana and a longer cast delay. |
| 👁️ | **Phasing** | Epic | Passes straight through walls and terrain. |
| 🕳️ | **Vortex** | Epic | On impact, sucks nearby enemies toward the point of impact. |
| 🔁 | **Echo** | Legendary | The spell casts itself again a moment later for free. |

## Triggers

| | Part | Rarity | Effect |
|---|---|---|---|
| ⌛ | **On Expire** | Rare | Casts the payload spell when this spell ends, however it ends. |
| 🎇 | **On Hit** | Rare | Casts the payload spell wherever this spell hits something. |
| ⏲️ | **Timer** | Epic | Casts the payload spell once, half a second after casting, from wherever this spell is. |
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
| **Cluster Bomb** | Epic | Grenade + Fire → **OnExpire** → (Spray + Fire) | 42 | _A bomb full of smaller fire._ |
| **Orbiting Blades** | Epic | Bolt + Arcane + Orbit + Triple | 43 | _Three bolts circle you like a whirling shield._ |
| **Storm Shield** | Epic | Aegis + Lightning → **OnExpire** → (Nova + Lightning) | 72 | _When the shield breaks, it discharges._ |
| **Blink Strike** | Epic | Blink + Void → **OnHit** → (Nova + Void) | 64 | _Teleport in. Detonate._ |
| **Meteor** | Epic | Meteor + Fire | 36 | _Look up._ |
| **Ricochet Rain** | Epic | Spray + Earth + Bounce + Bounce + Explosive | 38 | _Pellets of stone that bounce around and blow up._ |
| **Seeking Inferno** | Epic | Bolt + Fire + Homing + Explosive + Lingering | 48 | _A homing fireball that leaves the ground burning._ |
| **Gravity Well** | Epic | Grenade + Earth + Vortex | 38 | _Pulls everyone together. Then explodes._ |
| **Toxic Comet** | Epic | Meteor + Poison + Lingering | 50 | _A meteor that leaves a poison crater._ |
| **Starfall** | Legendary | Meteor + Radiant + Triple | 76 | _Three radiant stars crash down at once._ |
| **Hailstorm** | Legendary | Cloud + Frost → **Pulse** → (Spark + Frost + Twin) | 60 | _A freezing cloud that spits ice in every direction._ |
| **Phantom Lance** | Legendary | Lance + Void + Phasing + Overcharge | 65 | _Walls mean nothing._ |
| **Singularity** | Legendary | Orb + Void + Vortex + Enlarge → **OnExpire** → (Nova + Void + Empower) | 88 | _Gather. Collapse. Detonate._ |
| **Echoing Thunder** | Legendary | Chain + Lightning + Echo + Pierce | 44 | _Strikes twice, jumps everywhere._ |
| **Doombringer** | Mythic | Meteor + Blood + Overcharge + Lingering → **OnHit** → (Nova + Fire + Knockback) | 115 | _A blood meteor that erupts in fire where it lands._ |
| **Sunwheel** | Mythic | Orb + Radiant + Orbit → **Pulse** → (Lance + Radiant) | 80 | _A radiant orb circles you, firing lances in every direction._ |

## Classes

| | Class | Access | Starting wand | Starting spells | Extra parts |
|---|---|---|---|---|---|
| 📖 | **Apprentice** | Free | Apprentice's Wand (Common) | Spark Bolt, Magic Bolt | Arcane, Bolt |
| 🔥 | **Pyromancer** | Premium | Emberheart Rod (Uncommon) | Firebolt, Firebomb | Explosive, Fire x2 |
| ❄️ | **Cryomancer** | Premium | Glacial Wand (Uncommon) | Frostbolt, Ice Shard | Frost x2, Pierce |
| ⚡ | **Stormcaller** | Premium | Tempest Scepter (Uncommon) | Quick Spark, Twin Sparks | Haste, Lightning, Twin |
| ☠️ | **Plaguebringer** | Premium | Rotwood Staff (Uncommon) | Venom Wisp, Magic Bolt | Lingering, Poison x2 |
| 🌌 | **Voidwalker** | Premium | Abyssal Focus (Uncommon) | Spark Bolt, Magic Bolt | Blink, Leech, Void |
| ⛰️ | **Geomancer** | Premium | Bedrock Staff (Uncommon) | Pebble Toss, Boulder | Aegis, Bounce, Earth |
| 🩸 | **Bloodmage** | Premium | Sanguine Rod (Uncommon) | Magic Bolt, Scattershot | Blood, Critical, Empower |
| ☀️ | **Lightbringer** | Premium | Sunlit Scepter (Uncommon) | Spark Bolt, Magic Bolt | Critical, Radiant |
| 🌪️ | **Windwalker** | Premium | Zephyr Wand (Uncommon) | Gust, Spark Bolt | Haste, Wind |

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
