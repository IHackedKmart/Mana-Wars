-- The cornucopia (the plaza, dais, Mana Spire and pedestals in the middle of every arena), chests
-- and loot satchels. Trees and rocks live in Decor, points of interest in Landmarks.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Build = require(script.Parent.Build)
local MapDefs = require(script.Parent.MapDefs)

type Style = MapDefs.Style

local Structures = {}

local A = Config.Arena
local M = Enum.Material
local rgb = Color3.fromRGB

local function block(
	model: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	material: Enum.Material,
	color: Color3,
	noCollide: boolean?
): Part
	local p = Build.part({ Name = name, Size = size, CFrame = cf, Material = material, Color = color }, model)
	if noCollide then
		p.CanCollide = false
	end
	return p
end

local function glow(part: BasePart, color: Color3, range: number, brightness: number)
	Build.make("PointLight", { Color = color, Range = range, Brightness = brightness }, part)
end

---------------------------------------------------------------------------
-- Cornucopia
---------------------------------------------------------------------------

export type ChestSpot = { cframe: CFrame, tier: string }
export type CornucopiaResult = { chests: { ChestSpot }, pedestals: { CFrame } }

-- Each map's themed decoration around the plaza edge, between the standing stones.
local FLAIR: { [string]: (Instance, CFrame, Style, number) -> () } = {}

function FLAIR.flowers(model: Instance, at: CFrame, style: Style, i: number)
	block(model, "Planter", Vector3.new(5, 1.6, 5), at * CFrame.new(0, 0.8, 0), M.WoodPlanks, style.wood)
	block(model, "Soil", Vector3.new(4.4, 0.4, 4.4), at * CFrame.new(0, 1.7, 0), M.Grass, rgb(84, 140, 60))
	local colors = { rgb(236, 70, 84), rgb(250, 210, 70), rgb(172, 110, 232), rgb(246, 246, 250), rgb(250, 140, 190) }
	for k = 0, 3 do
		local a = k * math.pi / 2 + i
		block(
			model,
			"Bloom",
			Vector3.new(1.1, 1, 1.1),
			at * CFrame.new(math.cos(a) * 1.2, 2.4, math.sin(a) * 1.2),
			M.SmoothPlastic,
			colors[(i + k) % #colors + 1],
			true
		)
	end
end

function FLAIR.crystals(model: Instance, at: CFrame, style: Style, i: number)
	block(model, "Base", Vector3.new(4, 1, 4), at * CFrame.new(0, 0.5, 0), M.Slate, rgb(120, 134, 160))
	for k = 1, 3 do
		local h = 7 - k * 1.5
		local shard = block(
			model,
			"Crystal",
			Vector3.new(h * 0.3, h, h * 0.3),
			at * CFrame.new((k - 2) * 1.1, 1 + h * 0.4, (k % 2) * 0.8) * CFrame.Angles(0, k, (k - 2) * 0.25),
			M.Neon,
			if (i + k) % 2 == 0 then style.accent else rgb(190, 140, 255),
			true
		)
		shard.Transparency = 0.1
		if k == 1 and i % 2 == 0 then
			glow(shard, style.accent, 16, 1.4)
		end
	end
end

function FLAIR.braziers(model: Instance, at: CFrame, _style: Style, _i: number)
	block(model, "Pillar", Vector3.new(1.8, 5, 1.8), at * CFrame.new(0, 2.5, 0), M.Basalt, rgb(56, 48, 50))
	local bowl = block(model, "Bowl", Vector3.new(3.4, 1, 3.4), at * CFrame.new(0, 5.5, 0), M.Metal, rgb(60, 50, 46))
	local coals =
		block(model, "Coals", Vector3.new(2.6, 0.3, 2.6), at * CFrame.new(0, 6.05, 0), M.Neon, rgb(255, 110, 30), true)
	Build.make("Fire", { Size = 4, Heat = 7, Color = rgb(255, 130, 40), SecondaryColor = rgb(255, 60, 20) }, coals)
	glow(bowl, rgb(255, 130, 50), 20, 2)
end

function FLAIR.obelisks(model: Instance, at: CFrame, style: Style, i: number)
	block(model, "Plinth", Vector3.new(3.4, 1.2, 3.4), at * CFrame.new(0, 0.6, 0), M.Sandstone, rgb(214, 180, 128))
	block(model, "Obelisk", Vector3.new(1.8, 10, 1.8), at * CFrame.new(0, 6.2, 0), M.Sandstone, rgb(228, 196, 146))
	block(model, "Band", Vector3.new(1.9, 0.8, 1.9), at * CFrame.new(0, 4, 0), M.Sandstone, style.plazaColor2, true)
	local tip = block(
		model,
		"Tip",
		Vector3.new(1.2, 1.2, 1.2),
		at * CFrame.new(0, 11.6, 0) * CFrame.Angles(0, math.rad(45), 0),
		M.Neon,
		style.accent,
		true
	)
	if i % 2 == 0 then
		glow(tip, style.accent, 14, 1.2)
	end
end

function FLAIR.mushrooms(model: Instance, at: CFrame, style: Style, i: number)
	local colors = { style.accent, rgb(220, 120, 255), rgb(255, 130, 210) }
	for k = 0, 1 do
		local h = 4 - k * 1.6
		local offset = CFrame.new(k * 1.8, 0, k * 1.2)
		block(
			model,
			"Stem",
			Vector3.new(0.9, h, 0.9),
			at * offset * CFrame.new(0, h / 2, 0),
			M.SmoothPlastic,
			rgb(232, 224, 210)
		)
		local cap = block(
			model,
			"Cap",
			Vector3.new(3.6 - k, 1, 3.6 - k),
			at * offset * CFrame.new(0, h + 0.4, 0),
			M.Neon,
			colors[(i + k) % #colors + 1],
			true
		)
		if k == 0 and i % 2 == 0 then
			glow(cap, cap.Color, 18, 1.4)
		end
	end
end

-- Builds the plaza in the middle of the arena: a patterned floor in the map's colours, the dais and the
-- Mana Spire, standing stones with banners, themed decoration, the cornucopia chests and the pedestals.
function Structures.cornucopia(parent: Instance, plazaY: number, style: Style): CornucopiaResult
	local model = Build.model("Cornucopia", parent)
	local center = Vector3.new(0, plazaY, 0)
	local R = A.CornucopiaRadius

	-- a patterned floor: rings and spokes inlaid in a second colour (each layer a little higher)
	local function disc(
		name: string,
		radius: number,
		top: number,
		material: Enum.Material,
		color: Color3,
		thickness: number?
	)
		local t = thickness or 0.3
		Build.cylinder(
			center + Vector3.new(0, top - t / 2, 0),
			radius * 2,
			t,
			{ Name = name, Material = material, Color = color },
			model
		)
	end
	local floorTop = 0.9
	disc("Plaza", R, floorTop, style.plaza, style.plazaColor, 1.4)
	disc("Inlay", R - 2, floorTop + 0.12, style.plaza, style.plazaColor2)
	disc("Plaza", R - 3.5, floorTop + 0.24, style.plaza, style.plazaColor:Lerp(Color3.new(1, 1, 1), 0.06))
	disc("Inlay", 21, floorTop + 0.36, style.plaza, style.plazaColor2)
	disc("Plaza", 19.5, floorTop + 0.48, style.plaza, style.plazaColor)
	for i = 1, Config.Match.MaxParticipants do
		local angle = (i / Config.Match.MaxParticipants) * math.pi * 2
		local from, to = 21, R - 3.5
		local mid = (from + to) / 2
		block(
			model,
			"Spoke",
			Vector3.new(to - from, 0.2, 1.6),
			CFrame.new(center + Vector3.new(math.cos(angle) * mid, floorTop + 0.2, math.sin(angle) * mid))
				* CFrame.Angles(0, -angle, 0),
			style.plaza,
			style.plazaColor2
		)
	end

	-- the dais and the Mana Spire: a floating crystal above a stone plinth
	Build.cylinder(
		center + Vector3.new(0, 1.2, 0),
		32,
		2,
		{ Name = "Dais", Material = style.dais, Color = style.daisColor },
		model
	)
	Build.cylinder(
		center + Vector3.new(0, 2.25, 0),
		33,
		0.3,
		{ Name = "DaisTrim", Material = M.Metal, Color = rgb(212, 175, 55) },
		model
	)
	Build.cylinder(
		center + Vector3.new(0, 4, 0),
		8,
		4,
		{ Name = "Plinth", Material = M.Basalt, Color = rgb(45, 40, 55) },
		model
	)
	Build.cylinder(
		center + Vector3.new(0, 6.1, 0),
		9,
		0.4,
		{ Name = "PlinthTrim", Material = M.Neon, Color = style.accent, CanCollide = false },
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
	Build.make("PointLight", { Color = spire.Color, Range = 50, Brightness = 3 }, spire)
	Build.make("ParticleEmitter", {
		Color = ColorSequence.new(style.accent:Lerp(Color3.new(1, 1, 1), 0.4)),
		LightEmission = 1,
		Size = NumberSequence.new(0.6, 0),
		Lifetime = NumberRange.new(1.5, 3),
		Rate = 25,
		Speed = NumberRange.new(2, 6),
		SpreadAngle = Vector2.new(180, 180),
	}, spire)
	-- three rings orbiting the spire
	for k = 1, 3 do
		local ring = CFrame.new(center + Vector3.new(0, 9 + k * 3.5, 0)) * CFrame.Angles(0, k * 0.7, 0)
		for s = 0, 3 do
			block(
				model,
				"Orbit",
				Vector3.new(4.5, 0.35, 0.35),
				ring * CFrame.Angles(0, s * math.pi / 2, 0) * CFrame.new(0, 0, -(4 + k)),
				M.Neon,
				style.accent:Lerp(Color3.new(1, 1, 1), 0.3),
				true
			)
		end
	end

	-- standing stones with banners, and the map's own decoration in between
	for i = 1, 8 do
		local angle = (i / 8) * math.pi * 2 + math.pi / 8
		local pos = Vector3.new(math.cos(angle) * (R - 5), plazaY + 5.5, math.sin(angle) * (R - 5))
		local look = CFrame.lookAt(pos, Vector3.new(0, pos.Y, 0))
		block(
			model,
			"Monolith",
			Vector3.new(3.4, 10, 3.4),
			look,
			style.stone,
			style.stoneColors[1]:Lerp(Color3.new(0, 0, 0), 0.25)
		)
		block(
			model,
			"MonolithCap",
			Vector3.new(4.2, 1, 4.2),
			look * CFrame.new(0, 5.5, 0),
			style.stone,
			style.stoneColors[2]
		)
		block(model, "Rune", Vector3.new(1.2, 1.6, 0.2), look * CFrame.new(0, 1.5, -1.75), M.Neon, style.accent, true)
		block(
			model,
			"Banner",
			Vector3.new(2.6, 5, 0.2),
			look * CFrame.new(0, 1, 1.8),
			M.Fabric,
			style.banner[(i - 1) % #style.banner + 1],
			true
		)
		local flairAngle = (i / 8) * math.pi * 2
		local at = CFrame.new(math.cos(flairAngle) * (R - 6), plazaY + floorTop + 0.24, math.sin(flairAngle) * (R - 6))
			* CFrame.Angles(0, -flairAngle, 0)
		local flair = FLAIR[style.flair]
		if flair then
			flair(model, at, style, i)
		end
	end

	-- chests: some on the dais around the spire, the rest spread over the plaza
	local chests: { ChestSpot } = {}
	local total = A.CornucopiaChests
	local onDais = math.min(total, 6)
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
		local pos = Vector3.new(math.cos(angle) * 31, plazaY + floorTop + 1.25, math.sin(angle) * 31)
		table.insert(chests, {
			cframe = CFrame.lookAt(pos, pos + Vector3.new(math.cos(angle), 0, math.sin(angle))),
			tier = "Cornucopia",
		})
	end

	-- pedestals, spread wide around the plaza
	local pedestals: { CFrame } = {}
	for i = 1, Config.Match.MaxParticipants do
		local angle = (i / Config.Match.MaxParticipants) * math.pi * 2
		local base = Vector3.new(math.cos(angle) * A.PedestalRadius, plazaY, math.sin(angle) * A.PedestalRadius)
		Build.cylinder(
			base + Vector3.new(0, 0.3, 0),
			8,
			0.6,
			{ Name = "PedestalTile", Material = style.plaza, Color = style.plazaColor2 },
			model
		)
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
	House = { body = Color3.fromRGB(110, 76, 50), trim = Color3.fromRGB(150, 120, 70), glow = nil },
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
