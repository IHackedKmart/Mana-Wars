-- Arcanum Plaza: the hub every player spawns in. Hang out, practise as long as you like, and walk
-- through the portal when you want to play; that puts you in the queue and sends you to the
-- library (the Arcane Athenaeum), where the map vote for the next match happens.
--   * a mana fountain at the heart of a cobbled plaza, benches, lamps, market stalls, wizard towers
--   * north: the portal to the Athenaeum ("join the game")
--   * east: a big Practice Range with standing and moving training dummies
--   * west: a gazebo with the Class Altar and Grimoire lecterns
--   * south: the Tailor's Loom and Coffer stalls (Enchanted Coin loot boxes, crafting robes and
--     hats) and the Gilded Gavel, the auction house pavilion
--   * by the spawn: a welcome board and a live "next match" board

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Build = require(script.Parent.Build)
local Props = require(script.Parent.Props)
local Decor = require(script.Parent.Decor)
local MapDefs = require(script.Parent.MapDefs)

-- the Plaza's gardens use the Verdant Isle look
local GARDEN = MapDefs.List[1].style
local Hub = {}

local M = Enum.Material
local part = Props.part

export type DummySpot = {
	cframe: CFrame,
	travel: Vector3?, -- moving dummies slide back and forth by up to this offset
}

export type HubInfo = {
	model: Model,
	spawn: CFrame,
	dummySpots: { DummySpot },
	joinPortal: BasePart,
	boardText: TextLabel, -- the live "next match" board
	leaderboard: Leaderboard, -- the Hall of Champions (filled in by LeaderboardService)
	floorY: number,
}

export type Leaderboard = { wins: TextLabel, kills: TextLabel, footer: TextLabel }

-- Far enough from the arena and the library that they never get in each other's way.
Hub.CENTER_Z = 700

local R = 110 -- plaza radius
local RIM = 18 -- grass ring around the cobbles
-- practice range annex, east of the plaza (local coordinates)
local RX0, RX1, RZ = 96, 196, 46

local COBBLE = Color3.fromRGB(150, 142, 135)
local GRASS = Color3.fromRGB(96, 150, 70)
local WATER = Color3.fromRGB(90, 220, 255)
local ROOF = Color3.fromRGB(80, 50, 130)
local IRON = Color3.fromRGB(45, 40, 38)

-- A board on two posts (standing on groundY) with a title and a multi-line body. Returns the body label.
local function board(
	parent: Instance,
	cf: CFrame,
	size: Vector2,
	groundY: number,
	title: string,
	body: string
): TextLabel
	local model = Build.model("Board", parent)
	local face = part(model, "BoardFace", Vector3.new(size.X, size.Y, 0.6), cf, M.WoodPlanks, Props.DARK_WOOD)
	part(model, "BoardTrim", Vector3.new(size.X + 1, size.Y + 1, 0.4), cf * CFrame.new(0, 0, 0.3), M.Metal, Props.GOLD)
	local postH = cf.Position.Y + size.Y / 2 - groundY
	for side = -1, 1, 2 do
		part(
			model,
			"BoardPost",
			Vector3.new(0.8, postH, 0.8),
			cf * CFrame.new(side * (size.X / 2 - 1), groundY + postH / 2 - cf.Position.Y, 0.8),
			M.WoodPlanks,
			Props.WOOD
		)
	end
	local gui = Build.make("SurfaceGui", { Face = Enum.NormalId.Front, PixelsPerStud = 24, LightInfluence = 0 }, face)
	Build.make("TextLabel", {
		Name = "Title",
		Size = UDim2.fromScale(1, 0.22),
		Position = UDim2.fromScale(0, 0.03),
		BackgroundTransparency = 1,
		Text = title,
		Font = Enum.Font.Fantasy,
		TextScaled = true,
		TextColor3 = Color3.fromRGB(230, 205, 255),
	}, gui)
	return Build.make("TextLabel", {
		Name = "Body",
		Size = UDim2.fromScale(0.92, 0.68),
		Position = UDim2.fromScale(0.04, 0.28),
		BackgroundTransparency = 1,
		Text = body,
		RichText = true,
		Font = Enum.Font.GothamBold,
		TextScaled = true,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextColor3 = Color3.fromRGB(255, 235, 190),
	}, gui)
end

-- The Hall of Champions: a tall gilded board with two columns, most wins and most kills.
local function hallOfChampions(parent: Instance, cf: CFrame, groundY: number): Leaderboard
	local model = Build.model("Leaderboard", parent)
	local size = Vector2.new(30, 17)
	local face = part(model, "BoardFace", Vector3.new(size.X, size.Y, 0.6), cf, M.WoodPlanks, Props.DARK_WOOD)
	part(
		model,
		"BoardTrim",
		Vector3.new(size.X + 1.2, size.Y + 1.2, 0.4),
		cf * CFrame.new(0, 0, 0.3),
		M.Metal,
		Props.GOLD
	)
	-- a crest on top and pillars at the sides
	part(model, "Crest", Vector3.new(8, 3, 0.8), cf * CFrame.new(0, size.Y / 2 + 1.6, 0.1), M.Metal, Props.GOLD)
	local gem = part(
		model,
		"CrestGem",
		Vector3.new(1.6, 1.6, 0.4),
		cf * CFrame.new(0, size.Y / 2 + 1.6, -0.4) * CFrame.Angles(0, 0, math.rad(45)),
		M.Neon,
		Props.ARCANE,
		{ CanCollide = false }
	)
	Build.make("PointLight", { Color = Props.ARCANE, Range = 16, Brightness = 1.5 }, gem)
	local postH = cf.Position.Y + size.Y / 2 - groundY
	for side = -1, 1, 2 do
		part(
			model,
			"BoardPillar",
			Vector3.new(1.6, postH + 2, 1.6),
			cf * CFrame.new(side * (size.X / 2 + 1.2), groundY + (postH + 2) / 2 - cf.Position.Y, 0.2),
			M.Marble,
			Props.MARBLE
		)
		Props.lantern(model, (cf * CFrame.new(side * (size.X / 2 + 1.2), size.Y / 2 + 2, 0.2)).Position, 1)
	end
	local gui = Build.make("SurfaceGui", { Face = Enum.NormalId.Front, PixelsPerStud = 24, LightInfluence = 0 }, face)
	Build.make("TextLabel", {
		Name = "Title",
		Size = UDim2.fromScale(1, 0.14),
		Position = UDim2.fromScale(0, 0.02),
		BackgroundTransparency = 1,
		Text = "🏆 Hall of Champions",
		Font = Enum.Font.Fantasy,
		TextScaled = true,
		TextColor3 = Color3.fromRGB(255, 215, 110),
	}, gui)
	local function column(x: number, heading: string): TextLabel
		Build.make("TextLabel", {
			Name = "Heading",
			Size = UDim2.fromScale(0.44, 0.08),
			Position = UDim2.fromScale(x, 0.17),
			BackgroundTransparency = 1,
			Text = heading,
			Font = Enum.Font.GothamBlack,
			TextScaled = true,
			TextColor3 = Color3.fromRGB(230, 205, 255),
		}, gui)
		return Build.make("TextLabel", {
			Name = "Column",
			Size = UDim2.fromScale(0.44, 0.66),
			Position = UDim2.fromScale(x, 0.26),
			BackgroundTransparency = 1,
			Text = "Loading...",
			RichText = true,
			Font = Enum.Font.GothamBold,
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextColor3 = Color3.fromRGB(255, 235, 190),
		}, gui)
	end
	local wins = column(0.04, "⚔️ MOST WINS")
	local kills = column(0.52, "💀 MOST KILLS")
	local footer = Build.make("TextLabel", {
		Name = "Footer",
		Size = UDim2.fromScale(0.92, 0.05),
		Position = UDim2.fromScale(0.04, 0.93),
		BackgroundTransparency = 1,
		Text = "All servers, all time",
		Font = Enum.Font.Gotham,
		TextScaled = true,
		TextColor3 = Color3.fromRGB(170, 160, 190),
	}, gui)
	return { wins = wins, kills = kills, footer = footer }
end

local function fountain(parent: Instance, animated: Instance, c: Vector3)
	local model = Build.model("ManaFountain", parent)
	Build.cylinder(
		c + Vector3.new(0, 1.2, 0),
		26,
		2.4,
		{ Name = "Basin", Material = M.Marble, Color = Props.MARBLE },
		model
	)
	Build.cylinder(
		c + Vector3.new(0, 2.45, 0),
		23,
		0.1,
		{ Name = "Water", Material = M.Neon, Color = WATER, Transparency = 0.25 },
		model
	)
	Build.cylinder(
		c + Vector3.new(0, 6.4, 0),
		4,
		8,
		{ Name = "Pillar", Material = M.Marble, Color = Props.MARBLE },
		model
	)
	Build.cylinder(
		c + Vector3.new(0, 10.4, 0),
		12,
		1.2,
		{ Name = "Bowl", Material = M.Marble, Color = Props.MARBLE },
		model
	)
	Build.cylinder(
		c + Vector3.new(0, 10.4, 0),
		12.4,
		0.4,
		{ Name = "BowlTrim", Material = M.Metal, Color = Props.GOLD },
		model
	)
	local upper = Build.cylinder(
		c + Vector3.new(0, 11.05, 0),
		10.5,
		0.1,
		{ Name = "Water", Material = M.Neon, Color = WATER, Transparency = 0.2, CanCollide = false },
		model
	)
	Build.make("ParticleEmitter", {
		Color = ColorSequence.new(WATER, Color3.fromRGB(200, 170, 255)),
		LightEmission = 1,
		Size = NumberSequence.new(0.5, 0.1),
		Transparency = NumberSequence.new(0, 1),
		Lifetime = NumberRange.new(1.2, 1.8),
		Rate = 45,
		Speed = NumberRange.new(7, 11),
		Acceleration = Vector3.new(0, -12, 0),
		SpreadAngle = Vector2.new(18, 18),
		EmissionDirection = Enum.NormalId.Top,
	}, upper)
	local crystal = part(
		animated,
		"FountainCrystal",
		Vector3.new(3, 6, 3),
		CFrame.new(c + Vector3.new(0, 17, 0)) * CFrame.Angles(0, math.rad(45), 0),
		M.Neon,
		Props.ARCANE,
		{ CanCollide = false, Transparency = 0.05 }
	)
	crystal:SetAttribute("Spin", 0.8)
	Build.make("PointLight", { Color = Props.ARCANE, Range = 45, Brightness = 2.5 }, crystal)
	for i = 1, 4 do
		local a = i * math.pi / 2
		local rune = Build.model("FloatingRune", animated)
		rune:SetAttribute("Bob", i * 1.7)
		part(
			rune,
			"Rune",
			Vector3.new(1.2, 1.2, 1.2),
			CFrame.new(c + Vector3.new(math.cos(a) * 6, 15, math.sin(a) * 6)) * CFrame.Angles(0.6, a, 0.6),
			M.Neon,
			Color3.fromRGB(255, 210, 120),
			{ CanCollide = false, CanQuery = false }
		)
	end
end

local function bench(parent: Instance, pos: Vector3, lookAt: Vector3)
	local model = Build.model("Bench", parent)
	local cf = CFrame.lookAt(pos, Vector3.new(lookAt.X, pos.Y, lookAt.Z))
	part(model, "Seat", Vector3.new(7, 0.6, 2.2), cf * CFrame.new(0, 1.7, 0), M.WoodPlanks, Props.WOOD)
	part(model, "BackRest", Vector3.new(7, 2.2, 0.4), cf * CFrame.new(0, 3, 1.1), M.WoodPlanks, Props.WOOD)
	for side = -1, 1, 2 do
		part(model, "Leg", Vector3.new(0.6, 1.4, 2), cf * CFrame.new(side * 3, 0.7, 0), M.Metal, IRON)
	end
end

local function tower(parent: Instance, base: Vector3, faceToward: Vector3, rng: Random)
	local model = Build.model("WizardTower", parent)
	local h = rng:NextNumber(40, 52)
	Build.cylinder(
		base + Vector3.new(0, h / 2, 0),
		14,
		h,
		{ Name = "Tower", Material = M.Cobblestone, Color = Props.STONE },
		model
	)
	Build.cylinder(
		base + Vector3.new(0, h + 0.5, 0),
		16,
		1,
		{ Name = "Ledge", Material = M.Metal, Color = Props.GOLD },
		model
	)
	-- a stepped conical roof
	for i = 0, 6 do
		local d = 17 - i * 2.4
		Build.cylinder(
			base + Vector3.new(0, h + 2 + i * 2.2, 0),
			d,
			2.2,
			{ Name = "Roof", Material = M.Slate, Color = ROOF:Lerp(Color3.new(0, 0, 0), i * 0.04) },
			model
		)
	end
	local tip = part(
		model,
		"Finial",
		Vector3.new(1.6, 1.6, 1.6),
		CFrame.new(base + Vector3.new(0, h + 18.5, 0)),
		M.Neon,
		Props.GOLD,
		{ Shape = Enum.PartType.Ball }
	)
	Build.make("PointLight", { Color = Props.GOLD, Range = 18, Brightness = 1.5 }, tip)
	-- door facing the plaza and a few glowing windows
	local look = CFrame.lookAt(base, Vector3.new(faceToward.X, base.Y, faceToward.Z))
	part(model, "Door", Vector3.new(4, 7, 0.6), look * CFrame.new(0, 3.5, -6.9), M.WoodPlanks, Props.DARK_WOOD)
	for _, wy in { h * 0.45, h * 0.75 } do
		for k = -1, 1 do
			local around = look * CFrame.Angles(0, k * math.rad(70), 0)
			part(
				model,
				"Window",
				Vector3.new(1.6, 3.2, 0.4),
				around * CFrame.new(0, wy, -7),
				M.Neon,
				Props.CANDLE,
				{ CanCollide = false }
			)
		end
	end
end

-- A promptable station (opens a window on the client through the prompt's LobbyAction).
local function stationPrompt(on: BasePart, actionText: string, objectText: string, lobbyAction: string)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = actionText
	prompt.ObjectText = objectText
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 11
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("LobbyAction", lobbyAction)
	prompt.Parent = on
end

-- A market stall. `goods` is what's on the counter: "potions", "cloth" (the tailor) or "coffers".
local function stall(
	parent: Instance,
	pos: Vector3,
	lookAt: Vector3,
	awning: Color3,
	rng: Random,
	goods: string?
): (Model, BasePart, CFrame)
	local model = Build.model("MarketStall", parent)
	local cf = CFrame.lookAt(pos, Vector3.new(lookAt.X, pos.Y, lookAt.Z))
	local counter = part(model, "Counter", Vector3.new(10, 3, 3), cf * CFrame.new(0, 1.5, 0), M.WoodPlanks, Props.WOOD)
	for _, o in { Vector3.new(-5, 0, -1.5), Vector3.new(5, 0, -1.5), Vector3.new(-5, 0, 3.5), Vector3.new(5, 0, 3.5) } do
		part(
			model,
			"Post",
			Vector3.new(0.6, 8, 0.6),
			cf * CFrame.new(o + Vector3.new(0, 4, 0)),
			M.WoodPlanks,
			Props.DARK_WOOD
		)
	end
	for i = 0, 4 do
		part(
			model,
			"Awning",
			Vector3.new(2.4, 0.3, 7),
			cf * CFrame.new(-4.8 + i * 2.4, 8.4, 1) * CFrame.Angles(math.rad(-12), 0, 0),
			M.Fabric,
			if i % 2 == 0 then awning else Color3.fromRGB(240, 230, 210),
			{ CanCollide = false }
		)
	end
	if goods == "cloth" then
		-- bolts of cloth and a dressmaker's mannequin wearing a half-finished robe
		for i = 1, 5 do
			part(
				model,
				"ClothBolt",
				Vector3.new(4.2, 1.1, 1.1),
				cf * CFrame.new(-3.8 + i * 1.25, 3.55, rng:NextNumber(-0.5, 0.5)) * CFrame.Angles(0, math.rad(90), 0),
				M.Fabric,
				Color3.fromHSV((i * 0.17 + 0.6) % 1, 0.65, 0.85),
				{ Shape = Enum.PartType.Cylinder, CanCollide = false }
			)
		end
		part(model, "MannequinStand", Vector3.new(0.4, 3.5, 0.4), cf * CFrame.new(6.8, 1.75, -1), M.Metal, IRON)
		part(
			model,
			"MannequinBody",
			Vector3.new(2, 2.4, 1),
			cf * CFrame.new(6.8, 4.6, -1),
			M.Fabric,
			Color3.fromRGB(110, 40, 150)
		)
		part(
			model,
			"MannequinSkirt",
			Vector3.new(2.6, 2, 1.6),
			cf * CFrame.new(6.8, 2.6, -1),
			M.Fabric,
			Color3.fromRGB(90, 30, 125),
			{ CanCollide = false }
		)
		part(
			model,
			"MannequinHat",
			Vector3.new(1.6, 2, 1.6),
			cf * CFrame.new(6.8, 6.6, -1),
			M.Fabric,
			Color3.fromRGB(60, 30, 100),
			{ CanCollide = false }
		)
	elseif goods == "coffers" then
		-- the five coffers, cheapest to grandest, each in its tier's colour
		local tints = {
			Color3.fromRGB(140, 110, 80),
			Color3.fromRGB(90, 170, 90),
			Color3.fromRGB(80, 130, 230),
			Color3.fromRGB(170, 90, 230),
			Color3.fromRGB(255, 190, 60),
		}
		for i, tint in tints do
			local size = 0.9 + i * 0.12
			local box = part(
				model,
				"Coffer",
				Vector3.new(size * 1.3, size, size),
				cf * CFrame.new(-4.6 + i * 1.55, 3 + size / 2, 0),
				M.WoodPlanks,
				tint,
				{ CanCollide = false }
			)
			part(
				model,
				"CofferBand",
				Vector3.new(size * 1.32, size * 0.2, size * 1.02),
				box.CFrame * CFrame.new(0, size * 0.15, 0),
				M.Metal,
				Props.GOLD,
				{ CanCollide = false }
			)
			if i == 5 then
				Build.make("PointLight", { Color = tint, Range = 9, Brightness = 1.6 }, box)
				Build.make("Sparkles", { SparkleColor = tint }, box)
			end
		end
	else
		for i = 1, 7 do
			local potion = part(
				model,
				"Potion",
				Vector3.new(0.9, 0.9, 0.9),
				cf * CFrame.new(-4 + i * 1.05, 3.45, rng:NextNumber(-0.6, 0.6)),
				M.Neon,
				Color3.fromHSV(rng:NextNumber(), 0.7, 1),
				{ Shape = Enum.PartType.Ball, CanCollide = false }
			)
			potion.Transparency = 0.15
		end
	end
	return model, counter, cf
end

-- The Gilded Gavel: an open marble pavilion with the auctioneer's podium and a spinning gold coin.
local function auctionHouse(parent: Instance, animated: Instance, c: Vector3, lookAt: Vector3)
	local model = Build.model("AuctionHouse", parent)
	local cf = CFrame.lookAt(c, Vector3.new(lookAt.X, c.Y, lookAt.Z))
	part(model, "PavilionFloor", Vector3.new(24, 0.8, 24), cf * CFrame.new(0, 0.4, 0), M.Marble, Props.MARBLE)
	part(model, "PavilionStep", Vector3.new(14, 0.4, 3), cf * CFrame.new(0, 0.2, -13.4), M.Marble, Props.MARBLE)
	part(
		model,
		"PavilionRug",
		Vector3.new(16, 0.1, 16),
		cf * CFrame.new(0, 0.85, 0),
		M.Fabric,
		Color3.fromRGB(130, 25, 40)
	)
	for _, o in { { -10, -10 }, { 10, -10 }, { -10, 10 }, { 10, 10 } } do
		part(
			model,
			"PavilionColumn",
			Vector3.new(1.8, 13, 1.8),
			cf * CFrame.new(o[1], 7.3, o[2]),
			M.Marble,
			Props.MARBLE
		)
		part(model, "ColumnCap", Vector3.new(2.4, 0.6, 2.4), cf * CFrame.new(o[1], 13.9, o[2]), M.Metal, Props.GOLD)
	end
	for i = 0, 3 do
		local w = 26 - i * 6
		part(
			model,
			"PavilionRoof",
			Vector3.new(w, 1.2, w),
			cf * CFrame.new(0, 14.8 + i * 1.2, 0),
			M.Slate,
			if i % 2 == 0 then Color3.fromRGB(120, 30, 45) else Props.GOLD
		)
	end
	-- the podium with its gavel
	local podium =
		part(model, "Podium", Vector3.new(5, 3.6, 2.6), cf * CFrame.new(0, 2.6, 3), M.WoodPlanks, Props.DARK_WOOD)
	part(model, "PodiumTop", Vector3.new(5.6, 0.3, 3.2), cf * CFrame.new(0, 4.55, 3), M.Metal, Props.GOLD)
	part(
		model,
		"GavelHandle",
		Vector3.new(0.25, 0.25, 2),
		cf * CFrame.new(0.8, 4.9, 3) * CFrame.Angles(0, math.rad(30), 0),
		M.WoodPlanks,
		Props.WOOD,
		{ CanCollide = false }
	)
	part(
		model,
		"GavelHead",
		Vector3.new(1.1, 0.55, 0.55),
		cf * CFrame.new(0.8, 4.95, 2.1) * CFrame.Angles(0, math.rad(30), 0),
		M.WoodPlanks,
		Props.DARK_WOOD,
		{ CanCollide = false }
	)
	-- display pedestals with sample wares
	for side = -1, 1, 2 do
		part(model, "Pedestal", Vector3.new(2, 3, 2), cf * CFrame.new(side * 7, 2.3, 4), M.Marble, Props.MARBLE)
		local ware = part(
			model,
			"Ware",
			Vector3.new(1.2, 1.2, 1.2),
			cf * CFrame.new(side * 7, 4.6, 4),
			M.Neon,
			if side < 0 then Color3.fromRGB(255, 140, 60) else Color3.fromRGB(120, 200, 255),
			{ Shape = Enum.PartType.Ball, CanCollide = false }
		)
		Build.make("PointLight", { Color = ware.Color, Range = 8, Brightness = 1.2 }, ware)
	end
	local coin = part(
		animated,
		"AuctionCoin",
		Vector3.new(0.6, 4.5, 4.5),
		cf * CFrame.new(0, 10, 0),
		M.Neon,
		Color3.fromRGB(255, 205, 70),
		{ Shape = Enum.PartType.Cylinder, CanCollide = false }
	)
	coin:SetAttribute("Spin", 1.5)
	Build.make("PointLight", { Color = coin.Color, Range = 20, Brightness = 2 }, coin)
	Props.sign(
		model,
		cf * CFrame.new(0, 11.8, -10.4),
		Vector2.new(18, 3.6),
		"⚖️ THE GILDED GAVEL ⚖️",
		"Auction House: buy and sell robe & hat parts"
	)
	stationPrompt(podium, "Trade", "Auction House", "Auction")
end

local function gazebo(parent: Instance, animated: Instance, c: Vector3)
	local model = Build.model("Gazebo", parent)
	Build.cylinder(
		c + Vector3.new(0, 0.2, 0),
		32,
		0.4,
		{ Name = "GazeboFloor", Material = M.Marble, Color = Props.MARBLE },
		model
	)
	Build.cylinder(
		c + Vector3.new(0, 0.25, 0),
		33,
		0.38,
		{ Name = "GazeboRim", Material = M.Metal, Color = Props.GOLD },
		model
	)
	for i = 1, 8 do
		local a = (i / 8) * math.pi * 2 + math.pi / 8
		part(
			model,
			"GazeboColumn",
			Vector3.new(1.8, 14, 1.8),
			CFrame.new(c + Vector3.new(math.cos(a) * 14, 7.4, math.sin(a) * 14)),
			M.Marble,
			Props.MARBLE
		)
	end
	for i = 0, 4 do
		Build.cylinder(
			c + Vector3.new(0, 15 + i * 1.3, 0),
			33 - i * 6.5,
			1.3,
			{ Name = "GazeboRoof", Material = M.Slate, Color = ROOF },
			model
		)
	end
	part(
		model,
		"GazeboFinial",
		Vector3.new(2, 2, 2),
		CFrame.new(c + Vector3.new(0, 21.8, 0)),
		M.Metal,
		Props.GOLD,
		{ Shape = Enum.PartType.Ball }
	)
	Props.classAltar(model, animated, c + Vector3.new(0, 0.4, 0))
end

local function floatingIsles(animated: Instance, c: Vector3, rng: Random)
	for i = 1, 7 do
		-- (all around except the east, where the practice range sticks out)
		local a = math.rad(40 + (i - 0.5) * 40) + rng:NextNumber(-0.15, 0.15)
		local r = rng:NextNumber(150, 190)
		local p = c + Vector3.new(math.cos(a) * r, rng:NextNumber(-25, 30), math.sin(a) * r)
		local isle = Build.model("FloatingIsle", animated)
		isle:SetAttribute("Bob", rng:NextNumber(0, math.pi * 2))
		local size = rng:NextNumber(8, 16)
		part(
			isle,
			"IsleRock",
			Vector3.new(size, size * 0.6, size),
			CFrame.new(p) * CFrame.Angles(0, rng:NextNumber(0, 3), 0),
			M.Rock,
			Color3.fromRGB(95, 88, 84),
			{ CanCollide = false, CanQuery = false }
		)
		part(
			isle,
			"IsleGrass",
			Vector3.new(size * 0.9, 0.6, size * 0.9),
			CFrame.new(p + Vector3.new(0, size * 0.3 + 0.2, 0)) * CFrame.Angles(0, rng:NextNumber(0, 3), 0),
			M.Grass,
			GRASS,
			{ CanCollide = false, CanQuery = false }
		)
		part(
			isle,
			"IsleCrystal",
			Vector3.new(1.4, size * 0.4, 1.4),
			CFrame.new(p + Vector3.new(0, size * 0.5 + 1, 0)) * CFrame.Angles(0.3, rng:NextNumber(0, 3), 0.2),
			M.Neon,
			Color3.fromHSV(rng:NextNumber(0.5, 0.85), 0.55, 1),
			{ CanCollide = false, CanQuery = false }
		)
	end
end

local function practiceRange(parent: Instance, at: (number, number, number?) -> Vector3, y: number): { DummySpot }
	local range = Build.model("PracticeRange", parent)
	local W, D = RX1 - RX0, RZ * 2
	local cx = (RX0 + RX1) / 2
	part(range, "RangeFloor", Vector3.new(W, 4, D), CFrame.new(at(cx, 0, -2)), M.Slate, Color3.fromRGB(88, 84, 96))
	for gx = RX0 + 10, RX1 - 10, 20 do
		for gz = -RZ + 10, RZ - 10, 20 do
			if ((gx + gz) // 20) % 2 == 0 then
				part(
					range,
					"Tile",
					Vector3.new(19.6, 0.1, 19.6),
					CFrame.new(at(gx, gz, 0.05)),
					M.Marble,
					Color3.fromRGB(150, 145, 160)
				)
			end
		end
	end
	-- low walls with lanterns, and a tall back wall to catch stray spells
	for side = -1, 1, 2 do
		part(range, "RangeWall", Vector3.new(W, 3, 2), CFrame.new(at(cx, side * (RZ - 1), 1.5)), M.Brick, Props.STONE)
		for x = RX0 + 20, RX1 - 10, 30 do
			Props.lantern(range, at(x, side * (RZ - 1), 3), 5)
		end
	end
	part(range, "BackWall", Vector3.new(3, 18, D), CFrame.new(at(RX1 - 1.5, 0, 9)), M.Brick, Props.STONE)
	for z = -RZ + 12, RZ - 12, 16 do
		part(
			range,
			"Banner",
			Vector3.new(0.4, 10, 5),
			CFrame.new(at(RX1 - 3.2, z, 10)),
			M.Fabric,
			if (z // 16) % 2 == 0 then ROOF else Color3.fromRGB(150, 40, 50)
		)
	end
	-- the gate from the plaza
	local gateX = RX0 + 2
	for side = -1, 1, 2 do
		part(range, "GatePillar", Vector3.new(3, 18, 3), CFrame.new(at(gateX, side * 14, 9)), M.Marble, Props.MARBLE)
	end
	part(range, "GateLintel", Vector3.new(4, 3, 31), CFrame.new(at(gateX, 0, 19.5)), M.Marble, Props.MARBLE)
	Props.sign(
		range,
		CFrame.lookAt(at(gateX - 2.3, 0, 24), at(0, 0, 24)),
		Vector2.new(28, 6),
		"PRACTICE RANGE",
		"Spell Lab: try anything on the dummies"
	)
	part(range, "FiringLine", Vector3.new(1, 0.12, D - 8), CFrame.new(at(118, 0, 0.08)), M.Neon, Props.GOLD)

	local spots: { DummySpot } = {}
	local facing = at(0, 0, 0)
	for _, p in { { 150, -26 }, { 150, 26 }, { 162, 0 }, { 186, -30 }, { 186, 30 } } do
		local pos = at(p[1], p[2])
		table.insert(spots, { cframe = Props.dummyPad(range, pos, Vector3.new(facing.X, y, pos.Z)) })
	end
	-- two moving dummies on glowing rails, for practising leading your shots
	for _, x in { 134, 174 } do
		part(range, "Rail", Vector3.new(1.2, 0.14, 64), CFrame.new(at(x, 0, 0.08)), M.Neon, Color3.fromRGB(255, 90, 90))
		local pos = at(x, 0)
		table.insert(spots, {
			cframe = CFrame.lookAt(pos + Vector3.new(0, 0.2, 0), Vector3.new(facing.X, pos.Y + 0.2, pos.Z)),
			travel = Vector3.new(0, 0, 30),
		})
	end
	return spots
end

function Hub.build(): HubInfo
	local existing = workspace:FindFirstChild("Hub")
	if existing then
		existing:Destroy()
	end
	local rng = Random.new(4242)
	local y = Config.Arena.LobbyHeight
	local center = Vector3.new(0, y, Hub.CENTER_Z)
	local function at(x: number, z: number, dy: number?): Vector3
		return center + Vector3.new(x, dy or 0, z)
	end
	local model = Build.model("Hub", workspace)
	local animated = Build.make("Folder", { Name = "Animated" }, model)

	---------------------------------------------------------------- ground
	Build.cylinder(at(0, 0, -2), R * 2, 4, { Name = "Ground", Material = M.Grass, Color = GRASS }, model)
	Build.cylinder(
		at(0, 0, 0.05),
		(R - RIM) * 2,
		0.1,
		{ Name = "Plaza", Material = M.Cobblestone, Color = COBBLE },
		model
	)
	Build.cylinder(at(0, 0, 0.1), 84, 0.1, { Name = "RuneCircle", Material = M.Neon, Color = Props.ARCANE }, model)
	Build.cylinder(at(0, 0, 0.15), 80, 0.1, { Name = "Heart", Material = M.Marble, Color = Props.MARBLE }, model)

	---------------------------------------------------------------- the heart of the plaza
	fountain(model, animated, at(0, 0, 0.2))
	for i = 1, 8 do
		local a = (i / 8) * math.pi * 2 + math.pi / 8
		bench(model, at(math.cos(a) * 22, math.sin(a) * 22, 0.2), at(0, 0))
	end
	for i = 1, 8 do
		local a = (i / 8) * math.pi * 2
		Props.lantern(model, at(math.cos(a) * 43, math.sin(a) * 43, 0.1))
	end

	---------------------------------------------------------------- north: the portal to the Athenaeum
	part(model, "PortalDais", Vector3.new(34, 1, 16), CFrame.new(at(0, -86, 0.5)), M.Marble, Props.MARBLE)
	part(model, "PortalStep", Vector3.new(26, 0.5, 4), CFrame.new(at(0, -76, 0.25)), M.Marble, Props.MARBLE)
	local joinPortal = Props.portal(
		model,
		CFrame.lookAt(at(0, -88, 1), at(0, 0, 1)),
		18,
		24,
		Props.ARCANE,
		"Join the game",
		"Portal to the Athenaeum"
	)
	joinPortal:SetAttribute("PortalAction", "JoinQueue")
	Props.sign(
		model,
		CFrame.lookAt(at(0, -88, 35), at(0, 0, 35)),
		Vector2.new(36, 7),
		"⚔️  JOIN THE GAME  ⚔️",
		"Walk through the portal to queue for the next match"
	)

	---------------------------------------------------------------- east: practice range
	local dummySpots = practiceRange(model, at, y)

	---------------------------------------------------------------- west: class altar + Grimoire
	gazebo(model, animated, at(-62, 0, 0.1))
	Props.lectern(model, at(-42, -14, 0.15), Vector3.new(1, 0, 0))
	Props.lectern(model, at(-42, 14, 0.15), Vector3.new(1, 0, 0))

	---------------------------------------------------------------- around the edge
	tower(model, at(-87, 50), at(0, 0), rng)
	tower(model, at(-87, -50), at(0, 0), rng)
	tower(model, at(57, -82), at(0, 0), rng)
	tower(model, at(52, 86), at(0, 0), rng)
	-- the Tailor's Loom (craft robes and hats) and the Coffer stall (loot boxes)
	local _, tailorCounter, tailorCf =
		stall(model, at(-40, 58, 0.1), at(0, 20), Color3.fromRGB(150, 40, 60), rng, "cloth")
	stationPrompt(tailorCounter, "Craft & dress", "The Tailor's Loom", "Wardrobe")
	Props.sign(
		model,
		tailorCf * CFrame.new(0, 9.6, -1.6),
		Vector2.new(12, 2.6),
		"🧵 TAILOR'S LOOM",
		"Stitch robes & hats"
	)
	local _, cofferCounter, cofferCf =
		stall(model, at(40, 58, 0.1), at(0, 20), Color3.fromRGB(40, 90, 150), rng, "coffers")
	stationPrompt(cofferCounter, "Open coffers", "Coffer Merchant", "Coffers")
	Props.sign(
		model,
		cofferCf * CFrame.new(0, 9.6, -1.6),
		Vector2.new(12, 2.6),
		"🎁 COFFERS",
		"Spend Enchanted Coins"
	)
	-- the auction house, south-west
	auctionHouse(model, animated, at(-52, -52, 0.1), at(0, 0))

	local decor = Build.make("Folder", { Name = "Decor" }, model)
	-- round stone planters with a tree each, in the open parts of the plaza
	for _, deg in { 30, 150, 315 } do -- (225 is the auction house)
		local a = math.rad(deg)
		local p = at(math.cos(a) * 66, math.sin(a) * 66)
		Build.cylinder(
			p + Vector3.new(0, 0.7, 0),
			10,
			1.4,
			{ Name = "Planter", Material = M.Cobblestone, Color = Props.STONE },
			model
		)
		Build.cylinder(
			p + Vector3.new(0, 1.3, 0),
			8.6,
			0.4,
			{ Name = "PlanterSoil", Material = M.Grass, Color = GRASS },
			model
		)
		Decor.build("tree", if deg < 180 then "birch" else "oak", decor, p + Vector3.new(0, 1.5, 0), rng, GARDEN)
	end
	local styles = { "oak", "birch", "pine" }
	for i = 1, 22 do
		local a = (i / 22) * math.pi * 2 + rng:NextNumber(-0.08, 0.08)
		local deg = math.deg(a) % 360
		-- keep the portal, the range gate and the towers clear
		local blocked = deg < 32 or deg > 328 or (deg > 248 and deg < 292)
		for _, t in { 150, 210, 305, 59, 90 } do
			if math.abs(deg - t) < 9 then
				blocked = true
			end
		end
		if not blocked then
			local r = rng:NextNumber(R - RIM + 5, R - 4)
			Decor.build(
				"tree",
				styles[rng:NextInteger(1, #styles)],
				decor,
				at(math.cos(a) * r, math.sin(a) * r),
				rng,
				GARDEN
			)
			local b = a + rng:NextNumber(0.06, 0.12)
			Decor.build("bush", "bush", decor, at(math.cos(b) * (R - 9), math.sin(b) * (R - 9)), rng, GARDEN)
			-- a few flowers around each bush
			for _ = 1, 4 do
				local f = b + rng:NextNumber(-0.05, 0.05)
				local fr = R - 9 + rng:NextNumber(-3, 3)
				Decor.build("bush", "flower", decor, at(math.cos(f) * fr, math.sin(f) * fr), rng, GARDEN)
			end
		end
	end
	floatingIsles(animated, center, rng)

	---------------------------------------------------------------- spawn + boards
	local spawnPos = at(0, 70, 0.6)
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(12, 1, 12)
	spawn.CFrame = CFrame.new(spawnPos)
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.CanQuery = false
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = model
	Build.cylinder(at(0, 70, 0.17), 12, 0.1, {
		Name = "SpawnRune",
		Material = M.Neon,
		Color = Color3.fromRGB(90, 220, 170),
		CanCollide = false,
		Transparency = 0.3,
	}, model)
	board(
		model,
		CFrame.lookAt(at(-20, 50, 9), at(0, 74, 9)),
		Vector2.new(17, 11),
		y + 0.1,
		"Arcanum Plaza",
		"Welcome, mage!\n"
			.. "• <b>Practise</b> on the range to the east\n"
			.. "• <b>B</b>: Spellbook  ·  <b>H</b>: Grimoire\n"
			.. "• Pick a <b>class</b> at the gazebo (west)\n"
			.. "• Ready? Walk through the <b>portal</b> (north) to join the next match"
	)
	local boardText = board(
		model,
		CFrame.lookAt(at(20, 50, 9), at(0, 74, 9)),
		Vector2.new(17, 11),
		y + 0.1,
		"Next Match",
		"Waiting for players"
	)

	-- behind the spawn, facing the plaza: the global leaderboard
	local leaderboard = hallOfChampions(model, CFrame.lookAt(at(0, 99, 10.5), at(0, 0, 10.5)), y + 0.1)

	---------------------------------------------------------------- containment + the rock underneath
	local segments = 48
	for i = 1, segments do
		local a = (i / segments) * math.pi * 2
		if math.abs(math.deg(a) % 360 - 180) < 155 then -- skip the opening to the range (east)
			local p = at(math.cos(a) * (R + 2), math.sin(a) * (R + 2), 40)
			Props.barrier(
				model,
				Vector3.new(2 * math.pi * (R + 2) / segments + 1, 80, 2),
				CFrame.lookAt(p, at(0, 0, 40))
			)
		end
	end
	-- the range's side walls start where the ring of barriers leaves off
	local wallX0 = RX0 - 2
	for side = -1, 1, 2 do
		Props.barrier(
			model,
			Vector3.new(RX1 + 1 - wallX0, 80, 2),
			CFrame.new(at((wallX0 + RX1 + 1) / 2, side * (RZ + 1), 40))
		)
	end
	Props.barrier(model, Vector3.new(2, 80, RZ * 2 + 4), CFrame.new(at(RX1 + 1, 0, 40)))

	for i, d in { 214, 186, 150, 104, 52 } do
		local rock = Build.cylinder(
			at(0, 0, -8 - (i - 1) * 7),
			d,
			8,
			{ Name = "Underside", Material = M.Rock, Color = Color3.fromRGB(90, 85, 80), CanQuery = false },
			model
		)
		rock.CanCollide = false
	end
	for i = 1, 3 do
		part(
			model,
			"Underside",
			Vector3.new(RX1 - RX0 - i * 12, 8, RZ * 2 - i * 14),
			CFrame.new(at((RX0 + RX1) / 2, 0, -8 - (i - 1) * 7)),
			M.Rock,
			Color3.fromRGB(90, 85, 80),
			{ CanQuery = false, CanCollide = false }
		)
	end

	return {
		model = model,
		spawn = CFrame.lookAt(spawnPos + Vector3.new(0, 3, 0), at(0, 0, 3.6)),
		dummySpots = dummySpots,
		joinPortal = joinPortal,
		boardText = boardText,
		leaderboard = leaderboard,
		floorY = y,
	}
end

return Hub
