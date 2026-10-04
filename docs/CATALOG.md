# Mana Wars catalogue

_Generated from the game data by `lune run tools/gen_docs`. Do not edit by hand._

**74 spell parts** (21 forms, 12 elements, 34 modifiers, 7 triggers). A spell is one form, an optional element, up to 4 modifiers and an optional trigger carrying a whole payload spell (nested up to 3 deep). That is about **376 million** different single-layer spells, and roughly **9.9e+17** once a single trigger payload is added.

## Forms

| | Form | Rarity | Damage | Mana | Cast delay | What it does |
|---|---|---|---|---|---|---|
| 🔹 | **Bolt** | Common | 8.4 | 10 | 0.12s | A reliable magic bolt. Medium speed, medium damage. |
| 💫 | **Spark** | Common | 3.6 | 4 | 0.04s | A tiny, very fast spark. Cheap to cast and quick to repeat. |
| 🎆 | **Spray** | Common | 3 | 14 | 0.24s | A short-ranged shotgun burst of five pellets. |
| ↩️ | **Boomerang** | Uncommon | 9.6 | 15 | 0.20s | A spinning glaive that flies out, then returns to you, cutting through everyone on the way. |
| 💣 | **Grenade** | Uncommon | explosion 15.6 | 22 | 0.30s | A lobbed bomb that bounces around and explodes when its fuse runs out or it hits someone. |
| 🔮 | **Orb** | Uncommon | 16.8 | 26 | 0.32s | A slow, heavy sphere that punches through its first target. |
| 👻 | **Wisp** | Uncommon | 6.6 | 15 | 0.18s | A slow spirit that hunts down the nearest enemy on its own. |
| ⛓️ | **Chain** | Rare | 7.2 | 18 | 0.20s | Arcs to the nearest enemy in front of you, then jumps to more enemies nearby. |
| ☁️ | **Cloud** | Rare | zone 6 | 28 | 0.35s | A lobbed flask that bursts into a lingering cloud, hurting everyone who stands in it. |
| 🏹 | **Lance** | Rare | 12 | 22 | 0.28s | An instant beam of force. Hits whatever is in your crosshair. |
| 🧨 | **Mine** | Rare | explosion 20.4 | 20 | 0.25s | A lobbed trap that sticks to the ground, arms itself, and explodes when an enemy walks near. |
| 🌟 | **Nova** | Rare | 10.8 | 26 | 0.30s | An instant ring of energy that blasts everything around you. |
| 🧱 | **Rampart** | Rare | — | 24 | 0.40s | Raises a solid wall where you aim that blocks movement and spells for 6 seconds. Impact effects go off at its base; expiry triggers fire when it crumbles. |
| ⚙️ | **Sawblade** | Rare | 7.8 | 20 | 0.25s | A whirling sawblade that rolls along the ground and ricochets off walls, cutting through everyone in its path. |
| 🐝 | **Swarm** | Rare | 2.1 | 24 | 0.30s | Releases six angry little sprites that wobble off and hunt down enemies. |
| 🛡️ | **Aegis** | Epic | — | 40 | 0.50s | Wraps you in a shield that absorbs damage for a few seconds. Triggers fire when it ends. |
| ⚫ | **Black Hole** | Epic | explosion 7.2 | 45 | 0.50s | A tiny black hole drifts forward, dragging everyone nearby into its crushing core, then collapses with a bang. |
| 🌀 | **Blink** | Epic | — | 30 | 0.45s | Teleports you up to 40 studs toward your aim. Triggers fire where you land. |
| ☄️ | **Meteor** | Epic | explosion 18 | 36 | 0.45s | Calls a burning rock down from the sky onto the spot you aim at. |
| 🌪️ | **Tornado** | Epic | zone 5.4 | 34 | 0.45s | A slow, wandering twister that drags enemies in, tosses them into the air and grinds them up. |
| 🧿 | **Sentry** | Legendary | zone 3.6 | 50 | 0.50s | Deploys a floating eye that hovers in place for 8 seconds and shoots sparks at the nearest enemy. Its shots inherit its element and modifiers; Pulse and Timer payloads are aimed at enemies too. |

## Elements

| | Part | Rarity | Effect |
|---|---|---|---|
| ✨ | **Arcane** | Common | Pure magic. +10% damage, +10% speed, 15% cheaper. |
| 🔥 | **Fire** | Common | Sets targets ablaze: 4 damage per second for 3 seconds. |
| ❄️ | **Frost** | Common | Chills targets (35% slower). Three chills in a row freeze them solid. 10% slower spell. |
| ⛰️ | **Earth** | Uncommon | Heavy and brutal. +35% damage and big knockback, but slower and affected by gravity. |
| 💀 | **Poison** | Uncommon | Stacking venom: 1.5 damage per second per stack (up to 5) for 6 seconds. -20% direct damage. |
| 🌪️ | **Wind** | Uncommon | Blows targets away and up into the air. +35% speed, -25% damage. |
| ⚡ | **Lightning** | Rare | Every hit arcs to one more nearby enemy for half damage. +35% speed, -10% damage. |
| 🌌 | **Void** | Rare | Drains life: heals you for 15% of damage dealt. |
| 🥀 | **Blood** | Epic | +50% damage, but every cast costs you 4 health. |
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
| ↪️ | **Returning** | Uncommon | Flies out, then curves back to you, hitting things both ways. +1 pierce. |
| ⏸️ | **Stasis** | Uncommon | Hangs frozen in the air for 1 second, then flies on. Instant spells go off 1 second late. Stack for traps. |
| 2️⃣ | **Twin** | Uncommon | Casts the spell twice at once. |
| 💥 | **Explosive** | Rare | Explodes on impact, damaging everything nearby. |
| 🦇 | **Leech** | Rare | Heals you for 20% of the damage this spell deals. |
| 🔥 | **Lingering** | Rare | Leaves a pool of its element behind that damages anyone standing in it. |
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
| 💀 | **Plaguebringer** | Silver | Rotwood Staff (Uncommon) | Venom Wisp, Magic Bolt | Extend, Poison x2, +1 random |
| ⚡ | **Stormcaller** | Silver | Tempest Scepter (Uncommon) | Quick Spark, Twin Sparks | Haste, Lightning, +1 random |
| 🌌 | **Voidwalker** | Gold | Abyssal Focus (Rare) | Void Seeker, Spark Bolt, Magic Bolt | Blink, Leech, Void, +1 random |
| 🧛 | **Bloodmage** | Gold | Sanguine Rod (Rare) | Blood Glaive, Scattershot, Magic Bolt | Blood, Critical, Empower, +1 random |
| ☀️ | **Lightbringer** | Gold | Sunlit Scepter (Rare) | Sunlance, Spark Bolt, Magic Bolt | Critical, Radiant, +1 random |
| 🔧 | **Artificer** | Arcane | Tinkerer's Rod (Rare) | Ripper, Earthen Rampart, Fireball, Pebble Toss | Bounce, Explosive, Rampart, Sawblade, +1 random |
| ⏳ | **Chronomancer** | Arcane | Hourglass Wand (Rare) | Time Bomb, Ice Shard, Switcheroo, Frostbolt | Frost, Quicken, Stasis x2, +1 random |
| 🐝 | **Swarmlord** | Arcane | Hive Staff (Rare) | The Hive, Seeker Swarm, Venom Wisp, Magic Bolt | Homing, Poison x2, Swarm, +1 random |
| ⛈️ | **Stormlord** | Astral | Thunderhead Scepter (Epic) | Hydra Storm, Chain Lightning, Thunder Lance, Twin Sparks | Bounce x2, Lightning x2, Pierce, +1 random |
| 🕳️ | **Void Archon** | Astral | Event Staff (Epic), Phase Focus (Rare) | Black Hole, Void Seeker, Switcheroo, Magic Bolt, Escape Step, Spark Bolt | Leech, Magnetic, Void x2, +1 random |
| 🌟 | **Archmage** | Archmage | Staff of the Archmage (Legendary), Warding Focus (Epic) | Arcane Rain, Fireworks, Starfall, Magic Missile, Escape Step, Bulwark | Arcane x2, Fractal, Skyfall, Triple, +1 random |
| ☄️ | **Harbinger** | Archmage | Harbinger's Rod (Legendary), Chaos Scepter (Epic) | Watchful Eye, Meteor, Seeking Inferno, Fireball, Chaos Orb, Sparkler | Chaos, Explosive x2, Gigantic, Sentry, +1 random |

## Game modes

| | Mode | Players | |
|---|---|---|---|
| ⚔️ | **Survival Games** | Up to 12 mages | Vote on one of five islands, start on a pedestal around the cornucopia, loot chests and outlast everyone as the Mana Storm closes in. |
| 🤺 | **1v1 Duel** | 2 mages | Face a single rival in a floating arena. You each get a random spell and one potion, and kits and outfit bonuses stay home: a fair fight. Starts as soon as an opponent is found. |
| 🧞 | **Battle Royale** | Up to 50 mages | Ride a flying carpet across an enormous island of five lands, jump off wherever you like and glide down. Loot villages, castles and ruins while the storm circle shrinks. |

**Duels:** a bot steps in after 15s alone; sudden death at 75s (6 damage a second), time limit 150s; 10 coins for a win, 2 for a loss; up to 6 duels at once.

**Battle Royale:** up to 50 mages (bots fill to 20). The queue gathers for 30s while the island is built, then the magic carpet crosses it in 50s, 330 studs up. Gliders fall at 32 studs/s and steer at 55 studs/s. Chests refill at 300s.

| Storm circle | Shown for | Closes in | Radius (share of the island) | Damage outside |
|---|---|---|---|---|
| 1 | 100s | 60s | 62% | 2/s |
| 2 | 55s | 45s | 36% | 4/s |
| 3 | 40s | 40s | 18% | 6/s |
| 4 | 30s | 30s | 7% | 10/s |
| 5 | 20s | 30s | 0% | 15/s |

**🧞 The Sundered Realms** (radius 1000 studs, 140 scattered chests plus those in its towns and landmarks):

| Realm | Named places | Landmarks | Weather |
|---|---|---|---|
| **The Heartland** | Spellcaster's Square | 3 (shrine, camp, windmill) | Clear |
| **The Frostlands** | Frostfang Hold, Rimeholm | 5 (ice spire, lodge, watchtower, ruined tower, shrine) | Snow |
| **The Ashlands** | Cinderforge, Ashfall Keep | 5 (obsidian gate, ruined tower, watchtower, camp, shrine) | Ash |
| **The Sunscar Desert** | Sunscar Bazaar, Dunewatch | 5 (pyramid, ruined tower, camp, watchtower, shrine) | Dust |
| **The Wildwood** | Glowcap Hollow, Mossbrook | 5 (stump, fairy ring, ancient oak, camp, ruined tower) | Spores |

## Maps

In Survival Games, players vote between 3 random maps in the lobby before every match. Each match generates a fresh layout of the chosen map: terrain, ruins and chest spots are different every time. The cornucopia always holds 10 chests.

| | Map | Radius | Scattered chests | Landmarks | Weather | |
|---|---|---|---|---|---|---|
| 🌳 | **Verdant Isle** | 450 studs | 30 | 10 | Pollen | _Flower meadows, a winding river, a windmill and the Ancient Oak. The classic._ |
| 🏔️ | **Frostpeak** | 420 studs | 28 | 9 | Snow | _Snowfields under an aurora: frozen rivers, glowing ice spires and a cosy hunter's lodge._ |
| 🌋 | **Ashen Wastes** | 400 studs | 26 | 9 | Ash (lava burns) | _Rivers of lava under a smoking volcano. Black glass, ember vents and a dwarven forge._ |
| 🏜️ | **Sandsea Ruins** | 480 studs | 30 | 11 | Dust | _Striped canyon mesas, palm oases, a step pyramid and a bazaar. The biggest map._ |
| 🍄 | **Fungal Hollow** | 380 studs | 24 | 8 | Spores | _A glowing night forest of giant mushrooms, fairy rings and fireflies. Small and deadly._ |

## Potions

| | Potion | Key | Rarity | Effect |
|---|---|---|---|---|
| 🧪 | **Healing Draught** | Z | Common | Restores 40 health over 4 seconds. |
| 💧 | **Mana Tonic** | X | Common | Instantly refills the mana of every wand you carry. |
| 👟 | **Swiftness Elixir** | C | Uncommon | +35% movement speed for 12 seconds. |
| 🧱 | **Stoneskin Potion** | V | Rare | Grants a 30 point shield for 10 seconds. |

## Robes, hats and coffers

Matches pay **Enchanted Coins** by finishing place: 12 for 1st, 11 for 2nd ... 1 for 12th in Survival Games, and 50 for 1st down to 1 in a Battle Royale (plus the outfit's Fortune bonus). Duels pay 10 for a win and 2 for a loss. New players get 60 coins and a plain robe and hat. Coins buy **coffers** of robe and hat parts; parts are stitched into garments at the Tailor's Loom, or traded on the auction house (10% fee, listings last 48 hours, 10 at a time).

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

### Familiars

Every item a coffer hands out can turn out to be a **familiar** instead (Tattered Satchel 3%, Apprentice's Coffer 5%, Enchanter's Chest 8%, Archmage's Vault 10%, Celestial Reliquary 15% per item). A familiar rolls its rarity from the coffer's usual odds, and 2.5% of familiars are **Shiny** (golden sparkles, looks only). Common and Uncommon familiars are purely cosmetic; from Rare up each species has one minor power that grows with rarity. Rare familiars glow, Epic ones sparkle, Legendary ones carry an elemental aura and Mythic ones leave a trail. **21** species, **532** distinct familiars to collect (species × colour × rarity × shiny).

| | Familiar | From rarity | Coffers | Power (Rare+) | Colours |
|---|---|---|---|---|---|
| 🐇 | **Dust Bunny** | Common | Tattered Satchel, Apprentice's Coffer only | Quickpaw | Snow, Ash, Cocoa, Blossom |
| 🐸 | **Pebble Toad** | Common | any | Springheel | Moss, Stone, Bog, Ruby |
| 🐭 | **Candle Mouse** | Common | any | Keen Nose | Grey, Cream, Sable |
| ✨ | **Wisp** | Common | any | Mana Sip | Azure, Violet, Verdant, Ember |
| 🐈 | **Lucky Tabby** | Uncommon | any | Lucky Charm | Ginger, Tuxedo, Calico, Silver |
| 🕊️ | **Paper Crane** | Uncommon | any | Attuned (Wind) | Parchment, Crimson, Indigo |
| 💚 | **Gel Slime** | Uncommon | any | Guardian | Lime, Berry, Ocean, Honey |
| 🦋 | **Luna Moth** | Uncommon | any | Mend | Pale Jade, Dusk, Rosy |
| 🦊 | **Ember Fox** | Rare | any | Nip | Flame, Ashen, Blue-flame |
| 🦉 | **Frost Owl** | Rare | any | Night Eyes | Snowy, Glacier, Midnight |
| 📖 | **Tome Mimic** | Rare | Apprentice's Coffer and up | Attuned (Arcane) | Oxblood, Forest, Royal |
| 🐍 | **Sky Eel** | Rare | Apprentice's Coffer and up | Attuned (Lightning) | Storm, Copper, Neon |
| 💎 | **Crystal Golemling** | Epic | Enchanter's Chest and up | Guardian | Amethyst, Quartz, Emerald, Ruby |
| 🦑 | **Void Jelly** | Epic | Enchanter's Chest and up | Nip | Abyss, Ink, Nebula |
| 🐦 | **Storm Raven** | Epic | Enchanter's Chest and up | Keen Nose | Coal, Thunderhead |
| 💀 | **Hex Skull** | Epic | Enchanter's Chest and up | Attuned (Blood) | Bone, Obsidian, Gilded |
| 🐉 | **Dragonling** | Legendary | Archmage's Vault and up | Nip | Crimson, Emerald, Obsidian, Frost |
| 🔥 | **Phoenix Chick** | Legendary | Archmage's Vault and up | Last Ember | Sunfire, Azure-flame |
| 🦄 | **Thunder Kirin** | Legendary | Archmage's Vault and up | Quickpaw | Pearl, Gold, Storm |
| 🐋 | **Star Whale** | Mythic | Celestial Reliquary only | Lucky Charm | Nebula, Aurora |
| 🐈 | **Eclipse Cat** | Mythic | Celestial Reliquary only | Nip | Eclipse, Blood Moon |

| Power | Effect (Rare to Mythic) | Rare / Epic / Legendary / Mythic |
|---|---|---|
| **Quickpaw** | +2% to 5% movement speed | 2% / 3% / 4% / 5% |
| **Springheel** | +4% to 10% jump height | 4% / 6% / 8% / 10% |
| **Mana Sip** | +3% to 6% mana regeneration | 3% / 4% / 5% / 6% |
| **Lucky Charm** | +4% to 10% Enchanted Coins from matches | 4% / 6% / 8% / 10% |
| **Guardian** | -2% to 5% damage taken | 2% / 3% / 4% / 5% |
| **Mend** | +0.2 to 0.5 health per second | 0.2 / 0.3 / 0.4 / 0.5 |
| **Attuned** | +3% to 6% its element's damage | 3% / 4% / 5% / 6% |
| **Keen Nose** | Points out unopened chests within 30 to 60 studs | 30 / 40 / 50 / 60 |
| **Night Eyes** | Every 12s, outlines the nearest enemy within 50 to 80 studs (only you see it) | 50 / 60 / 70 / 80 |
| **Nip** | Every 8s, darts at an enemy within 14 studs for 2 to 5 damage | 2 / 3 / 4 / 5 |
| **Last Ember** | When you fall, it bursts for 8 to 20 fire damage around you | 8 / 12 / 16 / 20 |

## Achievements

Each pays its Enchanted Coins once (345 in all). Players also get **3 coins a day** for logging in (days start at midnight UTC).

| | Achievement | Goal | Reward |
|---|---|---|---|
| 📖 | **Apprentice No More** | Finish the tutorial. | 5 💰 |
| ⚔️ | **First Blood** | Defeat another mage. | 5 💰 |
| 🗡️ | **Duelist** | Defeat 25 mages. | 15 💰 |
| 💀 | **Archmage of Ruin** | Defeat 100 mages. | 40 💰 |
| 🏆 | **Victor** | Win a match. | 10 💰 |
| 👑 | **Champion** | Win 10 matches. | 30 💰 |
| 🌟 | **Living Legend** | Win 50 matches. | 100 💰 |
| 🤺 | **Honour Bound** | Win 5 duels. | 10 💰 |
| 🧞 | **Carpet Champion** | Win a Battle Royale. | 20 💰 |
| 🥉 | **Survivor** | Finish a match in the top 3. | 5 💰 |
| 🎮 | **Regular** | Play 25 matches. | 15 💰 |
| 🔮 | **Spellwright** | Forge 10 spells in the Spellforge. | 10 💰 |
| 📦 | **Treasure Hunter** | Open 100 chests in matches. | 15 💰 |
| 🎁 | **Coffer Collector** | Open 10 coffers. | 10 💰 |
| 🧵 | **Tailor** | Stitch your own robe or hat at the Tailor's Loom. | 5 💰 |
| 🐾 | **Beast Friend** | Find 5 familiars. | 10 💰 |
| ✨ | **Something Shiny** | Find a Shiny familiar. | 20 💰 |
| ⚖️ | **Merchant** | Sell something at the auction house. | 5 💰 |
| 📅 | **Devoted** | Claim the daily reward 7 days in a row. | 15 💰 |
