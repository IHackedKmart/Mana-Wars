-- The Tailor's Loom: open Coffers with Enchanted Coins, stitch parts into robes and hats, and
-- choose what to wear. Opened from the Tailor / Coffer stalls in the Plaza or the hub buttons.
--   Coffers  - five loot boxes, 50 to 1000 coins, with their odds
--   Tailor   - pick a Cloth + Trim + Sigil (robe) or Shape + Band + Gem (hat) and stitch it
--   Wardrobe - wear / take off / unpick / salvage garments and loose parts
--   Familiars - summon / dismiss / salvage the companions that come out of Coffers

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage.Shared
local Remotes = require(Shared.Remotes)
local Rarity = require(Shared.Rarity)
local Cosmetics = require(Shared.Cosmetics)
local OutfitBuilder = require(Shared.OutfitBuilder)
local Familiars = require(Shared.Familiars)
local UI = script.Parent.Parent.UI
local Create = require(UI.Create)
local Theme = require(UI.Theme)
local Widgets = require(UI.Widgets)
local CosmeticInfo = require(UI.CosmeticInfo)
local State = require(script.Parent.State)
local Sounds = require(script.Parent.Sounds)
local FamiliarBuilder = require(script.Parent.FamiliarBuilder)

local WardrobeController = {}

local C = Theme.Colors
local action = Remotes.func("WardrobeAction")

local gui: ScreenGui
local coinsLabel: TextLabel
local pages: { [string]: Frame } = {}
local tabs: Widgets.TabsHandle
local currentTab = "Coffers"
local isOpen = false

-- Tailor state
local mode = "Robe"
local draft: { [string]: string } = {} -- slot -> part uid
local slotGrids: { ScrollingFrame } = {}
local slotHeaders: { TextLabel } = {}
local tailorPreview: any
local tailorSummary: TextLabel
local craftButton: TextButton

-- Coffers state
local revealRow: Frame

-- Wardrobe state
local selected: { kind: string, uid: string }? = nil
local garmentGrid: ScrollingFrame
local partGrid: ScrollingFrame
local wardrobePreview: any
local detailsInfo: Frame
local detailButtons: Frame

-- Familiars state
local familiarSelected: string? = nil
local familiarGrid: ScrollingFrame
local familiarPreview: any
local familiarInfo: Frame
local familiarButtons: Frame
local gearLabel: TextLabel

local function invoke(name: string, args: { [string]: any }): (boolean, string?, any)
	local ok, success, message, extra = pcall(function()
		return action:InvokeServer(name, args)
	end)
	if not ok then
		State.toast("The tailor is busy, try again", C.Bad)
		return false, nil, nil
	end
	if message then
		State.toast(message, if success then C.Good else C.Bad)
	end
	return success, message, extra
end

local function findPart(uid: string?): any
	if not uid then
		return nil
	end
	for _, p in State.wardrobe.parts do
		if p.uid == uid then
			return p
		end
	end
	return nil
end

local function findGarment(uid: string?): any
	if not uid then
		return nil
	end
	for _, g in State.wardrobe.garments do
		if g.uid == uid then
			return g
		end
	end
	return nil
end

local function worn(kind: string): any
	return findGarment(State.wardrobe.equipped[kind])
end

local function findFamiliar(uid: string?): any
	if not uid then
		return nil
	end
	for _, f in State.wardrobe.familiars or {} do
		if f.uid == uid then
			return f
		end
	end
	return nil
end

local function wornFamiliar(): any
	return findFamiliar(State.wardrobe.equipped.Familiar)
end

local function sortByRarity(list: { any }): { any }
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

---------------------------------------------------------------------------
-- Preview mannequin (a turntable in a ViewportFrame)
---------------------------------------------------------------------------

local function makePreview(parent: Instance, size: UDim2, position: UDim2)
	local viewport = Create("ViewportFrame", {
		Name = "Preview",
		Size = size,
		Position = position,
		BackgroundColor3 = Color3.fromRGB(20, 17, 32),
		Ambient = Color3.fromRGB(170, 160, 190),
		LightColor = Color3.fromRGB(255, 245, 230),
		LightDirection = Vector3.new(-1, -1.5, -1),
		Parent = parent,
	}, { Create.corner(10), Create.stroke(C.Stroke, 1.5) })
	local camera = Instance.new("Camera")
	camera.FieldOfView = 40
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	local model = Instance.new("Model")
	model.Name = "Mannequin"
	model.Parent = viewport
	local skin = Color3.fromRGB(205, 190, 175)
	local function limb(name: string, size3: Vector3, pos: Vector3): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.Size = size3
		p.CFrame = CFrame.new(pos)
		p.Color = skin
		p.Material = Enum.Material.SmoothPlastic
		p.Parent = model
		return p
	end
	local torso = limb("Torso", Vector3.new(2, 2, 1), Vector3.new(0, 3, 0))
	local head = limb("Head", Vector3.new(1.2, 1.2, 1.2), Vector3.new(0, 4.6, 0))
	local leftArm = limb("Left Arm", Vector3.new(1, 2, 1), Vector3.new(-1.5, 3, 0))
	local rightArm = limb("Right Arm", Vector3.new(1, 2, 1), Vector3.new(1.5, 3, 0))
	limb("Left Leg", Vector3.new(1, 2, 1), Vector3.new(-0.5, 1, 0))
	limb("Right Leg", Vector3.new(1, 2, 1), Vector3.new(0.5, 1, 0))
	local rig: OutfitBuilder.Rig = {
		torso = torso,
		hips = torso,
		head = head,
		leftArm = leftArm,
		rightArm = rightArm,
		legLength = 2,
		weld = false,
		parent = model,
	}
	local angle = 0
	local t = 0
	local pet: FamiliarBuilder.Rig? = nil
	local petCode: string? = nil
	RunService.RenderStepped:Connect(function(dt)
		if not gui or not gui.Enabled or not viewport.Visible then
			return
		end
		angle += dt * 0.6
		t += dt
		local eye = Vector3.new(math.sin(angle) * 9.5, 4.4, -math.cos(angle) * 9.5)
		camera.CFrame = CFrame.lookAt(eye, Vector3.new(0.6, 3, 0))
		if pet then
			-- the familiar keeps you company: hovering by your shoulder, or sitting at your feet
			local at = if pet.flies
				then Vector3.new(2.5, 4.3 + math.sin(t * 2) * 0.2, 0.6)
				else Vector3.new(2.3, 0, 0.9)
			FamiliarBuilder.pose(pet, CFrame.lookAt(at, at + Vector3.new(-0.3, 0, -1)), t, 0)
		end
	end)
	return {
		viewport = viewport,
		show = function(robe: any, hat: any, familiar: any)
			OutfitBuilder.strip(model)
			pcall(OutfitBuilder.build, rig, robe, hat, false)
			local code = if familiar then Familiars.encode(familiar) else nil
			if code ~= petCode then
				if pet then
					FamiliarBuilder.destroy(pet)
					pet = nil
				end
				petCode = code
				local look = Familiars.decode(code)
				if look then
					pet = FamiliarBuilder.build(look, viewport, false)
				end
			end
		end,
	}
end

---------------------------------------------------------------------------
-- Coffers
---------------------------------------------------------------------------

local function reveal(parts: { any })
	Widgets.clear(revealRow, true)
	for i, part in parts do
		local holder = Create("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(300, 120),
			LayoutOrder = i,
			Parent = revealRow,
		})
		local isFamiliar = part.species ~= nil
		local kind = if isFamiliar then "Familiar" else "Part"
		local icon, iconColor = CosmeticInfo.itemIcon(kind, part)
		local tile = Widgets.tile({
			name = "Got_" .. part.uid,
			size = 96,
			icon = icon,
			iconColor = iconColor,
			border = Theme.rarity(part.rarity),
			info = function()
				return CosmeticInfo.item(kind, part)
			end,
			parent = holder,
		})
		Widgets.label({
			Text = part.name,
			Font = Theme.Bold,
			TextSize = 15,
			TextWrapped = true,
			TextColor3 = Theme.rarity(part.rarity),
			Size = UDim2.new(1, -106, 0, 40),
			Position = UDim2.fromOffset(104, 8),
			Parent = holder,
		})
		Widgets.label({
			Text = if isFamiliar
				then "🐾 " .. part.rarity .. " familiar!" .. (if part.shiny then " ✨ Shiny!" else "")
				else part.rarity .. " " .. Cosmetics.Slots[part.slot].label,
			TextSize = 12,
			TextColor3 = C.Dim,
			Size = UDim2.new(1, -106, 0, 16),
			Position = UDim2.fromOffset(104, 50),
			Parent = holder,
		})
		-- a flash in the rarity colour, bigger for rarer finds
		local glow = Create("Frame", {
			BackgroundColor3 = Theme.rarity(part.rarity),
			BackgroundTransparency = 0.2,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 5,
			Parent = tile,
		}, { Create.corner(8) })
		TweenService:Create(glow, TweenInfo.new(0.35 + Rarity.rank(part.rarity) * 0.15), { BackgroundTransparency = 1 })
			:Play()
		if Rarity.rank(part.rarity) >= 4 then
			Sounds.play("Crit")
		end
	end
end

local function buildCoffers(page: Frame)
	local row = Create("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 340),
		Parent = page,
	}, { Create.list(Enum.FillDirection.Horizontal, 10) })
	for _, box in Cosmetics.Boxes do
		local card = Widgets.panel({
			Name = "Coffer_" .. box.id,
			Size = UDim2.fromOffset(194, 336),
			BackgroundColor3 = C.Panel2,
			LayoutOrder = box.id,
			Parent = row,
		})
		local stroke = card:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Color = Theme.rgb(box.color)
		end
		Widgets.label({
			Text = box.icon,
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Center,
			Size = UDim2.fromOffset(60, 60),
			Position = UDim2.new(0.5, -30, 0, 8),
			Parent = card,
		})
		Widgets.label({
			Text = box.name,
			Font = Theme.Black,
			TextSize = 15,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextColor3 = Theme.rgb(box.color),
			Size = UDim2.new(1, -12, 0, 36),
			Position = UDim2.fromOffset(6, 70),
			Parent = card,
		})
		Widgets.label({
			Text = box.parts .. (if box.parts == 1 then " part" else " parts"),
			Font = Theme.Bold,
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Center,
			Size = UDim2.new(1, -12, 0, 14),
			Position = UDim2.fromOffset(6, 106),
			Parent = card,
		})
		Widgets.label({
			Text = box.blurb,
			TextSize = 11,
			TextWrapped = true,
			TextColor3 = C.Dim,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextYAlignment = Enum.TextYAlignment.Top,
			Size = UDim2.new(1, -16, 0, 56),
			Position = UDim2.fromOffset(8, 124),
			Parent = card,
		})
		local odds = Create("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -16, 0, 96),
			Position = UDim2.fromOffset(8, 184),
			Parent = card,
		}, { Create.list(Enum.FillDirection.Vertical, 1) })
		for i, rarity in Rarity.Order do
			local pct = box.odds[rarity]
			if pct then
				Widgets.label({
					Text = rarity .. "  " .. pct .. "%",
					Font = Theme.Bold,
					TextSize = 12,
					TextXAlignment = Enum.TextXAlignment.Center,
					TextColor3 = Theme.rarity(rarity),
					Size = UDim2.new(1, 0, 0, 15),
					LayoutOrder = i,
					Parent = odds,
				})
			end
		end
		Widgets.label({
			Name = "FamiliarChance",
			Text = "🐾 " .. (Familiars.ChancePerItem[box.id] or 0) .. "% familiar per item",
			Font = Theme.Bold,
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextColor3 = C.Gold,
			Size = UDim2.new(1, 0, 0, 15),
			LayoutOrder = 20,
			Parent = odds,
		})
		local open = Widgets.button("Open  ·  💰 " .. box.price, {
			size = UDim2.new(1, -16, 0, 38),
			position = UDim2.new(0, 8, 1, -46),
			color = Theme.darken(Theme.rgb(box.color), 0.35),
			textSize = 15,
			onClick = function()
				local ok, _, got = invoke("OpenBox", { box = box.id })
				if ok and type(got) == "table" then
					reveal(got)
				end
			end,
			parent = card,
		})
		open.Name = "Open_" .. box.id
	end
	Widgets.label({
		Text = "Earn Enchanted Coins by playing: 1st place gets 12 ... 12th gets 1. Any item can be a familiar (same rarity odds), and 1 in "
			.. math.floor(100 / Familiars.ShinyChance + 0.5)
			.. " familiars is Shiny.",
		TextSize = 13,
		TextColor3 = C.Dim,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 18),
		Position = UDim2.fromOffset(0, 346),
		Parent = page,
	})
	revealRow = Create("Frame", {
		Name = "Reveal",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -20, 0, 124),
		Position = UDim2.fromOffset(10, 372),
		Parent = page,
	}, { Create.list(Enum.FillDirection.Horizontal, 16, Enum.HorizontalAlignment.Center) })
end

---------------------------------------------------------------------------
-- Tailor
---------------------------------------------------------------------------

local function draftParts(): { [string]: any }
	local parts = {}
	for _, slot in Cosmetics.Garments[mode].slots do
		parts[slot] = findPart(draft[slot])
	end
	return parts
end

local function refreshTailor()
	local slots = Cosmetics.Garments[mode].slots
	for i, slot in slots do
		local grid = slotGrids[i]
		local header = slotHeaders[i]
		header.Text = Cosmetics.Slots[slot].icon .. "  " .. string.upper(Cosmetics.Slots[slot].label)
		Widgets.clear(grid, true)
		if draft[slot] and not findPart(draft[slot]) then
			draft[slot] = nil
		end
		local n = 0
		for _, part in sortByRarity(State.wardrobe.parts) do
			if part.slot == slot then
				n += 1
				Widgets.itemRow({
					name = "Pick_" .. part.uid,
					icon = CosmeticInfo.icon(part),
					iconColor = CosmeticInfo.color(part),
					rarity = part.rarity,
					title = CosmeticInfo.shortName("Part", part),
					subtitle = part.rarity .. "  ·  " .. (if Cosmetics.ColorById[part.color]
						then Cosmetics.ColorById[part.color].name
						else "") .. (if part.aura then "  ·  ✨ aura" else ""),
					selected = draft[slot] == part.uid,
					layoutOrder = n,
					info = function()
						return CosmeticInfo.part(part)
					end,
					onClick = function()
						Sounds.play("Click")
						draft[slot] = if draft[slot] == part.uid then nil else part.uid
						refreshTailor()
					end,
					parent = grid,
				})
			end
		end
		if n == 0 then
			Widgets.label({
				Text = "No " .. Cosmetics.Slots[slot].label:lower() .. " parts yet. Open a Coffer!",
				TextSize = 12,
				TextWrapped = true,
				TextColor3 = C.Dim,
				Size = UDim2.new(1, -8, 0, 40),
				Parent = grid,
			})
		end
	end

	local parts = draftParts()
	local complete = Cosmetics.validate(mode, parts)
	craftButton.Text = Cosmetics.Garments[mode].verb .. " " .. mode
	craftButton.BackgroundColor3 = if complete then C.Accent else C.Panel3
	local otherKind = if mode == "Robe" then "Hat" else "Robe"
	local preview = if complete then Cosmetics.craft(mode, parts) else nil
	if mode == "Robe" then
		tailorPreview.show(preview, worn(otherKind), wornFamiliar())
	else
		tailorPreview.show(worn(otherKind), preview, wornFamiliar())
	end
	if preview then
		local level = Cosmetics.auraLevel(preview)
		local aura = Cosmetics.AuraById[Cosmetics.auraOf(preview) or ""]
		local lines = {
			"<b>" .. preview.name .. "</b>",
			string.format(
				"Resonance %d/6 (%s)  ·  Aura: %s",
				Cosmetics.resonance(parts),
				preview.rarity,
				if aura and level >= 3
					then aura.name .. ", " .. Cosmetics.AuraLevelNames[level]
					elseif aura then aura.name .. ", too weak to show"
					else "none"
			),
		}
		for _, slot in Cosmetics.Garments[mode].slots do
			for _, e in parts[slot].enchants do
				table.insert(lines, "✨ " .. Cosmetics.enchantText(e))
			end
		end
		tailorSummary.Text = table.concat(lines, "\n")
	else
		tailorSummary.Text =
			"Pick one part from each column. Auras only shine one tier above the garment's resonance (the average rarity of its three parts), so match your rarities!"
	end
end

local function buildTailor(page: Frame)
	local toggle = Create("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(300, 34),
		Parent = page,
	}, { Create.list(Enum.FillDirection.Horizontal, 8) })
	for i, kind in Cosmetics.GarmentOrder do
		local b = Widgets.button(Cosmetics.Garments[kind].icon .. "  " .. kind, {
			size = UDim2.fromOffset(130, 32),
			color = C.Panel3,
			layoutOrder = i,
			onClick = function()
				mode = kind
				draft = {}
				refreshTailor()
			end,
			parent = toggle,
		})
		b.Name = "Mode_" .. kind
	end
	for i = 1, 3 do
		local x = (i - 1) * 222
		slotHeaders[i] = Widgets.label({
			Text = "",
			Font = Theme.Black,
			TextSize = 13,
			TextColor3 = C.Gold,
			Size = UDim2.fromOffset(212, 18),
			Position = UDim2.fromOffset(x, 42),
			Parent = page,
		})
		slotGrids[i] = Create("ScrollingFrame", {
			Name = "Slot" .. i,
			BackgroundColor3 = C.Panel,
			BorderSizePixel = 0,
			Size = UDim2.fromOffset(212, 452),
			Position = UDim2.fromOffset(x, 62),
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollBarThickness = 5,
			Parent = page,
		}, { Create.corner(8), Create.padding(6, 6), Create.list(Enum.FillDirection.Vertical, 6) })
	end
	tailorPreview = makePreview(page, UDim2.fromOffset(330, 250), UDim2.fromOffset(672, 0))
	tailorSummary = Widgets.label({
		Name = "Summary",
		Text = "",
		RichText = true,
		TextSize = 13,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		Size = UDim2.fromOffset(330, 190),
		Position = UDim2.fromOffset(672, 258),
		Parent = page,
	})
	craftButton = Widgets.button("Stitch Robe", {
		size = UDim2.fromOffset(330, 44),
		position = UDim2.fromOffset(672, 458),
		color = C.Accent,
		textSize = 18,
		onClick = function()
			local ok = invoke("Craft", { kind = mode, parts = table.clone(draft) })
			if ok then
				draft = {}
				Sounds.play("Pickup")
			end
		end,
		parent = page,
	})
	craftButton.Name = "CraftButton"
end

---------------------------------------------------------------------------
-- Wardrobe
---------------------------------------------------------------------------

local function detailButton(text: string, color: Color3?, onClick: () -> (), name: string)
	local b = Widgets.button(text, {
		size = UDim2.fromOffset(158, 32),
		color = color or C.Panel3,
		textSize = 13,
		onClick = onClick,
		parent = detailButtons,
	})
	b.Name = name
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

local function refreshWardrobe()
	local w = State.wardrobe
	Widgets.clear(garmentGrid, true)
	Widgets.clear(partGrid, true)
	for i, g in sortByRarity(w.garments) do
		local isWorn = w.equipped[g.kind] == g.uid
		Widgets.card({
			name = "Garment_" .. g.uid,
			width = 72,
			icon = Cosmetics.Garments[g.kind].icon,
			iconColor = CosmeticInfo.color(g.parts[Cosmetics.Garments[g.kind].slots[1]]),
			rarity = g.rarity,
			caption = CosmeticInfo.shortName("Garment", g),
			badge = if isWorn then "✅" else nil,
			selected = selected ~= nil and selected.uid == g.uid,
			layoutOrder = i,
			info = function()
				return CosmeticInfo.garment(g)
			end,
			onClick = function()
				selected = { kind = "Garment", uid = g.uid }
				refreshWardrobe()
			end,
			parent = garmentGrid,
		})
	end
	for i, p in sortByRarity(w.parts) do
		Widgets.card({
			name = "Part_" .. p.uid,
			width = 72,
			icon = CosmeticInfo.icon(p),
			iconColor = CosmeticInfo.color(p),
			rarity = p.rarity,
			caption = CosmeticInfo.shortName("Part", p),
			selected = selected ~= nil and selected.uid == p.uid,
			layoutOrder = i,
			info = function()
				return CosmeticInfo.part(p)
			end,
			onClick = function()
				selected = { kind = "Part", uid = p.uid }
				refreshWardrobe()
			end,
			parent = partGrid,
		})
	end

	-- preview: what you're wearing, with the selected garment swapped in
	local robe, hat = worn("Robe"), worn("Hat")
	local item = if selected and selected.kind == "Garment" then findGarment(selected.uid) else nil
	if item then
		if item.kind == "Robe" then
			robe = item
		else
			hat = item
		end
	end
	wardrobePreview.show(robe, hat, wornFamiliar())
	local wornList = {}
	for _, kind in Cosmetics.GarmentOrder do
		local g = worn(kind)
		if g then
			table.insert(wornList, g)
		end
	end
	gearLabel.Text = "<b>Your outfit's bonuses</b>\n" .. CosmeticInfo.gearText(Cosmetics.gear(wornList))

	Widgets.clear(detailButtons, true)
	if not selected then
		Widgets.fillInfo(detailsInfo, nil)
		return
	end
	local sel = selected
	if sel.kind == "Garment" then
		local g = findGarment(sel.uid)
		if not g then
			selected = nil
			Widgets.fillInfo(detailsInfo, nil)
			return
		end
		Widgets.fillInfo(detailsInfo, CosmeticInfo.garment(g))
		if w.equipped[g.kind] == g.uid then
			detailButton("Take off", nil, function()
				invoke("Unequip", { kind = g.kind })
			end, "UnequipButton")
		else
			detailButton("Wear", C.Accent, function()
				invoke("Equip", { uid = g.uid })
			end, "WearButton")
		end
		detailButton("Unpick into parts", nil, function()
			invoke("Unbind", { uid = g.uid })
			selected = nil
		end, "UnbindButton")
		detailButton("Salvage (+" .. salvageValue("Garment", g) .. " 💰)", C.Bad, function()
			invoke("Salvage", { kind = "Garment", uid = g.uid })
			selected = nil
		end, "SalvageButton")
	else
		local p = findPart(sel.uid)
		if not p then
			selected = nil
			Widgets.fillInfo(detailsInfo, nil)
			return
		end
		Widgets.fillInfo(detailsInfo, CosmeticInfo.part(p))
		detailButton("Use at the Tailor", C.Accent, function()
			mode = Cosmetics.Slots[p.slot].garment
			draft = { [p.slot] = p.uid }
			WardrobeController.open("Tailor")
		end, "TailorButton")
		detailButton("Salvage (+" .. salvageValue("Part", p) .. " 💰)", C.Bad, function()
			invoke("Salvage", { kind = "Part", uid = p.uid })
			selected = nil
		end, "SalvageButton")
	end
end

local function buildWardrobe(page: Frame)
	Widgets.label({
		Text = "ROBES & HATS",
		Font = Theme.Black,
		TextSize = 13,
		TextColor3 = C.Gold,
		Size = UDim2.fromOffset(300, 18),
		Parent = page,
	})
	garmentGrid = Create("ScrollingFrame", {
		Name = "Garments",
		BackgroundColor3 = C.Panel,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(420, 212),
		Position = UDim2.fromOffset(0, 22),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 5,
		Parent = page,
	}, {
		Create.corner(8),
		Create.padding(8, 8),
		Create("UIGridLayout", {
			CellSize = UDim2.fromOffset(72, 96),
			CellPadding = UDim2.fromOffset(8, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	Widgets.label({
		Text = "LOOSE PARTS",
		Font = Theme.Black,
		TextSize = 13,
		TextColor3 = C.Gold,
		Size = UDim2.fromOffset(300, 18),
		Position = UDim2.fromOffset(0, 248),
		Parent = page,
	})
	partGrid = Create("ScrollingFrame", {
		Name = "Parts",
		BackgroundColor3 = C.Panel,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(420, 244),
		Position = UDim2.fromOffset(0, 270),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 5,
		Parent = page,
	}, {
		Create.corner(8),
		Create.padding(8, 8),
		Create("UIGridLayout", {
			CellSize = UDim2.fromOffset(72, 96),
			CellPadding = UDim2.fromOffset(8, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	wardrobePreview = makePreview(page, UDim2.fromOffset(250, 300), UDim2.fromOffset(432, 0))
	gearLabel = Widgets.label({
		Name = "Bonuses",
		Text = "",
		RichText = true,
		TextSize = 12,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		Size = UDim2.fromOffset(250, 196),
		Position = UDim2.fromOffset(432, 308),
		Parent = page,
	})
	detailsInfo = Create("Frame", {
		Name = "Details",
		BackgroundColor3 = C.Panel,
		Size = UDim2.fromOffset(320, 330),
		Position = UDim2.fromOffset(692, 0),
		Parent = page,
	}, { Create.corner(8), Create.padding(10, 8) })
	detailButtons = Create("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(320, 160),
		Position = UDim2.fromOffset(692, 340),
		Parent = page,
	}, { Create.grid(158, 4) })
	local layout = detailButtons:FindFirstChildOfClass("UIGridLayout")
	if layout then
		layout.CellSize = UDim2.fromOffset(158, 34)
	end
end

---------------------------------------------------------------------------
-- Familiars
---------------------------------------------------------------------------

local function familiarButton(text: string, color: Color3?, onClick: () -> (), name: string)
	local b = Widgets.button(text, {
		size = UDim2.fromOffset(158, 32),
		color = color or C.Panel3,
		textSize = 13,
		onClick = onClick,
		parent = familiarButtons,
	})
	b.Name = name
end

local function refreshFamiliars()
	local w = State.wardrobe
	Widgets.clear(familiarGrid, true)
	local list = sortByRarity(w.familiars or {})
	for i, f in list do
		Widgets.card({
			name = "Familiar_" .. f.uid,
			width = 72,
			icon = CosmeticInfo.familiarIcon(f),
			iconColor = CosmeticInfo.familiarColor(f),
			rarity = f.rarity,
			caption = CosmeticInfo.shortName("Familiar", f),
			selected = familiarSelected == f.uid,
			badge = if w.equipped.Familiar == f.uid then "🐾" elseif f.shiny then "✨" else nil,
			layoutOrder = i,
			info = function()
				return CosmeticInfo.familiar(f)
			end,
			onClick = function()
				Sounds.play("Click")
				familiarSelected = f.uid
				refreshFamiliars()
			end,
			parent = familiarGrid,
		})
	end
	if #list == 0 then
		Widgets.label({
			Text = "No familiars yet. Every item from a Coffer has a small chance to be one!",
			TextSize = 13,
			TextWrapped = true,
			TextColor3 = C.Dim,
			Size = UDim2.new(1, -8, 0, 40),
			Parent = familiarGrid,
		})
	end
	local selected = findFamiliar(familiarSelected)
	if not selected then
		familiarSelected = nil
	end
	familiarPreview.show(worn("Robe"), worn("Hat"), selected or wornFamiliar())
	Widgets.clear(familiarButtons, true)
	Widgets.fillInfo(familiarInfo, if selected then CosmeticInfo.familiar(selected) else nil)
	if not selected then
		return
	end
	local f = selected
	if w.equipped.Familiar == f.uid then
		familiarButton("Dismiss", nil, function()
			invoke("Unequip", { kind = "Familiar" })
		end, "DismissButton")
	else
		familiarButton("Summon", C.Accent, function()
			Sounds.play("Pickup")
			invoke("Equip", { uid = f.uid })
		end, "SummonButton")
		familiarButton(
			"Salvage (+" .. (Familiars.SalvageValue[Rarity.rank(f.rarity)] or 1) .. " 💰)",
			C.Bad,
			function()
				invoke("Salvage", { kind = "Familiar", uid = f.uid })
				familiarSelected = nil
			end,
			"SalvageButton"
		)
	end
end

local function buildFamiliars(page: Frame)
	Widgets.label({
		Text = "YOUR FAMILIARS",
		Font = Theme.Black,
		TextSize = 13,
		TextColor3 = C.Gold,
		Size = UDim2.fromOffset(300, 18),
		Parent = page,
	})
	familiarGrid = Create("ScrollingFrame", {
		Name = "FamiliarGrid",
		BackgroundColor3 = C.Panel,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(420, 492),
		Position = UDim2.fromOffset(0, 22),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 5,
		Parent = page,
	}, {
		Create.corner(8),
		Create.padding(8, 8),
		Create("UIGridLayout", {
			CellSize = UDim2.fromOffset(72, 96),
			CellPadding = UDim2.fromOffset(8, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	familiarPreview = makePreview(page, UDim2.fromOffset(250, 300), UDim2.fromOffset(432, 0))
	Widgets.label({
		Name = "FamiliarNote",
		Text = "<b>Familiars</b> follow you around the Plaza and into matches.\n"
			.. "Common and Uncommon ones are just for show. From <b>Rare</b> up, each kind has one small power that grows with rarity.\n"
			.. "Rare familiars glow, Epic ones sparkle, Legendary ones carry an elemental aura and Mythic ones leave a trail. Shiny ones shed gold.",
		RichText = true,
		TextSize = 12,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		Size = UDim2.fromOffset(250, 196),
		Position = UDim2.fromOffset(432, 308),
		Parent = page,
	})
	familiarInfo = Create("Frame", {
		Name = "FamiliarDetails",
		BackgroundColor3 = C.Panel,
		Size = UDim2.fromOffset(320, 330),
		Position = UDim2.fromOffset(692, 0),
		Parent = page,
	}, { Create.corner(8), Create.padding(10, 8) })
	familiarButtons = Create("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(320, 160),
		Position = UDim2.fromOffset(692, 340),
		Parent = page,
	}, { Create.grid(158, 4) })
	local layout = familiarButtons:FindFirstChildOfClass("UIGridLayout")
	if layout then
		layout.CellSize = UDim2.fromOffset(158, 34)
	end
end

---------------------------------------------------------------------------
-- Window
---------------------------------------------------------------------------

local function refresh()
	if not gui then
		return
	end
	coinsLabel.Text = "💰 " .. tostring(State.wardrobe.coins or 0) .. "  Enchanted Coins"
	if not isOpen then
		return
	end
	tabs.set(currentTab)
	for name, page in pages do
		page.Visible = name == currentTab
	end
	if currentTab == "Tailor" then
		refreshTailor()
	elseif currentTab == "Wardrobe" then
		refreshWardrobe()
	elseif currentTab == "Familiars" then
		refreshFamiliars()
	end
end

function WardrobeController.open(tab: string?)
	if tab and pages[tab] then
		currentTab = tab
	end
	isOpen = true
	gui.Enabled = true
	State.setMenu("wardrobe", true)
	refresh()
end

function WardrobeController.close()
	isOpen = false
	gui.Enabled = false
	Widgets.hideTooltip()
	State.setMenu("wardrobe", false)
end

function WardrobeController.isOpen(): boolean
	return isOpen
end

local function build()
	gui = Widgets.screen("Wardrobe", 11)
	gui.Enabled = false
	local window = Widgets.window(gui, {
		title = "The Tailor's Loom",
		icon = "🧵",
		subtitle = "Open coffers, stitch robes and hats, dress up and summon familiars",
		size = Vector2.new(1040, 644),
		onClose = function()
			WardrobeController.close()
		end,
	})
	coinsLabel = Widgets.label({
		Name = "Coins",
		Text = "",
		Font = Theme.Black,
		TextSize = 17,
		TextColor3 = C.Gold,
		TextXAlignment = Enum.TextXAlignment.Center,
		BackgroundColor3 = C.Ink,
		BackgroundTransparency = 0.35,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 32),
		Parent = window.right,
	})
	Create.corner(16).Parent = coinsLabel
	Create.padding(14, 0).Parent = coinsLabel
	tabs = Widgets.tabs(
		window.body,
		{
			{ "Coffers", "🎁  Coffers" },
			{ "Tailor", "🧵  Tailor" },
			{ "Wardrobe", "👘  Wardrobe" },
			{ "Familiars", "🐾  Familiars" },
		},
		160,
		function(id)
			Sounds.play("Click")
			currentTab = id
			refresh()
		end
	)
	for _, name in { "Coffers", "Tailor", "Wardrobe", "Familiars" } do
		pages[name] = Create("Frame", {
			Name = "Page_" .. name,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 1, -44),
			Position = UDim2.fromOffset(0, 44),
			Visible = false,
			Parent = window.body,
		})
	end
	buildCoffers(pages.Coffers)
	buildTailor(pages.Tailor)
	buildWardrobe(pages.Wardrobe)
	buildFamiliars(pages.Familiars)
end

function WardrobeController.init()
	build()
	State.WardrobeChanged:Connect(refresh)
	-- outfits are locked in for the match: close the loom if you get pulled into one
	Players.LocalPlayer:GetAttributeChangedSignal("InMatch"):Connect(function()
		if isOpen and State.inMatch() then
			WardrobeController.close()
		end
	end)
	refresh()
end

return WardrobeController
