-- Lays out the battle royale island (a realm map such as MapDefs.Royale): the named towns, castles
-- and villages of every realm and the roads between them, landmarks scattered through each realm,
-- bridges, the volcano, chests dotted all over, and decoration that matches the ground it grows on.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Build = require(script.Parent.Build)
local MapDefs = require(script.Parent.MapDefs)
local TerrainGen = require(script.Parent.TerrainGen)
local Structures = require(script.Parent.Structures)
local Decor = require(script.Parent.Decor)
local Landmarks = require(script.Parent.Landmarks)
local Scenery = require(script.Parent.Scenery)

type MapDef = MapDefs.MapDef
type Biome = MapDefs.Biome

local RealmGen = {}

local A = Config.Arena

export type Location = {
	name: string,
	realm: string,
	pos: Vector3, -- on the ground in the middle of the place
	radius: number,
}

export type Result = {
	land: TerrainGen.Land,
	chestSpots: { Structures.ChestSpot },
	locations: { Location },
}

type Poi = { pos: Vector3, kind: string, room: number, biome: number, name: string? }

function RealmGen.build(seed: number, def: MapDef, folder: Instance, decor: Instance): Result
	local biomes = def.biomes :: { Biome }
	local land = TerrainGen.makeRealmLand(seed, def)
	local heightAt = land.heightAt
	local biomeAt = land.biomeAt :: (number, number) -> number
	local rng = Random.new(seed + 1)
	local R = def.radius
	local liquid = def.terrain.liquidLevel
	local sectors = 0
	for _, b in biomes do
		if b.angle then
			sectors += 1
		end
	end
	local half = math.pi / math.max(1, sectors)
	local volcanoRadius = 0
	for _, b in biomes do
		if b.shape.volcano then
			volcanoRadius = b.shape.volcano.radius
		end
	end

	local function polar(angle: number, dist: number): (number, number)
		return math.cos(angle) * dist, math.sin(angle) * dist
	end

	local function steep(x: number, z: number): boolean
		local h = heightAt(x, z)
		return math.abs(heightAt(x + 3, z) - h) > 2.5 or math.abs(heightAt(x, z + 3) - h) > 2.5
	end

	-- how uneven (and how wet) the ground is under a footprint
	local function footprint(x: number, z: number, r: number): (number, number)
		local lo, hi, wet = math.huge, -math.huge, 0
		for k = 0, 8 do
			local a = k * math.pi / 4
			local d = if k == 8 then 0 else r
			local h = heightAt(x + math.cos(a) * d, z + math.sin(a) * d)
			lo, hi = math.min(lo, h), math.max(hi, h)
			if h < liquid + 2 then
				wet += 1
			end
		end
		return hi - lo, wet
	end

	local pois: { Poi } = {}
	local function clash(x: number, z: number, room: number): boolean
		for _, p in pois do
			if (Vector3.new(x, 0, z) - p.pos).Magnitude < room + p.room + 30 then
				return true
			end
		end
		local v = land.volcano
		if v and Vector3.new(x - v.X, 0, z - v.Z).Magnitude < volcanoRadius * 0.85 + room then
			return true
		end
		return false
	end
	local function score(x: number, z: number, room: number, biome: number?): number
		local bumps, wet = footprint(x, z, room)
		local s = bumps + wet * 60
		if math.sqrt(x * x + z * z) > R * 0.9 - room then
			s += 200 -- too close to the beach
		end
		if clash(x, z, room) then
			s += 300
		end
		if biome and biomeAt(x, z) ~= biome then
			s += 80
		end
		return s
	end

	-- 1. The named places, near where the map definition puts them
	for bi, b in biomes do
		for _, n in b.named do
			local room = Landmarks.Footprint[n.builder] or 30
			local tx, tz = polar(math.rad(n.angle), n.radius * R)
			local bestX, bestZ, best = tx, tz, math.huge
			for attempt = 1, 30 do
				local x, z = tx, tz
				if attempt > 1 then
					local ox, oz = polar(rng:NextNumber(0, math.pi * 2), rng:NextNumber(10, 90))
					x, z = tx + ox, tz + oz
				end
				local s = score(x, z, room, if n.radius > 0 then bi else nil)
					+ Vector3.new(x - tx, 0, z - tz).Magnitude * 0.05
				if s < best then
					bestX, bestZ, best = x, z, s
				end
				if best < 6 then
					break
				end
			end
			table.insert(
				pois,
				{ pos = Vector3.new(bestX, 0, bestZ), kind = n.builder, room = room, biome = bi, name = n.name }
			)
		end
	end
	local named = table.clone(pois)

	-- 2. Smaller landmarks scattered through every realm
	local function sample(b: Biome, inner: number, outer: number): (number, number)
		local r = R * math.sqrt(rng:NextNumber(inner * inner, outer * outer))
		local a = if b.angle
			then math.rad(b.angle) + rng:NextNumber(-half, half) * 0.92
			else rng:NextNumber(0, math.pi * 2)
		return polar(a, r)
	end
	local function band(b: Biome): (number, number)
		if b.angle then
			return 0.34, 0.88
		end
		return 0.12, 0.27
	end
	for bi, b in biomes do
		local inner, outer = band(b)
		for i = 1, b.poiCount do
			local kind = b.pois[(i - 1) % #b.pois + 1]
			local room = Landmarks.Footprint[kind] or 14
			local bestX, bestZ, best = 0, 0, math.huge
			for _ = 1, 24 do
				local x, z = sample(b, inner, outer)
				local s = score(x, z, room, bi)
				if s < best then
					bestX, bestZ, best = x, z, s
				end
				if best < 5 then
					break
				end
			end
			table.insert(pois, { pos = Vector3.new(bestX, 0, bestZ), kind = kind, room = room, biome = bi })
		end
	end

	-- 3. Roads: the town square out to the nearer named place of every realm, on to its farther
	-- one, and round a ring between the nearer ones
	local roads: { { Vector3 } } = {}
	local function road(from: Vector3, to: Vector3)
		local dir = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
		local len = dir.Magnitude
		if len < 1 then
			return
		end
		local side = Vector3.new(-dir.Z, 0, dir.X) / len
		local n = math.max(2, math.ceil(len / 45))
		local line = { from }
		for k = 1, n - 1 do
			local wobble = rng:NextNumber(-1, 1) * math.min(16, len * 0.06)
			table.insert(line, from:Lerp(to, k / n) + side * wobble)
		end
		table.insert(line, to)
		table.insert(roads, line)
	end
	local function arc(from: Vector3, to: Vector3)
		local a0, a1 = math.atan2(from.Z, from.X), math.atan2(to.Z, to.X)
		local da = ((a1 - a0 + math.pi) % (2 * math.pi)) - math.pi
		local r0, r1 = Vector3.new(from.X, 0, from.Z).Magnitude, Vector3.new(to.X, 0, to.Z).Magnitude
		local steps = math.max(3, math.ceil(math.abs(da) * (r0 + r1) / 2 / 45))
		local line = { from }
		for k = 1, steps - 1 do
			local t = k / steps
			local x, z = polar(a0 + da * t, r0 + (r1 - r0) * t + rng:NextNumber(-10, 10))
			table.insert(line, Vector3.new(x, 0, z))
		end
		table.insert(line, to)
		table.insert(roads, line)
	end
	local hub: Poi? = nil
	local innerPlaces: { Poi } = {}
	for _, p in named do
		if not biomes[p.biome].angle then
			hub = p
		end
	end
	for bi, b in biomes do
		if b.angle then
			local near, far = nil :: Poi?, nil :: Poi?
			for _, p in named do
				if p.biome == bi then
					local d = p.pos.Magnitude
					if not near or d < (near :: Poi).pos.Magnitude then
						far = near
						near = p
					elseif not far or d > (far :: Poi).pos.Magnitude then
						far = p
					end
				end
			end
			if near then
				table.insert(innerPlaces, near)
				if hub then
					road((hub :: Poi).pos, near.pos)
				end
				if far then
					road(near.pos, far.pos)
				end
			end
		end
	end
	table.sort(innerPlaces, function(a, b)
		return math.atan2(a.pos.Z, a.pos.X) < math.atan2(b.pos.Z, b.pos.X)
	end)
	for i, p in innerPlaces do
		local nextOne = innerPlaces[i % #innerPlaces + 1]
		if #innerPlaces > 1 and nextOne ~= p then
			arc(p.pos, nextOne.pos)
		end
	end
	TerrainGen.addPaths(land, roads)

	-- 4. The terrain itself
	TerrainGen.generate(land)

	-- 5. Landmarks, named places and their floating names
	local chestSpots: { Structures.ChestSpot } = {}
	local labels = Build.make("Folder", { Name = "Locations" }, folder)
	local locations: { Location } = {}
	for _, poi in pois do
		local b = biomes[poi.biome]
		local builder = Landmarks.Builders[poi.kind]
		if builder then
			for _, spot in builder(decor, poi.pos, heightAt, rng, b.style) do
				table.insert(chestSpots, spot)
			end
		else
			warn("[RealmGen] unknown landmark " .. poi.kind)
		end
		if poi.name then
			local ground = Vector3.new(poi.pos.X, heightAt(poi.pos.X, poi.pos.Z), poi.pos.Z)
			Scenery.locationLabel(labels, poi.name :: string, b.name, ground, b.style.accent)
			table.insert(locations, { name = poi.name :: string, realm = b.name, pos = ground, radius = poi.room })
		end
		task.wait()
	end

	-- 6. Bridges and the volcano
	Scenery.bridges(decor, land.paths, heightAt, liquid, def.style)
	if land.volcano then
		Scenery.volcano(folder, land.volcano :: Vector3, land.volcanoCrater)
	end

	local function nearPoi(x: number, z: number, dist: number): boolean
		for _, p in pois do
			if (Vector3.new(x, 0, z) - p.pos).Magnitude < dist + p.room then
				return true
			end
		end
		return false
	end

	-- 7. Chests dotted over the whole island, kept apart so every one is worth the trip
	local outer: { Vector3 } = {}
	local attempts = 0
	while #outer < def.outerChests and attempts < def.outerChests * 40 do
		attempts += 1
		local x, z = polar(rng:NextNumber(0, math.pi * 2), R * math.sqrt(rng:NextNumber(0.01, 0.85)))
		local h = heightAt(x, z)
		if h > liquid + 1 and not steep(x, z) and not nearPoi(x, z, A.ChestSpacing - 14) then
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

	-- 8. Decoration, realm by realm (only where that realm's ground is)
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
			if math.abs(p.X - x) < 6 and math.abs(p.Z - z) < 6 then
				return false
			end
		end
		return true
	end
	local placedTotal = 0
	for bi, b in biomes do
		-- (a little past the realm's edges: the biome check trims it to the realm's real ground)
		local inner = if b.angle then 0.26 else 0.05
		local outerBand = if b.angle then 0.97 else 0.33
		for _, entry in b.decor do
			local placed, tries = 0, 0
			local blocking = Decor.Blocking[entry.kind] == true
			local maxTries = entry.count * (if entry.nearWater then 40 else 14)
			local function fits(x: number, z: number): (boolean, number)
				local h = heightAt(x, z)
				if h <= liquid + 1.5 or h >= cliff or biomeAt(x, z) ~= bi then
					return false, h
				end
				if nearPoi(x, z, 4) or not clearOfChests(x, z) or (blocking and land.isPath(x, z)) then
					return false, h
				end
				return true, h
			end
			while placed < entry.count and tries < maxTries do
				tries += 1
				local x, z = sample(b, inner, outerBand)
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
						Decor.build(entry.kind, styleName, decor, Vector3.new(px, ph, pz), rng, b.style)
						placed += 1
						placedTotal += 1
						if placedTotal % 25 == 0 then
							task.wait()
						end
					end
				end
			end
		end
	end

	return { land = land, chestSpots = chestSpots, locations = locations }
end

return RealmGen
