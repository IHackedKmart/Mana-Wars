-- Points of interest on the arenas. Each builder makes one landmark at `center` (the y is ignored: it
-- reads the ground with heightAt) and returns where its chests go: { {cframe, tier} }.
-- The classic four (ruined tower, shrine, camp, watchtower) appear everywhere, restyled per map;
-- every map also has two landmarks of its own (see `pois` in MapDefs).

local Build = require(script.Parent.Build)
local MapDefs = require(script.Parent.MapDefs)

type Style = MapDefs.Style
export type ChestSpot = { cframe: CFrame, tier: string }
type HeightFn = (number, number) -> number

local Landmarks = {}

local M = Enum.Material
local rgb = Color3.fromRGB

local function pick<T>(rng: Random, list: { T }): T
	return list[rng:NextInteger(1, #list)]
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

local function glow(part: BasePart, color: Color3, range: number, brightness: number)
	Build.make("PointLight", { Color = color, Range = range, Brightness = brightness }, part)
end

local function landmark(parent: Instance, name: string): Model
	local model = Build.model(name, parent)
	model:SetAttribute("Landmark", true)
	return model
end

-- A floor that reaches down into uneven terrain. Returns the floor's top Y.
local function foundation(
	parent: Instance,
	center: Vector3,
	size: number,
	heightAt: HeightFn,
	material: Enum.Material,
	color: Color3
): number
	local half = size / 2
	local hs = {
		heightAt(center.X - half, center.Z - half),
		heightAt(center.X + half, center.Z - half),
		heightAt(center.X - half, center.Z + half),
		heightAt(center.X + half, center.Z + half),
		heightAt(center.X, center.Z),
	}
	local top = math.max(table.unpack(hs)) + 0.4
	local bottom = math.min(table.unpack(hs)) - 3
	Build.part({
		Name = "Foundation",
		Size = Vector3.new(size, top - bottom, size),
		CFrame = CFrame.new(center.X, (top + bottom) / 2, center.Z),
		Material = material,
		Color = color,
	}, parent)
	return top
end

-- A cloth banner hanging from a pole.
local function banner(parent: Instance, base: Vector3, height: number, color: Color3, facing: number)
	local pole = CFrame.new(base + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, facing, 0)
	block(parent, "Pole", Vector3.new(0.5, height, 0.5), pole, M.Wood, rgb(80, 58, 40))
	block(
		parent,
		"Banner",
		Vector3.new(0.15, height * 0.4, 2.6),
		pole * CFrame.new(0, height * 0.22, 1.4),
		M.Fabric,
		color,
		true
	)
	block(
		parent,
		"Finial",
		Vector3.new(0.8, 0.8, 0.8),
		pole * CFrame.new(0, height / 2 + 0.3, 0),
		M.Metal,
		rgb(212, 175, 55),
		true
	)
end

local function lantern(parent: Instance, pos: Vector3, color: Color3?)
	local c = color or rgb(255, 196, 110)
	block(
		parent,
		"LanternCap",
		Vector3.new(1, 0.3, 1),
		CFrame.new(pos + Vector3.new(0, 0.8, 0)),
		M.Metal,
		rgb(50, 44, 40),
		true
	)
	local lamp = block(parent, "Lantern", Vector3.new(0.8, 1.1, 0.8), CFrame.new(pos), M.Neon, c, true)
	glow(lamp, c, 16, 1.6)
end

local function wallRing(
	model: Instance,
	center: Vector3,
	floorY: number,
	radius: number,
	segments: number,
	style: Style,
	rng: Random,
	minH: number,
	maxH: number,
	gap: number
)
	for i = 1, segments do
		if rng:NextNumber() > gap then
			local angle = (i / segments) * math.pi * 2
			local h = rng:NextNumber(minH, maxH)
			local pos =
				Vector3.new(center.X + math.cos(angle) * radius, floorY + h / 2, center.Z + math.sin(angle) * radius)
			block(
				model,
				"Wall",
				Vector3.new(2 * math.pi * radius / segments + 0.4, h, 1.6),
				CFrame.lookAt(pos, Vector3.new(center.X, pos.Y, center.Z)),
				style.stone,
				pick(rng, style.stoneColors)
			)
		end
	end
end

---------------------------------------------------------------------------
-- The classic four
---------------------------------------------------------------------------

function Landmarks.ruinedTower(
	parent: Instance,
	center: Vector3,
	heightAt: HeightFn,
	rng: Random,
	style: Style
): { ChestSpot }
	local model = landmark(parent, "RuinedTower")
	local floorY = foundation(model, center, 20, heightAt, style.floor, style.floorColor)
	wallRing(model, center, floorY, 8, 14, style, rng, 3, 15, 0.22)
	-- a broken arch over the doorway
	local yaw = rng:NextNumber(0, math.pi * 2)
	local door = CFrame.new(center.X, floorY, center.Z) * CFrame.Angles(0, yaw, 0) * CFrame.new(0, 0, -10.5)
	for side = -1, 1, 2 do
		block(
			model,
			"ArchPost",
			Vector3.new(1.8, 8, 1.8),
			door * CFrame.new(side * 3, 4, 0),
			style.stone,
			style.stoneColors[2]
		)
	end
	block(
		model,
		"ArchTop",
		Vector3.new(8, 1.6, 2),
		door * CFrame.new(0, 8.6, 0) * CFrame.Angles(0, 0, math.rad(6)),
		style.stone,
		style.stoneColors[3]
	)
	-- ivy creeping over the walls
	for _ = 1, 4 do
		local a = rng:NextNumber(0, math.pi * 2)
		block(
			model,
			"Ivy",
			Vector3.new(2.6, rng:NextNumber(3, 6), 0.3),
			CFrame.new(center.X + math.cos(a) * 9, floorY + 3, center.Z + math.sin(a) * 9)
				* CFrame.Angles(0, -a + math.pi / 2, 0),
			M.Grass,
			rgb(70, 130, 60),
			true
		)
	end
	for _ = 1, 5 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(10, 16)
		local p = Vector3.new(center.X + math.cos(a) * r, 0, center.Z + math.sin(a) * r)
		block(
			model,
			"Rubble",
			Vector3.new(rng:NextNumber(2, 4), rng:NextNumber(1.5, 3), rng:NextNumber(2, 4)),
			CFrame.new(p.X, heightAt(p.X, p.Z) + 0.5, p.Z)
				* CFrame.Angles(rng:NextNumber(0, 1), rng:NextNumber(0, 3), 0),
			style.stone,
			style.stoneColors[1]
		)
	end
	local spots = { { cframe = CFrame.new(center.X, floorY + 1, center.Z), tier = "Shrine" } }
	if rng:NextNumber() < 0.5 then
		table.insert(
			spots,
			{ cframe = CFrame.new(center.X + 4, floorY + 1, center.Z + 3) * CFrame.Angles(0, 2, 0), tier = "Outer" }
		)
	end
	return spots
end

function Landmarks.shrine(
	parent: Instance,
	center: Vector3,
	heightAt: HeightFn,
	rng: Random,
	style: Style
): { ChestSpot }
	local model = landmark(parent, "Shrine")
	local floorY = foundation(model, center, 18, heightAt, style.shrine, style.shrineColor)
	block(
		model,
		"Step",
		Vector3.new(20, 0.8, 20),
		CFrame.new(center.X, floorY - 0.4, center.Z),
		style.shrine,
		style.shrineColor:Lerp(Color3.new(0, 0, 0), 0.12)
	)
	local roofY = floorY + 13
	for _, offset in { Vector3.new(-7, 0, -7), Vector3.new(7, 0, -7), Vector3.new(-7, 0, 7), Vector3.new(7, 0, 7) } do
		local pillar = CFrame.new(center.X + offset.X, floorY + 6.5, center.Z + offset.Z)
		block(model, "Pillar", Vector3.new(2, 13, 2), pillar, style.shrine, style.shrineColor)
		block(
			model,
			"Base",
			Vector3.new(2.8, 1, 2.8),
			pillar * CFrame.new(0, -6, 0),
			style.shrine,
			style.shrineColor:Lerp(Color3.new(0, 0, 0), 0.15)
		)
		block(
			model,
			"Capital",
			Vector3.new(2.8, 1, 2.8),
			pillar * CFrame.new(0, 6, 0),
			style.shrine,
			style.shrineColor:Lerp(Color3.new(0, 0, 0), 0.15)
		)
	end
	block(
		model,
		"Roof",
		Vector3.new(19, 1.5, 19),
		CFrame.new(center.X, roofY + 0.75, center.Z),
		style.shrine,
		style.shrineColor:Lerp(Color3.new(0, 0, 0), 0.08)
	)
	block(
		model,
		"RoofTrim",
		Vector3.new(19.4, 0.5, 19.4),
		CFrame.new(center.X, roofY + 0.1, center.Z),
		M.Neon,
		style.accent,
		true
	)
	block(
		model,
		"RoofTop",
		Vector3.new(12, 1.5, 12),
		CFrame.new(center.X, roofY + 2.25, center.Z),
		style.shrine,
		style.shrineColor
	)
	block(
		model,
		"Altar",
		Vector3.new(5, 2.5, 3),
		CFrame.new(center.X, floorY + 1.25, center.Z - 3),
		style.shrine,
		style.shrineColor:Lerp(Color3.new(0, 0, 0), 0.2)
	)
	local crystal = block(
		model,
		"Crystal",
		Vector3.new(1.6, 3.5, 1.6),
		CFrame.new(center.X, floorY + 6, center.Z - 3) * CFrame.Angles(0, math.rad(45), math.rad(20)),
		M.Neon,
		style.accent:Lerp(Color3.fromHSV(rng:NextNumber(), 0.5, 1), 0.25),
		true
	)
	glow(crystal, crystal.Color, 20, 2)
	-- hanging cloth between the front pillars
	block(
		model,
		"Drape",
		Vector3.new(12, 3, 0.2),
		CFrame.new(center.X, roofY - 1.5, center.Z - 7),
		M.Fabric,
		pick(rng, style.banner),
		true
	)
	return { { cframe = CFrame.new(center.X, floorY + 1, center.Z + 1), tier = "Shrine" } }
end

function Landmarks.camp(parent: Instance, center: Vector3, heightAt: HeightFn, rng: Random, style: Style): { ChestSpot }
	local model = landmark(parent, "Camp")
	local groundY = heightAt(center.X, center.Z)
	for i = 1, 6 do
		local a = i / 6 * math.pi * 2
		block(
			model,
			"FireStone",
			Vector3.new(1.2, 0.8, 1.2),
			CFrame.new(center.X + math.cos(a) * 2, groundY + 0.3, center.Z + math.sin(a) * 2),
			M.Slate,
			rgb(90, 88, 92)
		)
	end
	local fire = Build.part({
		Name = "Campfire",
		Size = Vector3.new(2.6, 0.8, 2.6),
		CFrame = CFrame.new(center.X, groundY + 0.2, center.Z),
		Material = M.Wood,
		Color = style.wood,
		CanCollide = false,
	}, model)
	Build.make("Fire", { Size = 4, Heat = 6 }, fire)
	glow(fire, rgb(255, 160, 80), 22, 2)
	for i = 1, 2 do
		local angle = rng:NextNumber(0, math.pi * 2) + i * math.pi
		local p = Vector3.new(center.X + math.cos(angle) * 9, 0, center.Z + math.sin(angle) * 9)
		local y = heightAt(p.X, p.Z)
		local look = CFrame.lookAt(Vector3.new(p.X, y + 2.5, p.Z), Vector3.new(center.X, y + 2.5, center.Z))
		local canvas = pick(rng, style.banner)
		Build.wedge({
			Name = "Tent",
			Size = Vector3.new(6, 5, 3),
			CFrame = look * CFrame.new(0, 0, -1.5),
			Color = canvas,
			Material = M.Fabric,
		}, model)
		Build.wedge({
			Name = "Tent",
			Size = Vector3.new(6, 5, 3),
			CFrame = look * CFrame.new(0, 0, 1.5) * CFrame.Angles(0, math.pi, 0),
			Color = canvas:Lerp(Color3.new(1, 1, 1), 0.2),
			Material = M.Fabric,
		}, model)
	end
	-- the camp's banner
	local ba = rng:NextNumber(0, math.pi * 2)
	local bp = Vector3.new(center.X + math.cos(ba) * 7, 0, center.Z + math.sin(ba) * 7)
	banner(model, Vector3.new(bp.X, heightAt(bp.X, bp.Z), bp.Z), 9, pick(rng, style.banner), -ba)
	-- log seats around the fire
	for i = 1, 2 do
		local a = rng:NextNumber(0, math.pi * 2) + i * math.pi
		local p = Vector3.new(center.X + math.cos(a) * 4.5, 0, center.Z + math.sin(a) * 4.5)
		Build.part({
			Name = "Seat",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(4, 1.4, 1.4),
			CFrame = CFrame.new(p.X, heightAt(p.X, p.Z) + 0.5, p.Z) * CFrame.Angles(0, -a + math.pi / 2, 0),
			Material = M.Wood,
			Color = style.wood,
		}, model)
	end
	for _ = 1, 3 do
		local a = rng:NextNumber(0, math.pi * 2)
		local p = Vector3.new(center.X + math.cos(a) * 6.5, 0, center.Z + math.sin(a) * 6.5)
		block(
			model,
			"Crate",
			Vector3.new(2.5, 2.5, 2.5),
			CFrame.new(p.X, heightAt(p.X, p.Z) + 1.1, p.Z) * CFrame.Angles(0, rng:NextNumber(0, 3), 0),
			M.WoodPlanks,
			style.wood:Lerp(Color3.new(1, 1, 1), 0.25)
		)
	end
	local chestAngle = rng:NextNumber(0, math.pi * 2)
	local cp = Vector3.new(center.X + math.cos(chestAngle) * 4, 0, center.Z + math.sin(chestAngle) * 4)
	local cy = heightAt(cp.X, cp.Z) + 1
	return {
		{ cframe = CFrame.lookAt(Vector3.new(cp.X, cy, cp.Z), Vector3.new(center.X, cy, center.Z)), tier = "Outer" },
	}
end

function Landmarks.watchtower(
	parent: Instance,
	center: Vector3,
	heightAt: HeightFn,
	rng: Random,
	style: Style
): { ChestSpot }
	local model = landmark(parent, "Watchtower")
	local groundY = heightAt(center.X, center.Z)
	local topY = groundY + 16
	for _, o in { Vector3.new(-4, 0, -4), Vector3.new(4, 0, -4), Vector3.new(-4, 0, 4), Vector3.new(4, 0, 4) } do
		local gy = heightAt(center.X + o.X, center.Z + o.Z)
		local h = topY - gy + 3
		block(
			model,
			"Leg",
			Vector3.new(1.4, h, 1.4),
			CFrame.new(center.X + o.X, gy + h / 2 - 3, center.Z + o.Z),
			M.Wood,
			style.wood
		)
	end
	-- cross braces
	for side = -1, 1, 2 do
		block(
			model,
			"Brace",
			Vector3.new(0.6, 11, 0.6),
			CFrame.new(center.X + side * 4, groundY + 8, center.Z) * CFrame.Angles(math.rad(36), 0, 0),
			M.Wood,
			style.wood
		)
	end
	local planks = style.wood:Lerp(Color3.new(1, 1, 1), 0.2)
	block(model, "Platform", Vector3.new(11, 1, 11), CFrame.new(center.X, topY, center.Z), M.WoodPlanks, planks)
	for _, o in { Vector3.new(0, 0, -5.2), Vector3.new(0, 0, 5.2) } do
		block(
			model,
			"Rail",
			Vector3.new(11, 2.5, 0.6),
			CFrame.new(center.X + o.X, topY + 1.75, center.Z + o.Z),
			M.WoodPlanks,
			planks
		)
	end
	block(
		model,
		"Rail",
		Vector3.new(0.6, 2.5, 11),
		CFrame.new(center.X - 5.2, topY + 1.75, center.Z),
		M.WoodPlanks,
		planks
	)
	-- a peaked roof in the map's colours
	local roofColor = pick(rng, style.banner)
	for _, o in { Vector3.new(-4, 0, -4), Vector3.new(4, 0, -4), Vector3.new(-4, 0, 4), Vector3.new(4, 0, 4) } do
		block(
			model,
			"RoofPost",
			Vector3.new(0.5, 6, 0.5),
			CFrame.new(center.X + o.X, topY + 3.5, center.Z + o.Z),
			M.Wood,
			style.wood
		)
	end
	local roofBase = CFrame.new(center.X, topY + 7.5, center.Z)
	Build.wedge({
		Name = "Roof",
		Size = Vector3.new(12, 3, 6),
		CFrame = roofBase * CFrame.new(0, 0, -3),
		Material = M.Fabric,
		Color = roofColor,
	}, model)
	Build.wedge({
		Name = "Roof",
		Size = Vector3.new(12, 3, 6),
		CFrame = roofBase * CFrame.new(0, 0, 3) * CFrame.Angles(0, math.pi, 0),
		Material = M.Fabric,
		Color = roofColor:Lerp(Color3.new(0, 0, 0), 0.15),
	}, model)
	lantern(model, Vector3.new(center.X + 3.5, topY + 5, center.Z + 3.5))
	local ladderH = topY - groundY + 1
	local truss = Instance.new("TrussPart")
	truss.Anchored = true
	truss.Size = Vector3.new(2, math.max(2, math.floor(ladderH / 2) * 2), 2)
	truss.CFrame = CFrame.new(center.X + 6.6, groundY + truss.Size.Y / 2 - 0.5, center.Z)
	truss.Color = style.wood
	truss.Parent = model
	return {
		{
			cframe = CFrame.new(center.X, topY + 1.5, center.Z) * CFrame.Angles(0, rng:NextNumber(0, 6), 0),
			tier = "Shrine",
		},
	}
end

---------------------------------------------------------------------------
-- Verdant Isle
---------------------------------------------------------------------------

-- an enormous old oak with glowing runes in its bark and lanterns in its branches
function Landmarks.ancientOak(
	parent: Instance,
	center: Vector3,
	heightAt: HeightFn,
	rng: Random,
	_style: Style
): { ChestSpot }
	local model = landmark(parent, "AncientOak")
	local g = heightAt(center.X, center.Z)
	local base = Vector3.new(center.X, g, center.Z)
	local bark = rgb(98, 70, 46)
	block(model, "Trunk", Vector3.new(7, 34, 7), CFrame.new(base + Vector3.new(0, 15, 0)), M.Wood, bark)
	block(
		model,
		"Trunk",
		Vector3.new(7.4, 30, 7.4),
		CFrame.new(base + Vector3.new(0, 13, 0)) * CFrame.Angles(0, math.rad(45), 0),
		M.Wood,
		bark:Lerp(Color3.new(0, 0, 0), 0.1)
	)
	-- roots
	for i = 1, 6 do
		local a = i / 6 * math.pi * 2 + 0.3
		local look =
			CFrame.lookAt(base + Vector3.new(math.cos(a) * 6, 1.5, math.sin(a) * 6), base + Vector3.new(0, 1.5, 0))
		Build.wedge(
			{ Name = "Root", Size = Vector3.new(2.4, 4, 6), CFrame = look, Material = M.Wood, Color = bark },
			model
		)
	end
	-- glowing runes
	for i = 1, 3 do
		local a = i * 2.1
		local rune = block(
			model,
			"Rune",
			Vector3.new(0.3, 2, 1.2),
			CFrame.new(base + Vector3.new(math.cos(a) * 3.9, 6 + i * 3, math.sin(a) * 3.9)) * CFrame.Angles(0, -a, 0),
			M.Neon,
			rgb(150, 255, 170),
			true
		)
		if i == 2 then
			glow(rune, rune.Color, 18, 1.5)
		end
	end
	-- branches and a huge layered canopy
	local greens = { rgb(66, 140, 54), rgb(84, 156, 60), rgb(56, 122, 50), rgb(104, 170, 66) }
	for i = 1, 5 do
		local a = i / 5 * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
		local cf = CFrame.new(base + Vector3.new(0, 22, 0))
			* CFrame.Angles(0, a, 0)
			* CFrame.Angles(0, 0, math.rad(55))
			* CFrame.new(0, 6, 0)
		block(model, "Branch", Vector3.new(2.2, 12, 2.2), cf, M.Wood, bark)
		local tip = cf * CFrame.new(0, 6, 0)
		block(
			model,
			"Leaves",
			Vector3.new(16, 8, 16),
			CFrame.new(tip.Position + Vector3.new(0, 3, 0)) * CFrame.Angles(0, a, 0),
			M.Grass,
			greens[(i % #greens) + 1]
		)
		lantern(model, tip.Position + Vector3.new(0, -3, 0), rgb(255, 210, 120))
	end
	block(model, "Crown", Vector3.new(24, 10, 24), CFrame.new(base + Vector3.new(0, 34, 0)), M.Grass, greens[2])
	block(model, "Crown", Vector3.new(14, 7, 14), CFrame.new(base + Vector3.new(2, 41, -1)), M.Grass, greens[4])
	-- a ring of flowers around the roots
	for i = 1, 12 do
		local a = i / 12 * math.pi * 2
		local p = Vector3.new(center.X + math.cos(a) * 10, 0, center.Z + math.sin(a) * 10)
		block(
			model,
			"Flower",
			Vector3.new(1, 0.5, 1),
			CFrame.new(p.X, heightAt(p.X, p.Z) + 0.6, p.Z),
			M.SmoothPlastic,
			pick(rng, { rgb(250, 210, 70), rgb(240, 90, 120), rgb(170, 110, 240) }),
			true
		)
	end
	local a = rng:NextNumber(0, math.pi * 2)
	local cp = Vector3.new(center.X + math.cos(a) * 6.5, 0, center.Z + math.sin(a) * 6.5)
	local cy = heightAt(cp.X, cp.Z) + 1
	return {
		{
			cframe = CFrame.lookAt(Vector3.new(cp.X, cy, cp.Z), Vector3.new(center.X, cy, center.Z))
				* CFrame.Angles(0, math.pi, 0),
			tier = "Shrine",
		},
	}
end

-- a stone windmill with turning-looking sails, hay bales and a fence
function Landmarks.windmill(
	parent: Instance,
	center: Vector3,
	heightAt: HeightFn,
	rng: Random,
	style: Style
): { ChestSpot }
	local model = landmark(parent, "Windmill")
	local floorY = foundation(model, center, 12, heightAt, M.Cobblestone, rgb(130, 126, 120))
	local y = floorY
	for i, w in { 10, 8.6, 7.2 } do
		local h = 7
		block(
			model,
			"Tower",
			Vector3.new(w, h, w),
			CFrame.new(center.X, y + h / 2, center.Z) * CFrame.Angles(0, i * 0.05, 0),
			M.Brick,
			rgb(214, 204, 186):Lerp(rgb(190, 176, 156), i / 3)
		)
		y += h
	end
	local roof = CFrame.new(center.X, y + 2, center.Z)
	local roofColor = rgb(170, 60, 50)
	Build.wedge({
		Name = "Roof",
		Size = Vector3.new(8.4, 4, 4.2),
		CFrame = roof * CFrame.new(0, 0, -2.1),
		Material = M.WoodPlanks,
		Color = roofColor,
	}, model)
	Build.wedge({
		Name = "Roof",
		Size = Vector3.new(8.4, 4, 4.2),
		CFrame = roof * CFrame.new(0, 0, 2.1) * CFrame.Angles(0, math.pi, 0),
		Material = M.WoodPlanks,
		Color = roofColor:Lerp(Color3.new(0, 0, 0), 0.15),
	}, model)
	-- door and window
	block(
		model,
		"Door",
		Vector3.new(3, 5, 0.4),
		CFrame.new(center.X, floorY + 2.5, center.Z - 5.1),
		M.WoodPlanks,
		style.wood
	)
	local window = block(
		model,
		"Window",
		Vector3.new(1.6, 1.6, 0.3),
		CFrame.new(center.X, y - 4, center.Z - 3.7),
		M.Neon,
		rgb(255, 210, 130),
		true
	)
	glow(window, window.Color, 14, 1)
	-- sails
	local hub = CFrame.new(center.X, y - 2, center.Z - 4.6) * CFrame.Angles(0, 0, rng:NextNumber(0, math.pi / 2))
	block(model, "Hub", Vector3.new(1.4, 1.4, 1.4), hub, M.Wood, style.wood)
	for i = 0, 3 do
		local arm = hub * CFrame.Angles(0, 0, i * math.pi / 2)
		block(model, "SailArm", Vector3.new(0.5, 13, 0.4), arm * CFrame.new(0, 6.5, -0.4), M.Wood, style.wood, true)
		block(
			model,
			"Sail",
			Vector3.new(2.6, 10, 0.15),
			arm * CFrame.new(1.5, 7.5, -0.5),
			M.Fabric,
			rgb(236, 228, 210),
			true
		)
	end
	-- hay bales and a fence
	for _ = 1, 3 do
		local a = rng:NextNumber(0, math.pi * 2)
		local p = Vector3.new(center.X + math.cos(a) * 10, 0, center.Z + math.sin(a) * 10)
		block(
			model,
			"Hay",
			Vector3.new(3, 2, 2),
			CFrame.new(p.X, heightAt(p.X, p.Z) + 1, p.Z) * CFrame.Angles(0, rng:NextNumber(0, 3), 0),
			M.Grass,
			rgb(226, 190, 90)
		)
	end
	for i = 1, 10 do
		local a = i / 14 * math.pi * 2 + 1
		local p = Vector3.new(center.X + math.cos(a) * 14, 0, center.Z + math.sin(a) * 14)
		local gy = heightAt(p.X, p.Z)
		block(model, "FencePost", Vector3.new(0.6, 3, 0.6), CFrame.new(p.X, gy + 1.3, p.Z), M.Wood, style.wood)
		block(
			model,
			"FenceRail",
			Vector3.new(6.4, 0.4, 0.3),
			CFrame.new(p.X, gy + 2, p.Z) * CFrame.Angles(0, -a - math.pi / 2 - 0.22, 0) * CFrame.new(3, 0, 0),
			M.Wood,
			style.wood,
			true
		)
	end
	return {
		{
			cframe = CFrame.new(center.X + 2, floorY + 1, center.Z - 7.4) * CFrame.Angles(0, math.pi, 0),
			tier = "Outer",
		},
	}
end

---------------------------------------------------------------------------
-- Frostpeak
---------------------------------------------------------------------------

-- a cluster of huge glowing ice crystals
function Landmarks.iceSpire(
	parent: Instance,
	center: Vector3,
	heightAt: HeightFn,
	rng: Random,
	style: Style
): { ChestSpot }
	local model = landmark(parent, "IceSpire")
	local g = heightAt(center.X, center.Z)
	local base = Vector3.new(center.X, g, center.Z)
	local main = nil
	for i = 1, 7 do
		local h = if i == 1 then 30 else rng:NextNumber(10, 22)
		local w = h * 0.22
		local a = i * 0.9
		local r = if i == 1 then 0 else rng:NextNumber(4, 8)
		local cf = CFrame.new(base + Vector3.new(math.cos(a) * r, h * 0.4, math.sin(a) * r))
			* CFrame.Angles(
				if i == 1 then 0 else rng:NextNumber(-0.35, 0.35),
				rng:NextNumber(0, 3),
				if i == 1 then 0 else rng:NextNumber(-0.35, 0.35)
			)
		local shard = block(model, "Shard", Vector3.new(w, h, w), cf, M.Ice, rgb(170, 224, 255))
		shard.Transparency = 0.15
		block(
			model,
			"Core",
			Vector3.new(w * 0.35, h * 0.8, w * 0.35),
			cf,
			M.Neon,
			if i % 2 == 0 then style.accent else rgb(190, 140, 255),
			true
		)
		main = main or shard
	end
	glow(main, style.accent, 36, 2.2)
	for _ = 1, 6 do
		local a = rng:NextNumber(0, math.pi * 2)
		local p = Vector3.new(center.X + math.cos(a) * 12, 0, center.Z + math.sin(a) * 12)
		block(
			model,
			"SnowMound",
			Vector3.new(5, 2, 4),
			CFrame.new(p.X, heightAt(p.X, p.Z) + 0.4, p.Z) * CFrame.Angles(0, a, 0),
			M.Snow,
			rgb(240, 246, 255)
		)
	end
	local a = rng:NextNumber(0, math.pi * 2)
	local cp = Vector3.new(center.X + math.cos(a) * 10, 0, center.Z + math.sin(a) * 10)
	local cy = heightAt(cp.X, cp.Z) + 1
	return {
		{ cframe = CFrame.lookAt(Vector3.new(cp.X, cy, cp.Z), Vector3.new(center.X, cy, center.Z)), tier = "Shrine" },
	}
end

-- a log cabin with a smoking chimney and warm windows
function Landmarks.lodge(
	parent: Instance,
	center: Vector3,
	heightAt: HeightFn,
	rng: Random,
	_style: Style
): { ChestSpot }
	local model = landmark(parent, "Lodge")
	local floorY = foundation(model, center, 18, heightAt, M.Slate, rgb(96, 104, 120))
	local yaw = CFrame.new(center.X, floorY, center.Z) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
	local logs = { rgb(116, 80, 52), rgb(100, 68, 44) }
	-- log walls (with a doorway at the front)
	for row = 0, 5 do
		local y = 0.8 + row * 1.5
		for _, side in { { 0, -6, 14, 0 }, { 0, 6, 14, 0 }, { -6.5, 0, 12, 1 }, { 6.5, 0, 12, 1 } } do
			local len = side[3]
			local cf = yaw
				* CFrame.new(side[1], y, side[2])
				* CFrame.Angles(0, if side[4] == 1 then math.pi / 2 else 0, 0)
			if side[2] == -6 and row < 3 then
				-- the doorway
				for s = -1, 1, 2 do
					Build.part({
						Name = "Log",
						Shape = Enum.PartType.Cylinder,
						Size = Vector3.new(5, 1.5, 1.5),
						CFrame = cf * CFrame.new(s * 4.5, 0, 0),
						Material = M.Wood,
						Color = logs[row % 2 + 1],
					}, model)
				end
			else
				Build.part({
					Name = "Log",
					Shape = Enum.PartType.Cylinder,
					Size = Vector3.new(len, 1.5, 1.5),
					CFrame = cf,
					Material = M.Wood,
					Color = logs[row % 2 + 1],
				}, model)
			end
		end
	end
	-- roof with snow on it
	local roof = yaw * CFrame.new(0, 10.5, 0)
	Build.wedge({
		Name = "Roof",
		Size = Vector3.new(16, 4, 7.5),
		CFrame = roof * CFrame.new(0, 0, -3.75),
		Material = M.WoodPlanks,
		Color = rgb(90, 56, 40),
	}, model)
	Build.wedge({
		Name = "Roof",
		Size = Vector3.new(16, 4, 7.5),
		CFrame = roof * CFrame.new(0, 0, 3.75) * CFrame.Angles(0, math.pi, 0),
		Material = M.WoodPlanks,
		Color = rgb(90, 56, 40),
	}, model)
	block(model, "RoofSnow", Vector3.new(16.4, 0.6, 3), roof * CFrame.new(0, 2.1, 0), M.Snow, rgb(244, 248, 255), true)
	-- chimney
	local chimney =
		block(model, "Chimney", Vector3.new(2.2, 9, 2.2), yaw * CFrame.new(5, 10, 2), M.Cobblestone, rgb(120, 116, 112))
	Build.make("Smoke", { Color = rgb(210, 210, 220), Opacity = 0.2, RiseVelocity = 5, Size = 3 }, chimney)
	-- warm windows
	for s = -1, 1, 2 do
		local w = block(
			model,
			"Window",
			Vector3.new(0.3, 1.6, 2),
			yaw * CFrame.new(s * 6.6, 4.5, 0),
			M.Neon,
			rgb(255, 190, 110),
			true
		)
		if s == 1 then
			glow(w, w.Color, 16, 1.5)
		end
	end
	lantern(model, (yaw * CFrame.new(2.8, 5.5, -7)).Position)
	-- woodpile
	for i = 0, 2 do
		Build.part({
			Name = "Firewood",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(3, 1, 1),
			CFrame = yaw * CFrame.new(-8.5, 0.6 + i * 0.9, -2 + i * 0.4),
			Material = M.Wood,
			Color = rgb(150, 110, 70),
		}, model)
	end
	return { { cframe = yaw * CFrame.new(0, 1, 2), tier = "Outer" } }
end

---------------------------------------------------------------------------
-- Ashen Wastes
---------------------------------------------------------------------------

-- a dwarven forge: a hearth, an anvil, a channel of lava and a smoking chimney
function Landmarks.forge(
	parent: Instance,
	center: Vector3,
	heightAt: HeightFn,
	rng: Random,
	style: Style
): { ChestSpot }
	local model = landmark(parent, "Forge")
	local floorY = foundation(model, center, 20, heightAt, M.Cobblestone, rgb(70, 62, 62))
	local yaw = CFrame.new(center.X, floorY, center.Z) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
	local stone = rgb(84, 74, 72)
	-- back wall and hearth
	block(model, "Wall", Vector3.new(16, 10, 2), yaw * CFrame.new(0, 5, 7), M.Brick, stone)
	block(model, "Hearth", Vector3.new(7, 5, 4), yaw * CFrame.new(-3, 2.5, 4.5), M.Brick, rgb(70, 60, 58))
	local coals =
		block(model, "Coals", Vector3.new(5, 0.6, 2.6), yaw * CFrame.new(-3, 5.1, 4.2), M.Neon, rgb(255, 110, 30), true)
	Build.make("Fire", { Size = 5, Heat = 8, Color = rgb(255, 130, 40), SecondaryColor = rgb(255, 60, 20) }, coals)
	glow(coals, rgb(255, 120, 40), 26, 2.5)
	local chimney = block(model, "Chimney", Vector3.new(3.4, 14, 3.4), yaw * CFrame.new(-3, 14, 6.5), M.Brick, stone)
	Build.make("Smoke", { Color = rgb(60, 56, 56), Opacity = 0.3, RiseVelocity = 8, Size = 5 }, chimney)
	-- lava channel across the floor
	block(model, "Channel", Vector3.new(16, 0.3, 1.6), yaw * CFrame.new(0, 0.2, 1), M.Neon, rgb(255, 100, 24), true)
	-- anvil
	block(model, "AnvilBase", Vector3.new(1.6, 2.4, 1.6), yaw * CFrame.new(3.5, 1.2, -2), M.Metal, rgb(50, 50, 56))
	block(model, "Anvil", Vector3.new(3.6, 1, 1.6), yaw * CFrame.new(3.5, 2.8, -2), M.Metal, rgb(64, 64, 72))
	-- weapon rack with glowing blades
	for i = -1, 1 do
		block(
			model,
			"Blade",
			Vector3.new(0.3, 4, 0.8),
			yaw * CFrame.new(5 + i * 1.3, 3, 5.6) * CFrame.Angles(0, 0, 0.1 * i),
			M.Metal,
			rgb(170, 170, 180)
		)
		block(
			model,
			"Rune",
			Vector3.new(0.35, 1.6, 0.3),
			yaw * CFrame.new(5 + i * 1.3, 3.3, 5.5),
			M.Neon,
			style.accent,
			true
		)
	end
	-- pillars
	for s = -1, 1, 2 do
		block(model, "Pillar", Vector3.new(2, 11, 2), yaw * CFrame.new(s * 8, 5.5, -7), M.Brick, stone)
		local brazier = block(
			model,
			"Brazier",
			Vector3.new(2.6, 0.8, 2.6),
			yaw * CFrame.new(s * 8, 11.4, -7),
			M.Metal,
			rgb(50, 44, 44)
		)
		Build.make("Fire", { Size = 3, Heat = 6 }, brazier)
	end
	return { { cframe = yaw * CFrame.new(0, 1, -1) * CFrame.Angles(0, math.pi, 0), tier = "Shrine" } }
end

-- a tall gate of black glass with a burning crystal floating inside it
function Landmarks.obsidianGate(
	parent: Instance,
	center: Vector3,
	heightAt: HeightFn,
	rng: Random,
	style: Style
): { ChestSpot }
	local model = landmark(parent, "ObsidianGate")
	local floorY = foundation(model, center, 16, heightAt, M.Basalt, rgb(40, 36, 40))
	local yaw = CFrame.new(center.X, floorY, center.Z) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
	local glass = rgb(24, 18, 30)
	for s = -1, 1, 2 do
		block(model, "Pillar", Vector3.new(3, 22, 3), yaw * CFrame.new(s * 6, 11, 0), M.Glass, glass)
		block(model, "Seam", Vector3.new(3.1, 18, 0.4), yaw * CFrame.new(s * 6, 11, 0), M.Neon, style.accent, true)
	end
	block(model, "Lintel", Vector3.new(17, 3, 3.4), yaw * CFrame.new(0, 23.5, 0), M.Glass, glass)
	block(model, "Lintel", Vector3.new(11, 2, 3), yaw * CFrame.new(0, 26, 0), M.Glass, glass)
	local crystal = block(
		model,
		"Crystal",
		Vector3.new(2.4, 5, 2.4),
		yaw * CFrame.new(0, 13, 0) * CFrame.Angles(0, math.rad(45), math.rad(15)),
		M.Neon,
		rgb(255, 80, 40),
		true
	)
	glow(crystal, rgb(255, 90, 40), 32, 2.5)
	Build.make("ParticleEmitter", {
		Color = ColorSequence.new(rgb(255, 160, 60), rgb(255, 60, 30)),
		LightEmission = 1,
		Size = NumberSequence.new(0.5, 0),
		Lifetime = NumberRange.new(1, 2),
		Rate = 14,
		Speed = NumberRange.new(1, 3),
		SpreadAngle = Vector2.new(180, 180),
	}, crystal)
	for i = 1, 6 do
		local a = i / 6 * math.pi * 2
		block(
			model,
			"Spike",
			Vector3.new(1.2, rng:NextNumber(3, 6), 1.2),
			yaw
				* CFrame.new(math.cos(a) * 9, 1.5, math.sin(a) * 9)
				* CFrame.Angles(rng:NextNumber(-0.3, 0.3), 0, rng:NextNumber(-0.3, 0.3)),
			M.Glass,
			glass
		)
	end
	return { { cframe = yaw * CFrame.new(0, 1, 3), tier = "Shrine" } }
end

---------------------------------------------------------------------------
-- Sandsea Ruins
---------------------------------------------------------------------------

-- a stepped pyramid with ramps up the front and a golden capstone; the chest waits at the top
function Landmarks.pyramid(
	parent: Instance,
	center: Vector3,
	heightAt: HeightFn,
	rng: Random,
	style: Style
): { ChestSpot }
	local model = landmark(parent, "Pyramid")
	local floorY = foundation(model, center, 34, heightAt, style.floor, style.floorColor)
	local face = rng:NextNumber(0, math.pi * 2)
	local yaw = CFrame.new(center.X, floorY, center.Z) * CFrame.Angles(0, face, 0)
	local y = 0
	local w = 30
	local colors = { rgb(222, 186, 132), rgb(208, 168, 116), rgb(230, 198, 148), rgb(196, 156, 106) }
	for i = 1, 4 do
		local h = 4.5
		block(model, "Tier", Vector3.new(w, h, w), yaw * CFrame.new(0, y + h / 2, 0), M.Sandstone, colors[i])
		block(
			model,
			"Band",
			Vector3.new(w + 0.2, 0.6, w + 0.2),
			yaw * CFrame.new(0, y + h - 0.6, 0),
			M.Sandstone,
			rgb(40, 130, 160),
			true
		)
		-- a ramp up the front of each tier (its tall end against the tier)
		Build.wedge({
			Name = "Ramp",
			Size = Vector3.new(6, h, 6),
			CFrame = yaw * CFrame.new(0, y + h / 2, -w / 2 - 3) * CFrame.Angles(0, math.pi, 0),
			Material = M.Sandstone,
			Color = colors[i]:Lerp(Color3.new(1, 1, 1), 0.15),
		}, model)
		y += h
		w -= 7
	end
	local cap = block(
		model,
		"Capstone",
		Vector3.new(3, 3, 3),
		yaw * CFrame.new(0, y + 1.5, 3.5) * CFrame.Angles(0, math.rad(45), 0),
		M.Neon,
		rgb(255, 200, 60),
		true
	)
	glow(cap, cap.Color, 30, 2)
	-- statues by the entrance
	for s = -1, 1, 2 do
		block(
			model,
			"Statue",
			Vector3.new(2.4, 7, 2.4),
			yaw * CFrame.new(s * 7, 3.5, -19),
			M.Sandstone,
			rgb(214, 180, 124)
		)
		block(
			model,
			"Head",
			Vector3.new(2.6, 2.4, 3),
			yaw * CFrame.new(s * 7, 8.2, -19.2),
			M.Sandstone,
			rgb(40, 130, 160)
		)
	end
	return { { cframe = yaw * CFrame.new(0, y + 1, -1) * CFrame.Angles(0, math.pi, 0), tier = "Shrine" } }
end

-- a little market of striped awnings, rugs and pots
function Landmarks.bazaar(
	parent: Instance,
	center: Vector3,
	heightAt: HeightFn,
	rng: Random,
	style: Style
): { ChestSpot }
	local model = landmark(parent, "Bazaar")
	local floorY = foundation(model, center, 24, heightAt, M.Sandstone, rgb(214, 178, 128))
	local spots: { ChestSpot } = {}
	for i = 1, 4 do
		local a = i / 4 * math.pi * 2 + 0.4
		local stall = CFrame.new(center.X + math.cos(a) * 7.5, floorY, center.Z + math.sin(a) * 7.5)
			* CFrame.Angles(0, -a - math.pi / 2, 0)
		local c1 = style.banner[(i - 1) % #style.banner + 1]
		local c2 = rgb(246, 236, 214)
		for _, o in { { -3, -2 }, { 3, -2 }, { -3, 2 }, { 3, 2 } } do
			block(model, "Post", Vector3.new(0.5, 7, 0.5), stall * CFrame.new(o[1], 3.5, o[2]), M.Wood, style.wood)
		end
		-- striped awning
		for s = 0, 5 do
			block(
				model,
				"Awning",
				Vector3.new(1.1, 0.25, 5.6),
				stall * CFrame.new(-2.75 + s * 1.1, 7.2, 0) * CFrame.Angles(math.rad(8), 0, 0),
				M.Fabric,
				if s % 2 == 0 then c1 else c2,
				true
			)
		end
		block(model, "Counter", Vector3.new(6, 2.6, 1.4), stall * CFrame.new(0, 1.3, 2.4), M.WoodPlanks, style.wood)
		block(
			model,
			"Rug",
			Vector3.new(5, 0.1, 3.6),
			stall * CFrame.new(0, 0.1, -0.3),
			M.Fabric,
			pick(rng, style.banner):Lerp(rgb(120, 30, 40), 0.3),
			true
		)
		for k = -1, 1 do
			Build.part({
				Name = "Pot",
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(1.2, 1.2, 1.2),
				CFrame = stall * CFrame.new(k * 1.8, 3.2, 2.4),
				Material = M.SmoothPlastic,
				Color = pick(rng, { rgb(190, 96, 56), rgb(40, 110, 170), rgb(40, 160, 160), rgb(240, 190, 60) }),
			}, model)
		end
		if i == 1 then
			table.insert(spots, { cframe = stall * CFrame.new(0, 1, -0.5), tier = "Outer" })
		end
	end
	-- a well in the middle
	Build.cylinder(
		Vector3.new(center.X, floorY + 1.2, center.Z),
		5,
		2.4,
		{ Name = "Well", Material = M.Sandstone, Color = rgb(200, 160, 110) },
		model
	)
	Build.cylinder(
		Vector3.new(center.X, floorY + 2.45, center.Z),
		3.8,
		0.2,
		{ Name = "WellWater", Material = M.Glass, Color = rgb(40, 160, 170) },
		model
	)
	if rng:NextNumber() < 0.4 then
		table.insert(spots, { cframe = CFrame.new(center.X + 3.6, floorY + 1, center.Z + 3.6), tier = "Shrine" })
	end
	return spots
end

---------------------------------------------------------------------------
-- Fungal Hollow
---------------------------------------------------------------------------

-- a ring of glowing mushrooms with sparkles drifting inside it
function Landmarks.fairyRing(
	parent: Instance,
	center: Vector3,
	heightAt: HeightFn,
	rng: Random,
	style: Style
): { ChestSpot }
	local model = landmark(parent, "FairyRing")
	local colors = { rgb(90, 255, 220), rgb(220, 120, 255), rgb(255, 130, 210) }
	for i = 1, 12 do
		local a = i / 12 * math.pi * 2
		local p = Vector3.new(center.X + math.cos(a) * 9, 0, center.Z + math.sin(a) * 9)
		local g = heightAt(p.X, p.Z)
		local h = rng:NextNumber(2, 4.5)
		block(
			model,
			"Stem",
			Vector3.new(0.8, h, 0.8),
			CFrame.new(p.X, g + h / 2, p.Z),
			M.SmoothPlastic,
			rgb(236, 228, 214)
		)
		local cap = block(
			model,
			"Cap",
			Vector3.new(2.8, 0.9, 2.8),
			CFrame.new(p.X, g + h + 0.3, p.Z) * CFrame.Angles(0, a, 0),
			M.Neon,
			colors[i % #colors + 1],
			true
		)
		if i % 4 == 0 then
			glow(cap, cap.Color, 16, 1.4)
		end
	end
	local g = heightAt(center.X, center.Z)
	local stone = block(
		model,
		"Stone",
		Vector3.new(2.4, 5, 1.4),
		CFrame.new(center.X, g + 2.2, center.Z - 3),
		M.Slate,
		rgb(80, 86, 96)
	)
	block(model, "Rune", Vector3.new(1, 1.6, 0.2), stone.CFrame * CFrame.new(0, 0.6, -0.75), M.Neon, style.accent, true)
	local motes = Build.part({
		Name = "Motes",
		Size = Vector3.new(14, 6, 14),
		CFrame = CFrame.new(center.X, g + 4, center.Z),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
	}, model)
	Build.make("ParticleEmitter", {
		Color = ColorSequence.new(rgb(140, 255, 230), rgb(230, 150, 255)),
		LightEmission = 1,
		LightInfluence = 0,
		Size = NumberSequence.new(0.3, 0),
		Lifetime = NumberRange.new(2, 4),
		Rate = 12,
		Speed = NumberRange.new(0.5, 1.5),
		SpreadAngle = Vector2.new(180, 180),
	}, motes)
	return { { cframe = CFrame.new(center.X, g + 1, center.Z + 1), tier = "Shrine" } }
end

-- the hollow stump of a giant tree, lived in by something with a lantern
function Landmarks.stump(
	parent: Instance,
	center: Vector3,
	heightAt: HeightFn,
	rng: Random,
	style: Style
): { ChestSpot }
	local model = landmark(parent, "Stump")
	local g = heightAt(center.X, center.Z)
	local bark = rgb(84, 62, 58)
	local n = 12
	local r = 7
	local doorAt = rng:NextInteger(1, n)
	for i = 1, n do
		local a = i / n * math.pi * 2
		local h = rng:NextNumber(10, 15)
		local pos = Vector3.new(center.X + math.cos(a) * r, g + h / 2 - 1, center.Z + math.sin(a) * r)
		if i == doorAt then
			-- the doorway: a short piece above an opening
			block(
				model,
				"Bark",
				Vector3.new(4, 4, 2.2),
				CFrame.lookAt(Vector3.new(pos.X, g + h - 3, pos.Z), Vector3.new(center.X, g + h - 3, center.Z)),
				M.Wood,
				bark
			)
			lantern(
				model,
				Vector3.new(center.X + math.cos(a) * (r + 1.8), g + 5, center.Z + math.sin(a) * (r + 1.8)),
				rgb(170, 255, 200)
			)
		else
			block(
				model,
				"Bark",
				Vector3.new(4, h, 2.2),
				CFrame.lookAt(pos, Vector3.new(center.X, pos.Y, center.Z)),
				M.Wood,
				if i % 2 == 0 then bark else bark:Lerp(Color3.new(0, 0, 0), 0.12)
			)
		end
		-- shelf fungi on the outside
		if i % 3 == 0 then
			local f = block(
				model,
				"Fungus",
				Vector3.new(3, 0.4, 2),
				CFrame.new(
					center.X + math.cos(a) * (r + 1.6),
					g + rng:NextNumber(4, 9),
					center.Z + math.sin(a) * (r + 1.6)
				) * CFrame.Angles(0, -a, 0),
				M.Neon,
				style.accent,
				true
			)
			if i == 6 then
				glow(f, f.Color, 18, 1.4)
			end
		end
		-- roots
		local look = CFrame.lookAt(
			Vector3.new(center.X + math.cos(a) * (r + 2.5), g + 1, center.Z + math.sin(a) * (r + 2.5)),
			Vector3.new(center.X, g + 1, center.Z)
		)
		if i % 2 == 1 and i ~= doorAt then
			Build.wedge({
				Name = "Root",
				Size = Vector3.new(2, 3, 4),
				CFrame = look * CFrame.new(0, 0.4, 0.5),
				Material = M.Wood,
				Color = bark,
			}, model)
		end
	end
	Build.cylinder(
		Vector3.new(center.X, g + 0.2, center.Z),
		13,
		0.6,
		{ Name = "Floor", Material = M.Grass, Color = rgb(60, 110, 100) },
		model
	)
	return { { cframe = CFrame.new(center.X, g + 1, center.Z), tier = "Shrine" } }
end

---------------------------------------------------------------------------
-- The battle royale's named locations: villages, a town, castles, and bigger versions of the
-- realms' own landmarks. Cottage and tower chests are "House" tier; the best loot is "Shrine".
---------------------------------------------------------------------------

local PLASTER = { rgb(232, 222, 200), rgb(222, 208, 182), rgb(236, 230, 214), rgb(214, 198, 176) }

-- A half-timbered cottage on its own little foundation, door facing `facing` (a point).
-- Returns a chest spot inside it.
local function cottage(
	parent: Instance,
	at: Vector3,
	facing: Vector3,
	heightAt: HeightFn,
	rng: Random,
	style: Style
): ChestSpot
	local model = Build.model("Cottage", parent)
	local w, d, wallH = rng:NextNumber(11, 14), rng:NextNumber(9, 11), 7.5
	local floorY =
		foundation(model, Vector3.new(at.X, 0, at.Z), math.max(w, d) + 2, heightAt, style.floor, style.floorColor)
	local base = CFrame.lookAt(Vector3.new(at.X, floorY, at.Z), Vector3.new(facing.X, floorY, facing.Z))
	local plaster = pick(rng, PLASTER)
	local beam = style.wood:Lerp(Color3.new(0, 0, 0), 0.2)
	-- walls: back, sides, and a front with a doorway (the front faces -Z, toward `facing`)
	block(model, "Wall", Vector3.new(w, wallH, 1), base * CFrame.new(0, wallH / 2, d / 2), M.SmoothPlastic, plaster)
	for side = -1, 1, 2 do
		block(
			model,
			"Wall",
			Vector3.new(1, wallH, d),
			base * CFrame.new(side * w / 2, wallH / 2, 0),
			M.SmoothPlastic,
			plaster
		)
		local seg = (w - 4) / 2
		block(
			model,
			"Wall",
			Vector3.new(seg, wallH, 1),
			base * CFrame.new(side * (2 + seg / 2), wallH / 2, -d / 2),
			M.SmoothPlastic,
			plaster
		)
		local window = block(
			model,
			"Window",
			Vector3.new(0.3, 2, 2.4),
			base * CFrame.new(side * (w / 2 + 0.1), wallH * 0.55, 0),
			M.Neon,
			rgb(255, 214, 140),
			true
		)
		if side == 1 and rng:NextNumber() < 0.5 then
			glow(window, window.Color, 14, 1)
		end
	end
	block(
		model,
		"Lintel",
		Vector3.new(4.4, wallH - 5.5, 1),
		base * CFrame.new(0, 5.5 + (wallH - 5.5) / 2, -d / 2),
		M.SmoothPlastic,
		plaster
	)
	-- timber frame
	for _, c in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
		block(
			model,
			"Beam",
			Vector3.new(0.8, wallH, 0.8),
			base * CFrame.new(c[1] * w / 2, wallH / 2, c[2] * d / 2),
			M.Wood,
			beam
		)
	end
	block(model, "Beam", Vector3.new(w + 0.6, 0.6, d + 0.6), base * CFrame.new(0, wallH, 0), M.Wood, beam)
	-- a pitched roof in one of the realm's colours
	local roofColor = pick(rng, style.banner):Lerp(rgb(90, 60, 50), 0.35)
	local roof = base * CFrame.new(0, wallH + 2.2, 0) * CFrame.Angles(0, math.pi / 2, 0)
	Build.wedge({
		Name = "Roof",
		Size = Vector3.new(d + 1.6, 4.4, w / 2 + 0.8),
		CFrame = roof * CFrame.new(0, 0, -(w / 4 + 0.4)),
		Material = M.Slate,
		Color = roofColor,
	}, model)
	Build.wedge({
		Name = "Roof",
		Size = Vector3.new(d + 1.6, 4.4, w / 2 + 0.8),
		CFrame = roof * CFrame.new(0, 0, w / 4 + 0.4) * CFrame.Angles(0, math.pi, 0),
		Material = M.Slate,
		Color = roofColor:Lerp(Color3.new(0, 0, 0), 0.12),
	}, model)
	if rng:NextNumber() < 0.5 then
		local chimney = block(
			model,
			"Chimney",
			Vector3.new(1.8, 5, 1.8),
			base * CFrame.new(w / 2 - 2, wallH + 3, d / 4),
			M.Brick,
			rgb(140, 90, 70)
		)
		Build.make("Smoke", { Color = rgb(220, 220, 225), Opacity = 0.15, RiseVelocity = 4, Size = 2.5 }, chimney)
	end
	return {
		cframe = base * CFrame.new(rng:NextNumber(-w / 4, w / 4), 1, d / 2 - 2) * CFrame.Angles(0, math.pi, 0),
		tier = "House",
	}
end

local function well(parent: Instance, at: Vector3, heightAt: HeightFn, style: Style)
	local model = Build.model("Well", parent)
	local g = heightAt(at.X, at.Z)
	Build.cylinder(
		Vector3.new(at.X, g + 1.2, at.Z),
		6,
		2.4,
		{ Name = "Well", Material = style.stone, Color = style.stoneColors[1] },
		model
	)
	Build.cylinder(
		Vector3.new(at.X, g + 2.45, at.Z),
		4.6,
		0.2,
		{ Name = "Water", Material = M.Glass, Color = rgb(60, 150, 200) },
		model
	)
	for side = -1, 1, 2 do
		block(model, "Post", Vector3.new(0.6, 5, 0.6), CFrame.new(at.X + side * 2.6, g + 4, at.Z), M.Wood, style.wood)
	end
	Build.wedge({
		Name = "WellRoof",
		Size = Vector3.new(7, 1.6, 3),
		CFrame = CFrame.new(at.X, g + 7.2, at.Z - 1.5),
		Material = M.WoodPlanks,
		Color = style.wood,
	}, model)
	Build.wedge({
		Name = "WellRoof",
		Size = Vector3.new(7, 1.6, 3),
		CFrame = CFrame.new(at.X, g + 7.2, at.Z + 1.5) * CFrame.Angles(0, math.pi, 0),
		Material = M.WoodPlanks,
		Color = style.wood,
	}, model)
end

local function ring(count: number, radius: number, rng: Random, center: Vector3): { Vector3 }
	local out = {}
	local start = rng:NextNumber(0, math.pi * 2)
	for i = 1, count do
		local a = start + (i / count) * math.pi * 2 + rng:NextNumber(-0.15, 0.15)
		local r = radius + rng:NextNumber(-3, 3)
		table.insert(out, Vector3.new(center.X + math.cos(a) * r, 0, center.Z + math.sin(a) * r))
	end
	return out
end

-- A village: cottages around a square with a well and a market stall.
function Landmarks.village(
	parent: Instance,
	center: Vector3,
	heightAt: HeightFn,
	rng: Random,
	style: Style
): { ChestSpot }
	local model = landmark(parent, "Village")
	local spots: { ChestSpot } = {}
	for i, p in ring(6, 26, rng, center) do
		local spot = cottage(model, p, center, heightAt, rng, style)
		if i % 2 == 1 then
			table.insert(spots, spot)
		end
	end
	well(model, center, heightAt, style)
	for i = 1, 4 do
		local a = i / 4 * math.pi * 2 + 0.4
		local p = Vector3.new(center.X + math.cos(a) * 12, 0, center.Z + math.sin(a) * 12)
		lantern(model, Vector3.new(p.X, heightAt(p.X, p.Z) + 4, p.Z))
		block(
			model,
			"LampPost",
			Vector3.new(0.5, 4, 0.5),
			CFrame.new(p.X, heightAt(p.X, p.Z) + 2, p.Z),
			M.Metal,
			rgb(50, 44, 40)
		)
	end
	local g = heightAt(center.X + 7, center.Z + 7)
	table.insert(spots, { cframe = CFrame.new(center.X + 7, g + 1, center.Z + 7), tier = "Shrine" })
	return spots
end

-- The island's biggest town, in the middle: a ring of cottages, a market and a mage's tower.
function Landmarks.town(parent: Instance, center: Vector3, heightAt: HeightFn, rng: Random, style: Style): { ChestSpot }
	local model = landmark(parent, "Town")
	local spots: { ChestSpot } = {}
	for i, p in ring(9, 44, rng, center) do
		local spot = cottage(model, p, center, heightAt, rng, style)
		if i % 2 == 0 then
			table.insert(spots, spot)
		end
	end
	-- the mage's tower: the best loot is at the top
	local g = heightAt(center.X, center.Z)
	local tower = CFrame.new(center.X, g, center.Z)
	Build.cylinder(
		tower.Position + Vector3.new(0, 9, 0),
		12,
		18,
		{ Name = "Tower", Material = style.stone, Color = style.stoneColors[1] },
		model
	)
	Build.cylinder(
		tower.Position + Vector3.new(0, 18.6, 0),
		14,
		1.2,
		{ Name = "TowerTop", Material = style.stone, Color = style.stoneColors[2] },
		model
	)
	for i = 1, 10 do
		local a = i / 10 * math.pi * 2
		block(
			model,
			"Merlon",
			Vector3.new(2, 2.4, 1.4),
			tower * CFrame.new(math.cos(a) * 6.4, 20.4, math.sin(a) * 6.4) * CFrame.Angles(0, -a, 0),
			style.stone,
			style.stoneColors[2]
		)
	end
	local orb = block(
		model,
		"Orb",
		Vector3.new(3, 3, 3),
		tower * CFrame.new(0, 26, 0) * CFrame.Angles(math.rad(45), 0, math.rad(45)),
		M.Neon,
		style.accent,
		true
	)
	glow(orb, style.accent, 40, 2.5)
	-- a spiral of steps up the outside
	for i = 0, 15 do
		local a = i * 0.42
		block(
			model,
			"Step",
			Vector3.new(4, 0.8, 3),
			tower * CFrame.Angles(0, a, 0) * CFrame.new(0, 1 + i * 1.15, -7.4),
			style.stone,
			style.stoneColors[3]
		)
	end
	table.insert(spots, { cframe = tower * CFrame.new(2, 20.2, 2), tier = "Shrine" })
	-- market stalls and benches around the square
	for i = 1, 3 do
		local a = i / 3 * math.pi * 2 + 0.6
		local p = Vector3.new(center.X + math.cos(a) * 22, 0, center.Z + math.sin(a) * 22)
		local gy = heightAt(p.X, p.Z)
		local stall = CFrame.lookAt(Vector3.new(p.X, gy, p.Z), Vector3.new(center.X, gy, center.Z))
		local c1 = style.banner[(i - 1) % #style.banner + 1]
		for _, o in { { -2.5, -1.5 }, { 2.5, -1.5 }, { -2.5, 1.5 }, { 2.5, 1.5 } } do
			block(model, "Post", Vector3.new(0.4, 6, 0.4), stall * CFrame.new(o[1], 3, o[2]), M.Wood, style.wood)
		end
		for k = 0, 4 do
			block(
				model,
				"Awning",
				Vector3.new(1.1, 0.25, 4),
				stall * CFrame.new(-2.2 + k * 1.1, 6.2, 0),
				M.Fabric,
				if k % 2 == 0 then c1 else rgb(246, 236, 214),
				true
			)
		end
		block(model, "Counter", Vector3.new(5, 2.4, 1.2), stall * CFrame.new(0, 1.2, -1.8), M.WoodPlanks, style.wood)
	end
	for i = 1, 6 do
		local a = i / 6 * math.pi * 2
		local p = Vector3.new(center.X + math.cos(a) * 33, 0, center.Z + math.sin(a) * 33)
		lantern(model, Vector3.new(p.X, heightAt(p.X, p.Z) + 5, p.Z))
		block(
			model,
			"LampPost",
			Vector3.new(0.5, 5, 0.5),
			CFrame.new(p.X, heightAt(p.X, p.Z) + 2.5, p.Z),
			M.Metal,
			rgb(50, 44, 40)
		)
	end
	return spots
end

-- A castle: curtain walls with a gate, four round towers and a keep in the courtyard.
function Landmarks.castle(
	parent: Instance,
	center: Vector3,
	heightAt: HeightFn,
	rng: Random,
	style: Style
): { ChestSpot }
	local model = landmark(parent, "Castle")
	local floorY = foundation(model, center, 46, heightAt, style.floor, style.floorColor)
	local yaw = CFrame.new(center.X, floorY, center.Z) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
	local S = 20 -- half the wall length
	local wallH = 12
	local stone = style.stoneColors
	for side = 0, 3 do
		local wall = yaw * CFrame.Angles(0, side * math.pi / 2, 0) * CFrame.new(0, 0, -S)
		if side == 0 then
			-- the gate side: two pieces and an arch
			for k = -1, 1, 2 do
				block(
					model,
					"Wall",
					Vector3.new(S - 4, wallH, 3),
					wall * CFrame.new(k * (S + 4) / 2, wallH / 2, 0),
					style.stone,
					stone[1]
				)
			end
			block(model, "Gatehouse", Vector3.new(10, 4, 4), wall * CFrame.new(0, wallH - 2, 0), style.stone, stone[2])
			block(
				model,
				"Portcullis",
				Vector3.new(7.6, 0.5, 0.4),
				wall * CFrame.new(0, wallH - 4.3, -1.4),
				M.Metal,
				rgb(50, 46, 44),
				true
			)
		else
			block(
				model,
				"Wall",
				Vector3.new(S * 2, wallH, 3),
				wall * CFrame.new(0, wallH / 2, 0),
				style.stone,
				stone[(side % #stone) + 1]
			)
		end
		for i = 0, 9 do
			block(
				model,
				"Merlon",
				Vector3.new(2, 2.2, 3.2),
				wall * CFrame.new(-S + 2 + i * 4, wallH + 1.1, -0.1),
				style.stone,
				stone[2]
			)
		end
		block(
			model,
			"Walkway",
			Vector3.new(S * 2, 1, 3),
			wall * CFrame.new(0, wallH - 0.5, 2.6),
			M.WoodPlanks,
			style.wood
		)
	end
	-- round towers on the corners, flying the realm's banner
	for i, c in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
		local at = (yaw * CFrame.new(c[1] * S, 0, c[2] * S)).Position
		Build.cylinder(
			at + Vector3.new(0, 9, 0),
			9,
			18,
			{ Name = "Tower", Material = style.stone, Color = stone[(i % #stone) + 1] },
			model
		)
		Build.cylinder(
			at + Vector3.new(0, 18.6, 0),
			10.5,
			1.2,
			{ Name = "TowerTop", Material = style.stone, Color = stone[2] },
			model
		)
		banner(model, at + Vector3.new(0, 19, 0), 8, style.banner[(i - 1) % #style.banner + 1], i)
	end
	-- the keep, with a ramp up to its roof
	local keep = yaw * CFrame.new(0, 0, 6)
	block(model, "Keep", Vector3.new(14, 14, 12), keep * CFrame.new(0, 7, 0), style.stone, stone[3])
	block(model, "KeepDoor", Vector3.new(4, 6, 0.6), keep * CFrame.new(0, 3, -6.1), M.WoodPlanks, style.wood, true)
	Build.wedge({
		Name = "Ramp",
		Size = Vector3.new(4, 14, 18),
		CFrame = keep * CFrame.new(-9, 7, 3) * CFrame.Angles(0, math.pi, 0),
		Material = style.stone,
		Color = stone[1],
	}, model)
	for i = 0, 5 do
		block(model, "Merlon", Vector3.new(2, 2, 1), keep * CFrame.new(-6 + i * 2.4, 15, -5.6), style.stone, stone[2])
	end
	local brazier =
		block(model, "Brazier", Vector3.new(2.4, 1, 2.4), keep * CFrame.new(4, 14.5, 3), M.Metal, rgb(60, 52, 46))
	Build.make("Fire", { Size = 4, Heat = 7 }, brazier)
	glow(brazier, rgb(255, 160, 80), 26, 2)
	return {
		{ cframe = keep * CFrame.new(0, 15, 2), tier = "Shrine" },
		{ cframe = yaw * CFrame.new(-14, 1, -12), tier = "House" },
		{ cframe = yaw * CFrame.new(14, 1, -12) * CFrame.Angles(0, math.pi, 0), tier = "House" },
	}
end

local function merge(into: { ChestSpot }, more: { ChestSpot })
	for _, spot in more do
		table.insert(into, spot)
	end
end

local function offset(center: Vector3, angle: number, distance: number): Vector3
	return Vector3.new(center.X + math.cos(angle) * distance, 0, center.Z + math.sin(angle) * distance)
end

-- The Ashlands' forge-town: the dwarven forge, an obsidian gate and smoking vents around them.
function Landmarks.cinderforge(
	parent: Instance,
	center: Vector3,
	heightAt: HeightFn,
	rng: Random,
	style: Style
): { ChestSpot }
	local spots = Landmarks.forge(parent, center, heightAt, rng, style)
	local a = rng:NextNumber(0, math.pi * 2)
	merge(spots, Landmarks.obsidianGate(parent, offset(center, a, 32), heightAt, rng, style))
	merge(spots, Landmarks.camp(parent, offset(center, a + 2.4, 30), heightAt, rng, style))
	return spots
end

-- The desert's market town: the bazaar, a step pyramid behind it and palms around a pool.
function Landmarks.oasisTown(
	parent: Instance,
	center: Vector3,
	heightAt: HeightFn,
	rng: Random,
	style: Style
): { ChestSpot }
	local spots = Landmarks.bazaar(parent, center, heightAt, rng, style)
	local a = rng:NextNumber(0, math.pi * 2)
	merge(spots, Landmarks.pyramid(parent, offset(center, a, 44), heightAt, rng, style))
	for _, p in ring(3, 22, rng, center) do
		merge(spots, { cottage(parent, p, center, heightAt, rng, style) })
	end
	return spots
end

-- The Wildwood's fairy glade: a ring of glowing mushrooms, a hollow stump and giant toadstools.
function Landmarks.glowcap(
	parent: Instance,
	center: Vector3,
	heightAt: HeightFn,
	rng: Random,
	style: Style
): { ChestSpot }
	local spots = Landmarks.fairyRing(parent, center, heightAt, rng, style)
	local a = rng:NextNumber(0, math.pi * 2)
	merge(spots, Landmarks.stump(parent, offset(center, a, 28), heightAt, rng, style))
	merge(spots, Landmarks.stump(parent, offset(center, a + 2.2, 30), heightAt, rng, style))
	return spots
end

-- A small village with a windmill.
function Landmarks.millbrook(
	parent: Instance,
	center: Vector3,
	heightAt: HeightFn,
	rng: Random,
	style: Style
): { ChestSpot }
	local model = landmark(parent, "Village")
	local spots: { ChestSpot } = {}
	for i, p in ring(4, 20, rng, center) do
		local spot = cottage(model, p, center, heightAt, rng, style)
		if i % 2 == 0 then
			table.insert(spots, spot)
		end
	end
	well(model, center, heightAt, style)
	merge(spots, Landmarks.windmill(parent, offset(center, rng:NextNumber(0, math.pi * 2), 38), heightAt, rng, style))
	return spots
end

Landmarks.Builders = {
	ruinedTower = Landmarks.ruinedTower,
	shrine = Landmarks.shrine,
	camp = Landmarks.camp,
	watchtower = Landmarks.watchtower,
	ancientOak = Landmarks.ancientOak,
	windmill = Landmarks.windmill,
	iceSpire = Landmarks.iceSpire,
	lodge = Landmarks.lodge,
	forge = Landmarks.forge,
	obsidianGate = Landmarks.obsidianGate,
	pyramid = Landmarks.pyramid,
	bazaar = Landmarks.bazaar,
	fairyRing = Landmarks.fairyRing,
	stump = Landmarks.stump,
	village = Landmarks.village,
	town = Landmarks.town,
	castle = Landmarks.castle,
	cinderforge = Landmarks.cinderforge,
	oasisTown = Landmarks.oasisTown,
	glowcap = Landmarks.glowcap,
	millbrook = Landmarks.millbrook,
}

-- How much room each landmark needs (keeps chests, trees and other landmarks out of it).
Landmarks.Footprint = {
	pyramid = 26,
	ancientOak = 24,
	bazaar = 18,
	village = 36,
	town = 58,
	castle = 34,
	cinderforge = 50,
	oasisTown = 66,
	glowcap = 42,
	millbrook = 50,
}

return Landmarks
