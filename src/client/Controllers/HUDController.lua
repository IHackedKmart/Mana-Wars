-- In-match HUD: health/shield, mana, wand hotbar with the spell deck, potions,
-- crosshair, match timer, banners, kill feed, toasts and the storm warning.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Consumables = require(Shared.Consumables)
local UI = script.Parent.Parent.UI
local Create = require(UI.Create)
local Theme = require(UI.Theme)
local Widgets = require(UI.Widgets)
local Dock = require(UI.Dock)
local ItemInfo = require(UI.ItemInfo)
local State = require(script.Parent.State)
local InputController = require(script.Parent.InputController)
local FXController = require(script.Parent.FXController)

local HUDController = {}

local player = Players.LocalPlayer
local C = Theme.Colors

local root: Frame
local combat: Frame
local spellbookButton: TextButton
local phaseTitle: TextLabel
local phaseSub: TextLabel
local bannerTitle: TextLabel
local bannerSub: TextLabel
local bannerToken = 0
local bigCount: TextLabel
local killFeed: Frame
local toastFrame: Frame
local healthBar: Widgets.Bar
local shieldFill: Frame
local manaBar: Widgets.Bar
local delayBar: Widgets.Bar
local hotbar: Frame
local deckRow: Frame
local potionRow: Frame
local crosshair: Frame
local hitmarker: Frame
local vignette: Frame
local stormWarning: TextLabel
local wandTitle: TextLabel

local castStart, castEnd = 0, 0

local function fmtTime(seconds: number): string
	seconds = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

function HUDController.banner(title: string, subtitle: string?, duration: number?)
	bannerToken += 1
	local token = bannerToken
	bannerTitle.Text = title
	bannerSub.Text = subtitle or ""
	bannerTitle.TextTransparency = 1
	bannerSub.TextTransparency = 1
	bannerTitle.Visible = true
	bannerSub.Visible = true
	TweenService:Create(bannerTitle, TweenInfo.new(0.25), { TextTransparency = 0 }):Play()
	TweenService:Create(bannerSub, TweenInfo.new(0.35), { TextTransparency = 0 }):Play()
	task.delay(duration or 3.5, function()
		if token ~= bannerToken then
			return
		end
		TweenService:Create(bannerTitle, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
		TweenService:Create(bannerSub, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
	end)
end

function HUDController.toast(text: string, color: Color3?)
	local label = Widgets.label({
		Text = text,
		Font = Theme.Bold,
		TextSize = 16,
		TextColor3 = color or C.Text,
		TextStrokeTransparency = 0.4,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 22),
		LayoutOrder = -math.floor(os.clock() * 100),
		Parent = toastFrame,
	})
	task.delay(2.5, function()
		TweenService:Create(label, TweenInfo.new(0.4), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		task.wait(0.45)
		label:Destroy()
	end)
	local labels = {}
	for _, child in toastFrame:GetChildren() do
		if child:IsA("TextLabel") then
			table.insert(labels, child)
		end
	end
	if #labels > 4 then
		table.sort(labels, function(a, b)
			return a.LayoutOrder > b.LayoutOrder
		end)
		labels[1]:Destroy()
	end
end

local function addKill(text: string, color: Color3?)
	local entry = Widgets.panel({
		Size = UDim2.new(1, 0, 0, 28),
		BackgroundColor3 = Color3.fromRGB(20, 17, 30),
		BackgroundTransparency = 0.25,
		LayoutOrder = -math.floor(os.clock() * 100),
		Parent = killFeed,
	})
	Create.padding(8, 0).Parent = entry
	Widgets.label({
		Text = text,
		RichText = true,
		TextSize = 14,
		Font = Theme.Bold,
		TextColor3 = color or C.Text,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = entry,
	})
	task.delay(7, function()
		entry:Destroy()
	end)
	local count = 0
	for _, child in killFeed:GetChildren() do
		if child:IsA("Frame") then
			count += 1
		end
	end
	if count > 6 then
		local oldest, order = nil, math.huge
		for _, child in killFeed:GetChildren() do
			if child:IsA("Frame") and -child.LayoutOrder < order then
				oldest, order = child, -child.LayoutOrder
			end
		end
		if oldest then
			oldest:Destroy()
		end
	end
end

local function escape(text: string): string
	return (text:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
end

---------------------------------------------------------------------------
-- Build
---------------------------------------------------------------------------

local function buildTop()
	local top = Widgets.panel({
		Name = "PhasePanel",
		Size = UDim2.fromOffset(440, 56),
		Position = UDim2.new(0.5, 0, 0, 10),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = C.Background,
		BackgroundTransparency = 0.12,
		Parent = root,
	})
	local topStroke = top:FindFirstChildOfClass("UIStroke") :: UIStroke
	topStroke.Color = C.GoldDeep
	topStroke.Transparency = 0.2
	phaseTitle = Widgets.label({
		Size = UDim2.new(1, 0, 0, 28),
		Position = UDim2.fromOffset(0, 5),
		Font = Theme.Black,
		TextSize = 20,
		TextColor3 = C.Gold,
		TextStrokeTransparency = 0.7,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = top,
	})
	phaseSub = Widgets.label({
		Size = UDim2.new(1, 0, 0, 18),
		Position = UDim2.fromOffset(0, 32),
		TextSize = 14,
		TextColor3 = C.Dim,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = top,
	})

	bannerTitle = Widgets.label({
		Size = UDim2.new(1, 0, 0, 56),
		Position = UDim2.fromScale(0, 0.2),
		Font = Theme.Black,
		TextSize = 44,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextStrokeTransparency = 0.3,
		TextColor3 = C.Gold,
		Visible = false,
		Parent = root,
	})
	bannerSub = Widgets.label({
		Size = UDim2.new(1, 0, 0, 26),
		Position = UDim2.new(0, 0, 0.2, 58),
		Font = Theme.Bold,
		TextSize = 20,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextStrokeTransparency = 0.4,
		Visible = false,
		Parent = root,
	})
	bigCount = Widgets.label({
		Size = UDim2.fromOffset(200, 140),
		Position = UDim2.fromScale(0.5, 0.42),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Font = Theme.Black,
		TextSize = 120,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextStrokeTransparency = 0.2,
		Visible = false,
		Parent = root,
	})

	killFeed = Create("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(380, 220),
		Position = UDim2.new(1, -16, 0.36, 0), -- below the Roblox player list
		AnchorPoint = Vector2.new(1, 0),
		Parent = root,
	}, { Create.list(Enum.FillDirection.Vertical, 4, Enum.HorizontalAlignment.Right) })

	toastFrame = Create("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(600, 120),
		Position = UDim2.new(0.5, 0, 1, -250),
		AnchorPoint = Vector2.new(0.5, 1),
		Parent = root,
	}, { Create.list(Enum.FillDirection.Vertical, 2, Enum.HorizontalAlignment.Center) })
	local layout = toastFrame:FindFirstChildOfClass("UIListLayout") :: UIListLayout
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom

	stormWarning = Widgets.label({
		Size = UDim2.new(1, 0, 0, 30),
		Position = UDim2.fromOffset(0, 74),
		Text = "⚠ You are in the Mana Storm! Get back inside the circle!",
		Font = Theme.Black,
		TextSize = 22,
		TextColor3 = Color3.fromRGB(255, 120, 200),
		TextStrokeTransparency = 0.3,
		TextXAlignment = Enum.TextXAlignment.Center,
		Visible = false,
		Parent = root,
	})

	local dock = Dock.get()
	spellbookButton = Widgets.button("📖  Spellbook   [B]", {
		size = UDim2.fromOffset(Dock.WIDTH, 38),
		color = Color3.fromRGB(70, 52, 120),
		layoutOrder = 1,
		onClick = function()
			if InputController.onToggleInventory then
				InputController.onToggleInventory()
			end
		end,
		parent = dock,
	})
	spellbookButton.Name = "SpellbookButton"
	Widgets.button("📜  Grimoire   [H]", {
		size = UDim2.fromOffset(Dock.WIDTH, 38),
		color = Color3.fromRGB(116, 82, 40),
		layoutOrder = 2,
		onClick = function()
			if InputController.onToggleGrimoire then
				InputController.onToggleGrimoire()
			end
		end,
		parent = dock,
	}).Name =
		"GrimoireButton"
end

local function buildCombat()
	-- health
	local healthPanel = Widgets.panel({
		Size = UDim2.fromOffset(310, 64),
		Position = UDim2.new(0, 16, 1, -16),
		AnchorPoint = Vector2.new(0, 1),
		BackgroundColor3 = C.Background,
		BackgroundTransparency = 0.15,
		Parent = combat,
	})
	Widgets.label({
		Text = "❤  HEALTH",
		Font = Theme.Black,
		TextSize = 12,
		TextColor3 = C.Dim,
		Size = UDim2.fromOffset(200, 16),
		Position = UDim2.fromOffset(12, 6),
		Parent = healthPanel,
	})
	healthBar = Widgets.bar(C.Health, UDim2.new(1, -24, 0, 26), healthPanel)
	healthBar.frame.Position = UDim2.fromOffset(12, 26)
	shieldFill = Create("Frame", {
		BackgroundColor3 = C.Shield,
		BackgroundTransparency = 0.25,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0, 1),
		ZIndex = 2,
		Parent = healthBar.frame,
	}, { Create.corner(6) })

	-- wand hotbar + deck
	local bottom = Create("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(640, 150),
		Position = UDim2.new(0.5, 0, 1, -12),
		AnchorPoint = Vector2.new(0.5, 1),
		Parent = combat,
	})
	wandTitle = Widgets.label({
		Size = UDim2.new(1, 0, 0, 18),
		Position = UDim2.fromOffset(0, 0),
		Font = Theme.Bold,
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextStrokeTransparency = 0.5,
		Parent = bottom,
	})
	deckRow = Create("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 36),
		Position = UDim2.fromOffset(0, 20),
		Parent = bottom,
	}, { Create.list(Enum.FillDirection.Horizontal, 4, Enum.HorizontalAlignment.Center) })
	manaBar = Widgets.bar(C.Mana, UDim2.fromOffset(380, 16), bottom)
	manaBar.frame.Position = UDim2.new(0.5, 0, 0, 60)
	manaBar.frame.AnchorPoint = Vector2.new(0.5, 0)
	delayBar = Widgets.bar(Color3.fromRGB(230, 230, 255), UDim2.fromOffset(380, 5), bottom)
	delayBar.frame.Position = UDim2.new(0.5, 0, 0, 79)
	delayBar.frame.AnchorPoint = Vector2.new(0.5, 0)
	hotbar = Create("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 56),
		Position = UDim2.new(0, 0, 1, 0),
		AnchorPoint = Vector2.new(0, 1),
		Parent = bottom,
	}, { Create.list(Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Center) })

	-- potions
	potionRow = Create("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(260, 60),
		Position = UDim2.new(1, -16, 1, -16),
		AnchorPoint = Vector2.new(1, 1),
		Parent = combat,
	}, { Create.list(Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Right) })

	-- crosshair
	crosshair = Create("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(26, 26),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Parent = root,
	})
	Create("Frame", {
		Size = UDim2.fromOffset(4, 4),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		Parent = crosshair,
	}, { Create.corner(4) })
	Create("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = crosshair,
	}, { Create.corner(100), Create.stroke(Color3.new(1, 1, 1), 1.5, 0.35) })
	hitmarker = Create("Frame", {
		Size = UDim2.fromOffset(34, 34),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = crosshair,
	}, { Create.corner(100), Create.stroke(Color3.fromRGB(255, 90, 90), 3, 0) })

	-- hurt vignette: four gradient edges
	vignette =
		Create("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false, Parent = root })
	local function edge(size: UDim2, pos: UDim2, rotation: number)
		Create("Frame", {
			Size = size,
			Position = pos,
			BackgroundColor3 = Color3.fromRGB(200, 0, 20),
			BorderSizePixel = 0,
			Parent = vignette,
		}, {
			Create("UIGradient", {
				Rotation = rotation,
				Transparency = NumberSequence.new(0.2, 1),
			}),
		})
	end
	edge(UDim2.fromScale(1, 0.18), UDim2.fromScale(0, 0), 90)
	edge(UDim2.fromScale(1, 0.18), UDim2.fromScale(0, 0.82), -90)
	edge(UDim2.fromScale(0.12, 1), UDim2.fromScale(0, 0), 0)
	edge(UDim2.fromScale(0.12, 1), UDim2.fromScale(0.88, 0), 180)
end

---------------------------------------------------------------------------
-- Refresh
---------------------------------------------------------------------------

-- The equipped wand's spells, highlighting the one that fires next. Cheap enough to redo every cast.
local function refreshDeck()
	Widgets.clear(deckRow, true)
	local wand = State.equippedWand()
	wandTitle.Text = if wand then wand.name else "No wand - find one in a chest!"
	wandTitle.TextColor3 = if wand then Theme.rarity(wand.rarity) else C.Dim
	if not wand then
		return
	end
	local w = State.wand
	local nextSlot = nil
	if w and w.uid == wand.uid and w.order and #w.order > 0 then
		nextSlot = w.order[math.clamp(w.deckPos, 1, #w.order)]
	end
	for si = 1, wand.stats.capacity do
		local spell = wand.slots[si]
		if spell then
			local icon, color = ItemInfo.spellVisual(spell.recipe)
			Widgets.tile({
				size = 34,
				icon = icon,
				iconColor = color,
				border = Theme.rarity(spell.rarity),
				highlight = si == nextSlot,
				layoutOrder = si,
				info = function()
					return ItemInfo.spell(spell, wand)
				end,
				parent = deckRow,
			})
		else
			Widgets.tile({ size = 34, empty = true, layoutOrder = si, parent = deckRow })
		end
	end
end

local function refreshHotbar()
	Widgets.clear(hotbar, true)
	Widgets.clear(potionRow, true)
	refreshDeck()
	local inv = State.inventory
	if not inv then
		return
	end
	for i = 1, Config.Inventory.MaxWands do
		local wand = inv.wands[i]
		local card = Widgets.panel({
			Size = UDim2.fromOffset(148, 54),
			BackgroundColor3 = if wand and inv.equipped == i then C.Panel3 else C.Panel,
			BackgroundTransparency = if wand then 0.1 else 0.5,
			LayoutOrder = i,
			Parent = hotbar,
		})
		local stroke = card:FindFirstChildOfClass("UIStroke") :: UIStroke
		if wand then
			stroke.Color = if inv.equipped == i then C.Gold else Theme.rarity(wand.rarity)
			stroke.Thickness = if inv.equipped == i then 2.5 else 1.5
			stroke.Transparency = 0
			Widgets.tile({
				size = 42,
				wandColor = Theme.rgb(wand.color),
				gemColor = Theme.rarity(wand.rarity),
				border = Theme.rarity(wand.rarity),
				parent = card,
			}).Position =
				UDim2.fromOffset(6, 6)
			Widgets.label({
				Text = wand.name,
				Font = Theme.Bold,
				TextSize = 12,
				TextWrapped = true,
				TextColor3 = Theme.rarity(wand.rarity),
				Size = UDim2.fromOffset(92, 40),
				Position = UDim2.fromOffset(52, 7),
				TextYAlignment = Enum.TextYAlignment.Top,
				Parent = card,
			})
		end
		Widgets.label({
			Text = tostring(i),
			Font = Theme.Black,
			TextSize = 12,
			TextColor3 = C.Dim,
			Size = UDim2.fromOffset(14, 14),
			Position = UDim2.new(1, -14, 1, -15),
			Parent = card,
		})
		local click = Create("TextButton", {
			BackgroundTransparency = 1,
			Text = "",
			Size = UDim2.fromScale(1, 1),
			ZIndex = 5,
			Parent = card,
		})
		click.Activated:Connect(function()
			InputController.equip(i)
		end)
		if wand then
			Widgets.attachTooltip(click, function()
				return ItemInfo.wand(wand)
			end)
		end
	end

	for i, c in Consumables.List do
		local count = inv.consumables[c.id] or 0
		local tile = Widgets.tile({
			size = 54,
			icon = c.icon,
			iconColor = Theme.rgb(c.color),
			border = Theme.rarity(c.rarity),
			count = count,
			empty = count <= 0,
			corner = c.key,
			layoutOrder = i,
			onClick = function()
				InputController.usePotion(c.id)
			end,
			info = function()
				return ItemInfo.consumable(c.id)
			end,
			parent = potionRow,
		})
		if count == 1 then
			Widgets.label({
				Text = "x1",
				Font = Theme.Black,
				TextSize = 12,
				TextXAlignment = Enum.TextXAlignment.Right,
				Size = UDim2.fromOffset(48, 14),
				Position = UDim2.new(0, 2, 1, -15),
				TextStrokeTransparency = 0.3,
				ZIndex = 3,
				Parent = tile,
			})
		end
	end
end

local function plural(n: number, word: string): string
	return n .. " " .. word .. (if n == 1 then "" else "s")
end

local function updatePhase()
	local phase = State.phase()
	local now = State.now()
	local remaining = State.phaseEndsAt() - now
	local alive = ReplicatedStorage:GetAttribute("AliveCount") or 0
	local queued = tonumber(ReplicatedStorage:GetAttribute("QueueCount")) or 0
	local start = ReplicatedStorage:GetAttribute("MatchStartedAt") or now
	local running = phase == "Countdown" or phase == "Grace" or phase == "Battle"
	bigCount.Visible = false

	-- In the hub: what's going on, and whether it's worth joining right now
	if State.inHub() then
		if phase == "Voting" then
			phaseTitle.Text = "Match starting in " .. fmtTime(remaining)
			phaseSub.Text = plural(queued, "mage") .. " in the queue · join through the portal!"
		elseif phase == "Loading" or running then
			phaseTitle.Text = "Match in progress"
			phaseSub.Text = plural(alive, "mage") .. " alive · join the queue for the next one"
		elseif phase == "Ended" then
			phaseTitle.Text = "Match over"
			phaseSub.Text = "Join the queue for the next one"
		else
			phaseTitle.Text = "Arcanum Plaza"
			phaseSub.Text = "Practise freely · walk through the portal to start a match"
		end
		return
	end

	if phase == "Waiting" then
		phaseTitle.Text = "In the queue"
		phaseSub.Text = "Waiting for more players to join"
	elseif phase == "Voting" then
		phaseTitle.Text = "Map vote  " .. fmtTime(remaining)
		phaseSub.Text = "Vote on the right · " .. plural(queued, "mage") .. " in the queue"
	elseif phase == "Loading" then
		phaseTitle.Text = "Building "
			.. tostring(ReplicatedStorage:GetAttribute("NextMapName") or "the island")
			.. "..."
		phaseSub.Text = "The match is about to begin"
	elseif phase == "Countdown" then
		phaseTitle.Text = "Get ready!"
		phaseSub.Text = alive .. " mages on the pedestals"
		if State.inMatch() then
			bigCount.Visible = remaining > 0
			bigCount.Text = tostring(math.ceil(remaining))
		end
	elseif phase == "Grace" then
		phaseTitle.Text = "Grace period " .. fmtTime(remaining)
		phaseSub.Text = alive .. " mages alive · no PvP yet!"
	elseif phase == "Battle" then
		local stormIn = start + Config.Match.StormStartAt - now
		local refillIn = start + Config.Match.ChestRefillAt - now
		if ReplicatedStorage:GetAttribute("StormActive") then
			phaseTitle.Text = "The Mana Storm is closing"
		else
			phaseTitle.Text = "Storm in " .. fmtTime(stormIn)
		end
		local extra = if refillIn > 0 then " · chest refill in " .. fmtTime(refillIn) else ""
		phaseSub.Text = alive .. " mages alive" .. extra
	elseif phase == "Ended" then
		phaseTitle.Text = "Match over"
		phaseSub.Text = "Back to the library in " .. fmtTime(remaining)
	end
	if running and not State.inMatch() then
		-- queued, but this match started without you
		phaseSub.Text = plural(alive, "mage") .. " alive · waiting for the next match"
	end
end

local function updateCombat()
	local active = State.canAct()
	combat.Visible = active
	spellbookButton.Visible = active
	crosshair.Visible = active and not State.anyMenuOpen()
	if not active then
		stormWarning.Visible = false
		return
	end
	local character = player.Character
	local hum = character and character:FindFirstChildOfClass("Humanoid")
	if hum then
		healthBar.set(hum.Health / math.max(1, hum.MaxHealth))
		healthBar.label.Text = math.ceil(hum.Health) .. " / " .. math.floor(hum.MaxHealth)
		local bubble = character and character:FindFirstChild("ShieldBubble")
		shieldFill.Visible = bubble ~= nil
		shieldFill.Size = UDim2.fromScale(if bubble then 1 else 0, 1)
	end

	local mana, max = State.mana()
	manaBar.set(mana / max)
	manaBar.label.Text = math.floor(mana) .. " / " .. math.floor(max)
	local now = State.now()
	local w = State.wand
	if w then
		if now >= castEnd or castEnd <= castStart then
			delayBar.set(1)
			delayBar.fill.BackgroundColor3 = Color3.fromRGB(230, 230, 255)
		else
			delayBar.set((now - castStart) / (castEnd - castStart))
			delayBar.fill.BackgroundColor3 = if now < w.rechargeUntil
				then Color3.fromRGB(255, 190, 90)
				else Color3.fromRGB(230, 230, 255)
		end
	end

	-- convert viewport pixels into the scaled root's coordinate space
	local screen = InputController.aimScreenPoint()
	local scale = (root:FindFirstChildOfClass("UIScale") :: UIScale).Scale
	crosshair.Position = UDim2.fromOffset(screen.X / scale, screen.Y / scale)

	local root3 = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root3 and State.alive() and ReplicatedStorage:GetAttribute("StormActive") then
		local center = ReplicatedStorage:GetAttribute("StormCenter") or Vector3.zero
		local radius = ReplicatedStorage:GetAttribute("StormRadius") or 1e5
		local d = Vector3.new(root3.Position.X - center.X, 0, root3.Position.Z - center.Z).Magnitude
		stormWarning.Visible = d > radius
	else
		stormWarning.Visible = false
	end
end

function HUDController.init()
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
	end)
	-- the menu dock steps aside while a window is open
	State.MenusChanged:Connect(function()
		Dock.setVisible(not State.anyMenuOpen())
	end)

	local gui = Widgets.screen("HUD", 1)
	root = Widgets.scaledRoot(gui)
	combat = Create(
		"Frame",
		{ Name = "Combat", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false, Parent = root }
	)
	buildTop()
	buildCombat()
	refreshHotbar()

	State.InventoryChanged:Connect(refreshHotbar)
	State.WandChanged:Connect(function()
		local w = State.wand
		if w and w.nextCastAt > State.now() then
			castStart = State.now()
			castEnd = w.nextCastAt
		end
		refreshDeck()
	end)
	State.Toast:Connect(function(text, color)
		HUDController.toast(text, color)
	end)

	FXController.Hurt:Connect(function(amount: number)
		if amount <= 0 then
			return
		end
		vignette.Visible = true
		for _, edge in vignette:GetChildren() do
			if edge:IsA("Frame") then
				edge.BackgroundTransparency = 0
				TweenService:Create(edge, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
			end
		end
	end)
	FXController.Hit:Connect(function()
		hitmarker.Visible = true
		task.delay(0.12, function()
			hitmarker.Visible = false
		end)
	end)

	Remotes.event("Announce").OnClientEvent:Connect(function(kind, data)
		if type(data) ~= "table" then
			return
		end
		if kind == "Banner" then
			HUDController.banner(tostring(data.title or ""), data.subtitle and tostring(data.subtitle) or nil)
		elseif kind == "Kill" then
			local victim = escape(tostring(data.victim or "?"))
			local text
			if data.left then
				text = victim .. " left the match"
			elseif data.killer then
				local spell = if data.spell
					then ' <font color="#a99bd0">(' .. escape(tostring(data.spell)) .. ")</font>"
					else ""
				text = '<font color="#ffcf5a">'
					.. escape(tostring(data.killer))
					.. "</font> eliminated "
					.. victim
					.. spell
			elseif data.spell == "the Mana Storm" then
				text = victim .. " was consumed by the Mana Storm"
			else
				text = victim .. " was eliminated"
			end
			addKill(text)
			if data.victim == player.DisplayName then
				HUDController.banner(
					"You were eliminated",
					if data.killer then "by " .. tostring(data.killer) else nil,
					4
				)
			end
		elseif kind == "Winner" then
			if data.name then
				local you = data.name == player.DisplayName and State.inMatch()
				HUDController.banner(
					if you then "🏆 VICTORY! 🏆" else "🏆 " .. tostring(data.name) .. " wins!",
					tostring(data.kills or 0) .. " eliminations",
					8
				)
			else
				HUDController.banner("No winner this time", "The Mana Storm claims everyone", 8)
			end
		end
	end)

	RunService.RenderStepped:Connect(function()
		updatePhase()
		updateCombat()
	end)
end

return HUDController
