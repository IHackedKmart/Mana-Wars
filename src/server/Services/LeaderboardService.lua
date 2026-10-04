-- The global leaderboard: everyone's lifetime wins and kills go into two OrderedDataStores (shared
-- by every server), and the Hall of Champions board in the Plaza shows the top players of each,
-- refreshed every Config.Leaderboard.RefreshSeconds. Scores are written after each match and when
-- a player leaves. (The player list's Wins / Kills columns are the per-player leaderstats.)

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local MapService = require(script.Parent.MapService)
local Events = require(script.Parent.Events)

local LeaderboardService = {}

export type Entry = { userId: number, name: string, value: number }

local STATS = { "wins", "kills" }
local stores: { [string]: OrderedDataStore } = {}
local pushed: { [Player]: { [string]: number } } = {}
local names: { [number]: string } = {}

LeaderboardService.top = { wins = {}, kills = {} } :: { [string]: { Entry } }
LeaderboardService.online = false

local function nameOf(userId: number): string
	local cached = names[userId]
	if cached then
		return cached
	end
	local okPlayer, player = pcall(function()
		return Players:GetPlayerByUserId(userId)
	end)
	local name = if okPlayer and player then player.Name else nil
	if not name then
		local ok, result = pcall(function()
			return Players:GetNameFromUserIdAsync(userId)
		end)
		name = if ok and type(result) == "string" then result else "Mage #" .. userId
	end
	names[userId] = name
	return name :: string
end

local MEDALS = { "🥇", "🥈", "🥉" }

local function escape(text: string): string
	return (string.gsub(text, "[<>&]", { ["<"] = "&lt;", [">"] = "&gt;", ["&"] = "&amp;" }))
end

-- The text of one column of the board.
function LeaderboardService.columnText(entries: { Entry }): string
	if #entries == 0 then
		return "<i>Nobody yet. Win a match to claim the first spot!</i>"
	end
	local lines = {}
	for rank, e in entries do
		local place = MEDALS[rank] or (rank .. ".")
		table.insert(
			lines,
			string.format('%s  %s  <font color="#FFD86B"><b>%d</b></font>', place, escape(e.name), e.value)
		)
	end
	return table.concat(lines, "\n")
end

local function render()
	local hub = MapService.hub
	if not hub then
		return
	end
	local board = hub.leaderboard
	if not LeaderboardService.online then
		board.wins.Text = "<i>Offline</i>"
		board.kills.Text = "<i>Offline</i>"
		board.footer.Text = "The leaderboard needs DataStores: turn on API access in Game Settings » Security"
		return
	end
	board.wins.Text = LeaderboardService.columnText(LeaderboardService.top.wins)
	board.kills.Text = LeaderboardService.columnText(LeaderboardService.top.kills)
	board.footer.Text = "All servers, all time  ·  updates every few minutes"
end

-- Writes a player's wins and kills to the global lists (only what changed since last time).
function LeaderboardService.push(player: Player)
	local profile = DataService.profile(player)
	if not profile or not LeaderboardService.online then
		return
	end
	local last = pushed[player] or {}
	pushed[player] = last
	for _, stat in STATS do
		local value = (profile :: any)[stat] :: number
		if value > 0 and last[stat] ~= value then
			local store = stores[stat]
			local ok, err = pcall(function()
				store:SetAsync("u" .. player.UserId, value)
			end)
			if ok then
				last[stat] = value
			else
				warn("[Leaderboard] couldn't save " .. stat .. " for " .. player.Name .. ": " .. tostring(err))
			end
		end
	end
end

-- Reads the top of each list and redraws the board.
function LeaderboardService.refresh()
	if LeaderboardService.online then
		for _, stat in STATS do
			local store = stores[stat]
			local ok, page = pcall(function()
				return store:GetSortedAsync(false, Config.Leaderboard.Size):GetCurrentPage()
			end)
			if ok and type(page) == "table" then
				local entries: { Entry } = {}
				for _, item in page do
					local userId = tonumber(string.match(tostring(item.key), "^u(%d+)$"))
					if userId then
						table.insert(entries, { userId = userId, name = nameOf(userId), value = item.value })
					end
				end
				LeaderboardService.top[stat] = entries
			end
		end
	end
	render()
end

function LeaderboardService.init()
	local ok, err = pcall(function()
		for _, stat in STATS do
			stores[stat] = DataStoreService:GetOrderedDataStore(DataService.storeName("Leaderboard_" .. stat))
		end
	end)
	LeaderboardService.online = ok and stores.wins ~= nil and stores.kills ~= nil
	if not LeaderboardService.online then
		warn("[Leaderboard] DataStores unavailable, the Hall of Champions stays empty: " .. tostring(err))
	end

	Events.on("MatchFinished", function(player: Player)
		LeaderboardService.push(player)
	end)
	DataService.onLoaded(function(player)
		LeaderboardService.push(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		LeaderboardService.push(player)
		pushed[player] = nil
	end)
	task.spawn(function()
		task.wait(5)
		while true do
			LeaderboardService.refresh()
			task.wait(Config.Leaderboard.RefreshSeconds)
		end
	end)
end

return LeaderboardService
