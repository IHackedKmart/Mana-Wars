-- The Gilded Gavel: the auction house. Opened from the pavilion in the Plaza or the hub button.
--   Browse      - everything for sale (filter by parts / robes / hats and rarity), buy with coins
--   Sell        - put a loose part or an unworn robe / hat up for a price (the house keeps 10%)
--   My listings - what you have on the market; take unsold items back
-- The market is shared by every server when MemoryStore is available.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Remotes = require(Shared.Remotes)
local Config = require(Shared.Config)
local Rarity = require(Shared.Rarity)
local Cosmetics = require(Shared.Cosmetics)
local UI = script.Parent.Parent.UI
local Create = require(UI.Create)
local Theme = require(UI.Theme)
local Widgets = require(UI.Widgets)
local CosmeticInfo = require(UI.CosmeticInfo)
local State = require(script.Parent.State)
local Sounds = require(script.Parent.Sounds)

local AuctionController = {}

AuctionController.onOpenWardrobe = nil :: (() -> ())?

local C = Theme.Colors
local E = Config.Economy
local GOLD = Color3.fromRGB(255, 215, 90)
local action = Remotes.func("AuctionAction")

local gui: ScreenGui
local coinsLabel: TextLabel
local scopeLabel: TextLabel
local pages: { [string]: Frame } = {}
local tabButtons: { [string]: TextButton } = {}
local currentTab = "Browse"
local isOpen = false
local refresh: () -> ()

-- Browse state
local listings: { any } = {}
local lastFetch = -math.huge
local fetching = false
local filter = "All"
local rarityFilter = 0 -- 0 = any, otherwise a rarity rank
local sortMode = 1
local SORTS = { "Newest", "Cheapest", "Priciest", "Rarest" }
local filterButtons: { [string]: TextButton } = {}
local rarityButton: TextButton
local sortButton: TextButton
local browseList: ScrollingFrame
local browseEmpty: TextLabel
local confirmId: string? = nil

-- Sell state
local sellSelected: { kind: string, uid: string }? = nil
local sellGrid: ScrollingFrame
local sellInfo: Frame
local priceBox: TextBox
local feeLabel: TextLabel
local listButton: TextButton

-- My listings state
local mineList: ScrollingFrame
local mineEmpty: TextLabel
local mineCount: TextLabel

local function invoke(name: string, args: { [string]: any }): (boolean, any)
	local ok, success, message, extra = pcall(function()
		return action:InvokeServer(name, args)
	end)
	if not ok then
		State.toast("The auctioneer is busy, try again", C.Bad)
		return false, nil
	end
	if message then
		State.toast(message, if success then C.Good else C.Bad)
	end
	return success == true, extra
end

---------------------------------------------------------------------------
-- Item helpers
---------------------------------------------------------------------------

local function itemInfo(kind: string, item: any)
	return if kind == "Garment" then CosmeticInfo.garment(item) else CosmeticInfo.part(item)
end

local function itemIcon(kind: string, item: any): (string, Color3)
	if kind == "Garment" then
		local def = Cosmetics.Garments[item.kind]
		return def.icon, CosmeticInfo.color(item.parts[def.slots[1]])
	end
	return CosmeticInfo.icon(item), CosmeticInfo.color(item)
end

local function typeLabel(kind: string, item: any): string
	if kind == "Garment" then
		return item.rarity .. " " .. item.kind:lower()
	end
	local slot = Cosmetics.Slots[item.slot]
	return item.rarity .. " " .. (if slot then slot.label:lower() else tostring(item.slot))
end

local function timeLeft(expires: number): string
	local s = expires - State.now()
	if s <= 0 then
		return "expired"
	elseif s >= 3600 then
		return math.floor(s / 3600) .. "h left"
	end
	return math.max(1, math.floor(s / 60)) .. "m left"
end

local function proceeds(price: number): number
	return price - math.floor(price * E.AuctionFee)
end

local function salvageValue(kind: string, item: any): number
	if kind == "Garment" then
		local v = 0
		for _, p in item.parts do
			v += Cosmetics.SalvageValue[Rarity.rank(p.rarity)] or 1
		end
		return v
	end
	return Cosmetics.SalvageValue[Rarity.rank(item.rarity)] or 1
end

-- One row: tile, name, details, price and an action button.
local function row(
	parent: Instance,
	name: string,
	order: number,
	kind: string,
	item: any,
	price: number,
	details: string,
	button: { text: string, color: Color3, name: string, onClick: () -> () }?
)
	local frame = Create("Frame", {
		Name = name,
		BackgroundColor3 = C.Panel,
		BorderSizePixel = 0,
		Size = UDim2.new(1, -12, 0, 62),
		LayoutOrder = order,
		Parent = parent,
	}, { Create.corner(8), Create.stroke(Theme.rarity(item.rarity), 1, 0.6) })
	local icon, color = itemIcon(kind, item)
	local tile = Widgets.tile({
		size = 50,
		icon = icon,
		iconColor = color,
		border = Theme.rarity(item.rarity),
		info = function()
			return itemInfo(kind, item)
		end,
		parent = frame,
	})
	tile.Position = UDim2.fromOffset(6, 6)
	Widgets.label({
		Text = item.name,
		Font = Theme.Bold,
		TextSize = 16,
		TextColor3 = Theme.rarity(item.rarity),
		TextTruncate = Enum.TextTruncate.AtEnd,
		Size = UDim2.new(1, -330, 0, 22),
		Position = UDim2.fromOffset(66, 8),
		Parent = frame,
	})
	Widgets.label({
		Text = details,
		TextSize = 12,
		TextColor3 = C.Dim,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Size = UDim2.new(1, -330, 0, 18),
		Position = UDim2.fromOffset(66, 32),
		Parent = frame,
	})
	Widgets.label({
		Text = "🪙 " .. price,
		Font = Theme.Black,
		TextSize = 18,
		TextColor3 = GOLD,
		TextXAlignment = Enum.TextXAlignment.Right,
		Size = UDim2.fromOffset(120, 30),
		Position = UDim2.new(1, -262, 0, 16),
		Parent = frame,
	})
	if button then
		local b = Widgets.button(button.text, {
			size = UDim2.fromOffset(124, 36),
			position = UDim2.new(1, -134, 0, 13),
			color = button.color,
			onClick = button.onClick,
			parent = frame,
		})
		b.Name = button.name
	end
	return frame
end

local function scrollList(parent: Instance, name: string, size: UDim2, position: UDim2): ScrollingFrame
	return Create("ScrollingFrame", {
		Name = name,
		BackgroundColor3 = Color3.fromRGB(20, 17, 32),
		BackgroundTransparency = 0.2,
		BorderSizePixel = 0,
		Size = size,
		Position = position,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		Parent = parent,
	}, { Create.corner(8), Create.padding(6, 6), Create.list(Enum.FillDirection.Vertical, 6) })
end

local function emptyNote(parent: Instance, position: UDim2): TextLabel
	return Widgets.label({
		Name = "Empty",
		Text = "",
		TextSize = 15,
		TextColor3 = C.Dim,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextWrapped = true,
		Size = UDim2.fromOffset(600, 60),
		Position = position,
		AnchorPoint = Vector2.new(0.5, 0),
		ZIndex = 3,
		Parent = parent,
	})
end

---------------------------------------------------------------------------
-- Browse
---------------------------------------------------------------------------

local FILTER_KINDS: { [string]: string } = { Parts = "Part", Robes = "Robe", Hats = "Hat" }

local function matches(l: any): boolean
	if type(l.item) ~= "table" then
		return false
	end
	local kind: string = if l.kind == "Garment" then l.item.kind else "Part"
	local want = FILTER_KINDS[filter]
	if want and kind ~= want then
		return false
	end
	return rarityFilter == 0 or Rarity.rank(l.item.rarity) == rarityFilter
end

local function compare(a: any, b: any): boolean
	local mode = SORTS[sortMode]
	if mode == "Cheapest" and a.price ~= b.price then
		return a.price < b.price
	elseif mode == "Priciest" and a.price ~= b.price then
		return a.price > b.price
	elseif mode == "Rarest" then
		local ra, rb = Rarity.rank(a.item.rarity), Rarity.rank(b.item.rarity)
		if ra ~= rb then
			return ra > rb
		end
		if a.price ~= b.price then
			return a.price < b.price
		end
	end
	return a.id > b.id -- ids start with the listing time, so this is newest first
end

local fetch: (force: boolean?) -> ()

local function refreshBrowse()
	for name, b in filterButtons do
		b.BackgroundColor3 = if name == filter then C.Accent else C.Panel3
	end
	rarityButton.Text = "Rarity: " .. (if rarityFilter == 0 then "Any" else Rarity.fromRank(rarityFilter))
	rarityButton.TextColor3 = if rarityFilter == 0
		then Color3.new(1, 1, 1)
		else Theme.rarity(Rarity.fromRank(rarityFilter))
	sortButton.Text = "Sort: " .. SORTS[sortMode]
	Widgets.clear(browseList, true)
	local shown = {}
	for _, l in listings do
		if matches(l) then
			table.insert(shown, l)
		end
	end
	table.sort(shown, compare)
	local coins = State.wardrobe.coins or 0
	for i, l in shown do
		if i > 150 then
			break
		end
		local mine = l.mine == true
		local text, color
		if mine then
			text, color = "Yours", C.Panel3
		elseif confirmId == l.id then
			text, color = "Confirm buy", C.Good
		else
			text, color = "Buy", if coins >= l.price then C.Accent else C.Panel3
		end
		row(
			browseList,
			"Listing_" .. l.id,
			i,
			l.kind,
			l.item,
			l.price,
			typeLabel(l.kind, l.item) .. "  ·  sold by " .. tostring(l.sellerName) .. "  ·  " .. timeLeft(l.expires),
			{
				text = text,
				color = color,
				name = "Buy_" .. l.id,
				onClick = function()
					if mine then
						currentTab = "Mine"
						refresh()
						return
					end
					if confirmId ~= l.id then
						Sounds.play("Click")
						confirmId = l.id
						refreshBrowse()
						return
					end
					confirmId = nil
					if invoke("Buy", { id = l.id }) then
						Sounds.play("Pickup")
					end
					fetch(true)
				end,
			}
		)
	end
	browseEmpty.Visible = #shown == 0
	browseEmpty.Text = if fetching and #listings == 0
		then "Asking the auctioneer..."
		elseif #listings == 0 then "Nothing is for sale right now. Be the first to sell something!"
		else "Nothing matches those filters"
end

fetch = function(force: boolean?)
	if fetching or (not force and os.clock() - lastFetch < 5) then
		return
	end
	fetching = true
	task.spawn(function()
		local ok, success, _, result = pcall(function()
			return action:InvokeServer("Browse", {})
		end)
		fetching = false
		lastFetch = os.clock()
		if ok and success and type(result) == "table" then
			listings = result
		end
		if isOpen and currentTab == "Browse" then
			refreshBrowse()
		end
	end)
end

local function buildBrowse(page: Frame)
	local bar = Create("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 34),
		Parent = page,
	}, { Create.list(Enum.FillDirection.Horizontal, 8) })
	for i, name in { "All", "Parts", "Robes", "Hats" } do
		local b = Widgets.button(name, {
			size = UDim2.fromOffset(96, 32),
			color = C.Panel3,
			layoutOrder = i,
			onClick = function()
				Sounds.play("Click")
				filter = name
				refreshBrowse()
			end,
			parent = bar,
		})
		b.Name = "Filter_" .. name
		filterButtons[name] = b
	end
	rarityButton = Widgets.button("Rarity: Any", {
		size = UDim2.fromOffset(170, 32),
		color = C.Panel3,
		layoutOrder = 10,
		onClick = function()
			Sounds.play("Click")
			rarityFilter = (rarityFilter + 1) % (#Rarity.Order + 1)
			refreshBrowse()
		end,
		parent = bar,
	})
	rarityButton.Name = "RarityFilter"
	sortButton = Widgets.button("Sort: Newest", {
		size = UDim2.fromOffset(160, 32),
		color = C.Panel3,
		layoutOrder = 11,
		onClick = function()
			Sounds.play("Click")
			sortMode = sortMode % #SORTS + 1
			refreshBrowse()
		end,
		parent = bar,
	})
	sortButton.Name = "Sort"
	local refreshButton = Widgets.button("⟳  Refresh", {
		size = UDim2.fromOffset(120, 32),
		color = C.Accent,
		layoutOrder = 12,
		onClick = function()
			Sounds.play("Click")
			fetch(true)
		end,
		parent = bar,
	})
	refreshButton.Name = "Refresh"
	browseList = scrollList(page, "Listings", UDim2.new(1, 0, 1, -42), UDim2.fromOffset(0, 42))
	browseEmpty = emptyNote(page, UDim2.new(0.5, 0, 0, 120))
end

---------------------------------------------------------------------------
-- Sell
---------------------------------------------------------------------------

local function sellItem(): (string?, any)
	local sel = sellSelected
	if not sel then
		return nil, nil
	end
	local list = if sel.kind == "Garment" then State.wardrobe.garments else State.wardrobe.parts
	for _, item in list do
		if item.uid == sel.uid then
			return sel.kind, item
		end
	end
	return nil, nil
end

local function enteredPrice(): number?
	local n = tonumber(priceBox.Text)
	if not n then
		return nil
	end
	n = math.floor(n)
	return if n >= 1 and n <= E.MaxPrice then n else nil
end

local function updateFee()
	local kind, item = sellItem()
	local price = enteredPrice()
	local lines = {}
	if price then
		table.insert(
			lines,
			"You receive <b>🪙 "
				.. proceeds(price)
				.. "</b> when it sells (the house keeps "
				.. math.floor(E.AuctionFee * 100 + 0.5)
				.. "%)"
		)
	else
		table.insert(lines, "Enter a price from 1 to " .. E.MaxPrice .. " coins")
	end
	if kind and item then
		table.insert(lines, "Salvaging it instead would give 🪙 " .. salvageValue(kind, item))
	end
	table.insert(
		lines,
		"Unsold items come back after " .. E.AuctionHours .. " hours. Up to " .. E.MaxListings .. " listings at once."
	)
	feeLabel.Text = table.concat(lines, "\n")
	local ready = kind ~= nil and price ~= nil
	listButton.BackgroundColor3 = if ready then C.Good else C.Panel3
	listButton.AutoButtonColor = ready
end

local function refreshSell()
	local w = State.wardrobe
	Widgets.clear(sellGrid, true)
	local order = 0
	local wornUids = {}
	for _, uid in w.equipped do
		wornUids[uid] = true
	end
	local function add(kind: string, item: any)
		order += 1
		local icon, color = itemIcon(kind, item)
		Widgets.tile({
			name = "Sell_" .. item.uid,
			size = 54,
			icon = icon,
			iconColor = color,
			border = Theme.rarity(item.rarity),
			selected = sellSelected ~= nil and sellSelected.uid == item.uid,
			label = if kind == "Garment" then item.kind else nil,
			layoutOrder = order,
			info = function()
				return itemInfo(kind, item)
			end,
			onClick = function()
				Sounds.play("Click")
				sellSelected = { kind = kind, uid = item.uid }
				refreshSell()
			end,
			parent = sellGrid,
		})
	end
	local function byRarity(list: { any }): { any }
		local copy = table.clone(list)
		table.sort(copy, function(a, b)
			local ra, rb = Rarity.rank(a.rarity), Rarity.rank(b.rarity)
			if ra ~= rb then
				return ra > rb
			end
			return a.name < b.name
		end)
		return copy
	end
	for _, g in byRarity(w.garments) do
		if not wornUids[g.uid] then
			add("Garment", g)
		end
	end
	for _, p in byRarity(w.parts) do
		add("Part", p)
	end
	local kind, item = sellItem()
	if not kind then
		sellSelected = nil
	end
	Widgets.fillInfo(sellInfo, if kind then itemInfo(kind, item) else nil)
	if not kind then
		Widgets.label({
			Text = "Pick something to sell. Worn robes and hats can't be sold: take them off first.",
			TextSize = 14,
			TextColor3 = C.Dim,
			TextWrapped = true,
			Size = UDim2.new(1, 0, 0, 60),
			Parent = sellInfo,
		})
	end
	updateFee()
end

local function buildSell(page: Frame)
	Widgets.label({
		Text = "YOUR UNWORN ROBES, HATS AND PARTS",
		Font = Theme.Black,
		TextSize = 13,
		TextColor3 = C.Gold,
		Size = UDim2.fromOffset(420, 18),
		Parent = page,
	})
	sellGrid = Create("ScrollingFrame", {
		Name = "SellGrid",
		BackgroundColor3 = C.Panel,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(440, 482),
		Position = UDim2.fromOffset(0, 20),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		Parent = page,
	}, { Create.corner(8), Create.padding(6, 6), Create.grid(54, 8) })
	sellInfo = Create("Frame", {
		Name = "SellDetails",
		BackgroundColor3 = C.Panel,
		Size = UDim2.fromOffset(300, 502),
		Position = UDim2.fromOffset(452, 0),
		Parent = page,
	}, { Create.corner(8), Create.padding(10, 8) })
	local x = 764
	Widgets.label({
		Text = "PRICE (ENCHANTED COINS)",
		Font = Theme.Black,
		TextSize = 13,
		TextColor3 = C.Gold,
		Size = UDim2.fromOffset(240, 18),
		Position = UDim2.fromOffset(x, 0),
		Parent = page,
	})
	priceBox = Create("TextBox", {
		Name = "PriceBox",
		Text = "",
		PlaceholderText = "e.g. 150",
		ClearTextOnFocus = false,
		Font = Theme.Black,
		TextSize = 22,
		TextColor3 = GOLD,
		PlaceholderColor3 = C.Dim,
		BackgroundColor3 = C.Panel,
		Size = UDim2.fromOffset(240, 44),
		Position = UDim2.fromOffset(x, 22),
		Parent = page,
	}, { Create.corner(8), Create.stroke(C.Stroke, 1.5) })
	priceBox:GetPropertyChangedSignal("Text"):Connect(function()
		local digits = priceBox.Text:gsub("%D", "")
		if digits ~= priceBox.Text then
			priceBox.Text = digits
			return
		end
		updateFee()
	end)
	feeLabel = Widgets.label({
		Name = "FeeNote",
		Text = "",
		RichText = true,
		TextSize = 13,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		Size = UDim2.fromOffset(240, 150),
		Position = UDim2.fromOffset(x, 76),
		Parent = page,
	})
	listButton = Widgets.button("⚖  List for sale", {
		size = UDim2.fromOffset(240, 44),
		position = UDim2.fromOffset(x, 236),
		color = C.Panel3,
		textSize = 17,
		onClick = function()
			local kind, item = sellItem()
			local price = enteredPrice()
			if not kind or not item then
				State.toast("Pick something to sell first", C.Bad)
				return
			end
			if not price then
				State.toast("Enter a price from 1 to " .. E.MaxPrice, C.Bad)
				return
			end
			if invoke("List", { kind = kind, uid = item.uid, price = price }) then
				Sounds.play("Forge")
				sellSelected = nil
				priceBox.Text = ""
				fetch(true)
			end
			refreshSell()
		end,
		parent = page,
	})
	listButton.Name = "ListButton"
	Widgets.button("👘  Open the Wardrobe", {
		size = UDim2.fromOffset(240, 36),
		position = UDim2.fromOffset(x, 292),
		color = C.Panel3,
		onClick = function()
			if AuctionController.onOpenWardrobe then
				AuctionController.onOpenWardrobe()
			end
		end,
		parent = page,
	}).Name =
		"WardrobeLink"
end

---------------------------------------------------------------------------
-- My listings
---------------------------------------------------------------------------

local function refreshMine()
	Widgets.clear(mineList, true)
	local mine = {}
	for id, record in State.wardrobe.listings or {} do
		if type(record) == "table" and type(record.item) == "table" then
			table.insert(mine, { id = id, record = record })
		end
	end
	table.sort(mine, function(a, b)
		return a.id > b.id
	end)
	for i, entry in mine do
		local record = entry.record
		local expired = record.expires <= State.now()
		row(
			mineList,
			"Mine_" .. entry.id,
			i,
			record.kind,
			record.item,
			record.price,
			typeLabel(record.kind, record.item)
				.. "  ·  "
				.. (
					if expired
						then "unsold, coming back to you shortly"
						else timeLeft(record.expires) .. "  ·  you get 🪙 " .. proceeds(record.price)
				),
			if expired
				then nil
				else {
					text = "Take back",
					color = C.Bad,
					name = "Cancel_" .. entry.id,
					onClick = function()
						if invoke("Cancel", { id = entry.id }) then
							Sounds.play("Click")
						end
						fetch(true)
					end,
				}
		)
	end
	mineCount.Text = #mine .. " / " .. E.MaxListings .. " listings"
	mineEmpty.Visible = #mine == 0
	mineEmpty.Text = "You aren't selling anything. Head to the Sell tab to put something up."
end

local function buildMine(page: Frame)
	mineCount = Widgets.label({
		Name = "Count",
		Text = "",
		Font = Theme.Bold,
		TextSize = 14,
		TextColor3 = C.Dim,
		Size = UDim2.fromOffset(400, 24),
		Parent = page,
	})
	Widgets.label({
		Text = "Coins from sales in other servers arrive the next time you visit.",
		TextSize = 13,
		TextColor3 = C.Dim,
		TextXAlignment = Enum.TextXAlignment.Right,
		Size = UDim2.new(1, -400, 0, 24),
		Position = UDim2.fromOffset(400, 0),
		Parent = page,
	})
	mineList = scrollList(page, "MyListings", UDim2.new(1, 0, 1, -32), UDim2.fromOffset(0, 32))
	mineEmpty = emptyNote(page, UDim2.new(0.5, 0, 0, 120))
end

---------------------------------------------------------------------------
-- Window
---------------------------------------------------------------------------

refresh = function()
	if not gui then
		return
	end
	coinsLabel.Text = "🪙 " .. tostring(State.wardrobe.coins or 0) .. "  Enchanted Coins"
	scopeLabel.Text = if ReplicatedStorage:GetAttribute("AuctionGlobal") == true
		then "One market shared by every server"
		else "Market for this server only (no MemoryStore access)"
	if not isOpen then
		return
	end
	for name, button in tabButtons do
		button.BackgroundColor3 = if name == currentTab then C.Accent else C.Panel3
	end
	for name, page in pages do
		page.Visible = name == currentTab
	end
	if currentTab == "Browse" then
		refreshBrowse()
		fetch(false)
	elseif currentTab == "Sell" then
		refreshSell()
	else
		refreshMine()
	end
end

function AuctionController.open(tab: string?)
	if tab and pages[tab] then
		currentTab = tab
	end
	confirmId = nil
	isOpen = true
	gui.Enabled = true
	State.setMenu("auction", true)
	refresh()
end

function AuctionController.close()
	if not gui then
		return
	end
	isOpen = false
	gui.Enabled = false
	confirmId = nil
	Widgets.hideTooltip()
	State.setMenu("auction", false)
end

function AuctionController.isOpen(): boolean
	return isOpen
end

local function build()
	gui = Widgets.screen("AuctionHouse", 11)
	gui.Enabled = false
	local root = Widgets.scaledRoot(gui)
	local panel = Widgets.panel({
		Size = UDim2.fromOffset(1040, 620),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = C.Background,
		BackgroundTransparency = 0.03,
		Parent = root,
	})
	Widgets.label({
		Text = "THE GILDED GAVEL",
		Font = Theme.Black,
		TextSize = 24,
		TextColor3 = C.Gold,
		Size = UDim2.fromOffset(300, 30),
		Position = UDim2.fromOffset(18, 10),
		Parent = panel,
	})
	scopeLabel = Widgets.label({
		Name = "Scope",
		Text = "",
		TextSize = 12,
		TextColor3 = C.Dim,
		Size = UDim2.fromOffset(340, 30),
		Position = UDim2.fromOffset(250, 12),
		Parent = panel,
	})
	coinsLabel = Widgets.label({
		Name = "Coins",
		Text = "",
		Font = Theme.Black,
		TextSize = 18,
		TextColor3 = GOLD,
		TextXAlignment = Enum.TextXAlignment.Right,
		Size = UDim2.fromOffset(320, 30),
		Position = UDim2.new(1, -378, 0, 10),
		Parent = panel,
	})
	Widgets.button("✕", {
		size = UDim2.fromOffset(34, 34),
		position = UDim2.new(1, -46, 0, 8),
		color = C.Panel3,
		onClick = function()
			AuctionController.close()
		end,
		parent = panel,
	})
	local tabs = Create("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -36, 0, 34),
		Position = UDim2.fromOffset(18, 48),
		Parent = panel,
	}, { Create.list(Enum.FillDirection.Horizontal, 8) })
	for i, def in { { "Browse", "🔍  Browse" }, { "Sell", "💰  Sell" }, { "Mine", "📜  My listings" } } do
		local b = Widgets.button(def[2], {
			size = UDim2.fromOffset(160, 32),
			color = C.Panel3,
			layoutOrder = i,
			onClick = function()
				Sounds.play("Click")
				currentTab = def[1]
				confirmId = nil
				refresh()
			end,
			parent = tabs,
		})
		b.Name = "Tab_" .. def[1]
		tabButtons[def[1]] = b
		pages[def[1]] = Create("Frame", {
			Name = "Page_" .. def[1],
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -36, 1, -104),
			Position = UDim2.fromOffset(18, 92),
			Visible = false,
			Parent = panel,
		})
	end
	buildBrowse(pages.Browse)
	buildSell(pages.Sell)
	buildMine(pages.Mine)
end

function AuctionController.init()
	build()
	State.WardrobeChanged:Connect(refresh)
	ReplicatedStorage:GetAttributeChangedSignal("AuctionGlobal"):Connect(refresh)
	-- the market is a Plaza thing: close it if you get pulled into a match
	Players.LocalPlayer:GetAttributeChangedSignal("InMatch"):Connect(function()
		if isOpen and State.inMatch() then
			AuctionController.close()
		end
	end)
	local sinceTick = 0
	RunService.Heartbeat:Connect(function(dt)
		sinceTick += dt
		if not isOpen or sinceTick < 1 then
			return
		end
		sinceTick = 0
		if currentTab == "Browse" then
			fetch(false)
		elseif currentTab == "Mine" then
			refreshMine() -- keep the time-left text ticking
		end
	end)
	refresh()
end

return AuctionController
