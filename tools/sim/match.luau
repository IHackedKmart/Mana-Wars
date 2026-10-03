--[[
	Full match simulation (run from the repo root with Lune):

		lune run tools/sim/match

	Boots the REAL server (src/server/init.server.lua) on the fake engine with one passive player,
	who spawns in the hub (nothing starts until they join), walks through the portal to join the
	queue, and then sits through two complete matches: the map vote, map generation, bots filling
	the match, pedestals, grace period, chest refill, the mana storm, eliminations, the winner, and
	the reset back to the library. Finally they leave the queue through the library's portal, and no
	new match may start. Any runtime error or warning fails the run.
]]

local process = require("@lune/process")
local roblox = require("@lune/roblox")
local Mock = require("./mock")

local Vector3 = roblox.Vector3
local CFrame = Mock.CFrame
local Instance = Mock.Instance
local Enum = roblox.Enum

local failures = 0
local function fail(msg: string)
	failures += 1
	print("FAIL  " .. msg)
end

local function makeBody(name: string): any
	local model = Instance.new("Model")
	model.Name = name
	local root = Instance.new("Part", model)
	root.Name = "HumanoidRootPart"
	local head = Instance.new("Part", model)
	head.Name = "Head"
	head.Size = Vector3.new(2, 1, 1)
	local hum = Instance.new("Humanoid", model)
	Instance.new("Animator", hum)
	model.PrimaryPart = root
	return model
end

-- one passive human player
local player = Instance.new("Player")
player.Name = "Tester"
player.DisplayName = "Tester"
player.UserId = 1
player.MembershipType = Enum.MembershipType.None
Instance.new("PlayerGui", player).Name = "PlayerGui"
player.Parent = Instance.new("Players")
local loads = 0
local function loadCharacter()
	loads += 1
	local old = player.Character
	if old then
		old:Destroy()
	end
	local body = makeBody("Tester")
	body.Parent = Mock.workspace
	player.Character = body
	player.CharacterAdded:Fire(body)
end
rawset(player, "LoadCharacterAsync", function()
	loadCharacter()
end)
Mock.localPlayer = player

local Players = {
	PlayerAdded = Mock.signal(),
	PlayerRemoving = Mock.signal(),
	PlayerMembershipChanged = Mock.signal(),
	GetPlayers = function()
		return { player }
	end,
	GetPlayerFromCharacter = function(_, model)
		return if model == player.Character then player else nil
	end,
	CreateHumanoidModelFromDescription = function(_, _desc, _rig)
		return makeBody("Bot")
	end,
}

local savedStats = {}
local server = Mock.realm({
	RunService = Mock.runService(true),
	Players = Players,
	ProximityPromptService = { PromptTriggered = Mock.signal() },
	TweenService = Mock.TweenService,
	Lighting = Instance.new("Lighting"),
	MarketplaceService = {
		PromptGamePassPurchaseFinished = Mock.signal(),
		UserOwnsGamePassAsync = function()
			return false
		end,
		PromptGamePassPurchase = function() end,
		PromptPremiumPurchase = function() end,
	},
	DataStoreService = {
		GetDataStore = function()
			return {
				GetAsync = function(_, key)
					return savedStats[key]
				end,
				UpdateAsync = function(_, key, fn)
					-- like Roblox: returning nil from the transform cancels the write
					local result = fn(savedStats[key])
					if result ~= nil then
						savedStats[key] = result
					end
					return result
				end,
			}
		end,
	},
}, true)

-- terrain is not simulated: count the voxel writes instead
local voxelWrites = 0
rawset(Mock.workspace.Terrain, "Clear", function() end)
rawset(Mock.workspace.Terrain, "WriteVoxels", function()
	voxelWrites += 1
end)

-- Humanoids don't die on their own in the fake engine: fire Died when health runs out.
local deadSeen = {}
local function emulateDeaths()
	for _, inst in Mock.workspace:GetDescendants() do
		if inst.ClassName == "Humanoid" and inst.Health <= 0 and not deadSeen[inst] then
			deadSeen[inst] = true
			inst.Died:Fire()
		end
	end
end

-- Boot the real server entry point inside a coroutine (it yields while generating the map).
Mock.task.spawn(function()
	server.load("Server")
end)

local Combatants = server.load("Server/Services/Combatants")
local phasesSeen: { string } = {}
local lastPhase = nil
local seconds = 0
-- record every phase change as it happens (some, like Loading, are very short here)
Mock.onAttribute = function(name, value)
	if name == "Phase" and value ~= lastPhase then
		lastPhase = value
		table.insert(phasesSeen, value)
		print(string.format("  t=%5.1fs  phase -> %s", seconds, tostring(value)))
	end
end
local winners = 0
local announceCounts = {}
local announce = Mock.Remotes.event("Announce")
announce.OnClientEvent:Connect(function(kind, data)
	announceCounts[kind] = (announceCounts[kind] or 0) + 1
	if kind == "Winner" then
		winners += 1
		print("  winner: " .. tostring(data.name) .. " (" .. tostring(data.kills) .. " kills)")
	end
end)

local function rootZ(): number
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	return if root then root.Position.Z else 0 / 0
end
local function step(n: number)
	for _ = 1, n * 2 do
		Mock.step(0.5)
		seconds += 0.5
		emulateDeaths()
	end
end

-- 1. Spawn in the hub. Nobody is queued, so no match may start, however long we wait.
step(30)
local QueueService = server.load("Server/Services/QueueService")
local MapService = server.load("Server/Services/MapService")
local me = Combatants.forPlayer(player)
local hubZ = server.load("Server/Map/Hub").CENTER_Z
if math.abs(rootZ() - hubZ) > 120 then
	fail("new players should spawn in the hub, got z=" .. rootZ())
end
if me and me.queued then
	fail("new players should not start in the queue")
end
if Mock.repAttributes.Phase ~= "Waiting" or #phasesSeen > 1 then
	fail("no match should start while nobody is queued (phases: " .. table.concat(phasesSeen, " > ") .. ")")
end
if me and not me.practice then
	fail("players in the hub should be in the Spell Lab")
end
local board = MapService.hub and MapService.hub.boardText
if not board or not string.find(board.Text, "No match yet", 1, true) then
	fail("the hub board should say no match is running")
end

-- 2. Walk into the hub portal: joined, and moved to the library.
local portal = MapService.hub and MapService.hub.joinPortal
if portal and player.Character then
	portal.Touched:Fire(player.Character:FindFirstChild("HumanoidRootPart"))
end
step(1)
if not me or not me.queued or player:GetAttribute("Queued") ~= true then
	fail("walking into the portal should join the queue")
end
if math.abs(rootZ()) > 100 then
	fail("joining should move the player to the library, got z=" .. rootZ())
end

local maxBots = 0
local maxChests = 0
local boardDuringMatch = ""
local LIMIT = 2400
while seconds < LIMIT do
	Mock.step(0.5)
	seconds += 0.5
	emulateDeaths()
	local phase = Mock.repAttributes.Phase
	local bots = Mock.workspace:FindFirstChild("Bots")
	if bots then
		maxBots = math.max(maxBots, #bots:GetChildren())
	end
	local chests = 0
	for _, inst in Mock.workspace:GetDescendants() do
		if inst.ClassName == "Model" and inst:GetAttribute("ChestId") then
			chests += 1
		end
	end
	maxChests = math.max(maxChests, chests)
	if phase == "Battle" and board then
		boardDuringMatch = board.Text
	end
	if winners >= 2 and (phase == "Waiting" or phase == "Voting") then
		break
	end
end

local joined = table.concat(phasesSeen, " > ")
print("phases: " .. joined)
for _, needed in { "Voting", "Loading", "Countdown", "Grace", "Battle", "Ended" } do
	if not string.find(joined, needed, 1, true) then
		fail("never reached phase " .. needed)
	end
end
if winners < 2 then
	fail("expected two finished matches, got " .. winners)
end
if maxBots < 3 then
	fail("bots should fill the match, saw " .. maxBots)
end
if maxChests < 30 then
	fail("expected the arena to be full of chests, saw " .. maxChests)
end
if voxelWrites < 10 then
	fail("terrain should have been generated")
end
if (announceCounts.Kill or 0) < 3 then
	fail("expected eliminations in the kill feed")
end
if not string.find(boardDuringMatch, "Match in progress", 1, true) then
	fail("the hub board should show the running match, got: " .. boardDuringMatch)
end
if not me or me.inMatch then
	fail("the player should be back in the library after the match")
end
if me and not me.queued then
	fail("players should stay queued after a match")
end
if me and not me.practice then
	fail("back in the lobby the player should be in the Spell Lab")
end
if me and (me.inventory.parts.Bolt or 0) < 1 then
	fail("the Spell Lab kit should include spell parts")
end
if player:GetAttribute("Practice") ~= true then
	fail("the Practice attribute should be published")
end
-- 3. Leave through the library's portal: back to the hub, and the next match never starts.
step(2)
if math.abs(rootZ()) > 100 then
	fail("after a match queued players should wait in the library, got z=" .. rootZ())
end
local exitPrompt = MapService.lobby and MapService.lobby.exitPortal:FindFirstChildOfClass("ProximityPrompt")
if exitPrompt then
	exitPrompt.Triggered:Fire(player)
else
	fail("the library needs a portal back to the hub")
end
step(1)
if me and me.queued then
	fail("the library portal should take the player out of the queue")
end
if math.abs(rootZ() - hubZ) > 120 then
	fail("leaving the queue should move the player to the hub, got z=" .. rootZ())
end
local phasesBefore = #phasesSeen
step(60)
for i = phasesBefore + 1, #phasesSeen do
	if phasesSeen[i] ~= "Waiting" then
		fail("a match started with nobody queued: " .. phasesSeen[i])
	end
end
if Mock.repAttributes.Phase ~= "Waiting" then
	fail("with nobody queued the game should wait, phase is " .. tostring(Mock.repAttributes.Phase))
end

-- 4. The Join / Leave buttons go through the QueueAction remote.
local queueAction = Mock.Remotes.func("QueueAction")
local okJoin = queueAction:InvokeServer("Join")
if not okJoin or not me or not me.queued then
	fail("the Join Game button should join the queue")
end
step(2)
if Mock.repAttributes.Phase ~= "Voting" or (Mock.repAttributes.QueueCount or 0) ~= 1 then
	fail("joining should open the map vote and count the queue")
end
if not QueueService.waiting()[1] then
	fail("the queue should list the player")
end
local okLeave = queueAction:InvokeServer("Leave")
step(2)
if not okLeave or (me and me.queued) or Mock.repAttributes.Phase ~= "Waiting" then
	fail("leaving during the vote should cancel it")
end

local stats = savedStats["u1"]
if not stats or (stats.matches or 0) < 1 then
	fail("match stats should be saved")
end
print(
	string.format("bots: %d, chests: %d, voxel chunks: %d, character loads: %d", maxBots, maxChests, voxelWrites, loads)
)
print("announcements: " .. (function()
	local parts = {}
	for k, v in announceCounts do
		table.insert(parts, k .. "=" .. v)
	end
	table.sort(parts)
	return table.concat(parts, ", ")
end)())

for _, w in Mock.warnings do
	fail(w)
end
if failures > 0 then
	print(failures .. " failure(s)")
	process.exit(1)
end
print("match simulation passed")
