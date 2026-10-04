-- Creates (server) or waits for (client) every RemoteEvent / RemoteFunction the game uses.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = {}

local EVENTS = {
	"CastRequest", -- client -> server: (aimPosition: Vector3)
	"EquipWand", -- client -> server: (index: number)
	"UseConsumable", -- client -> server: (id: string)
	"FX", -- server -> client: (kind: string, ...)
	"InventoryUpdated", -- server -> client: (inventory)
	"WandState", -- server -> client: (state table)
	"ChestContents", -- server -> client: (chestId, title, entries | nil)
	"Announce", -- server -> client: (kind: string, data)
	"Knockback", -- server -> client: (velocity: Vector3)
	"VoteState", -- server -> client: (vote payload)
	"TutorialDone", -- client -> server: the player finished (or skipped) the tutorial
	"WardrobeUpdated", -- server -> client: (wardrobe snapshot: coins, parts, garments, equipped, listings)
	"AchievementsUpdated", -- server -> client: (stats, unlocked achievements, daily reward streak)
}

local UNRELIABLE = {
	"FXSync", -- server -> client: projectile position corrections
	"DamageNumber", -- server -> client: (position, amount, crit, element)
}

local FUNCTIONS = {
	"InventoryAction", -- (action: string, args: table) -> (ok, message, extra)
	"ChestAction", -- (action: string, chestId: string, index: number?) -> (ok, message)
	"ClassAction", -- (action: string, classId: string?) -> (ok, message)
	"VoteAction", -- (action: "Vote", mapId: string) -> (ok, message)
	"QueueAction", -- (action: "Join" | "Leave") -> (ok, message)
	"WardrobeAction", -- (action: string, args: table) -> (ok, message, extra)
	"AuctionAction", -- (action: string, args: table) -> (ok, message, extra)
	"DevAction", -- (action: string, args: table) -> (ok, message, extra); admins only
}

local folder: Folder

if RunService:IsServer() then
	local existing = ReplicatedStorage:FindFirstChild("Remotes")
	if existing then
		folder = existing :: Folder
	else
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		for _, name in EVENTS do
			local r = Instance.new("RemoteEvent")
			r.Name = name
			r.Parent = folder
		end
		for _, name in UNRELIABLE do
			local r = Instance.new("UnreliableRemoteEvent")
			r.Name = name
			r.Parent = folder
		end
		for _, name in FUNCTIONS do
			local r = Instance.new("RemoteFunction")
			r.Name = name
			r.Parent = folder
		end
		folder.Parent = ReplicatedStorage
	end
else
	folder = ReplicatedStorage:WaitForChild("Remotes") :: Folder
end

function Remotes.event(name: string): RemoteEvent
	return folder:WaitForChild(name) :: RemoteEvent
end

function Remotes.unreliable(name: string): UnreliableRemoteEvent
	return folder:WaitForChild(name) :: UnreliableRemoteEvent
end

function Remotes.func(name: string): RemoteFunction
	return folder:WaitForChild(name) :: RemoteFunction
end

return Remotes
