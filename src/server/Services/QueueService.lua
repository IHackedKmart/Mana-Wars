-- The queue between the hub and a match.
--   * Everyone spawns in the hub (Arcanum Plaza) and can practise and hang out there for as long
--     as they like.
--   * Walking through the hub portal (or pressing "Play") opens the game mode menu. Picking a mode
--     joins that mode's queue and moves you to the library, where Survival Games' map vote happens.
--     Only queued players are put into matches (or duels).
--   * The library's portal (or "Leave queue") takes you back to the hub, any time you're not
--     fighting.
-- Also keeps the hub's "Next Match" board up to date.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Remotes = require(Shared.Remotes)
local Modes = require(Shared.Modes)
local Combatants = require(script.Parent.Combatants)
local GameState = require(script.Parent.GameState)
local MapService = require(script.Parent.MapService)
local VoteService = require(script.Parent.VoteService)
local Events = require(script.Parent.Events)
local FX = require(script.Parent.FX)

type Combatant = Combatants.Combatant

local QueueService = {}

local rng = Random.new()

-- Where a player who isn't fighting belongs: the library if queued, otherwise the hub.
function QueueService.restCFrame(c: Combatant): CFrame
	local base = if c.queued then MapService.lobbySpawn else MapService.hubSpawn
	return base * CFrame.new(rng:NextNumber(-8, 8), 0, rng:NextNumber(-5, 5))
end

local function moveToRest(c: Combatant)
	local character = c.player and c.player.Character
	if character and not c.inMatch then
		character:PivotTo(QueueService.restCFrame(c))
	end
end

-- Queued players ready for a match (not already fighting in one), first in line first. With a
-- mode, only those queued for it.
function QueueService.waiting(mode: string?): { Player }
	local list = {}
	local order: { [Player]: number } = {}
	for _, player in Players:GetPlayers() do
		local c = Combatants.forPlayer(player)
		if c and c.queued and not c.inMatch and player.Character and (mode == nil or c.queuedMode == mode) then
			table.insert(list, player)
			order[player] = c.queuedAt
		end
	end
	table.sort(list, function(a, b)
		return order[a] < order[b]
	end)
	return list
end

-- Someone who just got a match goes to the back of the line (matters when more than 12 are queued).
function QueueService.backOfLine(c: Combatant)
	c.queuedAt = workspace:GetServerTimeNow()
end

local function publishCounts()
	GameState.setPublic("QueueCount", #QueueService.waiting())
	for _, mode in Modes.List do
		GameState.setPublic("Queue" .. mode.id, #QueueService.waiting(mode.id))
	end
end

local function setQueued(c: Combatant, queued: boolean, mode: string?)
	c.queued = queued
	if queued then
		c.queuedAt = workspace:GetServerTimeNow()
		c.queuedMode = mode or c.queuedMode
	end
	if c.player then
		c.player:SetAttribute("Queued", queued)
		c.player:SetAttribute("QueuedMode", if queued then c.queuedMode else nil)
		if not queued or c.queuedMode ~= "Survival" then
			VoteService.withdraw(c.player)
		end
	end
	publishCounts()
end

local JOINED = {
	Survival = "You joined Survival Games! Vote for the next map.",
	Duel = "Looking for a duel opponent...",
	Royale = "You joined the Battle Royale! The carpet leaves soon.",
}

-- Joins (or switches to) a game mode's queue.
function QueueService.join(player: Player, mode: any): (boolean, string)
	local c = Combatants.forPlayer(player)
	if not c then
		return false, "Still loading, try again in a moment"
	end
	local modeId = if Modes.isValid(mode) then mode :: string else Modes.Default
	if c.inMatch then
		return false, "Finish your match first"
	end
	if c.queued and c.queuedMode == modeId then
		return true, "You're already queued for " .. Modes.ById[modeId].name
	end
	local wasQueued = c.queued
	setQueued(c, true, modeId)
	moveToRest(c)
	if not wasQueued then
		Events.fire("QueueJoined", player)
	end
	Events.fire("ModeQueued", player, modeId)
	return true, JOINED[modeId] or "Queued"
end

-- Asks this player's screen to show the game mode menu (the portal does this).
function QueueService.offerModes(player: Player)
	FX.announceTo(player, "PlayMenu", {})
end

function QueueService.leave(player: Player): (boolean, string)
	local c = Combatants.forPlayer(player)
	if not c then
		return false, "Still loading, try again in a moment"
	end
	if c.inMatch then
		return false, "You can't leave in the middle of a match"
	end
	if not c.queued then
		return true, "You're not in the queue"
	end
	setQueued(c, false)
	moveToRest(c)
	return true, "Back to Arcanum Plaza"
end

-- After a match (when Config.Queue.StayQueuedAfterMatch is off): out of the queue, no teleport.
function QueueService.dequeue(c: Combatant)
	if c.queued then
		setQueued(c, false)
	end
end

local function fmtTime(seconds: number): string
	seconds = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

local function plural(n: number, word: string): string
	return n .. " " .. word .. (if n == 1 then "" else "s")
end

-- What the hub's "Next Match" board says right now.
function QueueService.boardText(): string
	local phase = GameState.phase
	local left = (ReplicatedStorage:GetAttribute("PhaseEndsAt") or 0) - workspace:GetServerTimeNow()
	local map = tostring(ReplicatedStorage:GetAttribute("MapName") or "the island")
	local alive = tonumber(ReplicatedStorage:GetAttribute("AliveCount")) or 0
	local mode = Modes.ById[GameState.mode] or Modes.ById[Modes.Default]
	local queues = string.format(
		"Queued: ⚔️ %d  ·  🧞 %d  ·  🤺 %d",
		#QueueService.waiting("Survival"),
		#QueueService.waiting("Royale"),
		#QueueService.waiting("Duel")
	)
	local headline
	if phase == "Voting" then
		headline = string.format("<b>Survival Games map vote: %s left</b>", fmtTime(left))
	elseif phase == "Gathering" then
		headline = string.format("<b>Battle Royale: the carpet leaves in %s</b>", fmtTime(left))
	elseif phase == "Loading" then
		headline =
			string.format("<b>Building %s...</b>", tostring(ReplicatedStorage:GetAttribute("NextMapName") or map))
	elseif phase == "Countdown" or phase == "Grace" or phase == "Carpet" or phase == "Battle" then
		headline = string.format(
			"<b>%s %s in progress</b>  ·  %s still standing",
			mode.icon,
			mode.name,
			plural(alive, "mage")
		)
	elseif phase == "Ended" then
		headline = "<b>Match over!</b> The next one starts in a moment"
	else
		headline = "<b>No match yet</b>: walk through the portal to play"
	end
	return headline .. "\n" .. queues .. "\nDuels start as soon as two mages are queued"
end

function QueueService.init()
	Remotes.func("QueueAction").OnServerInvoke = function(player: Player, action: any, mode: any)
		if action == "Join" then
			return QueueService.join(player, mode)
		elseif action == "Leave" then
			return QueueService.leave(player)
		end
		return false, "Unknown action"
	end

	-- the portals: walk into (or use) the hub portal to join; use the library's to leave
	local hub = MapService.hub
	if hub then
		local portal = hub.joinPortal
		local prompt = portal:FindFirstChildOfClass("ProximityPrompt")
		if prompt then
			prompt.Triggered:Connect(function(player)
				QueueService.offerModes(player)
			end)
		end
		local lastTouch: { [Player]: number } = setmetatable({}, { __mode = "k" }) :: any
		portal.Touched:Connect(function(hit: BasePart)
			local character = hit.Parent
			local player = character and Players:GetPlayerFromCharacter(character)
			if not player then
				return
			end
			local t = os.clock()
			if t - (lastTouch[player] or 0) < 4 then
				return
			end
			lastTouch[player] = t
			local c = Combatants.forPlayer(player)
			if c and not c.queued then
				QueueService.offerModes(player)
			end
		end)
	end
	local lobby = MapService.lobby
	if lobby then
		local prompt = lobby.exitPortal:FindFirstChildOfClass("ProximityPrompt")
		if prompt then
			prompt.Triggered:Connect(function(player)
				QueueService.leave(player)
			end)
		end
	end

	-- keep the queue count and the hub board fresh
	task.spawn(function()
		while true do
			publishCounts()
			if hub then
				hub.boardText.Text = QueueService.boardText()
			end
			task.wait(0.5)
		end
	end)
end

return QueueService
