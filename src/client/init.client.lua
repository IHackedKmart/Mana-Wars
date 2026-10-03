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

State.init()
Widgets.initTooltip()
FXController.init()
InputController.init()
HUDController.init()
InventoryController.init()
ChestController.init()
LobbyController.init()
StormController.init()

InputController.onToggleInventory = InventoryController.toggle

print("[Mana Wars] client ready")
