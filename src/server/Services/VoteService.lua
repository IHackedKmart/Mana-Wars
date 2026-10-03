-- The map vote held in the lobby before every match.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local MapDefs = require(script.Parent.Parent.Map.MapDefs)

type MapDef = MapDefs.MapDef

local VoteService = {}

local stateEvent = Remotes.event("VoteState")
local options: { MapDef } = {}
local votes: { [Player]: string } = {}
local endsAt = 0
local open = false

local function counts(): { [string]: number }
	local out: { [string]: number } = {}
	for _, def in options do
		out[def.id] = 0
	end
	for _, id in votes do
		out[id] = (out[id] or 0) + 1
	end
	return out
end

-- Everything the vote screen shows. `options` is nil once voting has closed.
function VoteService.payload(): { [string]: any }
	if not open then
		return { open = false }
	end
	local summaries = {}
	for _, def in options do
		table.insert(summaries, MapDefs.summary(def))
	end
	return { open = true, options = summaries, counts = counts(), endsAt = endsAt }
end

local function broadcast()
	stateEvent:FireAllClients(VoteService.payload())
end

-- Opens a vote between a few random maps (avoiding the one just played when possible).
function VoteService.begin(rng: Random, closesAt: number, lastMapId: string?): { MapDef }
	local pool = {}
	for _, def in MapDefs.List do
		if def.id ~= lastMapId or #MapDefs.List <= Config.Match.VoteOptions then
			table.insert(pool, def)
		end
	end
	for i = #pool, 2, -1 do
		local j = rng:NextInteger(1, i)
		pool[i], pool[j] = pool[j], pool[i]
	end
	options = {}
	for i = 1, math.min(Config.Match.VoteOptions, #pool) do
		options[i] = pool[i]
	end
	table.clear(votes)
	endsAt = closesAt
	open = true
	broadcast()
	return options
end

-- Closes the vote and returns the winner (ties are broken randomly).
function VoteService.finish(rng: Random): MapDef
	local tally = counts()
	local best, bestCount = {}, -1
	for _, def in options do
		local n = tally[def.id] or 0
		if n > bestCount then
			best, bestCount = { def }, n
		elseif n == bestCount then
			table.insert(best, def)
		end
	end
	open = false
	broadcast()
	if #best == 0 then
		return MapDefs.List[1]
	end
	return best[rng:NextInteger(1, #best)]
end

function VoteService.vote(player: Player, mapId: any): (boolean, string?)
	if not open then
		return false, "Voting is closed"
	end
	if type(mapId) ~= "string" then
		return false, "Bad map"
	end
	for _, def in options do
		if def.id == mapId then
			votes[player] = mapId
			broadcast()
			return true, "Voted for " .. def.name
		end
	end
	return false, "That map isn't on the ballot"
end

function VoteService.init()
	Remotes.func("VoteAction").OnServerInvoke = function(player, action, mapId)
		if action == "Vote" then
			return VoteService.vote(player, mapId)
		end
		return false, "Unknown action"
	end
	Players.PlayerAdded:Connect(function(player)
		stateEvent:FireClient(player, VoteService.payload())
	end)
	Players.PlayerRemoving:Connect(function(player)
		if votes[player] then
			votes[player] = nil
			if open then
				broadcast()
			end
		end
	end)
end

return VoteService
