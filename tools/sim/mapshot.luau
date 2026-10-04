--[[
	Map snapshots. Generates arenas with the REAL map code and saves what was built (the terrain surface,
	every part, the lighting) as JSON, so tools/ui/maprender.cjs can draw them as pictures:

		lune run tools/sim/mapshot build/maps            -- every map
		lune run tools/sim/mapshot build/maps Ashen      -- one map (by id)
		lune run tools/sim/mapshot build/maps Hub        -- the hub (Arcanum Plaza) and the library
		node tools/ui/maprender.cjs build/maps/*.json

	The pictures are approximate (no Roblox textures), but good enough to judge colours and layout.
]]

local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")
local Mock = require("./mock")
local roblox = require("@lune/roblox")

local Vector3 = roblox.Vector3

local Instance = Mock.Instance

local outDir = process.args[1] or "build/maps"
local only: { [string]: boolean } = {}
for i = 2, #process.args do
	only[process.args[i]] = true
end
pcall(fs.writeDir, outDir)

local server = Mock.realm({
	RunService = Mock.runService(true),
	Players = {
		PlayerAdded = Mock.signal(),
		PlayerRemoving = Mock.signal(),
		GetPlayers = function()
			return {}
		end,
	},
	TweenService = Mock.TweenService,
	Lighting = Instance.new("Lighting"),
}, true)

local RES = 4

-- the terrain surface, one column per 4x4 stud cell: top height + material, plus the lake bed under water
type Column = { y: number, m: string, fy: number?, fm: string? }
local columns: { [number]: { [number]: Column } } = {}
local materialColors: { [string]: { number } } = {}
local terrain = Mock.workspace.Terrain
rawset(terrain, "Clear", function()
	columns = {}
end)
rawset(terrain, "SetMaterialColor", function(_, material, color)
	materialColors[material.Name] = { color.R, color.G, color.B }
end)
rawset(terrain, "WriteVoxels", function(_, region, res, materials, occupancy)
	assert(res == RES)
	local min = region.CFrame.Position - region.Size / 2
	for ix, matX in materials do
		local gx = math.floor((min.X + (ix - 0.5) * RES) / RES)
		columns[gx] = columns[gx] or {}
		local nz = #matX[1]
		for iz = 1, nz do
			local gz = math.floor((min.Z + (iz - 0.5) * RES) / RES)
			local col: Column? = nil
			for iy = #matX, 1, -1 do
				local occ = occupancy[ix][iy][iz]
				local mat = matX[iy][iz]
				if occ > 0 and mat.Name ~= "Air" then
					local top = min.Y + (iy - 1) * RES + occ * RES
					if not col then
						col = { y = top, m = mat.Name }
						if mat.Name ~= "Water" then
							break
						end
					elseif mat.Name ~= "Water" then
						col.fy = top
						col.fm = mat.Name
						break
					end
				end
			end
			if col then
				columns[gx][gz] = col
			end
		end
	end
end)

local function rgb(c): { number }
	return { c.R, c.G, c.B }
end

local function partsUnder(root): { any }
	local out = {}
	for _, inst in root:GetDescendants() do
		if inst:IsA("BasePart") then
			local props = rawget(inst, "_props")
			local transparency = props.Transparency or 0
			if transparency < 0.98 then
				local cf = props.CFrame or Mock.CFrame.new()
				local shape = props.Shape
				local entry = {
					c = inst.ClassName,
					s = if shape then shape.Name else "Block",
					z = { props.Size.X, props.Size.Y, props.Size.Z },
					f = { cf:GetComponents() },
					k = rgb(props.Color or { R = 0.64, G = 0.64, B = 0.64 }),
					m = if props.Material then props.Material.Name else "Plastic",
					t = transparency,
				}
				-- lights make glowing things glow in the picture too
				local light = inst:FindFirstChildOfClass("PointLight")
				if light then
					local lp = rawget(light, "_props")
					entry.l = { rgb(lp.Color or { R = 1, G = 1, B = 1 }), lp.Range or 8, lp.Brightness or 1 }
				end
				if inst:FindFirstChildOfClass("Fire") then
					entry.fire = true
				end
				table.insert(out, entry)
			end
		end
	end
	return out
end

local function lightingOf(lighting, atmosphere): { [string]: any }
	local out = {}
	for key, value in lighting do
		out[key] = if typeof(value) == "Color3" then rgb(value) else value
	end
	out.atmosphere = {}
	for key, value in atmosphere do
		out.atmosphere[key] = if typeof(value) == "Color3" then rgb(value) else value
	end
	return out
end

-- points of interest worth a close-up: models tagged with a Landmark attribute (or the classic ruins)
local CLASSIC = { RuinedTower = true, Shrine = true, Camp = true, Watchtower = true }
local function landmarks(root): { any }
	local out = {}
	local seen: { [string]: number } = {}
	for _, child in root:GetDescendants() do
		if child.ClassName == "Model" and (child:GetAttribute("Landmark") or CLASSIC[child.Name]) then
			seen[child.Name] = (seen[child.Name] or 0) + 1
			if seen[child.Name] == 1 then
				local sum, n = Vector3.zero, 0
				for _, inst in child:GetDescendants() do
					if inst:IsA("BasePart") then
						sum += rawget(inst, "_props").CFrame.Position
						n += 1
					end
				end
				if n > 0 then
					local c = sum / n
					table.insert(out, { name = child.Name, p = { c.X, c.Y, c.Z } })
				end
			end
		end
	end
	return out
end

local function save(name: string, data: { [string]: any })
	local path = outDir .. "/" .. name .. ".json"
	fs.writeFile(path, serde.encode("json", data))
	print("saved " .. path)
end

local function terrainGrid(): { [string]: any }
	local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
	for gx, row in columns do
		minX, maxX = math.min(minX, gx), math.max(maxX, gx)
		for gz in row do
			minZ, maxZ = math.min(minZ, gz), math.max(maxZ, gz)
		end
	end
	local heights, mats, floors, floorMats = {}, {}, {}, {}
	local names: { string } = {}
	local index: { [string]: number } = {}
	local function id(m: string): number
		if not index[m] then
			table.insert(names, m)
			index[m] = #names - 1
		end
		return index[m]
	end
	for gx = minX, maxX do
		for gz = minZ, maxZ do
			local col = columns[gx] and columns[gx][gz]
			table.insert(heights, if col then math.floor(col.y * 10 + 0.5) / 10 else -30)
			table.insert(mats, if col then id(col.m) else -1)
			table.insert(floors, if col and col.fy then math.floor(col.fy * 10 + 0.5) / 10 else -999)
			table.insert(floorMats, if col and col.fm then id(col.fm) else -1)
		end
	end
	return {
		res = RES,
		x0 = minX * RES,
		z0 = minZ * RES,
		nx = maxX - minX + 1,
		nz = maxZ - minZ + 1,
		heights = heights,
		mats = mats,
		floors = floors,
		floorMats = floorMats,
		names = names,
	}
end

local MapDefs = server.load("Server/Map/MapDefs")
local MapService = server.load("Server/Services/MapService")

MapService.init()

local function run(fn: () -> ())
	local done = false
	local co = Mock.task.spawn(function()
		local ok, err = pcall(fn)
		if not ok then
			print("ERROR " .. tostring(err))
		end
		done = true
	end)
	local guard = 0
	while not done and coroutine.status(co) ~= "dead" and guard < 40000 do
		Mock.step(1 / 60)
		guard += 1
	end
end

if only.Hub or next(only) == nil then
	local hub = Mock.workspace:FindFirstChild("Hub")
	local lobby = Mock.workspace:FindFirstChild("Lobby")
	local first = MapDefs.List[1]
	local parts = partsUnder(hub)
	for _, entry in partsUnder(lobby) do
		table.insert(parts, entry)
	end
	save("Hub", {
		kind = "hub",
		name = "Arcanum Plaza + Library",
		parts = parts,
		lighting = lightingOf(first.lighting, first.atmosphere),
		landmarks = {},
	})
end

-- a line-up of mannequins wearing every robe and hat design
if only.Outfits then
	local Cosmetics = server.load("Shared/Cosmetics")
	local OutfitBuilder = server.load("Shared/OutfitBuilder")
	local stage = Instance.new("Folder", Mock.workspace)
	stage.Name = "Stage"
	local function limb(parent, name: string, size, pos)
		local p = Instance.new("Part", parent)
		p.Name = name
		p.Size = size
		p.CFrame = Mock.CFrame.new(pos)
		p.Color = roblox.Color3.fromRGB(205, 190, 175)
		p.Material = roblox.Enum.Material.SmoothPlastic
		return p
	end
	local function part(slot: string, design: string, color: string, material: string, aura: string?)
		return {
			uid = slot .. design,
			slot = slot,
			rarity = "Epic",
			design = design,
			color = color,
			material = material,
			aura = aura,
			enchants = {},
			box = 1,
			name = design,
		}
	end
	local cloths = Cosmetics.Designs.Cloth
	local shapes = Cosmetics.Designs.Shape
	local trims = Cosmetics.Designs.Trim
	local bands = Cosmetics.Designs.Band
	local gems = Cosmetics.Designs.Gem
	local sigils = Cosmetics.Designs.Sigil
	local palette = {
		"Crimson",
		"Royal",
		"Emerald",
		"Plum",
		"Midnight",
		"Saffron",
		"Teal",
		"Obsidian",
		"Arcane",
		"Frost",
		"Starlight",
		"Sunset",
		"Ivory",
	}
	local accents = {
		"Gold",
		"Ivory",
		"Gold",
		"Saffron",
		"Starlight",
		"Crimson",
		"Gold",
		"Blood",
		"Gold",
		"Sky",
		"Gold",
		"Gold",
		"Royal",
	}
	local materials = {
		"Wool",
		"Velvet",
		"Leather",
		"Silk",
		"Velvet",
		"Wool",
		"Silk",
		"Velvet",
		"Silk",
		"Crystal",
		"Silk",
		"Velvet",
		"Wool",
	}
	local n = math.max(#cloths, #shapes)
	for i = 1, n do
		local x = (i - (n + 1) / 2) * 5
		local m = Instance.new("Model", stage)
		m.Name = "Mannequin"
		limb(m, "LeftUpperLeg", roblox.Vector3.new(1, 1.1, 1), roblox.Vector3.new(x - 0.5, 1.55, 0))
		limb(m, "RightUpperLeg", roblox.Vector3.new(1, 1.1, 1), roblox.Vector3.new(x + 0.5, 1.55, 0))
		limb(m, "LeftLowerLeg", roblox.Vector3.new(1, 1, 1), roblox.Vector3.new(x - 0.5, 0.5, 0))
		limb(m, "RightLowerLeg", roblox.Vector3.new(1, 1, 1), roblox.Vector3.new(x + 0.5, 0.5, 0))
		local lower = limb(m, "LowerTorso", roblox.Vector3.new(2, 0.4, 1), roblox.Vector3.new(x, 2.3, 0))
		local upper = limb(m, "UpperTorso", roblox.Vector3.new(2, 1.6, 1), roblox.Vector3.new(x, 3.3, 0))
		local head = limb(m, "Head", roblox.Vector3.new(1.2, 1.2, 1.2), roblox.Vector3.new(x, 4.7, 0))
		local lu = limb(m, "LeftUpperArm", roblox.Vector3.new(1, 1.2, 1), roblox.Vector3.new(x - 1.5, 3.5, 0))
		local ru = limb(m, "RightUpperArm", roblox.Vector3.new(1, 1.2, 1), roblox.Vector3.new(x + 1.5, 3.5, 0))
		local la = limb(m, "LeftLowerArm", roblox.Vector3.new(1, 1.1, 1), roblox.Vector3.new(x - 1.5, 2.35, 0))
		local ra = limb(m, "RightLowerArm", roblox.Vector3.new(1, 1.1, 1), roblox.Vector3.new(x + 1.5, 2.35, 0))
		local cloth = cloths[(i - 1) % #cloths + 1]
		local shape = shapes[(i - 1) % #shapes + 1]
		local robe = {
			uid = "r" .. i,
			kind = "Robe",
			name = cloth.name,
			rarity = "Epic",
			parts = {
				Cloth = part("Cloth", cloth.id, palette[i], materials[i]),
				Trim = part("Trim", trims[(i - 1) % #trims + 1].id, accents[i], "Silk"),
				Sigil = part("Sigil", sigils[(i - 1) % #sigils + 1].id, accents[i], "Iron"),
			},
		}
		local hat = {
			uid = "h" .. i,
			kind = "Hat",
			name = shape.name,
			rarity = "Epic",
			parts = {
				Shape = part("Shape", shape.id, palette[i], materials[i]),
				Band = part("Band", bands[(i - 1) % #bands + 1].id, accents[i], "Silk"),
				Gem = part("Gem", gems[(i - 1) % #gems + 1].id, "Arcane", "Crystal"),
			},
		}
		OutfitBuilder.build({
			torso = upper,
			hips = lower,
			head = head,
			leftArm = la,
			rightArm = ra,
			leftUpperArm = lu,
			rightUpperArm = ru,
			legLength = 2.1,
			weld = false,
			parent = m,
		}, robe, hat, false)
	end
	local floor = Instance.new("Part", stage)
	floor.Size = roblox.Vector3.new(n * 5 + 10, 1, 14)
	floor.CFrame = Mock.CFrame.new(0, -0.5, 0)
	floor.Color = roblox.Color3.fromRGB(60, 52, 80)
	floor.Material = roblox.Enum.Material.Slate
	save("Outfits", {
		kind = "showcase",
		name = "Outfits",
		count = n,
		parts = partsUnder(stage),
		lighting = {
			ClockTime = 14,
			Brightness = 2.4,
			OutdoorAmbient = { 0.55, 0.55, 0.6 },
			atmosphere = { Density = 0 },
		},
		landmarks = {},
	})
	stage:Destroy()
end

for _, def in MapDefs.List do
	if next(only) ~= nil and not only[def.id] then
		continue
	end
	materialColors = {}
	run(function()
		MapService.generate(1234, def)
	end)
	local arena = Mock.workspace:FindFirstChild("Arena")
	local terrainData = terrainGrid()
	terrainData.colors = materialColors
	save(def.id, {
		kind = "arena",
		id = def.id,
		name = def.name,
		radius = def.radius,
		plazaY = MapDefs.plazaHeight(def),
		liquidLevel = def.terrain.liquidLevel,
		water = { color = rgb(def.water.color), transparency = def.water.transparency },
		terrain = terrainData,
		parts = partsUnder(arena),
		landmarks = landmarks(arena),
		lighting = lightingOf(def.lighting, def.atmosphere),
	})
end
