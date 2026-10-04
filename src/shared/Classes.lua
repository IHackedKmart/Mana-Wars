--!strict
-- Starting kits, sold in tiers from a free Apprentice up to $25 Archmage kits.
--   * Every paid kit is its own game pass (ids in Config.Kits.GamePassIds). Prices are set on the
--     Creator Dashboard; the Robux amounts below are what the shop shows and what we recommend.
--   * Every kit also hands out ONE random spell part each match. Higher tiers roll rarer parts;
--     the odds are listed below and shown to players before they buy (Roblox requires that for
--     paid random items).
-- Cheap tiers are mostly flavour. The top tiers are a real head start, but the chests still hold
-- the best gear in the game.

local WandGenerator = require(script.Parent.WandGenerator)
local Rarity = require(script.Parent.Rarity)
local SpellParts = require(script.Parent.Spells.SpellParts)

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
	tier: number, -- 0 = free, 1-6 = paid tiers (see Classes.Tiers)
	color: { number },
	tagline: string,
	kit: ClassKit,
}

export type Tier = {
	id: number,
	name: string,
	robux: number, -- recommended game pass price
	usd: string, -- what that roughly costs a player
	color: { number },
	bonusOdds: { [string]: number }, -- rarity -> % chance for the random bonus spell part
}

local Classes = {}

-- (~80 Robux per $0.99 at the standard Robux pack price)
Classes.Tiers = {
	{
		id = 0,
		name = "Novice",
		robux = 0,
		usd = "Free",
		color = { 200, 200, 210 },
		bonusOdds = { Common = 100 },
	},
	{
		id = 1,
		name = "Copper",
		robux = 80,
		usd = "$0.99",
		color = { 200, 125, 70 },
		bonusOdds = { Common = 75, Uncommon = 25 },
	},
	{
		id = 2,
		name = "Silver",
		robux = 240,
		usd = "$2.99",
		color = { 200, 210, 225 },
		bonusOdds = { Common = 30, Uncommon = 55, Rare = 15 },
	},
	{
		id = 3,
		name = "Gold",
		robux = 400,
		usd = "$4.99",
		color = { 255, 205, 90 },
		bonusOdds = { Uncommon = 40, Rare = 50, Epic = 10 },
	},
	{
		id = 4,
		name = "Arcane",
		robux = 800,
		usd = "$9.99",
		color = { 165, 115, 255 },
		bonusOdds = { Rare = 55, Epic = 40, Legendary = 5 },
	},
	{
		id = 5,
		name = "Astral",
		robux = 1200,
		usd = "$14.99",
		color = { 120, 200, 255 },
		bonusOdds = { Rare = 20, Epic = 60, Legendary = 20 },
	},
	{
		id = 6,
		name = "Archmage",
		robux = 2000,
		usd = "$24.99",
		color = { 255, 120, 90 },
		bonusOdds = { Epic = 55, Legendary = 45 },
	},
} :: { Tier }

local function wand(
	name: string,
	rarity: string,
	wandType: string,
	color: { number },
	stats: { [string]: any },
	perks: { any }?
): WandGenerator.WandTemplate
	return { name = name, rarity = rarity, wandType = wandType, color = color, stats = stats, perks = perks }
end

Classes.List = {
	---------------------------------------------------------------- Free
	{
		id = "Apprentice",
		name = "Apprentice",
		icon = "📖",
		tier = 0,
		color = { 200, 200, 210 },
		tagline = "A humble student with a basic wand. Loot fast!",
		kit = {
			wands = {
				{
					template = wand("Apprentice's Wand", "Common", "Wand", { 140, 100, 60 }, {
						capacity = 3,
						castDelay = 0.16,
						rechargeTime = 0.45,
						manaMax = 140,
						manaRegen = 45,
						spread = 2,
					}),
					spells = { "SparkBolt", "MagicBolt" },
				},
			},
			parts = { Bolt = 1, Arcane = 1 },
			consumables = { HealingDraught = 1 },
		},
	},

	---------------------------------------------------------------- Copper ($0.99): flavour
	{
		id = "Cryomancer",
		name = "Cryomancer",
		icon = "❄️",
		tier = 1,
		color = { 140, 220, 255 },
		tagline = "Starts with frost: slow them down, then freeze them solid.",
		kit = {
			wands = {
				{
					template = wand("Frosted Wand", "Common", "Wand", { 180, 230, 255 }, {
						capacity = 3,
						castDelay = 0.15,
						rechargeTime = 0.45,
						manaMax = 150,
						manaRegen = 48,
						spread = 1,
					}, { { kind = "Affinity", element = "Frost", amount = 0.1 } }),
					spells = { "Frostbolt", "SparkBolt" },
				},
			},
			parts = { Frost = 1 },
			consumables = { HealingDraught = 1 },
		},
	},
	{
		id = "Geomancer",
		name = "Geomancer",
		icon = "⛰️",
		tier = 1,
		color = { 170, 125, 80 },
		tagline = "Throws rocks. Heavy ones.",
		kit = {
			wands = {
				{
					template = wand("Pebble Rod", "Common", "Rod", { 100, 85, 70 }, {
						capacity = 3,
						castDelay = 0.17,
						rechargeTime = 0.45,
						manaMax = 160,
						manaRegen = 45,
						spread = 2,
					}, { { kind = "Affinity", element = "Earth", amount = 0.1 } }),
					spells = { "PebbleToss", "MagicBolt" },
				},
			},
			parts = { Earth = 1 },
			consumables = { HealingDraught = 1 },
		},
	},
	{
		id = "Windwalker",
		name = "Windwalker",
		icon = "🌪️",
		tier = 1,
		color = { 180, 255, 220 },
		tagline = "A breezy wand that blows enemies off their feet.",
		kit = {
			wands = {
				{
					template = wand("Breeze Wand", "Common", "Wand", { 220, 240, 230 }, {
						capacity = 3,
						castDelay = 0.13,
						rechargeTime = 0.4,
						manaMax = 140,
						manaRegen = 50,
						spread = 3,
					}),
					spells = { "Gust", "SparkBolt" },
				},
			},
			parts = { Wind = 1 },
			consumables = { SwiftnessElixir = 1 },
		},
	},

	---------------------------------------------------------------- Silver ($2.99): a better wand
	{
		id = "Pyromancer",
		name = "Pyromancer",
		icon = "🔥",
		tier = 2,
		color = { 255, 120, 40 },
		tagline = "Burns everything. Fire spells deal +20% damage.",
		kit = {
			wands = {
				{
					template = wand("Emberheart Rod", "Uncommon", "Rod", { 120, 40, 20 }, {
						capacity = 4,
						castDelay = 0.18,
						rechargeTime = 0.55,
						manaMax = 220,
						manaRegen = 55,
						spread = 2,
					}, { { kind = "Affinity", element = "Fire", amount = 0.2 } }),
					spells = { "Firebolt", "Firebomb" },
				},
			},
			parts = { Fire = 2, Heavy = 1 },
			consumables = { HealingDraught = 1 },
		},
	},
	{
		id = "Plaguebringer",
		name = "Plaguebringer",
		icon = "💀",
		tier = 2,
		color = { 120, 230, 60 },
		tagline = "Stacks venom with homing wisps. Patience kills.",
		kit = {
			wands = {
				{
					template = wand("Rotwood Staff", "Uncommon", "Staff", { 70, 90, 40 }, {
						capacity = 4,
						castDelay = 0.24,
						rechargeTime = 0.7,
						manaMax = 260,
						manaRegen = 60,
						spread = 2,
					}, { { kind = "Affinity", element = "Poison", amount = 0.2 } }),
					spells = { "VenomWisp", "MagicBolt" },
				},
			},
			parts = { Poison = 2, Extend = 1 },
			consumables = { HealingDraught = 1 },
		},
	},
	{
		id = "Stormcaller",
		name = "Stormcaller",
		icon = "⚡",
		tier = 2,
		color = { 255, 235, 90 },
		tagline = "Casts two spells at once with a twin-cast scepter.",
		kit = {
			wands = {
				{
					template = wand("Tempest Scepter", "Uncommon", "Scepter", { 70, 80, 120 }, {
						capacity = 4,
						spellsPerCast = 2,
						castDelay = 0.22,
						rechargeTime = 0.6,
						manaMax = 200,
						manaRegen = 60,
						spread = 3,
					}),
					spells = { "QuickSpark", "TwinSparks" },
				},
			},
			parts = { Lightning = 1, Haste = 1 },
			consumables = { ManaTonic = 1 },
		},
	},

	---------------------------------------------------------------- Gold ($4.99): rare gear
	{
		id = "Voidwalker",
		name = "Voidwalker",
		icon = "🌌",
		tier = 3,
		color = { 150, 70, 210 },
		tagline = "Drains life with every hit, and can blink away.",
		kit = {
			wands = {
				{
					template = wand("Abyssal Focus", "Rare", "Focus", { 40, 20, 60 }, {
						capacity = 3,
						castDelay = 0.1,
						rechargeTime = 0.35,
						manaMax = 200,
						manaRegen = 85,
						spread = 1,
					}, { { kind = "Vampiric", amount = 0.06 } }),
					spells = { "VoidSeeker", "SparkBolt", "MagicBolt" },
				},
			},
			parts = { Void = 1, Leech = 1, Blink = 1 },
			consumables = { HealingDraught = 1, ManaTonic = 1 },
		},
	},
	{
		id = "Bloodmage",
		name = "Bloodmage",
		icon = "🧛",
		tier = 3,
		color = { 210, 30, 50 },
		tagline = "Trades health for raw power. High risk, high reward.",
		kit = {
			wands = {
				{
					template = wand("Sanguine Rod", "Rare", "Rod", { 90, 10, 20 }, {
						capacity = 4,
						castDelay = 0.16,
						rechargeTime = 0.5,
						manaMax = 240,
						manaRegen = 65,
						spread = 1,
					}, { { kind = "Vampiric", amount = 0.05 } }),
					spells = { "BloodGlaive", "Scattershot", "MagicBolt" },
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
		tier = 3,
		color = { 255, 230, 140 },
		tagline = "Every spell homes in. Reveals enemies through walls.",
		kit = {
			wands = {
				{
					template = wand("Sunlit Scepter", "Rare", "Scepter", { 230, 200, 120 }, {
						capacity = 3,
						castDelay = 0.18,
						rechargeTime = 0.5,
						manaMax = 240,
						manaRegen = 60,
						spread = 1,
					}, { { kind = "AlwaysCast", modifier = "Homing" } }),
					spells = { "Sunlance", "SparkBolt", "MagicBolt" },
				},
			},
			parts = { Radiant = 1, Critical = 1 },
			consumables = { HealingDraught = 1, StoneskinPotion = 1 },
		},
	},

	---------------------------------------------------------------- Arcane ($9.99): signature spells
	{
		id = "Artificer",
		name = "Artificer",
		icon = "🔧",
		tier = 4,
		color = { 210, 160, 90 },
		tagline = "Builds walls, throws sawblades and blows things up.",
		kit = {
			wands = {
				{
					template = wand("Tinkerer's Rod", "Rare", "Rod", { 150, 110, 60 }, {
						capacity = 4,
						castDelay = 0.17,
						rechargeTime = 0.5,
						manaMax = 320,
						manaRegen = 80,
						spread = 1,
					}, { { kind = "Affinity", element = "Earth", amount = 0.2 } }),
					spells = { "Ripper", "EarthenRampart", "Fireball", "PebbleToss" },
				},
			},
			parts = { Sawblade = 1, Rampart = 1, Bounce = 1, Explosive = 1 },
			consumables = { HealingDraught = 2, StoneskinPotion = 1 },
		},
	},
	{
		id = "Chronomancer",
		name = "Chronomancer",
		icon = "⏳",
		tier = 4,
		color = { 255, 215, 140 },
		tagline = "Bends time: delayed bombs, frozen foes and swapped places.",
		kit = {
			wands = {
				{
					template = wand("Hourglass Wand", "Rare", "Wand", { 200, 170, 110 }, {
						capacity = 4,
						castDelay = 0.12,
						rechargeTime = 0.4,
						manaMax = 300,
						manaRegen = 90,
						spread = 1,
					}, { { kind = "Affinity", element = "Frost", amount = 0.15 } }),
					spells = { "TimeBomb", "IceShard", "Switcheroo", "Frostbolt" },
				},
			},
			parts = { Stasis = 2, Frost = 1, Quicken = 1 },
			consumables = { HealingDraught = 1, SwiftnessElixir = 1, ManaTonic = 1 },
		},
	},
	{
		id = "Swarmlord",
		name = "Swarmlord",
		icon = "🐝",
		tier = 4,
		color = { 230, 200, 60 },
		tagline = "Never fights alone. Clouds of homing sprites do the work.",
		kit = {
			wands = {
				{
					template = wand("Hive Staff", "Rare", "Staff", { 140, 110, 40 }, {
						capacity = 4,
						castDelay = 0.22,
						rechargeTime = 0.55,
						manaMax = 360,
						manaRegen = 85,
						spread = 2,
					}, { { kind = "Affinity", element = "Poison", amount = 0.2 } }),
					spells = { "Hive", "SeekerSwarm", "VenomWisp", "MagicBolt" },
				},
			},
			parts = { Swarm = 1, Poison = 2, Homing = 1 },
			consumables = { HealingDraught = 2 },
		},
	},

	---------------------------------------------------------------- Astral ($14.99): epic gear
	{
		id = "Stormlord",
		name = "Stormlord",
		icon = "⛈️",
		tier = 5,
		color = { 150, 200, 255 },
		tagline = "Lightning that splits, chains and never stops bouncing.",
		kit = {
			wands = {
				{
					template = wand("Thunderhead Scepter", "Epic", "Scepter", { 60, 70, 110 }, {
						capacity = 4,
						spellsPerCast = 2,
						castDelay = 0.16,
						rechargeTime = 0.45,
						manaMax = 420,
						manaRegen = 120,
						spread = 2,
					}, { { kind = "Affinity", element = "Lightning", amount = 0.2 } }),
					spells = { "HydraStorm", "ChainLightning", "ThunderLance", "TwinSparks" },
				},
			},
			parts = { Lightning = 2, Bounce = 2, Pierce = 1 },
			consumables = { HealingDraught = 2, SwiftnessElixir = 1 },
		},
	},
	{
		id = "VoidArchon",
		name = "Void Archon",
		icon = "🕳️",
		tier = 5,
		color = { 120, 50, 170 },
		tagline = "Opens black holes and swaps places with whatever's inside.",
		kit = {
			wands = {
				{
					template = wand("Event Staff", "Epic", "Staff", { 30, 10, 50 }, {
						capacity = 4,
						castDelay = 0.22,
						rechargeTime = 0.55,
						manaMax = 480,
						manaRegen = 120,
						spread = 1,
					}, { { kind = "Vampiric", amount = 0.06 } }),
					spells = { "BlackHole", "VoidSeeker", "Switcheroo", "MagicBolt" },
				},
				{
					template = wand("Phase Focus", "Rare", "Focus", { 80, 40, 120 }, {
						capacity = 2,
						castDelay = 0.1,
						rechargeTime = 0.3,
						manaMax = 200,
						manaRegen = 90,
						spread = 1,
					}),
					spells = { "EscapeStep", "SparkBolt" },
				},
			},
			parts = { Void = 2, Magnetic = 1, Leech = 1 },
			consumables = { HealingDraught = 2, ManaTonic = 1 },
		},
	},

	---------------------------------------------------------------- Archmage ($24.99): legendary gear
	{
		id = "Archmage",
		name = "Archmage",
		icon = "🌟",
		tier = 6,
		color = { 255, 210, 120 },
		tagline = "A legendary twin-cast staff that rains stars and fireworks.",
		kit = {
			wands = {
				{
					template = wand("Staff of the Archmage", "Legendary", "Staff", { 255, 240, 200 }, {
						capacity = 5,
						spellsPerCast = 2,
						castDelay = 0.15,
						rechargeTime = 0.45,
						manaMax = 600,
						manaRegen = 160,
						spread = 1,
					}, { { kind = "Affinity", element = "Arcane", amount = 0.25 } }),
					spells = { "ArcaneRain", "Fireworks", "Starfall", "MagicMissile" },
				},
				{
					template = wand("Warding Focus", "Epic", "Focus", { 170, 230, 255 }, {
						capacity = 2,
						castDelay = 0.1,
						rechargeTime = 0.3,
						manaMax = 260,
						manaRegen = 110,
						spread = 1,
					}),
					spells = { "EscapeStep", "Bulwark" },
				},
			},
			parts = { Fractal = 1, Skyfall = 1, Arcane = 2, Triple = 1 },
			consumables = { HealingDraught = 2, ManaTonic = 2, StoneskinPotion = 1 },
		},
	},
	{
		id = "Harbinger",
		name = "Harbinger",
		icon = "☄️",
		tier = 6,
		color = { 255, 90, 60 },
		tagline = "A watching eye, falling meteors and pure chaos.",
		kit = {
			wands = {
				{
					template = wand("Harbinger's Rod", "Legendary", "Rod", { 255, 120, 50 }, {
						capacity = 4,
						castDelay = 0.2,
						rechargeTime = 0.5,
						manaMax = 650,
						manaRegen = 150,
						spread = 1,
					}, {
						{ kind = "Affinity", element = "Fire", amount = 0.25 },
						{ kind = "Siphon", amount = 10 } :: any,
					}),
					spells = { "WatchfulEye", "Meteor", "SeekingInferno", "Fireball" },
				},
				{
					template = wand("Chaos Scepter", "Epic", "Scepter", { 255, 80, 200 }, {
						capacity = 2,
						spellsPerCast = 2,
						castDelay = 0.25,
						rechargeTime = 0.6,
						manaMax = 300,
						manaRegen = 100,
						spread = 3,
					}),
					spells = { "ChaosOrb", "Sparkler" },
				},
			},
			parts = { Sentry = 1, Chaos = 1, Gigantic = 1, Explosive = 2 },
			consumables = { HealingDraught = 2, StoneskinPotion = 1, ManaTonic = 1 },
		},
	},
} :: { ClassDef }

Classes.ById = {} :: { [string]: ClassDef }
for _, c in Classes.List do
	Classes.ById[c.id] = c
end

Classes.Default = "Apprentice"

function Classes.tierInfo(tier: number): Tier
	return Classes.Tiers[tier + 1] or Classes.Tiers[1]
end

function Classes.isFree(class: ClassDef): boolean
	return class.tier == 0
end

-- "75% Common · 25% Uncommon", rarest last.
function Classes.oddsText(tier: number): string
	local odds = Classes.tierInfo(tier).bonusOdds
	local parts = {}
	for _, rarity in Rarity.Order do
		local pct = odds[rarity]
		if pct and pct > 0 then
			table.insert(parts, pct .. "% " .. rarity)
		end
	end
	return table.concat(parts, " · ")
end

-- The random bonus spell part a kit hands out each match: roll a rarity with the tier's odds,
-- then pick any part of that rarity.
function Classes.rollBonusPart(class: ClassDef, rng: any): string
	local odds = Classes.tierInfo(class.tier).bonusOdds
	local total = 0
	for _, pct in odds do
		total += pct
	end
	local pick = rng:NextNumber(0, total)
	local rarity = "Common"
	for _, name in Rarity.Order do
		local pct = odds[name]
		if pct then
			rarity = name
			pick -= pct
			if pick <= 0 then
				break
			end
		end
	end
	local pool = {}
	for _, part in SpellParts.List do
		if part.rarity == rarity then
			table.insert(pool, part.id)
		end
	end
	if #pool == 0 then
		return "Bolt"
	end
	return pool[rng:NextInteger(1, #pool)]
end

return Classes
