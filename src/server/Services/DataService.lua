-- Lifetime stats (wins / kills / matches) saved with DataStores and shown on the leaderboard.
-- Everything is wrapped in pcall: in Studio without API access the game still runs.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local DataService = {}

type Stats = { wins: number, kills: number, matches: number, tutorial: boolean }

local cache: { [Player]: Stats } = {}
local store: DataStore? = nil

local function key(player: Player): string
	return "u" .. player.UserId
end

local function leaderstats(player: Player, stats: Stats)
	local folder = player:FindFirstChild("leaderstats")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "leaderstats"
		folder.Parent = player
	end
	for _, name in { "Wins", "Kills" } do
		local value = folder:FindFirstChild(name) :: IntValue?
		if not value then
			local v = Instance.new("IntValue")
			v.Name = name
			v.Parent = folder
			value = v
		end
		(value :: IntValue).Value = if name == "Wins" then stats.wins else stats.kills
	end
end

function DataService.load(player: Player)
	local stats: Stats = { wins = 0, kills = 0, matches = 0, tutorial = false }
	if store then
		local ok, data = pcall(function()
			return (store :: DataStore):GetAsync(key(player))
		end)
		if ok and type(data) == "table" then
			stats.wins = tonumber(data.wins) or 0
			stats.kills = tonumber(data.kills) or 0
			stats.matches = tonumber(data.matches) or 0
			stats.tutorial = data.tutorial == true
		end
	end
	cache[player] = stats
	leaderstats(player, stats)
	if stats.tutorial then
		player:SetAttribute("TutorialDone", true)
	end
	player:SetAttribute("StatsLoaded", true)
end

function DataService.save(player: Player)
	local stats = cache[player]
	if not stats or not store then
		return
	end
	local ok, err = pcall(function()
		(store :: DataStore):UpdateAsync(key(player), function()
			return { wins = stats.wins, kills = stats.kills, matches = stats.matches, tutorial = stats.tutorial }
		end)
	end)
	if not ok then
		warn("[Data] save failed for " .. player.Name .. ": " .. tostring(err))
	end
end

local function bump(player: Player, field: string)
	local stats = cache[player]
	if not stats then
		return
	end
	(stats :: any)[field] += 1
	leaderstats(player, stats)
end

function DataService.addKill(player: Player)
	bump(player, "kills")
end

function DataService.addWin(player: Player)
	bump(player, "wins")
end

function DataService.addMatch(player: Player)
	bump(player, "matches")
end

function DataService.init()
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(Config.DataStoreName)
	end)
	if ok then
		store = result
	else
		warn("[Data] DataStores unavailable, stats will not be saved: " .. tostring(result))
	end
	Remotes.event("TutorialDone").OnServerEvent:Connect(function(player)
		player:SetAttribute("TutorialDone", true)
		local stats = cache[player]
		if stats and not stats.tutorial then
			stats.tutorial = true
			task.spawn(DataService.save, player)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		DataService.save(player)
		cache[player] = nil
	end)
	game:BindToClose(function()
		for _, player in Players:GetPlayers() do
			task.spawn(DataService.save, player)
		end
		task.wait(2)
	end)
end

return DataService
