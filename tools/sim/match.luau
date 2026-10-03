--[[
	Full match simulation (run from the repo root with Lune):

		lune run tools/sim/match

	Boots the REAL server (src/server/init.server.lua) on the fake engine with one passive player,
	then fast-forwards the clock through two complete matches: map generation, bots filling the
	lobby, pedestals, grace period, chest refill, the mana storm, eliminations, the winner, and the
	reset back to the sky lobby. Any runtime error or warning fails the run.
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
					savedStats[key] = fn(savedStats[key])
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

local maxBots = 0
local maxChests = 0
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
local me = Combatants.forPlayer(player)
if not me or me.inMatch then
	fail("the player should be back in the lobby after the match")
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
