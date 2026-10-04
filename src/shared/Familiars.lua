--!strict
-- Familiars: little companions that float or scamper after their mage, in the Plaza and in
-- matches. They come out of Coffers: every item a Coffer hands out has a small chance to be a
-- familiar instead of a robe or hat part, and it rolls its rarity from the Coffer's usual odds.
--
-- * Common and Uncommon familiars are purely for show.
-- * From Rare up, each species has one minor power (a touch more speed, sniffing out chests,
--   a nip at a nearby enemy...) that grows a little with rarity.
-- * Rarer familiars also look grander: a glow from Rare, sparkles from Epic, an elemental aura
--   from Legendary and a trail at Mythic. Any familiar can roll Shiny (golden sparkles, looks only).

local Rarity = require(script.Parent.Rarity)
local Items = require(script.Parent.Items)

local Familiars = {}

export type Variant = { id: string, name: string, rgb: { number }, accent: { number } }

export type Species = {
	id: string,
	name: string,
	icon: string,
	body: string, -- which model FamiliarBuilder makes
	minRarity: string,
	minBox: number?,
	boxes: { number }?, -- only from these Coffers
	power: string,
	element: string?, -- flavour of its aura particles (and of Attuned / Nip)
	flies: boolean,
	size: number,
	variants: { Variant },
	blurb: string,
}

export type Power = {
	id: string,
	name: string,
	text: string, -- with %s for the value
	percent: boolean,
	values: { number }, -- Rare, Epic, Legendary, Mythic
	stat: string?, -- a gear stat it adds to (see Cosmetics.Enchants); nil = a special power
}

export type Familiar = {
	uid: string,
	species: string,
	rarity: string,
	variant: string,
	shiny: boolean,
	box: number,
	name: string,
}

-- Chance (in %) that each item from a Coffer is a familiar, by Coffer id.
Familiars.ChancePerItem = { 3, 5, 8, 10, 15 }
Familiars.ShinyChance = 2.5 -- % of familiars
-- Powers start at this rarity rank (Rare). Below it a familiar is just for show.
Familiars.PowerRank = 3
-- What a familiar salvages for, by rarity rank.
Familiars.SalvageValue = { 5, 12, 35, 90, 220, 550 }

---------------------------------------------------------------------------
-- Powers (all deliberately small)
---------------------------------------------------------------------------

Familiars.Powers = {
	{
		id = "speed",
		name = "Quickpaw",
		text = "+%s movement speed",
		percent = true,
		values = { 0.02, 0.03, 0.04, 0.05 },
		stat = "speed",
	},
	{
		id = "jump",
		name = "Springheel",
		text = "+%s jump height",
		percent = true,
		values = { 0.04, 0.06, 0.08, 0.1 },
		stat = "jump",
	},
	{
		id = "manaRegen",
		name = "Mana Sip",
		text = "+%s mana regeneration",
		percent = true,
		values = { 0.03, 0.04, 0.05, 0.06 },
		stat = "manaRegen",
	},
	{
		id = "fortune",
		name = "Lucky Charm",
		text = "+%s Enchanted Coins from matches",
		percent = true,
		values = { 0.04, 0.06, 0.08, 0.1 },
		stat = "fortune",
	},
	{
		id = "ward",
		name = "Guardian",
		text = "-%s damage taken",
		percent = true,
		values = { 0.02, 0.03, 0.04, 0.05 },
		stat = "ward",
	},
	{
		id = "regen",
		name = "Mend",
		text = "+%s health per second",
		percent = false,
		values = { 0.2, 0.3, 0.4, 0.5 },
		stat = "regen",
	},
	{
		id = "attuned",
		name = "Attuned",
		text = "+%s %s damage",
		percent = true,
		values = { 0.03, 0.04, 0.05, 0.06 },
		stat = "elem", -- + the species' element
	},
	{
		id = "chestSense",
		name = "Keen Nose",
		text = "Points out unopened chests within %s studs",
		percent = false,
		values = { 30, 40, 50, 60 },
	},
	{
		id = "spotter",
		name = "Night Eyes",
		text = "Every 12s, outlines the nearest enemy within %s studs (only you see it)",
		percent = false,
		values = { 50, 60, 70, 80 },
	},
	{
		id = "nip",
		name = "Nip",
		text = "Every 8s, darts at an enemy within 14 studs for %s damage",
		percent = false,
		values = { 2, 3, 4, 5 },
	},
	{
		id = "emberWake",
		name = "Last Ember",
		text = "When you fall, it bursts for %s fire damage around you",
		percent = false,
		values = { 8, 12, 16, 20 },
	},
} :: { Power }

Familiars.PowerById = {} :: { [string]: Power }
for _, p in Familiars.Powers do
	Familiars.PowerById[p.id] = p
end

Familiars.NipRange = 14
Familiars.NipCooldown = 8
Familiars.SpotterCooldown = 12
Familiars.EmberWakeRadius = 10

---------------------------------------------------------------------------
-- Species
---------------------------------------------------------------------------

local function v(id: string, name: string, rgb: { number }, accent: { number }): Variant
	return { id = id, name = name, rgb = rgb, accent = accent }
end

Familiars.Species = {
	-- Common
	{
		id = "DustBunny",
		name = "Dust Bunny",
		icon = "🐇",
		body = "rabbit",
		minRarity = "Common",
		boxes = { 1, 2 },
		power = "speed",
		flies = false,
		size = 1,
		variants = {
			v("Snow", "Snow", { 240, 240, 245 }, { 255, 180, 200 }),
			v("Ash", "Ash", { 130, 130, 140 }, { 220, 220, 230 }),
			v("Cocoa", "Cocoa", { 140, 95, 65 }, { 240, 220, 200 }),
			v("Blossom", "Blossom", { 255, 190, 215 }, { 255, 255, 255 }),
		},
		blurb = "Lives under library shelves. Hops after you, ears flopping.",
	},
	{
		id = "PebbleToad",
		name = "Pebble Toad",
		icon = "🐸",
		body = "toad",
		minRarity = "Common",
		power = "jump",
		element = "Earth",
		flies = false,
		size = 1,
		variants = {
			v("Moss", "Moss", { 100, 150, 70 }, { 230, 220, 120 }),
			v("Stone", "Stone", { 140, 135, 125 }, { 200, 190, 170 }),
			v("Bog", "Bog", { 70, 90, 60 }, { 200, 120, 60 }),
			v("Ruby", "Ruby", { 180, 60, 70 }, { 255, 200, 120 }),
		},
		blurb = "Sits very still, then jumps very far.",
	},
	{
		id = "CandleMouse",
		name = "Candle Mouse",
		icon = "🐭",
		body = "mouse",
		minRarity = "Common",
		power = "chestSense",
		element = "Fire",
		flies = false,
		size = 0.85,
		variants = {
			v("Grey", "Grey", { 150, 150, 155 }, { 255, 200, 200 }),
			v("Cream", "Cream", { 235, 220, 190 }, { 255, 170, 170 }),
			v("Sable", "Sable", { 70, 55, 50 }, { 230, 150, 150 }),
		},
		blurb = "Carries a stub of candle on its head and a nose for treasure.",
	},
	{
		id = "Wisp",
		name = "Wisp",
		icon = "✨",
		body = "wisp",
		minRarity = "Common",
		power = "manaRegen",
		element = "Arcane",
		flies = true,
		size = 0.9,
		variants = {
			v("Azure", "Azure", { 120, 190, 255 }, { 255, 255, 255 }),
			v("Violet", "Violet", { 180, 120, 255 }, { 255, 220, 255 }),
			v("Verdant", "Verdant", { 120, 255, 170 }, { 230, 255, 230 }),
			v("Ember", "Ember", { 255, 170, 90 }, { 255, 240, 200 }),
		},
		blurb = "A loose spark of mana that decided it liked you.",
	},
	-- Uncommon
	{
		id = "LuckyTabby",
		name = "Lucky Tabby",
		icon = "🐈",
		body = "cat",
		minRarity = "Uncommon",
		power = "fortune",
		flies = false,
		size = 1,
		variants = {
			v("Ginger", "Ginger", { 230, 140, 60 }, { 255, 235, 210 }),
			v("Tuxedo", "Tuxedo", { 40, 40, 45 }, { 240, 240, 240 }),
			v("Calico", "Calico", { 240, 230, 220 }, { 220, 120, 50 }),
			v("Silver", "Silver", { 180, 185, 195 }, { 110, 115, 125 }),
		},
		blurb = "Finds coins down the back of every sofa.",
	},
	{
		id = "PaperCrane",
		name = "Paper Crane",
		icon = "🕊️",
		body = "crane",
		minRarity = "Uncommon",
		power = "attuned",
		element = "Wind",
		flies = true,
		size = 1,
		variants = {
			v("Parchment", "Parchment", { 240, 230, 205 }, { 200, 60, 50 }),
			v("Crimson", "Crimson", { 200, 50, 60 }, { 255, 230, 200 }),
			v("Indigo", "Indigo", { 70, 80, 170 }, { 240, 220, 150 }),
		},
		blurb = "Folded from a page of a wind spell. It still remembers the words.",
	},
	{
		id = "GelSlime",
		name = "Gel Slime",
		icon = "🟢",
		body = "slime",
		minRarity = "Uncommon",
		power = "ward",
		element = "Poison",
		flies = false,
		size = 1,
		variants = {
			v("Lime", "Lime", { 140, 230, 90 }, { 220, 255, 200 }),
			v("Berry", "Berry", { 210, 70, 150 }, { 255, 200, 230 }),
			v("Ocean", "Ocean", { 60, 160, 230 }, { 200, 240, 255 }),
			v("Honey", "Honey", { 255, 190, 60 }, { 255, 240, 190 }),
		},
		blurb = "Wobbles. Absorbs the odd stray hit, and the odd stray sock.",
	},
	{
		id = "LunaMoth",
		name = "Luna Moth",
		icon = "🦋",
		body = "moth",
		minRarity = "Uncommon",
		power = "regen",
		element = "Radiant",
		flies = true,
		size = 1,
		variants = {
			v("Jade", "Pale Jade", { 170, 240, 200 }, { 255, 240, 170 }),
			v("Dusk", "Dusk", { 150, 110, 200 }, { 255, 200, 120 }),
			v("Rosy", "Rosy", { 255, 170, 190 }, { 255, 240, 250 }),
		},
		blurb = "Drawn to the warm glow of a healthy mage.",
	},
	-- Rare
	{
		id = "EmberFox",
		name = "Ember Fox",
		icon = "🦊",
		body = "fox",
		minRarity = "Rare",
		power = "nip",
		element = "Fire",
		flies = false,
		size = 1.05,
		variants = {
			v("Flame", "Flame", { 240, 110, 40 }, { 255, 230, 140 }),
			v("Ash", "Ashen", { 90, 80, 80 }, { 255, 120, 40 }),
			v("BlueFlame", "Blue-flame", { 60, 120, 240 }, { 180, 230, 255 }),
		},
		blurb = "Its tail is actually on fire. It doesn't seem to mind.",
	},
	{
		id = "FrostOwl",
		name = "Frost Owl",
		icon = "🦉",
		body = "owl",
		minRarity = "Rare",
		power = "spotter",
		element = "Frost",
		flies = true,
		size = 1,
		variants = {
			v("Snowy", "Snowy", { 240, 245, 255 }, { 120, 200, 255 }),
			v("Glacier", "Glacier", { 150, 210, 240 }, { 240, 250, 255 }),
			v("Midnight", "Midnight", { 60, 70, 110 }, { 170, 220, 255 }),
		},
		blurb = "Sees in the dark, and tells you about it.",
	},
	{
		id = "TomeMimic",
		name = "Tome Mimic",
		icon = "📖",
		body = "book",
		minRarity = "Rare",
		minBox = 2,
		power = "attuned",
		element = "Arcane",
		flies = true,
		size = 1,
		variants = {
			v("Oxblood", "Oxblood", { 120, 30, 40 }, { 220, 180, 90 }),
			v("Forest", "Forest", { 40, 90, 60 }, { 220, 200, 120 }),
			v("Royal", "Royal", { 60, 40, 120 }, { 240, 210, 110 }),
		},
		blurb = "A grimoire that grew teeth. Mostly friendly.",
	},
	{
		id = "SkyEel",
		name = "Sky Eel",
		icon = "🐍",
		body = "eel",
		minRarity = "Rare",
		minBox = 2,
		power = "attuned",
		element = "Lightning",
		flies = true,
		size = 1,
		variants = {
			v("Storm", "Storm", { 90, 120, 200 }, { 255, 240, 120 }),
			v("Copper", "Copper", { 190, 110, 60 }, { 140, 240, 255 }),
			v("Neon", "Neon", { 40, 220, 200 }, { 255, 255, 255 }),
		},
		blurb = "Swims through the air on static.",
	},
	-- Epic
	{
		id = "Golemling",
		name = "Crystal Golemling",
		icon = "💎",
		body = "crystal",
		minRarity = "Epic",
		minBox = 3,
		power = "ward",
		element = "Earth",
		flies = true,
		size = 1,
		variants = {
			v("Amethyst", "Amethyst", { 170, 100, 240 }, { 255, 220, 255 }),
			v("Quartz", "Quartz", { 230, 235, 245 }, { 170, 220, 255 }),
			v("Emerald", "Emerald", { 60, 200, 120 }, { 220, 255, 230 }),
			v("Ruby", "Ruby", { 230, 50, 80 }, { 255, 210, 220 }),
		},
		blurb = "A heart of crystal held together by shards that orbit it.",
	},
	{
		id = "VoidJelly",
		name = "Void Jelly",
		icon = "🪼",
		body = "jelly",
		minRarity = "Epic",
		minBox = 3,
		power = "nip",
		element = "Void",
		flies = true,
		size = 1.05,
		variants = {
			v("Abyss", "Abyss", { 60, 30, 110 }, { 200, 120, 255 }),
			v("Ink", "Ink", { 25, 25, 35 }, { 120, 255, 230 }),
			v("Nebula", "Nebula", { 120, 40, 140 }, { 255, 140, 220 }),
		},
		blurb = "Drifts through nothing. Its sting is a little bit of nothing too.",
	},
	{
		id = "StormRaven",
		name = "Storm Raven",
		icon = "🐦",
		body = "raven",
		minRarity = "Epic",
		minBox = 3,
		power = "chestSense",
		element = "Lightning",
		flies = true,
		size = 1,
		variants = {
			v("Coal", "Coal", { 35, 35, 45 }, { 150, 200, 255 }),
			v("Thunder", "Thunderhead", { 60, 60, 90 }, { 255, 240, 120 }),
		},
		blurb = "Collects shiny things. Chests count.",
	},
	{
		id = "HexSkull",
		name = "Hex Skull",
		icon = "💀",
		body = "skull",
		minRarity = "Epic",
		minBox = 3,
		power = "attuned",
		element = "Blood",
		flies = true,
		size = 0.95,
		variants = {
			v("Bone", "Bone", { 230, 225, 205 }, { 255, 60, 60 }),
			v("Obsidian", "Obsidian", { 40, 35, 45 }, { 170, 255, 120 }),
			v("Gilded", "Gilded", { 220, 180, 80 }, { 255, 80, 80 }),
		},
		blurb = "Grins at everything. Especially blood magic.",
	},
	-- Legendary
	{
		id = "Dragonling",
		name = "Dragonling",
		icon = "🐉",
		body = "dragon",
		minRarity = "Legendary",
		minBox = 4,
		power = "nip",
		element = "Fire",
		flies = true,
		size = 1.15,
		variants = {
			v("Crimson", "Crimson", { 200, 40, 40 }, { 255, 200, 80 }),
			v("Emerald", "Emerald", { 40, 160, 80 }, { 255, 230, 120 }),
			v("Obsidian", "Obsidian", { 40, 40, 50 }, { 255, 90, 40 }),
			v("Frost", "Frost", { 170, 220, 255 }, { 255, 255, 255 }),
		},
		blurb = "Small enough to sit on a shoulder. Not small enough to be harmless.",
	},
	{
		id = "PhoenixChick",
		name = "Phoenix Chick",
		icon = "🔥",
		body = "phoenix",
		minRarity = "Legendary",
		minBox = 4,
		power = "emberWake",
		element = "Fire",
		flies = true,
		size = 1.05,
		variants = {
			v("Sunfire", "Sunfire", { 255, 140, 40 }, { 255, 240, 120 }),
			v("Azure", "Azure-flame", { 60, 150, 255 }, { 200, 240, 255 }),
		},
		blurb = "When its mage falls, it goes up in flames. It always comes back.",
	},
	{
		id = "ThunderKirin",
		name = "Thunder Kirin",
		icon = "🦄",
		body = "kirin",
		minRarity = "Legendary",
		minBox = 4,
		power = "speed",
		element = "Lightning",
		flies = false,
		size = 1.15,
		variants = {
			v("Pearl", "Pearl", { 240, 240, 250 }, { 140, 200, 255 }),
			v("Gold", "Gold", { 240, 200, 90 }, { 255, 255, 200 }),
			v("Storm", "Storm", { 70, 80, 120 }, { 255, 240, 120 }),
		},
		blurb = "Gallops on the crackle before a thunderclap.",
	},
	-- Mythic (Celestial Reliquary only)
	{
		id = "StarWhale",
		name = "Star Whale",
		icon = "🐋",
		body = "whale",
		minRarity = "Mythic",
		boxes = { 5 },
		power = "fortune",
		element = "Radiant",
		flies = true,
		size = 1.3,
		variants = {
			v("Nebula", "Nebula", { 40, 50, 120 }, { 255, 240, 170 }),
			v("Aurora", "Aurora", { 40, 120, 120 }, { 200, 255, 180 }),
		},
		blurb = "Swims between the stars, and now between the towers of the Plaza.",
	},
	{
		id = "EclipseCat",
		name = "Eclipse Cat",
		icon = "🐈‍⬛",
		body = "cat",
		minRarity = "Mythic",
		boxes = { 5 },
		power = "nip",
		element = "Void",
		flies = false,
		size = 1.1,
		variants = {
			v("Eclipse", "Eclipse", { 20, 20, 28 }, { 255, 180, 60 }),
			v("BloodMoon", "Blood Moon", { 30, 15, 20 }, { 255, 60, 60 }),
		},
		blurb = "Where it walks, the light bends. Its eyes are two tiny suns.",
	},
} :: { Species }

Familiars.SpeciesById = {} :: { [string]: Species }
for _, s in Familiars.Species do
	Familiars.SpeciesById[s.id] = s
end

function Familiars.variantOf(f: { species: string, variant: string }): Variant
	local s = Familiars.SpeciesById[f.species]
	if s then
		for _, variant in s.variants do
			if variant.id == f.variant then
				return variant
			end
		end
		return s.variants[1]
	end
	return v("?", "?", { 200, 200, 200 }, { 255, 255, 255 })
end

---------------------------------------------------------------------------
-- Rolling
---------------------------------------------------------------------------

local function rank(name: string): number
	return Rarity.rank(name)
end

-- Can this species come out of this Coffer at this rarity?
function Familiars.allowed(s: Species, rarity: string, box: number): boolean
	if rank(s.minRarity) > rank(rarity) then
		return false
	end
	if s.boxes then
		return table.find(s.boxes, box) ~= nil
	end
	return box >= (s.minBox or 1)
end

function Familiars.familiarName(f: Familiar): string
	local s = Familiars.SpeciesById[f.species]
	local variant = Familiars.variantOf(f)
	return (if f.shiny then "Shiny " else "") .. variant.name .. " " .. (if s then s.name else f.species)
end

-- Does this Coffer item turn out to be a familiar?
function Familiars.rollIsFamiliar(rng: any, boxId: number): boolean
	return rng:NextNumber(0, 100) < (Familiars.ChancePerItem[boxId] or 0)
end

-- A familiar of the given rarity from a Coffer. Species close to the rolled rarity are favoured,
-- so a Legendary roll is usually a Legendary-only species rather than a fancy Dust Bunny.
function Familiars.roll(rng: any, boxId: number, rarity: string, forcedSpecies: string?): Familiar
	local species: Species? = if forcedSpecies then Familiars.SpeciesById[forcedSpecies] else nil
	if not species then
		local pool, total = {}, 0
		local r = rank(rarity)
		for _, s in Familiars.Species do
			if Familiars.allowed(s, rarity, boxId) then
				local w = 1 + 3 * rank(s.minRarity) / r
				if s.boxes then
					w *= 1.5
				end
				table.insert(pool, { s = s, w = w })
				total += w
			end
		end
		local pick = rng:NextNumber(0, total)
		for _, p in pool do
			pick -= p.w
			if pick <= 0 then
				species = p.s
				break
			end
		end
		species = species or pool[#pool].s
	end
	local s = species :: Species
	local f: Familiar = {
		uid = Items.newUid("f"),
		species = s.id,
		rarity = rarity,
		variant = s.variants[rng:NextInteger(1, #s.variants)].id,
		shiny = rng:NextNumber(0, 100) < Familiars.ShinyChance,
		box = boxId,
		name = "",
	}
	f.name = Familiars.familiarName(f)
	return f
end

---------------------------------------------------------------------------
-- Powers
---------------------------------------------------------------------------

-- The familiar's power and its strength, or nil for a Common / Uncommon (just for show).
function Familiars.powerOf(f: { species: string, rarity: string }): (Power?, number)
	local s = Familiars.SpeciesById[f.species]
	local r = rank(f.rarity)
	if not s or r < Familiars.PowerRank then
		return nil, 0
	end
	local power = Familiars.PowerById[s.power]
	if not power then
		return nil, 0
	end
	return power, power.values[math.clamp(r - Familiars.PowerRank + 1, 1, #power.values)]
end

-- The gear stat a familiar adds to (e.g. "speed", "elem:Fire"), and how much.
function Familiars.statOf(f: { species: string, rarity: string }): (string?, number)
	local power, value = Familiars.powerOf(f)
	if not power or not power.stat then
		return nil, 0
	end
	if power.stat == "elem" then
		local s = Familiars.SpeciesById[f.species]
		return "elem:" .. (s.element or "Arcane"), value
	end
	return power.stat, value
end

local function valueText(power: Power, value: number): string
	if power.percent then
		return tostring(math.floor(value * 1000 + 0.5) / 10) .. "%"
	end
	return tostring(value)
end

-- "Nip: Every 8s, darts at an enemy within 14 studs for 4 damage", or nil if it has no power.
function Familiars.powerText(f: { species: string, rarity: string }): string?
	local power, value = Familiars.powerOf(f)
	if not power then
		return nil
	end
	local s = Familiars.SpeciesById[f.species]
	local text = if power.id == "attuned"
		then string.format(power.text, valueText(power, value), s.element or "Arcane")
		else string.format(power.text, valueText(power, value))
	return power.name .. ": " .. text
end

-- "+2% to 5% movement speed": a power's range from Rare to Mythic (for the Grimoire and docs).
function Familiars.powerRangeText(power: Power, element: string?): string
	local range = valueText(power, power.values[1]) .. " to " .. valueText(power, power.values[#power.values])
	if power.id == "attuned" then
		return string.format(power.text, range, element or "its element's")
	end
	return string.format(power.text, range)
end

-- What the species' power will be once it's Rare (for the tooltip of a Common / Uncommon one).
function Familiars.speciesPowerName(speciesId: string): string
	local s = Familiars.SpeciesById[speciesId]
	local power = s and Familiars.PowerById[s.power]
	return if power then power.name else "?"
end

---------------------------------------------------------------------------
-- Sending a familiar's look to clients (a character attribute)
---------------------------------------------------------------------------

function Familiars.encode(f: Familiar): string
	return table.concat({ f.species, f.rarity, f.variant, if f.shiny then "1" else "0" }, "|")
end

export type Look = { species: string, rarity: string, variant: string, shiny: boolean }

function Familiars.decode(text: any): Look?
	if type(text) ~= "string" then
		return nil
	end
	local species, rarity, variant, shiny = string.match(text, "^([^|]+)|([^|]+)|([^|]+)|([01])$")
	if not species or not rarity or not variant or not Familiars.SpeciesById[species] or not Rarity.Info[rarity] then
		return nil
	end
	return { species = species, rarity = rarity, variant = variant, shiny = shiny == "1" }
end

-- Distinct familiars that can exist: species x colour x rarity x shiny.
function Familiars.varietyCount(): number
	local total = 0
	for _, s in Familiars.Species do
		local rarities = #Rarity.Order - rank(s.minRarity) + 1
		total += #s.variants * rarities * 2
	end
	return total
end

return Familiars
