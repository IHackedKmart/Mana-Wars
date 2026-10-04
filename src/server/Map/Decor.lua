-- Decoration scattered over the arenas: trees, rocks, flowers and ground clutter for every biome.
-- Everything is built from a handful of parts (the blocky look is a Minecraft nod), using Roblox
-- materials for texture. Builders are grouped by kind ("tree" | "rock" | "bush") and named in MapDefs.

local Build = require(script.Parent.Build)
local MapDefs = require(script.Parent.MapDefs)

type Style = MapDefs.Style

local Decor = {}

local M = Enum.Material
local rgb = Color3.fromRGB

local LEAVES = { rgb(76, 150, 58), rgb(62, 135, 50), rgb(98, 165, 64), rgb(58, 122, 64), rgb(112, 172, 70) }
local AUTUMN = { rgb(232, 122, 40), rgb(214, 74, 46), rgb(244, 184, 56), rgb(196, 58, 64), rgb(226, 150, 40) }
local FLOWERS = {
	rgb(236, 70, 84),
	rgb(250, 210, 70),
	rgb(172, 110, 232),
	rgb(246, 246, 250),
	rgb(90, 150, 242),
	rgb(250, 140, 190),
	rgb(255, 150, 60),
}
local DESERT_FLOWERS = { rgb(250, 110, 160), rgb(255, 210, 60), rgb(255, 140, 70), rgb(200, 120, 240) }
local STONE = { rgb(134, 132, 136), rgb(116, 112, 110), rgb(150, 146, 138) }
local CAPS = { rgb(206, 52, 76), rgb(146, 70, 210), rgb(54, 120, 226), rgb(236, 120, 52), rgb(220, 70, 170) }
local GLOW = { rgb(90, 255, 220), rgb(200, 120, 255), rgb(255, 120, 200), rgb(140, 220, 255), rgb(170, 255, 120) }
local STRATA = { rgb(204, 120, 76), rgb(238, 206, 160), rgb(170, 84, 60), rgb(246, 226, 190), rgb(214, 150, 96) }

local function pick<T>(rng: Random, list: { T }): T
	return list[rng:NextInteger(1, #list)]
end

local function vary(c: Color3, rng: Random, amount: number): Color3
	local f = 1 + rng:NextNumber(-amount, amount)
	return Color3.new(math.clamp(c.R * f, 0, 1), math.clamp(c.G * f, 0, 1), math.clamp(c.B * f, 0, 1))
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

local function at(ground: Vector3, x: number, y: number, z: number): CFrame
	return CFrame.new(ground + Vector3.new(x, y, z))
end

local function spin(rng: Random): CFrame
	return CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
end

---------------------------------------------------------------------------
-- Trees
---------------------------------------------------------------------------

local trees = {}

-- a canopy of a few overlapping blocks in neighbouring shades
local function canopy(model: Instance, center: Vector3, w: number, palette: { Color3 }, rng: Random)
	local base = pick(rng, palette)
	block(model, "Leaves", Vector3.new(w, w * 0.62, w), CFrame.new(center), M.Grass, base)
	for _ = 1, rng:NextInteger(2, 3) do
		local s = w * rng:NextNumber(0.45, 0.65)
		local offset =
			Vector3.new(rng:NextNumber(-w, w) * 0.35, rng:NextNumber(0.1, 0.45) * w, rng:NextNumber(-w, w) * 0.35)
		block(model, "Leaves", Vector3.new(s, s * 0.7, s), CFrame.new(center + offset), M.Grass, vary(base, rng, 0.12))
	end
end

local function trunk(model: Instance, ground: Vector3, width: number, height: number, color: Color3): Part
	return block(model, "Trunk", Vector3.new(width, height + 2, width), at(ground, 0, height / 2 - 1, 0), M.Wood, color)
end

function trees.oak(model: Model, ground: Vector3, rng: Random)
	local h = rng:NextNumber(8, 12)
	trunk(model, ground, 2.4, h, rgb(108, 76, 48))
	if rng:NextNumber() < 0.5 then
		local yaw = spin(rng)
		block(
			model,
			"Branch",
			Vector3.new(1, 4, 1),
			at(ground, 0, h * 0.6, 0) * yaw * CFrame.Angles(0, 0, math.rad(50)) * CFrame.new(0, 2, 0),
			M.Wood,
			rgb(108, 76, 48)
		)
	end
	canopy(model, ground + Vector3.new(0, h + 2, 0), rng:NextNumber(8, 11), LEAVES, rng)
end

function trees.autumn(model: Model, ground: Vector3, rng: Random)
	local h = rng:NextNumber(8, 11)
	trunk(model, ground, 2.2, h, rgb(96, 66, 44))
	canopy(model, ground + Vector3.new(0, h + 2, 0), rng:NextNumber(8, 10), AUTUMN, rng)
	-- a few fallen leaves
	for _ = 1, 3 do
		block(
			model,
			"Fallen",
			Vector3.new(1.2, 0.15, 1.2),
			at(ground, rng:NextNumber(-5, 5), 0.1, rng:NextNumber(-5, 5)) * spin(rng),
			M.Grass,
			pick(rng, AUTUMN),
			true
		)
	end
end

local function pine(model: Model, ground: Vector3, rng: Random, snowy: boolean)
	local h = rng:NextNumber(10, 15)
	trunk(model, ground, 2, h, rgb(86, 60, 40))
	local y = h * 0.42
	local w = rng:NextNumber(8, 10.5)
	local green = if snowy then rgb(40, 92, 70) else rgb(44, 100, 58)
	for i = 1, 4 do
		local shade = if i % 2 == 0 then green else green:Lerp(Color3.new(0, 0, 0), 0.12)
		block(
			model,
			"Leaves",
			Vector3.new(w, 3.2, w),
			at(ground, 0, y, 0) * CFrame.Angles(0, i * 0.4, 0),
			M.Grass,
			shade
		)
		if snowy then
			block(
				model,
				"Snow",
				Vector3.new(w * 0.82, 0.7, w * 0.82),
				at(ground, 0, y + 1.9, 0) * CFrame.Angles(0, i * 0.4, 0),
				M.Snow,
				rgb(242, 247, 255)
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

function trees.birch(model: Model, ground: Vector3, rng: Random)
	local h = rng:NextNumber(10, 13)
	local bark = trunk(model, ground, 1.8, h, rgb(232, 228, 216))
	for i = 1, 3 do
		block(
			model,
			"Mark",
			Vector3.new(1.85, 0.35, 0.9),
			bark.CFrame * CFrame.new(0, -h / 2 + i * h / 4, rng:NextNumber(-0.4, 0.4)),
			M.SmoothPlastic,
			rgb(40, 38, 36),
			true
		)
	end
	canopy(model, ground + Vector3.new(0, h + 1.5, 0), 7, { rgb(140, 186, 72), rgb(160, 196, 80) }, rng)
end

function trees.frostbirch(model: Model, ground: Vector3, rng: Random)
	local h = rng:NextNumber(10, 13)
	trunk(model, ground, 1.7, h, rgb(236, 240, 246))
	canopy(
		model,
		ground + Vector3.new(0, h + 1.5, 0),
		7.5,
		{ rgb(196, 230, 255), rgb(220, 236, 255), rgb(170, 210, 250) },
		rng
	)
end

function trees.dead(model: Model, ground: Vector3, rng: Random)
	local h = rng:NextNumber(9, 15)
	local bark = rgb(46, 38, 36)
	trunk(model, ground, 1.8, h, bark)
	for _ = 1, rng:NextInteger(2, 4) do
		local y = rng:NextNumber(h * 0.5, h * 0.95)
		local len = rng:NextNumber(3, 6)
		local cf = at(ground, 0, y, 0)
			* spin(rng)
			* CFrame.Angles(0, 0, math.rad(rng:NextNumber(35, 60)))
			* CFrame.new(0, len / 2, 0)
		block(model, "Branch", Vector3.new(0.8, len, 0.8), cf, M.Wood, bark)
	end
end

-- a burnt tree with glowing cracks and smouldering branch tips
function trees.charred(model: Model, ground: Vector3, rng: Random)
	local h = rng:NextNumber(8, 13)
	local bark = trunk(model, ground, 2, h, rgb(30, 26, 26))
	block(
		model,
		"Crack",
		Vector3.new(2.05, h * 0.6, 0.3),
		bark.CFrame * CFrame.new(0, -h * 0.1, 0),
		M.Neon,
		rgb(255, 110, 30),
		true
	)
	for _ = 1, rng:NextInteger(2, 3) do
		local len = rng:NextNumber(3, 5)
		local cf = at(ground, 0, rng:NextNumber(h * 0.55, h * 0.9), 0)
			* spin(rng)
			* CFrame.Angles(0, 0, math.rad(rng:NextNumber(35, 55)))
			* CFrame.new(0, len / 2, 0)
		block(model, "Branch", Vector3.new(0.8, len, 0.8), cf, M.Wood, rgb(30, 26, 26))
		block(
			model,
			"Ember",
			Vector3.new(0.9, 0.6, 0.9),
			cf * CFrame.new(0, len / 2, 0),
			M.Neon,
			rgb(255, 150, 50),
			true
		)
	end
end

function trees.palm(model: Model, ground: Vector3, rng: Random)
	local cf = CFrame.new(ground) * CFrame.Angles(math.rad(rng:NextNumber(4, 12)), rng:NextNumber(0, math.pi * 2), 0)
	local segments = rng:NextInteger(5, 7)
	for i = 1, segments do
		block(
			model,
			"Trunk",
			Vector3.new(1.6, 2.6, 1.6),
			cf * CFrame.new(0, (i - 0.5) * 2.4, 0),
			M.Wood,
			if i % 2 == 0 then rgb(156, 118, 72) else rgb(136, 102, 62)
		)
		cf *= CFrame.Angles(math.rad(3), 0, 0)
	end
	local top = cf * CFrame.new(0, segments * 2.4, 0)
	for i = 1, 7 do
		local frond = top
			* CFrame.Angles(0, i * math.pi * 2 / 7, 0)
			* CFrame.Angles(math.rad(-22), 0, 0)
			* CFrame.new(0, 0, -3.2)
		block(
			model,
			"Frond",
			Vector3.new(1.8, 0.4, 6.5),
			frond,
			M.Grass,
			if i % 2 == 0 then rgb(70, 156, 60) else rgb(92, 172, 64)
		)
	end
	for i = 1, rng:NextInteger(2, 3) do
		Build.part({
			Name = "Coconut",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(1, 1, 1),
			CFrame = top * CFrame.Angles(0, i * 2.1, 0) * CFrame.new(0.7, -0.6, 0),
			Material = M.Wood,
			Color = rgb(110, 76, 44),
		}, model)
	end
end

function trees.cactus(model: Model, ground: Vector3, rng: Random)
	local green = vary(rgb(70, 140, 62), rng, 0.1)
	local h = rng:NextNumber(6, 11)
	block(model, "Cactus", Vector3.new(2, h, 2), at(ground, 0, h / 2 - 0.5, 0), M.Grass, green)
	block(
		model,
		"Rib",
		Vector3.new(2.15, h - 0.6, 0.6),
		at(ground, 0, h / 2 - 0.5, 0),
		M.Grass,
		green:Lerp(Color3.new(0, 0, 0), 0.15)
	)
	for side = -1, 1, 2 do
		if rng:NextNumber() < 0.6 then
			local y = rng:NextNumber(h * 0.35, h * 0.65)
			local base = at(ground, 0, y, 0) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0)
			block(model, "Arm", Vector3.new(2.4, 1.4, 1.4), base * CFrame.new(side * 1.8, 0, 0), M.Grass, green)
			local up = rng:NextNumber(2, 4)
			block(model, "Arm", Vector3.new(1.4, up, 1.4), base * CFrame.new(side * 2.6, up / 2, 0), M.Grass, green)
		end
	end
	if rng:NextNumber() < 0.45 then
		block(
			model,
			"Bloom",
			Vector3.new(1.2, 0.8, 1.2),
			at(ground, 0, h - 0.2, 0),
			M.SmoothPlastic,
			pick(rng, DESERT_FLOWERS),
			true
		)
	end
end

local function mushroom(model: Instance, ground: Vector3, h: number, capW: number, rng: Random, lightChance: number)
	Build.cylinder(ground + Vector3.new(0, h / 2 - 0.5, 0), math.max(1, capW * 0.2), h, {
		Name = "Stem",
		Material = M.SmoothPlastic,
		Color = rgb(228, 218, 202),
	}, model)
	local cap = pick(rng, CAPS)
	Build.cylinder(
		ground + Vector3.new(0, h + 0.5, 0),
		capW,
		capW * 0.22,
		{ Name = "Cap", Material = M.SmoothPlastic, Color = cap },
		model
	)
	Build.cylinder(
		ground + Vector3.new(0, h + 0.5 + capW * 0.17, 0),
		capW * 0.62,
		capW * 0.12,
		{ Name = "Cap", Material = M.SmoothPlastic, Color = cap },
		model
	)
	local glowColor = pick(rng, GLOW)
	local gills = Build.cylinder(ground + Vector3.new(0, h + 0.5 - capW * 0.12, 0), capW * 0.85, 0.2, {
		Name = "Gills",
		Material = M.Neon,
		Color = glowColor,
		CanCollide = false,
	}, model)
	if rng:NextNumber() < lightChance then
		glow(gills, glowColor, capW * 1.6, 1.5)
	end
	for _ = 1, math.floor(capW / 3) do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(0.5, capW * 0.4)
		block(
			model,
			"Spot",
			Vector3.new(capW * 0.1, 0.3, capW * 0.1),
			at(ground, math.cos(a) * r, h + 0.5 + capW * 0.12, math.sin(a) * r),
			M.Neon,
			rgb(255, 246, 230),
			true
		)
	end
end

function trees.bigmushroom(model: Model, ground: Vector3, rng: Random)
	mushroom(model, ground, rng:NextNumber(8, 18), rng:NextNumber(9, 16), rng, 0.35)
end

-- tall and thin with a pointed, stacked cap
function trees.conemushroom(model: Model, ground: Vector3, rng: Random)
	local h = rng:NextNumber(12, 20)
	Build.cylinder(
		ground + Vector3.new(0, h / 2 - 0.5, 0),
		1.6,
		h,
		{ Name = "Stem", Material = M.SmoothPlastic, Color = rgb(214, 206, 230) },
		model
	)
	local cap = pick(rng, CAPS)
	local w = rng:NextNumber(6, 8)
	for i = 0, 3 do
		Build.cylinder(ground + Vector3.new(0, h + i * 1.3, 0), w * (1 - i * 0.24), 1.4, {
			Name = "Cap",
			Material = M.SmoothPlastic,
			Color = if i % 2 == 0 then cap else cap:Lerp(Color3.new(1, 1, 1), 0.15),
		}, model)
	end
	local tip =
		block(model, "Tip", Vector3.new(0.8, 0.8, 0.8), at(ground, 0, h + 5.4, 0), M.Neon, pick(rng, GLOW), true)
	if rng:NextNumber() < 0.4 then
		glow(tip, tip.Color, 14, 1.4)
	end
end

function trees.mushroomcluster(model: Model, ground: Vector3, rng: Random)
	for i = 1, 3 do
		local a = i * 2.1 + rng:NextNumber(-0.3, 0.3)
		local r = if i == 1 then 0 else rng:NextNumber(3, 4.5)
		mushroom(
			model,
			ground + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r),
			rng:NextNumber(3, 8),
			rng:NextNumber(4, 7),
			rng,
			0.2
		)
	end
end

---------------------------------------------------------------------------
-- Rocks
---------------------------------------------------------------------------

local rocks = {}

local function boulder(
	parent: Instance,
	ground: Vector3,
	rng: Random,
	material: Enum.Material,
	color: Color3,
	scale: number
): (Part, Vector3)
	local size = Vector3.new(rng:NextNumber(4, 11), rng:NextNumber(3, 7), rng:NextNumber(4, 11)) * scale
	local p = block(
		parent,
		"Rock",
		size,
		at(ground, 0, size.Y * 0.25, 0)
			* CFrame.Angles(rng:NextNumber(-0.2, 0.2), rng:NextNumber(0, math.pi * 2), rng:NextNumber(-0.2, 0.2)),
		material,
		color
	)
	return p, size
end

function rocks.stone(parent: Instance, ground: Vector3, rng: Random)
	local model = Build.model("Rocks", parent)
	boulder(model, ground, rng, if rng:NextNumber() < 0.5 then M.Rock else M.Slate, pick(rng, STONE), 1)
	if rng:NextNumber() < 0.5 then
		boulder(
			model,
			ground + Vector3.new(rng:NextNumber(-5, 5), 0, rng:NextNumber(-5, 5)),
			rng,
			M.Rock,
			pick(rng, STONE),
			0.45
		)
	end
end

function rocks.mossystone(parent: Instance, ground: Vector3, rng: Random)
	local model = Build.model("MossyStone", parent)
	local rock, size = boulder(model, ground, rng, M.Rock, pick(rng, STONE), 1)
	block(
		model,
		"Moss",
		Vector3.new(size.X * 0.85, 0.6, size.Z * 0.85),
		rock.CFrame * CFrame.new(0, size.Y / 2, 0),
		M.Grass,
		rgb(84, 140, 60)
	)
end

function rocks.snowstone(parent: Instance, ground: Vector3, rng: Random)
	local model = Build.model("SnowStone", parent)
	local rock, size = boulder(model, ground, rng, M.Slate, rgb(100, 110, 130), 1)
	block(
		model,
		"Snow",
		Vector3.new(size.X * 0.9, 0.8, size.Z * 0.9),
		rock.CFrame * CFrame.new(0, size.Y / 2, 0),
		M.Snow,
		rgb(242, 247, 255)
	)
end

function rocks.ice(parent: Instance, ground: Vector3, rng: Random)
	local model = Build.model("IceShards", parent)
	for _ = 1, rng:NextInteger(2, 4) do
		local h = rng:NextNumber(4, 12)
		local w = rng:NextNumber(1.5, 3.5)
		local p = block(
			model,
			"Shard",
			Vector3.new(w, h, w),
			at(ground, rng:NextNumber(-3, 3), h * 0.35, rng:NextNumber(-3, 3))
				* CFrame.Angles(rng:NextNumber(-0.35, 0.35), rng:NextNumber(0, 3), rng:NextNumber(-0.35, 0.35)),
			M.Ice,
			rgb(170, 222, 252)
		)
		p.Transparency = 0.2
	end
end

-- glowing crystals in the map's accent colour
function rocks.crystal(parent: Instance, ground: Vector3, rng: Random, style: Style)
	local model = Build.model("Crystals", parent)
	local a = style.accent
	local b = style.accent:Lerp(rgb(220, 120, 255), 0.6)
	local brightest
	for i = 1, rng:NextInteger(3, 5) do
		local h = if i == 1 then rng:NextNumber(6, 10) else rng:NextNumber(2.5, 6)
		local w = h * 0.3
		local p = block(
			model,
			"Crystal",
			Vector3.new(w, h, w),
			at(ground, rng:NextNumber(-2.5, 2.5), h * 0.35, rng:NextNumber(-2.5, 2.5))
				* CFrame.Angles(rng:NextNumber(-0.4, 0.4), rng:NextNumber(0, 3), rng:NextNumber(-0.4, 0.4)),
			M.Neon,
			if rng:NextNumber() < 0.5 then a else b,
			i > 1
		)
		p.Transparency = 0.15
		brightest = brightest or p
	end
	if rng:NextNumber() < 0.5 then
		glow(brightest, a, 16, 1.4)
	end
end

function rocks.redcrystal(parent: Instance, ground: Vector3, rng: Random)
	local model = Build.model("Crystals", parent)
	local first
	for i = 1, rng:NextInteger(3, 4) do
		local h = if i == 1 then rng:NextNumber(5, 9) else rng:NextNumber(2, 5)
		local p = block(
			model,
			"Crystal",
			Vector3.new(h * 0.3, h, h * 0.3),
			at(ground, rng:NextNumber(-2, 2), h * 0.35, rng:NextNumber(-2, 2))
				* CFrame.Angles(rng:NextNumber(-0.4, 0.4), rng:NextNumber(0, 3), rng:NextNumber(-0.4, 0.4)),
			M.Neon,
			if i % 2 == 0 then rgb(255, 60, 40) else rgb(255, 130, 40),
			i > 1
		)
		first = first or p
	end
	glow(first, rgb(255, 90, 40), 14, 1.5)
end

function rocks.obsidian(parent: Instance, ground: Vector3, rng: Random)
	local model = Build.model("Obsidian", parent)
	local h = rng:NextNumber(6, 16)
	local w = rng:NextNumber(2.5, 5)
	local cf = at(ground, 0, h * 0.4, 0)
		* CFrame.Angles(rng:NextNumber(-0.2, 0.2), rng:NextNumber(0, 3), rng:NextNumber(-0.2, 0.2))
	block(model, "Spire", Vector3.new(w, h, w), cf, M.Glass, rgb(26, 20, 34))
	block(model, "Seam", Vector3.new(w + 0.1, h * 0.7, 0.3), cf, M.Neon, rgb(255, 104, 30), true)
end

-- a cluster of basalt columns (two crossed blocks make each one look many-sided)
function rocks.basalt(parent: Instance, ground: Vector3, rng: Random)
	local model = Build.model("BasaltColumns", parent)
	for _ = 1, rng:NextInteger(4, 7) do
		local x, z = rng:NextNumber(-4, 4), rng:NextNumber(-4, 4)
		local h = rng:NextNumber(3, 12)
		local w = rng:NextNumber(2, 3)
		local base = at(ground, x, h / 2 - 1, z)
		local shade = vary(rgb(52, 48, 52), rng, 0.15)
		block(model, "Column", Vector3.new(w, h, w), base, M.Basalt, shade)
		block(model, "Column", Vector3.new(w, h + 0.2, w), base * CFrame.Angles(0, math.rad(45), 0), M.Basalt, shade)
	end
end

function rocks.sandstone(parent: Instance, ground: Vector3, rng: Random)
	if rng:NextNumber() < 0.35 then
		local model = Build.model("Column", parent)
		local h = rng:NextNumber(5, 14)
		local d = rng:NextNumber(2.5, 3.5)
		Build.cylinder(
			ground + Vector3.new(0, h / 2 - 1, 0),
			d,
			h,
			{ Name = "Column", Material = M.Sandstone, Color = rgb(220, 190, 146) },
			model
		)
		Build.cylinder(
			ground + Vector3.new(0, h - 0.6, 0),
			d + 0.8,
			1,
			{ Name = "Capital", Material = M.Sandstone, Color = rgb(236, 210, 166) },
			model
		)
		return
	end
	boulder(parent, ground, rng, M.Sandstone, vary(rgb(206, 150, 104), rng, 0.1), 1)
end

-- a striped rock tower with a wide cap stone
function rocks.hoodoo(parent: Instance, ground: Vector3, rng: Random)
	local model = Build.model("Hoodoo", parent)
	local y = -1
	local w = rng:NextNumber(4, 6)
	local start = rng:NextInteger(1, #STRATA)
	for i = 1, rng:NextInteger(3, 5) do
		local h = rng:NextNumber(2.5, 4.5)
		block(
			model,
			"Layer",
			Vector3.new(w, h, w * rng:NextNumber(0.85, 1.1)),
			at(ground, 0, y + h / 2, 0) * CFrame.Angles(0, rng:NextNumber(-0.3, 0.3), 0),
			M.Sandstone,
			STRATA[(start + i) % #STRATA + 1]
		)
		y += h
		w *= rng:NextNumber(0.72, 0.9)
	end
	block(
		model,
		"Cap",
		Vector3.new(w * 2.2, 1.6, w * 2),
		at(ground, 0, y + 0.8, 0) * spin(rng),
		M.Sandstone,
		rgb(150, 76, 54)
	)
end

function rocks.mossy(parent: Instance, ground: Vector3, rng: Random)
	local model = Build.model("MossyRock", parent)
	local rock, size = boulder(model, ground, rng, M.Slate, rgb(60, 58, 72), 0.9)
	block(
		model,
		"Moss",
		Vector3.new(size.X * 0.8, 0.5, size.Z * 0.8),
		rock.CFrame * CFrame.new(0, size.Y / 2, 0),
		M.Grass,
		rgb(60, 146, 124)
	)
end

-- a dark rock covered in glowing shelf fungi
function rocks.shelf(parent: Instance, ground: Vector3, rng: Random)
	local model = Build.model("ShelfRock", parent)
	local rock, size = boulder(model, ground, rng, M.Slate, rgb(64, 58, 78), 1)
	local color = pick(rng, GLOW)
	for i = 1, rng:NextInteger(3, 5) do
		local a = i * 1.3 + rng:NextNumber(-0.3, 0.3)
		local cf = rock.CFrame
			* CFrame.new(math.cos(a) * size.X * 0.48, rng:NextNumber(-0.2, 0.35) * size.Y, math.sin(a) * size.Z * 0.48)
		Build.part({
			Name = "Fungus",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.4, 2.4, 2.4),
			CFrame = CFrame.new(cf.Position) * CFrame.Angles(0, 0, math.rad(90)),
			Material = M.Neon,
			Color = color,
			CanCollide = false,
		}, model)
	end
end

---------------------------------------------------------------------------
-- Bushes, flowers and ground clutter
---------------------------------------------------------------------------

local bushes = {}

function bushes.bush(parent: Instance, ground: Vector3, rng: Random)
	local w = rng:NextNumber(3, 5)
	local model = Build.model("Bush", parent)
	local color = pick(rng, LEAVES)
	block(model, "Bush", Vector3.new(w, rng:NextNumber(2, 3.5), w), at(ground, 0, 1, 0) * spin(rng), M.Grass, color)
	block(
		model,
		"Bush",
		Vector3.new(w * 0.6, 2, w * 0.6),
		at(ground, w * 0.3, 1.8, 0) * spin(rng),
		M.Grass,
		vary(color, rng, 0.15)
	)
end

function bushes.berrybush(parent: Instance, ground: Vector3, rng: Random)
	local model = Build.model("BerryBush", parent)
	local w = rng:NextNumber(3, 4.5)
	block(model, "Bush", Vector3.new(w, 2.6, w), at(ground, 0, 1.1, 0) * spin(rng), M.Grass, rgb(58, 120, 56))
	local berry = pick(rng, { rgb(220, 40, 60), rgb(90, 70, 220), rgb(250, 140, 40) })
	for _ = 1, 4 do
		block(
			model,
			"Berry",
			Vector3.new(0.5, 0.5, 0.5),
			at(ground, rng:NextNumber(-w, w) * 0.45, rng:NextNumber(1.6, 2.5), rng:NextNumber(-w, w) * 0.45),
			M.SmoothPlastic,
			berry,
			true
		)
	end
end

function bushes.flower(parent: Instance, ground: Vector3, rng: Random)
	local model = Build.model("Flower", parent)
	local h = rng:NextNumber(0.8, 1.8)
	block(model, "Stem", Vector3.new(0.2, h, 0.2), at(ground, 0, h / 2, 0), M.Grass, rgb(70, 140, 50), true)
	block(
		model,
		"Bloom",
		Vector3.new(0.8, 0.35, 0.8),
		at(ground, 0, h, 0) * spin(rng),
		M.SmoothPlastic,
		pick(rng, FLOWERS),
		true
	)
end

function bushes.desertflower(parent: Instance, ground: Vector3, rng: Random)
	local model = Build.model("Flower", parent)
	block(
		model,
		"Leaves",
		Vector3.new(1.2, 0.4, 1.2),
		at(ground, 0, 0.2, 0) * spin(rng),
		M.Grass,
		rgb(120, 140, 70),
		true
	)
	block(
		model,
		"Bloom",
		Vector3.new(0.7, 0.35, 0.7),
		at(ground, 0, 0.6, 0) * spin(rng),
		M.SmoothPlastic,
		pick(rng, DESERT_FLOWERS),
		true
	)
end

function bushes.glowflower(parent: Instance, ground: Vector3, rng: Random)
	local model = Build.model("GlowFlower", parent)
	local h = rng:NextNumber(1, 2.4)
	block(model, "Stem", Vector3.new(0.2, h, 0.2), at(ground, 0, h / 2, 0), M.Grass, rgb(60, 120, 110), true)
	local bell =
		block(model, "Bell", Vector3.new(0.7, 0.6, 0.7), at(ground, 0, h, 0) * spin(rng), M.Neon, pick(rng, GLOW), true)
	if rng:NextNumber() < 0.08 then
		glow(bell, bell.Color, 10, 1)
	end
end

function bushes.tallgrass(parent: Instance, ground: Vector3, rng: Random)
	local model = Build.model("Grass", parent)
	local color = vary(rgb(110, 166, 66), rng, 0.12)
	for i = 1, 2 do
		local h = rng:NextNumber(1.2, 2.6)
		block(
			model,
			"Blade",
			Vector3.new(0.25, h, 1.4),
			at(ground, rng:NextNumber(-0.6, 0.6), h / 2, rng:NextNumber(-0.6, 0.6))
				* CFrame.Angles(0, i * 1.4, rng:NextNumber(-0.2, 0.2)),
			M.Grass,
			color,
			true
		)
	end
end

function bushes.reeds(parent: Instance, ground: Vector3, rng: Random)
	local model = Build.model("Reeds", parent)
	for _ = 1, 3 do
		local h = rng:NextNumber(2.5, 4.5)
		local x, z = rng:NextNumber(-0.8, 0.8), rng:NextNumber(-0.8, 0.8)
		block(
			model,
			"Reed",
			Vector3.new(0.25, h, 0.25),
			at(ground, x, h / 2 - 0.3, z) * CFrame.Angles(rng:NextNumber(-0.12, 0.12), 0, rng:NextNumber(-0.12, 0.12)),
			M.Grass,
			rgb(96, 130, 60),
			true
		)
	end
	block(
		model,
		"Cattail",
		Vector3.new(0.45, 0.9, 0.45),
		at(ground, 0, rng:NextNumber(3, 4), 0),
		M.Fabric,
		rgb(110, 70, 40),
		true
	)
end

function bushes.log(parent: Instance, ground: Vector3, rng: Random)
	local model = Build.model("Log", parent)
	local len = rng:NextNumber(6, 10)
	local cf = at(ground, 0, 0.7, 0) * spin(rng)
	Build.part({
		Name = "Log",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(len, 1.8, 1.8),
		CFrame = cf,
		Material = M.Wood,
		Color = rgb(104, 74, 50),
	}, model)
	block(model, "Moss", Vector3.new(len * 0.6, 0.4, 1.4), cf * CFrame.new(0, 0.85, 0), M.Grass, rgb(84, 140, 60), true)
	if rng:NextNumber() < 0.5 then
		block(
			model,
			"Mushroom",
			Vector3.new(0.8, 0.5, 0.8),
			cf * CFrame.new(len * 0.3, 1.1, 0),
			M.SmoothPlastic,
			rgb(220, 60, 60),
			true
		)
	end
end

-- a fairy ring of little red-and-white mushrooms
function bushes.mushroomring(parent: Instance, ground: Vector3, rng: Random)
	local model = Build.model("MushroomRing", parent)
	local n = rng:NextInteger(6, 8)
	local r = rng:NextNumber(2.5, 3.5)
	for i = 1, n do
		local a = i / n * math.pi * 2
		local p = ground + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
		block(
			model,
			"Stem",
			Vector3.new(0.35, 0.7, 0.35),
			CFrame.new(p + Vector3.new(0, 0.35, 0)),
			M.SmoothPlastic,
			rgb(240, 236, 226),
			true
		)
		block(
			model,
			"Cap",
			Vector3.new(0.9, 0.35, 0.9),
			CFrame.new(p + Vector3.new(0, 0.8, 0)),
			M.SmoothPlastic,
			rgb(214, 46, 50),
			true
		)
	end
end

function bushes.snowdrift(parent: Instance, ground: Vector3, rng: Random)
	local w = rng:NextNumber(4, 8)
	block(
		parent,
		"Snowdrift",
		Vector3.new(w, rng:NextNumber(1.5, 3), w * rng:NextNumber(0.5, 1)),
		at(ground, 0, 0.6, 0) * spin(rng),
		M.Snow,
		rgb(242, 247, 255)
	)
end

function bushes.frostbush(parent: Instance, ground: Vector3, rng: Random)
	local model = Build.model("FrostBush", parent)
	local w = rng:NextNumber(3, 4.5)
	block(model, "Bush", Vector3.new(w, 2.4, w), at(ground, 0, 1, 0) * spin(rng), M.Grass, rgb(70, 110, 96))
	block(
		model,
		"Frost",
		Vector3.new(w * 0.9, 0.5, w * 0.9),
		at(ground, 0, 2.3, 0) * spin(rng),
		M.Snow,
		rgb(236, 244, 255)
	)
	for _ = 1, 4 do
		block(
			model,
			"Berry",
			Vector3.new(0.5, 0.5, 0.5),
			at(ground, rng:NextNumber(-w, w) * 0.45, rng:NextNumber(1.2, 2.2), rng:NextNumber(-w, w) * 0.45),
			M.SmoothPlastic,
			rgb(220, 30, 50),
			true
		)
	end
end

function bushes.icicles(parent: Instance, ground: Vector3, rng: Random)
	local model = Build.model("Icicles", parent)
	for _ = 1, 3 do
		local h = rng:NextNumber(1.5, 3.5)
		local p = block(
			model,
			"Icicle",
			Vector3.new(0.6, h, 0.6),
			at(ground, rng:NextNumber(-1.2, 1.2), h * 0.4, rng:NextNumber(-1.2, 1.2))
				* CFrame.Angles(rng:NextNumber(-0.3, 0.3), 0, rng:NextNumber(-0.3, 0.3)),
			M.Ice,
			rgb(190, 232, 255),
			true
		)
		p.Transparency = 0.2
	end
end

function bushes.snowman(parent: Instance, ground: Vector3, rng: Random)
	local model = Build.model("Snowman", parent)
	local y = 0
	for i, d in { 4, 3, 2.2 } do
		Build.part({
			Name = "Snow",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(d, d, d),
			CFrame = at(ground, 0, y + d / 2 - 0.2, 0),
			Material = M.Snow,
			Color = rgb(246, 250, 255),
		}, model)
		y += d * (if i == 1 then 0.8 else 0.85)
	end
	local face = at(ground, 0, y - 1.1, 0) * spin(rng)
	block(
		model,
		"Nose",
		Vector3.new(0.35, 0.35, 1.2),
		face * CFrame.new(0, 0, -1.3),
		M.SmoothPlastic,
		rgb(255, 130, 30),
		true
	)
	block(
		model,
		"Scarf",
		Vector3.new(2.6, 0.5, 2.6),
		face * CFrame.new(0, -1, 0),
		M.Fabric,
		pick(rng, { rgb(220, 40, 50), rgb(40, 110, 220), rgb(60, 170, 80) }),
		true
	)
	block(
		model,
		"Hat",
		Vector3.new(1.4, 1.2, 1.4),
		face * CFrame.new(0, 1.4, 0),
		M.SmoothPlastic,
		rgb(30, 30, 36),
		true
	)
end

function bushes.ashpile(parent: Instance, ground: Vector3, rng: Random)
	local w = rng:NextNumber(3, 6)
	local p = block(
		parent,
		"Ash",
		Vector3.new(w, rng:NextNumber(1, 2), w),
		at(ground, 0, 0.4, 0) * spin(rng),
		M.Slate,
		rgb(84, 78, 78)
	)
	if rng:NextNumber() < 0.25 then
		Build.make("Smoke", { Color = rgb(90, 85, 85), Opacity = 0.15, RiseVelocity = 3, Size = 2 }, p)
	end
end

function bushes.embers(parent: Instance, ground: Vector3, rng: Random)
	local model = Build.model("Embers", parent)
	block(model, "Ash", Vector3.new(4, 0.8, 4), at(ground, 0, 0.2, 0) * spin(rng), M.Slate, rgb(60, 54, 54))
	for _ = 1, 3 do
		block(
			model,
			"Ember",
			Vector3.new(0.8, 0.5, 0.8),
			at(ground, rng:NextNumber(-1.4, 1.4), 0.7, rng:NextNumber(-1.4, 1.4)) * spin(rng),
			M.Neon,
			pick(rng, { rgb(255, 120, 30), rgb(255, 70, 30), rgb(255, 180, 60) }),
			true
		)
	end
end

-- a smoking volcanic vent with a lick of fire
function bushes.vent(parent: Instance, ground: Vector3, rng: Random)
	local model = Build.model("Vent", parent)
	for i = 1, 5 do
		local a = i / 5 * math.pi * 2
		block(
			model,
			"Rim",
			Vector3.new(2.5, rng:NextNumber(1.2, 2.2), 1.6),
			at(ground, math.cos(a) * 2.2, 0.6, math.sin(a) * 2.2) * CFrame.Angles(0, -a, 0),
			M.Basalt,
			rgb(44, 38, 40)
		)
	end
	local core =
		block(model, "Core", Vector3.new(2.6, 0.4, 2.6), at(ground, 0, 0.4, 0), M.Neon, rgb(255, 110, 30), true)
	Build.make("Fire", { Size = 5, Heat = 9, Color = rgb(255, 120, 40), SecondaryColor = rgb(255, 60, 20) }, core)
	Build.make("Smoke", { Color = rgb(70, 64, 64), Opacity = 0.25, RiseVelocity = 7, Size = 4 }, core)
	glow(core, rgb(255, 120, 40), 22, 2)
end

-- an old skeleton half buried in the ground
function bushes.bones(parent: Instance, ground: Vector3, rng: Random)
	local model = Build.model("Bones", parent)
	local bone = rgb(232, 224, 200)
	local cf = at(ground, 0, 0.4, 0) * spin(rng)
	block(model, "Spine", Vector3.new(0.6, 0.6, 7), cf, M.SmoothPlastic, bone)
	for i = -2, 2 do
		for side = -1, 1, 2 do
			block(
				model,
				"Rib",
				Vector3.new(0.35, 2.4, 0.35),
				cf * CFrame.new(side * 0.9, 1, i * 1.2) * CFrame.Angles(0, 0, side * math.rad(-28)),
				M.SmoothPlastic,
				bone,
				true
			)
		end
	end
	block(model, "Skull", Vector3.new(1.6, 1.2, 2), cf * CFrame.new(0, 0.4, -4.4), M.SmoothPlastic, bone)
end

function bushes.shrub(parent: Instance, ground: Vector3, rng: Random)
	local w = rng:NextNumber(2, 3.5)
	block(
		parent,
		"Shrub",
		Vector3.new(w, rng:NextNumber(1.2, 2.2), w),
		at(ground, 0, 0.7, 0) * spin(rng),
		M.Grass,
		vary(rgb(136, 126, 72), rng, 0.12)
	)
end

-- a clay pot: terracotta, or glazed blue and turquoise
function bushes.urn(parent: Instance, ground: Vector3, rng: Random)
	local model = Build.model("Urn", parent)
	local color = pick(rng, { rgb(190, 96, 56), rgb(40, 110, 170), rgb(40, 160, 160), rgb(206, 120, 70) })
	local tipped = rng:NextNumber() < 0.3
	local base = at(ground, 0, 1.2, 0)
		* spin(rng)
		* (if tipped then CFrame.Angles(0, 0, math.rad(80)) else CFrame.new())
	Build.part({
		Name = "Body",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(2.4, 2.4, 2.4),
		CFrame = base,
		Material = M.SmoothPlastic,
		Color = color,
	}, model)
	Build.part({
		Name = "Neck",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1.2, 1.2, 1.2),
		CFrame = base * CFrame.new(0, 1.3, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Material = M.SmoothPlastic,
		Color = color:Lerp(rgb(240, 220, 180), 0.35),
	}, model)
end

function bushes.smallmushroom(parent: Instance, ground: Vector3, rng: Random)
	local model = Build.model("Mushroom", parent)
	local h = rng:NextNumber(1, 2.5)
	block(model, "Stem", Vector3.new(0.5, h, 0.5), at(ground, 0, h / 2, 0), M.SmoothPlastic, rgb(230, 225, 210))
	block(model, "Cap", Vector3.new(1.8, 0.6, 1.8), at(ground, 0, h + 0.2, 0), M.Neon, pick(rng, GLOW), true)
end

-- a swarm of fireflies (an invisible anchor that emits glowing motes)
function bushes.fireflies(parent: Instance, ground: Vector3, rng: Random)
	local anchor = Build.part({
		Name = "Fireflies",
		Size = Vector3.new(10, 4, 10),
		CFrame = at(ground, 0, 4, 0),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
	}, parent)
	local color = pick(rng, { rgb(210, 255, 120), rgb(140, 255, 220), rgb(255, 220, 120) })
	Build.make("ParticleEmitter", {
		Color = ColorSequence.new(color),
		LightEmission = 1,
		LightInfluence = 0,
		Size = NumberSequence.new(0.25),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.3, 0),
			NumberSequenceKeypoint.new(0.7, 0),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Lifetime = NumberRange.new(3, 6),
		Rate = 5,
		Speed = NumberRange.new(0.5, 1.5),
		SpreadAngle = Vector2.new(180, 180),
	}, anchor)
	if rng:NextNumber() < 0.4 then
		glow(anchor, color, 12, 0.8)
	end
end

local KINDS = { tree = trees, rock = rocks, bush = bushes }

-- Builds one decoration of the given kind ("tree" | "rock" | "bush") and style name.
function Decor.build(kind: string, styleName: string, parent: Instance, ground: Vector3, rng: Random, style: Style)
	local set = KINDS[kind]
	local fn = set and (set :: any)[styleName]
	if not fn then
		warn("[Decor] unknown decoration " .. kind .. "/" .. styleName)
		return
	end
	if kind == "tree" then
		fn(Build.model("Tree", parent), ground, rng, style)
	else
		fn(parent, ground, rng, style)
	end
end

function Decor.has(kind: string, styleName: string): boolean
	local set = KINDS[kind]
	return set ~= nil and (set :: any)[styleName] ~= nil
end

-- Kinds that shouldn't sit on roads (flowers and grass are fine).
Decor.Blocking = { tree = true, rock = true }

return Decor
