-- The daily login reward: the first time a player shows up each day (days start at midnight UTC)
-- they get Config.Rewards.DailyCoins Enchanted Coins. Coming back on consecutive days builds a
-- streak (the "Devoted" achievement wants 7). Players who stay online past midnight get the next
-- day's reward without rejoining.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local WardrobeService = require(script.Parent.WardrobeService)
local Events = require(script.Parent.Events)
local FX = require(script.Parent.FX)

local DailyRewardService = {}

local CHECK_EVERY = 60

-- Today's day number (UTC). Tests swap this out to travel in time.
DailyRewardService.today = function(): number
	return os.time() // 86400
end

-- Gives today's reward if the player hasn't had it yet. Returns whether it was given.
function DailyRewardService.claim(player: Player): boolean
	local profile = DataService.profile(player)
	if not profile then
		return false
	end
	local d = profile.daily
	local day = DailyRewardService.today()
	if d.last >= day then
		return false
	end
	d.streak = if d.last == day - 1 then d.streak + 1 else 1
	d.best = math.max(d.best, d.streak)
	d.last = day
	local coins = Config.Rewards.DailyCoins
	WardrobeService.addCoins(player, coins, nil, { type = "TimedReward", sku = "DailyLogin" })
	FX.announceTo(player, "Toast", {
		text = if d.streak > 1
			then string.format("📅 Daily reward: +%d 💰  ·  %d days in a row!", coins, d.streak)
			else string.format("📅 Daily reward: +%d 💰  ·  come back tomorrow for more", coins),
	})
	DataService.markDirty(player)
	Events.fire("DailyClaimed", player, d.streak, coins)
	return true
end

function DailyRewardService.init()
	DataService.onLoaded(function(player)
		task.wait(2) -- let them see the Plaza before the toast pops up
		if player.Parent then
			DailyRewardService.claim(player)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(CHECK_EVERY)
			for _, player in Players:GetPlayers() do
				task.spawn(DailyRewardService.claim, player)
			end
		end
	end)
end

return DailyRewardService
