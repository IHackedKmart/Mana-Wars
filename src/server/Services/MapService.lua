-- Builds the hub (Arcanum Plaza) and the library lobby once, and a brand new arena for every
-- match: the map players voted for, with a fresh random layout each time.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Map = script.Parent.Parent.Map
local Build = require(Map.Build)
local MapDefs = require(Map.MapDefs)
local TerrainGen = require(Map.TerrainGen)
local Structures = require(Map.Structures)
local Lobby = require(Map.Lobby)
local Hub = require(Map.Hub)

type MapDef = MapDefs.MapDef

local MapService = {}

local A = Config.Arena

export type Arena = {
	seed: number,
	def: MapDef,
	radius: number,
	plazaY: number,
	center: Vector3,
	pedestals: { CFrame },
	chestSpots: { Structures.ChestSpot },
	heightAt: (number, number) -> number,
	folder: Folder,
}

MapService.lobbySpawn = CFrame.new(0, A.LobbyHeight + 5, 0)
MapService.hubSpawn = CFrame.new(0, A.LobbyHeight + 5, Hub.CENTER_Z)
MapService.lobby = nil :: Lobby.LobbyInfo?
MapService.hub = nil :: Hub.HubInfo?
MapService.arena = nil :: Arena?
MapService.generating = false

local function applyLighting(def: MapDef)
	for key, value in def.lighting do
		pcall(function()
			(Lighting :: any)[key] = value
		end)
	end
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if not atmosphere then
		atmosphere = Instance.new("Atmosphere")
		atmosphere.Parent = Lighting
	end
	for key, value in def.atmosphere do
		pcall(function()
			(atmosphere :: any)[key] = value
		end)
	end
	if not Lighting:FindFirstChildOfClass("BloomEffect") then
		Build.make("BloomEffect", { Intensity = 0.7, Size = 26, Threshold = 1.4 }, Lighting)
		Build.make("ColorCorrectionEffect", { Saturation = 0.1, Contrast = 0.06, Brightness = 0.02 }, Lighting)
		Build.make("SunRaysEffect", { Intensity = 0.05, Spread = 0.8 }, Lighting)
	end
end

function MapService.init()
	applyLighting(MapDefs.List[1])
	local info = Lobby.build()
	MapService.lobby = info
	MapService.lobbySpawn = info.spawn
	local hub = Hub.build()
	MapService.hub = hub
	MapService.hubSpawn = hub.spawn
end

function MapService.randomDef(rng: Random): MapDef
	return MapDefs.List[rng:NextInteger(1, #MapDefs.List)]
end

-- Generates terrain + structures for a map. Yields for a few seconds.
function MapService.generate(seed: number, def: MapDef): Arena
	while MapService.generating do
		task.wait(0.2)
	end
	MapService.generating = true
	local ok, result = pcall(function()
		local old = workspace:FindFirstChild("Arena")
		if old then
			old:Destroy()
		end
		local folder = Instance.new("Folder")
		folder.Name = "Arena"
		folder.Parent = workspace
		local decor = Build.make("Folder", { Name = "Decor" }, folder)
		Build.make("Folder", { Name = "Chests" }, folder)

		applyLighting(def)
		local heightAt = TerrainGen.makeHeight(seed, def)
		TerrainGen.generate(heightAt, def)

		local rng = Random.new(seed)
		local radius = def.radius
		local liquid = def.terrain.liquidLevel
		local plazaY = MapDefs.plazaHeight(def)
		local corn = Structures.cornucopia(folder, plazaY, def.style)
		local chestSpots: { Structures.ChestSpot } = table.clone(corn.chests)

		local function polar(angle: number, dist: number): (number, number)
			return math.cos(angle) * dist, math.sin(angle) * dist
		end

		local function steep(x: number, z: number): boolean
			local h = heightAt(x, z)
			return math.abs(heightAt(x + 3, z) - h) > 2.5 or math.abs(heightAt(x, z + 3) - h) > 2.5
		end

		-- Points of interest, spread around the island
		local pois: { Vector3 } = {}
		for i = 1, def.poiCount do
			local x, z = 0, 0
			for _ = 1, 12 do
				local angle = (i / def.poiCount) * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
				local ring = if i % 2 == 0 then rng:NextNumber(0.3, 0.55) else rng:NextNumber(0.55, 0.82)
				x, z = polar(angle, radius * ring)
				if heightAt(x, z) > liquid + 2 then
					break
				end
			end
			local kind = def.pois[(i - 1) % #def.pois + 1]
			local builder = Structures.Pois[kind]
			if builder then
				for _, spot in builder(decor, Vector3.new(x, 0, z), heightAt, rng, def.style) do
					table.insert(chestSpots, spot)
				end
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

		-- Scattered chests, kept well apart so loot is worth travelling for
		local outer: { Vector3 } = {}
		local attempts = 0
		while #outer < def.outerChests and attempts < 4000 do
			attempts += 1
			local x, z = polar(rng:NextNumber(0, math.pi * 2), rng:NextNumber(75, radius - 35))
			local h = heightAt(x, z)
			if h > liquid + 1 and not steep(x, z) and not nearPoi(x, z, A.ChestSpacing) then
				local ok = true
				for _, p in outer do
					if (Vector3.new(x, 0, z) - p).Magnitude < A.ChestSpacing then
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

		-- Decoration
		local cliff = def.terrain.cliffHeight + 8
		for _, entry in def.decor do
			local placed, tries = 0, 0
			local minDist = A.PedestalRadius + (if entry.kind == "tree" then 16 else 10)
			local maxDist = radius + (if entry.kind == "bush" then -10 else 15)
			while placed < entry.count and tries < entry.count * 12 do
				tries += 1
				local x, z = polar(rng:NextNumber(0, math.pi * 2), rng:NextNumber(minDist, maxDist))
				local h = heightAt(x, z)
				if h > liquid + 1.5 and h < cliff and not nearPoi(x, z, 18) then
					local nearChest = false
					for _, p in outer do
						if (Vector3.new(x, 0, z) - p).Magnitude < 6 then
							nearChest = true
							break
						end
					end
					if not nearChest then
						local styleName = entry.styles[rng:NextInteger(1, #entry.styles)]
						Structures.decor(entry.kind, styleName, decor, Vector3.new(x, h, z), rng)
						placed += 1
						if placed % 25 == 0 then
							task.wait()
						end
					end
				end
			end
		end

		-- invisible wall well outside the playable area
		local wallRadius = radius + 45
		local segments = 64
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
			def = def,
			radius = radius,
			plazaY = plazaY,
			center = Vector3.new(0, plazaY, 0),
			pedestals = corn.pedestals,
			chestSpots = chestSpots,
			heightAt = heightAt,
			folder = folder,
		}
		return arena
	end)
	MapService.generating = false
	if not ok then
		error(result)
	end
	MapService.arena = result
	ReplicatedStorage:SetAttribute("MapId", def.id)
	ReplicatedStorage:SetAttribute("MapName", def.name)
	ReplicatedStorage:SetAttribute("MapWeather", def.weather or "")
	return result
end

-- Ground height at a point, or the plaza height if no arena exists yet.
function MapService.groundAt(x: number, z: number): number
	local arena = MapService.arena
	if arena then
		return arena.heightAt(x, z)
	end
	return 13
end

function MapService.radius(): number
	local arena = MapService.arena
	return if arena then arena.radius else 400
end

return MapService
