-- The floating Sky Sanctum where players wait between matches. It hovers above the
-- arena with a glass floor in the middle so you can watch the island below.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Build = require(script.Parent.Build)

local Lobby = {}

local SIZE = 150
local GLASS = 34

function Lobby.build(): (Model, CFrame)
	local existing = workspace:FindFirstChild("Lobby")
	if existing then
		existing:Destroy()
	end
	local y = Config.Arena.LobbyHeight
	local model = Build.model("Lobby", workspace)

	local floorColor = Color3.fromRGB(70, 65, 85)
	local half = SIZE / 2
	local strip = (SIZE - GLASS) / 2
	-- four floor slabs around a glass window
	Build.part({
		Name = "Floor",
		Size = Vector3.new(SIZE, 4, strip),
		CFrame = CFrame.new(0, y - 2, -(GLASS / 2 + strip / 2)),
		Material = Enum.Material.Slate,
		Color = floorColor,
	}, model)
	Build.part({
		Name = "Floor",
		Size = Vector3.new(SIZE, 4, strip),
		CFrame = CFrame.new(0, y - 2, GLASS / 2 + strip / 2),
		Material = Enum.Material.Slate,
		Color = floorColor,
	}, model)
	Build.part({
		Name = "Floor",
		Size = Vector3.new(strip, 4, GLASS),
		CFrame = CFrame.new(-(GLASS / 2 + strip / 2), y - 2, 0),
		Material = Enum.Material.Slate,
		Color = floorColor,
	}, model)
	Build.part({
		Name = "Floor",
		Size = Vector3.new(strip, 4, GLASS),
		CFrame = CFrame.new(GLASS / 2 + strip / 2, y - 2, 0),
		Material = Enum.Material.Slate,
		Color = floorColor,
	}, model)
	Build.part({
		Name = "Window",
		Size = Vector3.new(GLASS, 1, GLASS),
		CFrame = CFrame.new(0, y - 0.5, 0),
		Material = Enum.Material.Glass,
		Color = Color3.fromRGB(180, 210, 255),
		Transparency = 0.65,
	}, model)
	Build.part({
		Name = "WindowRim",
		Size = Vector3.new(GLASS + 2, 0.4, GLASS + 2),
		CFrame = CFrame.new(0, y - 0.15, 0),
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(150, 100, 255),
		Transparency = 0.6,
		CanCollide = false,
	}, model)

	-- decorative low walls + invisible containment
	for _, side in { Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(0, 0, -1) } do
		local alongX = side.Z ~= 0
		local size = if alongX then Vector3.new(SIZE, 3, 2) else Vector3.new(2, 3, SIZE)
		Build.part({
			Name = "Wall",
			Size = size,
			CFrame = CFrame.new(side * (half - 1) + Vector3.new(0, y + 1.5, 0)),
			Material = Enum.Material.Marble,
			Color = Color3.fromRGB(220, 215, 205),
		}, model)
		local barrier = if alongX then Vector3.new(SIZE, 80, 2) else Vector3.new(2, 80, SIZE)
		Build.part({
			Name = "Barrier",
			Size = barrier,
			CFrame = CFrame.new(side * (half + 1) + Vector3.new(0, y + 40, 0)),
			Transparency = 1,
			CanQuery = false,
		}, model)
	end
	Build.part({
		Name = "Ceiling",
		Size = Vector3.new(SIZE, 2, SIZE),
		CFrame = CFrame.new(0, y + 80, 0),
		Transparency = 1,
		CanQuery = false,
	}, model)

	-- crystal pillars in the corners
	for _, c in { Vector3.new(1, 0, 1), Vector3.new(-1, 0, 1), Vector3.new(1, 0, -1), Vector3.new(-1, 0, -1) } do
		local base = c * (half - 12)
		Build.part({
			Name = "Pillar",
			Size = Vector3.new(4, 14, 4),
			CFrame = CFrame.new(base + Vector3.new(0, y + 7, 0)),
			Material = Enum.Material.Marble,
			Color = Color3.fromRGB(230, 225, 215),
		}, model)
		local crystal = Build.part({
			Name = "Crystal",
			Size = Vector3.new(3, 6, 3),
			CFrame = CFrame.new(base + Vector3.new(0, y + 18, 0)) * CFrame.Angles(0, math.rad(45), 0),
			Material = Enum.Material.Neon,
			Color = Color3.fromRGB(160, 110, 255),
			CanCollide = false,
		}, model)
		Build.make("PointLight", { Color = crystal.Color, Range = 30, Brightness = 2 }, crystal)
	end

	-- floating title sign
	local sign = Build.part({
		Name = "Sign",
		Size = Vector3.new(44, 10, 1),
		CFrame = CFrame.new(0, y + 16, -half + 6),
		Material = Enum.Material.SmoothPlastic,
		Color = Color3.fromRGB(30, 25, 45),
	}, model)
	local gui = Build.make("SurfaceGui", { Face = Enum.NormalId.Back, PixelsPerStud = 25 }, sign)
	Build.make("TextLabel", {
		Size = UDim2.fromScale(1, 0.7),
		BackgroundTransparency = 1,
		Text = string.upper(Config.GameName),
		Font = Enum.Font.Fantasy,
		TextScaled = true,
		TextColor3 = Color3.fromRGB(220, 190, 255),
	}, gui)
	Build.make("TextLabel", {
		Size = UDim2.fromScale(1, 0.3),
		Position = UDim2.fromScale(0, 0.7),
		BackgroundTransparency = 1,
		Text = "Loot. Craft. Survive.",
		Font = Enum.Font.GothamBold,
		TextScaled = true,
		TextColor3 = Color3.fromRGB(255, 220, 140),
	}, gui)

	-- the rocky island underneath, built as shrinking rings so the glass window
	-- still has a clear view shaft down to the arena
	for i = 1, 4 do
		local s = SIZE * (1 - i * 0.16)
		local ring = (s - GLASS) / 2
		local layerY = y - 8 - (i - 1) * 8
		local rock = { Material = Enum.Material.Rock, Color = Color3.fromRGB(90, 85, 80), CanQuery = false }
		local function slab(size: Vector3, pos: Vector3)
			local props = table.clone(rock)
			props.Name = "Underside"
			props.Size = size
			props.CFrame = CFrame.new(pos)
			Build.part(props, model)
		end
		slab(Vector3.new(s, 8, ring), Vector3.new(0, layerY, -(GLASS / 2 + ring / 2)))
		slab(Vector3.new(s, 8, ring), Vector3.new(0, layerY, GLASS / 2 + ring / 2))
		slab(Vector3.new(ring, 8, GLASS), Vector3.new(-(GLASS / 2 + ring / 2), layerY, 0))
		slab(Vector3.new(ring, 8, GLASS), Vector3.new(GLASS / 2 + ring / 2, layerY, 0))
	end

	local spawnCFrame = CFrame.new(0, y + 0.5, half - 20)
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "LobbySpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(14, 1, 14)
	spawn.CFrame = spawnCFrame
	spawn.Material = Enum.Material.Neon
	spawn.Color = Color3.fromRGB(120, 80, 220)
	spawn.Transparency = 0.3
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = model

	return model, spawnCFrame + Vector3.new(0, 4, 0)
end

return Lobby
