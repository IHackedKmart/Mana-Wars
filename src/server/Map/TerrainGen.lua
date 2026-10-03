-- Generates a fresh island arena with Roblox smooth terrain: rolling hills, lakes,
-- a flat plaza in the centre for the cornucopia, and mountains around the edge.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local TerrainGen = {}

local A = Config.Arena
local RES = 4
local MIN_Y = -24
local MAX_Y = 176

local function smoothstep(e0: number, e1: number, x: number): number
	local t = math.clamp((x - e0) / (e1 - e0), 0, 1)
	return t * t * (3 - 2 * t)
end

-- Returns a deterministic height function for a seed. The same function is used to
-- place trees, chests and ruins so they always sit on the ground.
function TerrainGen.makeHeight(seed: number): (number, number) -> number
	local rng = Random.new(seed)
	local ox, oz = rng:NextNumber(-5000, 5000), rng:NextNumber(-5000, 5000)
	local flatRadius = A.PedestalRadius + 14
	local edge = A.Radius - 30
	return function(x: number, z: number): number
		local d = math.sqrt(x * x + z * z)
		local nx, nz = x + ox, z + oz
		local n = math.noise(nx / 170, nz / 170, 0.37) * 36
			+ math.noise(nx / 64, nz / 64, 7.13) * 13
			+ math.noise(nx / 22, nz / 22, 3.31) * 3
		local h = A.BaseHeight + n
		-- flatten the middle for the cornucopia plaza
		local t = smoothstep(flatRadius, flatRadius + 45, d)
		h = (A.BaseHeight + 1) * (1 - t) + h * t
		-- raise mountains around the rim so the island has a natural wall
		if d > edge then
			local e = (d - edge) / 60
			h += e * e * 85 + math.noise(x / 40, z / 40, 9.7) * 12 * math.min(e, 1)
		end
		return h
	end
end

function TerrainGen.plazaHeight(): number
	return A.BaseHeight + 1
end

local function surfaceMaterial(h: number, slope: number, x: number, z: number): Enum.Material
	if h < A.WaterLevel + 1.5 then
		return Enum.Material.Sand
	elseif h > 78 then
		return Enum.Material.Snow
	elseif slope > 1.15 or h > 50 then
		return Enum.Material.Rock
	end
	local patch = math.noise(x / 45, z / 45, 2.2)
	if patch > 0.25 then
		return Enum.Material.LeafyGrass
	elseif patch < -0.35 then
		return Enum.Material.Ground
	end
	return Enum.Material.Grass
end

-- Writes the terrain. Yields between chunks so the server stays responsive.
function TerrainGen.generate(heightAt: (number, number) -> number)
	local terrain = workspace.Terrain
	terrain:Clear()

	local R = math.ceil((A.Radius + 96) / RES) * RES
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
					local surface = surfaceMaterial(h, slope, x, z)
					for iy = 1, ny do
						local y0 = MIN_Y + (iy - 1) * RES
						local fill = math.clamp((h - y0) / RES, 0, 1)
						local mat = Enum.Material.Air
						local occ = 0
						if fill > 0 then
							local depth = h - (y0 + RES)
							if depth > 12 then
								mat = Enum.Material.Rock
							elseif depth > 3 and surface ~= Enum.Material.Sand and surface ~= Enum.Material.Snow then
								mat = if surface == Enum.Material.Rock then Enum.Material.Rock else Enum.Material.Ground
							else
								mat = surface
							end
							occ = fill
						elseif y0 < A.WaterLevel then
							mat = Enum.Material.Water
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
