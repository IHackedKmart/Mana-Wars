-- Mana Wars client entry point.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes")

local Controllers = script:WaitForChild("Controllers")
local Widgets = require(script:WaitForChild("UI"):WaitForChild("Widgets"))

local State = require(Controllers.State)
local FXController = require(Controllers.FXController)
local InputController = require(Controllers.InputController)
local HUDController = require(Controllers.HUDController)
local InventoryController = require(Controllers.InventoryController)
local ChestController = require(Controllers.ChestController)
local LobbyController = require(Controllers.LobbyController)
local StormController = require(Controllers.StormController)
local GrimoireController = require(Controllers.GrimoireController)
local TutorialController = require(Controllers.TutorialController)
local AmbienceController = require(Controllers.AmbienceController)
local WardrobeController = require(Controllers.WardrobeController)
local AuctionController = require(Controllers.AuctionController)

State.init()
Widgets.initTooltip()
FXController.init()
InputController.init()
HUDController.init()
InventoryController.init()
ChestController.init()
LobbyController.init()
StormController.init()
GrimoireController.init()
TutorialController.init()
AmbienceController.init()
WardrobeController.init()
AuctionController.init()

InputController.onToggleInventory = InventoryController.toggle
InputController.onToggleGrimoire = GrimoireController.toggle
LobbyController.onOpenGrimoire = function()
	GrimoireController.open()
end
LobbyController.onOpenWardrobe = function(tab)
	AuctionController.close()
	WardrobeController.open(tab)
end
LobbyController.onOpenAuction = function()
	WardrobeController.close()
	AuctionController.open()
end
AuctionController.onOpenWardrobe = function()
	AuctionController.close()
	WardrobeController.open("Wardrobe")
end
GrimoireController.onReplayTutorial = TutorialController.start

print("[Mana Wars] client ready")
