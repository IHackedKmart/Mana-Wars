--[[
	Map generation test (run from the repo root with Lune):

		lune run tools/sim/maps

	Builds the hub (Arcanum Plaza), the library lobby and the training dummies, then generates every map in MapDefs
	with the REAL map code (terrain writes are counted, not simulated) and checks the results:
	cornucopia + pedestals, chest counts and spacing, decoration, and no warnings.
]]

local process = require("@lune/process")
local roblox = require("@lune/roblox")
local Mock = require("./mock")

local Instance = Mock.Instance
local Vector3 = roblox.Vector3

local failures = 0
local function fail(msg: string)
	failures += 1
	print("FAIL  " .. msg)
end

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

local voxelWrites = 0
rawset(Mock.workspace.Terrain, "Clear", function() end)
rawset(Mock.workspace.Terrain, "WriteVoxels", function(_, region, res, materials, occupancy)
	voxelWrites += 1
	assert(res == 4, "voxel resolution")
	assert(#materials == #occupancy, "material/occupancy size mismatch")
	local size = region.Size
	assert(#materials == size.X / 4, "x voxels")
	assert(#materials[1] == size.Y / 4, "y voxels")
	assert(#materials[1][1] == size.Z / 4, "z voxels")
end)

local Config = server.load("Shared/Config")
local MapDefs = server.load("Server/Map/MapDefs")
local MapService = server.load("Server/Services/MapService")
local Combatants = server.load("Server/Services/Combatants")
local PracticeService = server.load("Server/Services/PracticeService")

-- Lobby + dummies
MapService.init()
PracticeService.init()
local lobby = Mock.workspace:FindFirstChild("Lobby")
if not lobby then
	fail("lobby was not built")
else
	local parts, prompts, shelves = 0, 0, 0
	for _, inst in lobby:GetDescendants() do
		if inst:IsA("BasePart") then
			parts += 1
		elseif inst.ClassName == "ProximityPrompt" then
			prompts += 1
		elseif inst.ClassName == "Model" and inst.Name == "Bookshelf" then
			shelves += 1
		end
	end
	print(string.format("lobby: %d parts, %d bookshelves, %d prompts", parts, shelves, prompts))
	if prompts < 5 then
		fail("expected lecterns + class altar prompts")
	end
	if shelves < 30 then
		fail("the library needs bookshelves")
	end
	if parts > 4000 then
		fail("lobby is too heavy: " .. parts .. " parts")
	end
	local spawn = lobby:FindFirstChild("LobbySpawn")
	if not spawn then
		fail("lobby spawn missing")
	end
end
local hub = Mock.workspace:FindFirstChild("Hub")
if not hub then
	fail("hub was not built")
else
	local parts, spawns, portals, boards = 0, 0, 0, 0
	for _, inst in hub:GetDescendants() do
		if inst:IsA("BasePart") then
			parts += 1
		end
		if inst.ClassName == "SpawnLocation" then
			spawns += 1
		elseif inst.Name == "PortalSheet" and inst:GetAttribute("PortalAction") == "JoinQueue" then
			portals += 1
		elseif inst.ClassName == "Model" and inst.Name == "Board" then
			boards += 1
		end
	end
	print(string.format("hub: %d parts", parts))
	if spawns ~= 1 then
		fail("the hub should hold the place's only SpawnLocation")
	end
	if portals ~= 1 then
		fail("the hub needs a portal that joins the queue")
	end
	if boards ~= 2 then
		fail("the hub needs its welcome and next-match boards")
	end
	if parts > 3000 then
		fail("hub is too heavy: " .. parts .. " parts")
	end
	local hall = hub:FindFirstChild("Leaderboard", true)
	if not hall or not hall:FindFirstChild("BoardFace", true) then
		fail("the hub needs the Hall of Champions leaderboard")
	end
	if not hub:FindFirstChild("ClassAltar", true) or not hub:FindFirstChild("Lectern", true) then
		fail("the hub needs a class altar and Grimoire lecterns")
	end
	-- the Tailor's Loom, the Coffer stall and the auction house are reached from the Plaza
	local actions = {}
	for _, inst in hub:GetDescendants() do
		if inst.ClassName == "ProximityPrompt" and inst:GetAttribute("LobbyAction") then
			actions[inst:GetAttribute("LobbyAction")] = true
		end
	end
	for _, action in { "Wardrobe", "Coffers", "Auction", "Grimoire", "ClassPicker" } do
		if not actions[action] then
			fail("the hub has no prompt for " .. action)
		end
	end
end
for _, inst in Mock.workspace:GetDescendants() do
	if inst.ClassName == "SpawnLocation" and not inst:IsDescendantOf(hub) then
		fail("stray SpawnLocation outside the hub: " .. inst.Name)
	end
end
local exit = lobby and lobby:FindFirstChild("PortalSheet", true)
if not exit or exit:GetAttribute("PortalAction") ~= "LeaveQueue" then
	fail("the library needs a portal back to the hub")
end

local dummies = PracticeService.dummies()
if #dummies ~= 12 then
	fail("expected 12 training dummies (7 in the hub, 5 in the library), got " .. #dummies)
end
local moving = {}
for _, d in dummies do
	if not d.isDummy or not Combatants.isActive(d) then
		fail("dummies should be active combatants")
	end
	if d.name == "Moving Dummy" then
		table.insert(moving, { c = d, start = d.root.Position })
	end
end
if #moving ~= 2 then
	fail("the hub range should have 2 moving dummies, got " .. #moving)
end
Mock.step(1.5)
for _, m in moving do
	if (m.c.root.Position - m.start).Magnitude < 1 then
		fail("moving dummies should slide along their rails")
	end
end

-- Every map
for _, def in MapDefs.List do
	local before = #Mock.warnings
	local writesBefore = voxelWrites
	local arena = nil
	local co = Mock.task.spawn(function()
		arena = MapService.generate(1234, def)
	end)
	local guard = 0
	while coroutine.status(co) ~= "dead" and guard < 20000 do
		Mock.step(1 / 60)
		guard += 1
	end
	if not arena then
		fail(def.id .. ": generation did not finish")
		continue
	end
	local outer, shrine, corn = 0, 0, 0
	local outerPositions = {}
	for _, spot in arena.chestSpots do
		if spot.tier == "Outer" then
			outer += 1
			table.insert(outerPositions, spot.cframe.Position)
		elseif spot.tier == "Shrine" then
			shrine += 1
		elseif spot.tier == "Cornucopia" then
			corn += 1
		end
	end
	local folder = Mock.workspace:FindFirstChild("Arena")
	local decorCount = 0
	local decor = folder and folder:FindFirstChild("Decor")
	if decor then
		decorCount = #decor:GetChildren()
	end
	local area = math.pi * def.radius ^ 2
	print(
		string.format(
			"%-14s r=%d  chests: %2d cornucopia, %2d outer, %2d ruins (1 per %5.0f studs²)  decor: %d  voxel chunks: %d",
			def.name,
			def.radius,
			corn,
			outer,
			shrine,
			area / (corn + outer + shrine),
			decorCount,
			voxelWrites - writesBefore
		)
	)
	if corn ~= Config.Arena.CornucopiaChests then
		fail(def.id .. ": cornucopia should have " .. Config.Arena.CornucopiaChests .. " chests")
	end
	if outer < def.outerChests * 0.8 then
		fail(def.id .. ": only " .. outer .. " scattered chests")
	end
	if #arena.pedestals ~= Config.Match.MaxParticipants then
		fail(def.id .. ": wrong pedestal count")
	end
	if decorCount < 200 then
		fail(def.id .. ": too little decoration (" .. decorCount .. ")")
	end
	for i = 1, #outerPositions do
		for j = i + 1, #outerPositions do
			local a, b = outerPositions[i], outerPositions[j]
			-- (chests inside a ruin sit up to ~6 studs from its centre)
			if (Vector3.new(a.X, 0, a.Z) - Vector3.new(b.X, 0, b.Z)).Magnitude < Config.Arena.ChestSpacing - 8 then
				fail(def.id .. ": two scattered chests are too close together")
			end
		end
	end
	if MapDefs.plazaHeight(def) <= def.terrain.liquidLevel + 1 then
		fail(def.id .. ": the plaza would be under liquid")
	end
	if Mock.repAttributes.MapId ~= def.id then
		fail(def.id .. ": MapId attribute not published")
	end
	for i = before + 1, #Mock.warnings do
		fail(def.id .. ": " .. Mock.warnings[i])
	end
end

if failures > 0 then
	print(failures .. " failure(s)")
	process.exit(1)
end
print("map simulation passed")
