-- The loot window shown when you open a chest or a dead mage's satchel.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Items = require(Shared.Items)
local UI = script.Parent.Parent.UI
local Create = require(UI.Create)
local Theme = require(UI.Theme)
local Widgets = require(UI.Widgets)
local ItemInfo = require(UI.ItemInfo)
local State = require(script.Parent.State)
local Sounds = require(script.Parent.Sounds)

local ChestController = {}

local C = Theme.Colors
local player = Players.LocalPlayer
local chestAction = Remotes.func("ChestAction")

local gui: ScreenGui
local titleLabel: TextLabel
local list: ScrollingFrame
local currentId: string? = nil
local currentPos: Vector3? = nil

local KIND_TEXT = { Part = "Spell part", Spell = "Spell", Wand = "Wand", Consumable = "Potion" }

local function findChestPosition(id: string): Vector3?
	for _, container in { workspace:FindFirstChild("Arena"), workspace:FindFirstChild("Satchels") } do
		if container then
			for _, model in container:GetDescendants() do
				if model:IsA("Model") and model:GetAttribute("ChestId") == id then
					local primary = model.PrimaryPart
					return if primary then primary.Position else model:GetPivot().Position
				end
			end
		end
	end
	return nil
end

function ChestController.close()
	if not currentId then
		return
	end
	local id = currentId
	currentId = nil
	currentPos = nil
	gui.Enabled = false
	Widgets.hideTooltip()
	State.setMenu("chest", false)
	task.spawn(function()
		pcall(function()
			chestAction:InvokeServer("Close", id)
		end)
	end)
end

local function take(index: number?)
	local id = currentId
	if not id then
		return
	end
	local ok, success, message = pcall(function()
		if index then
			return chestAction:InvokeServer("Take", id, index)
		end
		return chestAction:InvokeServer("TakeAll", id)
	end)
	if ok and success then
		Sounds.play("Pickup", 0.2)
	elseif ok and message then
		State.toast(message, C.Bad)
	end
end

local function render(title: string, entries: { Items.LootEntry })
	titleLabel.Text = title
	Widgets.clear(list, true)
	if #entries == 0 then
		Widgets.label({
			Text = "Empty.",
			TextColor3 = C.Dim,
			TextSize = 15,
			Size = UDim2.new(1, 0, 0, 30),
			Parent = list,
		})
		return
	end
	for i, entry in entries do
		local info = ItemInfo.entry(entry)
		local row = Widgets.panel({
			Size = UDim2.new(1, -8, 0, 62),
			BackgroundColor3 = C.Panel2,
			LayoutOrder = i,
			Parent = list,
		})
		local stroke = row:FindFirstChildOfClass("UIStroke") :: UIStroke
		stroke.Color = info.color
		stroke.Transparency = 0.4
		local tileOpts: Widgets.TileOptions = {
			size = 48,
			border = info.color,
			count = entry.count,
			info = function()
				return info
			end,
			onClick = function()
				take(i)
			end,
			parent = row,
		}
		if entry.kind == "Wand" and entry.wand then
			tileOpts.wandColor = Theme.rgb(entry.wand.color)
			tileOpts.gemColor = info.color
		else
			tileOpts.icon = info.icon
			tileOpts.iconColor = info.iconColor
		end
		Widgets.tile(tileOpts).Position = UDim2.fromOffset(7, 7)
		Widgets.label({
			Text = info.title .. (if entry.count and entry.count > 1 then "  x" .. entry.count else ""),
			Font = Theme.Bold,
			TextSize = 15,
			TextColor3 = info.color,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Size = UDim2.new(1, -150, 0, 20),
			Position = UDim2.fromOffset(64, 10),
			Parent = row,
		})
		Widgets.label({
			Text = (info.subtitle or KIND_TEXT[entry.kind] or entry.kind),
			TextSize = 12,
			TextColor3 = C.Dim,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Size = UDim2.new(1, -150, 0, 16),
			Position = UDim2.fromOffset(64, 32),
			Parent = row,
		})
		Widgets.button("Take", {
			size = UDim2.fromOffset(70, 32),
			position = UDim2.new(1, -80, 0.5, 0),
			anchor = Vector2.new(0, 0.5),
			textSize = 14,
			onClick = function()
				take(i)
			end,
			parent = row,
		})
	end
end

local function build()
	gui = Widgets.screen("Chest", 9)
	gui.Enabled = false
	-- a side window: you can still see (and walk) around while looting, so no dimming
	local window = Widgets.window(gui, {
		title = "Chest",
		icon = "🧰",
		subtitle = "Click Take, or press F to take everything",
		size = Vector2.new(430, 480),
		onClose = function()
			ChestController.close()
		end,
	})
	window.scrim.Visible = false
	window.panel.Position = UDim2.new(1, -36, 0.5, 0)
	window.panel.AnchorPoint = Vector2.new(1, 0.5)
	window.title.TextSize = 24
	window.title.Size = UDim2.new(1, -130, 0, 32)
	titleLabel = window.title
	list = Create("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 1, -50),
		ScrollBarThickness = 5,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = window.body,
	}, { Create.list(Enum.FillDirection.Vertical, 6), Create.padding(2, 2) })
	Widgets.button("Take All  [F]", {
		size = UDim2.new(1, 0, 0, 40),
		position = UDim2.new(0, 0, 1, -40),
		color = C.Gold,
		textColor = C.Ink,
		textSize = 16,
		onClick = function()
			take(nil)
		end,
		parent = window.body,
	})
end

function ChestController.init()
	build()
	Remotes.event("ChestContents").OnClientEvent:Connect(function(id: string, title: string?, entries)
		if entries == nil then
			if currentId == id then
				ChestController.close()
			end
			return
		end
		if currentId ~= id then
			currentId = id
			currentPos = findChestPosition(id)
			Sounds.play("Click")
		end
		gui.Enabled = true
		State.setMenu("chest", true)
		render(title or "Chest", entries)
	end)

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or not currentId then
			return
		end
		if input.KeyCode == Enum.KeyCode.Escape then
			ChestController.close()
		elseif input.KeyCode == Enum.KeyCode.F then
			take(nil)
		end
	end)

	RunService.Heartbeat:Connect(function()
		if not currentId then
			return
		end
		if not State.alive() then
			ChestController.close()
			return
		end
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root and currentPos and (root.Position - currentPos).Magnitude > Config.Inventory.ChestReach + 4 then
			ChestController.close()
		end
	end)
end

return ChestController
