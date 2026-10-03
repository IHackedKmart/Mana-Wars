-- Generates a fresh island arena with Roblox smooth terrain: hills, lakes (water, ice or lava),
-- a flat plaza in the middle for the cornucopia, and mountains around the edge.
-- Everything about the look comes from the map definition (see MapDefs).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local MapDefs = require(script.Parent.MapDefs)

type MapDef = MapDefs.MapDef

local TerrainGen = {}

local A = Config.Arena
local RES = 4
local MIN_Y = -24
local MAX_Y = 176

local function smoothstep(e0: number, e1: number, x: number): number
	local t = math.clamp((x - e0) / (e1 - e0), 0, 1)
	return t * t * (3 - 2 * t)
end

-- Returns a deterministic height function for a seed and map. The same function is used to
-- place trees, chests and ruins so they always sit on the ground.
function TerrainGen.makeHeight(seed: number, def: MapDef): (number, number) -> number
	local rng = Random.new(seed)
	local ox, oz = rng:NextNumber(-5000, 5000), rng:NextNumber(-5000, 5000)
	local T = def.terrain
	local flatRadius = A.PedestalRadius + 14
	local edge = def.radius - 30
	local plaza = MapDefs.plazaHeight(def)
	return function(x: number, z: number): number
		local d = math.sqrt(x * x + z * z)
		local nx, nz = x + ox, z + oz
		local n = math.noise(nx / T.hillScale, nz / T.hillScale, 0.37) * T.hills
			+ math.noise(nx / 64, nz / 64, 7.13) * T.detail
			+ math.noise(nx / 22, nz / 22, 3.31) * T.rough
		local h = T.base + n
		-- flatten the middle for the cornucopia plaza
		local t = smoothstep(flatRadius, flatRadius + 45, d)
		h = plaza * (1 - t) + h * t
		-- raise mountains around the rim so the island has a natural wall
		if d > edge then
			local e = (d - edge) / 60
			h += e * e * T.mountains + math.noise(x / 40, z / 40, 9.7) * 12 * math.min(e, 1)
		end
		return h
	end
end

local function surfaceMaterial(def: MapDef, h: number, slope: number, x: number, z: number): Enum.Material
	local m = def.materials
	local T = def.terrain
	if h < T.liquidLevel + 1.5 then
		return m.shore
	elseif h > T.peakHeight then
		return m.peak
	elseif slope > 1.15 or h > T.cliffHeight then
		return m.cliff
	end
	local patch = math.noise(x / 45, z / 45, 2.2)
	if patch > 0.25 then
		return m.alt
	elseif patch < -0.35 then
		return m.alt2
	end
	return m.surface
end

-- Writes the terrain. Yields between chunks so the server stays responsive.
function TerrainGen.generate(heightAt: (number, number) -> number, def: MapDef)
	local terrain = workspace.Terrain
	terrain:Clear()
	for material, color in def.colors do
		pcall(function()
			terrain:SetMaterialColor(material, color)
		end)
	end
	terrain.WaterColor = def.water.color
	terrain.WaterTransparency = def.water.transparency
	terrain.WaterWaveSize = 0.12

	local T = def.terrain
	local surfaceSoil = def.materials.under
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
					local surface = surfaceMaterial(def, h, slope, x, z)
					for iy = 1, ny do
						local y0 = MIN_Y + (iy - 1) * RES
						local fill = math.clamp((h - y0) / RES, 0, 1)
						local mat = Enum.Material.Air
						local occ = 0
						if fill > 0 then
							local depth = h - (y0 + RES)
							if depth > 12 then
								mat = Enum.Material.Rock
							elseif depth > 3 then
								mat = if surface == def.materials.cliff then surface else surfaceSoil
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
