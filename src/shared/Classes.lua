--!strict
-- Starting kits. "Apprentice" is free; every other class is a premium perk
-- (Roblox Premium or the classes game pass, see Config.Premium).
-- Kits are a head start, not a win button: the best gear is always in the chests.

local WandGenerator = require(script.Parent.WandGenerator)

export type ClassKit = {
	wands: { { template: WandGenerator.WandTemplate, spells: { string } } },
	spells: { string }?, -- extra premade spells placed in the bag
	parts: { [string]: number }?,
	consumables: { [string]: number }?,
}

export type ClassDef = {
	id: string,
	name: string,
	icon: string,
	premium: boolean,
	color: { number },
	tagline: string,
	kit: ClassKit,
}

local Classes = {}

Classes.List = {
	{
		id = "Apprentice",
		name = "Apprentice",
		icon = "📖",
		premium = false,
		color = { 200, 200, 210 },
		tagline = "A humble student with a basic wand. Loot fast!",
		kit = {
			wands = {
				{
					template = {
						name = "Apprentice's Wand",
						rarity = "Common",
						wandType = "Wand",
						color = { 140, 100, 60 },
						stats = {
							capacity = 3,
							castDelay = 0.16,
							rechargeTime = 0.45,
							manaMax = 140,
							manaRegen = 45,
							spread = 2,
						},
					},
					spells = { "SparkBolt", "MagicBolt" },
				},
			},
			parts = { Bolt = 1, Arcane = 1 },
			consumables = { HealingDraught = 1 },
		},
	},
	{
		id = "Pyromancer",
		name = "Pyromancer",
		icon = "🔥",
		premium = true,
		color = { 255, 120, 40 },
		tagline = "Burns everything. Fire spells deal +20% damage.",
		kit = {
			wands = {
				{
					template = {
						name = "Emberheart Rod",
						rarity = "Uncommon",
						wandType = "Rod",
						color = { 120, 40, 20 },
						stats = {
							capacity = 4,
							castDelay = 0.18,
							rechargeTime = 0.55,
							manaMax = 220,
							manaRegen = 55,
							spread = 2,
						},
						perks = { { kind = "Affinity", element = "Fire", amount = 0.2 } },
					},
					spells = { "Firebolt", "Firebomb" },
				},
			},
			parts = { Fire = 2, Explosive = 1 },
			consumables = { HealingDraught = 1 },
		},
	},
	{
		id = "Cryomancer",
		name = "Cryomancer",
		icon = "❄️",
		premium = true,
		color = { 140, 220, 255 },
		tagline = "Slows, freezes and shatters. Control the fight.",
		kit = {
			wands = {
				{
					template = {
						name = "Glacial Wand",
						rarity = "Uncommon",
						wandType = "Wand",
						color = { 180, 230, 255 },
						stats = {
							capacity = 3,
							castDelay = 0.14,
							rechargeTime = 0.5,
							manaMax = 180,
							manaRegen = 55,
							spread = 1,
						},
						perks = { { kind = "Affinity", element = "Frost", amount = 0.2 } },
					},
					spells = { "Frostbolt", "IceShard" },
				},
			},
			parts = { Frost = 2, Pierce = 1 },
			consumables = { HealingDraught = 1 },
		},
	},
	{
		id = "Stormcaller",
		name = "Stormcaller",
		icon = "⚡",
		premium = true,
		color = { 255, 235, 90 },
		tagline = "Casts two spells at once with a twin-cast scepter.",
		kit = {
			wands = {
				{
					template = {
						name = "Tempest Scepter",
						rarity = "Uncommon",
						wandType = "Scepter",
						color = { 70, 80, 120 },
						stats = {
							capacity = 4,
							spellsPerCast = 2,
							castDelay = 0.22,
							rechargeTime = 0.6,
							manaMax = 200,
							manaRegen = 60,
							spread = 3,
						},
					},
					spells = { "QuickSpark", "TwinSparks" },
				},
			},
			parts = { Lightning = 1, Haste = 1, Twin = 1 },
			consumables = { ManaTonic = 1 },
		},
	},
	{
		id = "Plaguebringer",
		name = "Plaguebringer",
		icon = "☠️",
		premium = true,
		color = { 120, 230, 60 },
		tagline = "Stacks venom with homing wisps. Patience kills.",
		kit = {
			wands = {
				{
					template = {
						name = "Rotwood Staff",
						rarity = "Uncommon",
						wandType = "Staff",
						color = { 70, 90, 40 },
						stats = {
							capacity = 4,
							castDelay = 0.24,
							rechargeTime = 0.7,
							manaMax = 260,
							manaRegen = 60,
							spread = 2,
						},
						perks = { { kind = "Affinity", element = "Poison", amount = 0.2 } },
					},
					spells = { "VenomWisp", "MagicBolt" },
				},
			},
			parts = { Poison = 2, Lingering = 1 },
			consumables = { HealingDraught = 1 },
		},
	},
	{
		id = "Voidwalker",
		name = "Voidwalker",
		icon = "🌌",
		premium = true,
		color = { 150, 70, 210 },
		tagline = "Drains life from enemies. Starts with lifesteal.",
		kit = {
			wands = {
				{
					template = {
						name = "Abyssal Focus",
						rarity = "Uncommon",
						wandType = "Focus",
						color = { 40, 20, 60 },
						stats = {
							capacity = 2,
							castDelay = 0.1,
							rechargeTime = 0.35,
							manaMax = 160,
							manaRegen = 75,
							spread = 1,
						},
						perks = { { kind = "Vampiric", amount = 0.06 } },
					},
					spells = { "SparkBolt", "MagicBolt" },
				},
			},
			parts = { Void = 1, Leech = 1, Blink = 1 },
			consumables = { HealingDraught = 1 },
		},
	},
	{
		id = "Geomancer",
		name = "Geomancer",
		icon = "⛰️",
		premium = true,
		color = { 170, 125, 80 },
		tagline = "Hits like a landslide. Starts with a shield part.",
		kit = {
			wands = {
				{
					template = {
						name = "Bedrock Staff",
						rarity = "Uncommon",
						wandType = "Staff",
						color = { 100, 85, 70 },
						stats = {
							capacity = 4,
							castDelay = 0.26,
							rechargeTime = 0.7,
							manaMax = 280,
							manaRegen = 55,
							spread = 2,
						},
						perks = { { kind = "Affinity", element = "Earth", amount = 0.2 } },
					},
					spells = { "PebbleToss", "Boulder" },
				},
			},
			parts = { Earth = 1, Bounce = 1, Aegis = 1 },
			consumables = { StoneskinPotion = 1 },
		},
	},
	{
		id = "Bloodmage",
		name = "Bloodmage",
		icon = "🩸",
		premium = true,
		color = { 210, 30, 50 },
		tagline = "Trades health for raw power. High risk, high reward.",
		kit = {
			wands = {
				{
					template = {
						name = "Sanguine Rod",
						rarity = "Uncommon",
						wandType = "Rod",
						color = { 90, 10, 20 },
						stats = {
							capacity = 3,
							castDelay = 0.16,
							rechargeTime = 0.5,
							manaMax = 200,
							manaRegen = 60,
							spread = 1,
						},
						perks = { { kind = "Vampiric", amount = 0.05 } },
					},
					spells = { "MagicBolt", "Scattershot" },
				},
			},
			parts = { Blood = 1, Critical = 1, Empower = 1 },
			consumables = { HealingDraught = 2 },
		},
	},
	{
		id = "Lightbringer",
		name = "Lightbringer",
		icon = "☀️",
		premium = true,
		color = { 255, 230, 140 },
		tagline = "Reveals enemies through walls and hunts them down.",
		kit = {
			wands = {
				{
					template = {
						name = "Sunlit Scepter",
						rarity = "Uncommon",
						wandType = "Scepter",
						color = { 230, 200, 120 },
						stats = {
							capacity = 3,
							castDelay = 0.18,
							rechargeTime = 0.55,
							manaMax = 210,
							manaRegen = 55,
							spread = 1,
						},
						perks = { { kind = "AlwaysCast", modifier = "Homing" } },
					},
					spells = { "SparkBolt", "MagicBolt" },
				},
			},
			parts = { Radiant = 1, Critical = 1 },
			consumables = { HealingDraught = 1 },
		},
	},
	{
		id = "Windwalker",
		name = "Windwalker",
		icon = "🌪️",
		premium = true,
		color = { 180, 255, 220 },
		tagline = "The fastest wand in the game. Blows enemies away.",
		kit = {
			wands = {
				{
					template = {
						name = "Zephyr Wand",
						rarity = "Uncommon",
						wandType = "Wand",
						color = { 220, 240, 230 },
						stats = {
							capacity = 3,
							castDelay = 0.08,
							rechargeTime = 0.3,
							manaMax = 150,
							manaRegen = 70,
							spread = 3,
							speedMult = 1.15,
						},
					},
					spells = { "Gust", "SparkBolt" },
				},
			},
			parts = { Wind = 1, Haste = 1 },
			consumables = { SwiftnessElixir = 1 },
		},
	},
} :: { ClassDef }

Classes.ById = {} :: { [string]: ClassDef }
for _, c in Classes.List do
	Classes.ById[c.id] = c
end

Classes.Default = "Apprentice"

return Classes
