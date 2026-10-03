--!strict
-- Procedurally generates wands. Rarity scales every stat and adds perks.

local Items = require(script.Parent.Items)
local Rarity = require(script.Parent.Rarity)
local SpellParts = require(script.Parent.Spells.SpellParts)

type WandItem = Items.WandItem
type WandStats = Items.WandStats
type Perk = Items.Perk

local WandGenerator = {}

type Range = { number }

type WandType = {
	weight: number,
	capacity: Range,
	castDelay: Range,
	recharge: Range,
	manaMax: Range,
	regen: Range,
	spread: Range,
	multicastBias: number,
}

WandGenerator.Types = {
	Wand = {
		weight = 30,
		capacity = { 2, 4 },
		castDelay = { 0.08, 0.2 },
		recharge = { 0.3, 0.65 },
		manaMax = { 110, 240 },
		regen = { 35, 70 },
		spread = { 0, 4 },
		multicastBias = 0,
	},
	Rod = {
		weight = 25,
		capacity = { 3, 5 },
		castDelay = { 0.12, 0.28 },
		recharge = { 0.35, 0.85 },
		manaMax = { 160, 340 },
		regen = { 40, 90 },
		spread = { 0, 3 },
		multicastBias = 0.05,
	},
	Staff = {
		weight = 20,
		capacity = { 4, 7 },
		castDelay = { 0.18, 0.38 },
		recharge = { 0.55, 1.15 },
		manaMax = { 240, 480 },
		regen = { 50, 110 },
		spread = { 0, 6 },
		multicastBias = 0.05,
	},
	Scepter = {
		weight = 15,
		capacity = { 2, 4 },
		castDelay = { 0.12, 0.26 },
		recharge = { 0.4, 0.9 },
		manaMax = { 180, 360 },
		regen = { 45, 95 },
		spread = { 0, 3 },
		multicastBias = 0.35,
	},
	Focus = {
		weight = 10,
		capacity = { 1, 3 },
		castDelay = { 0.04, 0.12 },
		recharge = { 0.15, 0.4 },
		manaMax = { 90, 200 },
		regen = { 70, 140 },
		spread = { 0, 2 },
		multicastBias = 0,
	},
} :: { [string]: WandType }

WandGenerator.TypeOrder = { "Wand", "Rod", "Staff", "Scepter", "Focus" }

-- Materials per rarity: name + handle colour
WandGenerator.Materials = {
	Common = {
		{ "Oak", { 140, 100, 60 } },
		{ "Birch", { 220, 210, 180 } },
		{ "Ash", { 120, 115, 105 } },
		{ "Pine", { 110, 80, 50 } },
	},
	Uncommon = {
		{ "Yew", { 100, 60, 40 } },
		{ "Willow", { 150, 140, 90 } },
		{ "Bone", { 235, 230, 210 } },
		{ "Copper", { 190, 110, 60 } },
	},
	Rare = {
		{ "Silver", { 200, 205, 215 } },
		{ "Moonwood", { 120, 130, 190 } },
		{ "Ivory", { 250, 245, 230 } },
		{ "Jade", { 80, 170, 120 } },
	},
	Epic = {
		{ "Obsidian", { 40, 30, 50 } },
		{ "Crystal", { 170, 230, 255 } },
		{ "Dragonbone", { 200, 190, 150 } },
		{ "Starsteel", { 120, 140, 200 } },
	},
	Legendary = {
		{ "Celestial", { 255, 240, 200 } },
		{ "Phoenix", { 255, 120, 50 } },
		{ "Worldtree", { 90, 140, 70 } },
		{ "Runic", { 80, 200, 255 } },
	},
	Mythic = { { "Primordial", { 255, 80, 120 } }, { "Eldritch", { 90, 40, 120 } }, { "Astral", { 200, 160, 255 } } },
} :: { [string]: { { any } } }

local AFFINITY_SUFFIX = {
	Arcane = "Sorcery",
	Fire = "Embers",
	Frost = "Winter",
	Lightning = "Storms",
	Poison = "Plague",
	Void = "the Void",
	Earth = "Mountains",
	Wind = "Gales",
	Radiant = "Dawn",
	Blood = "Blood",
}

local ALWAYS_SUFFIX = {
	Homing = "Seeking",
	Haste = "Haste",
	Pierce = "Piercing",
	Bounce = "Ricochets",
	Critical = "Precision",
	Empower = "Might",
	Enlarge = "Giants",
	Extend = "Reach",
	Explosive = "Ruin",
	Leech = "Hunger",
	Twin = "Twins",
}

local ALWAYS_CAST_BASIC = { "Homing", "Haste", "Pierce", "Bounce", "Critical", "Empower", "Enlarge", "Extend" }
local ALWAYS_CAST_RARE = { "Explosive", "Leech", "Twin" }

local function roll(rng: any, range: Range): number
	return rng:NextNumber(range[1], range[2])
end

local function round(n: number, places: number): number
	local p = 10 ^ places
	return math.floor(n * p + 0.5) / p
end

local function pickWeighted(rng: any, entries: { { any } }): any
	local total = 0
	for _, e in entries do
		total += e[2]
	end
	local pick = rng:NextNumber(0, total)
	for _, e in entries do
		pick -= e[2]
		if pick <= 0 then
			return e[1]
		end
	end
	return entries[#entries][1]
end

local function elementIds(): { string }
	local ids = {}
	for _, part in SpellParts.ByCategory.Element do
		table.insert(ids, part.id)
	end
	return ids
end

local function rollPerk(rng: any, rank: number, taken: { [string]: boolean }): Perk?
	local options: { { any } } = {}
	if not taken.Affinity then
		table.insert(options, { "Affinity", 4 } :: { any })
	end
	if not taken.AlwaysCast then
		table.insert(options, { "AlwaysCast", 3 } :: { any })
	end
	if not taken.Siphon then
		table.insert(options, { "Siphon", 2 } :: { any })
	end
	if not taken.Vampiric then
		table.insert(options, { "Vampiric", 2 } :: { any })
	end
	if #options == 0 then
		return nil
	end
	local kind = pickWeighted(rng, options)
	taken[kind] = true
	if kind == "Affinity" then
		local ids = elementIds()
		return {
			kind = kind,
			element = ids[rng:NextInteger(1, #ids)],
			amount = round(0.2 + 0.05 * (rank - 1), 2),
		} :: Perk
	elseif kind == "AlwaysCast" then
		local pool = table.clone(ALWAYS_CAST_BASIC)
		if rank >= 5 then
			for _, id in ALWAYS_CAST_RARE do
				table.insert(pool, id)
			end
		end
		return { kind = kind, modifier = pool[rng:NextInteger(1, #pool)] } :: Perk
	elseif kind == "Siphon" then
		return { kind = kind, amount = 4 + 2 * rank } :: Perk
	else
		return { kind = kind, amount = round(0.03 + 0.01 * rank, 2) } :: Perk
	end
end

function WandGenerator.perkSuffix(perk: Perk): string
	if perk.kind == "Affinity" then
		return AFFINITY_SUFFIX[perk.element or ""] or "Elements"
	elseif perk.kind == "AlwaysCast" then
		return ALWAYS_SUFFIX[perk.modifier or ""] or "Echoes"
	elseif perk.kind == "Siphon" then
		return "Siphoning"
	end
	return "Thirst"
end

function WandGenerator.describePerk(perk: Perk): string
	if perk.kind == "Affinity" then
		return string.format("+%d%% %s damage", math.floor((perk.amount or 0) * 100 + 0.5), perk.element or "?")
	elseif perk.kind == "AlwaysCast" then
		local part = SpellParts.get(perk.modifier)
		return "Always casts " .. (if part then part.name else "?")
	elseif perk.kind == "Siphon" then
		return string.format("+%d mana on hit", perk.amount or 0)
	elseif perk.kind == "Vampiric" then
		return string.format("%d%% lifesteal", math.floor((perk.amount or 0) * 100 + 0.5))
	end
	return perk.kind
end

-- rng: Roblox Random (or shim). rarity: optional forced rarity. wandType: optional forced type.
function WandGenerator.generate(rng: any, rarity: string?, wandType: string?): WandItem
	local rarityName = rarity or Rarity.roll(rng, 0)
	local rank = Rarity.rank(rarityName)

	local typeName = wandType
	if typeName == nil then
		local entries = {}
		for _, name in WandGenerator.TypeOrder do
			table.insert(entries, { name, WandGenerator.Types[name].weight } :: { any })
		end
		typeName = pickWeighted(rng, entries)
	end
	assert(typeName, "wand type missing")
	local t = WandGenerator.Types[typeName]
	local step = rank - 1

	local spellsPerCast = 1
	local twoChance = ({ 0, 0.05, 0.15, 0.3, 0.45, 0.6 })[rank] + t.multicastBias
	if rng:NextNumber() < twoChance then
		spellsPerCast = 2
		if rank >= 5 and rng:NextNumber() < 0.15 + t.multicastBias * 0.5 then
			spellsPerCast = 3
		end
	end

	local capacity = rng:NextInteger(t.capacity[1], t.capacity[2]) + math.floor(step * 0.7)
	capacity = math.clamp(math.max(capacity, spellsPerCast), 1, 10)

	local shuffleChance = ({ 0.55, 0.4, 0.25, 0.12, 0.05, 0 })[rank]
	if spellsPerCast > 1 then
		shuffleChance *= 0.6
	end

	local stats: WandStats = {
		capacity = capacity,
		spellsPerCast = spellsPerCast,
		castDelay = round(roll(rng, t.castDelay) * (1 - 0.07 * step), 2),
		rechargeTime = round(roll(rng, t.recharge) * (1 - 0.08 * step), 2),
		manaMax = math.floor(roll(rng, t.manaMax) * (1 + 0.18 * step)),
		manaRegen = math.floor(roll(rng, t.regen) * (1 + 0.15 * step)),
		spread = round(math.max(0, roll(rng, t.spread) * (1 - 0.12 * step)), 1),
		speedMult = round(rng:NextNumber(0.9, 1.2) + 0.02 * step, 2),
		damageMult = round(1 + 0.04 * step + rng:NextNumber(-0.05, 0.08), 2),
		shuffle = rng:NextNumber() < shuffleChance,
	}

	local perkCount = 0
	if rank == 2 then
		perkCount = if rng:NextNumber() < 0.4 then 1 else 0
	elseif rank == 3 then
		perkCount = 1
	elseif rank == 4 then
		perkCount = rng:NextInteger(1, 2)
	elseif rank == 5 then
		perkCount = 2
	elseif rank >= 6 then
		perkCount = 3
	end
	local perks: { Perk } = {}
	local taken: { [string]: boolean } = {}
	for _ = 1, perkCount do
		local perk = rollPerk(rng, rank, taken)
		if perk then
			table.insert(perks, perk)
		end
	end

	local materials = WandGenerator.Materials[rarityName]
	local material = materials[rng:NextInteger(1, #materials)]
	local name = material[1] .. " " .. typeName
	if #perks > 0 then
		name ..= " of " .. WandGenerator.perkSuffix(perks[1])
	elseif spellsPerCast == 2 then
		name = "Twincast " .. name
	elseif spellsPerCast >= 3 then
		name = "Tricast " .. name
	end

	local slots: { any } = {}
	for i = 1, capacity do
		slots[i] = false
	end

	return {
		uid = Items.newUid("w"),
		name = name,
		rarity = rarityName,
		wandType = typeName,
		color = material[2],
		stats = stats,
		perks = perks,
		slots = slots,
	}
end

export type WandTemplate = {
	name: string,
	rarity: string,
	wandType: string,
	color: { number }?,
	stats: { [string]: any },
	perks: { Perk }?,
}

-- Builds a fixed wand (used for class starting kits).
function WandGenerator.fromTemplate(template: WandTemplate): WandItem
	local s = template.stats
	local stats: WandStats = {
		capacity = s.capacity or 3,
		spellsPerCast = s.spellsPerCast or 1,
		castDelay = s.castDelay or 0.2,
		rechargeTime = s.rechargeTime or 0.5,
		manaMax = s.manaMax or 200,
		manaRegen = s.manaRegen or 60,
		spread = s.spread or 1,
		speedMult = s.speedMult or 1,
		damageMult = s.damageMult or 1,
		shuffle = s.shuffle == true,
	}
	local slots: { any } = {}
	for i = 1, stats.capacity do
		slots[i] = false
	end
	return {
		uid = Items.newUid("w"),
		name = template.name,
		rarity = template.rarity,
		wandType = template.wandType,
		color = template.color or { 140, 100, 60 },
		stats = stats,
		perks = template.perks and table.clone(template.perks) or {},
		slots = slots,
	}
end

return WandGenerator
