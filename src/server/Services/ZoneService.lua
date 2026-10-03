-- Lingering ground effects left by Cloud spells and the Lingering modifier, and the solid
-- walls conjured by Rampart spells.

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

type Wall = {
	part: BasePart,
	untilT: number,
	onEnd: ((Vector3) -> ())?,
}

local zones: { Zone } = {}
local walls: { Wall } = {}
local nextId = 0
local MAX_ZONES = 60
local MAX_WALLS = 40
local TICK = 0.5

-- What a conjured wall is made of, by element.
local WALL_LOOKS: { [string]: { Enum.Material | number } } = {
	Earth = { Enum.Material.Slate, 0 },
	Frost = { Enum.Material.Ice, 0.15 },
	Fire = { Enum.Material.CrackedLava, 0 },
	Poison = { Enum.Material.Glass, 0.35 },
	Void = { Enum.Material.Glass, 0.3 },
	Chaos = { Enum.Material.Neon, 0.4 },
}

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

-- A solid wall standing on `ground`, its face turned toward `facing`. Blocks movement and spells
-- until it crumbles, then calls onEnd with its centre.
function ZoneService.createWall(spec: Spec, ground: Vector3, facing: Vector3, onEnd: ((Vector3) -> ())?): BasePart
	if #walls >= MAX_WALLS then
		local oldest = table.remove(walls, 1) :: Wall
		oldest.part:Destroy()
	end
	local folder = workspace:FindFirstChild("SpellWalls")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "SpellWalls"
		folder.Parent = workspace
	end
	local flat = Vector3.new(facing.X, 0, facing.Z)
	local look = if flat.Magnitude > 1e-3 then flat.Unit else Vector3.new(0, 0, -1)
	local style = WALL_LOOKS[spec.element] or { Enum.Material.Glass, 0.3 }
	local center = ground + Vector3.new(0, spec.wallHeight / 2 - 0.5, 0)
	local part = Instance.new("Part")
	part.Name = "SpellWall"
	part.Anchored = true
	part.CanTouch = false
	part.Size = Vector3.new(spec.wallWidth, spec.wallHeight, 2)
	part.CFrame = CFrame.lookAt(center, center + look)
	part.Material = style[1] :: Enum.Material
	part.Transparency = style[2] :: number
	part.Color = Color3.fromRGB(spec.color[1], spec.color[2], spec.color[3])
	part.Parent = folder
	table.insert(walls, { part = part, untilT = now() + spec.lifetime, onEnd = onEnd })
	return part
end

function ZoneService.clear()
	table.clear(zones)
	for _, wall in walls do
		wall.part:Destroy()
	end
	table.clear(walls)
end

local function tickWalls(t: number)
	local i = 1
	while i <= #walls do
		local wall = walls[i]
		if t >= wall.untilT then
			table.remove(walls, i)
			local center = wall.part.Position
			wall.part:Destroy()
			if wall.onEnd then
				task.spawn(wall.onEnd, center)
			end
		else
			i += 1
		end
	end
end

function ZoneService.init()
	RunService.Heartbeat:Connect(function()
		if #walls > 0 then
			tickWalls(now())
		end
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
