--!strict
-- Generates readable names for crafted spells, e.g. "Seeking Twin Ember Bolt » Frost Nova".

local SpellTypes = require(script.Parent.SpellTypes)
local SpellParts = require(script.Parent.SpellParts)

type Recipe = SpellTypes.Recipe

local SpellNames = {}

local MAX_ADJECTIVES = 2

local function core(recipe: Recipe, withMods: boolean): string
	local words: { string } = {}
	local extra = 0
	if withMods and recipe.mods then
		local seen: { [string]: boolean } = {}
		for _, id in recipe.mods do
			if not seen[id] then
				seen[id] = true
				local part = SpellParts.ById[id]
				if part and #words < MAX_ADJECTIVES then
					table.insert(words, part.adjective or part.name)
				else
					extra += 1
				end
			else
				extra += 1
			end
		end
	end
	local elementPart = SpellParts.get(recipe.element)
	if elementPart and elementPart.adjective and elementPart.adjective ~= "" then
		table.insert(words, elementPart.adjective)
	end
	local formPart = SpellParts.ById[recipe.form]
	table.insert(words, if formPart then formPart.noun or formPart.name else "Spell")
	local name = table.concat(words, " ")
	if extra > 0 then
		name ..= " +" .. extra
	end
	return name
end

function SpellNames.generate(recipe: Recipe): string
	local name = core(recipe, true)
	if recipe.trigger and recipe.payload then
		name ..= " » " .. core(recipe.payload, false)
	end
	return name
end

return SpellNames
