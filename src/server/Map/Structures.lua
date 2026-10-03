-- Everything built out of parts: blocky trees, rocks, ruins, the cornucopia, chests,
-- pedestals and loot satchels. Purely visual/physical; no game logic in here.
-- Most builders take a `style` (see MapDefs) so each map gets its own look.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Build = require(script.Parent.Build)
local MapDefs = require(script.Parent.MapDefs)

type Style = MapDefs.Style

local Structures = {}

local A = Config.Arena
local M = Enum.Material

local LEAF_COLORS = {
	Color3.fromRGB(76, 140, 58),
	Color3.fromRGB(62, 125, 50),
	Color3.fromRGB(95, 155, 64),
	Color3.fromRGB(58, 110, 64),
}
local STONE_COLORS = {
	Color3.fromRGB(130, 130, 135),
	Color3.fromRGB(115, 112, 110),
	Color3.fromRGB(150, 148, 140),
}
local MUSHROOM_CAPS = {
	Color3.fromRGB(200, 60, 80),
	Color3.fromRGB(140, 70, 200),
	Color3.fromRGB(60, 120, 220),
	Color3.fromRGB(230, 120, 60),
}
local GLOW_COLORS = {
	Color3.fromRGB(90, 255, 220),
	Color3.fromRGB(200, 120, 255),
	Color3.fromRGB(255, 120, 200),
	Color3.fromRGB(140, 220, 255),
}

local function pick<T>(rng: Random, list: { T }): T
	return list[rng:NextInteger(1, #list)]
end

local function block(
	model: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	material: Enum.Material,
	color: Color3
): Part
	return Build.part({ Name = name, Size = size, CFrame = cf, Material = material, Color = color }, model)
end

---------------------------------------------------------------------------
-- Trees
---------------------------------------------------------------------------

local trees = {}

-- oak: thick trunk with a big square canopy
function trees.oak(model: Model, ground: Vector3, rng: Random)
	local trunkH = rng:NextNumber(8, 12)
	block(
		model,
		"Trunk",
		Vector3.new(2.4, trunkH + 2, 2.4),
		CFrame.new(ground + Vector3.new(0, trunkH / 2 - 1, 0)),
		M.Wood,
		Color3.fromRGB(105, 75, 48)
	)
	local w = rng:NextNumber(8, 11)
	local leaf = pick(rng, LEAF_COLORS)
	block(model, "Leaves", Vector3.new(w, 6, w), CFrame.new(ground + Vector3.new(0, trunkH + 2, 0)), M.Grass, leaf)
	block(
		model,
		"Leaves",
		Vector3.new(w * 0.6, 3.5, w * 0.6),
		CFrame.new(ground + Vector3.new(0, trunkH + 6.5, 0)),
		M.Grass,
		leaf
	)
end

-- pine: stacked shrinking blocks, optionally snow-capped
local function pine(model: Model, ground: Vector3, rng: Random, snowy: boolean)
	local trunkH = rng:NextNumber(10, 14)
	block(
		model,
		"Trunk",
		Vector3.new(2, trunkH + 2, 2),
		CFrame.new(ground + Vector3.new(0, trunkH / 2 - 1, 0)),
		M.Wood,
		Color3.fromRGB(85, 60, 40)
	)
	local y = trunkH * 0.45
	local w = rng:NextNumber(8, 10)
	for _ = 1, 4 do
		block(
			model,
			"Leaves",
			Vector3.new(w, 3.2, w),
			CFrame.new(ground + Vector3.new(0, y, 0)),
			M.Grass,
			Color3.fromRGB(45, 95, 60)
		)
		if snowy then
			block(
				model,
				"Snow",
				Vector3.new(w * 0.8, 0.6, w * 0.8),
				CFrame.new(ground + Vector3.new(0, y + 1.9, 0)),
				M.Snow,
				Color3.fromRGB(240, 245, 255)
			)
		end
		y += 3.2
		w *= 0.72
	end
end

function trees.pine(model: Model, ground: Vector3, rng: Random)
	pine(model, ground, rng, false)
end

function trees.snowpine(model: Model, ground: Vector3, rng: Random)
	pine(model, ground, rng, true)
end

-- birch: pale and slim
function trees.birch(model: Model, ground: Vector3, rng: Random)
	local trunkH = rng:NextNumber(10, 13)
	block(
		model,
		"Trunk",
		Vector3.new(1.8, trunkH + 2, 1.8),
		CFrame.new(ground + Vector3.new(0, trunkH / 2 - 1, 0)),
		M.Wood,
		Color3.fromRGB(225, 222, 210)
	)
	block(
		model,
		"Leaves",
		Vector3.new(7, 7, 7),
		CFrame.new(ground + Vector3.new(0, trunkH + 1.5, 0)),
		M.Grass,
		Color3.fromRGB(130, 175, 70)
	)
end

-- dead tree: a charred trunk with a few crooked branches
function trees.dead(model: Model, ground: Vector3, rng: Random)
	local trunkH = rng:NextNumber(9, 15)
	local bark = Color3.fromRGB(45, 38, 36)
	block(
		model,
		"Trunk",
		Vector3.new(1.8, trunkH + 2, 1.8),
		CFrame.new(ground + Vector3.new(0, trunkH / 2 - 1, 0)),
		M.Wood,
		bark
	)
	for _ = 1, rng:NextInteger(2, 4) do
		local y = rng:NextNumber(trunkH * 0.5, trunkH * 0.95)
		local yaw = rng:NextNumber(0, math.pi * 2)
		local len = rng:NextNumber(3, 6)
		local cf = CFrame.new(ground + Vector3.new(0, y, 0))
			* CFrame.Angles(0, yaw, 0)
			* CFrame.Angles(0, 0, math.rad(rng:NextNumber(35, 60)))
			* CFrame.new(0, len / 2, 0)
		block(model, "Branch", Vector3.new(0.8, len, 0.8), cf, M.Wood, bark)
	end
end

-- palm: a leaning segmented trunk with drooping fronds
function trees.palm(model: Model, ground: Vector3, rng: Random)
	local lean = CFrame.Angles(math.rad(rng:NextNumber(4, 10)), rng:NextNumber(0, math.pi * 2), 0)
	local cf = CFrame.new(ground) * lean
	local segments = rng:NextInteger(5, 7)
	for i = 1, segments do
		block(
			model,
			"Trunk",
			Vector3.new(1.6, 2.6, 1.6),
			cf * CFrame.new(0, (i - 0.5) * 2.4, 0),
			M.Wood,
			Color3.fromRGB(150, 115, 70)
		)
		cf *= CFrame.Angles(math.rad(3), 0, 0)
	end
	local top = cf * CFrame.new(0, segments * 2.4, 0)
	for i = 1, 6 do
		local frond = top
			* CFrame.Angles(0, i * math.pi / 3, 0)
			* CFrame.Angles(math.rad(-25), 0, 0)
			* CFrame.new(0, 0, -3)
		block(model, "Frond", Vector3.new(1.6, 0.4, 6), frond, M.Grass, Color3.fromRGB(70, 150, 60))
	end
end

-- cactus: green column with an arm or two
function trees.cactus(model: Model, ground: Vector3, rng: Random)
	local green = Color3.fromRGB(70, 135, 60)
	local h = rng:NextNumber(6, 11)
	block(model, "Cactus", Vector3.new(2, h, 2), CFrame.new(ground + Vector3.new(0, h / 2 - 0.5, 0)), M.Grass, green)
	for side = -1, 1, 2 do
		if rng:NextNumber() < 0.6 then
			local y = rng:NextNumber(h * 0.35, h * 0.65)
			local yaw = CFrame.Angles(0, rng:NextNumber(0, math.pi), 0)
			local base = CFrame.new(ground + Vector3.new(0, y, 0)) * yaw
			block(model, "Arm", Vector3.new(2.4, 1.4, 1.4), base * CFrame.new(side * 1.8, 0, 0), M.Grass, green)
			local up = rng:NextNumber(2, 4)
			block(model, "Arm", Vector3.new(1.4, up, 1.4), base * CFrame.new(side * 2.6, up / 2, 0), M.Grass, green)
		end
	end
end

-- giant mushroom: pale stem, broad coloured cap with glowing spots
function trees.bigmushroom(model: Model, ground: Vector3, rng: Random)
	local h = rng:NextNumber(8, 18)
	local stemW = rng:NextNumber(1.8, 3)
	Build.cylinder(ground + Vector3.new(0, h / 2 - 0.5, 0), stemW, h, {
		Name = "Stem",
		Material = M.SmoothPlastic,
		Color = Color3.fromRGB(225, 215, 200),
	}, model)
	local capW = rng:NextNumber(9, 16)
	local cap = pick(rng, MUSHROOM_CAPS)
	Build.cylinder(
		ground + Vector3.new(0, h + 0.5, 0),
		capW,
		3,
		{ Name = "Cap", Material = M.SmoothPlastic, Color = cap },
		model
	)
	Build.cylinder(
		ground + Vector3.new(0, h + 2.4, 0),
		capW * 0.6,
		1.4,
		{ Name = "Cap", Material = M.SmoothPlastic, Color = cap },
		model
	)
	local glow = pick(rng, GLOW_COLORS)
	local gills = Build.cylinder(ground + Vector3.new(0, h - 1.1, 0), capW * 0.85, 0.2, {
		Name = "Gills",
		Material = M.Neon,
		Color = glow,
		CanCollide = false,
	}, model)
	if rng:NextNumber() < 0.35 then
		Build.make("PointLight", { Color = glow, Range = 18, Brightness = 1.5 }, gills)
	end
	for _ = 1, rng:NextInteger(3, 6) do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(1, capW * 0.42)
		block(
			model,
			"Spot",
			Vector3.new(1.2, 0.3, 1.2),
			CFrame.new(ground + Vector3.new(math.cos(a) * r, h + 2.1, math.sin(a) * r)),
			M.Neon,
			Color3.fromRGB(255, 245, 230)
		).CanCollide =
			false
	end
end

---------------------------------------------------------------------------
-- Rocks
---------------------------------------------------------------------------

local rocks = {}

function rocks.stone(parent: Instance, ground: Vector3, rng: Random)
	local size = Vector3.new(rng:NextNumber(4, 12), rng:NextNumber(3, 8), rng:NextNumber(4, 12))
	block(
		parent,
		"Rock",
		size,
		CFrame.new(ground + Vector3.new(0, size.Y * 0.25, 0))
			* CFrame.Angles(rng:NextNumber(-0.2, 0.2), rng:NextNumber(0, math.pi * 2), rng:NextNumber(-0.2, 0.2)),
		if rng:NextNumber() < 0.5 then M.Rock else M.Slate,
		pick(rng, STONE_COLORS)
	)
end

-- a cluster of tilted ice shards
function rocks.ice(parent: Instance, ground: Vector3, rng: Random)
	local model = Build.model("IceShards", parent)
	for _ = 1, rng:NextInteger(2, 4) do
		local h = rng:NextNumber(4, 12)
		local w = rng:NextNumber(1.5, 3.5)
		local p = block(
			model,
			"Shard",
			Vector3.new(w, h, w),
			CFrame.new(ground + Vector3.new(rng:NextNumber(-3, 3), h * 0.35, rng:NextNumber(-3, 3)))
				* CFrame.Angles(rng:NextNumber(-0.35, 0.35), rng:NextNumber(0, 3), rng:NextNumber(-0.35, 0.35)),
			M.Ice,
			Color3.fromRGB(170, 220, 250)
		)
		p.Transparency = 0.25
	end
end

-- black volcanic glass with a glowing seam
function rocks.obsidian(parent: Instance, ground: Vector3, rng: Random)
	local model = Build.model("Obsidian", parent)
	local h = rng:NextNumber(6, 16)
	local w = rng:NextNumber(2.5, 5)
	local cf = CFrame.new(ground + Vector3.new(0, h * 0.4, 0))
		* CFrame.Angles(rng:NextNumber(-0.2, 0.2), rng:NextNumber(0, 3), rng:NextNumber(-0.2, 0.2))
	block(model, "Spire", Vector3.new(w, h, w), cf, M.Basalt, Color3.fromRGB(25, 22, 28))
	local seam = block(model, "Seam", Vector3.new(w + 0.1, h * 0.7, 0.3), cf, M.Neon, Color3.fromRGB(255, 110, 30))
	seam.CanCollide = false
end

-- sandstone boulders and broken columns
function rocks.sandstone(parent: Instance, ground: Vector3, rng: Random)
	if rng:NextNumber() < 0.35 then
		local h = rng:NextNumber(5, 14)
		Build.cylinder(ground + Vector3.new(0, h / 2 - 1, 0), rng:NextNumber(2.5, 3.5), h, {
			Name = "Column",
			Material = M.Sandstone,
			Color = Color3.fromRGB(215, 185, 140),
		}, parent)
		return
	end
	local size = Vector3.new(rng:NextNumber(4, 11), rng:NextNumber(3, 7), rng:NextNumber(4, 11))
	block(
		parent,
		"Rock",
		size,
		CFrame.new(ground + Vector3.new(0, size.Y * 0.25, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0),
		M.Sandstone,
		Color3.fromRGB(200, 160, 110)
	)
end

-- dark rock with a cap of glowing moss
function rocks.mossy(parent: Instance, ground: Vector3, rng: Random)
	local model = Build.model("MossyRock", parent)
	local size = Vector3.new(rng:NextNumber(4, 10), rng:NextNumber(3, 6), rng:NextNumber(4, 10))
	local cf = CFrame.new(ground + Vector3.new(0, size.Y * 0.25, 0))
		* CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
	block(model, "Rock", size, cf, M.Slate, Color3.fromRGB(60, 58, 70))
	block(
		model,
		"Moss",
		Vector3.new(size.X * 0.8, 0.5, size.Z * 0.8),
		cf * CFrame.new(0, size.Y / 2, 0),
		M.Grass,
		Color3.fromRGB(60, 140, 120)
	)
end

---------------------------------------------------------------------------
-- Bushes and ground clutter
---------------------------------------------------------------------------

local bushes = {}

function bushes.bush(parent: Instance, ground: Vector3, rng: Random)
	local w = rng:NextNumber(3, 5)
	block(
		parent,
		"Bush",
		Vector3.new(w, rng:NextNumber(2, 3.5), w),
		CFrame.new(ground + Vector3.new(0, 1, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0),
		M.Grass,
		pick(rng, LEAF_COLORS)
	)
end

function bushes.snowdrift(parent: Instance, ground: Vector3, rng: Random)
	local w = rng:NextNumber(4, 8)
	block(
		parent,
		"Snowdrift",
		Vector3.new(w, rng:NextNumber(1.5, 3), w * rng:NextNumber(0.5, 1)),
		CFrame.new(ground + Vector3.new(0, 0.6, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0),
		M.Snow,
		Color3.fromRGB(240, 245, 255)
	)
end

function bushes.ashpile(parent: Instance, ground: Vector3, rng: Random)
	local w = rng:NextNumber(3, 6)
	local p = block(
		parent,
		"Ash",
		Vector3.new(w, rng:NextNumber(1, 2), w),
		CFrame.new(ground + Vector3.new(0, 0.4, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0),
		M.Slate,
		Color3.fromRGB(80, 76, 76)
	)
	if rng:NextNumber() < 0.25 then
		Build.make("Smoke", { Color = Color3.fromRGB(90, 85, 85), Opacity = 0.15, RiseVelocity = 3, Size = 2 }, p)
	end
end

function bushes.shrub(parent: Instance, ground: Vector3, rng: Random)
	local w = rng:NextNumber(2, 3.5)
	block(
		parent,
		"Shrub",
		Vector3.new(w, rng:NextNumber(1.2, 2.2), w),
		CFrame.new(ground + Vector3.new(0, 0.7, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0),
		M.Grass,
		Color3.fromRGB(130, 120, 70)
	)
end

function bushes.smallmushroom(parent: Instance, ground: Vector3, rng: Random)
	local model = Build.model("Mushroom", parent)
	local h = rng:NextNumber(1, 2.5)
	block(
		model,
		"Stem",
		Vector3.new(0.5, h, 0.5),
		CFrame.new(ground + Vector3.new(0, h / 2, 0)),
		M.SmoothPlastic,
		Color3.fromRGB(230, 225, 210)
	)
	local cap = block(
		model,
		"Cap",
		Vector3.new(1.8, 0.6, 1.8),
		CFrame.new(ground + Vector3.new(0, h + 0.2, 0)),
		M.Neon,
		pick(rng, GLOW_COLORS)
	)
	cap.CanCollide = false
end

local DECOR = { tree = trees, rock = rocks, bush = bushes }

-- Builds one decoration of the given kind ("tree" | "rock" | "bush") and style.
function Structures.decor(kind: string, styleName: string, parent: Instance, ground: Vector3, rng: Random)
	local set = DECOR[kind]
	local fn = set and set[styleName]
	if not fn then
		warn("[Structures] unknown decoration " .. kind .. "/" .. styleName)
		return
	end
	if kind == "tree" then
		fn(Build.model("Tree", parent), ground, rng)
	else
		fn(parent, ground, rng)
	end
end

function Structures.hasDecor(kind: string, styleName: string): boolean
	local set = DECOR[kind]
	return set ~= nil and set[styleName] ~= nil
end

---------------------------------------------------------------------------
-- Points of interest. Each returns a list of chest spots: { {cframe, tier} }
---------------------------------------------------------------------------

export type ChestSpot = { cframe: CFrame, tier: string }

-- Builds a floor that reaches down into uneven terrain, returns the floor top Y.
local function foundation(
	parent: Instance,
	center: Vector3,
	size: number,
	heightAt: (number, number) -> number,
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

function Structures.ruinedTower(parent: Instance, center: Vector3, heightAt, rng: Random, style: Style): { ChestSpot }
	local model = Build.model("RuinedTower", parent)
	local floorY = foundation(model, center, 20, heightAt, style.floor, style.floorColor)
	local segments = 14
	for i = 1, segments do
		if rng:NextNumber() > 0.22 then
			local angle = (i / segments) * math.pi * 2
			local h = rng:NextNumber(3, 14)
			local pos = Vector3.new(center.X + math.cos(angle) * 8, floorY + h / 2, center.Z + math.sin(angle) * 8)
			block(
				model,
				"Wall",
				Vector3.new(3.8, h, 1.6),
				CFrame.lookAt(pos, Vector3.new(center.X, pos.Y, center.Z)),
				style.stone,
				pick(rng, style.stoneColors)
			)
		end
	end
	-- fallen blocks
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
		table.insert(spots, {
			cframe = CFrame.new(center.X + 4, floorY + 1, center.Z + 3) * CFrame.Angles(0, 2, 0),
			tier = "Outer",
		})
	end
	return spots
end

function Structures.shrine(parent: Instance, center: Vector3, heightAt, rng: Random, style: Style): { ChestSpot }
	local model = Build.model("Shrine", parent)
	local floorY = foundation(model, center, 18, heightAt, style.shrine, style.shrineColor)
	local roofY = floorY + 13
	for _, offset in { Vector3.new(-7, 0, -7), Vector3.new(7, 0, -7), Vector3.new(-7, 0, 7), Vector3.new(7, 0, 7) } do
		block(
			model,
			"Pillar",
			Vector3.new(2, 13, 2),
			CFrame.new(center.X + offset.X, floorY + 6.5, center.Z + offset.Z),
			style.shrine,
			style.shrineColor
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
		"Altar",
		Vector3.new(5, 2.5, 3),
		CFrame.new(center.X, floorY + 1.25, center.Z - 3),
		style.shrine,
		style.shrineColor:Lerp(Color3.new(0, 0, 0), 0.2)
	)
	local crystal = Build.part({
		Name = "Crystal",
		Size = Vector3.new(1.6, 3.5, 1.6),
		CFrame = CFrame.new(center.X, floorY + 6, center.Z - 3) * CFrame.Angles(0, math.rad(45), math.rad(20)),
		Material = M.Neon,
		Color = style.accent:Lerp(Color3.fromHSV(rng:NextNumber(), 0.5, 1), 0.25),
		CanCollide = false,
	}, model)
	Build.make("PointLight", { Color = crystal.Color, Range = 18, Brightness = 2 }, crystal)
	return { { cframe = CFrame.new(center.X, floorY + 1, center.Z + 1), tier = "Shrine" } }
end

function Structures.camp(parent: Instance, center: Vector3, heightAt, rng: Random, style: Style): { ChestSpot }
	local model = Build.model("Camp", parent)
	local groundY = heightAt(center.X, center.Z)
	local fire = Build.part({
		Name = "Campfire",
		Size = Vector3.new(3, 0.8, 3),
		CFrame = CFrame.new(center.X, groundY + 0.2, center.Z),
		Material = M.Wood,
		Color = style.wood,
		CanCollide = false,
	}, model)
	Build.make("Fire", { Size = 4, Heat = 6 }, fire)
	Build.make("PointLight", { Color = Color3.fromRGB(255, 160, 80), Range = 20, Brightness = 2 }, fire)
	for i = 1, 2 do
		local angle = rng:NextNumber(0, math.pi * 2) + i * math.pi
		local p = Vector3.new(center.X + math.cos(angle) * 9, 0, center.Z + math.sin(angle) * 9)
		local y = heightAt(p.X, p.Z)
		local look = CFrame.lookAt(Vector3.new(p.X, y + 2.5, p.Z), Vector3.new(center.X, y + 2.5, center.Z))
		local canvas = Color3.fromHSV(rng:NextNumber(), 0.35, 0.75)
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
			Color = canvas,
			Material = M.Fabric,
		}, model)
	end
	for _ = 1, 3 do
		local a = rng:NextNumber(0, math.pi * 2)
		local p = Vector3.new(center.X + math.cos(a) * 5.5, 0, center.Z + math.sin(a) * 5.5)
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

function Structures.watchtower(parent: Instance, center: Vector3, heightAt, rng: Random, style: Style): { ChestSpot }
	local model = Build.model("Watchtower", parent)
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
	-- ladder on the open side
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

Structures.Pois = {
	ruinedTower = Structures.ruinedTower,
	shrine = Structures.shrine,
	camp = Structures.camp,
	watchtower = Structures.watchtower,
}

---------------------------------------------------------------------------
-- Cornucopia
---------------------------------------------------------------------------

export type CornucopiaResult = { chests: { ChestSpot }, pedestals: { CFrame } }

function Structures.cornucopia(parent: Instance, plazaY: number, style: Style): CornucopiaResult
	local model = Build.model("Cornucopia", parent)
	local center = Vector3.new(0, plazaY, 0)

	Build.cylinder(center + Vector3.new(0, 0.2, 0), A.CornucopiaRadius * 2, 1.4, {
		Name = "Plaza",
		Material = style.plaza,
		Color = style.plazaColor,
	}, model)
	Build.cylinder(
		center + Vector3.new(0, 1.2, 0),
		32,
		2,
		{ Name = "Dais", Material = style.dais, Color = style.daisColor },
		model
	)
	Build.cylinder(center + Vector3.new(0, 2.25, 0), 33, 0.3, {
		Name = "DaisTrim",
		Material = M.Metal,
		Color = Color3.fromRGB(212, 175, 55),
	}, model)

	-- The Mana Spire: a floating crystal above a stone plinth
	Build.cylinder(
		center + Vector3.new(0, 4, 0),
		8,
		4,
		{ Name = "Plinth", Material = M.Basalt, Color = Color3.fromRGB(45, 40, 55) },
		model
	)
	local spire = Build.part({
		Name = "ManaSpire",
		Size = Vector3.new(5, 14, 5),
		CFrame = CFrame.new(center + Vector3.new(0, 14, 0)) * CFrame.Angles(0, math.rad(45), 0),
		Material = M.Neon,
		Color = style.accent,
		Transparency = 0.15,
		CanCollide = false,
	}, model)
	Build.make("PointLight", { Color = spire.Color, Range = 45, Brightness = 3 }, spire)
	Build.make("ParticleEmitter", {
		Color = ColorSequence.new(style.accent:Lerp(Color3.new(1, 1, 1), 0.4)),
		LightEmission = 1,
		Size = NumberSequence.new(0.6, 0),
		Lifetime = NumberRange.new(1.5, 3),
		Rate = 25,
		Speed = NumberRange.new(2, 6),
		SpreadAngle = Vector2.new(180, 180),
	}, spire)

	-- Standing stones around the plaza
	for i = 1, 8 do
		local angle = (i / 8) * math.pi * 2 + math.pi / 8
		local pos = Vector3.new(
			math.cos(angle) * (A.CornucopiaRadius - 5),
			plazaY + 5,
			math.sin(angle) * (A.CornucopiaRadius - 5)
		)
		local look = CFrame.lookAt(pos, Vector3.new(0, pos.Y, 0))
		block(
			model,
			"Monolith",
			Vector3.new(3, 9, 3),
			look,
			style.stone,
			style.stoneColors[1]:Lerp(Color3.new(0, 0, 0), 0.25)
		)
		block(model, "Rune", Vector3.new(1.2, 1.2, 0.2), look * CFrame.new(0, 1.5, -1.55), M.Neon, style.accent).CanCollide =
			false
	end

	-- Chests: most on the dais around the spire, the rest out on the plaza
	local chests: { ChestSpot } = {}
	local total = A.CornucopiaChests
	local onDais = math.min(total, 8)
	for i = 1, onDais do
		local angle = (i / onDais) * math.pi * 2
		local pos = Vector3.new(math.cos(angle) * 10.5, plazaY + 3.25, math.sin(angle) * 10.5)
		table.insert(chests, {
			cframe = CFrame.lookAt(pos, pos + Vector3.new(math.cos(angle), 0, math.sin(angle))),
			tier = "Cornucopia",
		})
	end
	local onPlaza = total - onDais
	for i = 1, onPlaza do
		local angle = (i / onPlaza) * math.pi * 2 + math.pi / 4
		local pos = Vector3.new(math.cos(angle) * 23, plazaY + 1.9, math.sin(angle) * 23)
		table.insert(chests, {
			cframe = CFrame.lookAt(pos, pos + Vector3.new(math.cos(angle), 0, math.sin(angle))),
			tier = "Cornucopia",
		})
	end

	local pedestals: { CFrame } = {}
	for i = 1, Config.Match.MaxParticipants do
		local angle = (i / Config.Match.MaxParticipants) * math.pi * 2
		local base = Vector3.new(math.cos(angle) * A.PedestalRadius, plazaY, math.sin(angle) * A.PedestalRadius)
		Build.cylinder(base + Vector3.new(0, 1.2, 0), 5, 2.4, {
			Name = "Pedestal",
			Material = style.dais,
			Color = style.daisColor:Lerp(Color3.new(0, 0, 0), 0.1),
		}, model)
		Build.cylinder(base + Vector3.new(0, 2.45, 0), 4, 0.15, {
			Name = "PedestalRune",
			Material = M.Neon,
			Color = style.accent,
			CanCollide = false,
		}, model)
		local standAt = base + Vector3.new(0, 2.4 + 3, 0)
		table.insert(pedestals, CFrame.lookAt(standAt, Vector3.new(0, standAt.Y, 0)))
	end

	return { chests = chests, pedestals = pedestals }
end

---------------------------------------------------------------------------
-- Containers
---------------------------------------------------------------------------

local CHEST_STYLE = {
	Outer = { body = Color3.fromRGB(140, 95, 55), trim = Color3.fromRGB(90, 90, 95), glow = nil },
	Cornucopia = {
		body = Color3.fromRGB(120, 80, 45),
		trim = Color3.fromRGB(212, 175, 55),
		glow = Color3.fromRGB(255, 210, 90),
	},
	Shrine = {
		body = Color3.fromRGB(60, 45, 90),
		trim = Color3.fromRGB(190, 150, 255),
		glow = Color3.fromRGB(170, 120, 255),
	},
}

-- Returns the chest model plus its lid (so ChestService can swing it open).
function Structures.chest(parent: Instance, cframe: CFrame, tier: string): (Model, BasePart)
	local style = CHEST_STYLE[tier] or CHEST_STYLE.Outer
	local model = Build.model("Chest", parent)
	local base = Build.part({
		Name = "Base",
		Size = Vector3.new(3.2, 1.8, 2.2),
		CFrame = cframe * CFrame.new(0, -0.1, 0),
		Material = Enum.Material.WoodPlanks,
		Color = style.body,
	}, model)
	local lid = Build.part({
		Name = "Lid",
		Size = Vector3.new(3.3, 0.8, 2.3),
		CFrame = cframe * CFrame.new(0, 1.2, 0),
		Material = Enum.Material.WoodPlanks,
		Color = style.body,
	}, model)
	Build.part({
		Name = "Band",
		Size = Vector3.new(3.35, 0.3, 2.35),
		CFrame = cframe * CFrame.new(0, 0.75, 0),
		Material = Enum.Material.Metal,
		Color = style.trim,
		CanCollide = false,
	}, model)
	Build.part({
		Name = "Lock",
		Size = Vector3.new(0.6, 0.7, 0.3),
		CFrame = cframe * CFrame.new(0, 0.7, -1.2),
		Material = Enum.Material.Metal,
		Color = Color3.fromRGB(230, 190, 70),
		CanCollide = false,
	}, model)
	if style.glow then
		Build.make("PointLight", { Color = style.glow, Range = 10, Brightness = 1.5 }, base)
	end
	model.PrimaryPart = base
	return model, lid
end

function Structures.satchel(parent: Instance, position: Vector3, label: string): Model
	local model = Build.model("Satchel", parent)
	local sack = Build.part({
		Name = "Sack",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(2.6, 2.6, 2.6),
		CFrame = CFrame.new(position),
		Material = Enum.Material.Fabric,
		Color = Color3.fromRGB(125, 90, 60),
	}, model)
	Build.part({
		Name = "Knot",
		Size = Vector3.new(0.8, 0.8, 0.8),
		CFrame = CFrame.new(position + Vector3.new(0, 1.4, 0)),
		Material = Enum.Material.Fabric,
		Color = Color3.fromRGB(95, 65, 40),
		CanCollide = false,
	}, model)
	Build.make("PointLight", { Color = Color3.fromRGB(255, 220, 140), Range = 8, Brightness = 1 }, sack)
	local gui = Build.make("BillboardGui", {
		Size = UDim2.fromOffset(160, 30),
		StudsOffset = Vector3.new(0, 2.6, 0),
		MaxDistance = 60,
		AlwaysOnTop = false,
	}, sack)
	Build.make("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = label,
		TextColor3 = Color3.fromRGB(255, 230, 170),
		TextStrokeTransparency = 0.4,
		Font = Enum.Font.GothamBold,
		TextScaled = true,
	}, gui)
	model.PrimaryPart = sack
	return model
end

return Structures
