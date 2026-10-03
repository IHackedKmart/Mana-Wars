-- Everything built out of parts: blocky trees, rocks, ruins, the cornucopia, chests,
-- pedestals and loot satchels. Purely visual/physical; no game logic in here.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Build = require(script.Parent.Build)

local Structures = {}

local A = Config.Arena

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

---------------------------------------------------------------------------
-- Nature
---------------------------------------------------------------------------

function Structures.tree(parent: Instance, ground: Vector3, rng: Random)
	local model = Build.model("Tree", parent)
	local kind = rng:NextInteger(1, 10)
	if kind <= 5 then
		-- oak: thick trunk with a big square canopy
		local trunkH = rng:NextNumber(8, 12)
		Build.part({
			Name = "Trunk",
			Size = Vector3.new(2.4, trunkH + 2, 2.4),
			CFrame = CFrame.new(ground + Vector3.new(0, trunkH / 2 - 1, 0)),
			Material = Enum.Material.Wood,
			Color = Color3.fromRGB(105, 75, 48),
		}, model)
		local w = rng:NextNumber(8, 11)
		local leaf = LEAF_COLORS[rng:NextInteger(1, #LEAF_COLORS)]
		Build.part({
			Name = "Leaves",
			Size = Vector3.new(w, 6, w),
			CFrame = CFrame.new(ground + Vector3.new(0, trunkH + 2, 0)),
			Material = Enum.Material.Grass,
			Color = leaf,
		}, model)
		Build.part({
			Name = "Leaves",
			Size = Vector3.new(w * 0.6, 3.5, w * 0.6),
			CFrame = CFrame.new(ground + Vector3.new(0, trunkH + 6.5, 0)),
			Material = Enum.Material.Grass,
			Color = leaf,
		}, model)
	elseif kind <= 8 then
		-- pine: stacked shrinking blocks
		local trunkH = rng:NextNumber(10, 14)
		Build.part({
			Name = "Trunk",
			Size = Vector3.new(2, trunkH + 2, 2),
			CFrame = CFrame.new(ground + Vector3.new(0, trunkH / 2 - 1, 0)),
			Material = Enum.Material.Wood,
			Color = Color3.fromRGB(85, 60, 40),
		}, model)
		local y = trunkH * 0.45
		local w = rng:NextNumber(8, 10)
		for _ = 1, 4 do
			Build.part({
				Name = "Leaves",
				Size = Vector3.new(w, 3.2, w),
				CFrame = CFrame.new(ground + Vector3.new(0, y, 0)),
				Material = Enum.Material.Grass,
				Color = Color3.fromRGB(45, 95, 60),
			}, model)
			y += 3.2
			w *= 0.72
		end
	else
		-- birch: pale and slim
		local trunkH = rng:NextNumber(10, 13)
		Build.part({
			Name = "Trunk",
			Size = Vector3.new(1.8, trunkH + 2, 1.8),
			CFrame = CFrame.new(ground + Vector3.new(0, trunkH / 2 - 1, 0)),
			Material = Enum.Material.Wood,
			Color = Color3.fromRGB(225, 222, 210),
		}, model)
		Build.part({
			Name = "Leaves",
			Size = Vector3.new(7, 7, 7),
			CFrame = CFrame.new(ground + Vector3.new(0, trunkH + 1.5, 0)),
			Material = Enum.Material.Grass,
			Color = Color3.fromRGB(130, 175, 70),
		}, model)
	end
end

function Structures.rock(parent: Instance, ground: Vector3, rng: Random)
	local size = Vector3.new(rng:NextNumber(4, 12), rng:NextNumber(3, 8), rng:NextNumber(4, 12))
	Build.part({
		Name = "Rock",
		Size = size,
		CFrame = CFrame.new(ground + Vector3.new(0, size.Y * 0.25, 0))
			* CFrame.Angles(rng:NextNumber(-0.2, 0.2), rng:NextNumber(0, math.pi * 2), rng:NextNumber(-0.2, 0.2)),
		Material = if rng:NextNumber() < 0.5 then Enum.Material.Rock else Enum.Material.Slate,
		Color = STONE_COLORS[rng:NextInteger(1, #STONE_COLORS)],
	}, parent)
end

function Structures.bush(parent: Instance, ground: Vector3, rng: Random)
	local w = rng:NextNumber(3, 5)
	Build.part({
		Name = "Bush",
		Size = Vector3.new(w, rng:NextNumber(2, 3.5), w),
		CFrame = CFrame.new(ground + Vector3.new(0, 1, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0),
		Material = Enum.Material.Grass,
		Color = LEAF_COLORS[rng:NextInteger(1, #LEAF_COLORS)],
	}, parent)
end

---------------------------------------------------------------------------
-- Points of interest. Each returns a list of chest spots: { {cframe, tier} }
---------------------------------------------------------------------------

export type ChestSpot = { cframe: CFrame, tier: string }

-- Builds a stone floor that reaches down into uneven terrain, returns the floor top Y.
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

function Structures.ruinedTower(parent: Instance, center: Vector3, heightAt, rng: Random): { ChestSpot }
	local model = Build.model("RuinedTower", parent)
	local floorY = foundation(model, center, 20, heightAt, Enum.Material.Cobblestone, Color3.fromRGB(120, 118, 115))
	local segments = 14
	for i = 1, segments do
		if rng:NextNumber() > 0.22 then
			local angle = (i / segments) * math.pi * 2
			local h = rng:NextNumber(3, 14)
			local pos = Vector3.new(center.X + math.cos(angle) * 8, floorY + h / 2, center.Z + math.sin(angle) * 8)
			Build.part({
				Name = "Wall",
				Size = Vector3.new(3.8, h, 1.6),
				CFrame = CFrame.lookAt(pos, Vector3.new(center.X, pos.Y, center.Z)),
				Material = Enum.Material.Cobblestone,
				Color = STONE_COLORS[rng:NextInteger(1, #STONE_COLORS)],
			}, model)
		end
	end
	-- fallen blocks
	for _ = 1, 5 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(10, 16)
		local p = Vector3.new(center.X + math.cos(a) * r, 0, center.Z + math.sin(a) * r)
		Build.part({
			Name = "Rubble",
			Size = Vector3.new(rng:NextNumber(2, 4), rng:NextNumber(1.5, 3), rng:NextNumber(2, 4)),
			CFrame = CFrame.new(p.X, heightAt(p.X, p.Z) + 0.5, p.Z)
				* CFrame.Angles(rng:NextNumber(0, 1), rng:NextNumber(0, 3), 0),
			Material = Enum.Material.Cobblestone,
			Color = STONE_COLORS[1],
		}, model)
	end
	return {
		{ cframe = CFrame.new(center.X, floorY + 1, center.Z), tier = "Shrine" },
		{ cframe = CFrame.new(center.X + 4, floorY + 1, center.Z + 3) * CFrame.Angles(0, 2, 0), tier = "Outer" },
	}
end

function Structures.shrine(parent: Instance, center: Vector3, heightAt, rng: Random): { ChestSpot }
	local model = Build.model("Shrine", parent)
	local floorY = foundation(model, center, 18, heightAt, Enum.Material.Marble, Color3.fromRGB(225, 222, 215))
	local roofY = floorY + 13
	for _, offset in { Vector3.new(-7, 0, -7), Vector3.new(7, 0, -7), Vector3.new(-7, 0, 7), Vector3.new(7, 0, 7) } do
		Build.part({
			Name = "Pillar",
			Size = Vector3.new(2, 13, 2),
			CFrame = CFrame.new(center.X + offset.X, floorY + 6.5, center.Z + offset.Z),
			Material = Enum.Material.Marble,
			Color = Color3.fromRGB(235, 232, 225),
		}, model)
	end
	Build.part({
		Name = "Roof",
		Size = Vector3.new(19, 1.5, 19),
		CFrame = CFrame.new(center.X, roofY + 0.75, center.Z),
		Material = Enum.Material.Marble,
		Color = Color3.fromRGB(210, 205, 195),
	}, model)
	Build.part({
		Name = "Altar",
		Size = Vector3.new(5, 2.5, 3),
		CFrame = CFrame.new(center.X, floorY + 1.25, center.Z - 3),
		Material = Enum.Material.Marble,
		Color = Color3.fromRGB(180, 175, 170),
	}, model)
	local crystal = Build.part({
		Name = "Crystal",
		Size = Vector3.new(1.6, 3.5, 1.6),
		CFrame = CFrame.new(center.X, floorY + 6, center.Z - 3) * CFrame.Angles(0, math.rad(45), math.rad(20)),
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(150, 110, 255),
		CanCollide = false,
	}, model)
	Build.make("PointLight", { Color = crystal.Color, Range = 18, Brightness = 2 }, crystal)
	local hue = rng:NextNumber(0.6, 0.85)
	crystal.Color = Color3.fromHSV(hue, 0.5, 1)
	return { { cframe = CFrame.new(center.X, floorY + 1, center.Z + 1), tier = "Shrine" } }
end

function Structures.camp(parent: Instance, center: Vector3, heightAt, rng: Random): { ChestSpot }
	local model = Build.model("Camp", parent)
	local groundY = heightAt(center.X, center.Z)
	-- campfire
	local fire = Build.part({
		Name = "Campfire",
		Size = Vector3.new(3, 0.8, 3),
		CFrame = CFrame.new(center.X, groundY + 0.2, center.Z),
		Material = Enum.Material.Wood,
		Color = Color3.fromRGB(70, 50, 35),
		CanCollide = false,
	}, model)
	Build.make("Fire", { Size = 4, Heat = 6 }, fire)
	Build.make("PointLight", { Color = Color3.fromRGB(255, 160, 80), Range = 20, Brightness = 2 }, fire)
	-- tents
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
			Material = Enum.Material.Fabric,
		}, model)
		Build.wedge({
			Name = "Tent",
			Size = Vector3.new(6, 5, 3),
			CFrame = look * CFrame.new(0, 0, 1.5) * CFrame.Angles(0, math.pi, 0),
			Color = canvas,
			Material = Enum.Material.Fabric,
		}, model)
	end
	-- crates
	for _ = 1, 3 do
		local a = rng:NextNumber(0, math.pi * 2)
		local p = Vector3.new(center.X + math.cos(a) * 5.5, 0, center.Z + math.sin(a) * 5.5)
		Build.part({
			Name = "Crate",
			Size = Vector3.new(2.5, 2.5, 2.5),
			CFrame = CFrame.new(p.X, heightAt(p.X, p.Z) + 1.1, p.Z) * CFrame.Angles(0, rng:NextNumber(0, 3), 0),
			Material = Enum.Material.WoodPlanks,
			Color = Color3.fromRGB(160, 120, 75),
		}, model)
	end
	local chestAngle = rng:NextNumber(0, math.pi * 2)
	local cp = Vector3.new(center.X + math.cos(chestAngle) * 4, 0, center.Z + math.sin(chestAngle) * 4)
	return {
		{
			cframe = CFrame.lookAt(
				Vector3.new(cp.X, heightAt(cp.X, cp.Z) + 1, cp.Z),
				Vector3.new(center.X, heightAt(cp.X, cp.Z) + 1, center.Z)
			),
			tier = "Outer",
		},
	}
end

function Structures.watchtower(parent: Instance, center: Vector3, heightAt, rng: Random): { ChestSpot }
	local model = Build.model("Watchtower", parent)
	local groundY = heightAt(center.X, center.Z)
	local topY = groundY + 16
	for _, o in { Vector3.new(-4, 0, -4), Vector3.new(4, 0, -4), Vector3.new(-4, 0, 4), Vector3.new(4, 0, 4) } do
		local gy = heightAt(center.X + o.X, center.Z + o.Z)
		local h = topY - gy + 3
		Build.part({
			Name = "Leg",
			Size = Vector3.new(1.4, h, 1.4),
			CFrame = CFrame.new(center.X + o.X, gy + h / 2 - 3, center.Z + o.Z),
			Material = Enum.Material.Wood,
			Color = Color3.fromRGB(110, 80, 50),
		}, model)
	end
	Build.part({
		Name = "Platform",
		Size = Vector3.new(11, 1, 11),
		CFrame = CFrame.new(center.X, topY, center.Z),
		Material = Enum.Material.WoodPlanks,
		Color = Color3.fromRGB(150, 110, 70),
	}, model)
	for _, o in { Vector3.new(0, 0, -5.2), Vector3.new(0, 0, 5.2) } do
		Build.part({
			Name = "Rail",
			Size = Vector3.new(11, 2.5, 0.6),
			CFrame = CFrame.new(center.X + o.X, topY + 1.75, center.Z + o.Z),
			Material = Enum.Material.WoodPlanks,
			Color = Color3.fromRGB(130, 95, 60),
		}, model)
	end
	Build.part({
		Name = "Rail",
		Size = Vector3.new(0.6, 2.5, 11),
		CFrame = CFrame.new(center.X - 5.2, topY + 1.75, center.Z),
		Material = Enum.Material.WoodPlanks,
		Color = Color3.fromRGB(130, 95, 60),
	}, model)
	-- ladder on the open side
	local ladderH = topY - groundY + 1
	local truss = Instance.new("TrussPart")
	truss.Anchored = true
	truss.Size = Vector3.new(2, math.max(2, math.floor(ladderH / 2) * 2), 2)
	truss.CFrame = CFrame.new(center.X + 6.6, groundY + truss.Size.Y / 2 - 0.5, center.Z)
	truss.Color = Color3.fromRGB(110, 80, 50)
	truss.Parent = model
	return {
		{
			cframe = CFrame.new(center.X, topY + 1.5, center.Z) * CFrame.Angles(0, rng:NextNumber(0, 6), 0),
			tier = "Shrine",
		},
	}
end

---------------------------------------------------------------------------
-- Cornucopia
---------------------------------------------------------------------------

export type CornucopiaResult = { chests: { ChestSpot }, pedestals: { CFrame } }

function Structures.cornucopia(parent: Instance, plazaY: number): CornucopiaResult
	local model = Build.model("Cornucopia", parent)
	local center = Vector3.new(0, plazaY, 0)

	Build.cylinder(center + Vector3.new(0, 0.2, 0), A.CornucopiaRadius * 2, 1.4, {
		Name = "Plaza",
		Material = Enum.Material.Slate,
		Color = Color3.fromRGB(105, 105, 115),
	}, model)
	Build.cylinder(center + Vector3.new(0, 1.2, 0), 32, 2, {
		Name = "Dais",
		Material = Enum.Material.Marble,
		Color = Color3.fromRGB(225, 220, 210),
	}, model)
	Build.cylinder(center + Vector3.new(0, 2.25, 0), 33, 0.3, {
		Name = "DaisTrim",
		Material = Enum.Material.Metal,
		Color = Color3.fromRGB(212, 175, 55),
	}, model)

	-- The Mana Spire: a floating crystal above a stone plinth
	Build.cylinder(center + Vector3.new(0, 4, 0), 8, 4, {
		Name = "Plinth",
		Material = Enum.Material.Basalt,
		Color = Color3.fromRGB(45, 40, 55),
	}, model)
	local spire = Build.part({
		Name = "ManaSpire",
		Size = Vector3.new(5, 14, 5),
		CFrame = CFrame.new(center + Vector3.new(0, 14, 0)) * CFrame.Angles(0, math.rad(45), 0),
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(150, 90, 255),
		Transparency = 0.15,
		CanCollide = false,
	}, model)
	Build.make("PointLight", { Color = spire.Color, Range = 45, Brightness = 3 }, spire)
	Build.make("ParticleEmitter", {
		Color = ColorSequence.new(Color3.fromRGB(200, 160, 255)),
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
		Build.part({
			Name = "Monolith",
			Size = Vector3.new(3, 9, 3),
			CFrame = CFrame.lookAt(pos, Vector3.new(0, pos.Y, 0)),
			Material = Enum.Material.Slate,
			Color = Color3.fromRGB(80, 78, 90),
		}, model)
		local rune = Build.part({
			Name = "Rune",
			Size = Vector3.new(1.2, 1.2, 0.2),
			CFrame = CFrame.lookAt(pos, Vector3.new(0, pos.Y, 0)) * CFrame.new(0, 1.5, -1.55),
			Material = Enum.Material.Neon,
			Color = Color3.fromRGB(170, 120, 255),
			CanCollide = false,
		}, model)
		rune.Name = "Rune"
	end

	local chests: { ChestSpot } = {}
	for i = 1, 12 do
		local angle = (i / 12) * math.pi * 2
		local pos = Vector3.new(math.cos(angle) * 10.5, plazaY + 3.25, math.sin(angle) * 10.5)
		table.insert(chests, {
			cframe = CFrame.lookAt(pos, pos + Vector3.new(math.cos(angle), 0, math.sin(angle))),
			tier = "Cornucopia",
		})
	end
	for i = 1, 4 do
		local angle = (i / 4) * math.pi * 2 + math.pi / 4
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
			Material = Enum.Material.Marble,
			Color = Color3.fromRGB(200, 195, 190),
		}, model)
		Build.cylinder(base + Vector3.new(0, 2.45, 0), 4, 0.15, {
			Name = "PedestalRune",
			Material = Enum.Material.Neon,
			Color = Color3.fromRGB(150, 100, 255),
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
