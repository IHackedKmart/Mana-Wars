-- Achievements (defined in Shared/Achievements): counts what players do (through the Events bus),
-- unlocks achievements once their stat reaches the goal, pays out their Enchanted Coins, awards the
-- matching Roblox badge if one is set up (Config.Achievements.BadgeIds), and keeps the client's
-- Achievements window up to date. Stats players already had count too, so veterans unlock theirs
-- the first time they join after this was added.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Achievements = require(Shared.Achievements)
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local DataService = require(script.Parent.DataService)
local WardrobeService = require(script.Parent.WardrobeService)
local DailyRewardService = require(script.Parent.DailyRewardService)
local Events = require(script.Parent.Events)
local FX = require(script.Parent.FX)

type Achievement = Achievements.Achievement

local AchievementService = {}

local updated = Remotes.event("AchievementsUpdated")
local badges: BadgeService? = nil

-- How far along a player is on one of the stats achievements count.
function AchievementService.statOf(profile: DataService.Profile, stat: string): number
	if stat == "wins" then
		return profile.wins
	elseif stat == "kills" then
		return profile.kills
	elseif stat == "matches" then
		return profile.matches
	elseif stat == "tutorial" then
		return if profile.tutorial then 1 else 0
	elseif stat == "streak" then
		return profile.daily.best
	end
	return profile.counters[stat] or 0
end

-- Everything the Achievements window shows.
function AchievementService.snapshot(player: Player): { [string]: any }?
	local profile = DataService.profile(player)
	if not profile then
		return nil
	end
	local stats = {}
	for _, stat in Achievements.Stats do
		stats[stat] = AchievementService.statOf(profile, stat)
	end
	local day = DailyRewardService.today()
	return {
		stats = stats,
		unlocked = table.clone(profile.achievements),
		daily = {
			streak = profile.daily.streak,
			best = profile.daily.best,
			claimedToday = profile.daily.last >= day,
			coins = Config.Rewards.DailyCoins,
			nextIn = math.max(0, (os.time() // 86400 + 1) * 86400 - os.time()), -- seconds until midnight UTC
		},
	}
end

function AchievementService.sync(player: Player)
	local snapshot = AchievementService.snapshot(player)
	if snapshot then
		updated:FireClient(player, snapshot)
	end
end

local function awardBadge(player: Player, id: string)
	local badgeId = Config.Achievements.BadgeIds[id]
	if badges and type(badgeId) == "number" and badgeId > 0 then
		local service = badges :: BadgeService
		local ok, err = pcall(function()
			service:AwardBadge(player.UserId, badgeId)
		end)
		if not ok then
			warn("[Achievements] couldn't award badge " .. id .. ": " .. tostring(err))
		end
	end
end

-- Unlocks (and pays for) every achievement the player has reached, then updates their window.
-- Returns the achievements unlocked just now.
function AchievementService.check(player: Player): { Achievement }
	local profile = DataService.profile(player)
	if not profile then
		return {}
	end
	local newly: { Achievement } = {}
	for _, a in Achievements.List do
		if not profile.achievements[a.id] and AchievementService.statOf(profile, a.stat) >= a.goal then
			profile.achievements[a.id] = os.time()
			table.insert(newly, a)
		end
	end
	if #newly > 0 then
		local coins = 0
		for _, a in newly do
			coins += a.reward
			awardBadge(player, a.id)
			Events.fire("AchievementUnlocked", player, a)
		end
		WardrobeService.addCoins(player, coins, nil, { type = "Gameplay", sku = "Achievement" })
		local text = if #newly == 1
			then string.format("🏆 Achievement unlocked: %s %s  (+%d 💰)", newly[1].icon, newly[1].name, coins)
			else string.format("🏆 %d achievements unlocked!  (+%d 💰)", #newly, coins)
		FX.announceTo(player, "Toast", { text = text })
		DataService.markDirty(player)
	end
	AchievementService.sync(player)
	return newly
end

-- Adds to a lifetime counter ("chests", "forged"...) and checks for unlocks.
function AchievementService.count(player: Player, counter: string, amount: number?)
	DataService.count(player, counter, amount)
	AchievementService.check(player)
end

function AchievementService.init()
	local ok, service = pcall(function()
		return game:GetService("BadgeService")
	end)
	badges = if ok then service else nil

	local function check(player: Player)
		AchievementService.check(player)
	end
	for _, name in { "Kill", "Win", "TutorialDone", "DailyClaimed" } do
		Events.on(name, check)
	end
	Events.on("MatchFinished", function(player: Player, place: number, ...: any)
		local mode = select(5, ...) -- (after outOf, kills, mapId and classId)
		if place == 1 and mode == "Royale" then
			DataService.count(player, "royaleWins")
		end
		if place <= 3 then
			AchievementService.count(player, "top3")
		else
			AchievementService.check(player)
		end
	end)
	Events.on("DuelFinished", function(player: Player, won: boolean)
		if won then
			AchievementService.count(player, "duelWins")
		end
	end)
	local counters = {
		ChestOpened = "chests",
		Forged = "forged",
		CofferOpened = "coffers",
		Crafted = "crafted",
		AuctionSold = "sold",
	}
	for event, counter in counters do
		Events.on(event, function(player: Player)
			AchievementService.count(player, counter)
		end)
	end
	Events.on("FamiliarFound", function(player: Player, familiar: any)
		DataService.count(player, "familiars")
		if type(familiar) == "table" and familiar.shiny then
			DataService.count(player, "shiny")
		end
		AchievementService.check(player)
	end)

	DataService.onLoaded(function(player, profile)
		AchievementService.check(player)
		-- badges set up after players unlocked the achievement: hand them out now
		for id in profile.achievements do
			awardBadge(player, id)
		end
	end)
end

return AchievementService
