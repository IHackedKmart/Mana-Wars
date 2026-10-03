--[[
	Regenerates docs/CATALOG.md from the game data (run from the repo root with Lune):

		lune run tools/gen_docs
]]

local fs = require("@lune/fs")
local Mock = require("./sim/mock")

local shared = Mock.realm({}, true)
local SpellParts = shared.load("Shared/Spells/SpellParts")
local SpellBuilder = shared.load("Shared/Spells/SpellBuilder")
local PremadeSpells = shared.load("Shared/Spells/PremadeSpells")
local Classes = shared.load("Shared/Classes")
local Consumables = shared.load("Shared/Consumables")
local Rarity = shared.load("Shared/Rarity")
local Config = shared.load("Shared/Config")
local MapDefs = shared.load("Server/Map/MapDefs")

local out = {}
local function line(s: string?)
	table.insert(out, s or "")
end

local function sortedParts(category: string)
	local list = table.clone(SpellParts.ByCategory[category])
	table.sort(list, function(a, b)
		local ra, rb = Rarity.rank(a.rarity), Rarity.rank(b.rarity)
		if ra ~= rb then
			return ra < rb
		end
		return a.name < b.name
	end)
	return list
end

local function recipeText(recipe): string
	local parts = { recipe.form }
	if recipe.element then
		table.insert(parts, recipe.element)
	end
	for _, m in recipe.mods or {} do
		table.insert(parts, m)
	end
	local text = table.concat(parts, " + ")
	if recipe.trigger then
		text ..= " → **" .. recipe.trigger .. "** → (" .. recipeText(recipe.payload) .. ")"
	end
	return text
end

line("# Mana Wars catalogue")
line()
line("_Generated from the game data by `lune run tools/gen_docs`. Do not edit by hand._")
line()

local f = #SpellParts.ByCategory.Form
local e = #SpellParts.ByCategory.Element
local m = #SpellParts.ByCategory.Modifier
local t = #SpellParts.ByCategory.Trigger
local combos = 0
for k = 0, Config.Spell.MaxModifiers do
	combos += m ^ k
end
local single = f * (e + 1) * combos
line(
	string.format(
		"**%d spell parts** (%d forms, %d elements, %d modifiers, %d triggers). A spell is one form, an optional element, up to %d modifiers and an optional trigger carrying a whole payload spell (nested up to %d deep). That is about **%.0f million** different single-layer spells, and roughly **%.1e** once a single trigger payload is added.",
		f + e + m + t,
		f,
		e,
		m,
		t,
		Config.Spell.MaxModifiers,
		Config.Spell.MaxDepth,
		single / 1e6,
		single * t * single
	)
)
line()

line("## Forms")
line()
line("| | Form | Rarity | Damage | Mana | Cast delay | What it does |")
line("|---|---|---|---|---|---|---|")
for _, part in sortedParts("Form") do
	local spec = SpellBuilder.compile({ form = part.id })
	local damage
	if spec.kind == "Blink" or spec.kind == "Aegis" or spec.kind == "Wall" then
		damage = "—"
	elseif spec.directMult > 0 then
		damage = tostring(spec.damage)
	else
		damage = (if spec.explodeRadius > 0 then "explosion " else "zone ") .. spec.damage
	end
	line(
		string.format(
			"| %s | **%s** | %s | %s | %d | %.2fs | %s |",
			part.icon,
			part.name,
			part.rarity,
			damage,
			spec.mana,
			spec.castDelay,
			part.description
		)
	)
end
line()

for _, category in { "Element", "Modifier", "Trigger" } do
	line("## " .. category .. "s")
	line()
	line("| | Part | Rarity | Effect |")
	line("|---|---|---|---|")
	for _, part in sortedParts(category) do
		line(string.format("| %s | **%s** | %s | %s |", part.icon, part.name, part.rarity, part.description))
	end
	line()
end

line("## Premade spells (found in chests)")
line()
line("Every premade spell can be dismantled in the Spellforge to recover its parts.")
line()
line("| Spell | Rarity | Recipe | Mana | |")
line("|---|---|---|---|---|")
for _, premade in PremadeSpells.List do
	local spec = SpellBuilder.compile(premade.recipe)
	line(
		string.format(
			"| **%s** | %s | %s | %d | _%s_ |",
			premade.name,
			premade.rarity,
			recipeText(premade.recipe),
			spec.mana,
			premade.flavor
		)
	)
end
line()

line("## Kits")
line()
line(
	"Kits (classes) decide what you start each match with. The Apprentice is free; every other kit is its own game pass, priced by tier. Every kit also gives **one random spell part** each match, rolled with its tier's odds."
)
line()
line("| Tier | Price | Bonus part odds |")
line("|---|---|---|")
for _, tier in Classes.Tiers do
	line(
		string.format(
			"| **%s** | %s | %s |",
			tier.name,
			if tier.robux > 0 then string.format("R$%d (about %s)", tier.robux, tier.usd) else "Free",
			Classes.oddsText(tier.id)
		)
	)
end
line()
line("| | Kit | Tier | Wands | Starting spells | Parts |")
line("|---|---|---|---|---|---|")
for _, class in Classes.List do
	local wands, spells = {}, {}
	for _, w in class.kit.wands do
		table.insert(wands, w.template.name .. " (" .. w.template.rarity .. ")")
		for _, id in w.spells do
			table.insert(spells, PremadeSpells.ById[id].name)
		end
	end
	local parts = {}
	for id, n in class.kit.parts or {} do
		table.insert(parts, SpellParts.ById[id].name .. (if n > 1 then " x" .. n else ""))
	end
	table.sort(parts)
	table.insert(parts, "+1 random")
	line(
		string.format(
			"| %s | **%s** | %s | %s | %s | %s |",
			class.icon,
			class.name,
			Classes.tierInfo(class.tier).name,
			table.concat(wands, ", "),
			table.concat(spells, ", "),
			table.concat(parts, ", ")
		)
	)
end
line()

line("## Maps")
line()
line(
	string.format(
		"Players vote between %d random maps in the lobby before every match. Each match generates a fresh layout of the chosen map: terrain, ruins and chest spots are different every time. The cornucopia always holds %d chests.",
		Config.Match.VoteOptions,
		Config.Arena.CornucopiaChests
	)
)
line()
line("| | Map | Radius | Scattered chests | Landmarks | Weather | |")
line("|---|---|---|---|---|---|---|")
for _, def in MapDefs.List do
	line(
		string.format(
			"| %s | **%s** | %d studs | %d | %d | %s | _%s_ |",
			def.icon,
			def.name,
			def.radius,
			def.outerChests,
			def.poiCount,
			(def.weather or "Clear") .. (if def.hazard then " (" .. string.lower(def.hazard) .. " burns)" else ""),
			def.description
		)
	)
end
line()

line("## Potions")
line()
line("| | Potion | Key | Rarity | Effect |")
line("|---|---|---|---|---|")
for _, c in Consumables.List do
	line(string.format("| %s | **%s** | %s | %s | %s |", c.icon, c.name, c.key, c.rarity, c.description))
end
line()

fs.writeDir("docs")
fs.writeFile("docs/CATALOG.md", table.concat(out, "\n"))
print("wrote docs/CATALOG.md")
