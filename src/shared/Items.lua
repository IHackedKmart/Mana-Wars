--!strict
-- Plain-data item shapes shared by server and client. Everything here survives RemoteEvents.

local Rarity = require(script.Parent.Rarity)
local SpellTypes = require(script.Parent.Spells.SpellTypes)
local SpellBuilder = require(script.Parent.Spells.SpellBuilder)

type Recipe = SpellTypes.Recipe

export type SpellItem = {
	uid: string,
	name: string,
	rarity: string,
	recipe: Recipe,
	premadeId: string?,
}

export type Perk = {
	kind: string, -- "Affinity" | "AlwaysCast" | "Siphon" | "Vampiric"
	element: string?,
	modifier: string?,
	amount: number?,
}

export type WandStats = {
	capacity: number,
	spellsPerCast: number,
	castDelay: number,
	rechargeTime: number,
	manaMax: number,
	manaRegen: number,
	spread: number,
	speedMult: number,
	damageMult: number,
	shuffle: boolean,
}

export type WandItem = {
	uid: string,
	name: string,
	rarity: string,
	wandType: string,
	color: { number },
	stats: WandStats,
	perks: { Perk },
	slots: { SpellItem | false },
}

export type Inventory = {
	wands: { WandItem | false },
	equipped: number,
	spells: { SpellItem },
	parts: { [string]: number },
	consumables: { [string]: number },
}

-- A single entry inside a chest / satchel
export type LootEntry = {
	kind: string, -- "Part" | "Spell" | "Wand" | "Consumable"
	id: string?, -- part id or consumable id
	count: number?,
	spell: SpellItem?,
	wand: WandItem?,
}

local Items = {}

local counter = 0
local sessionTag = string.format("%x", math.floor((os.clock() * 1000) % 0xFFFFF))

function Items.newUid(prefix: string?): string
	counter += 1
	return (prefix or "i") .. sessionTag .. "_" .. counter
end

-- Rarity of a crafted spell is driven by the rarest part inside it and its complexity.
function Items.rarityOfRecipe(recipe: Recipe, partRarity: (string) -> string): string
	local best = 1
	local function visit(r: Recipe)
		for id in SpellBuilder.countParts(r) do
			best = math.max(best, Rarity.rank(partRarity(id)))
		end
		if r.payload then
			visit(r.payload)
		end
	end
	visit(recipe)
	if SpellBuilder.complexity(recipe) >= 7 then
		best += 1
	end
	return Rarity.fromRank(best)
end

function Items.newSpell(recipe: Recipe, name: string?, rarity: string?, premadeId: string?): SpellItem
	local spec = SpellBuilder.compile(recipe)
	return {
		uid = Items.newUid("s"),
		name = name or (if spec then spec.name else "Unknown Spell"),
		rarity = rarity or "Common",
		recipe = SpellBuilder.sanitize(recipe),
		premadeId = premadeId,
	}
end

function Items.newInventory(): Inventory
	return {
		wands = { false, false, false, false },
		equipped = 1,
		spells = {},
		parts = {},
		consumables = {},
	}
end

-- Builds the WandContext that SpellBuilder uses to fold wand bonuses into spells.
function Items.wandContext(wand: WandItem): SpellBuilder.WandContext
	local ctx: SpellBuilder.WandContext = {
		damageMult = wand.stats.damageMult,
		speedMult = wand.stats.speedMult,
	}
	local always: { string } = {}
	for _, perk in wand.perks do
		if perk.kind == "Affinity" then
			ctx.affinity = perk.element
			ctx.affinityBonus = perk.amount
		elseif perk.kind == "AlwaysCast" and perk.modifier then
			table.insert(always, perk.modifier)
		end
	end
	if #always > 0 then
		ctx.alwaysCast = always
	end
	return ctx
end

function Items.perkValue(wand: WandItem, kind: string): number
	local total = 0
	for _, perk in wand.perks do
		if perk.kind == kind then
			total += perk.amount or 0
		end
	end
	return total
end

function Items.deepCopy<T>(value: T): T
	if type(value) ~= "table" then
		return value
	end
	local out = {}
	for k, v in value :: any do
		out[Items.deepCopy(k)] = Items.deepCopy(v)
	end
	return out :: any
end

return Items
