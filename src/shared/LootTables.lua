--!strict
-- What can be found in chests. Cornucopia and shrine chests roll with more luck.

local Items = require(script.Parent.Items)
local Rarity = require(script.Parent.Rarity)
local Consumables = require(script.Parent.Consumables)
local WandGenerator = require(script.Parent.WandGenerator)
local SpellParts = require(script.Parent.Spells.SpellParts)
local PremadeSpells = require(script.Parent.Spells.PremadeSpells)
local SpellTypes = require(script.Parent.Spells.SpellTypes)

type LootEntry = Items.LootEntry
type SpellItem = Items.SpellItem
type Recipe = SpellTypes.Recipe

local LootTables = {}

export type Tier = {
	displayName: string,
	rolls: { number },
	luck: number,
	weights: { [string]: number },
	maxWandRank: number,
	healChance: number, -- chance of a Healing Draught on top of the rolls
}

-- Chests hold only a few things each (so your bag doesn't overflow), plus a good chance of a
-- Healing Draught.
LootTables.Tiers = {
	Outer = {
		displayName = "Chest",
		rolls = { 1, 3 },
		luck = 0,
		weights = { Part = 52, Spell = 22, Wand = 9, Consumable = 17 },
		maxWandRank = 4,
		healChance = 0.5,
	},
	House = { -- inside the battle royale's cottages and castles
		displayName = "Cupboard",
		rolls = { 1, 3 },
		luck = 0.4,
		weights = { Part = 48, Spell = 24, Wand = 11, Consumable = 17 },
		maxWandRank = 5,
		healChance = 0.55,
	},
	Cornucopia = {
		displayName = "Cornucopia Chest",
		rolls = { 2, 3 },
		luck = 0.9,
		weights = { Part = 40, Spell = 27, Wand = 18, Consumable = 15 },
		maxWandRank = 6,
		healChance = 0.6,
	},
	Shrine = {
		displayName = "Shrine Reliquary",
		rolls = { 2, 4 },
		luck = 2.2,
		weights = { Part = 34, Spell = 30, Wand = 24, Consumable = 12 },
		maxWandRank = 6,
		healChance = 0.8,
	},
	Refill = {
		displayName = "Chest",
		rolls = { 1, 3 },
		luck = 1.2,
		weights = { Part = 45, Spell = 25, Wand = 14, Consumable = 16 },
		maxWandRank = 6,
		healChance = 0.6,
	},
} :: { [string]: Tier }

local function pickWeighted(rng: any, weights: { [string]: number }, order: { string }): string
	local total = 0
	for _, key in order do
		total += weights[key] or 0
	end
	local pick = rng:NextNumber(0, total)
	for _, key in order do
		pick -= weights[key] or 0
		if pick <= 0 then
			return key
		end
	end
	return order[#order]
end

local KIND_ORDER = { "Part", "Spell", "Wand", "Consumable" }

local function partRarity(id: string): string
	local part = SpellParts.ById[id]
	return if part then part.rarity else "Common"
end

function LootTables.rollPart(rng: any, luck: number): string
	-- Pick a rarity first, then a part of that rarity (falling back to lower tiers if empty).
	local rarity = Rarity.roll(rng, luck)
	for rank = Rarity.rank(rarity), 1, -1 do
		local pool = {}
		for _, part in SpellParts.List do
			if Rarity.rank(part.rarity) == rank then
				table.insert(pool, part)
			end
		end
		if #pool > 0 then
			return pool[rng:NextInteger(1, #pool)].id
		end
	end
	return "Bolt"
end

-- A random but valid crafted spell, so chests also contain spells nobody designed.
function LootTables.rollRandomRecipe(rng: any, luck: number, depth: number?): Recipe
	local d = depth or 1
	local forms = SpellParts.ByCategory.Form
	local recipe: Recipe = {
		form = LootTables.rollFromCategory(rng, "Form", luck) or forms[1].id,
		element = if rng:NextNumber() < 0.85 then LootTables.rollFromCategory(rng, "Element", luck) else nil,
		mods = {},
	}
	local modCount = rng:NextInteger(0, if luck > 1 then 3 else 2)
	for _ = 1, modCount do
		local id = LootTables.rollFromCategory(rng, "Modifier", luck)
		if id and recipe.mods then
			table.insert(recipe.mods, id)
		end
	end
	if d < 2 and rng:NextNumber() < 0.12 + luck * 0.05 then
		recipe.trigger = LootTables.rollFromCategory(rng, "Trigger", luck)
		recipe.payload = LootTables.rollRandomRecipe(rng, luck * 0.5, d + 1)
		if recipe.trigger == nil then
			recipe.payload = nil
		end
	end
	return recipe
end

function LootTables.rollFromCategory(rng: any, category: string, luck: number): string?
	local list = SpellParts.ByCategory[category]
	local total = 0
	for _, part in list do
		total += Rarity.weightFor(part.rarity, luck)
	end
	local pick = rng:NextNumber(0, total)
	for _, part in list do
		pick -= Rarity.weightFor(part.rarity, luck)
		if pick <= 0 then
			return part.id
		end
	end
	return if #list > 0 then list[#list].id else nil
end

function LootTables.rollSpell(rng: any, luck: number): SpellItem
	if rng:NextNumber() < 0.3 then
		local recipe = LootTables.rollRandomRecipe(rng, luck)
		return Items.newSpell(recipe, nil, Items.rarityOfRecipe(recipe, partRarity))
	end
	local rarity = Rarity.roll(rng, luck)
	for rank = Rarity.rank(rarity), 1, -1 do
		local pool = {}
		for _, premade in PremadeSpells.List do
			if Rarity.rank(premade.rarity) == rank then
				table.insert(pool, premade)
			end
		end
		if #pool > 0 then
			local premade = pool[rng:NextInteger(1, #pool)]
			return Items.newSpell(premade.recipe, premade.name, premade.rarity, premade.id)
		end
	end
	local fallback = PremadeSpells.List[1]
	return Items.newSpell(fallback.recipe, fallback.name, fallback.rarity, fallback.id)
end

function LootTables.premadeSpell(id: string): SpellItem
	local premade = PremadeSpells.ById[id]
	assert(premade, "unknown premade spell " .. id)
	return Items.newSpell(premade.recipe, premade.name, premade.rarity, premade.id)
end

function LootTables.rollWand(rng: any, luck: number, maxRank: number?): Items.WandItem
	local rarity = Rarity.roll(rng, luck, maxRank)
	local wand = WandGenerator.generate(rng, rarity)
	-- Found wands come with a spell or two already slotted, like in Noita.
	local preload = math.min(wand.stats.capacity, rng:NextInteger(1, 2))
	for i = 1, preload do
		wand.slots[i] = LootTables.rollSpell(rng, math.max(0, luck - 0.5))
	end
	return wand
end

function LootTables.rollConsumable(rng: any, luck: number): string
	local weights: { [string]: number } = {}
	local order: { string } = {}
	for _, c in Consumables.List do
		weights[c.id] = Rarity.weightFor(c.rarity, luck)
		table.insert(order, c.id)
	end
	return pickWeighted(rng, weights, order)
end

function LootTables.rollEntry(rng: any, tier: Tier): LootEntry
	local kind = pickWeighted(rng, tier.weights, KIND_ORDER)
	if kind == "Part" then
		return { kind = "Part", id = LootTables.rollPart(rng, tier.luck), count = 1 }
	elseif kind == "Spell" then
		return { kind = "Spell", spell = LootTables.rollSpell(rng, tier.luck) }
	elseif kind == "Wand" then
		return { kind = "Wand", wand = LootTables.rollWand(rng, tier.luck, tier.maxWandRank) }
	end
	return { kind = "Consumable", id = LootTables.rollConsumable(rng, tier.luck), count = 1 }
end

function LootTables.rollChest(rng: any, tierName: string): { LootEntry }
	local tier = LootTables.Tiers[tierName] or LootTables.Tiers.Outer
	local entries: { LootEntry } = {}
	local n = rng:NextInteger(tier.rolls[1], tier.rolls[2])
	local heal = rng:NextNumber() < tier.healChance
	for i = 1, n + (if heal then 1 else 0) do
		local entry = if i > n
			then { kind = "Consumable", id = "HealingDraught", count = 1 } :: LootEntry
			else LootTables.rollEntry(rng, tier)
		-- merge duplicate parts / potions into stacks
		local merged = false
		if entry.kind == "Part" or entry.kind == "Consumable" then
			for _, existing in entries do
				if existing.kind == entry.kind and existing.id == entry.id then
					existing.count = (existing.count or 1) + 1
					merged = true
					break
				end
			end
		end
		if not merged then
			table.insert(entries, entry)
		end
	end
	return entries
end

LootTables.partRarity = partRarity

return LootTables
