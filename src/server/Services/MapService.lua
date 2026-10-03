-- Builds the lobby once and a brand new arena (new seed, new layout) for every match.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Map = script.Parent.Parent.Map
local Build = require(Map.Build)
local TerrainGen = require(Map.TerrainGen)
local Structures = require(Map.Structures)
local Lobby = require(Map.Lobby)

local MapService = {}

local A = Config.Arena

export type Arena = {
	seed: number,
	plazaY: number,
	center: Vector3,
	pedestals: { CFrame },
	chestSpots: { Structures.ChestSpot },
	heightAt: (number, number) -> number,
	folder: Folder,
}

MapService.lobbySpawn = CFrame.new(0, A.LobbyHeight + 5, 0)
MapService.arena = nil :: Arena?
MapService.generating = false

local function setupLighting()
	if Lighting:FindFirstChildOfClass("Atmosphere") then
		return
	end
	Build.make("Atmosphere", {
		Density = 0.28,
		Offset = 0.15,
		Color = Color3.fromRGB(200, 205, 230),
		Decay = Color3.fromRGB(110, 100, 140),
		Glare = 0.25,
		Haze = 1.4,
	}, Lighting)
	Build.make("BloomEffect", { Intensity = 0.7, Size = 26, Threshold = 1.4 }, Lighting)
	Build.make("ColorCorrectionEffect", { Saturation = 0.1, Contrast = 0.06, Brightness = 0.02 }, Lighting)
	Build.make("SunRaysEffect", { Intensity = 0.05, Spread = 0.8 }, Lighting)
	workspace.Terrain.WaterColor = Color3.fromRGB(60, 130, 170)
	workspace.Terrain.WaterTransparency = 0.6
	workspace.Terrain.WaterWaveSize = 0.12
end

function MapService.init()
	setupLighting()
	local _, spawnCFrame = Lobby.build()
	MapService.lobbySpawn = spawnCFrame
end

-- Generates terrain + structures. Yields for a few seconds.
function MapService.generate(seed: number): Arena
	MapService.generating = true
	local old = workspace:FindFirstChild("Arena")
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "Arena"
	folder.Parent = workspace
	local decor = Build.make("Folder", { Name = "Decor" }, folder)
	Build.make("Folder", { Name = "Chests" }, folder)

	local heightAt = TerrainGen.makeHeight(seed)
	TerrainGen.generate(heightAt)

	local rng = Random.new(seed)
	local plazaY = TerrainGen.plazaHeight()
	local corn = Structures.cornucopia(folder, plazaY)
	local chestSpots: { Structures.ChestSpot } = table.clone(corn.chests)

	local function polar(angle: number, dist: number): (number, number)
		return math.cos(angle) * dist, math.sin(angle) * dist
	end

	local function steep(x: number, z: number): boolean
		local h = heightAt(x, z)
		return math.abs(heightAt(x + 3, z) - h) > 2.5 or math.abs(heightAt(x, z + 3) - h) > 2.5
	end

	-- Points of interest ring
	local builders = { Structures.ruinedTower, Structures.shrine, Structures.camp, Structures.watchtower }
	local pois: { Vector3 } = {}
	for i = 1, A.RuinCount do
		local x, z
		for _ = 1, 10 do
			local angle = (i / A.RuinCount) * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
			x, z = polar(angle, rng:NextNumber(120, A.Radius - 75))
			if heightAt(x, z) > A.WaterLevel + 2 then
				break
			end
		end
		local builder = builders[(i - 1) % #builders + 1]
		local spots = builder(decor, Vector3.new(x, 0, z), heightAt, rng)
		for _, spot in spots do
			table.insert(chestSpots, spot)
		end
		table.insert(pois, Vector3.new(x, 0, z))
		task.wait()
	end

	local function nearPoi(x: number, z: number, dist: number): boolean
		for _, p in pois do
			if (Vector3.new(x, 0, z) - p).Magnitude < dist then
				return true
			end
		end
		return false
	end

	-- Scattered chests
	local outer: { Vector3 } = {}
	local attempts = 0
	while #outer < A.OuterChestCount and attempts < 3000 do
		attempts += 1
		local x, z = polar(rng:NextNumber(0, math.pi * 2), rng:NextNumber(70, A.Radius - 30))
		local h = heightAt(x, z)
		if h > A.WaterLevel + 1 and not steep(x, z) and not nearPoi(x, z, 24) then
			local ok = true
			for _, p in outer do
				if (Vector3.new(x, 0, z) - p).Magnitude < 30 then
					ok = false
					break
				end
			end
			if ok then
				table.insert(outer, Vector3.new(x, 0, z))
				table.insert(chestSpots, {
					cframe = CFrame.new(x, h + 1, z) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0),
					tier = "Outer",
				})
			end
		end
	end

	-- Nature
	local function scatter(count: number, minDist: number, maxDist: number, fn)
		local placed, tries = 0, 0
		while placed < count and tries < count * 12 do
			tries += 1
			local x, z = polar(rng:NextNumber(0, math.pi * 2), rng:NextNumber(minDist, maxDist))
			local h = heightAt(x, z)
			if h > A.WaterLevel + 1.5 and h < 60 and not nearPoi(x, z, 18) then
				local nearChest = false
				for _, p in outer do
					if (Vector3.new(x, 0, z) - p).Magnitude < 6 then
						nearChest = true
						break
					end
				end
				if not nearChest then
					fn(decor, Vector3.new(x, h, z), rng)
					placed += 1
					if placed % 25 == 0 then
						task.wait()
					end
				end
			end
		end
	end
	scatter(A.TreeCount, A.PedestalRadius + 16, A.Radius + 20, Structures.tree)
	scatter(A.RockCount, A.PedestalRadius + 12, A.Radius + 10, Structures.rock)
	scatter(math.floor(A.TreeCount * 0.6), A.PedestalRadius + 10, A.Radius - 10, Structures.bush)

	-- invisible wall well outside the playable area
	local wallRadius = A.Radius + 45
	local segments = 48
	for i = 1, segments do
		local angle = (i / segments) * math.pi * 2
		local pos = Vector3.new(math.cos(angle) * wallRadius, 150, math.sin(angle) * wallRadius)
		Build.part({
			Name = "WorldEdge",
			Size = Vector3.new(2 * math.pi * wallRadius / segments + 2, 400, 4),
			CFrame = CFrame.lookAt(pos, Vector3.new(0, 150, 0)),
			Transparency = 1,
			CanQuery = false,
		}, folder)
	end

	local arena: Arena = {
		seed = seed,
		plazaY = plazaY,
		center = Vector3.new(0, plazaY, 0),
		pedestals = corn.pedestals,
		chestSpots = chestSpots,
		heightAt = heightAt,
		folder = folder,
	}
	MapService.arena = arena
	MapService.generating = false
	return arena
end

-- Ground height at a point, or the plaza height if no arena exists yet.
function MapService.groundAt(x: number, z: number): number
	local arena = MapService.arena
	if arena then
		return arena.heightAt(x, z)
	end
	return TerrainGen.plazaHeight()
end

return MapService
