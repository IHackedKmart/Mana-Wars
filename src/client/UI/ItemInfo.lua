-- Builds tooltip / details content for every kind of item.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Items = require(Shared.Items)
local Consumables = require(Shared.Consumables)
local WandGenerator = require(Shared.WandGenerator)
local SpellParts = require(Shared.Spells.SpellParts)
local SpellBuilder = require(Shared.Spells.SpellBuilder)
local SpellTypes = require(Shared.Spells.SpellTypes)
local PremadeSpells = require(Shared.Spells.PremadeSpells)
local Theme = require(script.Parent.Theme)

export type Info = {
	title: string,
	color: Color3,
	subtitle: string?,
	lines: { { string } }?,
	body: string?,
	icon: string?,
	iconColor: Color3?,
}

local ItemInfo = {}

function ItemInfo.recipeText(recipe: SpellTypes.Recipe): string
	local parts = {}
	local function name(id: string?): string?
		local part = SpellParts.get(id)
		return if part then part.name else nil
	end
	table.insert(parts, name(recipe.form) or "?")
	local element = name(recipe.element)
	if element then
		table.insert(parts, element)
	end
	if recipe.mods then
		for _, id in recipe.mods do
			table.insert(parts, name(id) or "?")
		end
	end
	local text = table.concat(parts, " + ")
	if recipe.trigger and recipe.payload then
		text ..= "  [" .. (name(recipe.trigger) or "?") .. " » " .. ItemInfo.recipeText(recipe.payload) .. "]"
	end
	return text
end

-- The icon of a spell is its form's icon tinted with its element's colour.
function ItemInfo.spellVisual(recipe: SpellTypes.Recipe): (string, Color3)
	local form = SpellParts.get(recipe.form)
	local element = SpellParts.get(recipe.element)
	local color = if element then Theme.rgb(element.color) else Theme.rgb(SpellParts.NeutralElement.color)
	return if form then form.icon else "?", color
end

function ItemInfo.part(id: string): Info
	local part = SpellParts.ById[id]
	if not part then
		return { title = id, color = Theme.Colors.Dim }
	end
	local lines = nil
	if part.category == "Form" then
		local spec = SpellBuilder.compile({ form = id })
		if spec then
			lines = SpellBuilder.describe(spec)
		end
	end
	return {
		title = part.name,
		color = Theme.rarity(part.rarity),
		subtitle = part.rarity .. " " .. part.category,
		lines = lines,
		body = part.description,
		icon = part.icon,
		iconColor = Theme.CategoryColors[part.category],
	}
end

function ItemInfo.spell(spell: Items.SpellItem, wand: Items.WandItem?): Info
	local spec = SpellBuilder.compile(spell.recipe, if wand then Items.wandContext(wand) else nil)
	local icon, color = ItemInfo.spellVisual(spell.recipe)
	local premade = if spell.premadeId then PremadeSpells.ById[spell.premadeId] else nil
	local body = ItemInfo.recipeText(spell.recipe)
	if premade then
		body = premade.flavor .. "\n" .. body
	end
	return {
		title = spell.name,
		color = Theme.rarity(spell.rarity),
		subtitle = spell.rarity .. " spell" .. (if wand then "  (with this wand's bonuses)" else ""),
		lines = if spec then SpellBuilder.describe(spec) else nil,
		body = body,
		icon = icon,
		iconColor = color,
	}
end

local function fmt(n: number, places: number?): string
	local p = 10 ^ (places or 0)
	local v = math.floor(n * p + 0.5) / p
	return tostring(v)
end

function ItemInfo.wand(wand: Items.WandItem): Info
	local s = wand.stats
	local lines = {
		{ "Mana", fmt(s.manaMax) .. " (+" .. fmt(s.manaRegen) .. "/s)" },
		{ "Cast delay", fmt(s.castDelay, 2) .. "s" },
		{ "Recharge", fmt(s.rechargeTime, 2) .. "s" },
		{ "Spell slots", tostring(s.capacity) },
		{ "Spells per cast", tostring(s.spellsPerCast) },
		{ "Spread", fmt(s.spread, 1) .. "°" },
		{ "Damage", "x" .. fmt(s.damageMult, 2) },
		{ "Speed", "x" .. fmt(s.speedMult, 2) },
		{ "Order", if s.shuffle then "Shuffled" else "In order" },
	}
	local perks = {}
	for _, perk in wand.perks do
		table.insert(perks, "⭐ " .. WandGenerator.describePerk(perk))
	end
	return {
		title = wand.name,
		color = Theme.rarity(wand.rarity),
		subtitle = wand.rarity .. " " .. wand.wandType,
		lines = lines,
		body = if #perks > 0 then table.concat(perks, "\n") else "No special perks.",
		icon = nil,
		iconColor = Theme.rgb(wand.color),
	}
end

function ItemInfo.consumable(id: string): Info
	local c = Consumables.ById[id]
	if not c then
		return { title = id, color = Theme.Colors.Dim }
	end
	return {
		title = c.name,
		color = Theme.rarity(c.rarity),
		subtitle = c.rarity .. " potion  [" .. c.key .. "]",
		body = c.description,
		icon = c.icon,
		iconColor = Theme.rgb(c.color),
	}
end

function ItemInfo.entry(entry: Items.LootEntry): Info
	if entry.kind == "Part" and entry.id then
		return ItemInfo.part(entry.id)
	elseif entry.kind == "Spell" and entry.spell then
		return ItemInfo.spell(entry.spell, nil)
	elseif entry.kind == "Wand" and entry.wand then
		return ItemInfo.wand(entry.wand)
	elseif entry.kind == "Consumable" and entry.id then
		return ItemInfo.consumable(entry.id)
	end
	return { title = "Unknown", color = Theme.Colors.Dim }
end

return ItemInfo
