-- Player profiles saved with DataStores: lifetime stats (wins / kills / matches, shown on the
-- leaderboard), Enchanted Coins, and the wardrobe (cosmetic parts, crafted garments, what's worn,
-- and items currently up for auction).
-- * Session lock: a profile is claimed by one server at a time (stops duplicating items by
--   joining two servers at once). A claim older than 90s is considered abandoned.
-- * Saved on leave, on shutdown, after matches, and every minute while anything changed.
-- Everything is wrapped in pcall: in Studio without API access the game still runs (unsaved).

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local DataService = {}

export type Wardrobe = {
	parts: { any },
	garments: { any },
	equipped: { [string]: string }, -- "Robe" / "Hat" -> garment uid
	listings: { [string]: any }, -- auction listing id -> { item, kind, price, expires }
}

export type Profile = {
	wins: number,
	kills: number,
	matches: number,
	tutorial: boolean,
	coins: number,
	starter: boolean, -- has received the starter outfit
	wardrobe: Wardrobe,
}

local cache: { [Player]: Profile } = {}
local dirty: { [Player]: boolean } = {}
local loadedCallbacks: { (Player, Profile) -> () } = {}
local store: DataStore? = nil

local SESSION_TIMEOUT = 90
local AUTOSAVE = 60

local function key(player: Player): string
	return "u" .. player.UserId
end

local function jobId(): string
	local ok, id = pcall(function()
		return game.JobId
	end)
	return if ok and type(id) == "string" then id else ""
end

local function newProfile(): Profile
	return {
		wins = 0,
		kills = 0,
		matches = 0,
		tutorial = false,
		coins = 0,
		starter = false,
		wardrobe = { parts = {}, garments = {}, equipped = {}, listings = {} },
	}
end

local function fromSaved(data: any): Profile
	local p = newProfile()
	if type(data) ~= "table" then
		return p
	end
	p.wins = tonumber(data.wins) or 0
	p.kills = tonumber(data.kills) or 0
	p.matches = tonumber(data.matches) or 0
	p.tutorial = data.tutorial == true
	p.coins = math.max(0, math.floor(tonumber(data.coins) or 0))
	p.starter = data.starter == true
	local w = data.wardrobe
	if type(w) == "table" then
		p.wardrobe.parts = if type(w.parts) == "table" then w.parts else {}
		p.wardrobe.garments = if type(w.garments) == "table" then w.garments else {}
		p.wardrobe.equipped = if type(w.equipped) == "table" then w.equipped else {}
		p.wardrobe.listings = if type(w.listings) == "table" then w.listings else {}
	end
	return p
end

local function toSaved(p: Profile, session: { job: string, t: number }?): { [string]: any }
	return {
		wins = p.wins,
		kills = p.kills,
		matches = p.matches,
		tutorial = p.tutorial,
		coins = p.coins,
		starter = p.starter,
		wardrobe = p.wardrobe,
		session = session,
	}
end

local function leaderstats(player: Player, stats: Profile)
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

-- Claims the profile for this server and returns what was saved (nil if it couldn't be read).
local function claim(player: Player): (boolean, any)
	local s = store :: DataStore
	for attempt = 1, 6 do
		local locked = false
		local saved: any = nil
		local ok, err = pcall(function()
			s:UpdateAsync(key(player), function(data)
				local session = type(data) == "table" and data.session or nil
				local fresh = session
					and session.job ~= jobId()
					and os.time() - (tonumber(session.t) or 0) < SESSION_TIMEOUT
				if fresh and attempt < 6 then
					locked = true
					return nil -- leave it alone, try again shortly
				end
				local out = if type(data) == "table" then data else {}
				out.session = { job = jobId(), t = os.time() }
				saved = out
				return out
			end)
		end)
		if not ok then
			warn("[Data] couldn't load " .. player.Name .. ": " .. tostring(err))
			return false, nil
		end
		if not locked then
			return true, saved
		end
		task.wait(3) -- another server still has it (they probably just switched servers)
	end
	return false, nil
end

function DataService.load(player: Player)
	local profile = newProfile()
	if store then
		local ok, saved = claim(player)
		if ok then
			profile = fromSaved(saved)
		end
	end
	if not player.Parent then
		return
	end
	cache[player] = profile
	leaderstats(player, profile)
	if profile.tutorial then
		player:SetAttribute("TutorialDone", true)
	end
	player:SetAttribute("StatsLoaded", true)
	for _, callback in loadedCallbacks do
		task.spawn(callback, player, profile)
	end
end

-- The live profile (nil until loaded). Change it, then call markDirty.
function DataService.profile(player: Player): Profile?
	return cache[player]
end

function DataService.markDirty(player: Player)
	dirty[player] = true
end

-- Runs `callback(player, profile)` whenever a profile finishes loading.
function DataService.onLoaded(callback: (Player, Profile) -> ())
	table.insert(loadedCallbacks, callback)
	for player, profile in cache do
		task.spawn(callback, player, profile)
	end
end

function DataService.save(player: Player, release: boolean?)
	local profile = cache[player]
	if not profile or not store then
		return
	end
	dirty[player] = nil
	local session = if release then nil else { job = jobId(), t = os.time() }
	local ok, err = pcall(function()
		(store :: DataStore):UpdateAsync(key(player), function(data)
			local current = type(data) == "table" and data.session or nil
			if current and current.job ~= jobId() and os.time() - (tonumber(current.t) or 0) < SESSION_TIMEOUT then
				-- someone else owns this profile now: don't overwrite their newer data
				return nil
			end
			return toSaved(profile, session)
		end)
	end)
	if not ok then
		warn("[Data] save failed for " .. player.Name .. ": " .. tostring(err))
		dirty[player] = true
	end
end

local function bump(player: Player, field: string)
	local stats = cache[player]
	if not stats then
		return
	end
	(stats :: any)[field] += 1
	leaderstats(player, stats)
	dirty[player] = true
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
		warn("[Data] DataStores unavailable, progress will not be saved: " .. tostring(result))
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
		DataService.save(player, true)
		cache[player] = nil
		dirty[player] = nil
	end)
	game:BindToClose(function()
		for _, player in Players:GetPlayers() do
			task.spawn(DataService.save, player, true)
		end
		task.wait(2)
	end)
	task.spawn(function()
		while true do
			task.wait(AUTOSAVE)
			for player in dirty do
				if player.Parent then
					task.spawn(DataService.save, player)
				end
			end
		end
	end)
end

return DataService
