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
local Cosmetics = shared.load("Shared/Cosmetics")
local Achievements = shared.load("Shared/Achievements")
local Familiars = shared.load("Shared/Familiars")
local Modes = shared.load("Shared/Modes")

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
		damage = tostring(math.floor(spec.damage * 10 + 0.5) / 10)
	else
		damage = (if spec.explodeRadius > 0 then "explosion " else "zone ")
			.. tostring(math.floor(spec.damage * 10 + 0.5) / 10)
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

line("## Game modes")
line()
line("| | Mode | Players | |")
line("|---|---|---|---|")
for _, mode in Modes.List do
	line(string.format("| %s | **%s** | %s | %s |", mode.icon, mode.name, mode.players, mode.description))
end
line()
do
	local D, R = Config.Duel, Config.Royale
	line(
		string.format(
			"**Duels:** a bot steps in after %ds alone; sudden death at %ds (%d damage a second), time limit %ds; %d coins for a win, %d for a loss; up to %d duels at once.",
			D.BotAfter,
			D.SuddenDeathAt,
			D.SuddenDeathDps,
			D.TimeLimit,
			D.WinCoins,
			D.LoseCoins,
			D.MaxArenas
		)
	)
	line()
	line(
		string.format(
			"**Battle Royale:** up to %d mages (bots fill to %d). The queue gathers for %ds while the island is built, then the magic carpet crosses it in %ds, %d studs up. Gliders fall at %d studs/s and steer at %d studs/s. Chests refill at %ds.",
			R.MaxParticipants,
			R.FillTo,
			R.GatherTime,
			R.CarpetTime,
			R.CarpetAltitude,
			R.GlideFallSpeed,
			R.GlideSpeed,
			R.ChestRefillAt
		)
	)
	line()
	line("| Storm circle | Shown for | Closes in | Radius (share of the island) | Damage outside |")
	line("|---|---|---|---|---|")
	for i, c in R.Circles do
		line(
			string.format(
				"| %d | %ds | %ds | %d%% | %d/s |",
				i,
				c.wait,
				c.shrink,
				math.floor(c.radius * 100 + 0.5),
				c.dps
			)
		)
	end
	line()
	local royale = MapDefs.Royale
	line(
		string.format(
			"**%s %s** (radius %d studs, %d scattered chests plus those in its towns and landmarks):",
			royale.icon,
			royale.name,
			royale.radius,
			royale.outerChests
		)
	)
	line()
	line("| Realm | Named places | Landmarks | Weather |")
	line("|---|---|---|---|")
	for _, b in royale.biomes do
		local names, landmarks = {}, {}
		for _, n in b.named do
			table.insert(names, n.name)
		end
		for _, kind in b.pois do
			-- ("iceSpire" -> "ice spire")
			table.insert(landmarks, string.lower((string.gsub(kind, "(%u)", " %1"))))
		end
		line(
			string.format(
				"| **%s** | %s | %d (%s) | %s |",
				b.name,
				table.concat(names, ", "),
				b.poiCount,
				table.concat(landmarks, ", "),
				b.weather or "Clear"
			)
		)
	end
	line()
end

line("## Maps")
line()
line(
	string.format(
		"In Survival Games, players vote between %d random maps in the lobby before every match. Each match generates a fresh layout of the chosen map: terrain, ruins and chest spots are different every time. The cornucopia always holds %d chests.",
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

line("## Robes, hats and coffers")
line()
local E = Config.Economy
line(
	string.format(
		"Matches pay **Enchanted Coins** by finishing place: %d for 1st, %d for 2nd ... 1 for 12th in Survival Games, and %d for 1st down to 1 in a Battle Royale (plus the outfit's Fortune bonus). Duels pay %d for a win and %d for a loss. New players get %d coins and a plain robe and hat. Coins buy **coffers** of robe and hat parts; parts are stitched into garments at the Tailor's Loom, or traded on the auction house (%d%% fee, listings last %d hours, %d at a time).",
		E.CoinsForFirst,
		E.CoinsForFirst - 1,
		Config.Royale.CoinsForFirst,
		Config.Duel.WinCoins,
		Config.Duel.LoseCoins,
		E.StarterCoins,
		math.floor(E.AuctionFee * 100 + 0.5),
		E.AuctionHours,
		E.MaxListings
	)
)
line()
line("| | Coffer | Price | Parts | Odds | Only here |")
line("|---|---|---|---|---|---|")
for _, box in Cosmetics.Boxes do
	local only = {}
	for slot, list in Cosmetics.Designs do
		for _, d in list do
			if d.boxes and #d.boxes == 1 and d.boxes[1] == box.id then
				table.insert(only, d.name .. " (" .. string.lower(Cosmetics.Slots[slot].label) .. ")")
			end
		end
	end
	table.sort(only)
	line(
		string.format(
			"| %s | **%s** | %d coins | %d | %s | %s |",
			box.icon,
			box.name,
			box.price,
			box.parts,
			Cosmetics.boxOddsText(box),
			if #only > 0 then table.concat(only, ", ") else "-"
		)
	)
end
line()
local colors, materials, auras = #Cosmetics.Colors, #Cosmetics.Materials, #Cosmetics.Auras
line(
	string.format(
		"A **robe** is a Cloth + Trim + Sigil; a **hat** is a Hat shape + Band + Gem. Each part rolls a design, one of %d colours, one of %d materials, %d-%d enchantments by rarity and (Sigils and Gems) one of %d auras, all gated by rarity and coffer: **%s** distinct-looking parts in all.",
		colors,
		materials,
		Cosmetics.EnchantCount[1],
		Cosmetics.EnchantCount[#Cosmetics.EnchantCount],
		auras,
		string.reverse((string.gsub(string.reverse(tostring(Cosmetics.varietyCount())), "(%d%d%d)(%d)", "%1,%2")))
	)
)
line()
line(
	"**Resonance and auras:** a garment's resonance is the average rarity rank of its three parts (rounded down). Its aura shines at the aura part's rarity, but never more than one tier above the resonance: visible from Rare strength, with light from Epic, and an extra flourish at Mythic. A robe and hat with the same aura, both at Epic strength or better, leave a trail."
)
line()
line("| Slot | Designs (minimum rarity) |")
line("|---|---|")
for _, slot in Cosmetics.SlotOrder do
	local names = {}
	for _, d in Cosmetics.Designs[slot] do
		table.insert(names, d.name .. " (" .. d.minRarity .. ")")
	end
	line(
		string.format(
			"| %s %s | %s |",
			Cosmetics.Slots[slot].icon,
			Cosmetics.Slots[slot].label,
			table.concat(names, ", ")
		)
	)
end
line()
local auraNames = {}
for _, a in Cosmetics.Auras do
	table.insert(auraNames, a.name .. " (" .. a.minRarity .. ")")
end
line("**Auras:** " .. table.concat(auraNames, ", ") .. ".")
line()
line("| Enchantment | Effect | Per part (Common → Mythic) | Outfit cap |")
line("|---|---|---|---|")
for _, def in Cosmetics.Enchants do
	local values = {}
	for _, v in def.values do
		table.insert(values, (Cosmetics.enchantText({ stat = def.id, amount = v }):match("[%d%.]+%%?")))
	end
	line(
		string.format(
			"| **%s** | %s | %s | %s |",
			def.name,
			string.format(def.text, "N"),
			table.concat(values, " / "),
			Cosmetics.enchantText({ stat = def.id, amount = def.cap })
		)
	)
end
line()

line("### Familiars")
line()
local chances = {}
for _, box in Cosmetics.Boxes do
	table.insert(chances, string.format("%s %d%%", box.name, Familiars.ChancePerItem[box.id] or 0))
end
line(
	string.format(
		"Every item a coffer hands out can turn out to be a **familiar** instead (%s per item). A familiar rolls its rarity from the coffer's usual odds, and %s%% of familiars are **Shiny** (golden sparkles, looks only). Common and Uncommon familiars are purely cosmetic; from Rare up each species has one minor power that grows with rarity. Rare familiars glow, Epic ones sparkle, Legendary ones carry an elemental aura and Mythic ones leave a trail. **%d** species, **%d** distinct familiars to collect (species × colour × rarity × shiny).",
		table.concat(chances, ", "),
		tostring(Familiars.ShinyChance),
		#Familiars.Species,
		Familiars.varietyCount()
	)
)
line()
line("| | Familiar | From rarity | Coffers | Power (Rare+) | Colours |")
line("|---|---|---|---|---|---|")
for _, sp in Familiars.Species do
	local boxes
	if sp.boxes then
		local names = {}
		for _, id in sp.boxes do
			table.insert(names, Cosmetics.Boxes[id].name)
		end
		boxes = table.concat(names, ", ") .. " only"
	elseif (sp.minBox or 1) > 1 then
		boxes = Cosmetics.Boxes[sp.minBox].name .. " and up"
	else
		boxes = "any"
	end
	local colours = {}
	for _, v in sp.variants do
		table.insert(colours, v.name)
	end
	line(
		string.format(
			"| %s | **%s** | %s | %s | %s | %s |",
			sp.icon,
			sp.name,
			sp.minRarity,
			boxes,
			Familiars.PowerById[sp.power].name
				.. (if sp.power == "attuned" then " (" .. tostring(sp.element) .. ")" else ""),
			table.concat(colours, ", ")
		)
	)
end
line()
line("| Power | Effect (Rare to Mythic) | Rare / Epic / Legendary / Mythic |")
line("|---|---|---|")
for _, power in Familiars.Powers do
	local values = {}
	for _, value in power.values do
		table.insert(
			values,
			if power.percent then tostring(math.floor(value * 1000 + 0.5) / 10) .. "%" else tostring(value)
		)
	end
	line(
		string.format(
			"| **%s** | %s | %s |",
			power.name,
			Familiars.powerRangeText(power, nil),
			table.concat(values, " / ")
		)
	)
end
line()

line("## Achievements")
line()
line(
	string.format(
		"Each pays its Enchanted Coins once (%d in all). Players also get **%d coins a day** for logging in (days start at midnight UTC).",
		Achievements.totalReward(),
		Config.Rewards.DailyCoins
	)
)
line()
line("| | Achievement | Goal | Reward |")
line("|---|---|---|---|")
for _, a in Achievements.List do
	line(string.format("| %s | **%s** | %s | %d 💰 |", a.icon, a.name, a.description, a.reward))
end
line()

fs.writeDir("docs")
fs.writeFile("docs/CATALOG.md", table.concat(out, "\n"))
print("wrote docs/CATALOG.md")
