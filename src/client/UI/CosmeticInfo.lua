-- Tooltip / detail text for robe and hat parts, finished garments and familiars.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cosmetics = require(ReplicatedStorage.Shared.Cosmetics)
local Familiars = require(ReplicatedStorage.Shared.Familiars)
local Rarity = require(ReplicatedStorage.Shared.Rarity)
local Theme = require(script.Parent.Theme)
local ItemInfo = require(script.Parent.ItemInfo)

local CosmeticInfo = {}

function CosmeticInfo.color(part: any): Color3
	local def = part and Cosmetics.ColorById[part.color]
	return if def then Theme.rgb(def.rgb) else Color3.fromRGB(120, 120, 130)
end

function CosmeticInfo.icon(part: any): string
	local slot = part and Cosmetics.Slots[part.slot]
	if part and part.slot == "Sigil" then
		local design = Cosmetics.DesignById.Sigil[part.design]
		return if design and design.glyph then design.glyph else "⭐"
	end
	return if slot then slot.icon else "?"
end

local function auraLine(auraId: string?, level: number?): string?
	local aura = auraId and Cosmetics.AuraById[auraId]
	if not aura then
		return nil
	end
	if level then
		local name = Cosmetics.AuraLevelNames[math.clamp(level, 1, 6)] or "none"
		return aura.name .. " (" .. (if level < 3 then "too weak to see" else name) .. ")"
	end
	return aura.name
end

function CosmeticInfo.part(part: any): ItemInfo.Info
	local slot = Cosmetics.Slots[part.slot]
	local lines = {}
	local material = Cosmetics.MaterialById[part.material]
	table.insert(lines, { "Material", if material then material.name else "?" })
	local aura = auraLine(part.aura, nil)
	if aura then
		table.insert(lines, { "Aura", aura })
	end
	local box = Cosmetics.Boxes[part.box]
	local body = {}
	for _, e in part.enchants do
		table.insert(body, "✨ " .. Cosmetics.enchantText(e))
	end
	if part.aura and Rarity.rank(part.rarity) >= 3 then
		table.insert(body, "\nIts aura shows when stitched with parts of a similar rarity.")
	end
	return {
		title = part.name,
		color = Theme.rarity(part.rarity),
		subtitle = part.rarity .. " " .. (if slot then slot.label else part.slot) .. (if box
			then "  ·  from the " .. box.name
			elseif part.box == 0 then "  ·  starter gear"
			else ""),
		lines = lines,
		body = table.concat(body, "\n"),
		icon = CosmeticInfo.icon(part),
		iconColor = CosmeticInfo.color(part),
	}
end

function CosmeticInfo.garment(g: any): ItemInfo.Info
	local slots = Cosmetics.Garments[g.kind].slots
	local lines = {}
	for _, slot in slots do
		local part = g.parts[slot]
		if part then
			table.insert(lines, { Cosmetics.Slots[slot].label, part.rarity })
		end
	end
	local level = Cosmetics.auraLevel(g)
	local aura = auraLine(Cosmetics.auraOf(g), level)
	if aura then
		table.insert(lines, { "Aura", aura })
	end
	local enchants = {}
	for _, slot in slots do
		local part = g.parts[slot]
		if part then
			for _, e in part.enchants do
				table.insert(enchants, "✨ " .. Cosmetics.enchantText(e))
			end
		end
	end
	return {
		title = g.name,
		color = Theme.rarity(g.rarity),
		subtitle = g.rarity .. " " .. g.kind:lower() .. "  ·  resonance " .. Cosmetics.resonance(g.parts) .. "/6",
		lines = lines,
		body = table.concat(enchants, "\n"),
		icon = Cosmetics.Garments[g.kind].icon,
		iconColor = CosmeticInfo.color(g.parts[slots[1]]),
	}
end

function CosmeticInfo.familiarColor(f: any): Color3
	local variant = Familiars.variantOf(f)
	return Theme.rgb(variant.rgb)
end

function CosmeticInfo.familiarIcon(f: any): string
	local s = Familiars.SpeciesById[f.species]
	return if s then s.icon else "🐾"
end

function CosmeticInfo.familiar(f: any): ItemInfo.Info
	local s = Familiars.SpeciesById[f.species]
	local variant = Familiars.variantOf(f)
	local power = Familiars.powerOf(f)
	local lines = {
		{ "Species", if s then s.name else tostring(f.species) },
		{ "Colour", variant.name },
		{ "Power", if power then power.name else "none (just for show)" },
	}
	if f.shiny then
		table.insert(lines, { "Shiny", "✨ yes" })
	end
	local body = {}
	local text = Familiars.powerText(f)
	if text then
		table.insert(body, "✨ " .. text)
	elseif s then
		table.insert(
			body,
			"Just for show. Rare and rarer "
				.. s.name
				.. "s have a small power: "
				.. Familiars.speciesPowerName(s.id)
				.. "."
		)
	end
	if s then
		table.insert(body, "\n" .. s.blurb)
	end
	local box = Cosmetics.Boxes[f.box]
	return {
		title = f.name,
		color = Theme.rarity(f.rarity),
		subtitle = f.rarity .. " familiar" .. (if box then "  ·  from the " .. box.name else ""),
		lines = lines,
		body = table.concat(body, "\n"),
		icon = CosmeticInfo.familiarIcon(f),
		iconColor = CosmeticInfo.familiarColor(f),
	}
end

-- A short label for cards and lists ("Novice Robe", "Star Sigil", "Dust Bunny"); the tooltip
-- has the full name.
function CosmeticInfo.shortName(kind: string, item: any): string
	if kind == "Familiar" then
		local s = Familiars.SpeciesById[item.species]
		return if s then s.name else tostring(item.name)
	end
	local part = item
	if kind == "Garment" then
		part = item.parts and item.parts[Cosmetics.Garments[item.kind].slots[1]]
	end
	local design = part and Cosmetics.DesignById[part.slot] and Cosmetics.DesignById[part.slot][part.design]
	if not design then
		return tostring(item.name)
	end
	if part.slot == "Sigil" then
		return design.name .. " Sigil"
	elseif part.slot == "Gem" then
		return design.name .. " Gem"
	end
	return design.name
end

-- Info / icon / colour for any wardrobe item ("Part", "Garment" or "Familiar").
function CosmeticInfo.item(kind: string, item: any): ItemInfo.Info
	if kind == "Garment" then
		return CosmeticInfo.garment(item)
	elseif kind == "Familiar" then
		return CosmeticInfo.familiar(item)
	end
	return CosmeticInfo.part(item)
end

function CosmeticInfo.itemIcon(kind: string, item: any): (string, Color3)
	if kind == "Garment" then
		local def = Cosmetics.Garments[item.kind]
		return def.icon, CosmeticInfo.color(item.parts[def.slots[1]])
	elseif kind == "Familiar" then
		return CosmeticInfo.familiarIcon(item), CosmeticInfo.familiarColor(item)
	end
	return CosmeticInfo.icon(item), CosmeticInfo.color(item)
end

-- Total stats of a worn outfit, as text lines.
function CosmeticInfo.gearText(gear: { [string]: number }): string
	local lines = {}
	for _, def in Cosmetics.Enchants do
		local amount = gear[def.id]
		if amount and amount > 0 then
			local capped = if amount >= def.cap - 1e-9 then "  (max)" else ""
			table.insert(lines, "✨ " .. Cosmetics.enchantText({ stat = def.id, amount = amount }) .. capped)
		end
	end
	if #lines == 0 then
		return "No enchantments"
	end
	return table.concat(lines, "\n")
end

return CosmeticInfo
