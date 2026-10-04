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
local FamiliarController = require(Controllers.FamiliarController)
local DevController = require(Controllers.DevController)
local AuctionController = require(Controllers.AuctionController)
local ChatController = require(Controllers.ChatController)
local AchievementsController = require(Controllers.AchievementsController)
local ModeMenuController = require(Controllers.ModeMenuController)
local CarpetController = require(Controllers.CarpetController)

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
FamiliarController.init()
DevController.init()
AuctionController.init()
ChatController.init()
AchievementsController.init()
ModeMenuController.init()
CarpetController.init()

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
	AchievementsController.close()
	AuctionController.open()
end
LobbyController.onOpenModes = function()
	WardrobeController.close()
	AuctionController.close()
	AchievementsController.close()
	ModeMenuController.toggle()
end
LobbyController.onOpenAchievements = function()
	WardrobeController.close()
	AuctionController.close()
	AchievementsController.toggle()
end
AuctionController.onOpenWardrobe = function()
	AuctionController.close()
	WardrobeController.open("Wardrobe")
end
GrimoireController.onReplayTutorial = TutorialController.start

print("[Mana Wars] client ready")
