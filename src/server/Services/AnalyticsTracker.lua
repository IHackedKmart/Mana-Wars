-- Sends gameplay events to Roblox's built-in analytics (Creator Dashboard -> your experience ->
-- Analytics), so you can see where new players drop off and how coins flow:
-- * Onboarding funnel: 1 Joined -> 2 Finished the tutorial -> 3 Joined the queue -> 4 Finished a
--   match -> 5 Opened a coffer. Each step is logged once per player, ever.
-- * Economy: every Enchanted Coin earned (match placement, daily reward, achievements, salvage,
--   auction sales) and spent (coffers, auction purchases), with the balance after it.
-- * Custom events: MatchFinished (value = finishing place, by map and kit), MatchKills, KitPicked,
--   KitPurchased, AchievementUnlocked, DailyStreak.
-- Everything goes through pcall: analytics must never break the game. Config.Analytics.Enabled
-- turns it all off.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local Events = require(script.Parent.Events)

local AnalyticsTracker = {}

AnalyticsTracker.OnboardingSteps = {
	"Joined",
	"Finished the tutorial",
	"Joined the queue",
	"Finished a match",
	"Opened a coffer",
}

local service: any = nil
local warned = false

-- Enum items by name, falling back to the plain name (keeps working if an enum is renamed).
local function enumItem(enumName: string, itemName: string): any
	local ok, item = pcall(function()
		return (Enum :: any)[enumName][itemName]
	end)
	return if ok and item then item else itemName
end

local function fieldKey(n: number): string
	local item = enumItem("AnalyticsCustomFieldKeys", "CustomField0" .. n)
	return if type(item) == "string" then item else item.Name
end

local function call(method: string, ...: any)
	if not service or not Config.Analytics.Enabled then
		return
	end
	local ok, err = pcall(service[method], service, ...)
	if not ok and not warned then
		warned = true -- once per server is plenty
		warn("[Analytics] " .. method .. " failed: " .. tostring(err))
	end
end

-- Logs onboarding step `step` for this player unless it was logged before.
function AnalyticsTracker.onboard(player: Player, step: number)
	local profile = DataService.profile(player)
	if not profile then
		return
	end
	local key = tostring(step)
	if profile.onboarding[key] then
		return
	end
	profile.onboarding[key] = true
	DataService.markDirty(player)
	call("LogOnboardingFunnelStepEvent", player, step, AnalyticsTracker.OnboardingSteps[step])
end

function AnalyticsTracker.custom(player: Player, name: string, value: number?, fields: { string }?)
	local custom = nil
	if fields then
		custom = {}
		for i, v in fields do
			custom[fieldKey(i)] = v
		end
	end
	call("LogCustomEvent", player, name, value or 1, custom)
end

function AnalyticsTracker.init()
	local ok, result = pcall(function()
		return game:GetService("AnalyticsService")
	end)
	service = if ok then result else nil

	DataService.onLoaded(function(player, profile)
		if next(profile.onboarding) == nil and (profile.matches > 0 or profile.tutorial) then
			-- they played before analytics existed: they aren't new, don't count them as onboarding
			for step in AnalyticsTracker.OnboardingSteps do
				profile.onboarding[tostring(step)] = true
			end
			DataService.markDirty(player)
			return
		end
		AnalyticsTracker.onboard(player, 1)
	end)
	Events.on("TutorialDone", function(player: Player)
		AnalyticsTracker.onboard(player, 2)
	end)
	Events.on("QueueJoined", function(player: Player)
		AnalyticsTracker.onboard(player, 3)
	end)
	Events.on(
		"MatchFinished",
		function(player: Player, place: number, _outOf: number, kills: number, mapId: string, classId: string)
			AnalyticsTracker.onboard(player, 4)
			AnalyticsTracker.custom(player, "MatchFinished", place, { mapId, classId })
			AnalyticsTracker.custom(player, "MatchKills", kills, { mapId })
		end
	)
	Events.on("CofferOpened", function(player: Player)
		AnalyticsTracker.onboard(player, 5)
	end)

	Events.on("Coins", function(player: Player, delta: number, kind: string, sku: string?, balance: number)
		if kind == "Dev" or delta == 0 then
			return -- dev panel handouts aren't real economy
		end
		local transaction = enumItem("AnalyticsEconomyTransactionType", kind)
		call(
			"LogEconomyEvent",
			player,
			enumItem("AnalyticsEconomyFlowType", if delta > 0 then "Source" else "Sink"),
			"EnchantedCoins",
			math.abs(delta),
			balance,
			if type(transaction) == "string" then transaction else transaction.Name,
			sku
		)
	end)
	Events.on("KitPicked", function(player: Player, classId: string)
		AnalyticsTracker.custom(player, "KitPicked", 1, { classId })
	end)
	Events.on("PassPurchased", function(player: Player, classId: string)
		AnalyticsTracker.custom(player, "KitPurchased", 1, { classId })
	end)
	Events.on("AchievementUnlocked", function(player: Player, achievement: any)
		AnalyticsTracker.custom(player, "AchievementUnlocked", 1, { achievement.id })
	end)
	Events.on("DailyClaimed", function(player: Player, streak: number)
		AnalyticsTracker.custom(player, "DailyStreak", streak)
	end)
end

return AnalyticsTracker
