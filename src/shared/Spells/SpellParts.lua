--!strict
-- Every spell part in the game. A spell is built from:
--   1 Form      (what the spell physically is: bolt, orb, beam, nova, mine...)
--   0-1 Element (what it is made of: fire burns, frost slows, void drains...)
--   0-4 Modifiers (homing, twin, explosive, bounce...; stack the same one for more)
--   0-1 Trigger + a payload spell (cast a whole other spell on hit / expiry / timer)
--
-- To add a new part, add an entry below. Forms set base stats, everything else
-- mutates the compiled spec in apply()/post(). See SpellBuilder for the pipeline.

local SpellTypes = require(script.Parent.SpellTypes)

type Spec = SpellTypes.Spec
type Part = SpellTypes.Part

local SpellParts = {}

SpellParts.Categories = { "Form", "Element", "Modifier", "Trigger" }
SpellParts.ById = {} :: { [string]: Part }
SpellParts.ByCategory = { Form = {}, Element = {}, Modifier = {}, Trigger = {} } :: { [string]: { Part } }
SpellParts.List = {} :: { Part }

local function register(part: Part)
	assert(SpellParts.ById[part.id] == nil, "duplicate spell part " .. part.id)
	SpellParts.ById[part.id] = part
	table.insert(SpellParts.List, part)
	table.insert(SpellParts.ByCategory[part.category], part)
end

local function form(id: string, data: { [string]: any })
	register({
		id = id,
		name = data.name or id,
		category = "Form",
		rarity = data.rarity,
		icon = data.icon,
		description = data.description,
		color = data.color or { 220, 220, 235 },
		kind = data.kind,
		base = data.base,
		noun = data.noun or id,
	})
end

local function element(id: string, data: { [string]: any })
	register({
		id = id,
		name = data.name or id,
		category = "Element",
		rarity = data.rarity,
		icon = data.icon,
		description = data.description,
		color = data.color,
		elementApply = data.apply,
		adjective = data.adjective or id,
		-- secondary colour is read by SpellBuilder through the base table
		base = { color2 = data.color2 },
	})
end

local function modifier(id: string, data: { [string]: any })
	register({
		id = id,
		name = data.name or id,
		category = "Modifier",
		rarity = data.rarity,
		icon = data.icon,
		description = data.description,
		color = data.color or { 120, 200, 255 },
		apply = data.apply,
		post = data.post,
		adjective = data.adjective or id,
	})
end

local function trigger(id: string, data: { [string]: any })
	register({
		id = id,
		name = data.name or id,
		category = "Trigger",
		rarity = data.rarity,
		icon = data.icon,
		description = data.description,
		color = data.color or { 255, 210, 120 },
		triggerMana = data.mana,
	})
end

---------------------------------------------------------------------------
-- FORMS
---------------------------------------------------------------------------

form("Bolt", {
	rarity = "Common",
	icon = "🔹",
	kind = "Projectile",
	description = "A reliable magic bolt. Medium speed, medium damage.",
	base = { damage = 14, speed = 120, lifetime = 1.5, size = 0.9, mana = 10, castDelay = 0.12, knockback = 12 },
})

form("Spark", {
	rarity = "Common",
	icon = "💫",
	kind = "Projectile",
	description = "A tiny, very fast spark. Cheap to cast and quick to repeat.",
	base = { damage = 6, speed = 190, lifetime = 0.8, size = 0.45, mana = 4, castDelay = 0.04, knockback = 4 },
})

form("Spray", {
	rarity = "Common",
	icon = "🎆",
	kind = "Projectile",
	noun = "Spray",
	description = "A short-ranged shotgun burst of five pellets.",
	base = {
		damage = 5,
		speed = 130,
		lifetime = 0.4,
		size = 0.5,
		count = 5,
		spread = 16,
		mana = 14,
		castDelay = 0.24,
		knockback = 8,
	},
})

form("Orb", {
	rarity = "Uncommon",
	icon = "🔮",
	kind = "Projectile",
	description = "A slow, heavy sphere that punches through its first target.",
	base = {
		damage = 28,
		speed = 45,
		lifetime = 3.2,
		size = 2.4,
		pierce = 1,
		mana = 26,
		castDelay = 0.32,
		knockback = 30,
	},
})

form("Grenade", {
	rarity = "Uncommon",
	icon = "💣",
	kind = "Projectile",
	noun = "Bomb",
	description = "A lobbed bomb that bounces around and explodes when its fuse runs out or it hits someone.",
	base = {
		damage = 26,
		directMult = 0,
		speed = 75,
		gravity = 1,
		lifetime = 1.6,
		size = 1,
		bounces = 3,
		explodeRadius = 10,
		explodeMult = 1,
		explodeOnExpire = true,
		mana = 22,
		castDelay = 0.3,
		knockback = 40,
	},
})

form("Wisp", {
	rarity = "Uncommon",
	icon = "👻",
	kind = "Projectile",
	description = "A slow spirit that hunts down the nearest enemy on its own.",
	base = {
		damage = 11,
		speed = 55,
		lifetime = 4,
		size = 0.8,
		homing = 3.5,
		mana = 15,
		castDelay = 0.18,
		knockback = 6,
	},
})

form("Boomerang", {
	rarity = "Uncommon",
	icon = "↩️",
	kind = "Projectile",
	noun = "Glaive",
	description = "A spinning glaive that flies out, then returns to you, cutting through everyone on the way.",
	base = {
		damage = 16,
		speed = 95,
		lifetime = 1.8,
		size = 1.2,
		boomerangAt = 0.55,
		pierce = 99,
		mana = 15,
		castDelay = 0.2,
		knockback = 14,
	},
})

form("Lance", {
	rarity = "Rare",
	icon = "🏹",
	kind = "Beam",
	description = "An instant beam of force. Hits whatever is in your crosshair.",
	base = { damage = 20, range = 150, size = 0.5, mana = 22, castDelay = 0.28, knockback = 18 },
})

form("Mine", {
	rarity = "Rare",
	icon = "🧨",
	kind = "Projectile",
	description = "A lobbed trap that sticks to the ground, arms itself, and explodes when an enemy walks near.",
	base = {
		damage = 34,
		directMult = 0,
		speed = 45,
		gravity = 1,
		lifetime = 25,
		size = 1,
		stick = true,
		proximity = 7,
		armTime = 0.8,
		explodeRadius = 9,
		explodeMult = 1,
		mana = 20,
		castDelay = 0.25,
		knockback = 45,
	},
})

form("Nova", {
	rarity = "Rare",
	icon = "🌟",
	kind = "Nova",
	description = "An instant ring of energy that blasts everything around you.",
	base = { damage = 18, radius = 14, size = 1, mana = 26, castDelay = 0.3, knockback = 40 },
})

form("Chain", {
	rarity = "Rare",
	icon = "⛓️",
	kind = "Chain",
	description = "Arcs to the nearest enemy in front of you, then jumps to more enemies nearby.",
	base = {
		damage = 12,
		range = 50,
		chainJumps = 3,
		chainRange = 24,
		size = 0.4,
		mana = 18,
		castDelay = 0.2,
		knockback = 6,
	},
})

form("Cloud", {
	rarity = "Rare",
	icon = "☁️",
	kind = "Projectile",
	description = "A lobbed flask that bursts into a lingering cloud, hurting everyone who stands in it.",
	base = {
		damage = 10,
		directMult = 0,
		speed = 65,
		gravity = 0.8,
		lifetime = 2,
		size = 1.2,
		zoneOnImpact = true,
		zoneRadius = 11,
		zoneDuration = 5,
		zoneMult = 0.5,
		mana = 28,
		castDelay = 0.35,
		knockback = 0,
	},
})

form("Blink", {
	rarity = "Epic",
	icon = "🌀",
	kind = "Blink",
	noun = "Step",
	description = "Teleports you up to 40 studs toward your aim. Triggers fire where you land.",
	base = { damage = 12, directMult = 0, blinkDistance = 40, size = 1, mana = 30, castDelay = 0.45, knockback = 20 },
})

form("Aegis", {
	rarity = "Epic",
	icon = "🛡️",
	kind = "Aegis",
	noun = "Ward",
	description = "Wraps you in a shield that absorbs damage for a few seconds. Triggers fire when it ends.",
	base = {
		damage = 0,
		directMult = 0,
		shieldAmount = 35,
		shieldDuration = 6,
		size = 1,
		mana = 40,
		castDelay = 0.5,
		knockback = 0,
	},
})

form("Meteor", {
	rarity = "Epic",
	icon = "☄️",
	kind = "Meteor",
	description = "Calls a burning rock down from the sky onto the spot you aim at.",
	base = {
		damage = 30,
		directMult = 0,
		range = 170,
		meteorHeight = 90,
		speed = 150,
		lifetime = 3,
		size = 2.6,
		explodeRadius = 11,
		explodeMult = 1,
		mana = 36,
		castDelay = 0.45,
		knockback = 50,
	},
})

---------------------------------------------------------------------------
-- ELEMENTS
---------------------------------------------------------------------------

element("Arcane", {
	rarity = "Common",
	icon = "✨",
	color = { 200, 120, 255 },
	color2 = { 120, 70, 255 },
	description = "Pure magic. +10% damage, +10% speed, 15% cheaper.",
	apply = function(s: Spec)
		s.damage *= 1.1
		s.speed *= 1.1
		s.mana *= 0.85
	end,
})

element("Fire", {
	rarity = "Common",
	icon = "🔥",
	adjective = "Ember",
	color = { 255, 120, 30 },
	color2 = { 255, 220, 80 },
	description = "Sets targets ablaze: 4 damage per second for 3 seconds.",
	apply = function(s: Spec)
		s.status = { kind = "Burn", dps = 4, duration = 3 }
	end,
})

element("Frost", {
	rarity = "Common",
	icon = "❄️",
	color = { 140, 220, 255 },
	color2 = { 235, 250, 255 },
	description = "Chills targets (35% slower). Three chills in a row freeze them solid. 10% slower spell.",
	apply = function(s: Spec)
		s.status = { kind = "Chill", slow = 0.35, duration = 2.5, maxStacks = 3 }
		s.speed *= 0.9
	end,
})

element("Earth", {
	rarity = "Uncommon",
	icon = "⛰️",
	adjective = "Stone",
	color = { 160, 115, 70 },
	color2 = { 95, 75, 55 },
	description = "Heavy and brutal. +35% damage and big knockback, but slower and affected by gravity.",
	apply = function(s: Spec)
		s.damage *= 1.35
		s.speed *= 0.75
		s.gravity += 0.35
		s.knockback += 30
		s.size *= 1.15
	end,
})

element("Wind", {
	rarity = "Uncommon",
	icon = "🌪️",
	adjective = "Gale",
	color = { 215, 250, 240 },
	color2 = { 160, 255, 215 },
	description = "Blows targets away and up into the air. +35% speed, -25% damage.",
	apply = function(s: Spec)
		s.knockback += 70
		s.lift += 35
		s.speed *= 1.35
		s.damage *= 0.75
	end,
})

element("Poison", {
	rarity = "Uncommon",
	icon = "☠️",
	adjective = "Venom",
	color = { 120, 230, 60 },
	color2 = { 40, 120, 30 },
	description = "Stacking venom: 1.5 damage per second per stack (up to 5) for 6 seconds. -20% direct damage.",
	apply = function(s: Spec)
		s.status = { kind = "Venom", dps = 1.5, duration = 6, maxStacks = 5 }
		s.damage *= 0.8
	end,
})

element("Lightning", {
	rarity = "Rare",
	icon = "⚡",
	adjective = "Storm",
	color = { 255, 240, 90 },
	color2 = { 150, 200, 255 },
	description = "Every hit arcs to one more nearby enemy for half damage. +35% speed, -10% damage.",
	apply = function(s: Spec)
		s.arc += 1
		s.speed *= 1.35
		s.damage *= 0.9
	end,
})

element("Void", {
	rarity = "Rare",
	icon = "🌌",
	color = { 120, 50, 170 },
	color2 = { 25, 0, 45 },
	description = "Drains life: heals you for 15% of damage dealt.",
	apply = function(s: Spec)
		s.lifesteal += 0.15
		s.damage *= 1.05
	end,
})

element("Radiant", {
	rarity = "Epic",
	icon = "☀️",
	color = { 255, 245, 190 },
	color2 = { 255, 205, 80 },
	description = "Marks targets for 5s: they glow through walls for everyone and take 15% more damage. +15% crit.",
	apply = function(s: Spec)
		s.mark = math.max(s.mark, 5)
		s.crit += 0.15
	end,
})

element("Blood", {
	rarity = "Epic",
	icon = "🩸",
	color = { 210, 20, 45 },
	color2 = { 90, 0, 15 },
	description = "+50% damage, but every cast costs you 4 health.",
	apply = function(s: Spec)
		s.damage *= 1.5
		s.hpCost += 4
	end,
})

---------------------------------------------------------------------------
-- MODIFIERS
---------------------------------------------------------------------------

modifier("Empower", {
	rarity = "Common",
	icon = "💪",
	adjective = "Mighty",
	description = "+35% damage.",
	apply = function(s: Spec)
		s.damage *= 1.35
		s.mana += 8
	end,
})

modifier("Haste", {
	rarity = "Common",
	icon = "⏩",
	adjective = "Swift",
	description = "+60% projectile speed (beams and chains reach further).",
	apply = function(s: Spec)
		s.speed *= 1.6
		s.range *= 1.15
		s.chainRange *= 1.2
		s.mana += 3
	end,
})

modifier("Enlarge", {
	rarity = "Common",
	icon = "🔍",
	adjective = "Greater",
	description = "+60% size and +35% area, +20% damage, slightly slower.",
	apply = function(s: Spec)
		s.size *= 1.6
		s.radius *= 1.35
		s.explodeRadius *= 1.3
		s.zoneRadius *= 1.3
		s.damage *= 1.2
		s.speed *= 0.85
		s.mana += 6
	end,
})

modifier("Quicken", {
	rarity = "Common",
	icon = "⏱️",
	adjective = "Quick",
	description = "Reduces cast delay by 0.08s and wand recharge by 0.12s.",
	apply = function(s: Spec)
		s.castDelay -= 0.08
		s.recharge -= 0.12
		s.mana += 4
	end,
})

modifier("Extend", {
	rarity = "Common",
	icon = "📏",
	adjective = "Far",
	description = "+60% lifetime and +40% range. Zones and shields last longer.",
	apply = function(s: Spec)
		s.lifetime *= 1.6
		s.range *= 1.4
		s.zoneDuration *= 1.3
		s.shieldDuration *= 1.4
		s.blinkDistance *= 1.3
		s.mana += 5
	end,
})

modifier("Bounce", {
	rarity = "Common",
	icon = "🏀",
	adjective = "Ricochet",
	description = "Bounces off walls and the ground 3 more times. Beams reflect.",
	apply = function(s: Spec)
		s.bounces += 3
		s.mana += 5
	end,
})

modifier("Knockback", {
	rarity = "Common",
	icon = "👊",
	adjective = "Forceful",
	description = "Hits send enemies flying.",
	apply = function(s: Spec)
		s.knockback += 60
		s.lift += 10
		s.mana += 6
	end,
})

modifier("Heavy", {
	rarity = "Common",
	icon = "🏋️",
	adjective = "Heavy",
	description = "Arcs downward under gravity. +30% damage and extra knockback.",
	apply = function(s: Spec)
		s.gravity += 0.9
		s.damage *= 1.3
		s.speed *= 0.9
		s.knockback += 15
		s.mana += 4
	end,
})

modifier("Erratic", {
	rarity = "Common",
	icon = "🎲",
	adjective = "Chaotic",
	description = "Wobbles unpredictably through the air. +15% damage.",
	apply = function(s: Spec)
		s.erratic += 1
		s.damage *= 1.15
		s.mana += 2
	end,
})

modifier("Twin", {
	rarity = "Uncommon",
	icon = "2️⃣",
	adjective = "Twin",
	description = "Casts the spell twice at once.",
	apply = function(s: Spec)
		s.mana += 4 + s.mana * 0.5
		s.count *= 2
		s.spread += 10
	end,
})

modifier("Homing", {
	rarity = "Uncommon",
	icon = "🎯",
	adjective = "Seeking",
	description = "Projectiles steer toward the nearest enemy.",
	apply = function(s: Spec)
		s.homing += if s.homing > 0 then 1.5 else 3
		s.mana += 10
	end,
})

modifier("Pierce", {
	rarity = "Uncommon",
	icon = "📌",
	adjective = "Piercing",
	description = "Passes through 2 more enemies. Chains jump 2 more times.",
	apply = function(s: Spec)
		s.pierce += 2
		s.chainJumps += 2
		s.mana += 8
	end,
})

modifier("Efficient", {
	rarity = "Uncommon",
	icon = "♻️",
	adjective = "Thrifty",
	description = "The whole spell costs 40% less mana.",
	post = function(s: Spec)
		s.mana *= 0.6
	end,
})

modifier("Critical", {
	rarity = "Uncommon",
	icon = "🗡️",
	adjective = "Keen",
	description = "+25% chance to critically hit for double damage.",
	apply = function(s: Spec)
		s.crit += 0.25
		s.mana += 7
	end,
})

modifier("Accelerate", {
	rarity = "Uncommon",
	icon = "🚀",
	adjective = "Accelerating",
	description = "Starts slow and speeds up rapidly. +20% damage.",
	apply = function(s: Spec)
		s.accelerate += 2.2
		s.speed *= 0.4
		s.lifetime *= 1.3
		s.damage *= 1.2
		s.mana += 5
	end,
})

modifier("Explosive", {
	rarity = "Rare",
	icon = "💥",
	adjective = "Bursting",
	description = "Explodes on impact, damaging everything nearby.",
	apply = function(s: Spec)
		s.explodeRadius = math.max(s.explodeRadius, 6 + s.size * 1.5) + 1
		s.explodeMult = math.max(s.explodeMult, 0.7)
		s.mana += 14
	end,
})

modifier("Lingering", {
	rarity = "Rare",
	icon = "♨️",
	adjective = "Lingering",
	description = "Leaves a pool of its element behind that damages anyone standing in it.",
	apply = function(s: Spec)
		s.zoneOnImpact = true
		s.zoneRadius = math.max(s.zoneRadius, 7 + s.size * 2)
		s.zoneDuration = math.max(s.zoneDuration, 3)
		s.zoneMult = math.max(s.zoneMult, 0.25)
		s.mana += 14
	end,
})

modifier("Leech", {
	rarity = "Rare",
	icon = "🦇",
	adjective = "Hungering",
	description = "Heals you for 20% of the damage this spell deals.",
	apply = function(s: Spec)
		s.lifesteal += 0.2
		s.mana += 12
	end,
})

modifier("Triple", {
	rarity = "Rare",
	icon = "3️⃣",
	adjective = "Triple",
	description = "Casts the spell three times at once in a fan.",
	apply = function(s: Spec)
		s.mana += 8 + s.mana * 0.9
		s.count *= 3
		s.spread += 18
	end,
})

modifier("Shatter", {
	rarity = "Rare",
	icon = "💎",
	adjective = "Shattering",
	description = "Bursts into 3 sharp shards of the same element when it hits something.",
	apply = function(s: Spec)
		s.shatter += 3
		s.mana += 15
	end,
})

modifier("Orbit", {
	rarity = "Rare",
	icon = "🔄",
	adjective = "Orbiting",
	description = "Projectiles circle around you as a protective ring instead of flying away.",
	apply = function(s: Spec)
		s.orbit = true
		s.orbitRadius = math.max(s.orbitRadius, 7)
		s.lifetime *= 2.5
		s.mana += 10
	end,
})

modifier("Overcharge", {
	rarity = "Epic",
	icon = "🔋",
	adjective = "Overcharged",
	description = "+80% damage, but much more mana and a longer cast delay.",
	apply = function(s: Spec)
		s.damage *= 1.8
		s.castDelay += 0.15
		s.mana += 25
	end,
})

modifier("Phasing", {
	rarity = "Epic",
	icon = "👁️",
	adjective = "Phantom",
	description = "Passes straight through walls and terrain.",
	apply = function(s: Spec)
		s.phasing = true
		s.mana += 18
	end,
})

modifier("Vortex", {
	rarity = "Epic",
	icon = "🕳️",
	adjective = "Vortex",
	description = "On impact, sucks nearby enemies toward the point of impact.",
	apply = function(s: Spec)
		s.vortex += 60
		s.mana += 16
	end,
})

modifier("Echo", {
	rarity = "Legendary",
	icon = "🔁",
	adjective = "Echoing",
	description = "The spell casts itself again a moment later for free.",
	apply = function(s: Spec)
		s.echo += 1
		s.castDelay += 0.05
	end,
	post = function(s: Spec)
		s.mana = s.mana * 1.5 + 5
	end,
})

---------------------------------------------------------------------------
-- TRIGGERS (must be paired with a payload spell)
---------------------------------------------------------------------------

trigger("OnHit", {
	name = "On Hit",
	rarity = "Rare",
	icon = "🎇",
	mana = 8,
	description = "Casts the payload spell wherever this spell hits something.",
})

trigger("OnExpire", {
	name = "On Expire",
	rarity = "Rare",
	icon = "⌛",
	mana = 6,
	description = "Casts the payload spell when this spell ends, however it ends.",
})

trigger("Timer", {
	name = "Timer",
	rarity = "Epic",
	icon = "⏲️",
	mana = 10,
	description = "Casts the payload spell once, half a second after casting, from wherever this spell is.",
})

trigger("Pulse", {
	name = "Pulse",
	rarity = "Legendary",
	icon = "💓",
	mana = 22,
	description = "Casts the payload spell every 0.6 seconds while this spell is alive (up to 6 times).",
})

-- The implicit element used when a spell has no element part slotted.
SpellParts.NeutralElement = {
	id = "Neutral",
	adjective = "",
	color = { 235, 235, 255 },
	color2 = { 170, 190, 255 },
}

function SpellParts.get(id: string?): Part?
	if id == nil then
		return nil
	end
	return SpellParts.ById[id]
end

function SpellParts.isCategory(id: string?, category: string): boolean
	local part = SpellParts.get(id)
	return part ~= nil and part.category == category
end

return SpellParts
