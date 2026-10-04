-- 1v1 duels. Players queued for "Duel" are paired as soon as two are waiting (or, after
-- Config.Duel.BotAfter seconds alone, with a bot). Each duel gets its own floating arena (see
-- Map/DuelArena), so several can run at once, alongside whatever the main arena is doing.
-- Both duelists get the same wand with ONE random spell, plus ONE random potion.
--   Countdown (frozen) -> Fight -> sudden death (the arena burns) -> Over (back to the library)
-- Duelists stay queued afterwards, so the next opponent comes along by itself.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Consumables = require(Shared.Consumables)
local PremadeSpells = require(Shared.Spells.PremadeSpells)
local SpellBuilder = require(Shared.Spells.SpellBuilder)
local WandGenerator = require(Shared.WandGenerator)
local LootTables = require(Shared.LootTables)
local DuelArena = require(script.Parent.Parent.Map.DuelArena)
local Combatants = require(script.Parent.Combatants)
local QueueService = require(script.Parent.QueueService)
local InventoryService = require(script.Parent.InventoryService)
local StatusService = require(script.Parent.StatusService)
local DamageService = require(script.Parent.DamageService)
local BotService = require(script.Parent.BotService)
local WardrobeService = require(script.Parent.WardrobeService)
local DataService = require(script.Parent.DataService)
local Events = require(script.Parent.Events)
local FX = require(script.Parent.FX)

type Combatant = Combatants.Combatant

export type Duel = {
	id: number,
	slot: number,
	arena: DuelArena.Info,
	a: Combatant,
	b: Combatant,
	state: string, -- "Countdown" | "Fight" | "Over"
	fightStartedAt: number,
	suddenDeath: boolean,
	winner: Combatant?,
}

local DuelService = {}

local D = Config.Duel
local rng = Random.new()
local arenas: { [number]: DuelArena.Info } = {}
local busy: { [number]: Duel } = {}
local nextId = 0
local folder: Folder? = nil
local aloneSince: { [Player]: number } = {}

-- Hooks MatchService fills in (it owns character spawning and the respawn rules).
DuelService.spawnPlayer = nil :: ((Player, CFrame?) -> ())?
DuelService.watchCharacter = nil :: ((Combatant, Model) -> ())?
DuelService.sendToLobby = nil :: ((Combatant) -> ())?
DuelService.setFlags = nil :: ((Combatant) -> ())?

local function now(): number
	return workspace:GetServerTimeNow()
end

-- Premade spells that actually hurt (no blinks, shields or walls), from the duel's rarity pool.
local spellPool: { string } = {}
do
	local allowed = {}
	for _, r in D.SpellRarities do
		allowed[r] = true
	end
	for _, p in PremadeSpells.List do
		local spec = if allowed[p.rarity] then SpellBuilder.compile(p.recipe) else nil
		if
			spec
			and spec.damage > 0
			and spec.kind ~= "Blink"
			and spec.kind ~= "Aegis"
			and spec.kind ~= "Wall"
			and (spec.directMult > 0 or spec.explodeMult > 0 or spec.zoneMult > 0)
		then
			table.insert(spellPool, p.id)
		end
	end
end
DuelService.SpellPool = spellPool

local function arenaFor(slot: number): DuelArena.Info
	if not arenas[slot] then
		if not folder then
			local f = Instance.new("Folder")
			f.Name = "DuelArenas"
			f.Parent = workspace
			folder = f
		end
		arenas[slot] = DuelArena.build(slot, folder :: Folder)
	end
	return arenas[slot]
end

local function freeSlot(): number?
	for slot = 1, D.MaxArenas do
		if not busy[slot] then
			return slot
		end
	end
	return nil
end

local function setDuelAttributes(c: Combatant, duel: Duel?, endsAt: number?)
	local player = c.player
	if not player then
		return
	end
	if duel then
		local rival = if duel.a == c then duel.b else duel.a
		player:SetAttribute("Mode", "Duel")
		player:SetAttribute("DuelState", duel.state)
		player:SetAttribute("DuelEndsAt", endsAt or 0)
		player:SetAttribute("DuelOpponent", rival.name)
		player:SetAttribute("DuelSudden", duel.suddenDeath)
	else
		player:SetAttribute("DuelSudden", nil)
		player:SetAttribute("Mode", nil)
		player:SetAttribute("DuelState", nil)
		player:SetAttribute("DuelEndsAt", nil)
		player:SetAttribute("DuelOpponent", nil)
	end
end

local function both(duel: Duel): { Combatant }
	return { duel.a, duel.b }
end

local function banner(duel: Duel, data: { [string]: any })
	for _, c in both(duel) do
		if c.player then
			FX.announceTo(c.player, "Banner", data)
		end
	end
end

-- The loadout: the same wand for both, one random damaging spell each, one random potion each.
local function giveLoadout(c: Combatant, wandSeed: number)
	InventoryService.reset(c)
	local wand = WandGenerator.generate(Random.new(wandSeed), D.WandRarity, nil)
	for i in wand.slots do
		wand.slots[i] = false
	end
	local spellId = spellPool[rng:NextInteger(1, #spellPool)]
	wand.slots[1] = LootTables.premadeSpell(spellId)
	c.inventory.wands[1] = wand
	c.inventory.equipped = 1
	local potion = Consumables.List[rng:NextInteger(1, #Consumables.List)]
	c.inventory.consumables[potion.id] = 1
	InventoryService.refreshTools(c)
	InventoryService.sync(c)
	if c.player then
		local spell = PremadeSpells.ById[spellId]
		FX.announceTo(c.player, "Toast", {
			text = string.format("Your spell: %s · your potion: %s %s", spell.name, potion.icon, potion.name),
		})
	end
end

local function cleanup(duel: Duel)
	busy[duel.slot] = nil
	for _, c in both(duel) do
		c.duel = nil
		c.locked = false
		if c.player then
			c.inMatch = false
			c.alive = false
			StatusService.clear(c)
			InventoryService.reset(c)
			setDuelAttributes(c, nil)
			if DuelService.setFlags then
				DuelService.setFlags(c)
			end
			if c.player.Parent and DuelService.sendToLobby then
				DuelService.sendToLobby(c)
			end
		else
			BotService.remove(c)
		end
	end
end

local function finish(duel: Duel, winner: Combatant?, reason: string)
	if duel.state == "Over" then
		return
	end
	duel.state = "Over"
	duel.winner = winner
	for _, c in both(duel) do
		c.locked = true
		setDuelAttributes(c, duel, now() + 4)
		local player = c.player
		if player then
			local won = winner == c
			local rival = if duel.a == c then duel.b else duel.a
			if winner == nil then
				FX.announceTo(player, "Banner", { title = "Draw!", subtitle = reason })
			elseif won then
				FX.announceTo(
					player,
					"Banner",
					{ title = "🏆 Victory!", subtitle = "You beat " .. rival.name .. " · " .. reason }
				)
			else
				FX.announceTo(player, "Banner", { title = "Defeated", subtitle = rival.name .. " wins · " .. reason })
			end
			WardrobeService.addCoins(
				player,
				if won then D.WinCoins else D.LoseCoins,
				if won then "duel won" else "duel played",
				{ type = "Gameplay", sku = "Duel" }
			)
			if won then
				DataService.count(player, "duelWins") -- (for the achievements and the leaderboard)
			end
			Events.fire("DuelFinished", player, won, rival.isBot)
		end
	end
	task.delay(4, cleanup, duel)
end

-- Called (by MatchService) when a duelist's character dies.
function DuelService.onDied(c: Combatant)
	local duel = c.duel :: Duel?
	if not duel or duel.state == "Over" then
		return
	end
	c.alive = false
	local winner = if duel.a == c then duel.b else duel.a
	if c.lastAttacker == winner then
		winner.kills += 1
		if winner.player then
			DataService.addKill(winner.player)
		end
	end
	finish(duel, winner, c.name .. " was defeated")
end

-- A duelist left the server: the other one wins.
function DuelService.onLeave(c: Combatant)
	local duel = c.duel :: Duel?
	if duel and duel.state ~= "Over" then
		local winner = if duel.a == c then duel.b else duel.a
		finish(duel, winner, c.name .. " left")
	end
end

local function prepare(c: Combatant, duel: Duel)
	c.duel = duel
	c.practice = false
	c.inMatch = true
	c.alive = true
	c.place = nil
	c.kills = 0
	c.lastAttacker = nil
	c.status = {}
	c.locked = true
	c.dropping = nil
	-- no kit, no outfit or familiar bonuses: both duelists start equal (players are re-dressed, and
	-- their bonuses come back, when they respawn in the library afterwards)
	c.gear = {}
	local hum = c.humanoid
	if hum then
		hum.MaxHealth = Config.Combat.MaxHealth
		hum.Health = Config.Combat.MaxHealth
	end
end

-- Starts a duel between two combatants (`b` may be nil: a bot steps in).
function DuelService.start(aPlayer: Player, bPlayer: Player?): Duel?
	local slot = freeSlot()
	local a = Combatants.forPlayer(aPlayer)
	if not slot or not a then
		return nil
	end
	local arena = arenaFor(slot)
	nextId += 1
	local duel: Duel = {
		id = nextId,
		slot = slot,
		arena = arena,
		a = a,
		b = a, -- (replaced just below)
		state = "Countdown",
		fightStartedAt = 0,
		suddenDeath = false,
		winner = nil,
	}
	local b: Combatant?
	if bPlayer then
		b = Combatants.forPlayer(bPlayer)
	else
		local names = Config.Bots.Names
		b = BotService.spawn(names[rng:NextInteger(1, #names)], arena.spawns[2])
		if b then
			WardrobeService.dressBot(b, rng)
			if DuelService.watchCharacter then
				DuelService.watchCharacter(b, b.model :: Model)
			end
		end
	end
	if not b then
		return nil
	end
	duel.b = b
	busy[slot] = duel
	-- flags first: spawning yields, and being in a duel keeps them out of the queues meanwhile
	prepare(a, duel)
	prepare(b, duel)
	local seed = rng:NextInteger(1, 1e9)
	for i, c in both(duel) do
		if c.player and DuelService.spawnPlayer then
			DuelService.spawnPlayer(c.player, arena.spawns[i])
		end
		QueueService.backOfLine(c)
		giveLoadout(c, seed)
		StatusService.updateMovement(c)
		if DuelService.setFlags then
			DuelService.setFlags(c)
		end
	end
	local fightAt = now() + D.Countdown
	for _, c in both(duel) do
		setDuelAttributes(c, duel, fightAt)
	end
	banner(duel, { title = "🤺 " .. a.name .. "  vs  " .. b.name, subtitle = "One spell, one potion. Get ready..." })
	task.spawn(DuelService.run, duel)
	return duel
end

-- (read through a function so the type checker doesn't pin the state to what it last saw)
local function stateOf(duel: Duel): string
	return duel.state
end

-- The duel's clock: countdown, fight, sudden death, time limit.
function DuelService.run(duel: Duel)
	local fightAt = now() + D.Countdown
	while now() < fightAt and stateOf(duel) == "Countdown" do
		task.wait(0.1)
	end
	if stateOf(duel) ~= "Countdown" then
		return
	end
	duel.state = "Fight"
	duel.fightStartedAt = now()
	for _, c in both(duel) do
		c.locked = false
		StatusService.updateMovement(c)
		setDuelAttributes(c, duel, duel.fightStartedAt + D.SuddenDeathAt)
	end
	banner(duel, { title = "FIGHT!", subtitle = "Sudden death in " .. D.SuddenDeathAt .. " seconds" })
	FX.to(duel.a.player, "Gong")
	FX.to(duel.b.player, "Gong")
	local suddenDeath = false
	local acc = 0
	local last = now()
	while stateOf(duel) == "Fight" do
		task.wait(0.25)
		local t = now()
		local elapsed = t - duel.fightStartedAt
		acc += t - last
		last = t
		-- anyone who falls off the platform is out
		for _, c in both(duel) do
			local root = c.root
			if root and c.humanoid and (root :: BasePart).Position.Y < duel.arena.floorY - 40 then
				(c.humanoid :: Humanoid).Health = 0
			end
		end
		if not suddenDeath and elapsed >= D.SuddenDeathAt then
			suddenDeath = true
			duel.suddenDeath = true
			banner(duel, { title = "Sudden death", subtitle = "The arena burns both of you. Finish it!" })
			for _, c in both(duel) do
				setDuelAttributes(c, duel, duel.fightStartedAt + D.TimeLimit)
			end
		end
		if suddenDeath then
			while acc >= 0.5 do
				acc -= 0.5
				for _, c in both(duel) do
					if c.alive and Combatants.isActive(c) then
						DamageService.apply(c, D.SuddenDeathDps * 0.5, { isStorm = true, element = "Fire" })
					end
				end
			end
		else
			acc = 0
		end
		if elapsed >= D.TimeLimit and stateOf(duel) == "Fight" then
			local ha = if duel.a.humanoid then (duel.a.humanoid :: Humanoid).Health else 0
			local hb = if duel.b.humanoid then (duel.b.humanoid :: Humanoid).Health else 0
			if math.abs(ha - hb) < 0.5 then
				finish(duel, nil, "time ran out with nobody ahead")
			else
				finish(duel, if ha > hb then duel.a else duel.b, "more health left when time ran out")
			end
		end
	end
end

-- Pairs up whoever is waiting (or gives a lonely duelist a bot).
function DuelService.matchmake()
	local waiting = QueueService.waiting("Duel")
	local t = now()
	for player in aloneSince do
		if not table.find(waiting, player) then
			aloneSince[player] = nil
		end
	end
	while #waiting >= 2 and freeSlot() do
		local a = table.remove(waiting, 1) :: Player
		local b = table.remove(waiting, 1) :: Player
		aloneSince[a] = nil
		aloneSince[b] = nil
		DuelService.start(a, b)
	end
	if #waiting == 1 and freeSlot() then
		local p = waiting[1]
		aloneSince[p] = aloneSince[p] or t
		if Config.Bots.Enabled and t - aloneSince[p] >= D.BotAfter then
			aloneSince[p] = nil
			FX.announceTo(p, "Toast", { text = "No challenger yet, so a bot steps into the arena" })
			DuelService.start(p, nil)
		end
	end
end

function DuelService.active(): { Duel }
	local list = {}
	for _, duel in busy do
		table.insert(list, duel)
	end
	return list
end

function DuelService.init()
	-- (a duelist leaving mid-fight is handled by MatchService, which calls onLeave)
	Players.PlayerRemoving:Connect(function(player)
		aloneSince[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			local ok, err = pcall(DuelService.matchmake)
			if not ok then
				warn("[Duel] matchmaking failed: " .. tostring(err))
			end
		end
	end)
end

return DuelService
