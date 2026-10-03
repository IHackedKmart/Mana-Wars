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

InputController.onToggleInventory = InventoryController.toggle
InputController.onToggleGrimoire = GrimoireController.toggle
LobbyController.onOpenGrimoire = function()
	GrimoireController.open()
end
GrimoireController.onReplayTutorial = TutorialController.start

print("[Mana Wars] client ready")
