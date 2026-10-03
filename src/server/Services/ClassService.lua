-- Class selection and premium access.
-- Premium access = Roblox Premium membership OR owning the classes game pass
-- (or playing in Studio, so you can test every class). See Config.Premium.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Classes = require(Shared.Classes)

local ClassService = {}

local function computeAccess(player: Player): boolean
	local P = Config.Premium
	if P.StudioUnlocksAll and RunService:IsStudio() then
		return true
	end
	if P.UseRobloxPremium and player.MembershipType == Enum.MembershipType.Premium then
		return true
	end
	if P.ClassesGamePassId ~= 0 then
		local ok, owns = pcall(function()
			return MarketplaceService:UserOwnsGamePassAsync(player.UserId, P.ClassesGamePassId)
		end)
		if ok and owns then
			return true
		end
	end
	return false
end

function ClassService.refresh(player: Player)
	local access = computeAccess(player)
	player:SetAttribute("PremiumAccess", access)
	local class = Classes.ById[tostring(player:GetAttribute("Class"))]
	if not class or (class.premium and not access) then
		player:SetAttribute("Class", Classes.Default)
	end
end

function ClassService.hasAccess(player: Player): boolean
	return player:GetAttribute("PremiumAccess") == true
end

-- The class this player will actually start the match with.
function ClassService.classFor(player: Player): string
	local class = Classes.ById[tostring(player:GetAttribute("Class"))]
	if class and (not class.premium or ClassService.hasAccess(player)) then
		return class.id
	end
	return Classes.Default
end

function ClassService.randomClass(rng: Random): string
	local list = Classes.List
	return list[rng:NextInteger(1, #list)].id
end

function ClassService.init()
	Players.PlayerMembershipChanged:Connect(function(player)
		ClassService.refresh(player)
	end)
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if purchased and passId == Config.Premium.ClassesGamePassId then
			player:SetAttribute("PremiumAccess", true)
		end
	end)

	Remotes.func("ClassAction").OnServerInvoke = function(player, action, classId)
		if action == "Select" then
			if type(classId) ~= "string" then
				return false, "Bad class"
			end
			local class = Classes.ById[classId]
			if not class then
				return false, "Unknown class"
			end
			if class.premium and not ClassService.hasAccess(player) then
				return false, "This class needs Premium"
			end
			player:SetAttribute("Class", class.id)
			return true, class.name .. " selected"
		elseif action == "Unlock" then
			if Config.Premium.ClassesGamePassId ~= 0 then
				MarketplaceService:PromptGamePassPurchase(player, Config.Premium.ClassesGamePassId)
			elseif Config.Premium.UseRobloxPremium then
				MarketplaceService:PromptPremiumPurchase(player)
			end
			return true, nil
		end
		return false, "Unknown action"
	end
end

return ClassService
