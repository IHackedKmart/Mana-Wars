-- The queue between the hub and a match.
--   * Everyone spawns in the hub (Arcanum Plaza) and can practise and hang out there for as long
--     as they like.
--   * Walking through the hub portal (or pressing "Join Game") joins the queue and moves you to the
--     library, where the map vote happens. Only queued players are put into matches.
--   * The library's portal (or "Leave queue") takes you back to the hub, any time you're not
--     fighting.
-- Also keeps the hub's "Next Match" board up to date.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Remotes = require(Shared.Remotes)
local Combatants = require(script.Parent.Combatants)
local GameState = require(script.Parent.GameState)
local MapService = require(script.Parent.MapService)
local VoteService = require(script.Parent.VoteService)
local Events = require(script.Parent.Events)

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

-- Queued players ready for the next match (not already fighting in one), first in line first.
function QueueService.waiting(): { Player }
	local list = {}
	local order: { [Player]: number } = {}
	for _, player in Players:GetPlayers() do
		local c = Combatants.forPlayer(player)
		if c and c.queued and not c.inMatch and player.Character then
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

local function setQueued(c: Combatant, queued: boolean)
	c.queued = queued
	if queued then
		c.queuedAt = workspace:GetServerTimeNow()
	end
	if c.player then
		c.player:SetAttribute("Queued", queued)
		if not queued then
			VoteService.withdraw(c.player)
		end
	end
	GameState.setPublic("QueueCount", #QueueService.waiting())
end

function QueueService.join(player: Player): (boolean, string)
	local c = Combatants.forPlayer(player)
	if not c then
		return false, "Still loading, try again in a moment"
	end
	if c.queued then
		return true, "You're already in the queue"
	end
	setQueued(c, true)
	moveToRest(c)
	Events.fire("QueueJoined", player)
	return true, "You joined the queue! Vote for the next map."
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
	local waiting = #QueueService.waiting()
	local left = (ReplicatedStorage:GetAttribute("PhaseEndsAt") or 0) - workspace:GetServerTimeNow()
	local map = tostring(ReplicatedStorage:GetAttribute("MapName") or "the island")
	local alive = tonumber(ReplicatedStorage:GetAttribute("AliveCount")) or 0
	if phase == "Voting" then
		return string.format(
			"<b>Map vote: %s left</b>\n%s in the queue\nJoin now to play this round!",
			fmtTime(left),
			plural(waiting, "mage")
		)
	elseif phase == "Loading" then
		return string.format(
			"<b>Building %s...</b>\nThe match is about to start\n%s waiting for the next round",
			tostring(ReplicatedStorage:GetAttribute("NextMapName") or map),
			plural(waiting, "mage")
		)
	elseif phase == "Countdown" or phase == "Grace" or phase == "Battle" then
		return string.format(
			"<b>Match in progress</b> on %s\n%s still standing\n%s queued for the next one",
			map,
			plural(alive, "mage"),
			plural(waiting, "mage")
		)
	elseif phase == "Ended" then
		return "<b>Match over!</b>\nThe next vote starts in a moment\nJoin the queue to play"
	end
	return "<b>No match yet</b>\nWalk through the portal\nto start one!"
end

function QueueService.init()
	Remotes.func("QueueAction").OnServerInvoke = function(player: Player, action: any)
		if action == "Join" then
			return QueueService.join(player)
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
				QueueService.join(player)
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
			if t - (lastTouch[player] or 0) < 2 then
				return
			end
			lastTouch[player] = t
			QueueService.join(player)
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
			GameState.setPublic("QueueCount", #QueueService.waiting())
			if hub then
				hub.boardText.Text = QueueService.boardText()
			end
			task.wait(0.5)
		end
	end)
end

return QueueService
