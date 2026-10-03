--!strict
-- Hand-designed "fully created" spells found in chests. Every one of them can be
-- dismantled in the Spellforge to recover its parts, so rare spells double as rare parts.

local SpellTypes = require(script.Parent.SpellTypes)

type Recipe = SpellTypes.Recipe

export type Premade = {
	id: string,
	name: string,
	rarity: string,
	flavor: string,
	recipe: Recipe,
}

local PremadeSpells = {}

PremadeSpells.List = {
	-- Common ---------------------------------------------------------------
	{
		id = "MagicBolt",
		name = "Magic Bolt",
		rarity = "Common",
		flavor = "The first spell every apprentice learns.",
		recipe = { form = "Bolt", element = "Arcane" },
	},
	{
		id = "SparkBolt",
		name = "Spark Bolt",
		rarity = "Common",
		flavor = "Weak, cheap and terrifyingly fast in the right wand.",
		recipe = { form = "Spark", element = "Arcane" },
	},
	{
		id = "Firebolt",
		name = "Firebolt",
		rarity = "Common",
		flavor = "Sets things on fire. Mostly the intended things.",
		recipe = { form = "Bolt", element = "Fire" },
	},
	{
		id = "Frostbolt",
		name = "Frostbolt",
		rarity = "Common",
		flavor = "Slows the target. Hit them three times to freeze them solid.",
		recipe = { form = "Bolt", element = "Frost" },
	},
	{
		id = "PebbleToss",
		name = "Pebble Toss",
		rarity = "Common",
		flavor = "A rock. Thrown with magic. Hurts more than you'd think.",
		recipe = { form = "Bolt", element = "Earth", mods = { "Heavy" } },
	},
	{
		id = "Scattershot",
		name = "Scattershot",
		rarity = "Common",
		flavor = "Point it at their face.",
		recipe = { form = "Spray", element = "Arcane" },
	},
	{
		id = "Gust",
		name = "Gust",
		rarity = "Common",
		flavor = "Get out of my personal space.",
		recipe = { form = "Spray", element = "Wind" },
	},
	{
		id = "QuickSpark",
		name = "Quick Spark",
		rarity = "Common",
		flavor = "Crackles and pops. Shortens the wand's delay.",
		recipe = { form = "Spark", element = "Lightning", mods = { "Quicken" } },
	},

	-- Uncommon ---------------------------------------------------------------
	{
		id = "Sparkler",
		name = "Sparkler",
		rarity = "Uncommon",
		flavor = "Two wobbly sparks of fire. Festive and deadly.",
		recipe = { form = "Spark", element = "Fire", mods = { "Erratic", "Twin" } },
	},
	{
		id = "IceShard",
		name = "Ice Shard",
		rarity = "Uncommon",
		flavor = "Slips through the first two people in line.",
		recipe = { form = "Spark", element = "Frost", mods = { "Pierce" } },
	},
	{
		id = "VenomWisp",
		name = "Venom Wisp",
		rarity = "Uncommon",
		flavor = "It finds you. It always finds you.",
		recipe = { form = "Wisp", element = "Poison" },
	},
	{
		id = "RicochetBolt",
		name = "Ricochet Bolt",
		rarity = "Uncommon",
		flavor = "Bank shots off the walls.",
		recipe = { form = "Bolt", element = "Arcane", mods = { "Bounce", "Haste" } },
	},
	{
		id = "Firebomb",
		name = "Firebomb",
		rarity = "Uncommon",
		flavor = "Lob, bounce, boom.",
		recipe = { form = "Grenade", element = "Fire" },
	},
	{
		id = "Boulder",
		name = "Boulder",
		rarity = "Uncommon",
		flavor = "A huge rolling rock that flattens anything in its path.",
		recipe = { form = "Orb", element = "Earth", mods = { "Heavy" } },
	},
	{
		id = "GaleGlaive",
		name = "Glaive of Gales",
		rarity = "Uncommon",
		flavor = "Knocks everyone back, then comes home.",
		recipe = { form = "Boomerang", element = "Wind" },
	},
	{
		id = "TwinSparks",
		name = "Twin Sparks",
		rarity = "Uncommon",
		flavor = "Two sparks, each arcing to another victim.",
		recipe = { form = "Spark", element = "Lightning", mods = { "Twin" } },
	},
	{
		id = "FrostOrb",
		name = "Frost Orb",
		rarity = "Uncommon",
		flavor = "A slow, enormous snowball of doom.",
		recipe = { form = "Orb", element = "Frost", mods = { "Enlarge" } },
	},

	-- Rare -------------------------------------------------------------------
	{
		id = "Fireball",
		name = "Fireball",
		rarity = "Rare",
		flavor = "The classic.",
		recipe = { form = "Bolt", element = "Fire", mods = { "Explosive" } },
	},
	{
		id = "MagicMissile",
		name = "Magic Missile",
		rarity = "Rare",
		flavor = "Three homing darts that never miss.",
		recipe = { form = "Spark", element = "Arcane", mods = { "Homing", "Triple" } },
	},
	{
		id = "ChainLightning",
		name = "Chain Lightning",
		rarity = "Rare",
		flavor = "Jumps from victim to victim.",
		recipe = { form = "Chain", element = "Lightning" },
	},
	{
		id = "FrostNova",
		name = "Frost Nova",
		rarity = "Rare",
		flavor = "Everyone near you gets very, very cold.",
		recipe = { form = "Nova", element = "Frost" },
	},
	{
		id = "ThunderLance",
		name = "Thunder Lance",
		rarity = "Rare",
		flavor = "An instant bolt that goes straight through a crowd.",
		recipe = { form = "Lance", element = "Lightning", mods = { "Pierce" } },
	},
	{
		id = "PlagueCloud",
		name = "Plague Cloud",
		rarity = "Rare",
		flavor = "Hold your breath.",
		recipe = { form = "Cloud", element = "Poison" },
	},
	{
		id = "FireMine",
		name = "Proximity Mine",
		rarity = "Rare",
		flavor = "Leave a little present in the doorway.",
		recipe = { form = "Mine", element = "Fire" },
	},
	{
		id = "VoidSeeker",
		name = "Void Seeker",
		rarity = "Rare",
		flavor = "A hungry wisp that feeds you the life it steals.",
		recipe = { form = "Wisp", element = "Void", mods = { "Leech" } },
	},
	{
		id = "Shatterbolt",
		name = "Shatterbolt",
		rarity = "Rare",
		flavor = "Explodes into icy shards on impact.",
		recipe = { form = "Bolt", element = "Frost", mods = { "Shatter" } },
	},
	{
		id = "BloodGlaive",
		name = "Blood Glaive",
		rarity = "Rare",
		flavor = "Costs blood. Returns more.",
		recipe = { form = "Boomerang", element = "Blood", mods = { "Leech" } },
	},
	{
		id = "Sunlance",
		name = "Sunlance",
		rarity = "Rare",
		flavor = "Lights your target up for the whole lobby to see.",
		recipe = { form = "Lance", element = "Radiant" },
	},
	{
		id = "Bulwark",
		name = "Bulwark",
		rarity = "Rare",
		flavor = "A long-lasting stone shield.",
		recipe = { form = "Aegis", element = "Earth", mods = { "Extend" } },
	},
	{
		id = "EscapeStep",
		name = "Escape Step",
		rarity = "Rare",
		flavor = "Ride the wind somewhere safer.",
		recipe = { form = "Blink", element = "Wind" },
	},
	{
		id = "TickBomb",
		name = "Tick Bomb",
		rarity = "Rare",
		flavor = "A mine that leaves a toxic puddle behind.",
		recipe = { form = "Mine", element = "Poison", mods = { "Lingering" } },
	},
	{
		id = "SeekerSwarm",
		name = "Seeker Swarm",
		rarity = "Rare",
		flavor = "Three wisps, one target.",
		recipe = { form = "Wisp", element = "Arcane", mods = { "Triple" } },
	},
	{
		id = "Railgun",
		name = "Railgun",
		rarity = "Rare",
		flavor = "Starts slow. Ends fast. Goes through people.",
		recipe = { form = "Bolt", element = "Lightning", mods = { "Accelerate", "Pierce" } },
	},

	-- Epic -------------------------------------------------------------------
	{
		id = "Ripper",
		name = "Ripper",
		rarity = "Rare",
		flavor = "A stone sawblade that just keeps bouncing.",
		recipe = { form = "Sawblade", element = "Earth", mods = { "Bounce" } },
	},
	{
		id = "Hive",
		name = "The Hive",
		rarity = "Rare",
		flavor = "Six venomous sprites with a grudge.",
		recipe = { form = "Swarm", element = "Poison" },
	},
	{
		id = "EarthenRampart",
		name = "Earthen Rampart",
		rarity = "Rare",
		flavor = "Hide behind it. Or wall someone in.",
		recipe = { form = "Rampart", element = "Earth" },
	},
	{
		id = "Boomerbomb",
		name = "Boomerbomb",
		rarity = "Rare",
		flavor = "It comes back. That's the problem.",
		recipe = { form = "Grenade", element = "Fire", mods = { "Returning" } },
	},
	{
		id = "TimeBomb",
		name = "Time Bomb",
		rarity = "Rare",
		flavor = "Hangs in the air for a second. Then it doesn't.",
		recipe = { form = "Grenade", element = "Arcane", mods = { "Stasis", "Explosive" } },
	},
	{
		id = "ClusterBomb",
		name = "Cluster Bomb",
		rarity = "Epic",
		flavor = "A bomb full of smaller fire.",
		recipe = {
			form = "Grenade",
			element = "Fire",
			trigger = "OnExpire",
			payload = { form = "Spray", element = "Fire" },
		},
	},
	{
		id = "OrbitingBlades",
		name = "Orbiting Blades",
		rarity = "Epic",
		flavor = "Three bolts circle you like a whirling shield.",
		recipe = { form = "Bolt", element = "Arcane", mods = { "Orbit", "Triple" } },
	},
	{
		id = "StormShield",
		name = "Storm Shield",
		rarity = "Epic",
		flavor = "When the shield breaks, it discharges.",
		recipe = {
			form = "Aegis",
			element = "Lightning",
			trigger = "OnExpire",
			payload = { form = "Nova", element = "Lightning" },
		},
	},
	{
		id = "BlinkStrike",
		name = "Blink Strike",
		rarity = "Epic",
		flavor = "Teleport in. Detonate.",
		recipe = {
			form = "Blink",
			element = "Void",
			trigger = "OnHit",
			payload = { form = "Nova", element = "Void" },
		},
	},
	{
		id = "Meteor",
		name = "Meteor",
		rarity = "Epic",
		flavor = "Look up.",
		recipe = { form = "Meteor", element = "Fire" },
	},
	{
		id = "RicochetRain",
		name = "Ricochet Rain",
		rarity = "Epic",
		flavor = "Pellets of stone that bounce around and blow up.",
		recipe = { form = "Spray", element = "Earth", mods = { "Bounce", "Bounce", "Explosive" } },
	},
	{
		id = "SeekingInferno",
		name = "Seeking Inferno",
		rarity = "Epic",
		flavor = "A homing fireball that leaves the ground burning.",
		recipe = { form = "Bolt", element = "Fire", mods = { "Homing", "Explosive", "Lingering" } },
	},
	{
		id = "GravityWell",
		name = "Gravity Well",
		rarity = "Epic",
		flavor = "Pulls everyone together. Then explodes.",
		recipe = { form = "Grenade", element = "Earth", mods = { "Vortex" } },
	},
	{
		id = "PoisonRain",
		name = "Toxic Comet",
		rarity = "Epic",
		flavor = "A meteor that leaves a poison crater.",
		recipe = { form = "Meteor", element = "Poison", mods = { "Lingering" } },
	},

	{
		id = "Twister",
		name = "Twister",
		rarity = "Epic",
		flavor = "Picks people up. Puts them down somewhere else. Hard.",
		recipe = { form = "Tornado", element = "Wind", mods = { "Magnetic" } },
	},
	{
		id = "BlackHole",
		name = "Black Hole",
		rarity = "Epic",
		flavor = "Everything goes in. Nothing comes out.",
		recipe = { form = "BlackHole", element = "Void" },
	},
	{
		id = "ArcaneRain",
		name = "Arcane Rain",
		rarity = "Epic",
		flavor = "Five bolts fall out of a clear sky.",
		recipe = { form = "Bolt", element = "Arcane", mods = { "Skyfall", "Barrage" } },
	},
	{
		id = "Switcheroo",
		name = "Switcheroo",
		rarity = "Epic",
		flavor = "Now you're over there, and they're over here.",
		recipe = { form = "Bolt", element = "Arcane", mods = { "Transpose", "Haste" } },
	},
	{
		id = "FlakCannon",
		name = "Flak Cannon",
		rarity = "Epic",
		flavor = "Bursts into burning shrapnel next to anyone who gets close.",
		recipe = {
			form = "Bolt",
			element = "Fire",
			trigger = "Proximity",
			payload = { form = "Spray", element = "Fire" },
		},
	},
	{
		id = "BouncingBetty",
		name = "Bouncing Betty",
		rarity = "Epic",
		flavor = "Every bounce sets off a blast.",
		recipe = {
			form = "Grenade",
			element = "Earth",
			mods = { "Bounce" },
			trigger = "OnBounce",
			payload = { form = "Nova", element = "Fire" },
		},
	},
	{
		id = "ChaosOrb",
		name = "Chaos Orb",
		rarity = "Epic",
		flavor = "Nobody knows what it'll do. Including you.",
		recipe = { form = "Orb", element = "Chaos", mods = { "Gigantic" } },
	},

	-- Legendary --------------------------------------------------------------
	{
		id = "Starfall",
		name = "Starfall",
		rarity = "Legendary",
		flavor = "Three radiant stars crash down at once.",
		recipe = { form = "Meteor", element = "Radiant", mods = { "Triple" } },
	},
	{
		id = "Hailstorm",
		name = "Hailstorm",
		rarity = "Legendary",
		flavor = "A freezing cloud that spits ice in every direction.",
		recipe = {
			form = "Cloud",
			element = "Frost",
			trigger = "Pulse",
			payload = { form = "Spark", element = "Frost", mods = { "Twin" } },
		},
	},
	{
		id = "PhantomLance",
		name = "Phantom Lance",
		rarity = "Legendary",
		flavor = "Walls mean nothing.",
		recipe = { form = "Lance", element = "Void", mods = { "Phasing", "Overcharge" } },
	},
	{
		id = "Singularity",
		name = "Singularity",
		rarity = "Legendary",
		flavor = "Gather. Collapse. Detonate.",
		recipe = {
			form = "Orb",
			element = "Void",
			mods = { "Vortex", "Enlarge" },
			trigger = "OnExpire",
			payload = { form = "Nova", element = "Void", mods = { "Empower" } },
		},
	},
	{
		id = "EchoingThunder",
		name = "Echoing Thunder",
		rarity = "Legendary",
		flavor = "Strikes twice, jumps everywhere.",
		recipe = { form = "Chain", element = "Lightning", mods = { "Echo", "Pierce" } },
	},

	{
		id = "HydraStorm",
		name = "Hydra Storm",
		rarity = "Legendary",
		flavor = "One bolt. Then two. Then four. Then eight.",
		recipe = { form = "Bolt", element = "Lightning", mods = { "Bounce", "Hydra" } },
	},
	{
		id = "Fireworks",
		name = "Fireworks",
		rarity = "Legendary",
		flavor = "It splits, and splits, and splits again.",
		recipe = { form = "Spark", element = "Fire", mods = { "Fractal", "Fractal" } },
	},
	{
		id = "WatchfulEye",
		name = "Watchful Eye",
		rarity = "Legendary",
		flavor = "A floating eye that shoots at anyone it sees, and makes them glow.",
		recipe = { form = "Sentry", element = "Radiant" },
	},
	{
		id = "RewindLance",
		name = "Rewind Lance",
		rarity = "Legendary",
		flavor = "Undo the last two seconds of their escape.",
		recipe = { form = "Lance", element = "Chrono" },
	},
	{
		id = "ReapersChain",
		name = "Reaper's Chain",
		rarity = "Legendary",
		flavor = "Every death feeds the next.",
		recipe = {
			form = "Chain",
			element = "Void",
			trigger = "OnKill",
			payload = { form = "Chain", element = "Void", mods = { "Pierce" } },
		},
	},

	-- Mythic -----------------------------------------------------------------
	{
		id = "Doombringer",
		name = "Doombringer",
		rarity = "Mythic",
		flavor = "A blood meteor that erupts in fire where it lands.",
		recipe = {
			form = "Meteor",
			element = "Blood",
			mods = { "Overcharge", "Lingering" },
			trigger = "OnHit",
			payload = { form = "Nova", element = "Fire", mods = { "Knockback" } },
		},
	},
	{
		id = "Sunwheel",
		name = "Sunwheel",
		rarity = "Mythic",
		flavor = "A radiant orb circles you, firing lances in every direction.",
		recipe = {
			form = "Orb",
			element = "Radiant",
			mods = { "Orbit" },
			trigger = "Pulse",
			payload = { form = "Lance", element = "Radiant" },
		},
	},
	{
		id = "EventHorizon",
		name = "Event Horizon",
		rarity = "Mythic",
		flavor = "A colossal black hole that ends in a void supernova.",
		recipe = {
			form = "BlackHole",
			element = "Void",
			mods = { "Gigantic" },
			trigger = "OnExpire",
			payload = { form = "Nova", element = "Void", mods = { "Empower", "Enlarge" } },
		},
	},
	{
		id = "DoomTurret",
		name = "Doom Turret",
		rarity = "Mythic",
		flavor = "A burning eye that calls meteors down on whoever it sees.",
		recipe = {
			form = "Sentry",
			element = "Fire",
			trigger = "Pulse",
			payload = { form = "Meteor", element = "Fire" },
		},
	},
	{
		id = "Kaleidoscope",
		name = "Kaleidoscope",
		rarity = "Mythic",
		flavor = "Bounces, splits and splits again. Good luck counting them.",
		recipe = { form = "Spark", element = "Arcane", mods = { "Fractal", "Hydra", "Bounce", "Bounce" } },
	},
} :: { Premade }

PremadeSpells.ById = {} :: { [string]: Premade }
for _, premade in PremadeSpells.List do
	assert(PremadeSpells.ById[premade.id] == nil, "duplicate premade spell " .. premade.id)
	PremadeSpells.ById[premade.id] = premade
end

return PremadeSpells
