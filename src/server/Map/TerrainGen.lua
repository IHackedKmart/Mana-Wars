-- Generates a fresh island arena with Roblox smooth terrain: hills, lakes (water, ice or lava), winding
-- rivers, stepped mesas with striped cliffs, a volcano, dirt roads out to the landmarks, a flat plaza in
-- the middle for the cornucopia, and an uneven ring of mountains around the edge.
-- Everything about the look comes from the map definition (see MapDefs).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local MapDefs = require(script.Parent.MapDefs)

type MapDef = MapDefs.MapDef

local TerrainGen = {}

local A = Config.Arena
local RES = 4
local MIN_Y = -24
local MAX_Y = 200

local function smoothstep(e0: number, e1: number, x: number): number
	local t = math.clamp((x - e0) / (e1 - e0), 0, 1)
	return t * t * (3 - 2 * t)
end

export type Land = {
	def: MapDef,
	seed: number,
	heightAt: (number, number) -> number, -- the ground, including raised causeways
	baseHeightAt: (number, number) -> number, -- the ground before roads were added
	riverAt: (number, number) -> number, -- 0 = no river, 1 = the middle of the channel
	surfaceAt: (number, number, number, number) -> Enum.Material,
	materialsAt: (number, number) -> MapDefs.Materials, -- the material set used at a point
	biomeAt: ((number, number) -> number)?, -- realm maps: which biome (index into def.biomes)
	isPath: (number, number) -> boolean,
	paths: { { Vector3 } },
	volcano: Vector3?, -- the middle of the crater, at the crater floor
	volcanoCrater: number,
	pathCells: { [number]: boolean },
	cellKey: (number, number) -> number,
}

-- Builds the island's shape for a seed and map. The same height function is used to place trees,
-- chests and ruins so they always sit on the ground.
function TerrainGen.makeLand(seed: number, def: MapDef): Land
	local rng = Random.new(seed)
	local ox, oz = rng:NextNumber(-5000, 5000), rng:NextNumber(-5000, 5000)
	local rimSeed = rng:NextNumber(0, 100)
	local T = def.terrain
	local flatRadius = A.PedestalRadius + 14
	local edge = def.radius - 30
	local plaza = MapDefs.plazaHeight(def)

	local vx, vz, V = 0, 0, T.volcano
	if V then
		local a = rng:NextNumber(0, math.pi * 2)
		vx, vz = math.cos(a) * (def.radius + 20), math.sin(a) * (def.radius + 20)
	end

	-- the river: 1 in the middle of the channel, falling to 0 at its banks. `valley` is the much wider
	-- dip the river runs through, so it doesn't cut a gorge through the hills.
	local function riverParts(x: number, z: number): (number, number)
		local R = T.river
		if not R then
			return 0, 0
		end
		local d = math.sqrt(x * x + z * z)
		local mask = smoothstep(flatRadius + 30, flatRadius + 80, d) * (1 - smoothstep(edge - 50, edge - 5, d))
		if mask <= 0 then
			return 0, 0
		end
		local r = math.abs(math.noise((x + ox) / R.scale, (z + oz) / R.scale, 4.41))
		local valleyWidth = R.width * 7
		if r >= valleyWidth then
			return 0, 0
		end
		local channel = if r < R.width then smoothstep(0, 1, 1 - r / R.width) else 0
		return channel * mask, smoothstep(0, 1, 1 - r / valleyWidth) * mask
	end
	local function riverAt(x: number, z: number): number
		local channel = riverParts(x, z)
		return channel
	end

	local function mesaAt(x: number, z: number, d: number): number
		local S = T.mesas
		if not S then
			return 0
		end
		local mask = smoothstep(flatRadius + 50, flatRadius + 100, d) * (1 - smoothstep(edge - 40, edge, d))
		if mask <= 0 then
			return 0
		end
		local m = math.noise((x + ox) / S.scale, (z + oz) / S.scale, 8.83)
		local h = 0
		for i = 0, S.steps - 1 do
			local threshold = S.threshold + i * 0.085
			h += S.step * smoothstep(threshold, threshold + 0.022, m)
		end
		return h * mask
	end

	local function baseHeightAt(x: number, z: number): number
		local d = math.sqrt(x * x + z * z)
		local nx, nz = x + ox, z + oz
		local n = math.noise(nx / T.hillScale, nz / T.hillScale, 0.37) * T.hills
			+ math.noise(nx / 64, nz / 64, 7.13) * T.detail
			+ math.noise(nx / 22, nz / 22, 3.31) * T.rough
		local h = T.base + n + mesaAt(x, z, d)
		-- carve the river: a broad valley down to just above the water, then the channel itself
		local k, valley = riverParts(x, z)
		if valley > 0 then
			local R = T.river :: any
			if not R.dry then
				local floor = T.liquidLevel + 2.5
				if h > floor then
					h += (floor - h) * valley * 0.9
				end
			end
			if k > 0 then
				local bottom = if R.dry then h - R.depth else math.min(h - R.depth, T.liquidLevel - R.depth * 0.5)
				h += (bottom - h) * k
			end
		end
		-- flatten the middle for the cornucopia plaza
		local t = smoothstep(flatRadius, flatRadius + 45, d)
		h = plaza * (1 - t) + h * t
		-- an uneven ring of mountains around the rim so the island has a natural wall
		local angle = math.atan2(z, x)
		local ca, sa = math.cos(angle), math.sin(angle)
		local start = edge - 6 + math.noise(ca * 2.2 + rimSeed, sa * 2.2, 1.7) * 22
		if d > start then
			-- rises like the old wall at first, then levels off at a height that changes around the rim,
			-- with ridges and peaks on top, so the skyline is mountains rather than one flat wall
			local e = (d - start) / 70
			local amp = T.mountains
				* (0.45 + 0.85 * math.clamp(math.noise(ca * 1.9 + rimSeed, sa * 1.9, 2.9) + 0.5, 0, 1))
			local rise = 1 - math.exp(-e * e * 1.6)
			local ridges = math.abs(math.noise(x / 70, z / 70, 6.1)) * 45 + math.noise(x / 30, z / 30, 9.7) * 10
			h += rise * amp + ridges * math.min(e, 1)
		end
		-- the volcano (it sits in the rim, so its slopes reach into the island)
		if V then
			local dv = math.sqrt((x - vx) ^ 2 + (z - vz) ^ 2)
			if dv < V.radius then
				local cone = V.height * (1 - dv / V.radius) ^ 1.7
				if dv < V.crater then
					local lip = V.height * (1 - V.crater / V.radius) ^ 1.7
					cone = lip - (V.crater - dv) * 0.8
				end
				h = math.max(h, plaza + cone + math.noise(x / 18, z / 18, 4.2) * 4)
			end
		end
		return h
	end

	-- roads: cells (RES x RES) the paths cover, filled in by TerrainGen.addPaths
	local pathCells: { [number]: boolean } = {}
	local function cellKey(x: number, z: number): number
		return (math.floor(x / RES) + 4096) * 8192 + (math.floor(z / RES) + 4096)
	end
	local function isPath(x: number, z: number): boolean
		return pathCells[cellKey(x, z)] == true
	end

	local causeway = def.paths.crossing == "causeway"
	local function heightAt(x: number, z: number): number
		local h = baseHeightAt(x, z)
		if causeway and h < T.liquidLevel + 3 and isPath(x, z) then
			return T.liquidLevel + 3
		end
		return h
	end

	local function surfaceAt(x: number, z: number, h: number, slope: number): Enum.Material
		if V and (x - vx) ^ 2 + (z - vz) ^ 2 < (V.crater + 2) ^ 2 then
			return Enum.Material.CrackedLava
		end
		return TerrainGen.surfaceWith(def, def.materials, x, z, h, slope, ox, oz, riverAt, isPath)
	end

	local land: Land = {
		def = def,
		seed = seed,
		heightAt = heightAt,
		baseHeightAt = baseHeightAt,
		riverAt = riverAt,
		surfaceAt = surfaceAt,
		materialsAt = function()
			return def.materials
		end,
		biomeAt = nil,
		isPath = isPath,
		paths = {},
		volcano = nil,
		volcanoCrater = if V then V.crater else 0,
		pathCells = pathCells,
		cellKey = cellKey,
	}
	if V then
		land.volcano = Vector3.new(vx, baseHeightAt(vx, vz), vz)
	end
	return land
end

-- Picks the surface material at a point from a material set (shore, wet band, peaks, cliffs,
-- riverbeds, roads, then noise patches).
function TerrainGen.surfaceWith(
	def: MapDef,
	m: MapDefs.Materials,
	x: number,
	z: number,
	h: number,
	slope: number,
	ox: number,
	oz: number,
	riverAt: (number, number) -> number,
	isPath: (number, number) -> boolean
): Enum.Material
	local T = def.terrain
	local wob = math.noise(x / 16, z / 16, 5.5)
	if h < T.liquidLevel + 1.5 + wob then
		return m.shore
	elseif m.wet and h < T.liquidLevel + m.wet.height + wob * 1.5 then
		return m.wet.material
	elseif h > T.peakHeight + wob * 10 then
		return m.peak
	elseif slope > 1.15 or h > T.cliffHeight + wob * 12 then
		return m.cliff
	end
	if m.riverbed and riverAt(x, z) > 0.2 then
		return m.riverbed
	end
	if slope < 0.9 and isPath(x, z) then
		return m.path
	end
	if m.patches then
		for i, p in m.patches do
			if math.noise((x + ox) / p.scale, (z + oz) / p.scale, 2.2 + i * 1.7) > p.threshold then
				return p.material
			end
		end
		return m.surface
	end
	local patch = math.noise(x / 45, z / 45, 2.2)
	if patch > 0.25 then
		return m.alt
	elseif patch < -0.35 then
		return m.alt2
	end
	return m.surface
end

-- Realm maps (the battle royale island): a heartland in the middle and a ring of biomes around it,
-- each with its own shape (peaks, mesas, a volcano), materials and decoration, blended at the
-- borders, with beaches and open sea instead of a mountain wall around the edge.
function TerrainGen.makeRealmLand(seed: number, def: MapDef): Land
	local biomes = def.biomes :: { MapDefs.Biome }
	local rng = Random.new(seed)
	local ox, oz = rng:NextNumber(-5000, 5000), rng:NextNumber(-5000, 5000)
	local T = def.terrain
	local R = def.radius
	local sectors = 0
	for _, b in biomes do
		if b.angle then
			sectors += 1
		end
	end
	local half = math.pi / math.max(1, sectors)

	-- the volcano sits in the realm that has one, most of the way out
	local vx, vz, V = 0, 0, nil :: { height: number, radius: number, crater: number }?
	for _, b in biomes do
		if b.shape.volcano and b.angle then
			V = b.shape.volcano
			local a = math.rad(b.angle) + rng:NextNumber(-0.12, 0.12)
			vx, vz = math.cos(a) * R * 0.66, math.sin(a) * R * 0.66
		end
	end

	-- how much each biome counts at a point (they add up to 1)
	local function weights(x: number, z: number): { number }
		local r = math.sqrt(x * x + z * z) / R + math.noise((x + ox) / 180, (z + oz) / 180, 5.2) * 0.07
		local inner = 1 - smoothstep(0.24, 0.34, r)
		local a = math.atan2(z, x) + math.noise((x + ox) / 320, (z + oz) / 320, 13.1) * 0.5
		local w = table.create(#biomes, 0)
		local total = 0
		for i, b in biomes do
			if b.angle then
				local da = math.abs(((a - math.rad(b.angle) + math.pi) % (2 * math.pi)) - math.pi)
				w[i] = (1 - smoothstep(half - 0.16, half + 0.16, da)) * (1 - inner)
			else
				w[i] = inner
			end
			total += w[i]
		end
		for i = 1, #w do
			w[i] /= math.max(total, 1e-6)
		end
		return w
	end

	-- the biome whose materials and decoration a point gets (with a ragged border)
	local function biomeAt(x: number, z: number): number
		local w = weights(x, z)
		local best, bestW = 1, -math.huge
		for i, wi in w do
			local v = wi + math.noise(x / 26, z / 26, i * 3.3) * 0.14
			if v > bestW then
				best, bestW = i, v
			end
		end
		return best
	end

	local function mesaAt(
		S: { scale: number, threshold: number, step: number, steps: number },
		x: number,
		z: number
	): number
		local m = math.noise((x + ox) / S.scale, (z + oz) / S.scale, 8.83)
		local h = 0
		for i = 0, S.steps - 1 do
			local threshold = S.threshold + i * 0.085
			h += S.step * smoothstep(threshold, threshold + 0.022, m)
		end
		return h
	end

	local plaza = MapDefs.plazaHeight(def)
	local function baseHeightAt(x: number, z: number): number
		local d = math.sqrt(x * x + z * z)
		local w = weights(x, z)
		local nx, nz = x + ox, z + oz
		-- each realm's own hills, blended (blending the noise scale instead would squeeze the hills
		-- into ripples along the borders)
		local base, h = 0, 0
		local fine1, fine2 = math.noise(nx / 64, nz / 64, 7.13), math.noise(nx / 22, nz / 22, 3.31)
		for i, b in biomes do
			local wi = w[i]
			if wi > 0 then
				local sh = b.shape
				base += sh.base * wi
				h += wi * (sh.base + math.noise(nx / sh.hillScale, nz / sh.hillScale, 0.37) * sh.hills + fine1 * sh.detail + fine2 * sh.rough)
			end
		end
		local inland = 1 - smoothstep(R * 0.8, R * 0.95, d)
		for i, b in biomes do
			local wi = w[i]
			if wi > 0.01 then
				local sh = b.shape
				if sh.peaks then
					local ridge = 1 - math.abs(math.noise(nx / 240, nz / 240, 9.4))
					h += ridge ^ 3 * sh.peaks * wi * inland
				end
				if sh.mesas then
					h += mesaAt(sh.mesas, x, z) * wi * inland
				end
			end
		end
		-- a flat square in the very middle (the heart of the island's biggest town)
		local t = smoothstep(55, 95, d)
		h = plaza * (1 - t) + h * t
		-- the volcano
		if V then
			local v = V :: { height: number, radius: number, crater: number }
			local dv = math.sqrt((x - vx) ^ 2 + (z - vz) ^ 2)
			if dv < v.radius then
				local cone = v.height * (1 - dv / v.radius) ^ 1.7
				if dv < v.crater then
					cone = v.height * (1 - v.crater / v.radius) ^ 1.7 - (v.crater - dv) * 0.8
				end
				h = math.max(h, base + cone + math.noise(x / 18, z / 18, 4.2) * 4)
			end
		end
		-- beaches, then open sea, around a ragged coastline
		local angle = math.atan2(z, x)
		local coast = R - 40 + math.noise(math.cos(angle) * 2.4 + ox * 0.001, math.sin(angle) * 2.4, 3.7) * 70
		local sea = smoothstep(coast - 80, coast + 30, d)
		h += (T.liquidLevel - 14 - h) * sea
		return h
	end

	local pathCells: { [number]: boolean } = {}
	local function cellKey(x: number, z: number): number
		return (math.floor(x / RES) + 4096) * 8192 + (math.floor(z / RES) + 4096)
	end
	local function isPath(x: number, z: number): boolean
		return pathCells[cellKey(x, z)] == true
	end
	local function noRiver(_x: number, _z: number): number
		return 0
	end
	local function materialsAt(x: number, z: number): MapDefs.Materials
		return biomes[biomeAt(x, z)].materials
	end
	local function surfaceAt(x: number, z: number, h: number, slope: number): Enum.Material
		if V and (x - vx) ^ 2 + (z - vz) ^ 2 < ((V :: any).crater + 2) ^ 2 then
			return Enum.Material.CrackedLava
		end
		return TerrainGen.surfaceWith(def, materialsAt(x, z), x, z, h, slope, ox, oz, noRiver, isPath)
	end

	local land: Land = {
		def = def,
		seed = seed,
		heightAt = baseHeightAt,
		baseHeightAt = baseHeightAt,
		riverAt = noRiver,
		surfaceAt = surfaceAt,
		materialsAt = materialsAt,
		biomeAt = biomeAt,
		isPath = isPath,
		paths = {},
		volcano = nil,
		volcanoCrater = if V then (V :: any).crater else 0,
		pathCells = pathCells,
		cellKey = cellKey,
	}
	if V then
		land.volcano = Vector3.new(vx, baseHeightAt(vx, vz), vz)
	end
	return land
end

-- Old entry point: just the height function.
function TerrainGen.makeHeight(seed: number, def: MapDef): (number, number) -> number
	return TerrainGen.makeLand(seed, def).heightAt
end

-- Lays roads along polylines (lists of points). Call before generate().
function TerrainGen.addPaths(land: Land, polylines: { { Vector3 } })
	local cells = land.pathCells
	local key = land.cellKey
	local half = land.def.paths.width / 2
	for _, line in polylines do
		table.insert(land.paths, line)
		for i = 1, #line - 1 do
			local a, b = line[i], line[i + 1]
			local len = (Vector3.new(b.X, 0, b.Z) - Vector3.new(a.X, 0, a.Z)).Magnitude
			local steps = math.max(1, math.ceil(len / 1.5))
			for s = 0, steps do
				local t = s / steps
				local x, z = a.X + (b.X - a.X) * t, a.Z + (b.Z - a.Z) * t
				local r = half + math.noise(x / 9, z / 9, 6.6) * 2
				for dx = -r, r, RES / 2 do
					for dz = -r, r, RES / 2 do
						if dx * dx + dz * dz <= r * r then
							cells[key(x + dx, z + dz)] = true
						end
					end
				end
			end
		end
	end
end

-- Writes the terrain. Yields between chunks so the server stays responsive.
function TerrainGen.generate(land: Land)
	local def = land.def
	local heightAt = land.heightAt
	local terrain = workspace.Terrain
	terrain:Clear()
	for material, color in def.colors do
		pcall(function()
			terrain:SetMaterialColor(material, color)
		end)
	end
	terrain.WaterColor = def.water.color
	terrain.WaterTransparency = def.water.transparency
	terrain.WaterWaveSize = def.water.waves or 0.12
	pcall(function()
		terrain.WaterReflectance = def.water.reflectance or 0.5
	end)

	local T = def.terrain
	local R = math.ceil((def.radius + 96) / RES) * RES
	local cells = (2 * R) // RES
	local ny = (MAX_Y - MIN_Y) // RES

	-- Pre-compute the height grid (with a one cell border for slope estimates).
	local heights: { { number } } = {}
	for ix = 0, cells + 1 do
		local row = {}
		local x = -R + (ix - 1) * RES + RES / 2
		for iz = 0, cells + 1 do
			local z = -R + (iz - 1) * RES + RES / 2
			row[iz] = heightAt(x, z)
		end
		heights[ix] = row
		if ix % 40 == 0 then
			task.wait()
		end
	end

	local CHUNK = 32
	for cx = 0, cells - 1, CHUNK do
		for cz = 0, cells - 1, CHUNK do
			local nx = math.min(CHUNK, cells - cx)
			local nz = math.min(CHUNK, cells - cz)
			local materials = table.create(nx)
			local occupancy = table.create(nx)
			for ix = 1, nx do
				local gx = cx + ix
				local x = -R + (gx - 1) * RES + RES / 2
				local matX = table.create(ny)
				local occX = table.create(ny)
				for iy = 1, ny do
					matX[iy] = table.create(nz)
					occX[iy] = table.create(nz)
				end
				for iz = 1, nz do
					local gz = cz + iz
					local z = -R + (gz - 1) * RES + RES / 2
					local h = heights[gx][gz]
					local slope = (
						math.abs(heights[gx + 1][gz] - heights[gx - 1][gz])
						+ math.abs(heights[gx][gz + 1] - heights[gx][gz - 1])
					) / (2 * RES)
					local mats = land.materialsAt(x, z)
					local surfaceSoil = mats.under
					local cliffMaterial = mats.cliff
					local strata = mats.strata
					local surface = land.surfaceAt(x, z, h, slope)
					local striped = strata ~= nil and surface == cliffMaterial
					local warp = if striped then math.noise(x / 60, z / 60, 3.9) * 4 else 0
					for iy = 1, ny do
						local y0 = MIN_Y + (iy - 1) * RES
						local fill = math.clamp((h - y0) / RES, 0, 1)
						local mat = Enum.Material.Air
						local occ = 0
						if fill > 0 then
							local depth = h - (y0 + RES)
							if striped and depth <= 16 then
								-- striped canyon walls: the band depends on the height, not the depth
								local s = strata :: { Enum.Material }
								mat = s[(math.floor((y0 + warp) / 4.5) % #s) + 1]
							elseif depth > 12 then
								mat = Enum.Material.Rock
							elseif depth > 3 then
								mat = if surface == cliffMaterial then surface else surfaceSoil
							else
								mat = surface
							end
							occ = fill
						elseif y0 < T.liquidLevel then
							mat = T.liquid
							occ = 1
						end
						matX[iy][iz] = mat
						occX[iy][iz] = occ
					end
				end
				materials[ix] = matX
				occupancy[ix] = occX
			end
			local x0 = -R + cx * RES
			local z0 = -R + cz * RES
			local region = Region3.new(Vector3.new(x0, MIN_Y, z0), Vector3.new(x0 + nx * RES, MAX_Y, z0 + nz * RES))
			terrain:WriteVoxels(region, RES, materials, occupancy)
			task.wait()
		end
	end
end

return TerrainGen
