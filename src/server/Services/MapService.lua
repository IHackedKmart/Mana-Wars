-- Builds the hub (Arcanum Plaza) and the library lobby once, and a brand new arena for every
-- match: the map players voted for (or the battle royale island), with a fresh random layout each
-- time.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Map = script.Parent.Parent.Map
local Build = require(Map.Build)
local MapDefs = require(Map.MapDefs)
local TerrainGen = require(Map.TerrainGen)
local Structures = require(Map.Structures)
local Decor = require(Map.Decor)
local Landmarks = require(Map.Landmarks)
local Scenery = require(Map.Scenery)
local RealmGen = require(Map.RealmGen)
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
	locations: { RealmGen.Location }?, -- the battle royale island's named places
	realmAt: ((number, number) -> MapDefs.Biome)?, -- and which realm a point is in
}

MapService.lobbySpawn = CFrame.new(0, A.LobbyHeight + 5, 0)
MapService.hubSpawn = CFrame.new(0, A.LobbyHeight + 5, Hub.CENTER_Z)
MapService.lobby = nil :: Lobby.LobbyInfo?
MapService.hub = nil :: Hub.HubInfo?
MapService.arena = nil :: Arena?
MapService.generating = false

-- Finds (or makes) one of the map's post-processing effects in Lighting.
local function effect(className: string, name: string): Instance
	local existing = Lighting:FindFirstChild(name)
	if existing then
		return existing
	end
	return Build.make(className, { Name = name }, Lighting)
end

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
	-- colour grading, bloom and sun rays, tuned per map
	local post = def.post
	local color = effect("ColorCorrectionEffect", "MapColor") :: any
	color.Saturation = post.saturation
	color.Contrast = post.contrast
	color.Brightness = post.brightness
	color.TintColor = post.tint
	local bloom = effect("BloomEffect", "MapBloom") :: any
	bloom.Intensity = post.bloom
	bloom.Size = 26
	bloom.Threshold = 1.3
	local rays = effect("SunRaysEffect", "MapSunRays") :: any
	rays.Intensity = post.sunRays
	rays.Spread = 0.8
	-- dynamic clouds
	local terrain = workspace.Terrain
	local clouds = terrain:FindFirstChildOfClass("Clouds") :: any
	if def.clouds then
		if not clouds then
			clouds = Instance.new("Clouds")
			clouds.Parent = terrain
		end
		pcall(function()
			clouds.Enabled = true
			clouds.Cover = def.clouds.cover
			clouds.Density = def.clouds.density
			clouds.Color = def.clouds.color
		end)
	elseif clouds then
		clouds.Enabled = false
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

-- The battle royale island's definition (it isn't one of the maps Survival Games votes on).
function MapService.royaleDef(): MapDef
	return MapDefs.Royale
end

function MapService.randomDef(rng: Random): MapDef
	return MapDefs.List[rng:NextInteger(1, #MapDefs.List)]
end

-- An invisible wall well outside the playable area (`top` studs high).
local function worldEdge(folder: Instance, radius: number, top: number)
	local wallRadius = radius + 45
	local segments = 64
	local bottom = -50
	for i = 1, segments do
		local angle = (i / segments) * math.pi * 2
		local pos = Vector3.new(math.cos(angle) * wallRadius, (top + bottom) / 2, math.sin(angle) * wallRadius)
		Build.part({
			Name = "WorldEdge",
			Size = Vector3.new(2 * math.pi * wallRadius / segments + 2, top - bottom, 4),
			CFrame = CFrame.lookAt(pos, Vector3.new(0, pos.Y, 0)),
			Transparency = 1,
			CanQuery = false,
		}, folder)
	end
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
		if def.biomes then
			-- the battle royale island: no cornucopia or pedestals, everyone drops from the carpet
			local realm = RealmGen.build(seed, def, folder, decor)
			worldEdge(folder, def.radius, Config.Royale.CarpetAltitude + 150)
			local biomes = def.biomes :: { MapDefs.Biome }
			local biomeAt = realm.land.biomeAt :: (number, number) -> number
			local plaza = MapDefs.plazaHeight(def)
			local royale: Arena = {
				seed = seed,
				def = def,
				radius = def.radius,
				plazaY = plaza,
				center = Vector3.new(0, plaza, 0),
				pedestals = {},
				chestSpots = realm.chestSpots,
				heightAt = realm.land.heightAt,
				folder = folder,
				locations = realm.locations,
				realmAt = function(x: number, z: number): MapDefs.Biome
					return biomes[biomeAt(x, z)]
				end,
			}
			return royale
		end
		local land = TerrainGen.makeLand(seed, def)
		local heightAt = land.heightAt

		local rng = Random.new(seed)
		local radius = def.radius
		local liquid = def.terrain.liquidLevel
		local plazaY = MapDefs.plazaHeight(def)

		local function polar(angle: number, dist: number): (number, number)
			return math.cos(angle) * dist, math.sin(angle) * dist
		end

		local function steep(x: number, z: number): boolean
			local h = heightAt(x, z)
			return math.abs(heightAt(x + 3, z) - h) > 2.5 or math.abs(heightAt(x, z + 3) - h) > 2.5
		end

		-- how uneven the ground is under a landmark's footprint
		local function bumpiness(x: number, z: number, r: number): number
			local lo, hi = math.huge, -math.huge
			for _, o in { { 0, 0 }, { r, 0 }, { -r, 0 }, { 0, r }, { 0, -r } } do
				local h = heightAt(x + o[1], z + o[2])
				lo, hi = math.min(lo, h), math.max(hi, h)
			end
			return hi - lo
		end

		-- 1. Choose where the landmarks go: on dry, fairly flat ground, spread around the island
		type Poi = { pos: Vector3, kind: string, room: number }
		local pois: { Poi } = {}
		local function tooClose(x: number, z: number, room: number): boolean
			for _, p in pois do
				if (Vector3.new(x, 0, z) - p.pos).Magnitude < room + p.room + 40 then
					return true
				end
			end
			if land.volcano then
				local v = land.volcano :: Vector3
				if (Vector3.new(x - v.X, 0, z - v.Z)).Magnitude < (def.terrain.volcano :: any).radius * 0.8 then
					return true
				end
			end
			return false
		end
		for i = 1, def.poiCount do
			local kind = def.pois[(i - 1) % #def.pois + 1]
			local room = Landmarks.Footprint[kind] or 14
			local bestX, bestZ, bestScore = 0, 0, math.huge
			for attempt = 1, 24 do
				local angle = (i / def.poiCount) * math.pi * 2 + rng:NextNumber(-0.35, 0.35)
				local ring = if i % 2 == 0 then rng:NextNumber(0.34, 0.56) else rng:NextNumber(0.56, 0.8)
				local x, z = polar(angle, radius * ring)
				local score = bumpiness(x, z, room) + (if land.riverAt(x, z) > 0 then 50 else 0)
				-- keep the whole footprint out of the water
				for k = 0, 8 do
					local a = k * math.pi / 4
					local r = if k == 8 then 0 else room
					if heightAt(x + math.cos(a) * r, z + math.sin(a) * r) < liquid + 2 then
						score += 60
					end
				end
				if tooClose(x, z, room) then
					score += 200
				end
				if score < bestScore then
					bestX, bestZ, bestScore = x, z, score
				end
				if score < 6 and attempt > 3 then
					break
				end
			end
			table.insert(pois, { pos = Vector3.new(bestX, 0, bestZ), kind = kind, room = room })
		end

		-- 2. Roads from the plaza out to every landmark, wandering a little
		local roads: { { Vector3 } } = {}
		for _, poi in pois do
			local target = poi.pos
			local dir = Vector3.new(target.X, 0, target.Z).Unit
			local start = dir * (A.CornucopiaRadius - 2)
			local len = (target - start).Magnitude
			local side = Vector3.new(-dir.Z, 0, dir.X)
			local n = math.max(2, math.ceil(len / 45))
			local line = { start }
			for k = 1, n - 1 do
				local t = k / n
				local wobble = rng:NextNumber(-1, 1) * math.min(16, len * 0.08)
				table.insert(line, start:Lerp(target, t) + side * wobble)
			end
			table.insert(line, target)
			table.insert(roads, line)
		end
		TerrainGen.addPaths(land, roads)

		-- 3. The terrain itself
		TerrainGen.generate(land)

		-- 4. The cornucopia and the landmarks
		local corn = Structures.cornucopia(folder, plazaY, def.style)
		local chestSpots: { Structures.ChestSpot } = table.clone(corn.chests)
		for _, poi in pois do
			local builder = Landmarks.Builders[poi.kind]
			if builder then
				for _, spot in builder(decor, poi.pos, heightAt, rng, def.style) do
					table.insert(chestSpots, spot)
				end
			else
				warn("[MapService] unknown landmark " .. poi.kind)
			end
			task.wait()
		end

		-- 5. Bridges, the volcano and the sky
		if def.paths.crossing == "bridge" then
			Scenery.bridges(decor, land.paths, heightAt, liquid, def.style)
		end
		if land.volcano then
			Scenery.volcano(folder, land.volcano :: Vector3, land.volcanoCrater)
		end
		if def.sky == "Aurora" then
			Scenery.aurora(folder, radius, plazaY + 210, rng)
		end

		local function nearPoi(x: number, z: number, dist: number): boolean
			for _, p in pois do
				if (Vector3.new(x, 0, z) - p.pos).Magnitude < dist + p.room - 14 then
					return true
				end
			end
			return false
		end

		-- 6. Scattered chests, kept well apart so loot is worth travelling for
		local outer: { Vector3 } = {}
		local attempts = 0
		while #outer < def.outerChests and attempts < 4000 do
			attempts += 1
			local x, z = polar(rng:NextNumber(0, math.pi * 2), rng:NextNumber(A.PedestalRadius + 28, radius - 35))
			local h = heightAt(x, z)
			if h > liquid + 1 and not steep(x, z) and not nearPoi(x, z, A.ChestSpacing) then
				local spaced = true
				for _, p in outer do
					if (Vector3.new(x, 0, z) - p).Magnitude < A.ChestSpacing then
						spaced = false
						break
					end
				end
				if spaced then
					table.insert(outer, Vector3.new(x, 0, z))
					table.insert(chestSpots, {
						cframe = CFrame.new(x, h + 1, z) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0),
						tier = "Outer",
					})
				end
			end
		end

		-- 7. Decoration (some of it in little clusters, some only by the water)
		local cliff = def.terrain.cliffHeight + 8
		local function wetNear(x: number, z: number, r: number): boolean
			for k = 0, 7 do
				local a = k * math.pi / 4
				for _, d in { r * 0.5, r } do
					if heightAt(x + math.cos(a) * d, z + math.sin(a) * d) < liquid + 0.5 then
						return true
					end
				end
			end
			return false
		end
		local function clearOfChests(x: number, z: number): boolean
			for _, p in outer do
				if (Vector3.new(x, 0, z) - p).Magnitude < 6 then
					return false
				end
			end
			return true
		end
		for _, entry in def.decor do
			local placed, tries = 0, 0
			local blocking = Decor.Blocking[entry.kind] == true
			local minDist = A.PedestalRadius + (if entry.kind == "tree" then 16 else 10)
			local maxDist = radius + (if entry.kind == "bush" then -10 else 15)
			local maxTries = entry.count * (if entry.nearWater then 40 else 12)
			local function fits(x: number, z: number): (boolean, number)
				local h = heightAt(x, z)
				if h <= liquid + 1.5 or h >= cliff or nearPoi(x, z, 18) or not clearOfChests(x, z) then
					return false, h
				end
				if blocking and land.isPath(x, z) then
					return false, h
				end
				return true, h
			end
			while placed < entry.count and tries < maxTries do
				tries += 1
				local x, z = polar(rng:NextNumber(0, math.pi * 2), rng:NextNumber(minDist, maxDist))
				local okHere, h = fits(x, z)
				if okHere and (not entry.nearWater or wetNear(x, z, entry.nearWater)) then
					local members = if entry.cluster then rng:NextInteger(entry.cluster[1], entry.cluster[2]) else 1
					for m = 1, members do
						local px, pz, ph = x, z, h
						if m > 1 then
							local a = rng:NextNumber(0, math.pi * 2)
							local d = rng:NextNumber(1.5, entry.spread or 5)
							px, pz = x + math.cos(a) * d, z + math.sin(a) * d
							local okMember
							okMember, ph = fits(px, pz)
							if not okMember then
								continue
							end
						end
						local styleName = entry.styles[rng:NextInteger(1, #entry.styles)]
						Decor.build(entry.kind, styleName, decor, Vector3.new(px, ph, pz), rng, def.style)
						placed += 1
						if placed % 25 == 0 then
							task.wait()
						end
					end
				end
			end
		end

		worldEdge(folder, radius, 350)

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

-- The height of the current arena's water / lava / ice (anything below it is wet).
function MapService.liquidLevel(): number
	local arena = MapService.arena
	return if arena then arena.def.terrain.liquidLevel else -math.huge
end

function MapService.radius(): number
	local arena = MapService.arena
	return if arena then arena.radius else 400
end

return MapService
