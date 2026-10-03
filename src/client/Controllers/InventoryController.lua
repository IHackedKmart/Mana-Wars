-- The Spellbook: manage wands, slot spells into them, and craft new spells in the Spellforge.
--
--   * Click a spell in your bag, then click a wand slot to put it there (swaps if occupied).
--   * Click a spell in a wand, then "Unslot" (or right-click it) to send it back to the bag.
--   * Click spell parts to drop them into the Spellforge, then press Forge.
--   * Select a spell in your bag and press "Use as payload" to nest it inside a trigger spell.
--   * Dismantle any spell in your bag to get its parts back.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Items = require(Shared.Items)
local Consumables = require(Shared.Consumables)
local LootTables = require(Shared.LootTables)
local WandGenerator = require(Shared.WandGenerator)
local SpellParts = require(Shared.Spells.SpellParts)
local SpellBuilder = require(Shared.Spells.SpellBuilder)
local SpellTypes = require(Shared.Spells.SpellTypes)
local Signal = require(Shared.Util.Signal)
local UI = script.Parent.Parent.UI
local Create = require(UI.Create)
local Theme = require(UI.Theme)
local Widgets = require(UI.Widgets)
local ItemInfo = require(UI.ItemInfo)
local State = require(script.Parent.State)
local Sounds = require(script.Parent.Sounds)

local InventoryController = {}

-- Fired after every redraw (draft or inventory changed) and when a spell is forged.
-- The tutorial listens to these to know when each step is done.
InventoryController.Changed = Signal.new()
InventoryController.Forged = Signal.new()

local C = Theme.Colors
local action = Remotes.func("InventoryAction")

type Selection = {
	kind: string, -- "Spell" | "Part" | "Wand" | "Consumable"
	uid: string?,
	id: string?,
	wand: number?,
	slot: number?,
}

local gui: ScreenGui
local panel: Frame
local wandList: ScrollingFrame
local bagList: ScrollingFrame
local forgeFrame: Frame
local detailsInfo: Frame
local detailsButtons: Frame
local isOpen = false
local restockButton: TextButton
local selected: Selection? = nil
local draft = {
	form = nil :: string?,
	element = nil :: string?,
	mods = {} :: { string },
	trigger = nil :: string?,
	payloadUid = nil :: string?,
}

local refresh: () -> ()

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

local function invoke(name: string, args: { [string]: any }): (boolean, string?, any)
	local ok, success, message, extra = pcall(function()
		return action:InvokeServer(name, args)
	end)
	if not ok then
		State.toast("Couldn't reach the server", C.Bad)
		return false, nil, nil
	end
	if message then
		State.toast(message, if success then C.Good else C.Bad)
	end
	return success == true, message, extra
end

local function inventory(): Items.Inventory?
	return State.inventory
end

local function findBagSpell(uid: string?): Items.SpellItem?
	local inv = inventory()
	if not inv or not uid then
		return nil
	end
	for _, spell in inv.spells do
		if spell.uid == uid then
			return spell
		end
	end
	return nil
end

local function draftCount(id: string): number
	local n = 0
	if draft.form == id then
		n += 1
	end
	if draft.element == id then
		n += 1
	end
	if draft.trigger == id then
		n += 1
	end
	for _, m in draft.mods do
		if m == id then
			n += 1
		end
	end
	return n
end

local function available(id: string): number
	local inv = inventory()
	local have = if inv then inv.parts[id] or 0 else 0
	return have - draftCount(id)
end

local function draftRecipe(): SpellTypes.Recipe?
	if not draft.form then
		return nil
	end
	local payload = findBagSpell(draft.payloadUid)
	return {
		form = draft.form,
		element = draft.element,
		mods = table.clone(draft.mods),
		trigger = draft.trigger,
		payload = if payload then payload.recipe else nil,
	}
end

local function choose(sel: Selection?)
	selected = sel
	Sounds.play("Click")
	refresh()
end

local function isSelected(kind: string, key: any, wand: number?, slot: number?): boolean
	local s = selected
	if not s or s.kind ~= kind then
		return false
	end
	if kind == "Spell" then
		return s.uid == key and s.wand == wand and s.slot == slot
	elseif kind == "Part" or kind == "Consumable" then
		return s.id == key
	elseif kind == "Wand" then
		return s.wand == key
	end
	return false
end

local function addPartToDraft(id: string)
	local part = SpellParts.ById[id]
	if not part then
		return
	end
	if available(id) <= 0 then
		State.toast("You have no more " .. part.name .. " parts", C.Bad)
		return
	end
	if part.category == "Form" then
		draft.form = id
	elseif part.category == "Element" then
		draft.element = id
	elseif part.category == "Trigger" then
		draft.trigger = id
	elseif part.category == "Modifier" then
		if #draft.mods >= Config.Spell.MaxModifiers then
			State.toast("A spell can hold " .. Config.Spell.MaxModifiers .. " modifiers", C.Bad)
			return
		end
		table.insert(draft.mods, id)
	end
	Sounds.play("Click")
end

local function clearDraft()
	draft.form = nil
	draft.element = nil
	draft.mods = {}
	draft.trigger = nil
	draft.payloadUid = nil
end

---------------------------------------------------------------------------
-- Wand column
---------------------------------------------------------------------------

local function wandCard(index: number, wand: Items.WandItem | false, equipped: boolean, order: number)
	local card = Widgets.panel({
		Size = UDim2.new(1, -8, 0, if wand then 128 else 56),
		BackgroundColor3 = if equipped then C.Panel3 else C.Panel2,
		LayoutOrder = order,
		Parent = wandList,
	})
	local stroke = card:FindFirstChildOfClass("UIStroke") :: UIStroke
	if not wand then
		stroke.Transparency = 0.7
		Widgets.label({
			Text = index .. "   Empty wand slot - find wands in chests",
			TextColor3 = C.Dim,
			TextSize = 14,
			Size = UDim2.new(1, -20, 1, 0),
			Position = UDim2.fromOffset(12, 0),
			Parent = card,
		})
		return
	end
	stroke.Color = if equipped
		then C.Gold
		elseif isSelected("Wand", index) then Color3.new(1, 1, 1)
		else Theme.rarity(wand.rarity)
	stroke.Transparency = 0

	Widgets.tile({
		size = 46,
		wandColor = Theme.rgb(wand.color),
		gemColor = Theme.rarity(wand.rarity),
		border = Theme.rarity(wand.rarity),
		selected = isSelected("Wand", index),
		onClick = function()
			choose({ kind = "Wand", wand = index })
		end,
		info = function()
			return ItemInfo.wand(wand)
		end,
		parent = card,
	}).Position =
		UDim2.fromOffset(8, 8)

	local s = wand.stats
	local tags = { wand.rarity .. " " .. wand.wandType }
	if s.spellsPerCast > 1 then
		table.insert(tags, "casts " .. s.spellsPerCast .. " at once")
	end
	if s.shuffle then
		table.insert(tags, "shuffled")
	end
	Widgets.label({
		Text = index .. ". " .. wand.name,
		Font = Theme.Bold,
		TextSize = 15,
		TextColor3 = Theme.rarity(wand.rarity),
		TextTruncate = Enum.TextTruncate.AtEnd,
		Size = UDim2.new(1, -180, 0, 18),
		Position = UDim2.fromOffset(62, 6),
		Parent = card,
	})
	Widgets.label({
		Text = table.concat(tags, " · "),
		TextSize = 12,
		TextColor3 = C.Dim,
		Size = UDim2.new(1, -180, 0, 14),
		Position = UDim2.fromOffset(62, 24),
		Parent = card,
	})
	Widgets.label({
		Text = string.format(
			"Mana %d (+%d/s) · Delay %.2fs · Recharge %.2fs",
			s.manaMax,
			s.manaRegen,
			s.castDelay,
			s.rechargeTime
		),
		TextSize = 12,
		Size = UDim2.new(1, -70, 0, 14),
		Position = UDim2.fromOffset(62, 40),
		Parent = card,
	})
	local perks = {}
	for _, perk in wand.perks do
		table.insert(perks, "★ " .. WandGenerator.describePerk(perk))
	end
	Widgets.label({
		Text = if #perks > 0 then table.concat(perks, "   ") else "",
		TextSize = 12,
		TextColor3 = C.Gold,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Size = UDim2.new(1, -70, 0, 14),
		Position = UDim2.fromOffset(62, 55),
		Parent = card,
	})

	local slots = Create("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -16, 0, 42),
		Position = UDim2.fromOffset(8, 78),
		Parent = card,
	}, { Create.list(Enum.FillDirection.Horizontal, 4) })
	local tileSize = if s.capacity > 8 then 36 else 40
	for si = 1, s.capacity do
		local spell = wand.slots[si]
		if spell then
			local icon, color = ItemInfo.spellVisual(spell.recipe)
			Widgets.tile({
				name = "Slot_" .. index .. "_" .. si,
				size = tileSize,
				icon = icon,
				iconColor = color,
				border = Theme.rarity(spell.rarity),
				selected = isSelected("Spell", spell.uid, index, si),
				layoutOrder = si,
				onClick = function()
					local sel = selected
					if sel and sel.kind == "Spell" and sel.uid and sel.uid ~= spell.uid then
						invoke("PlaceSpell", { uid = sel.uid, wand = index, slot = si })
						selected = nil
					elseif isSelected("Spell", spell.uid, index, si) then
						selected = nil
					else
						selected = { kind = "Spell", uid = spell.uid, wand = index, slot = si }
					end
					Sounds.play("Click")
					refresh()
				end,
				onRightClick = function()
					invoke("Unslot", { wand = index, slot = si })
				end,
				info = function()
					return ItemInfo.spell(spell, wand)
				end,
				parent = slots,
			})
		else
			Widgets.tile({
				name = "Slot_" .. index .. "_" .. si,
				size = tileSize,
				empty = true,
				label = tostring(si),
				highlight = selected ~= nil and selected.kind == "Spell",
				layoutOrder = si,
				onClick = function()
					local sel = selected
					if sel and sel.kind == "Spell" and sel.uid then
						invoke("PlaceSpell", { uid = sel.uid, wand = index, slot = si })
						selected = nil
						refresh()
					end
				end,
				parent = slots,
			})
		end
	end

	if equipped then
		Widgets.label({
			Text = "EQUIPPED",
			Font = Theme.Black,
			TextSize = 12,
			TextColor3 = C.Gold,
			TextXAlignment = Enum.TextXAlignment.Right,
			Size = UDim2.fromOffset(100, 16),
			Position = UDim2.new(1, -108, 0, 8),
			Parent = card,
		})
	else
		Widgets.button("Equip", {
			size = UDim2.fromOffset(64, 24),
			position = UDim2.new(1, -72, 0, 6),
			textSize = 13,
			onClick = function()
				invoke("Equip", { index = index })
			end,
			parent = card,
		})
	end
end

---------------------------------------------------------------------------
-- Bag column
---------------------------------------------------------------------------

local function sectionTitle(text: string, order: number)
	Widgets.label({
		Text = text,
		Font = Theme.Black,
		TextSize = 13,
		TextColor3 = C.Dim,
		Size = UDim2.new(1, 0, 0, 18),
		LayoutOrder = order,
		Parent = bagList,
	})
end

local function gridFrame(order: number, count: number, cell: number): Frame
	local perRow = 6
	local rows = math.max(1, math.ceil(count / perRow))
	return Create("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -8, 0, rows * (cell + 6)),
		LayoutOrder = order,
		Parent = bagList,
	}, { Create.grid(cell, 6) })
end

local function buildBag()
	Widgets.clear(bagList, true)
	local inv = inventory()
	if not inv then
		return
	end
	local order = 0
	local function nextOrder(): number
		order += 1
		return order
	end

	sectionTitle(string.format("SPELLS  %d/%d", #inv.spells, Config.Inventory.MaxSpells), nextOrder())
	local spellGrid = gridFrame(nextOrder(), math.max(1, #inv.spells), 50)
	if #inv.spells == 0 then
		Widgets.label({
			Text = "No loose spells. Loot chests or forge some!",
			TextColor3 = C.Dim,
			TextSize = 13,
			Size = UDim2.new(1, 0, 0, 20),
			Parent = spellGrid,
		})
		local grid = spellGrid:FindFirstChildOfClass("UIGridLayout") :: UIGridLayout
		grid.CellSize = UDim2.new(1, 0, 0, 20)
	end
	for i, spell in inv.spells do
		local icon, color = ItemInfo.spellVisual(spell.recipe)
		Widgets.tile({
			name = "Spell_" .. spell.uid,
			size = 50,
			icon = icon,
			iconColor = color,
			border = Theme.rarity(spell.rarity),
			corner = if spell.recipe.trigger then "⚙" else nil,
			selected = isSelected("Spell", spell.uid) or draft.payloadUid == spell.uid,
			layoutOrder = i,
			onClick = function()
				if isSelected("Spell", spell.uid) then
					choose(nil)
				else
					choose({ kind = "Spell", uid = spell.uid })
				end
			end,
			info = function()
				return ItemInfo.spell(spell, State.equippedWand())
			end,
			parent = spellGrid,
		})
	end

	for _, category in SpellParts.Categories do
		local owned = {}
		for _, part in SpellParts.ByCategory[category] do
			if (inv.parts[part.id] or 0) > 0 then
				table.insert(owned, part)
			end
		end
		sectionTitle(string.upper(category) .. " PARTS", nextOrder())
		local grid = gridFrame(nextOrder(), math.max(1, #owned), 50)
		if #owned == 0 then
			local layout = grid:FindFirstChildOfClass("UIGridLayout") :: UIGridLayout
			layout.CellSize = UDim2.new(1, 0, 0, 20)
			Widgets.label({
				Text = "None yet",
				TextColor3 = C.Dim,
				TextSize = 12,
				Size = UDim2.new(1, 0, 0, 20),
				Parent = grid,
			})
		end
		for i, part in owned do
			local left = available(part.id)
			Widgets.tile({
				name = "Part_" .. part.id,
				size = 50,
				icon = part.icon,
				iconColor = Theme.CategoryColors[category],
				border = Theme.rarity(part.rarity),
				count = left,
				empty = left <= 0,
				selected = isSelected("Part", part.id),
				layoutOrder = i,
				onClick = function()
					selected = { kind = "Part", id = part.id }
					addPartToDraft(part.id)
					refresh()
				end,
				info = function()
					return ItemInfo.part(part.id)
				end,
				parent = grid,
			})
		end
	end

	local potions = {}
	for _, c in Consumables.List do
		if (inv.consumables[c.id] or 0) > 0 then
			table.insert(potions, c)
		end
	end
	if #potions > 0 then
		sectionTitle("POTIONS", nextOrder())
		local grid = gridFrame(nextOrder(), #potions, 50)
		for i, c in potions do
			Widgets.tile({
				name = "Potion_" .. c.id,
				size = 50,
				icon = c.icon,
				iconColor = Theme.rgb(c.color),
				border = Theme.rarity(c.rarity),
				count = inv.consumables[c.id],
				label = c.key,
				selected = isSelected("Consumable", c.id),
				layoutOrder = i,
				onClick = function()
					choose({ kind = "Consumable", id = c.id })
				end,
				info = function()
					return ItemInfo.consumable(c.id)
				end,
				parent = grid,
			})
		end
	end
end

---------------------------------------------------------------------------
-- Spellforge
---------------------------------------------------------------------------

local function forgeSlot(
	parent: Instance,
	title: string,
	partId: string?,
	onClear: () -> (),
	order: number,
	category: string
)
	local holder = Create("Frame", {
		Name = "Forge_" .. string.gsub(title, " ", ""),
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(56, 66),
		LayoutOrder = order,
		Parent = parent,
	})
	local part = SpellParts.get(partId)
	Widgets.tile({
		size = 48,
		icon = if part then part.icon else nil,
		iconColor = Theme.CategoryColors[category],
		border = if part then Theme.rarity(part.rarity) else nil,
		empty = part == nil,
		onClick = if part then onClear else nil,
		info = if part
			then function()
				return ItemInfo.part(part.id)
			end
			else nil,
		parent = holder,
	}).Position =
		UDim2.fromOffset(4, 0)
	Widgets.label({
		Text = title,
		TextSize = 10,
		Font = Theme.Bold,
		TextColor3 = C.Dim,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 14),
		Position = UDim2.fromOffset(0, 50),
		Parent = holder,
	})
end

local function buildForge()
	Widgets.clear(forgeFrame, true)
	Widgets.label({
		Text = "✦ SPELLFORGE",
		Font = Theme.Black,
		TextSize = 16,
		TextColor3 = C.Accent,
		Size = UDim2.new(1, 0, 0, 20),
		Position = UDim2.fromOffset(12, 8),
		Parent = forgeFrame,
	})
	Widgets.label({
		Text = "Click parts in your bag to add them",
		TextSize = 11,
		TextColor3 = C.Dim,
		TextXAlignment = Enum.TextXAlignment.Right,
		Size = UDim2.new(1, -24, 0, 20),
		Position = UDim2.fromOffset(12, 8),
		Parent = forgeFrame,
	})

	local row1 = Create("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -16, 0, 66),
		Position = UDim2.fromOffset(8, 32),
		Parent = forgeFrame,
	}, { Create.list(Enum.FillDirection.Horizontal, 2) })
	forgeSlot(row1, "FORM", draft.form, function()
		draft.form = nil
		refresh()
	end, 1, "Form")
	forgeSlot(row1, "ELEMENT", draft.element, function()
		draft.element = nil
		refresh()
	end, 2, "Element")
	forgeSlot(row1, "TRIGGER", draft.trigger, function()
		draft.trigger = nil
		refresh()
	end, 3, "Trigger")

	-- payload slot (a whole spell from the bag)
	local payloadHolder = Create("Frame", {
		Name = "Forge_PAYLOAD",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(56, 66),
		LayoutOrder = 4,
		Parent = row1,
	})
	local payload = findBagSpell(draft.payloadUid)
	if draft.payloadUid and not payload then
		draft.payloadUid = nil
	end
	local pIcon, pColor = nil, nil
	if payload then
		pIcon, pColor = ItemInfo.spellVisual(payload.recipe)
	end
	Widgets.tile({
		size = 48,
		icon = pIcon,
		iconColor = pColor,
		border = if payload then Theme.rarity(payload.rarity) else nil,
		empty = payload == nil,
		onClick = function()
			if payload then
				draft.payloadUid = nil
			elseif selected and selected.kind == "Spell" and findBagSpell(selected.uid) then
				draft.payloadUid = selected.uid
			else
				State.toast("Select a spell in your bag, then click here to make it the payload", C.Dim)
			end
			refresh()
		end,
		info = if payload
			then function()
				return ItemInfo.spell(payload, nil)
			end
			else nil,
		parent = payloadHolder,
	}).Position =
		UDim2.fromOffset(4, 0)
	Widgets.label({
		Text = "PAYLOAD",
		TextSize = 10,
		Font = Theme.Bold,
		TextColor3 = C.Dim,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 14),
		Position = UDim2.fromOffset(0, 50),
		Parent = payloadHolder,
	})

	local row2 = Create("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -16, 0, 66),
		Position = UDim2.fromOffset(8, 100),
		Parent = forgeFrame,
	}, { Create.list(Enum.FillDirection.Horizontal, 2) })
	for i = 1, Config.Spell.MaxModifiers do
		local id = draft.mods[i]
		forgeSlot(row2, "MOD " .. i, id, function()
			table.remove(draft.mods, i)
			refresh()
		end, i, "Modifier")
	end

	-- preview
	local preview = Create("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -24, 0, 92),
		Position = UDim2.fromOffset(12, 170),
		Parent = forgeFrame,
	})
	local recipe = draftRecipe()
	if not recipe then
		Widgets.label({
			Text = "Every spell needs a FORM (Bolt, Orb, Nova...). Add an ELEMENT and up to "
				.. Config.Spell.MaxModifiers
				.. " MODIFIERS. A TRIGGER casts a whole PAYLOAD spell when this one hits or ends.",
			TextWrapped = true,
			TextSize = 12,
			TextColor3 = C.Dim,
			TextYAlignment = Enum.TextYAlignment.Top,
			Size = UDim2.fromScale(1, 1),
			Parent = preview,
		})
	else
		local spec, err = SpellBuilder.compile(recipe)
		if not spec then
			Widgets.label({
				Text = err or "Invalid spell",
				TextColor3 = C.Bad,
				TextSize = 13,
				Font = Theme.Bold,
				Size = UDim2.new(1, 0, 0, 18),
				Parent = preview,
			})
		else
			local rarity = Items.rarityOfRecipe(recipe, LootTables.partRarity)
			Widgets.label({
				Text = spec.name,
				Font = Theme.Bold,
				TextSize = 15,
				TextColor3 = Theme.rarity(rarity),
				TextTruncate = Enum.TextTruncate.AtEnd,
				Size = UDim2.new(1, 0, 0, 18),
				Parent = preview,
			})
			local lines = SpellBuilder.describe(spec)
			local statText = {}
			for i, line in lines do
				if i > 8 then
					break
				end
				table.insert(statText, line[1] .. ": " .. line[2])
			end
			Widgets.label({
				Text = table.concat(statText, "   "),
				TextWrapped = true,
				TextSize = 12,
				TextYAlignment = Enum.TextYAlignment.Top,
				Size = UDim2.new(1, 0, 1, -20),
				Position = UDim2.fromOffset(0, 20),
				Parent = preview,
			})
		end
	end

	local forgeButton = Widgets.button("Forge Spell", {
		size = UDim2.new(0.62, -16, 0, 34),
		position = UDim2.new(0, 12, 1, -44),
		color = if recipe then C.Accent else C.Panel3,
		onClick = function()
			if not recipe then
				State.toast("Add a Form part first", C.Bad)
				return
			end
			local ok, _, newUid = invoke("Forge", {
				form = draft.form,
				element = draft.element,
				mods = table.clone(draft.mods),
				trigger = draft.trigger,
				payloadUid = draft.payloadUid,
			})
			if ok then
				Sounds.play("Forge")
				if type(newUid) == "string" then
					InventoryController.Forged:Fire(newUid)
				end
				clearDraft()
				if type(newUid) == "string" then
					selected = { kind = "Spell", uid = newUid }
				end
				refresh()
			end
		end,
		parent = forgeFrame,
	})
	forgeButton.Name = "ForgeButton"

	Widgets.button("Clear", {
		size = UDim2.new(0.38, -12, 0, 34),
		position = UDim2.new(0.62, 0, 1, -44),
		color = C.Panel3,
		onClick = function()
			clearDraft()
			refresh()
		end,
		parent = forgeFrame,
	})
end

---------------------------------------------------------------------------
-- Details
---------------------------------------------------------------------------

local function detailButton(text: string, color: Color3?, fn: () -> ())
	Widgets.button(text, {
		size = UDim2.fromOffset(102, 30),
		textSize = 13,
		color = color,
		onClick = function()
			fn()
			refresh()
		end,
		parent = detailsButtons,
	})
end

local function buildDetails()
	Widgets.clear(detailsButtons, true)
	local inv = inventory()
	local s = selected
	if not inv or not s then
		Widgets.fillInfo(detailsInfo, {
			title = "Nothing selected",
			color = C.Dim,
			body = "Hover or click anything to see its details. Right-click a spell in a wand to unslot it.",
		})
		return
	end
	if s.kind == "Spell" then
		local spell: Items.SpellItem? = nil
		local wand: Items.WandItem? = nil
		if s.wand and s.slot then
			local w = inv.wands[s.wand]
			if w then
				wand = w
				local slotted = w.slots[s.slot]
				if slotted and slotted.uid == s.uid then
					spell = slotted
				end
			end
		else
			spell = findBagSpell(s.uid)
		end
		if not spell then
			selected = nil
			Widgets.fillInfo(detailsInfo, nil)
			return
		end
		local theSpell = spell
		Widgets.fillInfo(detailsInfo, ItemInfo.spell(theSpell, wand or State.equippedWand()))
		if s.wand then
			detailButton("Unslot", nil, function()
				invoke("Unslot", { wand = s.wand, slot = s.slot })
				selected = nil
			end)
		else
			detailButton("Use as payload", C.Panel3, function()
				draft.payloadUid = theSpell.uid
				refresh()
			end)
			detailButton("Dismantle", Color3.fromRGB(190, 120, 40), function()
				local ok, _, payloadUid = invoke("Dismantle", { uid = theSpell.uid })
				if ok then
					selected = if type(payloadUid) == "string" then { kind = "Spell", uid = payloadUid } else nil
				end
			end)
			detailButton("Drop", C.Bad, function()
				invoke("DropSpell", { uid = theSpell.uid })
				selected = nil
			end)
		end
	elseif s.kind == "Part" and s.id then
		local id = s.id
		Widgets.fillInfo(detailsInfo, ItemInfo.part(id))
		detailButton("Add to forge", nil, function()
			addPartToDraft(id)
			refresh()
		end)
		detailButton("Drop one", C.Bad, function()
			invoke("DropPart", { id = id, count = 1 })
		end)
	elseif s.kind == "Wand" and s.wand then
		local wand = inv.wands[s.wand]
		if not wand then
			selected = nil
			return
		end
		Widgets.fillInfo(detailsInfo, ItemInfo.wand(wand))
		local index = s.wand
		detailButton("Equip", nil, function()
			invoke("Equip", { index = index })
		end)
		if index > 1 then
			detailButton("Move up", C.Panel3, function()
				invoke("SwapWands", { a = index, b = index - 1 })
				selected = { kind = "Wand", wand = index - 1 }
			end)
		end
		detailButton("Drop", C.Bad, function()
			invoke("DropWand", { index = index })
			selected = nil
		end)
	elseif s.kind == "Consumable" and s.id then
		local id = s.id
		Widgets.fillInfo(detailsInfo, ItemInfo.consumable(id))
		detailButton("Drink", nil, function()
			invoke("UseConsumable", { id = id })
		end)
	end
end

---------------------------------------------------------------------------
-- Build / open / close
---------------------------------------------------------------------------

refresh = function()
	if not isOpen then
		return
	end
	local inv = inventory()
	Widgets.clear(wandList, true)
	if inv then
		for i = 1, Config.Inventory.MaxWands do
			wandCard(i, inv.wands[i], inv.equipped == i, i)
		end
	end
	buildBag()
	buildForge()
	buildDetails()
	restockButton.Visible = State.practice()
	InventoryController.Changed:Fire()
end

local function build()
	gui = Widgets.screen("Spellbook", 10)
	gui.Enabled = false
	local root = Widgets.scaledRoot(gui)
	panel = Widgets.panel({
		Size = UDim2.fromOffset(1190, 630),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = C.Background,
		BackgroundTransparency = 0.05,
		Parent = root,
	})
	Widgets.label({
		Text = "SPELLBOOK",
		Font = Theme.Black,
		TextSize = 24,
		TextColor3 = C.Gold,
		Size = UDim2.fromOffset(300, 30),
		Position = UDim2.fromOffset(18, 10),
		Parent = panel,
	})
	Widgets.label({
		Text = "Select a spell, then click a wand slot to equip it.  Wands cast their spells left to right.",
		TextSize = 13,
		TextColor3 = C.Dim,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, -400, 0, 30),
		Position = UDim2.fromOffset(200, 10),
		Parent = panel,
	})
	Widgets.button("✕", {
		size = UDim2.fromOffset(34, 34),
		position = UDim2.new(1, -46, 0, 8),
		color = C.Panel3,
		onClick = function()
			InventoryController.close()
		end,
		parent = panel,
	})
	restockButton = Widgets.button("♻ Restock Spell Lab", {
		size = UDim2.fromOffset(170, 34),
		position = UDim2.new(1, -224, 0, 8),
		color = Color3.fromRGB(60, 120, 90),
		textSize = 13,
		onClick = function()
			clearDraft()
			selected = nil
			invoke("ResetPractice", {})
		end,
		parent = panel,
	})

	local function column(x: number, width: number, title: string): Frame
		local col = Widgets.panel({
			Size = UDim2.new(0, width, 1, -62),
			Position = UDim2.fromOffset(x, 50),
			BackgroundColor3 = C.Panel,
			Parent = panel,
		})
		Widgets.label({
			Text = title,
			Font = Theme.Black,
			TextSize = 14,
			TextColor3 = C.Accent,
			Size = UDim2.new(1, -20, 0, 22),
			Position = UDim2.fromOffset(10, 6),
			Parent = col,
		})
		return col
	end

	local wandCol = column(12, 440, "WANDS  (keys 1-4)")
	wandList = Create("ScrollingFrame", {
		Name = "Wands",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, -12, 1, -36),
		Position = UDim2.fromOffset(8, 30),
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = wandCol,
	}, { Create.list(Enum.FillDirection.Vertical, 8) })

	local bagCol = column(462, 370, "BAG")
	bagList = Create("ScrollingFrame", {
		Name = "Bag",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, -12, 1, -36),
		Position = UDim2.fromOffset(8, 30),
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = bagCol,
	}, { Create.list(Enum.FillDirection.Vertical, 6) })

	forgeFrame = Widgets.panel({
		Name = "Spellforge",
		Size = UDim2.fromOffset(344, 316),
		Position = UDim2.fromOffset(842, 50),
		BackgroundColor3 = C.Panel,
		Parent = panel,
	})
	local details = Widgets.panel({
		Name = "Details",
		Size = UDim2.new(0, 344, 1, -378),
		Position = UDim2.fromOffset(842, 372),
		BackgroundColor3 = C.Panel,
		Parent = panel,
	})
	local detailsScroll = Create("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, -16, 1, -48),
		Position = UDim2.fromOffset(8, 6),
		ScrollBarThickness = 4,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = details,
	})
	detailsInfo = Create("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -8, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = detailsScroll,
	})
	detailsButtons = Create("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -16, 0, 32),
		Position = UDim2.new(0, 8, 1, -38),
		Parent = details,
	}, { Create.list(Enum.FillDirection.Horizontal, 6) })
end

function InventoryController.open()
	if isOpen or not State.canAct() then
		return
	end
	isOpen = true
	gui.Enabled = true
	State.setMenu("inventory", true)
	refresh()
end

function InventoryController.close()
	if not isOpen then
		return
	end
	isOpen = false
	gui.Enabled = false
	Widgets.hideTooltip()
	State.setMenu("inventory", false)
end

function InventoryController.toggle()
	if isOpen then
		InventoryController.close()
	else
		InventoryController.open()
	end
end

function InventoryController.init()
	build()
	State.InventoryChanged:Connect(function()
		refresh()
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if input.KeyCode == Enum.KeyCode.Escape and isOpen and not processed then
			InventoryController.close()
		end
	end)
	-- moving between the lobby Spell Lab and a match swaps the whole inventory
	local function resetView()
		clearDraft()
		selected = nil
		InventoryController.close()
	end
	Players.LocalPlayer:GetAttributeChangedSignal("Alive"):Connect(resetView)
	Players.LocalPlayer:GetAttributeChangedSignal("Practice"):Connect(resetView)
end

function InventoryController.isOpen(): boolean
	return isOpen
end

function InventoryController.getDraft()
	return {
		form = draft.form,
		element = draft.element,
		mods = table.clone(draft.mods),
		trigger = draft.trigger,
		payloadUid = draft.payloadUid,
	}
end

return InventoryController
