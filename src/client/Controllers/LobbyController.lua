-- Sky Sanctum UI: class selection (premium classes), lobby status, and spectating.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Remotes = require(Shared.Remotes)
local Classes = require(Shared.Classes)
local Consumables = require(Shared.Consumables)
local SpellParts = require(Shared.Spells.SpellParts)
local PremadeSpells = require(Shared.Spells.PremadeSpells)
local UI = script.Parent.Parent.UI
local Create = require(UI.Create)
local Theme = require(UI.Theme)
local Widgets = require(UI.Widgets)
local ItemInfo = require(UI.ItemInfo)
local State = require(script.Parent.State)
local Sounds = require(script.Parent.Sounds)

local LobbyController = {}

local C = Theme.Colors
local player = Players.LocalPlayer
local classAction = Remotes.func("ClassAction")

local gui: ScreenGui
local root: Frame
local classPanel: Frame
local classGrid: Frame
local unlockButton: TextButton
local classButton: TextButton
local spectateBar: Frame
local spectateName: TextLabel
local spectateButton: TextButton
local spectating = false
local spectateIndex = 1

local function kitInfo(class: Classes.ClassDef): ItemInfo.Info
	local lines = {}
	for _, w in class.kit.wands do
		local names = {}
		for _, id in w.spells do
			local premade = PremadeSpells.ById[id]
			table.insert(names, if premade then premade.name else id)
		end
		table.insert(lines, "🔹 " .. w.template.name .. " (" .. w.template.rarity .. ")")
		table.insert(lines, "     " .. table.concat(names, ", "))
	end
	local parts = {}
	for id, n in (class.kit.parts or {}) :: { [string]: number } do
		local part = SpellParts.ById[id]
		table.insert(parts, (if part then part.icon .. " " .. part.name else id) .. (if n > 1 then " x" .. n else ""))
	end
	if #parts > 0 then
		table.insert(lines, "Parts: " .. table.concat(parts, ", "))
	end
	local potions = {}
	for id, n in (class.kit.consumables or {}) :: { [string]: number } do
		local c = Consumables.ById[id]
		table.insert(potions, (if c then c.name else id) .. (if n > 1 then " x" .. n else ""))
	end
	if #potions > 0 then
		table.insert(lines, "Potions: " .. table.concat(potions, ", "))
	end
	return {
		title = class.icon .. " " .. class.name,
		color = Theme.rgb(class.color),
		subtitle = if class.premium then "Premium class" else "Free class",
		body = class.tagline .. "\n\nStarting kit:\n" .. table.concat(lines, "\n"),
	}
end

local function renderClasses()
	Widgets.clear(classGrid, true)
	local access = player:GetAttribute("PremiumAccess") == true
	local current = player:GetAttribute("Class")
	for i, class in Classes.List do
		local locked = class.premium and not access
		local isCurrent = current == class.id
		local card = Create("TextButton", {
			Text = "",
			AutoButtonColor = false,
			BackgroundColor3 = if isCurrent then C.Panel3 else C.Panel2,
			LayoutOrder = i,
			Parent = classGrid,
		}, {
			Create.corner(10),
			Create.stroke(
				if isCurrent then C.Gold else Theme.rgb(class.color),
				if isCurrent then 3 else 1.5,
				if locked then 0.6 else 0
			),
		})
		Widgets.label({
			Text = class.icon,
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Center,
			Size = UDim2.fromOffset(44, 44),
			Position = UDim2.fromOffset(10, 10),
			Parent = card,
		})
		Widgets.label({
			Text = class.name,
			Font = Theme.Black,
			TextSize = 16,
			TextColor3 = if locked then C.Dim else Theme.rgb(class.color),
			Size = UDim2.new(1, -66, 0, 20),
			Position = UDim2.fromOffset(60, 10),
			Parent = card,
		})
		Widgets.label({
			Text = if class.premium then (if locked then "🔒 PREMIUM" else "⭐ PREMIUM") else "FREE",
			Font = Theme.Bold,
			TextSize = 11,
			TextColor3 = if class.premium then C.Gold else C.Good,
			Size = UDim2.new(1, -66, 0, 14),
			Position = UDim2.fromOffset(60, 32),
			Parent = card,
		})
		Widgets.label({
			Text = class.tagline,
			TextSize = 12,
			TextWrapped = true,
			TextColor3 = if locked then C.Dim else C.Text,
			TextYAlignment = Enum.TextYAlignment.Top,
			Size = UDim2.new(1, -20, 0, 44),
			Position = UDim2.fromOffset(10, 60),
			Parent = card,
		})
		Widgets.attachTooltip(card, function()
			return kitInfo(class)
		end)
		card.Activated:Connect(function()
			if locked then
				State.toast("Premium class - unlock it with Roblox Premium", C.Gold)
				return
			end
			Sounds.play("Click")
			local ok, success, message = pcall(function()
				return classAction:InvokeServer("Select", class.id)
			end)
			if ok and message then
				State.toast(message, if success then C.Good else C.Bad)
			end
		end)
	end
	unlockButton.Visible = not access
end

local function buildClassPanel()
	classPanel = Widgets.panel({
		Size = UDim2.fromOffset(1000, 470),
		Position = UDim2.fromScale(0.5, 0.52),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = C.Background,
		BackgroundTransparency = 0.05,
		Visible = false,
		Parent = root,
	})
	Widgets.label({
		Text = "CHOOSE YOUR CLASS",
		Font = Theme.Black,
		TextSize = 24,
		TextColor3 = C.Gold,
		Size = UDim2.fromOffset(400, 30),
		Position = UDim2.fromOffset(20, 12),
		Parent = classPanel,
	})
	Widgets.label({
		Text = "Your class decides the wand, spells and parts you start with. Everything else is in the chests!",
		TextSize = 13,
		TextColor3 = C.Dim,
		Size = UDim2.new(1, -40, 0, 18),
		Position = UDim2.fromOffset(20, 42),
		Parent = classPanel,
	})
	Widgets.button("✕", {
		size = UDim2.fromOffset(34, 34),
		position = UDim2.new(1, -46, 0, 10),
		color = C.Panel3,
		onClick = function()
			classPanel.Visible = false
		end,
		parent = classPanel,
	})
	classGrid = Create("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -40, 0, 330),
		Position = UDim2.fromOffset(20, 70),
		Parent = classPanel,
	}, {
		Create("UIGridLayout", {
			CellSize = UDim2.fromOffset(184, 112),
			CellPadding = UDim2.fromOffset(10, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	unlockButton = Widgets.button("⭐  Unlock every class with Premium", {
		size = UDim2.fromOffset(360, 40),
		position = UDim2.new(0.5, 0, 1, -54),
		anchor = Vector2.new(0.5, 0),
		color = Color3.fromRGB(200, 150, 40),
		onClick = function()
			pcall(function()
				classAction:InvokeServer("Unlock")
			end)
		end,
		parent = classPanel,
	})
end

---------------------------------------------------------------------------
-- Spectating
---------------------------------------------------------------------------

local function spectateTargets(): { Model }
	local list = {}
	for _, p in Players:GetPlayers() do
		if p ~= player and p:GetAttribute("Alive") and p.Character then
			table.insert(list, p.Character)
		end
	end
	local bots = workspace:FindFirstChild("Bots")
	if bots then
		for _, model in bots:GetChildren() do
			if model:IsA("Model") and model:GetAttribute("InMatch") then
				table.insert(list, model)
			end
		end
	end
	return list
end

local function setSpectate(on: boolean)
	spectating = on
	local camera = workspace.CurrentCamera
	if not on then
		local character = player.Character
		local hum = character and character:FindFirstChildOfClass("Humanoid")
		if hum then
			camera.CameraSubject = hum
		end
	end
end

local function updateSpectate()
	if not spectating then
		return
	end
	local targets = spectateTargets()
	if #targets == 0 then
		spectateName.Text = "Nobody left to watch"
		return
	end
	spectateIndex = (spectateIndex - 1) % #targets + 1
	local target = targets[spectateIndex]
	local hum = target:FindFirstChildOfClass("Humanoid")
	if hum then
		workspace.CurrentCamera.CameraSubject = hum
		spectateName.Text = "👁 " .. (hum.DisplayName ~= "" and hum.DisplayName or target.Name)
	end
end

local function buildSpectate()
	spectateButton = Widgets.button("👁  Spectate", {
		size = UDim2.fromOffset(160, 38),
		position = UDim2.new(0.5, 0, 1, -70),
		anchor = Vector2.new(0.5, 0),
		color = C.Panel3,
		onClick = function()
			setSpectate(true)
			updateSpectate()
		end,
		parent = root,
	})
	spectateBar = Widgets.panel({
		Size = UDim2.fromOffset(420, 50),
		Position = UDim2.new(0.5, 0, 1, -76),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 0.15,
		Visible = false,
		Parent = root,
	})
	Widgets.button("◀", {
		size = UDim2.fromOffset(40, 34),
		position = UDim2.fromOffset(8, 8),
		color = C.Panel3,
		onClick = function()
			spectateIndex -= 1
			updateSpectate()
		end,
		parent = spectateBar,
	})
	spectateName = Widgets.label({
		Font = Theme.Bold,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, -200, 1, 0),
		Position = UDim2.fromOffset(52, 0),
		Parent = spectateBar,
	})
	Widgets.button("▶", {
		size = UDim2.fromOffset(40, 34),
		position = UDim2.new(1, -140, 0, 8),
		color = C.Panel3,
		onClick = function()
			spectateIndex += 1
			updateSpectate()
		end,
		parent = spectateBar,
	})
	Widgets.button("Stop", {
		size = UDim2.fromOffset(84, 34),
		position = UDim2.new(1, -92, 0, 8),
		color = C.Bad,
		onClick = function()
			setSpectate(false)
		end,
		parent = spectateBar,
	})
end

function LobbyController.init()
	gui = Widgets.screen("Lobby", 5)
	root = Widgets.scaledRoot(gui)
	buildClassPanel()
	buildSpectate()

	classButton = Widgets.button("🎓  Class: Apprentice", {
		size = UDim2.fromOffset(230, 38),
		position = UDim2.fromOffset(16, 64),
		color = C.Accent,
		onClick = function()
			classPanel.Visible = not classPanel.Visible
			if classPanel.Visible then
				renderClasses()
			end
		end,
		parent = root,
	})

	local function updateClassButton()
		local class = Classes.ById[tostring(player:GetAttribute("Class"))]
		if class then
			classButton.Text = class.icon .. "  Class: " .. class.name
		end
		if classPanel.Visible then
			renderClasses()
		end
	end
	player:GetAttributeChangedSignal("Class"):Connect(updateClassButton)
	player:GetAttributeChangedSignal("PremiumAccess"):Connect(updateClassButton)
	updateClassButton()

	-- show the class picker once when you first arrive
	task.delay(2, function()
		if not State.alive() then
			classPanel.Visible = true
			renderClasses()
		end
	end)

	local lastTarget = 0
	RunService.RenderStepped:Connect(function()
		local inLobby = not State.alive()
		local phase = State.phase()
		local matchRunning = phase == "Countdown" or phase == "Grace" or phase == "Battle"
		classButton.Visible = inLobby
		if not inLobby then
			classPanel.Visible = false
		end
		spectateButton.Visible = inLobby and matchRunning and not spectating
		spectateBar.Visible = spectating
		if spectating and (not matchRunning or not inLobby) then
			setSpectate(false)
		end
		if spectating and os.clock() - lastTarget > 1 then
			lastTarget = os.clock()
			local hum = workspace.CurrentCamera.CameraSubject
			if not hum or not hum.Parent or (hum:IsA("Humanoid") and hum.Health <= 0) then
				spectateIndex += 1
			end
			updateSpectate()
		end
	end)
end

return LobbyController
