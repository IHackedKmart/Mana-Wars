-- The main arena's match loop. Survival Games and Battle Royale take turns in it (whichever mode's
-- queue has waited longest goes next); 1v1 duels run on their own floating arenas (DuelService).
--   Survival Games: Waiting -> Voting (queued players pick the next map in the library)
--     -> Loading (the island is built) -> Countdown on pedestals -> Grace period (a short breather)
--     -> Battle (chest refill, mana storm closes in) -> Ended (winner) -> back to the library.
--   Battle Royale: Waiting -> Gathering (the queue fills while the huge island is built)
--     -> Carpet (everyone rides the magic carpet across the island and jumps off, see
--     CarpetService) -> Battle (storm circles close in, see StormCircles) -> Ended.
-- Players spawn in the hub and only join matches through the queue (see QueueService). Outside a
-- match they practise in the Spell Lab (see PracticeService).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local SpellParts = require(Shared.Spells.SpellParts)
local Combatants = require(script.Parent.Combatants)
local GameState = require(script.Parent.GameState)
local MapService = require(script.Parent.MapService)
local MapDefs = require(script.Parent.Parent.Map.MapDefs)
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
local WardrobeService = require(script.Parent.WardrobeService)
local FamiliarService = require(script.Parent.FamiliarService)
local Events = require(script.Parent.Events)
local DuelService = require(script.Parent.DuelService)
local CarpetService = require(script.Parent.CarpetService)
local StormCircles = require(script.Parent.StormCircles)
local FX = require(script.Parent.FX)

type Combatant = Combatants.Combatant

local MatchService = {}

local M = Config.Match
local RC = Config.Royale
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
		if not c.duel then
			-- (duels set their own)
			c.player:SetAttribute("Mode", if c.inMatch then GameState.mode else nil)
		end
		if not c.inMatch then
			c.player:SetAttribute("RealmName", nil)
			c.player:SetAttribute("RealmWeather", nil)
		end
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
	if c.player then
		WardrobeService.dress(c) -- robe + hat (and the stats their enchantments give)
	end
	hum.MaxHealth = Config.Combat.MaxHealth + (c.gear.health or 0)
	hum.Health = hum.MaxHealth
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

-- Coins for finishing. Survival Games pays by place among everyone (12 for 1st ... 1 for 12th).
-- A battle royale only counts real players, so bots never inflate it: with N players in the match,
-- the best-placed player earns N coins (at most Config.Royale.CoinsForFirst), the next N - 1, and
-- so on down to 1. `playerPlace` is the place among real players only.
local function payPlacement(c: Combatant, place: number, playerPlace: number)
	if not c.player then
		return
	end
	if GameState.mode == "Royale" then
		local first = math.min(RC.CoinsForFirst, initialHumans)
		WardrobeService.awardPlacement(c, playerPlace, initialHumans, first, "players")
	else
		WardrobeService.awardPlacement(c, place, initialCount)
	end
end

onDied = function(c: Combatant)
	if c.duel then
		DuelService.onDied(c) -- duels keep their own score
		return
	end
	if not c.inMatch or not c.alive then
		-- died outside a match (fell off the lobby?): just respawn
		task.delay(2, sendToLobby, c)
		return
	end
	c.alive = false
	CarpetService.forget(c)
	-- finishing place: everyone still standing finishes ahead of you
	local stillAlive, playersAlive = 0, 0
	for _, other in participants do
		if other.alive and other ~= c then
			stillAlive += 1
			if other.player then
				playersAlive += 1
			end
		end
	end
	-- (someone who dies as the match ends was already ranked with the survivors: no second payout)
	if c.place == nil then
		local place = stillAlive + 1
		c.place = place
		payPlacement(c, place, playersAlive + 1)
	end
	local pos = if c.root then (c.root :: BasePart).Position else nil
	FamiliarService.onDeath(c, pos)
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

local function canStart(mode: string): boolean
	local n = #QueueService.waiting(mode)
	if Config.Bots.Enabled then
		local min = if mode == "Royale" then RC.MinRealPlayers else Config.Bots.MinRealPlayers
		return n >= math.max(1, min)
	end
	return n >= M.MinPlayers or (RunService:IsStudio() and n >= 1)
end

-- Which match the main arena runs next: of the modes with enough players queued, the one whose
-- first player in line has waited longest.
local ARENA_MODES = { "Survival", "Royale" }
local function nextMode(): string?
	local best, bestSince = nil, math.huge
	for _, mode in ARENA_MODES do
		if canStart(mode) then
			local first = QueueService.waiting(mode)[1]
			local c = first and Combatants.forPlayer(first)
			local since = if c then c.queuedAt else math.huge
			if since < bestSince or best == nil then
				best, bestSince = mode, since
			end
		end
	end
	return best
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

-- Dev panel controls: skip the current wait (vote, countdown or grace), jump the match clock
-- ahead (chest refill, storm), or end the match now.
local devSkipRequested = false
local devEndRequested = false
local devElapsed = 0

local function consumeSkip(): boolean
	if devSkipRequested then
		devSkipRequested = false
		return true
	end
	return false
end

function MatchService.devSkip()
	devSkipRequested = true
end

function MatchService.devAdvance(seconds: number)
	devElapsed += seconds
end

function MatchService.devEnd()
	devEndRequested = true
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
	CarpetService.stop()
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
	GameState.setPublic("StormNextRadius", nil)
	GameState.setPublic("StormNextCenter", nil)
	GameState.setPublic("StormStage", nil)
	GameState.setPublic("AliveCount", 0)
end

-- Gives everyone in the match a fresh inventory and their class kit (plus a toast about the kit's
-- random bonus part).
local function handOutKits()
	for _, c in participants do
		local classId = if c.player then ClassService.classFor(c.player) else ClassService.randomClass(rng)
		local bonus = InventoryService.giveKit(c, classId)
		if c.player and c.player:GetAttribute("DevLoadout") == true then
			InventoryService.giveDevLoadout(c) -- dev panel: everything, every match
		end
		local part = if bonus then SpellParts.ById[bonus] else nil
		if c.player and part then
			FX.announceTo(c.player, "Toast", {
				text = "Kit bonus: "
					.. part.icon
					.. " "
					.. part.name
					.. " ("
					.. part.rarity
					.. " "
					.. part.category
					.. ")",
			})
		end
		StatusService.updateMovement(c)
		setPlayerFlags(c)
	end
end

-- Fresh match state for everyone picked to play.
local function resetParticipants(locked: boolean)
	for _, c in participants do
		c.practice = false
		c.inMatch = true
		c.alive = true
		c.place = nil
		c.kills = 0
		c.lastAttacker = nil
		c.status = {}
		c.locked = locked
		InventoryService.reset(c)
	end
end

-- Anybody who wandered off the map dies, and lava burns.
local function fallsAndLava(lava: number?)
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
end

-- Whether the match is over (and who won, if anyone).
local function decided(elapsed: number, hardLimit: number): (boolean, Combatant?)
	local alive, aliveHumans = aliveParticipants()
	if initialCount >= 2 and #alive <= 1 then
		return true, alive[1]
	end
	if initialHumans > 0 and aliveHumans == 0 then
		-- every real player is out: crown the best bot so nobody waits forever
		table.sort(alive, function(a, b)
			return a.kills > b.kills
		end)
		return true, alive[1]
	end
	if #alive == 0 or elapsed >= hardLimit then
		return true, nil
	end
	return false, nil
end

-- The end screen, coins for everyone still standing, stats, then back to the library.
local function finishMatch(winner: Combatant?, def: MapDefs.MapDef, mode: string)
	GameState.setPhase("Ended", now() + M.EndScreenTime)
	FX.announce("Winner", {
		name = if winner then winner.name else nil,
		isBot = if winner then winner.isBot else false,
		kills = if winner then winner.kills else 0,
	})
	if winner and winner.player then
		DataService.addWin(winner.player)
		if mode == "Royale" then
			-- (wins counts every big-match win; the leaderboards split out the battle royale's)
			DataService.count(winner.player, "royaleWins")
		end
	end
	-- coins for everyone still standing: the winner first, then by kills
	local standing = {}
	for _, c in participants do
		if c.alive and c.inMatch and c.place == nil then
			table.insert(standing, c)
		end
	end
	table.sort(standing, function(a, b)
		if a == winner or b == winner then
			return a == winner
		end
		-- anyone already on their way down (health gone, death not yet processed) ranks last
		local activeA, activeB = Combatants.isActive(a), Combatants.isActive(b)
		if activeA ~= activeB then
			return activeA
		end
		return a.kills > b.kills
	end)
	local playersRanked = 0
	for i, c in standing do
		c.place = i
		if c.player then
			playersRanked += 1
			if c.player.Parent then
				payPlacement(c, i, playersRanked)
			end
		end
	end
	for _, c in participants do
		if c.player and c.player.Parent then
			DataService.addMatch(c.player)
			Events.fire(
				"MatchFinished",
				c.player,
				c.place or initialCount,
				initialCount,
				c.kills,
				def.id,
				tostring(c.player:GetAttribute("Class")),
				mode
			)
			task.spawn(DataService.save, c.player)
		end
	end
	task.wait(M.EndScreenTime)
	cleanupMatch()
end

local function runSurvival()
	GameState.mode = "Survival"
	GameState.setPublic("MatchMode", "Survival")
	-- Voting: queued players pick the next map in the library; anyone in the hub can still join
	local closesAt = now() + M.VoteTime
	VoteService.begin(rng, closesAt, lastMapId)
	GameState.setPhase("Voting", closesAt)
	announceMatch({ title = "Vote for the next map!", subtitle = "Pick your class and practise while you wait" })
	announceHub("⚔️ A match is starting in " .. M.VoteTime .. "s! Walk through the portal to join")
	local completed, shortened = true, false
	while now() < closesAt do
		if not canStart("Survival") then
			completed = false
			break
		end
		if consumeSkip() then
			break -- dev panel: close the vote now
		end
		-- every pedestal is spoken for: no need to wait for more players
		local fast = Config.Queue.FullQueueVoteTime
		if not shortened and #QueueService.waiting("Survival") >= M.MaxParticipants and closesAt - now() > fast then
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
	if not arena or not canStart("Survival") then
		return
	end

	-- Pick participants: the queue in order (anyone beyond 12 waits for the next round), then bots
	local pedestals = shuffle(table.clone(arena.pedestals))
	participants = {}
	for i, player in QueueService.waiting("Survival") do
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
				WardrobeService.dressBot(bot, rng)
				watchCharacter(bot, bot.model :: Model)
			end
		end
	end
	initialCount = #participants

	-- Place everyone on a pedestal with a fresh inventory and their class kit. (Flags first:
	-- spawning yields, and being in the match stops anyone picked from leaving the queue meanwhile.)
	resetParticipants(true)
	for i, c in participants do
		if c.player then
			spawnPlayer(c.player, pedestals[i])
		end
	end
	ChestService.spawnArenaChests(arena.chestSpots)
	handOutKits()

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
	announceHub("⚔️ A match just started on " .. def.name .. ". Join the queue to play the next one")
	waitPhase(M.PedestalCountdown, consumeSkip)

	for _, c in participants do
		c.locked = false
		StatusService.updateMovement(c)
	end
	local start = now()
	devElapsed = 0
	devEndRequested = false
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
		local elapsed = t - start + devElapsed

		if devEndRequested then
			devEndRequested = false
			winner = nil
			break
		end

		if GameState.phase == "Grace" and (elapsed >= M.GracePeriod or consumeSkip()) then
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
		fallsAndLava(lava)
		local over, won = decided(elapsed, M.HardTimeLimit)
		if over then
			winner = won
			break
		end
	end
	finishMatch(winner, def, "Survival")
end

-- Where a bot hopping off the carpet glides to: often the nearest named place, otherwise some dry
-- ground not far below.
local function landingFor(arena: MapService.Arena): (Vector3, Random) -> Vector3
	local wet = arena.def.terrain.liquidLevel + 1.5
	return function(from: Vector3, r: Random): Vector3
		local below = Vector3.new(from.X, 0, from.Z)
		local locations = arena.locations or {}
		if #locations > 0 and r:NextNumber() < 0.45 then
			local best, bestD = nil, 350
			for _, loc in locations do
				local d = (Vector3.new(loc.pos.X, 0, loc.pos.Z) - below).Magnitude
				if d < bestD then
					best, bestD = loc, d
				end
			end
			if best then
				local a, d = r:NextNumber(0, math.pi * 2), r:NextNumber(0, best.radius)
				return Vector3.new(best.pos.X + math.cos(a) * d, 0, best.pos.Z + math.sin(a) * d)
			end
		end
		for _ = 1, 10 do
			local a, d = r:NextNumber(0, math.pi * 2), r:NextNumber(0, 160)
			local x, z = below.X + math.cos(a) * d, below.Z + math.sin(a) * d
			if arena.heightAt(x, z) > wet and Vector3.new(x, 0, z).Magnitude < arena.radius * 0.9 then
				return Vector3.new(x, 0, z)
			end
		end
		return below * 0.8 -- (towards the middle, away from the sea)
	end
end

local function runRoyale()
	local def = MapService.royaleDef()
	GameState.mode = "Royale"
	GameState.setPublic("MatchMode", "Royale")

	-- Gathering: the queue stays open while the island is built underneath the library
	local closesAt = now() + RC.GatherTime
	GameState.setPhase("Gathering", closesAt)
	GameState.setPublic("NextMapName", def.name)
	announceMatch({
		title = "🧞 Battle Royale",
		subtitle = "The magic carpet leaves in " .. RC.GatherTime .. " seconds",
	})
	announceHub("🧞 A Battle Royale starts in " .. RC.GatherTime .. "s! Walk through the portal to join")
	ChestService.clear()
	local built: boolean? = nil
	local buildError: any = nil
	task.spawn(function()
		local ok, err = pcall(MapService.generate, rng:NextInteger(1, 1e9), def)
		built, buildError = ok, err
	end)
	local shortened = false
	while now() < closesAt or built == nil do
		if not canStart("Royale") then
			return -- everyone left (the island finishes building by itself)
		end
		if consumeSkip() then
			closesAt = now() -- dev panel: leave now
		end
		local fast = Config.Queue.FullQueueVoteTime
		if not shortened and #QueueService.waiting("Royale") >= RC.MaxParticipants and closesAt - now() > fast then
			shortened = true
			closesAt = now() + fast
			GameState.setPhase("Gathering", closesAt)
			announceMatch({ title = "The carpet is full!", subtitle = "Leaving in " .. fast .. " seconds" })
		end
		if now() >= closesAt and built == nil and GameState.phase ~= "Loading" then
			GameState.setPhase("Loading", 0)
			announceMatch({ title = "🧞 " .. def.name, subtitle = "The island is almost ready..." })
		end
		task.wait(0.25)
	end
	if not built then
		warn("[Match] map generation failed: " .. tostring(buildError))
		return
	end
	lastMapId = nil -- (the next Survival vote may offer any island)
	local arena = MapService.arena
	if not arena or not canStart("Royale") then
		return
	end

	-- Pick participants: the queue in order (up to 50), then bots
	participants = {}
	for i, player in QueueService.waiting("Royale") do
		if i > RC.MaxParticipants then
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
	local from, to = CarpetService.path(arena.radius, rng)
	if Config.Bots.Enabled then
		local used: { [string]: boolean } = {}
		for _ = 1, math.min(RC.FillTo, RC.MaxParticipants) - #participants do
			local bot = BotService.spawn(botName(used), CFrame.new(from))
			if bot then
				table.insert(participants, bot)
				WardrobeService.dressBot(bot, rng)
				watchCharacter(bot, bot.model :: Model)
			end
		end
	end
	initialCount = #participants
	resetParticipants(false)

	-- All aboard: the carpet hovers at the edge of the island while everyone is put on it
	local takeOff = now() + 8
	CarpetService.begin(participants, from, to, takeOff, arena.heightAt, landingFor(arena), rng)
	local spawning = 0
	for _, c in participants do
		local player = c.player
		if player then
			spawning += 1
			task.spawn(function()
				spawnPlayer(player, CarpetService.seatCFrame(c))
				spawning -= 1
			end)
		end
	end
	ChestService.spawnArenaChests(arena.chestSpots)
	handOutKits()

	-- The storm: circles planned now, shown from the start
	local plan = StormCircles.plan(RC.Circles, arena.radius, arena.plazaY, rng)
	local storm = StormCircles.at(plan, 0)
	GameState.stormCenter = storm.center
	GameState.stormRadius = storm.radius
	GameState.setPublic("StormCenter", storm.center)
	GameState.setPublic("StormRadius", storm.radius)
	GameState.setPublic("StormActive", true)
	GameState.setPublic("StormNextCenter", storm.nextCenter)
	GameState.setPublic("StormNextRadius", storm.nextRadius)
	GameState.setPublic("StormStage", storm.stage)
	GameState.setPublic("StormShrinking", false)
	GameState.setPublic("StormMovesAt", takeOff + plan[1].holdUntil)
	GameState.setPublic("ParticipantCount", initialCount)
	publishAlive()

	GameState.setPhase("Carpet", takeOff)
	announceMatch({ title = "🧞 All aboard the magic carpet!", subtitle = "Jump off wherever you like with SPACE" })
	announceHub("🧞 A Battle Royale just took off. Join the queue to play the next one")
	local boardBy = now() + 10
	while spawning > 0 and now() < boardBy do
		task.wait(0.1)
	end
	while now() < takeOff do
		if consumeSkip() then
			break
		end
		task.wait(0.1)
	end

	GameState.setPhase("Carpet", takeOff + RC.CarpetTime)
	FX.all("Gong")
	local start = takeOff
	devElapsed = 0
	devEndRequested = false
	GameState.matchStartedAt = start
	GameState.setPublic("MatchStartedAt", start)

	local landed = false
	local refilled = false
	local shownStage, shownShrinking = 0, false
	local nextRealmCheck = 0
	local stormAcc = 0
	local winner: Combatant? = nil
	local lastTick = now()
	while true do
		task.wait(0.25)
		local t = now()
		local dt = t - lastTick
		lastTick = t
		local elapsed = t - start + devElapsed

		if devEndRequested then
			devEndRequested = false
			winner = nil
			break
		end

		if not landed then
			landed = CarpetService.update()
			if GameState.phase == "Carpet" and t >= takeOff + RC.CarpetTime then
				GameState.setPhase("Battle", 0)
			end
			if landed then
				CarpetService.stop()
				announceMatch({ title = "Everyone has landed", subtitle = "Loot up and stay inside the circle" })
			end
		end

		if not refilled and elapsed >= RC.ChestRefillAt then
			refilled = true
			ChestService.refill()
			announceMatch({ title = "Chests refilled!", subtitle = "Fresh loot in every chest" })
		end

		-- the storm circles
		storm = StormCircles.at(plan, elapsed)
		GameState.stormCenter = storm.center
		GameState.stormRadius = storm.radius
		GameState.setPublic("StormCenter", storm.center)
		GameState.setPublic("StormRadius", storm.radius)
		if storm.stage <= #plan then
			GameState.setPublic("StormNextCenter", storm.nextCenter)
			GameState.setPublic("StormNextRadius", storm.nextRadius)
		else
			GameState.setPublic("StormNextCenter", nil)
			GameState.setPublic("StormNextRadius", nil)
		end
		GameState.setPublic("StormStage", storm.stage)
		GameState.setPublic("StormShrinking", storm.shrinking)
		local stage = plan[math.min(storm.stage, #plan)]
		GameState.setPublic(
			"StormMovesAt",
			if storm.shrinking then stage.shrinkUntil + start else stage.holdUntil + start
		)
		if storm.stage ~= shownStage or storm.shrinking ~= shownShrinking then
			if storm.shrinking then
				announceMatch({ title = "The storm is closing in!", subtitle = "Get inside the next circle" })
			elseif storm.stage > 1 and storm.stage <= #plan then
				announceMatch({ title = "A new circle has appeared", subtitle = "Check your map and head inside" })
			end
			shownStage, shownShrinking = storm.stage, storm.shrinking
		end
		if storm.dps > 0 then
			stormAcc += dt
			while stormAcc >= 0.5 do
				stormAcc -= 0.5
				stormDamageTick(storm.dps)
			end
		end

		-- which realm everyone is in (for their weather and the HUD)
		if t >= nextRealmCheck and arena.realmAt then
			nextRealmCheck = t + 1
			local realmAt = arena.realmAt :: (number, number) -> MapDefs.Biome
			for _, c in participants do
				if c.player and c.alive and c.root then
					local p = (c.root :: BasePart).Position
					local realm = realmAt(p.X, p.Z)
					c.player:SetAttribute("RealmName", realm.name)
					c.player:SetAttribute("RealmWeather", realm.weather or "")
				end
			end
		end

		fallsAndLava(nil)
		local over, won = decided(elapsed, RC.HardTimeLimit)
		if over then
			winner = won
			break
		end
	end
	CarpetService.stop()
	finishMatch(winner, def, "Royale")
end

---------------------------------------------------------------------------
-- Player lifecycle
---------------------------------------------------------------------------

local function onPlayerAdded(player: Player)
	local c = Combatants.create(player.DisplayName, player)
	player:SetAttribute("Class", "Apprentice")
	task.spawn(ClassService.refresh, player)
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
	if c.duel then
		DuelService.onLeave(c) -- the other duelist wins
	elseif c.inMatch and c.alive then
		local pos = if c.root then (c.root :: BasePart).Position else nil
		c.alive = false
		CarpetService.forget(c)
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
	-- duels run on their own, but spawn and respawn mages the same way as matches
	DuelService.spawnPlayer = spawnPlayer
	DuelService.watchCharacter = watchCharacter
	DuelService.sendToLobby = sendToLobby
	DuelService.setFlags = setPlayerFlags
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
			local mode = nextMode()
			while not mode do
				task.wait(1)
				mode = nextMode()
			end
			local ok, err = pcall(if mode == "Royale" then runRoyale else runSurvival)
			if not ok then
				warn("[Match] match crashed: " .. tostring(err))
				pcall(cleanupMatch)
			end
			task.wait(1)
		end
	end)
end

return MatchService
