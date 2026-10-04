-- The Play menu: pick a game mode (Survival Games, 1v1 Duel or Battle Royale). Opened by the Play
-- button, by walking through the Plaza's portal, and from the library to switch modes. Choosing a
-- mode joins its queue on the server (QueueAction "Join").

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Modes = require(Shared.Modes)
local Remotes = require(Shared.Remotes)
local UI = script.Parent.Parent.UI
local Create = require(UI.Create)
local Theme = require(UI.Theme)
local Widgets = require(UI.Widgets)
local State = require(script.Parent.State)

local ModeMenuController = {}

local C = Theme.Colors
local player = Players.LocalPlayer

local gui: ScreenGui
local isOpen = false
local cards: { [string]: { frame: Frame, count: TextLabel, button: TextButton, stroke: UIStroke } } = {}

local function queuedMode(): string?
	if not State.queued() then
		return nil
	end
	return player:GetAttribute("QueuedMode")
end

local function join(modeId: string)
	local ok, success, message = pcall(function()
		return Remotes.func("QueueAction"):InvokeServer("Join", modeId)
	end)
	if ok and type(message) == "string" then
		State.toast(message, if success then C.Good else C.Bad)
	end
	if ok and success then
		ModeMenuController.close()
	end
end

local function refresh()
	local current = queuedMode()
	for id, card in cards do
		local n = tonumber(ReplicatedStorage:GetAttribute("Queue" .. id)) or 0
		card.count.Text = if n == 1 then "1 mage queued" else n .. " mages queued"
		local mine = current == id
		card.button.Text = if mine then "✅  Queued" else "▶️  Play"
		card.stroke.Color = if mine then C.Gold else C.Stroke
		card.stroke.Thickness = if mine then 2.5 else 1.5
	end
end

local function card(mode: Modes.Mode, order: number, parent: Instance)
	local color = Theme.rgb(mode.color)
	local frame = Create("Frame", {
		Name = "Mode_" .. mode.id,
		Size = UDim2.fromOffset(300, 430),
		BackgroundColor3 = C.Panel2,
		LayoutOrder = order,
		Parent = parent,
	}, { Create.corner(14) })
	local stroke = Create.stroke(C.Stroke, 1.5, 0.1)
	stroke.Parent = frame
	-- a coloured banner with the mode's icon
	local banner = Create("Frame", {
		Size = UDim2.new(1, 0, 0, 120),
		BackgroundColor3 = color,
		Parent = frame,
	}, {
		Create.corner(14),
		Create("UIGradient", {
			Color = ColorSequence.new(Theme.lighten(color, 0.15), Theme.darken(color, 0.35)),
			Rotation = 90,
		}),
	})
	Widgets.label({
		Size = UDim2.fromScale(1, 1),
		Text = mode.icon,
		TextSize = 64,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = banner,
	})
	Widgets.label({
		Name = "Name",
		Size = UDim2.new(1, -24, 0, 30),
		Position = UDim2.fromOffset(12, 130),
		Text = mode.name,
		Font = Theme.Title,
		TextSize = 28,
		TextColor3 = C.Gold,
		Parent = frame,
	})
	Widgets.label({
		Name = "Tagline",
		Size = UDim2.new(1, -24, 0, 18),
		Position = UDim2.fromOffset(12, 162),
		Text = mode.tagline,
		Font = Theme.Bold,
		TextSize = 14,
		TextColor3 = Theme.lighten(color, 0.45),
		Parent = frame,
	})
	Widgets.label({
		Name = "Players",
		Size = UDim2.new(1, -24, 0, 16),
		Position = UDim2.fromOffset(12, 182),
		Text = "👥  " .. mode.players,
		TextSize = 13,
		TextColor3 = C.Dim,
		Parent = frame,
	})
	Widgets.label({
		Size = UDim2.new(1, -24, 0, 140),
		Position = UDim2.fromOffset(12, 206),
		Text = mode.description,
		TextSize = 15,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextColor3 = C.Text,
		Parent = frame,
	})
	local count = Widgets.label({
		Name = "Count",
		Size = UDim2.new(1, -24, 0, 18),
		Position = UDim2.new(0, 12, 1, -82),
		TextSize = 14,
		TextColor3 = C.Dim,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = frame,
	})
	local button = Widgets.button("▶️  Play", {
		size = UDim2.new(1, -24, 0, 46),
		position = UDim2.new(0, 12, 1, -58),
		color = color,
		textSize = 20,
		onClick = function()
			join(mode.id)
		end,
		parent = frame,
	})
	button.Name = "Play_" .. mode.id
	Create.stroke(C.Gold, 1.5, 0.3).Parent = button
	cards[mode.id] = { frame = frame, count = count, button = button, stroke = stroke }
end

function ModeMenuController.open()
	if State.inMatch() then
		return
	end
	isOpen = true
	gui.Enabled = true
	State.setMenu("modes", true)
	refresh()
end

function ModeMenuController.close()
	isOpen = false
	gui.Enabled = false
	State.setMenu("modes", false)
end

function ModeMenuController.toggle()
	if isOpen then
		ModeMenuController.close()
	else
		ModeMenuController.open()
	end
end

function ModeMenuController.isOpen(): boolean
	return isOpen
end

function ModeMenuController.init()
	gui = Widgets.screen("ModeMenu", 12)
	gui.Enabled = false
	local window = Widgets.window(gui, {
		title = "Choose a game mode",
		icon = "▶️",
		subtitle = "Pick one to join its queue  ·  you can switch any time before your match starts",
		size = Vector2.new(1000, 540),
		onClose = function()
			ModeMenuController.close()
		end,
	})
	local row = Create("Frame", {
		Name = "Modes",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = window.body,
	}, {
		Create.list(Enum.FillDirection.Horizontal, 20, Enum.HorizontalAlignment.Center),
	})
	for i, mode in Modes.List do
		card(mode, i, row)
	end

	State.PlayMenuRequested:Connect(function()
		ModeMenuController.open()
	end)
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if isOpen and acc > 0.5 then
			acc = 0
			refresh()
			if State.inMatch() then
				ModeMenuController.close()
			end
		end
	end)
end

return ModeMenuController
