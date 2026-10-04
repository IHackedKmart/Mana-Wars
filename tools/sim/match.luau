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
		-- (a battle royale's roster is set when the carpet takes off)
		local royale = Mock.repAttributes.MatchMode == "Royale"
		if (value == "Battle" and not royale) or (value == "Carpet" and royale and previous ~= "Carpet") then
			roster = {}
			for _, c in Combatants.all() do
				if c.inMatch and not c.isDummy then
					table.insert(roster, c)
				end
			end
			local cap = if royale then 50 else 12
			if #roster > cap then
				fail("matches hold at most " .. cap .. " mages, got " .. #roster)
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

-- 2. Walk into the hub portal: the game mode menu opens. Pick Survival Games: joined, and moved
--    to the library.
local portal = MapService.hub and MapService.hub.joinPortal
if portal and player.Character then
	portal.Touched:Fire(player.Character:FindFirstChild("HumanoidRootPart"))
end
step(1)
if (announceCounts.PlayMenu or 0) < 1 then
	fail("walking into the portal should open the game mode menu")
end
if me and me.queued then
	fail("the portal should only offer the modes, not pick one")
end
local queueAction = Mock.Remotes.func("QueueAction")
queueAction:InvokeServer("Join", "Survival")
step(1)
if
	not me
	or not me.queued
	or player:GetAttribute("Queued") ~= true
	or player:GetAttribute("QueuedMode") ~= "Survival"
then
	fail("picking Survival Games should join its queue")
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
if not string.find(boardDuringMatch, "Survival Games in progress", 1, true) then
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

-- 4. The Join / Leave buttons go through the QueueAction remote (no mode: Survival Games).
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
	elseif string.find(board.columns.wins.Text, player.Name, 1, true) == nil then
		fail("the leaderboard should list the player's Survival Games wins: " .. board.columns.wins.Text)
	end
	print("leaderboard: " .. string.gsub(board and board.columns.wins.Text or "", "\n", " | "))
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

local function waitUntil(check: () -> boolean, limit: number): boolean
	local waited = 0
	while not check() and waited < limit do
		step(0.5)
		waited += 0.5
	end
	return check()
end
local Config = server.load("Shared/Config")
local DamageService = server.load("Server/Services/DamageService")
local Events = server.load("Server/Services/Events")
local finishedModes: { string } = {}
Events.on("MatchFinished", function(who, _place, _outOf, _kills, _mapId, _classId, mode)
	if who == player then
		table.insert(finishedModes, tostring(mode))
	end
end)
local duelResults: { boolean } = {}
Events.on("DuelFinished", function(who, won)
	if who == player then
		table.insert(duelResults, won)
	end
end)

-- 6. Battle Royale: picked from the menu, the queue gathers while the enormous island is built,
--    then everyone (topped up with bots) rides the magic carpet across it. The player jumps,
--    glides down and lands; the bots hop off along the way; the storm circles close in until the
--    match is decided.
dev("Loadout", { on = false })
dev("God", { on = true }) -- (the passive player would only get in the way of the test by dying early)
dev("GiveOutfit", { rarity = "Mythic" }) -- (its bonuses count in the battle royale, not in duels)
if not waitUntil(function()
	return me ~= nil and not me.inMatch
end, 60) then
	fail("the dev match never wound up")
end
local okRoyale = queueAction:InvokeServer("Join", "Royale")
if not okRoyale or player:GetAttribute("QueuedMode") ~= "Royale" then
	fail("picking Battle Royale should switch the player to its queue")
end
if not waitUntil(function()
	return Mock.repAttributes.Phase == "Gathering"
end, 30) then
	fail("joining the Battle Royale should start gathering, phase is " .. tostring(Mock.repAttributes.Phase))
end
if Mock.repAttributes.MatchMode ~= "Royale" then
	fail("the arena should say it's playing the Battle Royale")
end
if board and not string.find(board.Text, "Battle Royale", 1, true) then
	fail("the hub board should announce the Battle Royale: " .. board.Text)
end
if not waitUntil(function()
	return Mock.repAttributes.Phase == "Carpet"
end, 1200) then
	fail("the carpet never took off, phase is " .. tostring(Mock.repAttributes.Phase))
end
print("battle royale: island built and the carpet is boarding")
step(1)
local CarpetService = server.load("Server/Services/CarpetService")
local arena = MapService.arena
if not arena or arena.def.id ~= "Royale" or #arena.pedestals ~= 0 then
	fail("the Battle Royale should be played on its own island, without pedestals")
end
local locations = arena and arena.folder:FindFirstChild("Locations")
if not locations or #locations:GetChildren() ~= 9 then
	fail("the island's 9 named places should have floating names")
end
local riders, botRiders = {}, {}
for _, c in Combatants.all() do
	if c.inMatch and not c.isDummy then
		table.insert(riders, c)
		if c.isBot then
			table.insert(botRiders, c)
		end
		if c.dropping ~= "riding" then
			fail(c.name .. " should be riding the carpet, is " .. tostring(c.dropping))
		end
	end
end
if #riders ~= Config.Royale.FillTo then
	fail(string.format("bots should top the carpet up to %d mages, got %d", Config.Royale.FillTo, #riders))
end
local royaleChests = 0
for _, inst in Mock.workspace:GetDescendants() do
	if inst.ClassName == "Model" and inst:GetAttribute("ChestId") then
		royaleChests += 1
	end
end
if royaleChests < 150 then
	fail("the island should be dotted with chests, saw " .. royaleChests)
end
local function myRoot()
	return player.Character and player.Character:FindFirstChild("HumanoidRootPart")
end
local seat = CarpetService.seatCFrame(me)
if player:GetAttribute("Riding") ~= true or typeof(player:GetAttribute("CarpetSeat")) ~= "Vector3" then
	fail("the player should be told they're riding, and where their seat is")
end
if not seat or not myRoot() or (myRoot().Position - seat.Position).Magnitude > 5 then
	fail("players should spawn in their seat on the carpet")
elseif seat.Position.Y < Config.Royale.CarpetAltitude - 5 then
	fail("the carpet should fly high above the island")
end
if Mock.repAttributes.StormActive ~= true or not Mock.repAttributes.StormNextRadius then
	fail("the storm and the first circle should be shown from the start")
end
if DamageService.canHurt(me, botRiders[1], false) then
	fail("nobody on the carpet can be hurt")
end
-- what the player's own client does: keep them in their seat as the carpet flies
local function ride(seconds: number)
	for _ = 1, seconds * 4 do
		local cf = CarpetService.seatCFrame(me)
		if cf and myRoot() then
			myRoot().CFrame = cf
		end
		Mock.step(0.25)
		emulateDeaths()
	end
end
ride(9)
local takeOffPos = myRoot() and myRoot().Position
ride(3)
if player:GetAttribute("Riding") ~= true then
	fail("riding along in your seat shouldn't drop you")
end
if takeOffPos and myRoot() and (myRoot().Position - takeOffPos).Magnitude < 50 then
	fail("the carpet should be flying across the island")
end
Mock.Remotes.event("RoyaleAction"):FireServer("Jump")
Mock.step(0.25)
if player:GetAttribute("Gliding") ~= true or player:GetAttribute("Riding") == true or me.dropping ~= "gliding" then
	fail("jumping should start the glide down")
end
if not player.Character:FindFirstChild("GlideRug") then
	fail("gliders ride a little rug of their own")
end
if DamageService.canHurt(me, botRiders[1], false) or DamageService.canHurt(botRiders[1], me, false) then
	fail("gliders can't fight yet")
end
-- touch down on dry ground
local landX, landZ = 0, 0
for _, loc in arena.locations do
	landX, landZ = loc.pos.X, loc.pos.Z
	break
end
myRoot().CFrame = CFrame.new(landX, arena.heightAt(landX, landZ) + 3, landZ)
step(1)
if me.dropping ~= nil or player:GetAttribute("Gliding") == true or player.Character:FindFirstChild("GlideRug") then
	fail("reaching the ground should end the glide")
end
-- the bots hop off along the way and glide down onto dry land
if
	not waitUntil(function()
		for _, c in botRiders do
			if c.dropping ~= nil and Combatants.isActive(c) then
				return false
			end
		end
		return true
	end, Config.Royale.CarpetTime + 30)
then
	fail("every bot should have landed once the carpet has crossed")
end
local liquid = arena.def.terrain.liquidLevel
for _, c in botRiders do
	if Combatants.isActive(c) then
		local p = c.root.Position
		if p.Y < liquid or math.abs(p.Y - (arena.heightAt(p.X, p.Z) + 3)) > 4 then
			fail(string.format("%s landed badly at (%.0f, %.0f, %.0f)", c.name, p.X, p.Y, p.Z))
		end
		if c.root.Anchored then
			fail(c.name .. " is still anchored after landing")
		end
	end
end
if Mock.repAttributes.CarpetActive == true then
	fail("the carpet should be gone once everyone has landed")
end
if Mock.repAttributes.Phase ~= "Battle" then
	fail("once the carpet has crossed the battle is on, phase is " .. tostring(Mock.repAttributes.Phase))
end
if not DamageService.canHurt(me, botRiders[1], false) then
	fail("once landed, mages can fight")
end
if type(player:GetAttribute("RealmName")) ~= "string" then
	fail("the player should know which realm they're in")
end
if next(me.gear) == nil then
	fail("the player's outfit bonuses should follow them into the battle royale")
end
-- the circles: the first one holds, then the storm moves in (its centre too)
local firstCenter = Mock.repAttributes.StormCenter
local holdLeft = (Mock.repAttributes.StormMovesAt or 0) - Mock.workspace:GetServerTimeNow()
if Mock.repAttributes.StormShrinking or holdLeft <= 0 then
	fail("the first circle should hold for a while after the carpet has crossed")
end
dev("Advance", { seconds = math.max(1, holdLeft + 5) })
step(2)
if Mock.repAttributes.StormShrinking ~= true or Mock.repAttributes.StormStage ~= 1 then
	fail("the storm should close in on the first circle")
end
dev("Advance", { seconds = 60 })
step(2)
if
	Mock.repAttributes.StormStage ~= 2
	or Mock.repAttributes.StormRadius > Config.Royale.Circles[1].radius * arena.radius + 1
then
	fail("after the first circle the next one should be revealed")
end
if firstCenter == Mock.repAttributes.StormCenter and Mock.repAttributes.StormRadius < 600 then
	print("  (the first circle happened to be centred where the storm started)")
end
-- the final storm burns everyone out: the match is decided
dev("God", { on = false })
local royaleProfile = DataService.profile(player)
local coinsBeforeEnd = royaleProfile.coins
local achievementsBeforeEnd = table.clone(royaleProfile.achievements)
local fortune = me.gear.fortune or 0
dev("Advance", { seconds = 400 })
local winnersBefore = winners
if not waitUntil(function()
	return winners > winnersBefore
end, 300) then
	fail("the Battle Royale never finished")
end
local places = {}
for _, c in riders do
	if c.place then
		if places[c.place] then
			fail("two mages finished in place " .. c.place)
		end
		places[c.place] = true
	end
end
if not me.place then
	fail("the player should have a finishing place")
else
	-- 50 coins for 1st, one less per place (plus the outfit's Fortune), and any achievements
	local base = math.max(1, Config.Royale.CoinsForFirst + 1 - me.place)
	local expected = base + math.floor(base * fortune + 0.5)
	for id in royaleProfile.achievements do
		if not achievementsBeforeEnd[id] then
			expected += Achievements.ById[id].reward
		end
	end
	local gained = royaleProfile.coins - coinsBeforeEnd
	if gained ~= expected then
		fail(string.format("finishing %d of %d should pay %d coins, got %d", me.place, #riders, expected, gained))
	else
		print(string.format("battle royale coins: %d for finishing %d of %d", gained, me.place, #riders))
	end
end
waitUntil(function()
	return me ~= nil and not me.inMatch and Mock.repAttributes.Phase ~= "Ended"
end, 30)
-- (straight on to the duel queue, so no second battle royale starts)
queueAction:InvokeServer("Join", "Duel")
if finishedModes[#finishedModes] ~= "Royale" then
	fail("the match should be reported as a Battle Royale, got " .. tostring(finishedModes[#finishedModes]))
end
if player:GetAttribute("Mode") ~= nil or player:GetAttribute("Riding") or player:GetAttribute("Gliding") then
	fail("back in the library the player's mode and carpet flags should be cleared")
end
print(string.format("battle royale: %d mages, %d chests, finished %s", #riders, royaleChests, tostring(me.place)))

-- 7. A 1v1 duel: alone in the queue, a bot steps in. One spell and one potion each, nobody else
--    can interfere, and the winner earns coins.
queueAction:InvokeServer("Join", "Duel")
if not waitUntil(function()
	return me.duel ~= nil
end, Config.Duel.BotAfter + 10) then
	fail("a bot should take on a lonely duelist")
end
local duel = me.duel
if duel then
	if player:GetAttribute("Mode") ~= "Duel" or player:GetAttribute("DuelState") ~= "Countdown" then
		fail("the duel should start with a countdown")
	end
	local rival = if duel.a == me then duel.b else duel.a
	local wandCount, spells = 0, 0
	for _, wand in me.inventory.wands do
		if wand then
			wandCount += 1
			for _, slot in wand.slots do
				if slot then
					spells += 1
				end
			end
		end
	end
	local potions = 0
	for _, n in me.inventory.consumables do
		potions += n
	end
	if wandCount ~= 1 or spells ~= 1 or potions ~= 1 then
		fail(
			string.format(
				"duelists get one spell and one potion (%d wands, %d spells, %d potions)",
				wandCount,
				spells,
				potions
			)
		)
	end
	if DamageService.canHurt(rival, me, false) then
		fail("no damage before the duel's countdown ends")
	end
	-- a level playing field: no outfit or familiar bonuses, no kit
	if next(me.gear) ~= nil or next(rival.gear) ~= nil then
		fail("outfit and familiar bonuses don't count in a duel")
	end
	if me.humanoid.MaxHealth ~= Config.Combat.MaxHealth or rival.humanoid.MaxHealth ~= Config.Combat.MaxHealth then
		fail("both duelists start with the same health")
	end
	waitUntil(function()
		return duel.state == "Fight"
	end, 10)
	if not DamageService.canHurt(rival, me, false) then
		fail("duelists can hurt each other once the fight is on")
	end
	local duelProfile = DataService.profile(player)
	local coinsBefore = duelProfile.coins
	local achievementsBeforeDuel = table.clone(duelProfile.achievements)
	rival.lastAttacker = me
	rival.lastAttackTime = Mock.workspace:GetServerTimeNow()
	rival.humanoid.Health = 0
	step(1)
	if duel.winner ~= me or duelResults[#duelResults] ~= true then
		fail("knocking the rival out should win the duel")
	end
	local expectedDuel = Config.Duel.WinCoins
	for id in duelProfile.achievements do
		if not achievementsBeforeDuel[id] then
			expectedDuel += Achievements.ById[id].reward
		end
	end
	local gained = duelProfile.coins - coinsBefore
	if gained ~= expectedDuel then
		fail("the duel winner should earn " .. expectedDuel .. " coins, got " .. gained)
	end
	step(6)
	if me.duel ~= nil or player:GetAttribute("Mode") ~= nil or me.inMatch then
		fail("after the duel the player should be back in the library")
	end
	if next(me.gear) == nil then
		fail("back from the duel the outfit's bonuses should return")
	end
	-- the duel leaderboard
	local LeaderboardService = server.load("Server/Services/LeaderboardService")
	LeaderboardService.refresh()
	local duelTop = LeaderboardService.top.duelWins
	if not duelTop[1] or duelTop[1].userId ~= player.UserId or duelTop[1].value ~= 1 then
		fail("the duel win should reach the global duel leaderboard")
	end
	local hall = MapService.hub and MapService.hub.leaderboard
	if not hall or not string.find(hall.columns.duelWins.Text, player.Name, 1, true) then
		fail("the Hall of Champions should list the duel winner")
	end
	if not hall or not string.find(hall.columns.royaleWins.Text, "Nobody yet", 1, true) then
		fail("nobody has won a battle royale yet (the bots did)")
	end
	if not me.queued or me.queuedMode ~= "Duel" then
		fail("duelists stay queued for their next opponent")
	end
end
queueAction:InvokeServer("Leave")
print("duel: one spell, one potion, won against a bot")

for _, w in Mock.warnings do
	fail(w)
end
if failures > 0 then
	print(failures .. " failure(s)")
	process.exit(1)
end
print("match simulation passed")
