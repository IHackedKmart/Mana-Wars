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
	GetPlayerByUserId = function(_, id)
		return if id == player.UserId then player else nil
	end,
	CreateHumanoidModelFromDescription = function(_, _desc, _rig)
		return makeBody("Bot")
	end,
}

local savedStats = {}
local leaderboards: { [string]: { [string]: number } } = {}
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
		-- the global leaderboard: remembers scores, reads them back highest first
		GetOrderedDataStore = function(_, name)
			leaderboards[name] = leaderboards[name] or {}
			local data = leaderboards[name]
			return {
				SetAsync = function(_, key, value)
					data[key] = value
				end,
				GetSortedAsync = function(_, _ascending, size)
					local items = {}
					for key, value in data do
						table.insert(items, { key = key, value = value })
					end
					table.sort(items, function(a, b)
						return a.value > b.value
					end)
					local page = table.move(items, 1, math.min(size, #items), 1, {})
					return {
						GetCurrentPage = function()
							return page
						end,
					}
				end,
			}
		end,
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
-- placements: everyone in a match finishes in a distinct place 1..N, and players earn
-- Enchanted Coins for it (1st = 12 ... 12th = 1, plus their Fortune enchantment)
local roster: { any } = {}
local expectedCoins = 0
local placementsChecked = 0
local function checkPlacements()
	local seen = {}
	for _, c in roster do
		local place = c.place
		if type(place) ~= "number" or place < 1 or place > #roster or seen[place] then
			fail(string.format("%s finished in place %s of %d", c.name, tostring(place), #roster))
		else
			seen[place] = true
		end
		if c.player then
			local base = math.max(1, 13 - (place or 13))
			expectedCoins += base + math.floor(base * (c.gear.fortune or 0) + 0.5)
			print(string.format("  %s finished %s of %d", c.name, tostring(place), #roster))
		end
	end
	placementsChecked += 1
end
Mock.onAttribute = function(name, value)
	if name == "Phase" and value ~= lastPhase then
		local previous = lastPhase
		lastPhase = value
		table.insert(phasesSeen, value)
		print(string.format("  t=%5.1fs  phase -> %s", seconds, tostring(value)))
		if value == "Battle" then
			roster = {}
			for _, c in Combatants.all() do
				if c.inMatch and not c.isDummy then
					table.insert(roster, c)
				end
			end
			if #roster > 12 then
				fail("matches hold at most 12 mages, got " .. #roster)
			end
		elseif previous == "Ended" then
			checkPlacements()
		end
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

local Familiars = server.load("Shared/Familiars")
local botFamiliars: { [string]: string } = {}
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
	if phase == "Battle" and bots then
		for _, bot in bots:GetChildren() do
			local code = bot:GetAttribute("Familiar")
			if code ~= nil then
				if not Familiars.decode(code) then
					fail("a bot has a broken familiar: " .. tostring(code))
				end
				botFamiliars[bot.Name] = code
			end
		end
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
local familiarCount = 0
for _ in botFamiliars do
	familiarCount += 1
end
print(string.format("bot familiars seen: %d", familiarCount))
if placementsChecked < 2 then
	fail("expected placements for two matches, checked " .. placementsChecked)
end
local DataService = server.load("Server/Services/DataService")
local profile = DataService.profile(player)
local coins = if profile then profile.coins else -1
-- the Hall of Champions in the Plaza lists the scores written after each match
local coinsBeforeBoard = if profile then profile.coins else -1
local achievementsBeforeBoard = if profile then table.clone(profile.achievements) else {}
do
	local LeaderboardService = server.load("Server/Services/LeaderboardService")
	local MapService = server.load("Server/Services/MapService")
	if profile and profile.wins == 0 then
		DataService.addWin(player) -- (bots won both matches: give the board something to show)
		Mock.step(0.2)
	end
	LeaderboardService.push(player)
	LeaderboardService.refresh()
	local board = MapService.hub and MapService.hub.leaderboard
	if not board or string.find(board.footer.Text, "All servers", 1, true) == nil then
		fail("the leaderboard board should be online")
	elseif string.find(board.wins.Text, player.Name, 1, true) == nil then
		fail("the leaderboard should list the player's wins: " .. board.wins.Text)
	end
	print("leaderboard: " .. string.gsub(board and board.wins.Text or "", "\n", " | "))
end

-- plus today's daily reward and any achievements the matches unlocked
local Achievements = server.load("Shared/Achievements")
local extra = server.load("Shared/Config").Rewards.DailyCoins
for id in achievementsBeforeBoard do
	extra += Achievements.ById[id].reward
end
print(
	string.format("coins: %d (60 to start + %d from placements + %d daily/achievements)", coins, expectedCoins, extra)
)
if coins ~= 60 + expectedCoins + extra then
	fail(string.format("coins should be 60 + %d from placements + %d, got %d", expectedCoins, extra, coins))
end
if not stats or stats.coins ~= coins then
	fail("coins should be saved with the profile")
end
if not stats or type(stats.wardrobe) ~= "table" or #stats.wardrobe.garments ~= 2 then
	fail("the starter outfit should be saved with the profile")
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

-- 5. Dev panel match controls: start a match right away, skip the countdown and grace period,
--    get the full loadout at the start, then end the match on demand.
local Dev = Mock.Remotes.func("DevAction")
local function dev(action: string, args: { [string]: any }?)
	local ok, message = Dev:InvokeServer(action, args or {})
	if not ok then
		fail("dev action " .. action .. " failed: " .. tostring(message))
	end
end
local function waitFor(phase: string, limit: number): number
	local waited = 0
	while Mock.repAttributes.Phase ~= phase and waited < limit do
		step(0.5)
		waited += 0.5
	end
	return waited
end
dev("Loadout", { on = true })
dev("Bots", { fill = 4 })
dev("StartMatch")
local tLoading = waitFor("Countdown", 20)
if Mock.repAttributes.Phase ~= "Countdown" then
	fail("Start a match now should skip the vote, phase is " .. tostring(Mock.repAttributes.Phase))
elseif tLoading > 10 then
	fail("the vote wasn't skipped (" .. tLoading .. "s)")
end
dev("Skip")
step(1)
if Mock.repAttributes.Phase ~= "Grace" then
	fail("Skip should end the countdown, phase is " .. tostring(Mock.repAttributes.Phase))
end
dev("Skip")
step(1)
if Mock.repAttributes.Phase ~= "Battle" then
	fail("Skip should end the grace period, phase is " .. tostring(Mock.repAttributes.Phase))
end
local wands = 0
for _, wand in me.inventory.wands do
	if wand then
		wands += 1
	end
end
if wands < 3 or (me.inventory.parts.Bolt or 0) < 20 then
	fail("the dev loadout should hand out wands and parts (" .. wands .. " wands)")
end
dev("Advance", { seconds = 200 })
step(1)
if Mock.repAttributes.StormActive ~= true then
	fail("+time should bring the storm in")
end
dev("EndMatch")
waitFor("Ended", 5)
if Mock.repAttributes.Phase ~= "Ended" then
	fail("End the match should end it, phase is " .. tostring(Mock.repAttributes.Phase))
end
print("dev panel: started, skipped and ended a match on demand")

for _, w in Mock.warnings do
	fail(w)
end
if failures > 0 then
	print(failures .. " failure(s)")
	process.exit(1)
end
print("match simulation passed")
