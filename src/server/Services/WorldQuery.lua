-- Raycasts against the world (never characters) and sweeps against combatant capsules.
-- Characters are tested with maths instead of physics so fast spells never tunnel through them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Geometry = require(ReplicatedStorage.Shared.Util.Geometry)
local Combatants = require(script.Parent.Combatants)

type Combatant = Combatants.Combatant

local WorldQuery = {}

local worldParams = RaycastParams.new()
worldParams.FilterType = Enum.RaycastFilterType.Exclude
worldParams.IgnoreWater = true
worldParams.RespectCanCollide = true

-- Call once per frame (cheap) so new characters are excluded from world casts.
-- (The lobby is solid too: Spell Lab spells splash against the library walls.
-- Its invisible barriers have CanQuery off, so spells pass through those.)
function WorldQuery.refresh()
	worldParams.FilterDescendantsInstances = table.clone(Combatants.models()) :: { any }
end

function WorldQuery.raycast(origin: Vector3, delta: Vector3): RaycastResult?
	if delta.Magnitude < 1e-3 then
		return nil
	end
	return workspace:Raycast(origin, delta, worldParams)
end

function WorldQuery.spherecast(origin: Vector3, radius: number, delta: Vector3): RaycastResult?
	if delta.Magnitude < 1e-3 then
		return nil
	end
	if radius <= 0.35 then
		return workspace:Raycast(origin, delta, worldParams)
	end
	return workspace:Spherecast(origin, radius, delta, worldParams)
end

function WorldQuery.groundBelow(position: Vector3, depth: number?): Vector3?
	local result = workspace:Raycast(position + Vector3.new(0, 3, 0), Vector3.new(0, -(depth or 60), 0), worldParams)
	return if result then result.Position else nil
end

function WorldQuery.lineOfSight(a: Vector3, b: Vector3): boolean
	return WorldQuery.raycast(a, b - a) == nil
end

export type SweepHit = { c: Combatant, t: number }

-- Every combatant whose capsule touches the swept sphere a->b, sorted by distance along the path.
function WorldQuery.sweep(a: Vector3, b: Vector3, radius: number, skip: (Combatant) -> boolean): { SweepHit }
	local hits: { SweepHit } = {}
	for _, c in Combatants.active() do
		if not skip(c) then
			local lo, hi = Combatants.capsule(c)
			local dist, t = Geometry.segmentSegment(a, b, lo, hi)
			if dist <= radius + Combatants.CapsuleRadius then
				table.insert(hits, { c = c, t = t })
			end
		end
	end
	table.sort(hits, function(x, y)
		return x.t < y.t
	end)
	return hits
end

return WorldQuery
