-- The survival-games loop:
--   Waiting (nobody queued) -> Voting (queued players pick the next map in the library)
--   -> Loading (the island is built) -> Countdown on pedestals -> Grace period (a short breather)
--   -> Battle (chest refill, mana storm closes in) -> Ended (winner) -> back to the library.
-- Players spawn in the hub and only join matches through the queue (see QueueService). Outside a
-- match they practise in the Spell Lab (see PracticeService).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Combatants = require(script.Parent.Combatants)
local GameState = require(script.Parent.GameState)
local MapService = require(script.Parent.MapService)
local ChestService = require(script.Parent.ChestService)
local InventoryService = require(script.Parent.InventoryService)
local CastingService = require(script.Parent.CastingService)
local StatusService = require(script.Parent.StatusService)
local DamageService = require(script.Parent.DamageService)
local ProjectileService = require(script.Parent.ProjectileService)
local ZoneService = require(script.Parent.ZoneService)
local ClassService = require(script.Parent.ClassService)
local DataService = require(script.Parent.DataService)
local BotService = require(script.Parent.BotService)
local VoteService = require(script.Parent.VoteService)
local QueueService = require(script.Parent.QueueService)
local FX = require(script.Parent.FX)

type Combatant = Combatants.Combatant

local MatchService = {}

local M = Config.Match
local rng = Random.new()
local participants: { Combatant } = {}
local initialCount = 0
local initialHumans = 0
local lobbyReady = false
local lastMapId: string? = nil
local watched: { [Model]: boolean } = setmetatable({}, { __mode = "k" }) :: any

local function now(): number
	return workspace:GetServerTimeNow()
end

---------------------------------------------------------------------------
-- Characters
---------------------------------------------------------------------------

local function setPlayerFlags(c: Combatant)
	if c.player then
		c.player:SetAttribute("Queued", c.queued)
		c.player:SetAttribute("InMatch", c.inMatch)
		c.player:SetAttribute("Alive", c.alive and c.inMatch)
		c.player:SetAttribute("Practice", c.practice)
		c.player:SetAttribute("MatchKills", c.kills)
	end
	if c.model then
		c.model:SetAttribute("InMatch", c.inMatch and c.alive)
	end
end

local function publishAlive()
	local alive = 0
	for _, c in participants do
		if c.alive then
			alive += 1
		end
	end
	GameState.setPublic("AliveCount", alive)
end

local onDied: (Combatant) -> ()

local function watchCharacter(c: Combatant, model: Model)
	if watched[model] then
		return
	end
	watched[model] = true
	local hum = model:WaitForChild("Humanoid", 10) :: Humanoid?
	model:WaitForChild("HumanoidRootPart", 10)
	if not hum then
		return
	end
	Combatants.setModel(c, model)
	hum.MaxHealth = Config.Combat.MaxHealth
	hum.Health = Config.Combat.MaxHealth
	hum.BreakJointsOnDeath = true
	hum.Died:Connect(function()
		if c.model == model then
			onDied(c)
		end
	end)
	-- back in the lobby: hand out the Spell Lab practice kit
	if c.player and not c.inMatch then
		c.practice = Config.Practice.Enabled
		c.status = {}
		InventoryService.reset(c)
		if c.practice then
			InventoryService.givePractice(c)
		end
	end
	StatusService.updateMovement(c)
	setPlayerFlags(c)
end

local function spawnPlayer(player: Player, cframe: CFrame?)
	local c = Combatants.forPlayer(player)
	if not c or not player.Parent then
		return
	end
	-- LoadCharacterAsync is the modern API; fall back for older engines.
	local ok, err = pcall(function()
		(player :: any):LoadCharacterAsync()
	end)
	if not ok then
		ok, err = pcall(function()
			(player :: any):LoadCharacter()
		end)
	end
	if not ok then
		warn("[Match] LoadCharacter failed: " .. tostring(err))
		return
	end
	local character = player.Character
	if character then
		if c.model ~= character then
			watchCharacter(c, character)
		end
		character:PivotTo(cframe or QueueService.restCFrame(c))
	end
end

-- Respawns a player where they belong outside a match (library if queued, otherwise the hub).
local function sendToLobby(c: Combatant)
	if c.player then
		task.spawn(spawnPlayer, c.player, nil)
	end
end

---------------------------------------------------------------------------
-- Eliminations
---------------------------------------------------------------------------

onDied = function(c: Combatant)
	if not c.inMatch or not c.alive then
		-- died outside a match (fell off the lobby?): just respawn
		task.delay(2, sendToLobby, c)
		return
	end
	c.alive = false
	local pos = if c.root then (c.root :: BasePart).Position else nil
	local killer: Combatant? = nil
	if c.lastAttacker and c.lastAttacker ~= c and now() - c.lastAttackTime < 20 then
		killer = c.lastAttacker
	end
	if killer then
		killer.kills += 1
		if killer.player then
			DataService.addKill(killer.player)
		end
		setPlayerFlags(killer)
	end

	local entries = InventoryService.takeAllAsLoot(c)
	if pos and #entries > 0 then
		ChestService.dropSatchel(pos, entries, c.name .. "'s satchel")
	end
	StatusService.clear(c)
	c.inMatch = false
	setPlayerFlags(c)
	publishAlive()

	FX.announce("Kill", {
		victim = c.name,
		killer = if killer then killer.name else nil,
		spell = c.lastSpellName,
		remaining = ReplicatedStorage:GetAttribute("AliveCount"),
	})
	FX.all("Cannon")

	if c.player then
		task.delay(M.RespawnToLobbyDelay, sendToLobby, c)
	else
		task.delay(3, BotService.remove, c)
	end
end

---------------------------------------------------------------------------
-- Match phases
---------------------------------------------------------------------------

-- Banners for everyone following the match (fighters + the library), and a toast for the hub.
local function announceMatch(data: { [string]: any })
	for _, player in Players:GetPlayers() do
		local c = Combatants.forPlayer(player)
		if c and (c.queued or c.inMatch) then
			FX.announceTo(player, "Banner", data)
		end
	end
end

local function announceHub(text: string)
	for _, player in Players:GetPlayers() do
		local c = Combatants.forPlayer(player)
		if c and not c.queued and not c.inMatch then
			FX.announceTo(player, "Toast", { text = text })
		end
	end
end

local function canStart(): boolean
	local n = #QueueService.waiting()
	if Config.Bots.Enabled then
		return n >= math.max(1, Config.Bots.MinRealPlayers)
	end
	return n >= M.MinPlayers or (RunService:IsStudio() and n >= 1)
end

local function shuffle<T>(list: { T }): { T }
	for i = #list, 2, -1 do
		local j = rng:NextInteger(1, i)
		list[i], list[j] = list[j], list[i]
	end
	return list
end

local function botName(used: { [string]: boolean }): string
	local names = Config.Bots.Names
	for _ = 1, 20 do
		local name = names[rng:NextInteger(1, #names)]
		if not used[name] then
			used[name] = true
			return name
		end
	end
	return "Mage" .. rng:NextInteger(100, 999)
end

local function waitPhase(seconds: number, abort: (() -> boolean)?): boolean
	local finish = now() + seconds
	while now() < finish do
		if abort and abort() then
			return false
		end
		task.wait(0.25)
	end
	return true
end

local function aliveParticipants(): ({ Combatant }, number)
	local alive, humans = {}, 0
	for _, c in participants do
		if c.alive and Combatants.isActive(c) then
			table.insert(alive, c)
			if c.player then
				humans += 1
			end
		end
	end
	return alive, humans
end

local function stormDamageTick(dps: number)
	local center = GameState.stormCenter
	for _, c in aliveParticipants() do
		local p = (c.root :: BasePart).Position
		if Vector3.new(p.X - center.X, 0, p.Z - center.Z).Magnitude > GameState.stormRadius then
			DamageService.apply(c, dps * 0.5, { isStorm = true, element = "Arcane" })
		end
	end
end

local function cleanupMatch()
	ProjectileService.clear()
	ZoneService.clear()
	BotService.removeAll()
	ChestService.clear()
	CastingService.clearCache()
	for _, c in participants do
		if c.player and c.player.Parent and c.inMatch then
			-- (eliminated players are already back in the lobby practising)
			c.inMatch = false
			c.alive = false
			StatusService.clear(c)
			InventoryService.reset(c)
			setPlayerFlags(c)
			sendToLobby(c)
		end
	end
	if not Config.Queue.StayQueuedAfterMatch then
		for _, c in participants do
			if c.player and c.player.Parent then
				QueueService.leave(c.player)
				setPlayerFlags(c)
			end
		end
	end
	table.clear(participants)
	GameState.stormRadius = 1e5
	GameState.setPublic("StormActive", false)
	GameState.setPublic("StormRadius", 1e5)
	GameState.setPublic("AliveCount", 0)
end

local function runMatch()
	-- Voting: queued players pick the next map in the library; anyone in the hub can still join
	local closesAt = now() + M.VoteTime
	VoteService.begin(rng, closesAt, lastMapId)
	GameState.setPhase("Voting", closesAt)
	announceMatch({ title = "Vote for the next map!", subtitle = "Pick your class and practise while you wait" })
	announceHub("⚔ A match is starting in " .. M.VoteTime .. "s! Walk through the portal to join")
	local completed, shortened = true, false
	while now() < closesAt do
		if not canStart() then
			completed = false
			break
		end
		-- every pedestal is spoken for: no need to wait for more players
		local fast = Config.Queue.FullQueueVoteTime
		if not shortened and #QueueService.waiting() >= M.MaxParticipants and closesAt - now() > fast then
			shortened = true
			closesAt = now() + fast
			GameState.setPhase("Voting", closesAt)
			VoteService.setEndsAt(closesAt)
			announceMatch({ title = "The queue is full!", subtitle = "Voting closes in " .. fast .. " seconds" })
		end
		task.wait(0.25)
	end
	local def = VoteService.finish(rng)
	if not completed then
		return
	end

	-- Loading: build the winning island
	GameState.setPhase("Loading", 0)
	GameState.setPublic("NextMapName", def.name)
	announceMatch({ title = def.icon .. "  " .. def.name, subtitle = "won the vote! Building the island..." })
	ChestService.clear()
	local generated, err = pcall(MapService.generate, rng:NextInteger(1, 1e9), def)
	if not generated then
		warn("[Match] map generation failed: " .. tostring(err))
		return
	end
	lastMapId = def.id
	local arena = MapService.arena
	if not arena or not canStart() then
		return
	end

	-- Pick participants: the queue in order (anyone beyond 24 waits for the next round), then bots
	local pedestals = shuffle(table.clone(arena.pedestals))
	participants = {}
	for i, player in QueueService.waiting() do
		if i > #pedestals then
			break
		end
		local c = Combatants.forPlayer(player)
		if c then
			QueueService.backOfLine(c)
			table.insert(participants, c)
		end
	end
	initialHumans = #participants
	if initialHumans == 0 then
		return
	end
	if Config.Bots.Enabled then
		local used: { [string]: boolean } = {}
		local wanted = math.min(Config.Bots.FillTo, #pedestals) - #participants
		for _ = 1, wanted do
			local idx = #participants + 1
			local bot = BotService.spawn(botName(used), pedestals[idx])
			if bot then
				table.insert(participants, bot)
				watchCharacter(bot, bot.model :: Model)
			end
		end
	end
	initialCount = #participants

	-- Place everyone on a pedestal with a fresh inventory and their class kit. (Flags first:
	-- spawning yields, and being in the match stops anyone picked from leaving the queue meanwhile.)
	for _, c in participants do
		c.practice = false
		c.inMatch = true
		c.alive = true
		c.kills = 0
		c.lastAttacker = nil
		c.status = {}
		c.locked = true
		InventoryService.reset(c)
	end
	for i, c in participants do
		if c.player then
			spawnPlayer(c.player, pedestals[i])
		end
	end
	ChestService.spawnArenaChests(arena.chestSpots)
	for _, c in participants do
		local classId = if c.player then ClassService.classFor(c.player) else ClassService.randomClass(rng)
		InventoryService.giveKit(c, classId)
		StatusService.updateMovement(c)
		setPlayerFlags(c)
	end

	-- Storm setup: it closes on a random point near the cornucopia
	local angle = rng:NextNumber(0, math.pi * 2)
	local offset = rng:NextNumber(0, 50)
	GameState.stormCenter = Vector3.new(math.cos(angle) * offset, arena.plazaY, math.sin(angle) * offset)
	local startRadius = arena.radius + 40
	local shrinkTime = M.StormShrinkTime * (arena.radius / 450)
	local lava = if arena.def.hazard == "Lava" then arena.def.terrain.liquidLevel + 4 else nil
	GameState.stormRadius = startRadius
	GameState.setPublic("StormCenter", GameState.stormCenter)
	GameState.setPublic("StormRadius", startRadius)
	GameState.setPublic("StormActive", false)
	GameState.setPublic("ParticipantCount", initialCount)
	publishAlive()

	GameState.setPhase("Countdown", now() + M.PedestalCountdown)
	announceMatch({ title = "Get ready...", subtitle = "Loot the cornucopia or run for the woods!" })
	announceHub("⚔ A match just started on " .. def.name .. ". Join the queue to play the next one")
	waitPhase(M.PedestalCountdown)

	for _, c in participants do
		c.locked = false
		StatusService.updateMovement(c)
	end
	local start = now()
	GameState.matchStartedAt = start
	GameState.setPublic("MatchStartedAt", start)
	GameState.setPhase("Grace", start + M.GracePeriod)
	announceMatch({ title = "GO!", subtitle = "Grace period: no PvP for " .. M.GracePeriod .. " seconds" })
	FX.all("Gong")

	local refilled = false
	local stormAnnounced = false
	local suddenDeath = false
	local stormAcc = 0
	local winner: Combatant? = nil
	local lastTick = now()
	while true do
		task.wait(0.25)
		local t = now()
		local dt = t - lastTick
		lastTick = t
		local elapsed = t - start

		if GameState.phase == "Grace" and elapsed >= M.GracePeriod then
			GameState.setPhase("Battle", 0)
			announceMatch({ title = "Grace period over", subtitle = "Spells now hurt other mages. Good luck." })
		end

		if not refilled and elapsed >= M.ChestRefillAt then
			refilled = true
			ChestService.refill()
			announceMatch({ title = "Chests refilled!", subtitle = "Fresh loot in every chest" })
		end

		if elapsed >= M.StormStartAt then
			if not stormAnnounced then
				stormAnnounced = true
				GameState.setPublic("StormActive", true)
				announceMatch({ title = "The Mana Storm is closing in", subtitle = "Stay inside the circle" })
			end
			local alpha = math.clamp((elapsed - M.StormStartAt) / shrinkTime, 0, 1)
			local radius = startRadius + (M.StormFinalRadius - startRadius) * alpha
			GameState.stormRadius = radius
			GameState.setPublic("StormRadius", radius)
			local dps = M.StormDamagePerSecond
			if elapsed >= M.SuddenDeathAt then
				dps *= 4
				if not suddenDeath then
					suddenDeath = true
					announceMatch({ title = "Sudden death", subtitle = "The storm burns four times as hot" })
				end
			end
			stormAcc += dt
			while stormAcc >= 0.5 do
				stormAcc -= 0.5
				stormDamageTick(dps)
			end
		end

		-- keep anybody who wandered off the map honest, and let lava burn
		for _, c in participants do
			if c.alive and c.root and c.humanoid then
				local y = (c.root :: BasePart).Position.Y
				if y < -40 then
					(c.humanoid :: Humanoid).Health = 0
				elseif lava and y < lava then
					StatusService.apply(c, { kind = "Burn", dps = 10, duration = 1.5 }, nil)
				end
			end
		end

		local alive, aliveHumans = aliveParticipants()
		if initialCount >= 2 and #alive <= 1 then
			winner = alive[1]
			break
		end
		if initialHumans > 0 and aliveHumans == 0 then
			-- every real player is out: crown the best bot so nobody waits forever
			table.sort(alive, function(a, b)
				return a.kills > b.kills
			end)
			winner = alive[1]
			break
		end
		if #alive == 0 or elapsed >= M.HardTimeLimit then
			winner = nil
			break
		end
	end

	GameState.setPhase("Ended", now() + M.EndScreenTime)
	FX.announce("Winner", {
		name = if winner then winner.name else nil,
		isBot = if winner then winner.isBot else false,
		kills = if winner then winner.kills else 0,
	})
	if winner and winner.player then
		DataService.addWin(winner.player)
	end
	for _, c in participants do
		if c.player and c.player.Parent then
			DataService.addMatch(c.player)
			task.spawn(DataService.save, c.player)
		end
	end
	task.wait(M.EndScreenTime)
	cleanupMatch()
end

---------------------------------------------------------------------------
-- Player lifecycle
---------------------------------------------------------------------------

local function onPlayerAdded(player: Player)
	local c = Combatants.create(player.DisplayName, player)
	player:SetAttribute("Class", "Apprentice")
	ClassService.refresh(player)
	task.spawn(DataService.load, player)
	player.CharacterAdded:Connect(function(character)
		task.spawn(watchCharacter, c, character)
	end)
	setPlayerFlags(c)
	while not lobbyReady do
		task.wait(0.1)
	end
	spawnPlayer(player, nil)
end

local function onPlayerRemoving(player: Player)
	local c = Combatants.forPlayer(player)
	if not c then
		return
	end
	if c.inMatch and c.alive then
		local pos = if c.root then (c.root :: BasePart).Position else nil
		c.alive = false
		c.inMatch = false
		local entries = InventoryService.takeAllAsLoot(c)
		if pos and #entries > 0 then
			ChestService.dropSatchel(pos, entries, c.name .. "'s satchel")
		end
		FX.announce("Kill", { victim = c.name, left = true })
		publishAlive()
	end
	Combatants.remove(c)
end

function MatchService.init()
	GameState.setPhase("Waiting", 0)
	GameState.setPublic("StormActive", false)
	GameState.setPublic("StormRadius", 1e5)
	GameState.setPublic("AliveCount", 0)

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	-- Safety net: anyone not fighting who falls off the hub or the library is put back.
	task.spawn(function()
		while true do
			task.wait(1)
			local floor = Config.Arena.LobbyHeight - 60
			for _, player in Players:GetPlayers() do
				local c = Combatants.forPlayer(player)
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if c and not c.inMatch and root and root.Position.Y < floor then
					(character :: Model):PivotTo(QueueService.restCFrame(c))
				end
			end
		end
	end)
end

function MatchService.start()
	lobbyReady = true
	-- Build a first island in the background so the view below the lobby is never empty
	task.spawn(function()
		local ok, err = pcall(MapService.generate, rng:NextInteger(1, 1e9), MapService.randomDef(rng))
		if not ok then
			warn("[Match] map generation failed: " .. tostring(err))
		end
	end)
	task.spawn(function()
		while true do
			GameState.setPhase("Waiting", 0)
			while not canStart() do
				task.wait(1)
			end
			local ok, err = pcall(runMatch)
			if not ok then
				warn("[Match] match crashed: " .. tostring(err))
				pcall(cleanupMatch)
			end
			task.wait(1)
		end
	end)
end

return MatchService
