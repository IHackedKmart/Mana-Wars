-- Familiar powers that need the server:
--   Nip        - every few seconds the familiar darts at the nearest enemy in reach for a little damage
--   Last Ember - when its mage falls, the familiar bursts into flame around them
-- Stat powers (speed, ward, coins...) are folded into the combatant's gear by WardrobeService, and
-- Keen Nose / Night Eyes only show things to their owner, so the client handles those.
-- Familiars follow the normal damage rules: nothing during the grace period, and in the Spell Lab
-- they only nip training dummies.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Familiars = require(Shared.Familiars)
local SpellParts = require(Shared.Spells.SpellParts)
local Combatants = require(script.Parent.Combatants)
local DamageService = require(script.Parent.DamageService)
local FX = require(script.Parent.FX)

type Combatant = Combatants.Combatant

local FamiliarService = {}

local nextNip: { [Combatant]: number } = setmetatable({}, { __mode = "k" }) :: any
local TICK = 0.25

local function colorsOf(element: string): ({ number }, { number })
	local part = SpellParts.get(element) :: any
	if part then
		local base = part.base or {}
		return part.color, base.color2 or part.color
	end
	return { 235, 235, 255 }, { 170, 190, 255 }
end

local function powerOf(c: Combatant): (string?, number, string)
	local f = c.familiar
	if not f then
		return nil, 0, "Arcane"
	end
	local power, value = Familiars.powerOf(f)
	local species = Familiars.SpeciesById[f.species]
	return if power then power.id else nil, value, (species and species.element) or "Arcane"
end

-- The nearest combatant this one is allowed to hurt, within `range` of `center`.
local function nearestFoe(c: Combatant, center: Vector3, range: number): Combatant?
	local best, bestDist = nil, range
	for _, other in Combatants.active() do
		if other ~= c and DamageService.canHurt(other, c) then
			local d = (Combatants.centerOf(other) - center).Magnitude
			if d < bestDist then
				best, bestDist = other, d
			end
		end
	end
	return best
end

function FamiliarService.tryNip(c: Combatant, now: number): boolean
	local power, value, element = powerOf(c)
	if power ~= "nip" or not Combatants.canAct(c) or (nextNip[c] or 0) > now then
		return false
	end
	local target = nearestFoe(c, Combatants.centerOf(c), Familiars.NipRange)
	if not target then
		return false
	end
	nextNip[c] = now + Familiars.NipCooldown
	local color = colorsOf(element)
	local hitPos = Combatants.centerOf(target)
	FX.all("FamiliarNip", c.model, hitPos, color, element)
	DamageService.apply(target, value, {
		attacker = c,
		element = element,
		noCrit = true,
		spellName = (c.familiar and c.familiar.name) or "Familiar",
		hitPos = hitPos,
	})
	return true
end

-- Called by MatchService when a combatant falls (before they're cleaned up).
function FamiliarService.onDeath(c: Combatant, position: Vector3?)
	local power, value = powerOf(c)
	if power ~= "emberWake" or not position then
		return
	end
	local color, color2 = colorsOf("Fire")
	FX.all("Boom", position, Familiars.EmberWakeRadius, color, color2, "Fire")
	for _, other in Combatants.withinRadius(position, Familiars.EmberWakeRadius, c) do
		if DamageService.canHurt(other, c) then
			local center = Combatants.centerOf(other)
			DamageService.apply(other, value, {
				attacker = c,
				element = "Fire",
				noCrit = true,
				knockDir = (center - position + Vector3.new(0, 1, 0)).Unit,
				knockback = 20,
				lift = 14,
				spellName = (c.familiar and c.familiar.name) or "Last Ember",
				hitPos = center,
			})
		end
	end
end

function FamiliarService.init()
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < TICK then
			return
		end
		acc = 0
		local now = os.clock()
		for _, c in Combatants.all() do
			if c.familiar then
				FamiliarService.tryNip(c, now)
			end
		end
	end)
end

return FamiliarService
