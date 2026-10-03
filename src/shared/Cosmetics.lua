--!strict
-- Robes and hats. Players win Enchanted Coins in matches, open Coffers for random garment parts,
-- stitch three parts into a robe or a hat at the Tailor, and wear them into matches.
--
--   Robe = Cloth (silhouette, colour, material) + Trim (hems, belt, cuffs) + Sigil (chest emblem + aura)
--   Hat  = Shape (the hat itself)               + Band (hat band)          + Gem (ornament + aura)
--
-- Every part rolls its design, colour, material, aura and 1-3 enchantments (small gameplay
-- bonuses) from pools gated by rarity and by which Coffer it came from, so there are thousands of
-- possible parts and far more finished outfits.
--
-- Auras (smoke, embers, lightning...) come from the Sigil / Gem, but they can only shine ONE TIER
-- brighter than the garment they're sewn into (see Cosmetics.auraLevel). A Legendary sigil on a
-- rag robe only glimmers; a full Legendary robe billows. Matching auras on robe AND hat add a trail.

local Rarity = require(script.Parent.Rarity)
local Items = require(script.Parent.Items)

local Cosmetics = {}

export type Enchant = { stat: string, amount: number }

export type CosmeticPart = {
	uid: string,
	slot: string, -- "Cloth" | "Trim" | "Sigil" | "Shape" | "Band" | "Gem"
	rarity: string,
	design: string,
	color: string, -- palette id
	material: string, -- material id
	aura: string?, -- Sigil / Gem only
	enchants: { Enchant },
	box: number, -- the Coffer it came from (0 = starter gear)
	name: string,
}

export type Garment = {
	uid: string,
	kind: string, -- "Robe" | "Hat"
	name: string,
	rarity: string, -- the garment's resonance (average of its parts, rounded down)
	parts: { [string]: CosmeticPart }, -- by slot
}

export type Gear = { [string]: number } -- stat -> total bonus (see Cosmetics.Enchants)

---------------------------------------------------------------------------
-- Slots
---------------------------------------------------------------------------

Cosmetics.Garments = {
	Robe = { slots = { "Cloth", "Trim", "Sigil" }, verb = "Stitch", icon = "👘" },
	Hat = { slots = { "Shape", "Band", "Gem" }, verb = "Craft", icon = "🎩" },
}
Cosmetics.GarmentOrder = { "Robe", "Hat" }

Cosmetics.Slots = {
	Cloth = { garment = "Robe", label = "Robe cloth", icon = "👘" },
	Trim = { garment = "Robe", label = "Trim", icon = "🧵" },
	Sigil = { garment = "Robe", label = "Sigil", icon = "🔯" },
	Shape = { garment = "Hat", label = "Hat", icon = "🎩" },
	Band = { garment = "Hat", label = "Hat band", icon = "🎀" },
	Gem = { garment = "Hat", label = "Gem", icon = "💎" },
}
Cosmetics.SlotOrder = { "Cloth", "Trim", "Sigil", "Shape", "Band", "Gem" }

---------------------------------------------------------------------------
-- Designs. minRarity: the lowest rarity it can roll at. minBox: the cheapest Coffer that can drop
-- it. boxes: if set, ONLY these Coffers drop it (collection exclusives).
---------------------------------------------------------------------------

export type Design = {
	id: string,
	name: string,
	minRarity: string,
	minBox: number?,
	boxes: { number }?,
	glyph: string?, -- sigils
}

local function designs(list: { Design }): { [string]: Design }
	local byId = {}
	for _, d in list do
		byId[d.id] = d
	end
	return byId
end

Cosmetics.Designs = {
	Cloth = {
		{ id = "Straight", name = "Novice Robe", minRarity = "Common" },
		{ id = "Patchwork", name = "Patchwork Robe", minRarity = "Common", boxes = { 1 } },
		{ id = "Bell", name = "Bell Robe", minRarity = "Common" },
		{ id = "Cloak", name = "Wanderer's Cloak", minRarity = "Uncommon" },
		{ id = "Monk", name = "Monk's Habit", minRarity = "Uncommon", minBox = 2 },
		{ id = "Battle", name = "Battlemage Tabard", minRarity = "Rare" },
		{ id = "Shadow", name = "Shadow Wrap", minRarity = "Epic", minBox = 3 },
		{ id = "Royal", name = "Royal Robe", minRarity = "Epic", minBox = 3 },
		{ id = "Archmage", name = "Archmage Regalia", minRarity = "Legendary", minBox = 4 },
		{ id = "Crystal", name = "Crystalweave", minRarity = "Legendary", boxes = { 5 } },
		{ id = "Celestial", name = "Celestial Vestment", minRarity = "Mythic", boxes = { 5 } },
	},
	Trim = {
		{ id = "Hem", name = "Plain Hem", minRarity = "Common" },
		{ id = "Double", name = "Double Hem", minRarity = "Common" },
		{ id = "Fur", name = "Fur Trim", minRarity = "Uncommon" },
		{ id = "Embroidered", name = "Embroidered Trim", minRarity = "Uncommon", minBox = 2 },
		{ id = "Gilded", name = "Gilded Trim", minRarity = "Rare" },
		{ id = "Chain", name = "Chainmail Trim", minRarity = "Rare", minBox = 2 },
		{ id = "Runic", name = "Runic Trim", minRarity = "Epic", minBox = 3 },
		{ id = "Starlit", name = "Starlit Trim", minRarity = "Mythic", boxes = { 5 } },
	},
	Sigil = {
		{ id = "Star", name = "Star", glyph = "✦", minRarity = "Common" },
		{ id = "Moon", name = "Moon", glyph = "☾", minRarity = "Common" },
		{ id = "Leaf", name = "Leaf", glyph = "❦", minRarity = "Common", boxes = { 1, 2 } },
		{ id = "Sun", name = "Sun", glyph = "☀", minRarity = "Uncommon" },
		{ id = "Flame", name = "Flame", glyph = "♨", minRarity = "Uncommon" },
		{ id = "Snow", name = "Snowflake", glyph = "❄", minRarity = "Uncommon" },
		{ id = "Bolt", name = "Thunder", glyph = "⚡", minRarity = "Rare" },
		{ id = "Skull", name = "Skull", glyph = "☠", minRarity = "Rare", minBox = 2 },
		{ id = "Eye", name = "Eye", glyph = "◉", minRarity = "Rare", minBox = 3 },
		{ id = "Balance", name = "Balance", glyph = "☯", minRarity = "Epic", minBox = 3 },
		{ id = "Trident", name = "Trident", glyph = "♆", minRarity = "Legendary", minBox = 4 },
		{ id = "Infinity", name = "Infinity", glyph = "∞", minRarity = "Legendary", minBox = 4 },
		{ id = "Crown", name = "Crown", glyph = "♛", minRarity = "Mythic", boxes = { 5 } },
		{ id = "Nova", name = "Nova", glyph = "✺", minRarity = "Mythic", boxes = { 5 } },
	},
	Shape = {
		{ id = "Pointed", name = "Pointed Hat", minRarity = "Common" },
		{ id = "Hood", name = "Hood", minRarity = "Common" },
		{ id = "Straw", name = "Straw Hat", minRarity = "Common", boxes = { 1 } },
		{ id = "Cap", name = "Feathered Cap", minRarity = "Uncommon" },
		{ id = "TopHat", name = "Top Hat", minRarity = "Uncommon", minBox = 2 },
		{ id = "Witch", name = "Witch Hat", minRarity = "Uncommon" },
		{ id = "Circlet", name = "Circlet", minRarity = "Rare" },
		{ id = "Tricorn", name = "Tricorn", minRarity = "Rare", minBox = 2 },
		{ id = "Horned", name = "Horned Helm", minRarity = "Epic", minBox = 3 },
		{ id = "Mitre", name = "Mitre", minRarity = "Epic", minBox = 3 },
		{ id = "Crown", name = "Crown", minRarity = "Legendary", minBox = 4 },
		{ id = "Halo", name = "Halo", minRarity = "Mythic", boxes = { 5 } },
		{ id = "Starcrown", name = "Starcrown", minRarity = "Mythic", boxes = { 5 } },
	},
	Band = {
		{ id = "Plain", name = "Plain Band", minRarity = "Common" },
		{ id = "Ribbon", name = "Ribbon", minRarity = "Common" },
		{ id = "Braided", name = "Braided Band", minRarity = "Uncommon" },
		{ id = "Studded", name = "Studded Band", minRarity = "Uncommon", minBox = 2 },
		{ id = "Gilded", name = "Gilded Band", minRarity = "Rare" },
		{ id = "Runic", name = "Runic Band", minRarity = "Epic", minBox = 3 },
		{ id = "Crystal", name = "Crystal Band", minRarity = "Legendary", minBox = 4 },
		{ id = "Starlit", name = "Starlit Band", minRarity = "Mythic", boxes = { 5 } },
	},
	Gem = {
		{ id = "Bead", name = "Bead", minRarity = "Common" },
		{ id = "Orb", name = "Orb", minRarity = "Common" },
		{ id = "Acorn", name = "Acorn", minRarity = "Common", boxes = { 1, 2 } },
		{ id = "Diamond", name = "Diamond", minRarity = "Uncommon" },
		{ id = "Star", name = "Star", minRarity = "Rare" },
		{ id = "Moon", name = "Moonstone", minRarity = "Rare", minBox = 2 },
		{ id = "Eye", name = "Seeing Eye", minRarity = "Epic", minBox = 3 },
		{ id = "Skull", name = "Skull", minRarity = "Epic", minBox = 3 },
		{ id = "Heart", name = "Phoenix Heart", minRarity = "Legendary", minBox = 4 },
		{ id = "Prism", name = "Prism", minRarity = "Mythic", boxes = { 5 } },
		{ id = "Singularity", name = "Singularity", minRarity = "Mythic", boxes = { 5 } },
	},
} :: { [string]: { Design } }

Cosmetics.DesignById = {} :: { [string]: { [string]: Design } }
for slot, list in Cosmetics.Designs do
	Cosmetics.DesignById[slot] = designs(list)
end

---------------------------------------------------------------------------
-- Colours, materials, auras
---------------------------------------------------------------------------

export type ColorDef = { id: string, name: string, rgb: { number }, minRarity: string, minBox: number? }

Cosmetics.Colors = {
	-- Common
	{ id = "Brown", name = "Brown", rgb = { 120, 85, 55 }, minRarity = "Common" },
	{ id = "Grey", name = "Grey", rgb = { 130, 130, 135 }, minRarity = "Common" },
	{ id = "Cream", name = "Cream", rgb = { 225, 215, 190 }, minRarity = "Common" },
	{ id = "Navy", name = "Navy", rgb = { 40, 55, 100 }, minRarity = "Common" },
	{ id = "Forest", name = "Forest", rgb = { 45, 90, 50 }, minRarity = "Common" },
	{ id = "Rust", name = "Rust", rgb = { 150, 70, 40 }, minRarity = "Common" },
	{ id = "Charcoal", name = "Charcoal", rgb = { 50, 50, 55 }, minRarity = "Common" },
	{ id = "Moss", name = "Moss", rgb = { 105, 115, 60 }, minRarity = "Common" },
	-- Uncommon
	{ id = "Crimson", name = "Crimson", rgb = { 165, 25, 40 }, minRarity = "Uncommon" },
	{ id = "Royal", name = "Royal Blue", rgb = { 50, 80, 190 }, minRarity = "Uncommon" },
	{ id = "Emerald", name = "Emerald", rgb = { 30, 150, 90 }, minRarity = "Uncommon" },
	{ id = "Plum", name = "Plum", rgb = { 110, 45, 110 }, minRarity = "Uncommon" },
	{ id = "Saffron", name = "Saffron", rgb = { 235, 170, 40 }, minRarity = "Uncommon" },
	{ id = "Teal", name = "Teal", rgb = { 30, 130, 140 }, minRarity = "Uncommon" },
	{ id = "Rose", name = "Rose", rgb = { 215, 110, 140 }, minRarity = "Uncommon" },
	{ id = "Slate", name = "Slate", rgb = { 80, 95, 115 }, minRarity = "Uncommon" },
	-- Rare
	{ id = "Amethyst", name = "Amethyst", rgb = { 150, 90, 220 }, minRarity = "Rare" },
	{ id = "Scarlet", name = "Scarlet", rgb = { 220, 30, 30 }, minRarity = "Rare" },
	{ id = "Sapphire", name = "Sapphire", rgb = { 25, 90, 230 }, minRarity = "Rare" },
	{ id = "Jade", name = "Jade", rgb = { 60, 190, 130 }, minRarity = "Rare" },
	{ id = "Ivory", name = "Ivory", rgb = { 250, 245, 230 }, minRarity = "Rare" },
	{ id = "Obsidian", name = "Obsidian", rgb = { 25, 20, 35 }, minRarity = "Rare" },
	{ id = "Sunset", name = "Sunset", rgb = { 250, 110, 50 }, minRarity = "Rare" },
	{ id = "Sky", name = "Sky", rgb = { 120, 190, 250 }, minRarity = "Rare" },
	-- Epic
	{ id = "Midnight", name = "Midnight", rgb = { 20, 20, 60 }, minRarity = "Epic" },
	{ id = "Arcane", name = "Arcane Violet", rgb = { 165, 90, 255 }, minRarity = "Epic" },
	{ id = "Blood", name = "Bloodred", rgb = { 130, 0, 15 }, minRarity = "Epic" },
	{ id = "Frost", name = "Frostwhite", rgb = { 215, 240, 255 }, minRarity = "Epic" },
	{ id = "Toxic", name = "Toxic", rgb = { 130, 240, 40 }, minRarity = "Epic" },
	{ id = "Gold", name = "Molten Gold", rgb = { 255, 190, 40 }, minRarity = "Epic" },
	-- Legendary
	{ id = "Starlight", name = "Starlight", rgb = { 255, 245, 200 }, minRarity = "Legendary", minBox = 3 },
	{ id = "Dragonfire", name = "Dragonfire", rgb = { 255, 80, 20 }, minRarity = "Legendary", minBox = 3 },
	{ id = "Abyss", name = "Abyssal", rgb = { 35, 0, 70 }, minRarity = "Legendary", minBox = 3 },
	{ id = "Aurora", name = "Aurora", rgb = { 80, 255, 200 }, minRarity = "Legendary", minBox = 4 },
	-- Mythic
	{ id = "Celestial", name = "Celestial", rgb = { 255, 255, 255 }, minRarity = "Mythic", minBox = 5 },
	{ id = "Eclipse", name = "Eclipse", rgb = { 10, 5, 15 }, minRarity = "Mythic", minBox = 5 },
} :: { ColorDef }

Cosmetics.ColorById = {} :: { [string]: ColorDef }
for _, c in Cosmetics.Colors do
	Cosmetics.ColorById[c.id] = c
end

export type MaterialDef = { id: string, name: string, enum: string, minRarity: string, slots: { string } }

local SOFT = { "Cloth", "Trim", "Shape", "Band" }
local HARD = { "Trim", "Shape", "Band", "Gem", "Sigil" }
local ALL = { "Cloth", "Trim", "Sigil", "Shape", "Band", "Gem" }

Cosmetics.Materials = {
	{ id = "Wool", name = "Wool", enum = "Fabric", minRarity = "Common", slots = SOFT },
	{ id = "Leather", name = "Leather", enum = "Leather", minRarity = "Common", slots = SOFT },
	{ id = "Wood", name = "Carved", enum = "Wood", minRarity = "Common", slots = { "Sigil", "Gem" } },
	{ id = "Velvet", name = "Velvet", enum = "SmoothPlastic", minRarity = "Uncommon", slots = ALL },
	{ id = "Silk", name = "Silk", enum = "Foil", minRarity = "Rare", slots = ALL },
	{ id = "Iron", name = "Iron", enum = "Metal", minRarity = "Rare", slots = HARD },
	{ id = "Marble", name = "Marble", enum = "Marble", minRarity = "Rare", slots = { "Shape", "Band", "Gem" } },
	{ id = "Crystal", name = "Crystal", enum = "Glass", minRarity = "Epic", slots = ALL },
	{ id = "Radiant", name = "Radiant", enum = "Neon", minRarity = "Legendary", slots = ALL },
	{ id = "Ethereal", name = "Ethereal", enum = "ForceField", minRarity = "Mythic", slots = ALL },
} :: { MaterialDef }

Cosmetics.MaterialById = {} :: { [string]: MaterialDef }
for _, m in Cosmetics.Materials do
	Cosmetics.MaterialById[m.id] = m
end

-- Particle looks. texture: "sparkles" | "fire" | "sparks" | "smoke". rise: upward acceleration.
export type AuraDef = {
	id: string,
	name: string,
	minRarity: string,
	minBox: number?,
	colors: { { number } },
	texture: string,
	size: number,
	speed: number,
	rise: number,
	spread: number,
	lifetime: number,
	rate: number,
	light: boolean?,
	crackle: boolean?, -- extra fast electric sparks
	inward: boolean?, -- particles get sucked in (void)
	rainbow: boolean?,
}

Cosmetics.Auras = {
	{
		id = "Embers",
		name = "Embers",
		minRarity = "Common",
		colors = { { 255, 170, 60 }, { 255, 70, 20 } },
		texture = "sparks",
		size = 0.25,
		speed = 2,
		rise = 4,
		spread = 40,
		lifetime = 1.4,
		rate = 18,
	},
	{
		id = "Mist",
		name = "Mist",
		minRarity = "Common",
		colors = { { 220, 230, 240 }, { 180, 190, 210 } },
		texture = "smoke",
		size = 1.4,
		speed = 0.6,
		rise = 0.6,
		spread = 180,
		lifetime = 2.4,
		rate = 6,
	},
	{
		id = "Sparkle",
		name = "Sparkles",
		minRarity = "Common",
		colors = { { 255, 255, 220 }, { 200, 220, 255 } },
		texture = "sparkles",
		size = 0.3,
		speed = 1,
		rise = 0.5,
		spread = 180,
		lifetime = 1.2,
		rate = 14,
	},
	{
		id = "Leaves",
		name = "Falling Leaves",
		minRarity = "Common",
		colors = { { 120, 170, 60 }, { 200, 140, 50 } },
		texture = "sparkles",
		size = 0.35,
		speed = 1,
		rise = -2,
		spread = 60,
		lifetime = 2,
		rate = 6,
	},
	{
		id = "Smoke",
		name = "Billowing Smoke",
		minRarity = "Uncommon",
		colors = { { 70, 70, 75 }, { 30, 30, 35 } },
		texture = "smoke",
		size = 2.2,
		speed = 1.2,
		rise = 2.5,
		spread = 35,
		lifetime = 2.6,
		rate = 10,
	},
	{
		id = "Frost",
		name = "Frost",
		minRarity = "Uncommon",
		colors = { { 230, 250, 255 }, { 150, 210, 255 } },
		texture = "sparkles",
		size = 0.3,
		speed = 0.8,
		rise = -1.5,
		spread = 180,
		lifetime = 1.8,
		rate = 16,
		light = true,
	},
	{
		id = "Toxic",
		name = "Toxic Fumes",
		minRarity = "Uncommon",
		colors = { { 140, 255, 60 }, { 40, 110, 20 } },
		texture = "smoke",
		size = 1.3,
		speed = 0.8,
		rise = 1.5,
		spread = 70,
		lifetime = 2,
		rate = 8,
	},
	{
		id = "Bubbles",
		name = "Bubbles",
		minRarity = "Uncommon",
		minBox = 2,
		colors = { { 170, 230, 255 }, { 220, 200, 255 } },
		texture = "sparkles",
		size = 0.4,
		speed = 0.8,
		rise = 2,
		spread = 50,
		lifetime = 2,
		rate = 8,
	},
	{
		id = "Lightning",
		name = "Lightning",
		minRarity = "Rare",
		colors = { { 255, 255, 180 }, { 140, 190, 255 } },
		texture = "sparks",
		size = 0.3,
		speed = 7,
		rise = 0,
		spread = 180,
		lifetime = 0.25,
		rate = 26,
		light = true,
		crackle = true,
	},
	{
		id = "Petals",
		name = "Petals",
		minRarity = "Rare",
		minBox = 2,
		colors = { { 255, 170, 200 }, { 255, 225, 235 } },
		texture = "sparkles",
		size = 0.4,
		speed = 1.2,
		rise = -1,
		spread = 90,
		lifetime = 2.6,
		rate = 8,
	},
	{
		id = "Bloodmist",
		name = "Bloodmist",
		minRarity = "Rare",
		colors = { { 200, 20, 40 }, { 80, 0, 10 } },
		texture = "smoke",
		size = 1.2,
		speed = 0.6,
		rise = -0.4,
		spread = 180,
		lifetime = 1.8,
		rate = 8,
	},
	{
		id = "Shadow",
		name = "Shadow",
		minRarity = "Epic",
		minBox = 3,
		colors = { { 25, 15, 35 }, { 0, 0, 0 } },
		texture = "smoke",
		size = 1.8,
		speed = 1,
		rise = 1,
		spread = 180,
		lifetime = 1.8,
		rate = 12,
	},
	{
		id = "Void",
		name = "Void Wisps",
		minRarity = "Epic",
		minBox = 3,
		colors = { { 170, 80, 255 }, { 40, 0, 80 } },
		texture = "sparkles",
		size = 0.45,
		speed = 3,
		rise = 0,
		spread = 180,
		lifetime = 0.9,
		rate = 22,
		inward = true,
		light = true,
	},
	{
		id = "Runes",
		name = "Floating Runes",
		minRarity = "Epic",
		minBox = 3,
		colors = { { 190, 140, 255 }, { 120, 200, 255 } },
		texture = "sparkles",
		size = 0.55,
		speed = 0.5,
		rise = 1.2,
		spread = 180,
		lifetime = 2.2,
		rate = 8,
		light = true,
	},
	{
		id = "Holy",
		name = "Holy Light",
		minRarity = "Epic",
		minBox = 3,
		colors = { { 255, 245, 190 }, { 255, 210, 90 } },
		texture = "sparkles",
		size = 0.4,
		speed = 1.5,
		rise = 3,
		spread = 25,
		lifetime = 1.5,
		rate = 20,
		light = true,
	},
	{
		id = "Inferno",
		name = "Inferno",
		minRarity = "Legendary",
		minBox = 4,
		colors = { { 255, 220, 90 }, { 255, 60, 10 } },
		texture = "fire",
		size = 1.4,
		speed = 3,
		rise = 6,
		spread = 25,
		lifetime = 0.9,
		rate = 30,
		light = true,
	},
	{
		id = "Storm",
		name = "Storm",
		minRarity = "Legendary",
		minBox = 4,
		colors = { { 210, 230, 255 }, { 90, 120, 255 } },
		texture = "sparks",
		size = 0.4,
		speed = 10,
		rise = 0,
		spread = 180,
		lifetime = 0.2,
		rate = 40,
		light = true,
		crackle = true,
	},
	{
		id = "Stardust",
		name = "Stardust",
		minRarity = "Legendary",
		minBox = 4,
		colors = { { 255, 255, 255 }, { 170, 200, 255 } },
		texture = "sparkles",
		size = 0.35,
		speed = 1.5,
		rise = -0.5,
		spread = 180,
		lifetime = 2.4,
		rate = 30,
		light = true,
	},
	{
		id = "Prismatic",
		name = "Prismatic",
		minRarity = "Mythic",
		minBox = 5,
		colors = { { 255, 80, 80 }, { 80, 120, 255 } },
		texture = "sparkles",
		size = 0.45,
		speed = 2,
		rise = 1,
		spread = 180,
		lifetime = 1.6,
		rate = 34,
		light = true,
		rainbow = true,
	},
	{
		id = "Eclipse",
		name = "Eclipse",
		minRarity = "Mythic",
		minBox = 5,
		colors = { { 255, 200, 120 }, { 20, 0, 30 } },
		texture = "smoke",
		size = 2,
		speed = 2,
		rise = 0,
		spread = 180,
		lifetime = 1.4,
		rate = 24,
		light = true,
		inward = true,
	},
} :: { AuraDef }

Cosmetics.AuraById = {} :: { [string]: AuraDef }
for _, a in Cosmetics.Auras do
	Cosmetics.AuraById[a.id] = a
end

---------------------------------------------------------------------------
-- Enchantments: small gameplay bonuses. values[rank] by the part's rarity (Common..Mythic).
-- Every stat is capped across the whole outfit.
---------------------------------------------------------------------------

export type EnchantDef = {
	id: string,
	name: string,
	text: string, -- format with %s = the number
	percent: boolean,
	values: { number },
	cap: number,
}

Cosmetics.Enchants = {
	{
		id = "speed",
		name = "Swiftness",
		text = "+%s movement speed",
		percent = true,
		values = { 0.02, 0.03, 0.04, 0.05, 0.06, 0.08 },
		cap = 0.12,
	},
	{
		id = "health",
		name = "Vitality",
		text = "+%s max health",
		percent = false,
		values = { 3, 5, 7, 10, 13, 16 },
		cap = 25,
	},
	{
		id = "manaMax",
		name = "Mana Well",
		text = "+%s wand mana",
		percent = true,
		values = { 0.04, 0.06, 0.08, 0.11, 0.14, 0.18 },
		cap = 0.25,
	},
	{
		id = "manaRegen",
		name = "Flow",
		text = "+%s mana regeneration",
		percent = true,
		values = { 0.04, 0.06, 0.08, 0.11, 0.14, 0.18 },
		cap = 0.25,
	},
	{
		id = "castDelay",
		name = "Celerity",
		text = "-%s cast delay",
		percent = true,
		values = { 0.02, 0.03, 0.04, 0.05, 0.07, 0.09 },
		cap = 0.12,
	},
	{
		id = "recharge",
		name = "Quickening",
		text = "-%s wand recharge",
		percent = true,
		values = { 0.03, 0.04, 0.05, 0.07, 0.09, 0.12 },
		cap = 0.15,
	},
	{
		id = "ward",
		name = "Warding",
		text = "-%s damage taken",
		percent = true,
		values = { 0.02, 0.03, 0.04, 0.05, 0.06, 0.08 },
		cap = 0.12,
	},
	{
		id = "crit",
		name = "Precision",
		text = "+%s crit chance",
		percent = true,
		values = { 0.01, 0.02, 0.03, 0.04, 0.05, 0.06 },
		cap = 0.1,
	},
	{
		id = "lifesteal",
		name = "Leeching",
		text = "+%s lifesteal",
		percent = true,
		values = { 0.01, 0.015, 0.02, 0.03, 0.04, 0.05 },
		cap = 0.08,
	},
	{
		id = "regen",
		name = "Mending",
		text = "+%s health per second",
		percent = false,
		values = { 0.2, 0.3, 0.4, 0.6, 0.8, 1 },
		cap = 1.5,
	},
	{
		id = "jump",
		name = "Bounding",
		text = "+%s jump height",
		percent = true,
		values = { 0.04, 0.06, 0.08, 0.1, 0.13, 0.16 },
		cap = 0.2,
	},
	{
		id = "fortune",
		name = "Fortune",
		text = "+%s Enchanted Coins from matches",
		percent = true,
		values = { 0.03, 0.05, 0.07, 0.1, 0.13, 0.16 },
		cap = 0.3,
	},
	{
		id = "resilience",
		name = "Resilience",
		text = "-%s burn, chill and venom duration",
		percent = true,
		values = { 0.04, 0.06, 0.08, 0.11, 0.14, 0.18 },
		cap = 0.3,
	},
} :: { EnchantDef }

-- one attunement per element: + damage with that element's spells
Cosmetics.AttunedElements = {
	"Arcane",
	"Fire",
	"Frost",
	"Earth",
	"Wind",
	"Poison",
	"Lightning",
	"Void",
	"Radiant",
	"Blood",
	"Chaos",
	"Chrono",
}
for _, element in Cosmetics.AttunedElements do
	table.insert(Cosmetics.Enchants, {
		id = "elem:" .. element,
		name = element .. " Attunement",
		text = "+%s " .. element .. " damage",
		percent = true,
		values = { 0.03, 0.04, 0.05, 0.07, 0.09, 0.12 },
		cap = 0.2,
	})
end

Cosmetics.EnchantById = {} :: { [string]: EnchantDef }
for _, e in Cosmetics.Enchants do
	Cosmetics.EnchantById[e.id] = e
end

-- how many enchantments a part rolls, by rarity rank
Cosmetics.EnchantCount = { 1, 1, 1, 2, 2, 3 }

---------------------------------------------------------------------------
-- Coffers (loot boxes), bought with Enchanted Coins
---------------------------------------------------------------------------

export type Box = {
	id: number,
	name: string,
	icon: string,
	price: number,
	parts: number,
	odds: { [string]: number }, -- rarity -> % (adds up to 100)
	color: { number },
	blurb: string,
}

Cosmetics.Boxes = {
	{
		id = 1,
		name = "Tattered Satchel",
		icon = "👝",
		price = 50,
		parts = 1,
		odds = { Common = 98, Uncommon = 1.8, Rare = 0.2 },
		color = { 160, 130, 90 },
		blurb = "Hand-me-downs. Patchwork robes and straw hats only come from here.",
	},
	{
		id = 2,
		name = "Apprentice's Coffer",
		icon = "🧰",
		price = 100,
		parts = 1,
		odds = { Common = 70, Uncommon = 24, Rare = 5, Epic = 1 },
		color = { 110, 170, 110 },
		blurb = "Scholarly gear: monk's habits, top hats, chainmail trims.",
	},
	{
		id = 3,
		name = "Enchanter's Chest",
		icon = "🧳",
		price = 300,
		parts = 2,
		odds = { Common = 30, Uncommon = 40, Rare = 22, Epic = 7, Legendary = 1 },
		color = { 90, 140, 255 },
		blurb = "Two parts. Shadow wraps, royal robes, runic trims and the first auras that really show.",
	},
	{
		id = 4,
		name = "Archmage's Vault",
		icon = "🗝️",
		price = 500,
		parts = 2,
		odds = { Uncommon = 30, Rare = 40, Epic = 22, Legendary = 7, Mythic = 1 },
		color = { 180, 90, 255 },
		blurb = "Two parts. Archmage regalia, crowns, infernos and storms.",
	},
	{
		id = 5,
		name = "Celestial Reliquary",
		icon = "🌠",
		price = 1000,
		parts = 3,
		odds = { Rare = 30, Epic = 40, Legendary = 24, Mythic = 6 },
		color = { 255, 200, 90 },
		blurb = "Three parts. Exclusive halos, starcrowns, crystalweave and celestial vestments.",
	},
} :: { Box }

-- What salvaging a part pays back, by rarity rank.
Cosmetics.SalvageValue = { 3, 8, 25, 70, 180, 450 }

---------------------------------------------------------------------------
-- Rolling parts
---------------------------------------------------------------------------

local function rank(rarity: string): number
	return Rarity.rank(rarity)
end

local function allowedInBox(
	minRarity: string,
	minBox: number?,
	boxes: { number }?,
	rarity: string,
	box: number
): boolean
	if rank(minRarity) > rank(rarity) then
		return false
	end
	if boxes then
		return table.find(boxes, box) ~= nil
	end
	return box >= (minBox or 1)
end

-- Weighted pick that favours entries close to the rolled rarity (fancy rolls get fancy designs).
local function pickFor(rng: any, list: { any }, rarity: string, box: number, slot: string?): any
	local pool, total = {}, 0
	local r = rank(rarity)
	for _, entry in list do
		local okSlot = slot == nil or entry.slots == nil or table.find(entry.slots, slot) ~= nil
		if okSlot and allowedInBox(entry.minRarity, entry.minBox, entry.boxes, rarity, box) then
			local closeness = 1 + 2 * rank(entry.minRarity) / r
			if entry.boxes then
				closeness *= 1.6 -- collection exclusives show up a bit more in their own Coffer
			end
			table.insert(pool, { entry = entry, w = closeness })
			total += closeness
		end
	end
	local pick = rng:NextNumber(0, total)
	for _, p in pool do
		pick -= p.w
		if pick <= 0 then
			return p.entry
		end
	end
	return pool[#pool].entry
end

function Cosmetics.rollRarity(rng: any, box: Box): string
	local pick = rng:NextNumber(0, 100)
	local last = "Common"
	for _, name in Rarity.Order do
		local pct = box.odds[name]
		if pct then
			last = name
			pick -= pct
			if pick <= 0 then
				return name
			end
		end
	end
	return last
end

function Cosmetics.partName(part: CosmeticPart): string
	local color = Cosmetics.ColorById[part.color]
	local material = Cosmetics.MaterialById[part.material]
	local design = Cosmetics.DesignById[part.slot][part.design]
	local aura = part.aura and Cosmetics.AuraById[part.aura]
	local c = if color then color.name else "?"
	local d = if design then design.name else part.design
	if part.slot == "Sigil" then
		return d .. " Sigil of " .. (if aura then aura.name else "Nothing")
	elseif part.slot == "Gem" then
		return c .. " " .. d .. " of " .. (if aura then aura.name else "Nothing")
	elseif part.slot == "Trim" or part.slot == "Band" then
		return c .. " " .. d
	end
	return c .. " " .. (if material then material.name else "") .. " " .. d
end

-- Rolls one random part from a Coffer.
function Cosmetics.rollPart(rng: any, boxId: number, forcedSlot: string?, forcedRarity: string?): CosmeticPart
	local box = Cosmetics.Boxes[boxId] or Cosmetics.Boxes[1]
	local rarity = forcedRarity or Cosmetics.rollRarity(rng, box)
	local slot = forcedSlot or Cosmetics.SlotOrder[rng:NextInteger(1, #Cosmetics.SlotOrder)]
	local design = pickFor(rng, Cosmetics.Designs[slot], rarity, box.id, nil) :: Design
	local color = pickFor(rng, Cosmetics.Colors, rarity, box.id, nil) :: ColorDef
	local material = pickFor(rng, Cosmetics.Materials, rarity, box.id, slot) :: MaterialDef
	local aura: AuraDef? = nil
	if slot == "Sigil" or slot == "Gem" then
		aura = pickFor(rng, Cosmetics.Auras, rarity, box.id, nil) :: AuraDef
	end
	local r = rank(rarity)
	local enchants: { Enchant } = {}
	local taken: { [string]: boolean } = {}
	for _ = 1, Cosmetics.EnchantCount[r] or 1 do
		local def: EnchantDef
		repeat
			def = Cosmetics.Enchants[rng:NextInteger(1, #Cosmetics.Enchants)]
		until not taken[def.id]
		taken[def.id] = true
		table.insert(enchants, { stat = def.id, amount = def.values[r] })
	end
	local part: CosmeticPart = {
		uid = Items.newUid("c"),
		slot = slot,
		rarity = rarity,
		design = design.id,
		color = color.id,
		material = material.id,
		aura = if aura then aura.id else nil,
		enchants = enchants,
		box = box.id,
		name = "",
	}
	part.name = Cosmetics.partName(part)
	return part
end

-- The plain outfit every new mage starts with.
function Cosmetics.starterParts(): { CosmeticPart }
	local looks: { { any } } = {
		{ "Cloth", "Straight", "Navy", "Wool", nil, "manaRegen" },
		{ "Trim", "Hem", "Cream", "Wool", nil, "speed" },
		{ "Sigil", "Star", "Saffron", "Wood", "Sparkle", "health" },
		{ "Shape", "Pointed", "Navy", "Wool", nil, "manaMax" },
		{ "Band", "Plain", "Cream", "Leather", nil, "jump" },
		{ "Gem", "Bead", "Royal", "Wood", "Sparkle", "fortune" },
	}
	local parts = {}
	for _, l in looks do
		local def = Cosmetics.EnchantById[l[6]]
		local part: CosmeticPart = {
			uid = Items.newUid("c"),
			slot = l[1],
			rarity = "Common",
			design = l[2],
			color = l[3],
			material = l[4],
			aura = l[5],
			enchants = { { stat = def.id, amount = def.values[1] } },
			box = 0,
			name = "",
		}
		part.name = Cosmetics.partName(part)
		table.insert(parts, part)
	end
	return parts
end

---------------------------------------------------------------------------
-- Crafting, resonance and auras
---------------------------------------------------------------------------

-- Checks that `parts` (slot -> part) makes a complete garment of this kind.
function Cosmetics.validate(kind: string, parts: { [string]: CosmeticPart? }): (boolean, string?)
	local garment = Cosmetics.Garments[kind]
	if not garment then
		return false, "Unknown garment"
	end
	for _, slot in garment.slots do
		local part = parts[slot]
		if not part then
			return false, "Pick a " .. Cosmetics.Slots[slot].label:lower()
		end
		if part.slot ~= slot then
			return false, "That part doesn't go there"
		end
	end
	return true, nil
end

-- A garment's resonance: the average rarity of its parts, rounded down.
function Cosmetics.resonance(parts: { [string]: CosmeticPart }): number
	local sum, n = 0, 0
	for _, part in parts do
		sum += rank(part.rarity)
		n += 1
	end
	if n == 0 then
		return 1
	end
	return math.max(1, math.floor(sum / n))
end

-- How strongly the aura shows (1-6): the Sigil / Gem's rarity, but at most ONE tier above the
-- garment's resonance. Below 3 (Rare) there are no particles, just the emblem.
function Cosmetics.auraLevel(garment: Garment): number
	local slot = if garment.kind == "Robe" then "Sigil" else "Gem"
	local source = garment.parts[slot]
	if not source or not source.aura then
		return 0
	end
	return math.min(rank(source.rarity), Cosmetics.resonance(garment.parts) + 1)
end

function Cosmetics.auraOf(garment: Garment): string?
	local slot = if garment.kind == "Robe" then "Sigil" else "Gem"
	local source = garment.parts[slot]
	return source and source.aura
end

Cosmetics.AuraLevelNames = { "none", "none", "faint", "glowing", "billowing", "blazing" }

function Cosmetics.craft(kind: string, parts: { [string]: CosmeticPart }): Garment
	local res = Cosmetics.resonance(parts)
	local garment: Garment = {
		uid = Items.newUid("g"),
		kind = kind,
		name = "",
		rarity = Rarity.fromRank(res),
		parts = parts,
	}
	local base = parts[if kind == "Robe" then "Cloth" else "Shape"]
	local source = parts[if kind == "Robe" then "Sigil" else "Gem"]
	local aura = source and source.aura and Cosmetics.AuraById[source.aura]
	local design = Cosmetics.DesignById[base.slot][base.design]
	local color = Cosmetics.ColorById[base.color]
	garment.name = (if color then color.name .. " " else "")
		.. (if design then design.name else kind)
		.. (if aura then " of " .. aura.name else "")
	return garment
end

-- Robe + hat with the same aura, both at least "glowing": the aura also trails behind you.
function Cosmetics.matchedTrail(robe: Garment?, hat: Garment?): string?
	if not robe or not hat then
		return nil
	end
	local a, b = Cosmetics.auraOf(robe), Cosmetics.auraOf(hat)
	if a and a == b and Cosmetics.auraLevel(robe) >= 4 and Cosmetics.auraLevel(hat) >= 4 then
		return a
	end
	return nil
end

---------------------------------------------------------------------------
-- Stats
---------------------------------------------------------------------------

function Cosmetics.emptyGear(): Gear
	return {}
end

-- Sums the enchantments of every part in the worn garments, capped per stat.
function Cosmetics.gear(garments: { Garment }): Gear
	local total: Gear = {}
	for _, garment in garments do
		for _, part in garment.parts do
			for _, e in part.enchants do
				local def = Cosmetics.EnchantById[e.stat]
				if def then
					total[e.stat] = math.min(def.cap, (total[e.stat] or 0) + e.amount)
				end
			end
		end
	end
	return total
end

function Cosmetics.enchantText(e: Enchant): string
	local def = Cosmetics.EnchantById[e.stat]
	if not def then
		return e.stat
	end
	local value = if def.percent
		then tostring(math.floor(e.amount * 1000 + 0.5) / 10) .. "%"
		else tostring(math.floor(e.amount * 10 + 0.5) / 10)
	return string.format(def.text, value)
end

function Cosmetics.boxOddsText(box: Box): string
	local parts = {}
	for _, name in Rarity.Order do
		local pct = box.odds[name]
		if pct and pct > 0 then
			table.insert(parts, pct .. "% " .. name)
		end
	end
	return table.concat(parts, " · ")
end

-- Rough count of distinct-looking parts (for the docs and to brag).
function Cosmetics.varietyCount(): number
	local total = 0
	for slot, list in Cosmetics.Designs do
		local mats = 0
		for _, m in Cosmetics.Materials do
			if table.find(m.slots, slot) then
				mats += 1
			end
		end
		local looks = #list * #Cosmetics.Colors * mats
		if slot == "Sigil" or slot == "Gem" then
			looks *= #Cosmetics.Auras
		end
		total += looks
	end
	return total
end

return Cosmetics
