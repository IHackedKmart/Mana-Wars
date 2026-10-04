-- The 🛠️ Dev panel: test everything without spending anything. It shows for players the server
-- marks as developers (everyone in Studio, the game's owner in live servers; see Config.Dev),
-- and the server checks every request again (DevService).
-- Open it with the 🛠️ Dev button or the ` key (backquote, left of 1).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage.Shared
local Remotes = require(Shared.Remotes)
local Rarity = require(Shared.Rarity)
local PremadeSpells = require(Shared.Spells.PremadeSpells)
local UI = script.Parent.Parent.UI
local Create = require(UI.Create)
local Theme = require(UI.Theme)
local Widgets = require(UI.Widgets)
local State = require(script.Parent.State)
local Sounds = require(script.Parent.Sounds)

local DevController = {}

local C = Theme.Colors
local GOLD = Color3.fromRGB(255, 205, 80)
local action = Remotes.func("DevAction")
local player = Players.LocalPlayer

local gui: ScreenGui
local panel: Frame
local openButton: TextButton
local rarity = "Mythic"
local shiny = false
local rarityButtons: { [string]: TextButton } = {}
local shinyButton: TextButton
local toggles: { [string]: { button: TextButton, label: string, on: boolean } } = {}
local confirmReset = false

local function invoke(name: string, args: { [string]: any }?): (boolean, any)
	local ok, success, message, extra = pcall(function()
		return action:InvokeServer(name, args or {})
	end)
	if not ok then
		State.toast("Dev tools: " .. tostring(success), C.Bad)
		return false, nil
	end
	if message and message ~= "" then
		State.toast(message, if success then C.Good else C.Bad)
	end
	return success == true, extra
end

---------------------------------------------------------------------------
-- Building blocks
---------------------------------------------------------------------------

local order = 0
local function nextOrder(): number
	order += 1
	return order
end

local function section(parent: Instance, title: string, cellWidth: number?): Frame
	Widgets.label({
		Text = title,
		Font = Theme.Black,
		TextSize = 13,
		TextColor3 = C.Gold,
		Size = UDim2.new(1, 0, 0, 18),
		LayoutOrder = nextOrder(),
		Parent = parent,
	})
	local grid = Create("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = nextOrder(),
		Parent = parent,
	})
	Create("UIGridLayout", {
		CellSize = UDim2.fromOffset(cellWidth or 146, 32),
		CellPadding = UDim2.fromOffset(6, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = grid,
	})
	return grid
end

local function button(parent: Instance, name: string, text: string, onClick: () -> (), color: Color3?): TextButton
	local b = Widgets.button(text, {
		color = color or C.Panel3,
		textSize = 13,
		layoutOrder = nextOrder(),
		onClick = function()
			Sounds.play("Click")
			onClick()
		end,
		parent = parent,
	})
	b.Name = name
	return b
end

local function setToggle(key: string, on: boolean)
	local t = toggles[key]
	if t then
		t.on = on
		t.button.Text = t.label .. (if on then ": ON" else ": OFF")
		t.button.BackgroundColor3 = if on then C.Good else C.Panel3
	end
end

-- A button that flips a server-side switch (free coffers, god mode...).
local function toggle(parent: Instance, key: string, label: string, actionName: string)
	local b = button(parent, "Toggle_" .. key, label, function()
		local t = toggles[key]
		local want = not t.on
		if invoke(actionName, { on = want }) then
			setToggle(key, want)
		end
	end)
	toggles[key] = { button = b, label = label, on = false }
	setToggle(key, false)
end

local function refreshPickers()
	for name, b in rarityButtons do
		b.BackgroundColor3 = if name == rarity then Theme.rarity(name) else C.Panel3
		b.TextColor3 = if name == rarity then Color3.new(0, 0, 0) else Theme.rarity(name)
	end
	shinyButton.Text = if shiny then "✨ Shiny: ON" else "✨ Shiny: OFF"
	shinyButton.BackgroundColor3 = if shiny then GOLD else C.Panel3
	shinyButton.TextColor3 = if shiny then Color3.new(0, 0, 0) else Color3.new(1, 1, 1)
end

local function syncStatus()
	local ok, status = invoke("Status", {})
	if ok and type(status) == "table" then
		setToggle("FreeCoffers", status.freeCoffers == true)
		setToggle("Loadout", status.loadout == true)
		setToggle("God", status.god == true)
		setToggle("Mana", status.mana == true)
	end
end

---------------------------------------------------------------------------
-- The panel
---------------------------------------------------------------------------

local function build()
	gui = Widgets.screen("DevPanel", 30)
	local root = Widgets.scaledRoot(gui)
	root.Name = "ButtonRoot"
	openButton = Widgets.button("🛠️ Dev", {
		size = UDim2.fromOffset(84, 32),
		position = UDim2.new(1, -16, 0, 52),
		anchor = Vector2.new(1, 0),
		color = Color3.fromRGB(60, 50, 30),
		textColor = GOLD,
		textSize = 14,
		onClick = function()
			DevController.toggle()
		end,
		parent = root,
	})
	openButton.Name = "DevButton"
	openButton.Visible = false

	local window = Widgets.window(gui, {
		title = "Developer Tools",
		icon = "🛠️",
		subtitle = "Only you see this  ·  Studio play tests save to separate test data  ·  ` opens and closes it",
		size = Vector2.new(680, 650),
		onClose = function()
			DevController.close()
		end,
	})
	local frameStroke = window.panel:FindFirstChildOfClass("UIStroke")
	if frameStroke then
		frameStroke.Color = GOLD
	end
	panel = window.root
	panel.Name = "Panel"
	panel.Visible = false
	local body = window.body

	-- the big one
	local unlock = Widgets.button("⭐  UNLOCK EVERYTHING  ⭐", {
		size = UDim2.new(1, 0, 0, 46),
		color = GOLD,
		textColor = Color3.fromRGB(40, 25, 0),
		textSize = 20,
		onClick = function()
			Sounds.play("Crit")
			if invoke("UnlockAll", {}) then
				syncStatus()
			end
		end,
		parent = body,
	})
	unlock.Name = "UnlockAll"
	Widgets.label({
		Text = "Every kit, 100,000 coins, free coffers, every robe/hat design and aura, an outfit of every rarity, every familiar (plus a Shiny Mythic of each), and a full spell loadout in every match.",
		TextSize = 12,
		TextWrapped = true,
		TextColor3 = C.Dim,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 30),
		Position = UDim2.fromOffset(0, 50),
		Parent = body,
	})

	-- rarity picker (used by the "give" buttons below)
	local picker = Create("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 30),
		Position = UDim2.fromOffset(0, 86),
		Parent = body,
	}, { Create.list(Enum.FillDirection.Horizontal, 5) })
	for i, name in Rarity.Order do
		local b = Widgets.button(name, {
			size = UDim2.fromOffset(84, 28),
			color = C.Panel3,
			textSize = 12,
			layoutOrder = i,
			onClick = function()
				rarity = name
				refreshPickers()
			end,
			parent = picker,
		})
		b.Name = "Rarity_" .. name
		rarityButtons[name] = b
	end
	shinyButton = Widgets.button("✨ Shiny: OFF", {
		size = UDim2.fromOffset(110, 28),
		color = C.Panel3,
		textSize = 12,
		layoutOrder = 10,
		onClick = function()
			shiny = not shiny
			refreshPickers()
		end,
		parent = picker,
	})
	shinyButton.Name = "Shiny"

	local scroll = Create("ScrollingFrame", {
		Name = "Tools",
		BackgroundColor3 = C.Panel,
		BackgroundTransparency = 0.3,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 1, -124),
		Position = UDim2.fromOffset(0, 124),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		Parent = body,
	}, { Create.corner(8), Create.padding(10, 8), Create.list(Enum.FillDirection.Vertical, 6) })

	local s = section(scroll, "COINS & COFFERS")
	button(s, "Coins_1000", "+1,000 coins", function()
		invoke("Coins", { amount = 1000 })
	end)
	button(s, "Coins_100000", "+100,000 coins", function()
		invoke("Coins", { amount = 100000 })
	end)
	button(s, "Coins_0", "Coins = 0", function()
		invoke("Coins", { amount = 0 })
	end)
	toggle(s, "FreeCoffers", "Free coffers", "FreeCoffers")

	s = section(scroll, "COSMETICS (USE THE RARITY PICKER ABOVE)")
	button(s, "GiveParts", "Give 6 parts", function()
		invoke("GiveParts", { rarity = rarity })
	end)
	button(s, "GiveOutfit", "Wear an outfit", function()
		invoke("GiveOutfit", { rarity = rarity })
	end)
	button(s, "GiveFamiliars", "Every familiar", function()
		invoke("GiveFamiliars", { rarity = rarity, shiny = shiny })
	end)

	s = section(scroll, "KITS")
	button(s, "Kits_all", "Unlock every kit", function()
		invoke("Kits", { mode = "all" })
	end)
	button(s, "Kits_normal", "Kits: normal", function()
		invoke("Kits", { mode = "normal" })
	end)
	button(s, "Kits_locked", "Lock (test the shop)", function()
		invoke("Kits", { mode = "locked" })
	end)

	s = section(scroll, "FIGHTING")
	toggle(s, "Loadout", "Full loadout", "Loadout")
	toggle(s, "God", "God mode", "God")
	toggle(s, "Mana", "Infinite mana", "Mana")
	button(s, "GiveWand", "Give a wand", function()
		invoke("GiveWand", { rarity = rarity })
	end)

	s = section(scroll, "MATCH")
	button(s, "StartMatch", "Start a match now", function()
		invoke("StartMatch", {})
	end, C.Accent)
	button(s, "Skip", "Skip the wait", function()
		invoke("Skip", {})
	end)
	button(s, "Advance", "+60s (refill, storm)", function()
		invoke("Advance", { seconds = 60 })
	end)
	button(s, "EndMatch", "End the match", function()
		invoke("EndMatch", {})
	end, C.Bad)
	for _, fill in { 1, 4, 8, 12 } do
		button(s, "Bots_" .. fill, if fill == 1 then "No bots" else "Bots: fill to " .. fill, function()
			invoke("Bots", { fill = fill })
		end)
	end
	button(s, "KillBots", "Knock out bots", function()
		invoke("KillBots", {})
	end)
	button(s, "Refill", "Refill chests", function()
		invoke("Refill", {})
	end)

	s = section(scroll, "MARKET & PROFILE")
	button(s, "FakeListings", "Test Merchant items", function()
		invoke("FakeListings", {})
	end)
	local reset: TextButton
	reset = button(s, "ResetProfile", "Reset my profile", function()
		if not confirmReset then
			confirmReset = true
			reset.Text = "Really reset?"
			task.delay(3, function()
				confirmReset = false
				reset.Text = "Reset my profile"
			end)
			return
		end
		confirmReset = false
		reset.Text = "Reset my profile"
		if invoke("ResetProfile", {}) then
			syncStatus()
		end
	end, C.Bad)

	s = section(scroll, "GIVE A PREMADE SPELL (TO YOUR BAG)", 196)
	local list = table.clone(PremadeSpells.List)
	table.sort(list, function(a, b)
		local ra, rb = Rarity.rank(a.rarity), Rarity.rank(b.rarity)
		if ra ~= rb then
			return ra < rb
		end
		return a.name < b.name
	end)
	for _, spell in list do
		local b = button(s, "Spell_" .. spell.id, spell.name, function()
			invoke("GiveSpell", { id = spell.id })
		end)
		b.TextColor3 = Theme.rarity(spell.rarity)
	end
	refreshPickers()
end

function DevController.open()
	if not player:GetAttribute("Dev") then
		return
	end
	panel.Visible = true
	State.setMenu("dev", true)
	task.spawn(syncStatus)
end

function DevController.close()
	panel.Visible = false
	Widgets.hideTooltip()
	State.setMenu("dev", false)
end

function DevController.toggle()
	if panel.Visible then
		DevController.close()
	else
		DevController.open()
	end
end

function DevController.isOpen(): boolean
	return panel ~= nil and panel.Visible
end

function DevController.init()
	build()
	local function update()
		-- (tucked away while another window is open, so it never covers a close button)
		local busy = State.anyMenuOpen()
		openButton.Visible = player:GetAttribute("Dev") == true and not busy
	end
	player:GetAttributeChangedSignal("Dev"):Connect(update)
	State.MenusChanged:Connect(update)
	update()
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.Backquote and player:GetAttribute("Dev") then
			DevController.toggle()
		end
	end)
end

return DevController
