-- Kit (class) selection and ownership. Every paid kit is its own game pass (Config.Kits);
-- Roblox Premium members get the cheapest tier(s) free, and Studio unlocks everything for testing.
-- Owned kits are published to the client as the "OwnedKits" attribute (comma separated ids).
-- The kit a player picks is saved with their profile, so it's still picked next time they play.
-- Each kit's random bonus spell part is a paid random item: where a player's region restricts
-- those (PolicyService), paid kits leave it out and the shop says so ("PaidRandomAllowed").
-- Kits are used in Survival Games and the Battle Royale; duels hand out their own random loadout.

local MarketplaceService = game:GetService("MarketplaceService")
local okPolicy, PolicyService = pcall(function()
	return game:GetService("PolicyService")
end)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Classes = require(Shared.Classes)
local Events = require(script.Parent.Events)
local DataService = require(script.Parent.DataService)

local ClassService = {}

local owned: { [Player]: { [string]: boolean } } = setmetatable({}, { __mode = "k" }) :: any
-- dev panel: "all" owns every kit, "locked" ignores the Studio unlock (to test the shop)
local devMode: { [Player]: string } = setmetatable({}, { __mode = "k" }) :: any
-- players whose game passes have been looked up this session
local checked: { [Player]: boolean } = setmetatable({}, { __mode = "k" }) :: any

local function passFor(classId: string): number
	return Config.Kits.GamePassIds[classId] or 0
end

local function kitForPass(passId: number): string?
	for classId, id in Config.Kits.GamePassIds do
		if id == passId and id ~= 0 then
			return classId
		end
	end
	return nil
end

local function publish(player: Player)
	local list = {}
	for _, class in Classes.List do
		if ClassService.owns(player, class.id) then
			table.insert(list, class.id)
		end
	end
	player:SetAttribute("OwnedKits", table.concat(list, ","))
end

function ClassService.owns(player: Player, classId: string): boolean
	local class = Classes.ById[classId]
	if not class then
		return false
	end
	if class.tier == 0 then
		return true
	end
	local K = Config.Kits
	local mode = devMode[player]
	if mode == "all" then
		return true
	end
	if K.StudioUnlocksAll and RunService:IsStudio() and mode ~= "locked" then
		return true
	end
	if class.tier <= K.PremiumFreeTier and player.MembershipType == Enum.MembershipType.Premium then
		return true
	end
	local set = owned[player]
	return set ~= nil and set[classId] == true
end

-- Asks Roblox whether this player may get paid random items (yields). Until it answers, and if it
-- can't, they're treated as not allowed, which is the safe side.
function ClassService.checkPolicy(player: Player)
	local allowed = false
	if okPolicy and PolicyService then
		for _ = 1, 2 do
			local ok, info = pcall(function()
				return (PolicyService :: any):GetPolicyInfoForPlayerAsync(player)
			end)
			if ok and type(info) == "table" then
				allowed = info.ArePaidRandomItemsRestricted == false
				break
			end
			task.wait(2)
		end
	end
	player:SetAttribute("PaidRandomAllowed", allowed)
end

-- Looks up which kit game passes the player owns (yields: one web call per configured pass).
function ClassService.refresh(player: Player)
	if player:GetAttribute("PaidRandomAllowed") == nil then
		task.spawn(ClassService.checkPolicy, player)
	end
	local set = owned[player] or {}
	owned[player] = set
	for _, class in Classes.List do
		local passId = passFor(class.id)
		if passId ~= 0 and not set[class.id] then
			local ok, has = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, passId)
			end)
			if ok and has then
				set[class.id] = true
			end
		end
	end
	checked[player] = true
	publish(player)
	if not ClassService.owns(player, tostring(player:GetAttribute("Class"))) then
		player:SetAttribute("Class", Classes.Default)
	end
end

-- Picks a kit and remembers it for next time.
function ClassService.select(player: Player, classId: string)
	player:SetAttribute("Class", classId)
	local profile = DataService.profile(player)
	if profile and profile.kit ~= classId then
		profile.kit = classId
		DataService.markDirty(player)
	end
end

-- Dev panel: "all" (own every kit), "locked" (only kits really bought) or "normal".
function ClassService.setDevMode(player: Player, mode: string)
	if mode == "all" or mode == "locked" then
		devMode[player] = mode
	else
		devMode[player] = nil
	end
	publish(player)
	if not ClassService.owns(player, tostring(player:GetAttribute("Class"))) then
		player:SetAttribute("Class", Classes.Default)
	end
end

function ClassService.devModeOf(player: Player): string
	return devMode[player] or "normal"
end

-- The class this player will actually start the match with.
function ClassService.classFor(player: Player): string
	local id = tostring(player:GetAttribute("Class"))
	if Classes.ById[id] and ClassService.owns(player, id) then
		return id
	end
	return Classes.Default
end

-- Bots pick a random kit, but never the top tiers (a bot with a $25 kit isn't fun to meet).
function ClassService.randomClass(rng: Random): string
	local list = {}
	for _, class in Classes.List do
		if class.tier <= 3 then
			table.insert(list, class.id)
		end
	end
	return list[rng:NextInteger(1, #list)]
end

function ClassService.init()
	-- the kit picked last time (once their game passes are known, an unowned one falls back to the
	-- free kit; refresh() checks it again if the profile loads first)
	DataService.onLoaded(function(player, profile)
		local saved = profile.kit
		if Classes.ById[saved] and (not checked[player] or ClassService.owns(player, saved)) then
			player:SetAttribute("Class", saved)
		end
	end)
	Players.PlayerMembershipChanged:Connect(function(player)
		publish(player)
	end)
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		local classId = kitForPass(passId)
		if purchased and classId then
			local set = owned[player] or {}
			owned[player] = set
			set[classId] = true
			publish(player)
			ClassService.select(player, classId)
			Events.fire("PassPurchased", player, classId)
		end
	end)

	Remotes.func("ClassAction").OnServerInvoke = function(player, action, classId)
		if type(classId) ~= "string" then
			return false, "Bad kit"
		end
		local class = Classes.ById[classId]
		if not class then
			return false, "Unknown kit"
		end
		if action == "Select" then
			if not ClassService.owns(player, class.id) then
				return false, "You don't own the " .. class.name .. " kit yet"
			end
			ClassService.select(player, class.id)
			Events.fire("KitPicked", player, class.id)
			return true, class.name .. " selected"
		elseif action == "Buy" then
			if ClassService.owns(player, class.id) then
				return true, "You already own " .. class.name
			end
			local passId = passFor(class.id)
			if passId ~= 0 then
				MarketplaceService:PromptGamePassPurchase(player, passId)
				return true, nil
			elseif class.tier <= Config.Kits.PremiumFreeTier then
				MarketplaceService:PromptPremiumPurchase(player)
				return true, nil
			end
			return false, "The " .. class.name .. " kit isn't on sale yet"
		end
		return false, "Unknown action"
	end
end

return ClassService
