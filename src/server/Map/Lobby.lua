-- The Arcane Athenaeum: a floating library where players wait between matches.
--   * bookshelf walls, marble columns, chandeliers and a rotating orrery (animated on the client)
--   * a glass "scrying window" in the floor looking down at the arena below
--   * Grimoire lecterns (open the encyclopedia) and a class altar (open the class picker)
--   * through the north arch: the open-air Practice Terrace with training dummies

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Build = require(script.Parent.Build)

local Lobby = {}

local M = Enum.Material

export type LobbyInfo = {
	model: Model,
	spawn: CFrame,
	dummySpots: { CFrame },
	floorY: number,
}

-- Library footprint
local X0, X1 = -80, 80
local Z0, Z1 = -60, 60
local WALL_H = 44
local WALL_T = 4
local HOLE = 28 -- scrying window
local SKYLIGHT = 40
local ARCH_HALF = 14
local ARCH_H = 26
-- Terrace footprint (north of the library)
local TX0, TX1 = -60, 60
local TZ0 = -150

local BOOK_COLORS = {
	Color3.fromRGB(140, 30, 40),
	Color3.fromRGB(40, 70, 140),
	Color3.fromRGB(40, 110, 60),
	Color3.fromRGB(120, 80, 30),
	Color3.fromRGB(90, 40, 120),
	Color3.fromRGB(170, 140, 60),
	Color3.fromRGB(60, 60, 70),
	Color3.fromRGB(150, 70, 40),
}
local WOOD = Color3.fromRGB(92, 62, 40)
local DARK_WOOD = Color3.fromRGB(62, 42, 30)
local STONE = Color3.fromRGB(104, 94, 108)
local MARBLE = Color3.fromRGB(226, 220, 210)
local GOLD = Color3.fromRGB(212, 175, 55)
local ARCANE = Color3.fromRGB(165, 115, 255)
local CANDLE = Color3.fromRGB(255, 200, 120)

local function part(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	material: Enum.Material,
	color: Color3,
	extra: { [string]: any }?
): Part
	local props: { [string]: any } = { Name = name, Size = size, CFrame = cf, Material = material, Color = color }
	if extra then
		for k, v in extra do
			props[k] = v
		end
	end
	return Build.part(props, parent)
end

-- A slab with a rectangular hole in the middle, built from four pieces.
local function holedSlab(
	parent: Instance,
	name: string,
	cx: number,
	cz: number,
	w: number,
	d: number,
	hole: number,
	y: number,
	thick: number,
	material: Enum.Material,
	color: Color3
)
	local sideW = (w - hole) / 2
	local sideD = (d - hole) / 2
	part(parent, name, Vector3.new(w, thick, sideD), CFrame.new(cx, y, cz - hole / 2 - sideD / 2), material, color)
	part(parent, name, Vector3.new(w, thick, sideD), CFrame.new(cx, y, cz + hole / 2 + sideD / 2), material, color)
	part(parent, name, Vector3.new(sideW, thick, hole), CFrame.new(cx - hole / 2 - sideW / 2, y, cz), material, color)
	part(parent, name, Vector3.new(sideW, thick, hole), CFrame.new(cx + hole / 2 + sideW / 2, y, cz), material, color)
end

-- A bookshelf whose front faces along `cf.LookVector`; `cf` sits on the floor at the shelf's centre.
local function bookshelf(parent: Instance, cf: CFrame, width: number, height: number, rng: Random)
	local model = Build.model("Bookshelf", parent)
	local depth = 2.6
	part(
		model,
		"Back",
		Vector3.new(width, height, 0.5),
		cf * CFrame.new(0, height / 2, depth / 2 - 0.25),
		M.WoodPlanks,
		DARK_WOOD
	)
	part(
		model,
		"Side",
		Vector3.new(0.6, height, depth),
		cf * CFrame.new(-width / 2 + 0.3, height / 2, 0),
		M.WoodPlanks,
		WOOD
	)
	part(
		model,
		"Side",
		Vector3.new(0.6, height, depth),
		cf * CFrame.new(width / 2 - 0.3, height / 2, 0),
		M.WoodPlanks,
		WOOD
	)
	part(
		model,
		"Top",
		Vector3.new(width + 0.4, 0.6, depth + 0.3),
		cf * CFrame.new(0, height + 0.3, 0),
		M.WoodPlanks,
		WOOD
	)
	local rows = 5
	local rowH = height / rows
	for r = 0, rows - 1 do
		local y = r * rowH
		part(
			model,
			"Shelf",
			Vector3.new(width - 1.2, 0.3, depth - 0.4),
			cf * CFrame.new(0, y + 0.15, 0),
			M.WoodPlanks,
			WOOD
		)
		-- clusters of books of different heights
		local x = -width / 2 + 0.8
		local limit = width / 2 - 0.8
		while x < limit - 0.6 do
			local w = math.min(rng:NextNumber(1.2, 2.6), limit - x)
			if rng:NextNumber() < 0.85 then
				local h = rng:NextNumber(rowH * 0.55, rowH * 0.85)
				local lean = if rng:NextNumber() < 0.12
					then CFrame.Angles(0, 0, math.rad(rng:NextNumber(-12, 12)))
					else CFrame.identity
				part(
					model,
					"Books",
					Vector3.new(w, h, depth - 0.8),
					cf * CFrame.new(x + w / 2, y + 0.3 + h / 2, -0.1) * lean,
					M.SmoothPlastic,
					BOOK_COLORS[rng:NextInteger(1, #BOOK_COLORS)]
				)
			end
			x += w + rng:NextNumber(0.05, 0.4)
		end
	end
end

local function column(parent: Instance, x: number, z: number, y: number)
	part(parent, "Column", Vector3.new(5, WALL_H, 5), CFrame.new(x, y + WALL_H / 2, z), M.Marble, MARBLE)
	part(
		parent,
		"ColumnBase",
		Vector3.new(6.5, 2, 6.5),
		CFrame.new(x, y + 1, z),
		M.Marble,
		MARBLE:Lerp(Color3.new(0, 0, 0), 0.1)
	)
	part(parent, "Capital", Vector3.new(6.5, 2, 6.5), CFrame.new(x, y + WALL_H - 1, z), M.Metal, GOLD)
end

local function chandelier(parent: Instance, center: Vector3, ceilingY: number)
	local model = Build.model("Chandelier", parent)
	part(
		model,
		"Chain",
		Vector3.new(0.3, ceilingY - center.Y, 0.3),
		CFrame.new(center.X, (ceilingY + center.Y) / 2, center.Z),
		M.Metal,
		Color3.fromRGB(50, 45, 40)
	)
	local core = part(
		model,
		"Core",
		Vector3.new(2, 2, 2),
		CFrame.new(center),
		M.Neon,
		CANDLE,
		{ Shape = Enum.PartType.Ball, CanCollide = false }
	)
	Build.make("PointLight", { Color = CANDLE, Range = 48, Brightness = 1.7, Shadows = true }, core)
	local n = 10
	for i = 1, n do
		local a = (i / n) * math.pi * 2
		local p = center + Vector3.new(math.cos(a) * 5, -1, math.sin(a) * 5)
		part(
			model,
			"Ring",
			Vector3.new(3.4, 0.4, 0.5),
			CFrame.lookAt(p, center) * CFrame.Angles(0, math.rad(90), 0),
			M.Metal,
			Color3.fromRGB(60, 52, 44)
		)
		part(
			model,
			"Candle",
			Vector3.new(0.4, 1.2, 0.4),
			CFrame.new(p + Vector3.new(0, 0.8, 0)),
			M.SmoothPlastic,
			Color3.fromRGB(240, 230, 210),
			{ CanCollide = false }
		)
		part(
			model,
			"Flame",
			Vector3.new(0.3, 0.5, 0.3),
			CFrame.new(p + Vector3.new(0, 1.65, 0)),
			M.Neon,
			CANDLE,
			{ CanCollide = false }
		)
	end
end

-- An orrery: three tilted rings of beads around a glowing core. The client spins the rings.
local function orrery(parent: Instance, center: Vector3)
	local animated = Build.make("Folder", { Name = "Animated" }, parent)
	local core = part(
		animated,
		"OrreryCore",
		Vector3.new(5, 5, 5),
		CFrame.new(center),
		M.Neon,
		ARCANE,
		{ Shape = Enum.PartType.Ball, CanCollide = false }
	)
	Build.make("PointLight", { Color = ARCANE, Range = 40, Brightness = 2.5 }, core)
	Build.make("ParticleEmitter", {
		Color = ColorSequence.new(Color3.fromRGB(210, 180, 255)),
		LightEmission = 1,
		Size = NumberSequence.new(0.5, 0),
		Lifetime = NumberRange.new(1, 2),
		Rate = 15,
		Speed = NumberRange.new(1, 3),
		SpreadAngle = Vector2.new(180, 180),
	}, core)
	local rings = {
		{ radius = 7, tilt = CFrame.Angles(math.rad(70), 0, 0), speed = 0.6, color = GOLD },
		{
			radius = 10.5,
			tilt = CFrame.Angles(math.rad(20), 0, math.rad(35)),
			speed = -0.4,
			color = Color3.fromRGB(180, 200, 255),
		},
		{ radius = 14, tilt = CFrame.Angles(math.rad(-30), 0, math.rad(-20)), speed = 0.25, color = GOLD },
	}
	for i, ring in rings do
		local model = Build.model("OrreryRing" .. i, animated)
		model:SetAttribute("Spin", ring.speed)
		local beads = 24
		local base = CFrame.new(center) * ring.tilt
		for b = 1, beads do
			local a = (b / beads) * math.pi * 2
			local p = (base * CFrame.new(math.cos(a) * ring.radius, 0, math.sin(a) * ring.radius)).Position
			part(
				model,
				"Bead",
				Vector3.new(0.6, 0.6, 0.6),
				CFrame.new(p),
				M.Metal,
				ring.color,
				{ CanCollide = false, CanQuery = false }
			)
		end
		local planet = (base * CFrame.new(ring.radius, 0, 0)).Position
		part(
			model,
			"Planet",
			Vector3.new(1.6, 1.6, 1.6),
			CFrame.new(planet),
			M.Neon,
			Color3.fromHSV(i * 0.27, 0.5, 1),
			{
				Shape = Enum.PartType.Ball,
				CanCollide = false,
				CanQuery = false,
			}
		)
	end
	return animated
end

local function floatingBooks(animated: Instance, center: Vector3, rng: Random)
	for i = 1, 12 do
		local a = (i / 12) * math.pi * 2 + rng:NextNumber(-0.2, 0.2)
		local r = rng:NextNumber(20, 30)
		local p = center + Vector3.new(math.cos(a) * r, rng:NextNumber(-6, 6), math.sin(a) * r)
		local model = Build.model("FloatingBook", animated)
		model:SetAttribute("Bob", rng:NextNumber(0, math.pi * 2))
		local cf = CFrame.new(p)
			* CFrame.Angles(rng:NextNumber(-0.4, 0.4), rng:NextNumber(0, 6), rng:NextNumber(-0.4, 0.4))
		part(
			model,
			"Cover",
			Vector3.new(2.2, 0.4, 3),
			cf,
			M.SmoothPlastic,
			BOOK_COLORS[rng:NextInteger(1, #BOOK_COLORS)],
			{
				CanCollide = false,
				CanQuery = false,
			}
		)
		local pages =
			part(model, "Pages", Vector3.new(2, 0.42, 2.8), cf, M.SmoothPlastic, Color3.fromRGB(245, 238, 220), {
				CanCollide = false,
				CanQuery = false,
			})
		Build.make("Sparkles", { SparkleColor = Color3.fromRGB(220, 200, 255) }, pages)
	end
end

local function lectern(parent: Instance, pos: Vector3, facing: Vector3)
	local model = Build.model("Lectern", parent)
	local cf = CFrame.lookAt(pos, pos + facing)
	part(model, "Stand", Vector3.new(1.4, 3.6, 1.4), cf * CFrame.new(0, 1.8, 0), M.WoodPlanks, WOOD)
	part(model, "Foot", Vector3.new(3, 0.4, 3), cf * CFrame.new(0, 0.2, 0), M.WoodPlanks, DARK_WOOD)
	local desk = part(
		model,
		"Desk",
		Vector3.new(3.2, 0.3, 2.4),
		cf * CFrame.new(0, 3.8, 0) * CFrame.Angles(math.rad(-20), 0, 0),
		M.WoodPlanks,
		WOOD
	)
	for side = -1, 1, 2 do
		part(
			model,
			"Page",
			Vector3.new(1.35, 0.12, 1.8),
			desk.CFrame * CFrame.new(side * 0.72, 0.22, 0) * CFrame.Angles(0, 0, math.rad(side * -6)),
			M.SmoothPlastic,
			Color3.fromRGB(248, 240, 220)
		)
	end
	local glow = part(model, "Glow", Vector3.new(0.5, 0.5, 0.5), desk.CFrame * CFrame.new(0, 1.2, 0), M.Neon, ARCANE, {
		Shape = Enum.PartType.Ball,
		CanCollide = false,
	})
	Build.make("PointLight", { Color = ARCANE, Range = 10, Brightness = 1.5 }, glow)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Read"
	prompt.ObjectText = "The Grimoire"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("LobbyAction", "Grimoire")
	prompt.Parent = desk
end

local function readingTable(parent: Instance, center: Vector3, rng: Random)
	local model = Build.model("ReadingTable", parent)
	part(model, "Top", Vector3.new(18, 0.8, 6), CFrame.new(center + Vector3.new(0, 3.2, 0)), M.WoodPlanks, WOOD)
	for _, o in { Vector3.new(-8, 0, -2.4), Vector3.new(8, 0, -2.4), Vector3.new(-8, 0, 2.4), Vector3.new(8, 0, 2.4) } do
		part(
			model,
			"Leg",
			Vector3.new(0.8, 3, 0.8),
			CFrame.new(center + o + Vector3.new(0, 1.5, 0)),
			M.WoodPlanks,
			DARK_WOOD
		)
	end
	for i = -1, 1 do
		for side = -1, 1, 2 do
			part(
				model,
				"Chair",
				Vector3.new(2.4, 1.8, 2.4),
				CFrame.new(center + Vector3.new(i * 5.5, 0.9, side * 5)),
				M.WoodPlanks,
				DARK_WOOD
			)
			part(
				model,
				"ChairBack",
				Vector3.new(2.4, 3, 0.4),
				CFrame.new(center + Vector3.new(i * 5.5, 3.3, side * 6.1)),
				M.WoodPlanks,
				DARK_WOOD
			)
		end
	end
	for i = 1, 4 do
		local p = center + Vector3.new(rng:NextNumber(-7, 7), 3.6, rng:NextNumber(-1.8, 1.8))
		local h = rng:NextNumber(0.6, 1.6)
		part(
			model,
			"BookStack",
			Vector3.new(1.6, h, 2.2),
			CFrame.new(p + Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, rng:NextNumber(0, 3), 0),
			M.SmoothPlastic,
			BOOK_COLORS[i]
		)
	end
	local flame = part(
		model,
		"Candle",
		Vector3.new(0.5, 1.4, 0.5),
		CFrame.new(center + Vector3.new(0, 4.3, 0)),
		M.Neon,
		CANDLE,
		{ CanCollide = false }
	)
	Build.make("PointLight", { Color = CANDLE, Range = 14, Brightness = 1.2 }, flame)
end

local function sign(parent: Instance, cf: CFrame, size: Vector2, title: string, subtitle: string)
	local board = part(parent, "Sign", Vector3.new(size.X, size.Y, 0.6), cf, M.WoodPlanks, DARK_WOOD)
	part(parent, "SignTrim", Vector3.new(size.X + 1, size.Y + 1, 0.4), cf * CFrame.new(0, 0, 0.3), M.Metal, GOLD)
	local gui = Build.make("SurfaceGui", { Face = Enum.NormalId.Front, PixelsPerStud = 20, LightInfluence = 0 }, board)
	Build.make("TextLabel", {
		Size = UDim2.fromScale(1, 0.62),
		BackgroundTransparency = 1,
		Text = title,
		Font = Enum.Font.Fantasy,
		TextScaled = true,
		TextColor3 = Color3.fromRGB(230, 205, 255),
	}, gui)
	Build.make("TextLabel", {
		Size = UDim2.fromScale(1, 0.32),
		Position = UDim2.fromScale(0, 0.64),
		BackgroundTransparency = 1,
		Text = subtitle,
		Font = Enum.Font.GothamBold,
		TextScaled = true,
		TextColor3 = Color3.fromRGB(255, 220, 140),
	}, gui)
end

function Lobby.build(): LobbyInfo
	local existing = workspace:FindFirstChild("Lobby")
	if existing then
		existing:Destroy()
	end
	local rng = Random.new(1337)
	local y = Config.Arena.LobbyHeight
	local model = Build.model("Lobby", workspace)
	local W, D = X1 - X0, Z1 - Z0

	---------------------------------------------------------------- floor
	holedSlab(model, "Floor", 0, 0, W, D, HOLE, y - 2, 4, M.WoodPlanks, Color3.fromRGB(122, 86, 56))
	part(
		model,
		"ScryingWindow",
		Vector3.new(HOLE, 1, HOLE),
		CFrame.new(0, y - 0.5, 0),
		M.Glass,
		Color3.fromRGB(180, 210, 255),
		{
			Transparency = 0.6,
		}
	)
	holedSlab(model, "Rug", 0, 0, HOLE + 14, HOLE + 14, HOLE + 1, y + 0.05, 0.1, M.Fabric, Color3.fromRGB(120, 30, 45))
	holedSlab(model, "RugTrim", 0, 0, HOLE + 16, HOLE + 16, HOLE + 14, y + 0.05, 0.12, M.Fabric, GOLD)
	holedSlab(model, "WindowRim", 0, 0, HOLE + 2, HOLE + 2, HOLE, y + 0.1, 0.25, M.Neon, ARCANE)

	---------------------------------------------------------------- walls
	local wallY = y + WALL_H / 2
	part(
		model,
		"Wall",
		Vector3.new(W + WALL_T * 2, WALL_H, WALL_T),
		CFrame.new(0, wallY, Z1 + WALL_T / 2),
		M.Brick,
		STONE
	)
	part(model, "Wall", Vector3.new(WALL_T, WALL_H, D), CFrame.new(X0 - WALL_T / 2, wallY, 0), M.Brick, STONE)
	part(model, "Wall", Vector3.new(WALL_T, WALL_H, D), CFrame.new(X1 + WALL_T / 2, wallY, 0), M.Brick, STONE)
	-- north wall with the grand arch to the terrace
	local northZ = Z0 - WALL_T / 2
	local sideLen = (W / 2 - ARCH_HALF) + WALL_T
	part(
		model,
		"Wall",
		Vector3.new(sideLen, WALL_H, WALL_T),
		CFrame.new(X0 - WALL_T + sideLen / 2, wallY, northZ),
		M.Brick,
		STONE
	)
	part(
		model,
		"Wall",
		Vector3.new(sideLen, WALL_H, WALL_T),
		CFrame.new(X1 + WALL_T - sideLen / 2, wallY, northZ),
		M.Brick,
		STONE
	)
	part(
		model,
		"ArchLintel",
		Vector3.new(ARCH_HALF * 2, WALL_H - ARCH_H, WALL_T),
		CFrame.new(0, y + ARCH_H + (WALL_H - ARCH_H) / 2, northZ),
		M.Brick,
		STONE
	)
	part(
		model,
		"ArchTrim",
		Vector3.new(ARCH_HALF * 2 + 2, 1.2, WALL_T + 1),
		CFrame.new(0, y + ARCH_H, northZ),
		M.Metal,
		GOLD
	)
	part(model, "Threshold", Vector3.new(ARCH_HALF * 2, 4, WALL_T), CFrame.new(0, y - 2, northZ), M.Marble, MARBLE)
	for side = -1, 1, 2 do
		part(
			model,
			"ArchPillar",
			Vector3.new(2.5, ARCH_H, WALL_T + 1.5),
			CFrame.new(side * (ARCH_HALF + 1.25), y + ARCH_H / 2, northZ),
			M.Marble,
			MARBLE
		)
	end

	-- stained glass windows high on the east and west walls
	for _, x in { X0 + 0.3, X1 - 0.3 } do
		for _, z in { -40, -15, 15, 40 } do
			part(
				model,
				"StainedGlass",
				Vector3.new(0.4, 14, 7),
				CFrame.new(x, y + 30, z),
				M.Neon,
				Color3.fromHSV(rng:NextNumber(0.55, 0.85), 0.45, 0.85),
				{
					Transparency = 0.15,
				}
			)
			part(model, "WindowFrame", Vector3.new(0.6, 15, 0.6), CFrame.new(x, y + 30, z), M.Metal, GOLD)
			part(model, "WindowFrame", Vector3.new(0.6, 0.6, 8), CFrame.new(x, y + 30, z), M.Metal, GOLD)
		end
	end

	---------------------------------------------------------------- ceiling with skylight
	local ceilY = y + WALL_H + 1.5
	holedSlab(model, "Ceiling", 0, 0, W + WALL_T * 2, D + WALL_T * 2, SKYLIGHT, ceilY, 3, M.WoodPlanks, DARK_WOOD)
	part(
		model,
		"Skylight",
		Vector3.new(SKYLIGHT, 0.6, SKYLIGHT),
		CFrame.new(0, ceilY, 0),
		M.Glass,
		Color3.fromRGB(200, 220, 255),
		{
			Transparency = 0.55,
		}
	)
	for i = -1, 1 do
		part(model, "Beam", Vector3.new(W, 2, 2), CFrame.new(0, ceilY - 2.5, i * 30), M.WoodPlanks, DARK_WOOD)
	end

	---------------------------------------------------------------- columns + shelves
	local columnsX = { -60, -30, 30, 60 }
	local columnsZ = { -30, 0, 30 }
	for _, x in columnsX do
		column(model, x, Z1 - 3, y)
		column(model, x, Z0 + 3, y)
	end
	for _, z in columnsZ do
		column(model, X0 + 3, z, y)
		column(model, X1 - 3, z, y)
	end
	local SHELF_W, SHELF_H = 8, 20
	local function nearColumn(v: number, list: { number }): boolean
		for _, c in list do
			if math.abs(v - c) < 7.5 then
				return true
			end
		end
		return false
	end
	-- south and north walls (shelves face into the room)
	for x = X0 + 10, X1 - 10, SHELF_W + 1 do
		if not nearColumn(x, columnsX) then
			bookshelf(model, CFrame.lookAt(Vector3.new(x, y, Z1 - 1.4), Vector3.new(x, y, 0)), SHELF_W, SHELF_H, rng)
			if math.abs(x) > ARCH_HALF + 6 then
				bookshelf(
					model,
					CFrame.lookAt(Vector3.new(x, y, Z0 + 1.4), Vector3.new(x, y, 0)),
					SHELF_W,
					SHELF_H,
					rng
				)
			end
		end
	end
	-- east and west walls
	for z = Z0 + 10, Z1 - 10, SHELF_W + 1 do
		if not nearColumn(z, columnsZ) then
			bookshelf(model, CFrame.lookAt(Vector3.new(X0 + 1.4, y, z), Vector3.new(0, y, z)), SHELF_W, SHELF_H, rng)
			bookshelf(model, CFrame.lookAt(Vector3.new(X1 - 1.4, y, z), Vector3.new(0, y, z)), SHELF_W, SHELF_H, rng)
		end
	end
	-- a free-standing double row of shelves in each side wing
	for _, x in { -52, 52 } do
		for _, z in { -32, 32 } do
			bookshelf(model, CFrame.lookAt(Vector3.new(x, y, z - 1.4), Vector3.new(x, y, z - 10)), SHELF_W * 2, 14, rng)
			bookshelf(model, CFrame.lookAt(Vector3.new(x, y, z + 1.4), Vector3.new(x, y, z + 10)), SHELF_W * 2, 14, rng)
		end
	end

	---------------------------------------------------------------- furniture and light
	for _, cx in { -45, 45 } do
		for _, cz in { -22, 22 } do
			chandelier(model, Vector3.new(cx, y + 32, cz), ceilY - 1.5)
		end
	end
	readingTable(model, Vector3.new(-50, y, 0), rng)
	readingTable(model, Vector3.new(50, y, 0), rng)
	for i = 1, 4 do
		local a = (i / 4) * math.pi * 2 + math.pi / 4
		local p = Vector3.new(math.cos(a) * 25, y, math.sin(a) * 25)
		lectern(model, p, Vector3.new(-p.X, 0, -p.Z))
	end

	local animated = orrery(model, Vector3.new(0, y + 21, 0))
	floatingBooks(animated, Vector3.new(0, y + 16, 0), rng)

	-- class altar near the south wall
	local altarPos = Vector3.new(0, y, 46)
	Build.cylinder(
		altarPos + Vector3.new(0, 1.5, 0),
		7,
		3,
		{ Name = "ClassAltar", Material = M.Marble, Color = MARBLE },
		model
	)
	Build.cylinder(
		altarPos + Vector3.new(0, 3.1, 0),
		7.4,
		0.3,
		{ Name = "AltarTrim", Material = M.Metal, Color = GOLD },
		model
	)
	local crystal = part(
		animated,
		"AltarCrystal",
		Vector3.new(2.4, 4.5, 2.4),
		CFrame.new(altarPos + Vector3.new(0, 7, 0)) * CFrame.Angles(0, math.rad(45), 0),
		M.Neon,
		Color3.fromRGB(255, 200, 90),
		{
			CanCollide = false,
			Transparency = 0.1,
		}
	)
	crystal:SetAttribute("Spin", 1.2)
	Build.make("PointLight", { Color = crystal.Color, Range = 22, Brightness = 2 }, crystal)
	local altarPrompt = Instance.new("ProximityPrompt")
	altarPrompt.ActionText = "Choose class"
	altarPrompt.ObjectText = "Class Altar"
	altarPrompt.HoldDuration = 0
	altarPrompt.MaxActivationDistance = 10
	altarPrompt.RequiresLineOfSight = false
	altarPrompt:SetAttribute("LobbyAction", "ClassPicker")
	altarPrompt.Parent = model:FindFirstChild("ClassAltar")

	-- (a part's Front face points along -Z, i.e. into the room for the south wall)
	sign(
		model,
		CFrame.new(0, y + 30, Z1 - 0.8),
		Vector2.new(44, 9),
		"THE ARCANE ATHENAEUM",
		"Mana Wars  ·  Loot. Craft. Survive."
	)

	-- spawn circle between the window and the altar
	local spawnPos = Vector3.new(0, y + 0.5, 32)
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "LobbySpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(10, 1, 10)
	spawn.CFrame = CFrame.new(spawnPos)
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = model
	Build.cylinder(
		Vector3.new(0, y + 0.12, 32),
		10,
		0.2,
		{ Name = "SpawnRune", Material = M.Neon, Color = ARCANE, CanCollide = false, Transparency = 0.3 },
		model
	)

	---------------------------------------------------------------- practice terrace
	local terrace = Build.model("PracticeTerrace", model)
	local TW, TD = TX1 - TX0, (Z0 - WALL_T) - TZ0
	local tz = (Z0 - WALL_T + TZ0) / 2
	part(terrace, "TerraceFloor", Vector3.new(TW, 4, TD), CFrame.new(0, y - 2, tz), M.Slate, Color3.fromRGB(88, 84, 96))
	-- checkered inlay
	for gx = TX0 + 10, TX1 - 10, 20 do
		for gz = TZ0 + 10, Z0 - WALL_T - 10, 20 do
			if ((gx + gz) // 20) % 2 == 0 then
				part(
					terrace,
					"Tile",
					Vector3.new(19.6, 0.1, 19.6),
					CFrame.new(gx, y + 0.05, gz),
					M.Marble,
					Color3.fromRGB(150, 145, 160)
				)
			end
		end
	end
	-- crenellated parapet
	local function parapet(size: Vector3, cf: CFrame)
		part(terrace, "Parapet", size, cf, M.Brick, STONE)
	end
	parapet(Vector3.new(TW, 3, 2), CFrame.new(0, y + 1.5, TZ0 + 1))
	parapet(Vector3.new(2, 3, TD), CFrame.new(TX0 + 1, y + 1.5, tz))
	parapet(Vector3.new(2, 3, TD), CFrame.new(TX1 - 1, y + 1.5, tz))
	for x = TX0 + 4, TX1 - 4, 8 do
		parapet(Vector3.new(3, 2, 2), CFrame.new(x, y + 4, TZ0 + 1))
	end
	for z = TZ0 + 4, Z0 - WALL_T - 4, 8 do
		parapet(Vector3.new(2, 2, 3), CFrame.new(TX0 + 1, y + 4, z))
		parapet(Vector3.new(2, 2, 3), CFrame.new(TX1 - 1, y + 4, z))
	end
	-- lanterns on the parapet
	for _, p in
		{
			Vector3.new(TX0 + 1, y + 6, -80),
			Vector3.new(TX1 - 1, y + 6, -80),
			Vector3.new(TX0 + 1, y + 6, -120),
			Vector3.new(TX1 - 1, y + 6, -120),
		}
	do
		part(
			terrace,
			"LanternPost",
			Vector3.new(0.6, 3, 0.6),
			CFrame.new(p - Vector3.new(0, 1.5, 0)),
			M.Metal,
			Color3.fromRGB(50, 45, 40)
		)
		local lamp = part(
			terrace,
			"Lantern",
			Vector3.new(1.4, 1.6, 1.4),
			CFrame.new(p + Vector3.new(0, 0.6, 0)),
			M.Neon,
			CANDLE,
			{ CanCollide = false }
		)
		Build.make("PointLight", { Color = CANDLE, Range = 30, Brightness = 1.6 }, lamp)
	end
	-- firing line
	part(terrace, "FiringLine", Vector3.new(TW - 8, 0.12, 1), CFrame.new(0, y + 0.08, -85), M.Neon, GOLD)
	sign(
		terrace,
		CFrame.new(0, y + 8, TZ0 + 3) * CFrame.Angles(0, math.pi, 0),
		Vector2.new(30, 7),
		"PRACTICE RANGE",
		"Try your spells on the dummies"
	)
	-- dummy platforms
	local dummySpots: { CFrame } = {}
	for i = -2, 2 do
		local p = Vector3.new(i * 22, y, -132)
		Build.cylinder(
			p + Vector3.new(0, 0.3, 0),
			7,
			0.6,
			{ Name = "DummyPad", Material = M.Marble, Color = MARBLE },
			terrace
		)
		Build.cylinder(
			p + Vector3.new(0, 0.62, 0),
			6,
			0.1,
			{ Name = "DummyRune", Material = M.Neon, Color = Color3.fromRGB(255, 90, 90), CanCollide = false },
			terrace
		)
		table.insert(dummySpots, CFrame.lookAt(p + Vector3.new(0, 0.6, 0), Vector3.new(i * 22, y + 0.6, 0)))
	end

	---------------------------------------------------------------- invisible containment
	local barrier = { Transparency = 1, CanQuery = false }
	local function wall(size: Vector3, pos: Vector3)
		local props = table.clone(barrier)
		props.Name = "Barrier"
		props.Size = size
		props.CFrame = CFrame.new(pos)
		Build.part(props, terrace)
	end
	wall(Vector3.new(TW, 90, 2), Vector3.new(0, y + 45, TZ0 - 1))
	wall(Vector3.new(2, 90, TD), Vector3.new(TX0 - 1, y + 45, tz))
	wall(Vector3.new(2, 90, TD), Vector3.new(TX1 + 1, y + 45, tz))
	wall(Vector3.new(TW, 2, TD), Vector3.new(0, y + 90, tz))

	---------------------------------------------------------------- the island underneath
	for i = 1, 4 do
		local shrink = i * 14
		local layerY = y - 8 - (i - 1) * 8
		holedSlab(model, "Underside", 0, 0, W - shrink, D - shrink, HOLE, layerY, 8, M.Rock, Color3.fromRGB(90, 85, 80))
		part(
			model,
			"Underside",
			Vector3.new(TW - shrink, 8, TD - shrink * 0.6),
			CFrame.new(0, layerY, tz),
			M.Rock,
			Color3.fromRGB(90, 85, 80)
		)
	end
	for _, child in model:GetChildren() do
		if child.Name == "Underside" and child:IsA("BasePart") then
			child.CanQuery = false
		end
	end

	return {
		model = model,
		spawn = CFrame.new(spawnPos + Vector3.new(0, 3.5, 0)), -- facing north, toward the orrery and the arch
		dummySpots = dummySpots,
		floorY = y,
	}
end

return Lobby
