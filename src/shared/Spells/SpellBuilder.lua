--!strict
-- Turns a spell Recipe (a list of part ids) into a compiled Spec with final numbers.
-- Used by the server to execute casts and by the client to preview spells in the Spellforge.

local Config = require(script.Parent.Parent.Config)
local SpellTypes = require(script.Parent.SpellTypes)
local SpellParts = require(script.Parent.SpellParts)
local SpellNames = require(script.Parent.SpellNames)

type Recipe = SpellTypes.Recipe
type Spec = SpellTypes.Spec

export type WandContext = {
	damageMult: number?,
	speedMult: number?,
	affinity: string?,
	affinityBonus: number?,
	alwaysCast: { string }?,
}

local SpellBuilder = {}

local function newSpec(): Spec
	return {
		name = "",
		form = "Bolt",
		element = "Neutral",
		kind = "Projectile",
		depth = 1,
		mana = 0,
		castDelay = 0,
		recharge = 0,
		hpCost = 0,
		damage = 0,
		directMult = 1,
		speed = 0,
		lifetime = 1,
		size = 1,
		gravity = 0,
		count = 1,
		spread = 0,
		range = 0,
		radius = 0,
		bounces = 0,
		pierce = 0,
		homing = 0,
		explodeRadius = 0,
		explodeMult = 0,
		explodeOnExpire = false,
		stick = false,
		proximity = 0,
		armTime = 0,
		zoneOnImpact = false,
		zoneRadius = 0,
		zoneDuration = 0,
		zoneMult = 0,
		chainJumps = 0,
		chainRange = 0,
		boomerangAt = 0,
		blinkDistance = 0,
		shieldAmount = 0,
		shieldDuration = 0,
		meteorHeight = 0,
		orbit = false,
		orbitRadius = 0,
		accelerate = 0,
		erratic = 0,
		phasing = false,
		vortex = 0,
		echo = 0,
		shatter = 0,
		hold = 0,
		hover = 0,
		turretRate = 0,
		turretRange = 0,
		pull = 0,
		auraDps = 0,
		auraRadius = 0,
		auraLift = 0,
		hydra = 0,
		fractal = 0,
		skyfall = false,
		swap = false,
		chaos = false,
		rewind = 0,
		wallWidth = 0,
		wallHeight = 0,
		knockback = 0,
		lift = 0,
		crit = 0,
		lifesteal = 0,
		arc = 0,
		status = nil,
		mark = 0,
		trigger = nil,
		payload = nil,
		shard = nil,
		turretShot = nil,
		fractalChild = nil,
		color = { 255, 255, 255 },
		color2 = { 255, 255, 255 },
	}
end

-- Returns true if the recipe is legal, otherwise false and a human readable reason.
function SpellBuilder.validate(recipe: any, depth: number?): (boolean, string?)
	local d = depth or 1
	if type(recipe) ~= "table" then
		return false, "Not a spell"
	end
	if d > Config.Spell.MaxDepth then
		return false, "Payloads can only be nested " .. Config.Spell.MaxDepth .. " deep"
	end
	if not SpellParts.isCategory(recipe.form, "Form") then
		return false, "A spell needs a Form"
	end
	if recipe.element ~= nil and not SpellParts.isCategory(recipe.element, "Element") then
		return false, "Invalid element"
	end
	local mods = recipe.mods
	if mods ~= nil then
		if type(mods) ~= "table" then
			return false, "Invalid modifiers"
		end
		if #mods > Config.Spell.MaxModifiers then
			return false, "At most " .. Config.Spell.MaxModifiers .. " modifiers"
		end
		local n = 0
		for _ in mods do
			n += 1
		end
		if n ~= #mods then
			return false, "Invalid modifiers"
		end
		for _, id in mods do
			if not SpellParts.isCategory(id, "Modifier") then
				return false, "Invalid modifier"
			end
		end
	end
	local hasTrigger = recipe.trigger ~= nil
	local hasPayload = recipe.payload ~= nil
	if hasTrigger ~= hasPayload then
		return false, if hasTrigger then "A trigger needs a payload spell" else "A payload needs a trigger"
	end
	if hasTrigger then
		if not SpellParts.isCategory(recipe.trigger, "Trigger") then
			return false, "Invalid trigger"
		end
		local ok, err = SpellBuilder.validate(recipe.payload, d + 1)
		if not ok then
			return false, err
		end
	end
	return true, nil
end

-- Deep copies only the known recipe fields, dropping anything a client may have smuggled in.
function SpellBuilder.sanitize(recipe: Recipe): Recipe
	local mods = {}
	if recipe.mods then
		for _, id in recipe.mods do
			table.insert(mods, id)
		end
	end
	return {
		form = recipe.form,
		element = recipe.element,
		mods = mods,
		trigger = recipe.trigger,
		payload = if recipe.payload then SpellBuilder.sanitize(recipe.payload) else nil,
	}
end

-- Counts the parts used directly by this recipe (not by its payload, which is its own spell).
function SpellBuilder.countParts(recipe: Recipe): { [string]: number }
	local counts: { [string]: number } = {}
	local function add(id: string?)
		if id then
			counts[id] = (counts[id] or 0) + 1
		end
	end
	add(recipe.form)
	add(recipe.element)
	if recipe.mods then
		for _, id in recipe.mods do
			add(id)
		end
	end
	add(recipe.trigger)
	return counts
end

-- Total number of parts in a recipe including nested payloads. Used for spell rarity.
function SpellBuilder.complexity(recipe: Recipe): number
	local n = 0
	for _, c in SpellBuilder.countParts(recipe) do
		n += c
	end
	if recipe.payload then
		n += SpellBuilder.complexity(recipe.payload)
	end
	return n
end

local function compileInner(recipe: Recipe, ctx: WandContext?, depth: number): Spec
	local spec = newSpec()
	spec.depth = depth

	-- 1. Form base stats
	local formPart = SpellParts.ById[recipe.form]
	spec.form = formPart.id
	spec.kind = formPart.kind or "Projectile"
	for key, value in (formPart.base or {}) :: { [string]: any } do
		(spec :: any)[key] = value
	end

	-- 2. Element
	local elementPart = SpellParts.get(recipe.element)
	if elementPart then
		spec.element = elementPart.id
		spec.color = elementPart.color
		spec.color2 = (elementPart.base and elementPart.base.color2) or elementPart.color
		if elementPart.elementApply then
			elementPart.elementApply(spec)
		end
	else
		spec.element = SpellParts.NeutralElement.id
		spec.color = SpellParts.NeutralElement.color
		spec.color2 = SpellParts.NeutralElement.color2
	end

	-- 3. Modifiers, in the order they were slotted
	local posts: { (Spec) -> () } = {}
	local function applyModifier(id: string)
		local mod = SpellParts.ById[id]
		if mod.apply then
			mod.apply(spec)
		end
		if mod.post then
			table.insert(posts, mod.post)
		end
	end
	if recipe.mods then
		for _, id in recipe.mods do
			applyModifier(id)
		end
	end

	-- 4. Wand "always cast" modifiers are free: they never add mana cost or cast delay
	if ctx and ctx.alwaysCast then
		local mana, delay = spec.mana, spec.castDelay
		local postCount = #posts
		for _, id in ctx.alwaysCast do
			if SpellParts.isCategory(id, "Modifier") then
				applyModifier(id)
			end
		end
		-- drop any post-processing the always-cast mods added so they stay free too
		for i = #posts, postCount + 1, -1 do
			table.remove(posts, i)
		end
		spec.mana, spec.castDelay = mana, delay
	end

	-- 5. Global balance (Config.Combat), then the wand's stat multipliers
	spec.damage *= Config.Combat.SpellDamageMultiplier
	if ctx then
		spec.damage *= ctx.damageMult or 1
		spec.speed *= ctx.speedMult or 1
		if ctx.affinity and ctx.affinity == spec.element then
			spec.damage *= 1 + (ctx.affinityBonus or 0)
		end
	end

	-- 6. Shatter shards: a little spark of the same element
	if spec.shatter > 0 then
		local shard = compileInner({ form = "Spark", element = recipe.element }, nil, depth + 1)
		shard.damage = spec.damage * 0.45
		shard.lifetime = 0.5
		shard.shatter = 0
		spec.shard = shard
	end

	-- 7. Trigger + payload: the payload's mana is paid up front, like in Noita
	if recipe.trigger and recipe.payload then
		local trig = SpellParts.ById[recipe.trigger]
		local payload = compileInner(recipe.payload, ctx, depth + 1)
		spec.trigger = trig.id
		spec.payload = payload
		spec.mana += (trig.triggerMana or 0) + payload.mana
		spec.castDelay += payload.castDelay * Config.Spell.PayloadDelayFactor
		spec.recharge += payload.recharge * Config.Spell.PayloadDelayFactor
	end

	-- 8. Whole-spell post-processing (Efficient, Echo)
	for _, post in posts do
		post(spec)
	end

	-- 9. Clamp to sane values
	spec.mana = math.max(0, math.floor(spec.mana + 0.5))
	spec.count = math.clamp(math.floor(spec.count), 1, 27)
	spec.crit = math.clamp(spec.crit, 0, 1)
	spec.lifesteal = math.clamp(spec.lifesteal, 0, 1)
	spec.pierce = math.max(0, spec.pierce)
	spec.bounces = math.clamp(spec.bounces, 0, 30)
	spec.echo = math.clamp(spec.echo, 0, 3)
	spec.size = math.clamp(spec.size, 0.2, 12)
	spec.lifetime = math.clamp(spec.lifetime, 0.1, 30)
	spec.hold = math.clamp(spec.hold, 0, 4)
	spec.hydra = math.clamp(spec.hydra, 0, 3)
	spec.fractal = math.clamp(spec.fractal, 0, 3)
	spec.rewind = math.clamp(spec.rewind, 0, 4)
	spec.name = SpellNames.generate(recipe)

	-- 10. Derived sub-spells
	if spec.turretRate > 0 then
		-- a sentry's shots inherit the sentry's element and modifiers, as a fast spark
		local shot = table.clone(spec)
		shot.form = "Spark"
		shot.kind = "Projectile"
		shot.speed = 200
		shot.lifetime = 1.1
		shot.size = math.clamp(spec.size * 0.3, 0.35, 1.2)
		shot.directMult = 1
		shot.pierce = math.max(0, spec.pierce - 99)
		shot.hover = 0
		shot.hold = 0
		shot.turretRate = 0
		shot.turretShot = nil
		shot.pull = 0
		shot.auraDps = 0
		shot.count = 1
		shot.echo = 0
		shot.fractal = 0
		shot.fractalChild = nil
		shot.orbit = false
		shot.skyfall = false
		shot.trigger = nil
		shot.payload = nil
		shot.mana = 0
		shot.name = spec.name
		spec.turretShot = shot
	end
	if spec.fractal > 0 then
		-- each generation is a smaller, weaker copy that splits again
		local function child(parent: Spec): Spec
			local c = table.clone(parent)
			c.fractal = parent.fractal - 1
			c.damage *= 0.55
			c.size = math.max(0.25, c.size * 0.7)
			c.radius *= 0.7
			c.explodeRadius *= 0.75
			c.zoneRadius *= 0.75
			c.range *= 0.7
			c.lifetime = math.max(0.25, c.lifetime * 0.7)
			c.speed *= 0.9
			c.count = 1
			c.echo = 0
			c.hold = 0
			c.skyfall = false
			c.mana = 0
			c.fractalChild = if c.fractal > 0 then child(c) else nil
			return c
		end
		spec.fractalChild = child(spec)
	end
	return spec
end

-- Compiles a recipe. Returns nil plus a reason if the recipe is invalid.
function SpellBuilder.compile(recipe: Recipe, ctx: WandContext?): (Spec?, string?)
	local ok, err = SpellBuilder.validate(recipe)
	if not ok then
		return nil, err
	end
	return compileInner(recipe, ctx, 1), nil
end

local function round(n: number, places: number?): string
	local p = 10 ^ (places or 0)
	local v = math.floor(n * p + 0.5) / p
	if v == math.floor(v) then
		return tostring(math.floor(v))
	end
	return tostring(v)
end

-- Human readable stat lines for tooltips: { {label, value}, ... }
function SpellBuilder.describe(spec: Spec): { { string } }
	local lines: { { string } } = {}
	local function add(label: string, value: string)
		table.insert(lines, { label, value })
	end

	local hits = if spec.count > 1 then " x" .. spec.count else ""
	if spec.kind == "Blink" then
		add("Teleport", round(spec.blinkDistance) .. " studs")
	elseif spec.kind == "Aegis" then
		add("Shield", round(spec.shieldAmount) .. " for " .. round(spec.shieldDuration, 1) .. "s")
	elseif spec.kind == "Wall" then
		add(
			"Wall",
			round(spec.wallWidth) .. " x " .. round(spec.wallHeight) .. " for " .. round(spec.lifetime, 1) .. "s"
		)
	else
		if spec.turretRate > 0 then
			add("Sentry shots", round(spec.damage, 1) .. " every " .. round(spec.turretRate, 2) .. "s")
		end
		if spec.auraDps > 0 then
			add("Aura", round(spec.auraDps, 1) .. "/s in " .. round(spec.auraRadius) .. " studs")
		end
		if spec.damage > 0 and spec.directMult > 0 then
			add("Damage", round(spec.damage * spec.directMult, 1) .. hits)
		end
		if spec.explodeRadius > 0 and spec.explodeMult > 0 then
			add(
				"Explosion",
				round(spec.damage * spec.explodeMult, 1) .. " in " .. round(spec.explodeRadius) .. " studs"
			)
		end
		if spec.zoneOnImpact then
			add("Zone", round(spec.damage * spec.zoneMult * 2, 1) .. "/s for " .. round(spec.zoneDuration, 1) .. "s")
		end
	end
	add("Mana", round(spec.mana))
	add("Cast delay", round(spec.castDelay, 2) .. "s")
	if spec.recharge ~= 0 then
		add("Recharge", (if spec.recharge > 0 then "+" else "") .. round(spec.recharge, 2) .. "s")
	end
	if spec.kind == "Projectile" or spec.kind == "Meteor" then
		add("Speed", round(spec.speed))
	elseif spec.kind == "Beam" or spec.kind == "Chain" then
		add("Range", round(spec.range))
	elseif spec.kind == "Nova" then
		add("Radius", round(spec.radius))
	end
	if spec.kind == "Chain" then
		add("Jumps", round(spec.chainJumps))
	end
	if spec.skyfall then
		add("Skyfall", "falls onto your aim")
	end
	if spec.hold > 0 then
		add("Stasis", round(spec.hold, 1) .. "s")
	end
	if spec.pull > 0 then
		add("Pull", round(spec.pull))
	end
	if spec.hydra > 0 then
		add("Hydra", "+" .. round(spec.hydra) .. " per bounce")
	end
	if spec.fractal > 0 then
		add("Fractal", round(spec.fractal) .. " generations")
	end
	if spec.swap then
		add("Transpose", "swap places on hit")
	end
	if spec.chaos then
		add("Chaos", "25%-250% damage")
	end
	if spec.rewind > 0 then
		add("Rewind", round(spec.rewind, 1) .. "s")
	end
	if spec.crit > 0 then
		add("Crit", round(spec.crit * 100) .. "%")
	end
	if spec.lifesteal > 0 then
		add("Lifesteal", round(spec.lifesteal * 100) .. "%")
	end
	if spec.homing > 0 then
		add("Homing", round(spec.homing, 1))
	end
	if spec.bounces > 0 then
		add("Bounces", round(spec.bounces))
	end
	if spec.pierce > 0 and spec.pierce < 50 then
		add("Pierce", round(spec.pierce))
	end
	if spec.hpCost > 0 then
		add("Health cost", round(spec.hpCost))
	end
	if spec.echo > 0 then
		add("Echoes", round(spec.echo))
	end
	if spec.status then
		add("Applies", spec.status.kind)
	end
	if spec.mark > 0 then
		add("Marks", round(spec.mark) .. "s")
	end
	if spec.trigger and spec.payload then
		local trig = SpellParts.ById[spec.trigger]
		add(trig.name, spec.payload.name)
	end
	return lines
end

return SpellBuilder
