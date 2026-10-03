-- Spell system tests. Run with: python3 tools/run_tests.py
local SpellParts = __require(Shared.Spells.SpellParts)
local SpellBuilder = __require(Shared.Spells.SpellBuilder)
local PremadeSpells = __require(Shared.Spells.PremadeSpells)
local Rarity = __require(Shared.Rarity)
local Config = __require(Shared.Config)

local NUMERIC_FIELDS = {
	"mana",
	"castDelay",
	"recharge",
	"damage",
	"speed",
	"lifetime",
	"size",
	"gravity",
	"count",
	"spread",
	"range",
	"radius",
	"bounces",
	"pierce",
	"homing",
	"explodeRadius",
	"explodeMult",
	"zoneRadius",
	"zoneDuration",
	"zoneMult",
	"knockback",
	"crit",
	"lifesteal",
}

local function checkSpec(spec, label)
	for _, field in NUMERIC_FIELDS do
		expect(isFinite(spec[field]), label .. ": " .. field .. " is not finite (" .. tostring(spec[field]) .. ")")
	end
	expect(spec.mana >= 0, label .. ": negative mana")
	expect(spec.count >= 1, label .. ": count < 1")
	expect(type(spec.name) == "string" and #spec.name > 0, label .. ": empty name")
	expect(spec.crit >= 0 and spec.crit <= 1, label .. ": crit out of range")
	if spec.payload then
		checkSpec(spec.payload, label .. " > payload")
	end
end

test("every part is well formed", function()
	local count = 0
	for _, part in SpellParts.List do
		count += 1
		expect(Rarity.Info[part.rarity] ~= nil, part.id .. " has unknown rarity " .. tostring(part.rarity))
		expect(type(part.icon) == "string" and #part.icon > 0, part.id .. " has no icon")
		expect(type(part.description) == "string" and #part.description > 10, part.id .. " has no description")
		expect(type(part.color) == "table" and #part.color == 3, part.id .. " has no colour")
		if part.category == "Form" then
			expect(part.kind ~= nil and part.base ~= nil, part.id .. " form without kind/base")
		elseif part.category == "Modifier" then
			expect(part.apply ~= nil or part.post ~= nil, part.id .. " modifier does nothing")
		elseif part.category == "Element" then
			expect(part.elementApply ~= nil, part.id .. " element does nothing")
		end
	end
	expect(count >= 50, "expected a big part list, got " .. count)
end)

test("every form compiles on its own and with every element", function()
	for _, f in SpellParts.ByCategory.Form do
		local spec = SpellBuilder.compile({ form = f.id })
		expect(spec ~= nil, f.id .. " failed to compile")
		checkSpec(spec, f.id)
		for _, e in SpellParts.ByCategory.Element do
			local s2 = SpellBuilder.compile({ form = f.id, element = e.id })
			expect(s2 ~= nil, f.id .. "+" .. e.id)
			checkSpec(s2, f.id .. "+" .. e.id)
			expect(s2.element == e.id, "element not applied")
		end
	end
end)

test("every modifier compiles on every form", function()
	for _, f in SpellParts.ByCategory.Form do
		for _, m in SpellParts.ByCategory.Modifier do
			local spec = SpellBuilder.compile({ form = f.id, element = "Fire", mods = { m.id, m.id } })
			expect(spec ~= nil, f.id .. "+" .. m.id)
			checkSpec(spec, f.id .. "+" .. m.id)
		end
	end
end)

test("premade spells are valid", function()
	for _, premade in PremadeSpells.List do
		local ok, err = SpellBuilder.validate(premade.recipe)
		expect(ok, premade.id .. ": " .. tostring(err))
		local spec = SpellBuilder.compile(premade.recipe)
		checkSpec(spec, premade.id)
		expect(Rarity.Info[premade.rarity] ~= nil, premade.id .. " rarity")
	end
	expect(#PremadeSpells.List >= 40, "expected at least 40 premade spells")
end)

test("invalid recipes are rejected", function()
	expect(not SpellBuilder.validate(nil), "nil accepted")
	expect(not SpellBuilder.validate({}), "empty accepted")
	expect(not SpellBuilder.validate({ form = "Fire" }), "element as form accepted")
	expect(not SpellBuilder.validate({ form = "Bolt", element = "Homing" }), "modifier as element accepted")
	expect(not SpellBuilder.validate({ form = "Bolt", mods = { "Fire" } }), "element as modifier accepted")
	expect(
		not SpellBuilder.validate({ form = "Bolt", mods = { "Homing", "Homing", "Homing", "Homing", "Homing" } }),
		"5 mods accepted"
	)
	expect(not SpellBuilder.validate({ form = "Bolt", trigger = "OnHit" }), "trigger without payload accepted")
	expect(
		not SpellBuilder.validate({ form = "Bolt", payload = { form = "Bolt" } }),
		"payload without trigger accepted"
	)
	expect(
		not SpellBuilder.validate({ form = "Bolt", mods = { [1] = "Homing", [3] = "Twin" } }),
		"sparse mods accepted"
	)
	local deep = { form = "Bolt" }
	for _ = 1, Config.Spell.MaxDepth do
		deep = { form = "Bolt", trigger = "OnHit", payload = deep }
	end
	expect(not SpellBuilder.validate(deep), "over-deep payload accepted")
	local okDeep = { form = "Bolt" }
	for _ = 1, Config.Spell.MaxDepth - 1 do
		okDeep = { form = "Bolt", trigger = "OnHit", payload = okDeep }
	end
	expect(SpellBuilder.validate(okDeep), "max-depth payload rejected")
end)

test("modifiers do what they say", function()
	local base = SpellBuilder.compile({ form = "Bolt", element = "Fire" })
	local twin = SpellBuilder.compile({ form = "Bolt", element = "Fire", mods = { "Twin" } })
	local triple = SpellBuilder.compile({ form = "Bolt", element = "Fire", mods = { "Triple" } })
	local both = SpellBuilder.compile({ form = "Bolt", element = "Fire", mods = { "Twin", "Triple" } })
	expect(twin.count == base.count * 2, "twin count")
	expect(triple.count == base.count * 3, "triple count")
	expect(both.count == 6, "twin+triple count")
	local eff = SpellBuilder.compile({ form = "Bolt", element = "Fire", mods = { "Efficient" } })
	expect(eff.mana < base.mana, "efficient should reduce mana")
	local emp = SpellBuilder.compile({ form = "Bolt", element = "Fire", mods = { "Empower" } })
	expect(emp.damage > base.damage, "empower damage")
	local homing = SpellBuilder.compile({ form = "Bolt", mods = { "Homing" } })
	expect(homing.homing > 0, "homing")
	local exp = SpellBuilder.compile({ form = "Bolt", mods = { "Explosive" } })
	expect(exp.explodeRadius > 0 and exp.explodeMult > 0, "explosive")
	local burn = SpellBuilder.compile({ form = "Bolt", element = "Fire" })
	expect(burn.status and burn.status.kind == "Burn", "fire burns")
end)

test("trigger payload mana is paid up front", function()
	local payload = SpellBuilder.compile({ form = "Nova", element = "Frost" })
	local parent = SpellBuilder.compile({ form = "Bolt", element = "Fire" })
	local combo = SpellBuilder.compile({
		form = "Bolt",
		element = "Fire",
		trigger = "OnHit",
		payload = { form = "Nova", element = "Frost" },
	})
	expect(combo.mana > parent.mana + payload.mana, "combo mana should include payload + trigger")
	expect(combo.payload.name == payload.name, "payload compiled")
	expect(string.find(combo.name, "»", 1, true) ~= nil, "combo name shows payload: " .. combo.name)
end)

test("wand context folds in bonuses and always-cast is free", function()
	local plain = SpellBuilder.compile({ form = "Bolt", element = "Fire" })
	local boosted = SpellBuilder.compile(
		{ form = "Bolt", element = "Fire" },
		{ damageMult = 1.5, affinity = "Fire", affinityBonus = 0.2, alwaysCast = { "Homing", "Twin" } }
	)
	expect(math.abs(boosted.damage - plain.damage * 1.5 * 1.2) < 0.001, "damage mult + affinity")
	expect(boosted.homing > 0, "always cast homing applied")
	expect(boosted.count == 2, "always cast twin applied")
	expect(boosted.mana == plain.mana, "always cast should be free, got " .. boosted.mana .. " vs " .. plain.mana)
end)

test("names read nicely", function()
	local spec = SpellBuilder.compile({ form = "Bolt", element = "Fire", mods = { "Homing", "Twin" } })
	expect(spec.name == "Seeking Twin Ember Bolt", spec.name)
	local spec2 = SpellBuilder.compile({ form = "Spark", mods = { "Haste", "Haste", "Pierce", "Bounce" } })
	expect(spec2.name == "Swift Piercing Spark +2", spec2.name)
end)

test("fuzz: random recipes always compile to finite numbers", function()
	local rng = Random.new(1234)
	local cats = SpellParts.ByCategory
	local function pick(list)
		return list[rng:NextInteger(1, #list)].id
	end
	local function randomRecipe(depth)
		local r = { form = pick(cats.Form), mods = {} }
		if rng:NextNumber() < 0.8 then
			r.element = pick(cats.Element)
		end
		for _ = 1, rng:NextInteger(0, Config.Spell.MaxModifiers) do
			table.insert(r.mods, pick(cats.Modifier))
		end
		if depth < Config.Spell.MaxDepth and rng:NextNumber() < 0.5 then
			r.trigger = pick(cats.Trigger)
			r.payload = randomRecipe(depth + 1)
		end
		return r
	end
	for i = 1, 4000 do
		local recipe = randomRecipe(1)
		local spec, err = SpellBuilder.compile(recipe)
		expect(spec ~= nil, "fuzz #" .. i .. " failed: " .. tostring(err))
		checkSpec(spec, "fuzz #" .. i)
		local lines = SpellBuilder.describe(spec)
		expect(#lines > 0, "describe returned nothing")
	end
end)

test("there really are tons of spells", function()
	local f = #SpellParts.ByCategory.Form
	local e = #SpellParts.ByCategory.Element + 1 -- or no element
	local m = #SpellParts.ByCategory.Modifier
	-- ordered modifier lists of length 0..MaxModifiers
	local modCombos = 0
	for k = 0, Config.Spell.MaxModifiers do
		modCombos += m ^ k
	end
	local single = f * e * modCombos
	print(
		string.format(
			"      single-layer spells: %.3g, with one trigger layer: %.3g",
			single,
			single * #SpellParts.ByCategory.Trigger * single
		)
	)
	expect(single > 1e6, "expected millions of combinations")
end)
