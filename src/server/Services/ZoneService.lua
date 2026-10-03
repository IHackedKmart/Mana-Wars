-- Lingering ground effects left by Cloud spells and the Lingering modifier.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local SpellTypes = require(ReplicatedStorage.Shared.Spells.SpellTypes)
local Combatants = require(script.Parent.Combatants)
local WorldQuery = require(script.Parent.WorldQuery)
local DamageService = require(script.Parent.DamageService)
local FX = require(script.Parent.FX)

type Spec = SpellTypes.Spec
type Combatant = Combatants.Combatant

type Zone = {
	id: number,
	pos: Vector3,
	radius: number,
	untilT: number,
	nextTick: number,
	damage: number,
	spec: Spec,
	caster: Combatant,
}

local ZoneService = {}

local zones: { Zone } = {}
local nextId = 0
local MAX_ZONES = 60
local TICK = 0.5

local function now(): number
	return workspace:GetServerTimeNow()
end

function ZoneService.create(spec: Spec, caster: Combatant, position: Vector3)
	if #zones >= MAX_ZONES then
		table.remove(zones, 1)
	end
	local ground = WorldQuery.groundBelow(position + Vector3.new(0, 2, 0), 40) or position
	nextId += 1
	local zone: Zone = {
		id = nextId,
		pos = ground,
		radius = spec.zoneRadius,
		untilT = now() + spec.zoneDuration,
		nextTick = now() + 0.15,
		damage = spec.damage * spec.zoneMult,
		spec = spec,
		caster = caster,
	}
	table.insert(zones, zone)
	FX.all("Zone", zone.id, ground, zone.radius, spec.zoneDuration, spec.color, spec.color2, spec.element)
end

function ZoneService.clear()
	table.clear(zones)
end

function ZoneService.init()
	RunService.Heartbeat:Connect(function()
		if #zones == 0 then
			return
		end
		local t = now()
		local i = 1
		while i <= #zones do
			local z = zones[i]
			if t >= z.untilT then
				table.remove(zones, i)
			else
				if t >= z.nextTick then
					z.nextTick += TICK
					for _, c in Combatants.active() do
						if c ~= z.caster then
							local p = (c.root :: BasePart).Position
							local flat = Vector3.new(p.X - z.pos.X, 0, p.Z - z.pos.Z).Magnitude
							if flat <= z.radius and math.abs(p.Y - z.pos.Y) < 8 then
								DamageService.apply(c, z.damage, {
									attacker = z.caster,
									element = z.spec.element,
									status = z.spec.status,
									noCrit = true,
									spellName = z.spec.name,
									lifesteal = z.spec.lifesteal * 0.5,
								})
							end
						end
					end
				end
				i += 1
			end
		end
	end)
end

return ZoneService
