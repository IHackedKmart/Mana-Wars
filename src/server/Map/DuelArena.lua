-- Floating duel arenas: a round platform high above everything else, with cover pillars, low walls,
-- a crenellated rim, braziers and an invisible wall so nobody is knocked into the sky. Each arena
-- slot gets the colours of one of the islands (see MapDefs styles) and is built once, then reused.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Build = require(script.Parent.Build)
local MapDefs = require(script.Parent.MapDefs)

local DuelArena = {}

local M = Enum.Material
local rgb = Color3.fromRGB

export type Info = {
	model: Model,
	center: Vector3, -- the middle of the floor's top surface
	radius: number,
	spawns: { CFrame },
	floorY: number,
}

-- Where arena `slot` floats: far from the islands, the Plaza and the library, and high above them.
function DuelArena.centerOf(slot: number): Vector3
	return Vector3.new(-2400 + (slot - 1) * 260, 900, -2400)
end

local function block(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	material: Enum.Material,
	color: Color3,
	noCollide: boolean?
): Part
	local p = Build.part({ Name = name, Size = size, CFrame = cf, Material = material, Color = color }, parent)
	if noCollide then
		p.CanCollide = false
	end
	return p
end

function DuelArena.build(slot: number, parent: Instance): Info
	local def = MapDefs.List[(slot - 1) % #MapDefs.List + 1]
	local style = def.style
	local R = Config.Duel.ArenaRadius
	local base = DuelArena.centerOf(slot)
	local model = Build.model("DuelArena" .. slot, parent)
	local top = base.Y

	-- the platform: a thick patterned disc over a tapering rock underside
	local function disc(
		name: string,
		radius: number,
		y: number,
		h: number,
		material: Enum.Material,
		color: Color3,
		noCollide: boolean?
	)
		Build.cylinder(Vector3.new(base.X, y, base.Z), radius * 2, h, {
			Name = name,
			Material = material,
			Color = color,
			CanCollide = not noCollide,
		}, model)
	end
	disc("Floor", R, top - 2, 4, style.plaza, style.plazaColor)
	disc("Inlay", R - 3, top + 0.06, 0.2, style.plaza, style.plazaColor2, true)
	disc("Floor", R - 4.5, top + 0.12, 0.2, style.plaza, style.plazaColor, true)
	disc("Inlay", 9, top + 0.18, 0.2, style.plaza, style.plazaColor2, true)
	disc("Rune", 6, top + 0.24, 0.2, M.Neon, style.accent, true)
	for i, r in { R - 2, R - 10, R - 20, R - 30 } do
		disc("Underside", r, top - 4 - i * 5, 6, M.Rock, rgb(92, 86, 84):Lerp(style.stoneColors[1], 0.3))
	end

	-- cover: four pillars and two low walls between the spawns
	for i = 1, 4 do
		local a = math.rad(45 + (i - 1) * 90)
		local at = CFrame.new(base.X + math.cos(a) * 17, top + 6, base.Z + math.sin(a) * 17)
		block(
			model,
			"Pillar",
			Vector3.new(4.5, 12, 4.5),
			at,
			style.stone,
			style.stoneColors[(i - 1) % #style.stoneColors + 1]
		)
		block(
			model,
			"PillarCap",
			Vector3.new(5.5, 1.2, 5.5),
			at * CFrame.new(0, 6.6, 0),
			style.stone,
			style.stoneColors[2]
		)
		block(
			model,
			"Banner",
			Vector3.new(3, 5, 0.2),
			at * CFrame.Angles(0, -a, 0) * CFrame.new(0, 1, -2.4),
			M.Fabric,
			style.banner[(i - 1) % #style.banner + 1],
			true
		)
	end
	for side = -1, 1, 2 do
		block(
			model,
			"Wall",
			Vector3.new(12, 4, 2),
			CFrame.new(base.X, top + 2, base.Z + side * 26),
			style.stone,
			style.stoneColors[1]
		)
	end

	-- the rim: crenellations, a glowing edge and four braziers
	local merlons = 28
	for i = 1, merlons do
		if i % 2 == 0 then
			local a = (i / merlons) * math.pi * 2
			local pos = Vector3.new(base.X + math.cos(a) * (R - 1), top + 1.5, base.Z + math.sin(a) * (R - 1))
			block(
				model,
				"Merlon",
				Vector3.new(4, 3, 2),
				CFrame.lookAt(pos, Vector3.new(base.X, pos.Y, base.Z)),
				style.stone,
				style.stoneColors[2]
			)
		end
	end
	disc("RimGlow", R + 0.4, top - 0.5, 0.5, M.Neon, style.accent, true)
	for i = 1, 4 do
		local a = (i - 1) * math.pi / 2 + math.pi / 4
		local p = Vector3.new(base.X + math.cos(a) * (R - 5), top, base.Z + math.sin(a) * (R - 5))
		block(
			model,
			"BrazierPost",
			Vector3.new(1.4, 4, 1.4),
			CFrame.new(p + Vector3.new(0, 2, 0)),
			M.Metal,
			rgb(50, 44, 42)
		)
		local bowl = block(
			model,
			"Brazier",
			Vector3.new(3, 0.8, 3),
			CFrame.new(p + Vector3.new(0, 4.4, 0)),
			M.Metal,
			rgb(60, 52, 46)
		)
		Build.make("Fire", { Size = 4, Heat = 7 }, bowl)
		Build.make("PointLight", { Color = rgb(255, 170, 90), Range = 30, Brightness = 2 }, bowl)
	end

	-- an invisible wall a little outside the rim (spells fly through it, mages don't)
	local segments = 36
	for i = 1, segments do
		local a = (i / segments) * math.pi * 2
		local pos = Vector3.new(base.X + math.cos(a) * (R + 1.5), top + 20, base.Z + math.sin(a) * (R + 1.5))
		local wall = block(
			model,
			"Barrier",
			Vector3.new(2 * math.pi * (R + 1.5) / segments + 1, 40, 1),
			CFrame.lookAt(pos, Vector3.new(base.X, pos.Y, base.Z)),
			M.SmoothPlastic,
			rgb(0, 0, 0)
		)
		wall.Transparency = 1
		wall.CanQuery = false
	end

	local spawns = {}
	for _, side in { -1, 1 } do
		local at = Vector3.new(base.X + side * (R - 8), top + 3, base.Z)
		table.insert(spawns, CFrame.lookAt(at, Vector3.new(base.X, at.Y, base.Z)))
	end
	return {
		model = model,
		center = Vector3.new(base.X, top, base.Z),
		radius = R,
		spawns = spawns,
		floorY = top,
	}
end

return DuelArena
