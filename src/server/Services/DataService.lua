-- Player profiles saved with DataStores: lifetime stats (wins / kills / matches, shown on the
-- leaderboard), Enchanted Coins, and the wardrobe (cosmetic parts, crafted garments, familiars,
-- what's worn, and items currently up for auction).
-- * Session lock: a profile is claimed by one server at a time (stops duplicating items by
--   joining two servers at once). A claim older than 90s is considered abandoned.
-- * Saved on leave, on shutdown, after matches, and every minute while anything changed.
-- Everything is wrapped in pcall: in Studio without API access the game still runs (unsaved).

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Events = require(script.Parent.Events)

local DataService = {}

export type Wardrobe = {
	parts: { any },
	garments: { any },
	familiars: { any },
	equipped: { [string]: string }, -- "Robe" / "Hat" -> garment uid, "Familiar" -> familiar uid
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
	counters: { [string]: number }, -- lifetime counts for achievements (chests, forged, coffers...)
	achievements: { [string]: number }, -- achievement id -> when it was unlocked (os.time)
	daily: { last: number, streak: number, best: number }, -- daily reward: last day claimed (UTC day number)
	onboarding: { [string]: boolean }, -- analytics onboarding steps already logged
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
		wardrobe = { parts = {}, garments = {}, familiars = {}, equipped = {}, listings = {} },
		counters = {},
		achievements = {},
		daily = { last = 0, streak = 0, best = 0 },
		onboarding = {},
	}
end

-- A table of string -> number (or boolean) from saved data, dropping anything malformed.
local function cleanMap(data: any, valueType: string): { [string]: any }
	local out = {}
	if type(data) == "table" then
		for k, v in data do
			if type(k) == "string" and type(v) == valueType then
				out[k] = v
			end
		end
	end
	return out
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
	p.counters = cleanMap(data.counters, "number")
	p.achievements = cleanMap(data.achievements, "number")
	p.onboarding = cleanMap(data.onboarding, "boolean")
	if type(data.daily) == "table" then
		p.daily.last = tonumber(data.daily.last) or 0
		p.daily.streak = tonumber(data.daily.streak) or 0
		p.daily.best = tonumber(data.daily.best) or 0
	end
	local w = data.wardrobe
	if type(w) == "table" then
		p.wardrobe.parts = if type(w.parts) == "table" then w.parts else {}
		p.wardrobe.garments = if type(w.garments) == "table" then w.garments else {}
		p.wardrobe.familiars = if type(w.familiars) == "table" then w.familiars else {}
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
		counters = p.counters,
		achievements = p.achievements,
		daily = p.daily,
		onboarding = p.onboarding,
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
	Events.fire("Kill", player)
end

function DataService.addWin(player: Player)
	bump(player, "wins")
	Events.fire("Win", player)
end

function DataService.addMatch(player: Player)
	bump(player, "matches")
end

-- Adds to one of the lifetime counters achievements look at ("chests", "forged"...).
function DataService.count(player: Player, counter: string, amount: number?)
	local profile = cache[player]
	if not profile then
		return
	end
	profile.counters[counter] = (profile.counters[counter] or 0) + (amount or 1)
	dirty[player] = true
end

-- The name to use for a DataStore / MemoryStore. Studio play tests get their own copies
-- (Config.Dev.SeparateStudioData) so coins and items handed out while testing stay out of the live game.
function DataService.storeName(base: string): string
	local studio = false
	pcall(function()
		studio = RunService:IsStudio()
	end)
	if studio and Config.Dev.SeparateStudioData then
		return base .. "_Studio"
	end
	return base
end

-- Wipes a profile back to a brand new player's (dev tool; listings on the market are kept).
function DataService.reset(player: Player)
	local profile = cache[player]
	if not profile then
		return
	end
	local fresh = newProfile()
	fresh.wardrobe.listings = profile.wardrobe.listings
	for k, v in fresh do
		(profile :: any)[k] = v
	end
	leaderstats(player, profile)
	player:SetAttribute("TutorialDone", nil)
	dirty[player] = true
end

function DataService.init()
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(DataService.storeName(Config.DataStoreName))
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
			Events.fire("TutorialDone", player)
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
