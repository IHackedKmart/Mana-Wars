-- Out-of-match UI for the hub (Arcanum Plaza) and the library (Arcane Athenaeum): Play (the game mode menu) /
-- Leave queue, the kit shop / class picker, the map vote, spectating, the lectern/altar
-- prompts, and the animated props (orrery, floating books, the fountain crystal, floating isles).

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Remotes = require(Shared.Remotes)
local Config = require(Shared.Config)
local Classes = require(Shared.Classes)
local Modes = require(Shared.Modes)
local Consumables = require(Shared.Consumables)
local SpellParts = require(Shared.Spells.SpellParts)
local PremadeSpells = require(Shared.Spells.PremadeSpells)
local UI = script.Parent.Parent.UI
local Create = require(UI.Create)
local Theme = require(UI.Theme)
local Widgets = require(UI.Widgets)
local Dock = require(UI.Dock)
local ItemInfo = require(UI.ItemInfo)
local State = require(script.Parent.State)
local Sounds = require(script.Parent.Sounds)

local LobbyController = {}

LobbyController.onOpenGrimoire = nil :: (() -> ())?
LobbyController.onOpenWardrobe = nil :: ((tab: string?) -> ())?
LobbyController.onOpenAuction = nil :: (() -> ())?
LobbyController.onOpenAchievements = nil :: (() -> ())?
LobbyController.onOpenModes = nil :: (() -> ())?

local C = Theme.Colors
local player = Players.LocalPlayer
local classAction = Remotes.func("ClassAction")

local gui: ScreenGui
local root: Frame
local classPanel: Frame
local classGrid: ScrollingFrame
local classButton: TextButton
local wardrobeButton: TextButton
local auctionButton: TextButton
local achievementsButton: TextButton
local coinsPill: TextLabel
local spectateBar: Frame
local spectateName: TextLabel
local spectateButton: TextButton
local spectating = false
local spectateIndex = 1
local joinButton: TextButton
local leaveButton: TextButton
local modeButton: TextButton
local votePanel: Frame
local voteList: Frame
local voteTimer: TextLabel
local voteState: { [string]: any } = { open = false }
local myVote: string? = nil

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
	local tier = Classes.tierInfo(class.tier)
	local allowed = Players.LocalPlayer:GetAttribute("PaidRandomAllowed") == true
	table.insert(
		lines,
		if Classes.bonusAllowed(class.tier, allowed)
			then "Bonus: 1 random spell part each match (" .. Classes.oddsText(class.tier) .. ")"
			else "Bonus: no random spell part (not offered in your region)"
	)
	return {
		title = class.icon .. " " .. class.name,
		color = Theme.rgb(class.color),
		subtitle = if class.tier == 0
			then "Free kit"
			else tier.name .. " kit · R$" .. tier.robux .. " (about " .. tier.usd .. ")",
		body = class.tagline .. "\n\nStarting kit:\n" .. table.concat(lines, "\n"),
	}
end

local function ownedKits(): { [string]: boolean }
	local set: { [string]: boolean } = {}
	for id in string.gmatch(tostring(player:GetAttribute("OwnedKits") or ""), "[^,]+") do
		set[id] = true
	end
	set[Classes.Default] = true
	return set
end

local function kitCard(class: Classes.ClassDef, owned: boolean, isCurrent: boolean, order: number, parent: Instance)
	local tier = Classes.tierInfo(class.tier)
	local card = Create("TextButton", {
		Name = "Kit_" .. class.id,
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = if isCurrent then C.Panel3 else C.Panel2,
		Size = UDim2.fromOffset(210, 112),
		LayoutOrder = order,
		Parent = parent,
	}, {
		Create.corner(10),
		Create.stroke(
			if isCurrent then C.Gold else Theme.rgb(class.color),
			if isCurrent then 3 else 1.5,
			if owned then 0 else 0.5
		),
	})
	Widgets.label({
		Text = class.icon,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.fromOffset(40, 40),
		Position = UDim2.fromOffset(8, 8),
		Parent = card,
	})
	Widgets.label({
		Text = class.name,
		Font = Theme.Black,
		TextSize = 16,
		TextColor3 = Theme.rgb(class.color),
		Size = UDim2.new(1, -60, 0, 20),
		Position = UDim2.fromOffset(54, 8),
		Parent = card,
	})
	Widgets.label({
		Name = "Status",
		Text = if isCurrent
			then "✅ SELECTED"
			elseif owned then (if class.tier == 0 then "FREE" else "OWNED · click to pick")
			else "🛒 R$" .. tier.robux .. "  (" .. tier.usd .. ")",
		Font = Theme.Bold,
		TextSize = 12,
		TextColor3 = if isCurrent then C.Gold elseif owned then C.Good else Theme.rgb(tier.color),
		Size = UDim2.new(1, -60, 0, 16),
		Position = UDim2.fromOffset(54, 30),
		Parent = card,
	})
	Widgets.label({
		Text = class.tagline,
		TextSize = 12,
		TextWrapped = true,
		TextColor3 = if owned then C.Text else C.Dim,
		TextYAlignment = Enum.TextYAlignment.Top,
		Size = UDim2.new(1, -16, 0, 52),
		Position = UDim2.fromOffset(8, 54),
		Parent = card,
	})
	Widgets.attachTooltip(card, function()
		return kitInfo(class)
	end)
	card.Activated:Connect(function()
		Sounds.play("Click")
		local ok, success, message = pcall(function()
			return classAction:InvokeServer(if owned then "Select" else "Buy", class.id)
		end)
		if ok and message then
			State.toast(message, if success then C.Good else C.Bad)
		end
	end)
end

local function renderClasses()
	Widgets.clear(classGrid, true)
	local owned = ownedKits()
	local current = player:GetAttribute("Class")
	local order = 0
	for tierIndex = 0, #Classes.Tiers - 1 do
		local tier = Classes.tierInfo(tierIndex)
		order += 1
		local row = Create("Frame", {
			Name = "Tier_" .. tier.name,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -12, 0, 116),
			LayoutOrder = order,
			Parent = classGrid,
		})
		Widgets.label({
			Text = string.upper(tier.name) .. (if tier.id == 0 then "" else " CIRCLE"),
			Font = Theme.Black,
			TextSize = 18,
			TextColor3 = Theme.rgb(tier.color),
			Size = UDim2.fromOffset(220, 22),
			Position = UDim2.fromOffset(4, 6),
			Parent = row,
		})
		Widgets.label({
			Text = if tier.robux > 0
				then "R$" .. tier.robux .. " each  ·  about " .. tier.usd
				else "Free for everyone",
			Font = Theme.Bold,
			TextSize = 13,
			TextColor3 = C.Text,
			Size = UDim2.fromOffset(220, 18),
			Position = UDim2.fromOffset(4, 30),
			Parent = row,
		})
		Widgets.label({
			Name = "BonusOdds",
			Text = "Bonus part each match:\n"
				.. Classes.bonusText(tier.id, player:GetAttribute("PaidRandomAllowed") == true),
			TextSize = 11,
			TextWrapped = true,
			TextColor3 = C.Dim,
			TextYAlignment = Enum.TextYAlignment.Top,
			Size = UDim2.fromOffset(220, 60),
			Position = UDim2.fromOffset(4, 52),
			Parent = row,
		})
		local cards = Create("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -236, 1, 0),
			Position = UDim2.fromOffset(232, 0),
			Parent = row,
		}, { Create.list(Enum.FillDirection.Horizontal, 10) })
		local n = 0
		for _, class in Classes.List do
			if class.tier == tierIndex then
				n += 1
				kitCard(class, owned[class.id] == true, current == class.id, n, cards)
			end
		end
	end
end

local function setKitShop(visible: boolean)
	classPanel.Visible = visible
	State.setMenu("kits", visible)
	if visible then
		renderClasses()
	end
end

local function buildClassPanel()
	local kitGui = Widgets.screen("KitShop", 8)
	local window = Widgets.window(kitGui, {
		title = "Choose Your Kit",
		icon = "🎓",
		subtitle = "Your kit decides the wands, spells and parts you start with, plus a random bonus part each match. Hover a kit to see everything in it.",
		size = Vector2.new(960, 600),
		onClose = function()
			setKitShop(false)
		end,
	})
	classPanel = window.root
	classPanel.Visible = false
	classGrid = Create("ScrollingFrame", {
		Name = "KitList",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 1, -28),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		Parent = window.body,
	}, { Create.list(Enum.FillDirection.Vertical, 6), Create.padding(2, 2) })
	local premiumNote = if Config.Kits.PremiumFreeTier > 0
		then "  ·  Roblox Premium members get every " .. Classes.tierInfo(Config.Kits.PremiumFreeTier).name .. " kit free"
		else ""
	Widgets.label({
		Text = "Prices are in Robux; dollar amounts are approximate." .. premiumNote,
		TextSize = 12,
		TextColor3 = C.Dim,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 18),
		Position = UDim2.new(0, 0, 1, -18),
		Parent = window.body,
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
		spectateName.Text = "👁️ " .. (hum.DisplayName ~= "" and hum.DisplayName or target.Name)
	end
end

local function buildSpectate()
	spectateButton = Widgets.button("👁️  Spectate the match", {
		size = UDim2.fromOffset(Dock.WIDTH, 38),
		color = C.Panel3,
		layoutOrder = 4,
		onClick = function()
			setSpectate(true)
			updateSpectate()
		end,
		parent = Dock.get(),
	})
	spectateBar = Widgets.panel({
		Size = UDim2.fromOffset(420, 50),
		Position = UDim2.new(0.5, 0, 0, 74),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 0.15,
		Visible = false,
		Parent = root,
	})
	Widgets.button("◀️", {
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
	Widgets.button("▶️", {
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

---------------------------------------------------------------------------
-- Queue: Play (in the hub) / Leave queue and change mode (in the library)
---------------------------------------------------------------------------

local queueAction = Remotes.func("QueueAction")

local function queue(action: string)
	Sounds.play("Click")
	local ok, success, message = pcall(function()
		return queueAction:InvokeServer(action)
	end)
	if ok and type(message) == "string" then
		State.toast(message, if success then C.Good else C.Bad)
	end
end

local function buildQueue()
	joinButton = Widgets.button("▶️  PLAY", {
		size = UDim2.fromOffset(280, 46),
		position = UDim2.new(0.5, 0, 0, 74),
		anchor = Vector2.new(0.5, 0),
		color = Color3.fromRGB(196, 132, 36),
		textSize = 20,
		onClick = function()
			if LobbyController.onOpenModes then
				LobbyController.onOpenModes()
			end
		end,
		parent = root,
	})
	joinButton.Name = "JoinButton"
	Create.stroke(C.Gold, 2).Parent = joinButton
	leaveButton = Widgets.button("↩️  Leave queue (back to the Plaza)", {
		size = UDim2.fromOffset(280, 34),
		position = UDim2.new(0.5, 0, 0, 74),
		anchor = Vector2.new(0.5, 0),
		color = C.Panel3,
		textSize = 14,
		onClick = function()
			queue("Leave")
		end,
		parent = root,
	})
	leaveButton.Name = "LeaveButton"
	modeButton = Widgets.button("🔄  Change mode", {
		size = UDim2.fromOffset(280, 30),
		position = UDim2.new(0.5, 0, 0, 112),
		anchor = Vector2.new(0.5, 0),
		color = C.Panel2,
		textSize = 13,
		onClick = function()
			if LobbyController.onOpenModes then
				LobbyController.onOpenModes()
			end
		end,
		parent = root,
	})
	modeButton.Name = "ModeButton"
end

---------------------------------------------------------------------------
-- Map vote
---------------------------------------------------------------------------

local voteAction = Remotes.func("VoteAction")

local function renderVote()
	Widgets.clear(voteList, true)
	local options = voteState.options
	if not voteState.open or not options then
		return
	end
	local counts = voteState.counts or {}
	for i, option in options do
		local chosen = myVote == option.id
		local card = Create("TextButton", {
			Name = "Vote_" .. option.id,
			Text = "",
			AutoButtonColor = false,
			Size = UDim2.new(1, 0, 0, 84),
			BackgroundColor3 = if chosen then C.Panel3 else C.Panel2,
			LayoutOrder = i,
			Parent = voteList,
		}, {
			Create.corner(10),
			Create.stroke(if chosen then C.Gold else C.Stroke, if chosen then 3 else 1.5),
		})
		Widgets.label({
			Text = option.icon,
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Center,
			Size = UDim2.fromOffset(52, 52),
			Position = UDim2.fromOffset(8, 16),
			Parent = card,
		})
		Widgets.label({
			Text = option.name,
			Font = Theme.Black,
			TextSize = 17,
			TextColor3 = if chosen then C.Gold else C.Text,
			Size = UDim2.new(1, -140, 0, 22),
			Position = UDim2.fromOffset(68, 8),
			Parent = card,
		})
		Widgets.label({
			Text = option.description,
			TextSize = 12,
			TextColor3 = C.Dim,
			TextWrapped = true,
			TextYAlignment = Enum.TextYAlignment.Top,
			Size = UDim2.new(1, -80, 0, 48),
			Position = UDim2.fromOffset(68, 32),
			Parent = card,
		})
		local votes = counts[option.id] or 0
		Widgets.label({
			Text = votes .. (if votes == 1 then " vote" else " votes"),
			Font = Theme.Bold,
			TextSize = 13,
			TextColor3 = C.Gold,
			TextXAlignment = Enum.TextXAlignment.Right,
			Size = UDim2.fromOffset(70, 20),
			Position = UDim2.new(1, -78, 0, 9),
			Parent = card,
		})
		card.Activated:Connect(function()
			Sounds.play("Click")
			local ok, success = pcall(function()
				return voteAction:InvokeServer("Vote", option.id)
			end)
			if ok and success then
				myVote = option.id
				renderVote()
			end
		end)
	end
end

local function buildVote()
	votePanel = Widgets.panel({
		Name = "MapVote",
		Size = UDim2.fromOffset(330, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Position = UDim2.new(1, -16, 0, 74),
		AnchorPoint = Vector2.new(1, 0),
		BackgroundColor3 = C.Background,
		BackgroundTransparency = 0.1,
		Visible = false,
		Parent = root,
	})
	Create.padding(12, 10).Parent = votePanel
	Create.list(Enum.FillDirection.Vertical, 8).Parent = votePanel
	Widgets.label({
		Text = "🗳️  VOTE FOR THE NEXT MAP",
		Font = Theme.Black,
		TextSize = 16,
		TextColor3 = C.Gold,
		Size = UDim2.new(1, 0, 0, 20),
		LayoutOrder = 1,
		Parent = votePanel,
	})
	voteTimer = Widgets.label({
		Text = "",
		TextSize = 12,
		TextColor3 = C.Dim,
		Size = UDim2.new(1, 0, 0, 14),
		LayoutOrder = 2,
		Parent = votePanel,
	})
	voteList = Create("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 3,
		Parent = votePanel,
	}, { Create.list(Enum.FillDirection.Vertical, 8) })

	Remotes.event("VoteState").OnClientEvent:Connect(function(payload)
		if type(payload) ~= "table" then
			return
		end
		if payload.open and not voteState.open then
			myVote = nil -- a new vote has started
		end
		voteState = payload
		renderVote()
	end)
end

---------------------------------------------------------------------------
-- Ambience: spin the orrery rings and the crystals, bob the floating books, runes and isles
---------------------------------------------------------------------------

local function animate(placeName: string)
	local place = workspace:WaitForChild(placeName, 30)
	local animated = place and place:WaitForChild("Animated", 10)
	if not animated then
		return
	end
	local entries = {}
	for _, child in animated:GetChildren() do
		local spin = child:GetAttribute("Spin")
		local bob = child:GetAttribute("Bob")
		if spin or bob then
			local base = if child:IsA("Model")
				then child:GetPivot()
				elseif child:IsA("BasePart") then child.CFrame
				else nil
			if base then
				table.insert(entries, { inst = child, base = base, spin = spin, bob = bob })
			end
		end
	end
	local orreryCore = animated:FindFirstChild("OrreryCore") :: BasePart?
	local center = if orreryCore then orreryCore.Position else Vector3.zero
	RunService.RenderStepped:Connect(function()
		local t = os.clock()
		for _, e in entries do
			local cf: CFrame
			if e.bob then
				cf = e.base
					* CFrame.new(0, math.sin(t * 1.3 + e.bob) * 0.9, 0)
					* CFrame.Angles(0, math.sin(t * 0.4 + e.bob) * 0.3, 0)
			elseif e.inst:IsA("Model") then
				-- orrery rings turn around the orrery's centre
				local pivot = CFrame.new(center)
				cf = pivot * CFrame.Angles(0, t * e.spin, 0) * pivot:Inverse() * e.base
			else
				cf = e.base * CFrame.Angles(0, t * e.spin, 0)
			end
			if e.inst:IsA("Model") then
				e.inst:PivotTo(cf)
			else
				(e.inst :: BasePart).CFrame = cf
			end
		end
	end)
end

function LobbyController.init()
	gui = Widgets.screen("Lobby", 5)
	root = Widgets.scaledRoot(gui)
	buildClassPanel()
	buildSpectate()
	buildVote()
	buildQueue()
	task.spawn(animate, "Lobby")
	task.spawn(animate, "Hub")
	player:GetAttributeChangedSignal("Queued"):Connect(function()
		if not State.queued() then
			myVote = nil -- the server drops your vote when you leave the queue
		end
	end)

	-- lecterns open the Grimoire, the altar opens the class picker
	ProximityPromptService.PromptTriggered:Connect(function(prompt, who)
		if who ~= player then
			return
		end
		local action = prompt:GetAttribute("LobbyAction")
		if action == "Grimoire" and LobbyController.onOpenGrimoire then
			LobbyController.onOpenGrimoire()
		elseif action == "ClassPicker" then
			setKitShop(true)
		elseif action == "Wardrobe" and LobbyController.onOpenWardrobe then
			LobbyController.onOpenWardrobe("Tailor")
		elseif action == "Coffers" and LobbyController.onOpenWardrobe then
			LobbyController.onOpenWardrobe("Coffers")
		elseif action == "Auction" and LobbyController.onOpenAuction then
			LobbyController.onOpenAuction()
		end
	end)

	classButton = Widgets.button("🎓  Class: Apprentice", {
		size = UDim2.fromOffset(Dock.WIDTH, 38),
		color = C.Accent,
		layoutOrder = 3,
		onClick = function()
			setKitShop(not classPanel.Visible)
		end,
		parent = Dock.get(),
	})
	classButton.Name = "ClassButton"

	local function updateClassButton()
		local class = Classes.ById[tostring(player:GetAttribute("Class"))]
		if class then
			classButton.Text = class.icon .. "  Class: " .. class.name
		end
		if classPanel.Visible then
			renderClasses()
		end
	end
	-- the Tailor's Loom and the Auction House are only open in the Plaza
	wardrobeButton = Widgets.button("👘  Wardrobe & Coffers", {
		size = UDim2.fromOffset(Dock.WIDTH, 38),
		color = Color3.fromRGB(120, 50, 90),
		layoutOrder = 5,
		onClick = function()
			if LobbyController.onOpenWardrobe then
				LobbyController.onOpenWardrobe(nil)
			end
		end,
		parent = Dock.get(),
	})
	wardrobeButton.Name = "WardrobeButton"
	auctionButton = Widgets.button("⚖️  Auction House", {
		size = UDim2.fromOffset(Dock.WIDTH, 38),
		color = Color3.fromRGB(46, 92, 110),
		layoutOrder = 6,
		onClick = function()
			if LobbyController.onOpenAuction then
				LobbyController.onOpenAuction()
			end
		end,
		parent = Dock.get(),
	})
	auctionButton.Name = "AuctionButton"
	achievementsButton = Widgets.button("🏆  Achievements", {
		size = UDim2.fromOffset(Dock.WIDTH, 38),
		color = Color3.fromRGB(150, 110, 30),
		layoutOrder = 7,
		onClick = function()
			if LobbyController.onOpenAchievements then
				LobbyController.onOpenAchievements()
			end
		end,
		parent = Dock.get(),
	})
	achievementsButton.Name = "AchievementsButton"
	coinsPill = Widgets.label({
		Name = "CoinsPill",
		Text = "💰 0 Enchanted Coins",
		Font = Theme.Black,
		TextSize = 16,
		TextColor3 = C.Gold,
		TextXAlignment = Enum.TextXAlignment.Center,
		BackgroundColor3 = C.Ink,
		BackgroundTransparency = 0.3,
		Size = UDim2.fromOffset(Dock.WIDTH, 32),
		LayoutOrder = 8,
		Parent = Dock.get(),
	})
	Create.corner(16).Parent = coinsPill
	Create.stroke(C.GoldDeep, 1.5, 0.3).Parent = coinsPill
	local function updateCoins()
		coinsPill.Text = "💰 " .. tostring(player:GetAttribute("Coins") or 0) .. " Enchanted Coins"
	end
	player:GetAttributeChangedSignal("Coins"):Connect(updateCoins)
	updateCoins()

	player:GetAttributeChangedSignal("Class"):Connect(updateClassButton)
	player:GetAttributeChangedSignal("OwnedKits"):Connect(updateClassButton)
	player:GetAttributeChangedSignal("PaidRandomAllowed"):Connect(updateClassButton)
	updateClassButton()

	local lastTarget = 0
	RunService.RenderStepped:Connect(function()
		local inLobby = not State.alive()
		local phase = State.phase()
		local matchRunning = phase == "Countdown" or phase == "Grace" or phase == "Battle"
		classButton.Visible = inLobby
		wardrobeButton.Visible = inLobby and State.inHub()
		auctionButton.Visible = wardrobeButton.Visible
		achievementsButton.Visible = inLobby
		coinsPill.Visible = inLobby
		if not inLobby and classPanel.Visible then
			setKitShop(false)
		end
		spectateButton.Visible = inLobby and matchRunning and not spectating
		spectateBar.Visible = spectating
		votePanel.Visible = inLobby and voteState.open == true and State.queuedMode() == "Survival"
		-- Play in the hub, Leave queue in the library (both move down while spectating)
		local inHub = State.inHub()
		local buttonY = if spectating then 132 else 74
		joinButton.Visible = inHub
		joinButton.Position = UDim2.new(0.5, 0, 0, buttonY)
		joinButton.Text = "▶️  PLAY"
		leaveButton.Visible = State.queued() and not State.inMatch()
		leaveButton.Position = UDim2.new(0.5, 0, 0, buttonY)
		modeButton.Visible = leaveButton.Visible
		modeButton.Position = UDim2.new(0.5, 0, 0, buttonY + 38)
		local mode = Modes.ById[State.queuedMode() or ""]
		if mode then
			modeButton.Text = "🔄  Queued for " .. mode.icon .. " " .. mode.name .. "  ·  change"
		end
		if votePanel.Visible then
			local left = math.max(0, math.ceil(State.phaseEndsAt() - State.now()))
			voteTimer.Text = "Voting closes in " .. left .. "s · the most votes wins"
		end
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
