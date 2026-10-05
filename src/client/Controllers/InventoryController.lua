-- The Spellbook: manage wands, slot spells into them, and craft new spells in the Spellforge.
--
--   * Click a spell in your bag, then click a wand slot to put it there (swaps if occupied).
--   * Click a spell in a wand, then "Unslot" (or right-click it) to send it back to the bag.
--   * Click spell parts to drop them into the Spellforge, then press Forge.
--   * Triggers and payloads: a Trigger part makes the spell release a second, finished spell (the
--     payload) when something happens (on hit, when it ends...). After adding a trigger, the next
--     spell clicked in the bag becomes the payload (or select one and press "Use as payload").
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
local wandList: ScrollingFrame
local bagPages: { [string]: ScrollingFrame } = {}
local bagTabs: Widgets.TabsHandle
local bagTab = "Spells"
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
		if not draft.payloadUid then
			-- next: the spell this trigger releases
			bagTab = "Spells"
			State.toast("Now pick the PAYLOAD: click the spell this trigger should release", C.Gold)
		end
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
	if not wand then
		local empty = Widgets.panel({
			Name = "EmptyWand_" .. index,
			Size = UDim2.new(1, -10, 0, 44),
			BackgroundColor3 = C.Panel,
			BackgroundTransparency = 0.4,
			LayoutOrder = order,
			Parent = wandList,
		})
		local stroke = empty:FindFirstChildOfClass("UIStroke") :: UIStroke
		stroke.Transparency = 0.75
		Widgets.label({
			Text = index .. "   Empty wand slot  ·  find wands in chests",
			TextColor3 = C.Dim,
			TextSize = 13,
			Size = UDim2.new(1, -24, 1, 0),
			Position = UDim2.fromOffset(14, 0),
			Parent = empty,
		})
		return
	end
	local rarityColor = Theme.rarity(wand.rarity)
	local card = Widgets.panel({
		Name = "Wand_" .. index,
		Size = UDim2.new(1, -10, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = if equipped then C.Panel3 else C.Panel2,
		LayoutOrder = order,
		Parent = wandList,
	})
	Create.padding(10, 8).Parent = card
	Create.list(Enum.FillDirection.Vertical, 6).Parent = card
	local stroke = card:FindFirstChildOfClass("UIStroke") :: UIStroke
	stroke.Color = if equipped then C.Gold elseif isSelected("Wand", index) then Color3.new(1, 1, 1) else rarityColor
	stroke.Transparency = if equipped then 0 else 0.35
	stroke.Thickness = if equipped then 2 else 1.5

	-- header: the wand, its name and type, and Equip
	local top = Create("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 46),
		LayoutOrder = 1,
		Parent = card,
	})
	Widgets.tile({
		size = 46,
		wandColor = Theme.rgb(wand.color),
		gemColor = rarityColor,
		border = rarityColor,
		selected = isSelected("Wand", index),
		onClick = function()
			choose({ kind = "Wand", wand = index })
		end,
		info = function()
			return ItemInfo.wand(wand)
		end,
		parent = top,
	})
	local s = wand.stats
	Widgets.label({
		Text = index .. "  " .. wand.name,
		Font = Theme.Bold,
		TextSize = 15,
		TextColor3 = rarityColor,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Size = UDim2.new(1, -150, 0, 20),
		Position = UDim2.fromOffset(56, 3),
		Parent = top,
	})
	Widgets.label({
		Text = wand.rarity .. " " .. wand.wandType .. "  ·  " .. s.capacity .. " slots",
		TextSize = 12,
		TextColor3 = C.Dim,
		Size = UDim2.new(1, -150, 0, 16),
		Position = UDim2.fromOffset(56, 24),
		Parent = top,
	})
	if equipped then
		local pill = Widgets.label({
			Text = "EQUIPPED",
			Font = Theme.Black,
			TextSize = 11,
			TextColor3 = C.Ink,
			TextXAlignment = Enum.TextXAlignment.Center,
			BackgroundColor3 = C.Gold,
			BackgroundTransparency = 0,
			Size = UDim2.fromOffset(78, 22),
			Position = UDim2.new(1, -78, 0, 2),
			Parent = top,
		})
		Create.corner(11).Parent = pill
	else
		Widgets.button("Equip", {
			size = UDim2.fromOffset(70, 26),
			position = UDim2.new(1, -70, 0, 0),
			textSize = 13,
			onClick = function()
				invoke("Equip", { index = index })
			end,
			parent = top,
		})
	end

	-- stats at a glance
	local chips = Create("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 18),
		LayoutOrder = 2,
		Parent = card,
	}, { Create.list(Enum.FillDirection.Horizontal, 5) })
	Widgets.chip(chips, string.format("💧 %d  +%d/s", s.manaMax, s.manaRegen), C.Mana, 1)
	Widgets.chip(chips, string.format("⏱️ %.2fs", s.castDelay), nil, 2)
	Widgets.chip(chips, string.format("🔄 %.2fs", s.rechargeTime), nil, 3)
	if s.spellsPerCast > 1 then
		Widgets.chip(chips, "✨ casts " .. s.spellsPerCast, C.Accent, 4)
	end
	if s.shuffle then
		Widgets.chip(chips, "🔀 shuffled", C.Dim, 5)
	end
	local perks = {}
	for _, perk in wand.perks do
		table.insert(perks, "⭐ " .. WandGenerator.describePerk(perk))
	end
	if #perks > 0 then
		Widgets.label({
			Text = table.concat(perks, "     "),
			TextSize = 12,
			TextColor3 = C.Gold,
			TextWrapped = true,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, 0, 0, 14),
			LayoutOrder = 3,
			Parent = card,
		})
	end

	-- the spell slots, cast left to right
	local slots = Create("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 44),
		LayoutOrder = 4,
		Parent = card,
	}, { Create.list(Enum.FillDirection.Horizontal, 4) })
	local tileSize = if s.capacity > 8 then 38 else 44
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
end

---------------------------------------------------------------------------
-- Bag column
---------------------------------------------------------------------------

local CARD = 80

local function emptyNote(parent: Instance, text: string, order: number)
	Widgets.label({
		Text = text,
		TextColor3 = C.Dim,
		TextSize = 13,
		TextWrapped = true,
		Size = UDim2.new(1, -8, 0, 36),
		LayoutOrder = order,
		Parent = parent,
	})
end

local function buildBag()
	for _, page in bagPages do
		Widgets.clear(page, true)
	end
	local inv = inventory()
	if not inv then
		return
	end

	-- Spells
	local spellsPage = bagPages.Spells
	Widgets.sectionHeader(
		spellsPage,
		string.format("Spells  %d / %d", #inv.spells, Config.Inventory.MaxSpells),
		"click one, then a wand slot",
		1
	)
	if #inv.spells == 0 then
		emptyNote(spellsPage, "No loose spells. Loot chests, or forge one from parts in the Spellforge.", 2)
	else
		local grid = Widgets.cardGrid(spellsPage, CARD, 2, "SpellCards")
		for i, spell in inv.spells do
			local icon, color = ItemInfo.spellVisual(spell.recipe)
			Widgets.card({
				name = "Spell_" .. spell.uid,
				width = CARD,
				icon = icon,
				iconColor = color,
				rarity = spell.rarity,
				caption = spell.name,
				captionColor = Theme.lighten(Theme.rarity(spell.rarity), 0.35),
				badge = if spell.recipe.trigger then "⚙️" else nil,
				selected = isSelected("Spell", spell.uid) or draft.payloadUid == spell.uid,
				layoutOrder = i,
				onClick = function()
					if draft.trigger and not findBagSpell(draft.payloadUid) then
						-- a trigger is waiting for its payload: this spell goes inside
						draft.payloadUid = spell.uid
						selected = { kind = "Spell", uid = spell.uid }
						Sounds.play("Click")
						State.toast(spell.name .. " is now the payload", C.Good)
						refresh()
					elseif isSelected("Spell", spell.uid) then
						choose(nil)
					else
						choose({ kind = "Spell", uid = spell.uid })
					end
				end,
				info = function()
					return ItemInfo.spell(spell, State.equippedWand())
				end,
				parent = grid,
			})
		end
	end

	-- Parts, grouped by kind
	local partsPage = bagPages.Parts
	local order = 0
	local hints = {
		Form = "what the spell is",
		Element = "what it's made of",
		Modifier = "how it behaves",
		Trigger = "releases a 2nd spell: the payload",
	}
	for _, category in SpellParts.Categories do
		local owned = {}
		for _, part in SpellParts.ByCategory[category] do
			if (inv.parts[part.id] or 0) > 0 then
				table.insert(owned, part)
			end
		end
		order += 1
		Widgets.sectionHeader(partsPage, category .. " parts  " .. #owned, hints[category], order)
		order += 1
		if #owned == 0 then
			emptyNote(partsPage, "None yet", order)
		else
			local grid = Widgets.cardGrid(partsPage, CARD, order, category .. "Cards")
			for i, part in owned do
				local left = available(part.id)
				Widgets.card({
					name = "Part_" .. part.id,
					width = CARD,
					icon = part.icon,
					iconColor = Theme.CategoryColors[category],
					rarity = part.rarity,
					caption = part.name,
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
	end

	-- Potions
	local potionsPage = bagPages.Potions
	local potions = {}
	for _, c in Consumables.List do
		if (inv.consumables[c.id] or 0) > 0 then
			table.insert(potions, c)
		end
	end
	Widgets.sectionHeader(potionsPage, "Potions  " .. #potions, "drink with the key shown", 1)
	if #potions == 0 then
		emptyNote(potionsPage, "No potions. They turn up in chests.", 2)
	else
		local grid = Widgets.cardGrid(potionsPage, CARD, 2, "PotionCards")
		for i, c in potions do
			Widgets.card({
				name = "Potion_" .. c.id,
				width = CARD,
				icon = c.icon,
				iconColor = Theme.rgb(c.color),
				rarity = c.rarity,
				caption = c.name,
				count = inv.consumables[c.id],
				badge = c.key,
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

	-- tab labels with counts
	local partCount = 0
	for _, n in inv.parts do
		if n > 0 then
			partCount += 1
		end
	end
	bagTabs.buttons.Spells.Text = "✨ Spells " .. #inv.spells
	bagTabs.buttons.Parts.Text = "🧩 Parts " .. partCount
	bagTabs.buttons.Potions.Text = "🧪 Potions " .. #potions
	bagTabs.set(bagTab)
	for name, page in bagPages do
		page.Visible = name == bagTab
	end
end

-- What the Spellforge holds right now (the tutorial follows along).
function InventoryController.draftState(): { form: string?, trigger: string?, payload: boolean }
	return { form = draft.form, trigger = draft.trigger, payload = findBagSpell(draft.payloadUid) ~= nil }
end

-- Switches the bag to the tab holding a named element ("Part_Bolt", "Spell_..."), so the tutorial
-- can point at it.
function InventoryController.reveal(elementName: string)
	local tab = if string.sub(elementName, 1, 5) == "Part_"
		then "Parts"
		elseif string.sub(elementName, 1, 7) == "Potion_" then "Potions"
		elseif string.sub(elementName, 1, 6) == "Spell_" then "Spells"
		else nil
	if tab and tab ~= bagTab then
		bagTab = tab
		refresh()
	end
end

---------------------------------------------------------------------------
-- Spellforge
---------------------------------------------------------------------------

-- What each empty Spellforge slot is for (shown when you hover it).
local SLOT_HELP: { [string]: { title: string, body: string } } = {
	Form = {
		title = "Form (required)",
		body = "What the spell is: a bolt, an orb, a nova, a mine... Every spell needs one.",
	},
	Element = { title = "Element (optional)", body = "What it's made of: fire burns, frost slows, lightning arcs..." },
	Modifier = { title = "Modifier (optional)", body = "How it behaves: homing, explosive, triple, bounce..." },
	Trigger = {
		title = "Trigger (optional)",
		body = "WHEN to release a second spell, the payload: on hit, when this spell ends, on a timer... A trigger always needs a payload.",
	},
}

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
		Size = UDim2.fromOffset(68, 66),
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
			else function()
				local help = SLOT_HELP[category]
				return { title = help.title, color = Theme.CategoryColors[category], body = help.body }
			end,
		parent = holder,
	}).Position =
		UDim2.fromOffset(10, 0)
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
	local head = Widgets.sectionHeader(forgeFrame, "✨ Spellforge", "click parts to add them", 0)
	head.Position = UDim2.fromOffset(12, 8)
	head.Size = UDim2.new(1, -24, 0, 22)

	local row1 = Create("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -16, 0, 66),
		Position = UDim2.fromOffset(12, 36),
		Parent = forgeFrame,
	}, { Create.list(Enum.FillDirection.Horizontal, 6) })
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
		Size = UDim2.fromOffset(68, 66),
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
	local needsPayload = draft.trigger ~= nil and payload == nil
	Widgets.tile({
		size = 48,
		icon = pIcon,
		iconColor = pColor,
		border = if payload then Theme.rarity(payload.rarity) else nil,
		empty = payload == nil,
		selected = needsPayload,
		onClick = function()
			if payload then
				draft.payloadUid = nil
			elseif selected and selected.kind == "Spell" and findBagSpell(selected.uid) then
				draft.payloadUid = selected.uid
			else
				bagTab = "Spells"
				State.toast("Click a spell in your bag to make it the payload (add a Trigger first)", C.Dim)
			end
			refresh()
		end,
		info = if payload
			then function()
				return ItemInfo.spell(payload, nil)
			end
			else function()
				return {
					title = "Payload",
					color = C.Gold,
					body = "A whole finished spell from your bag, packed inside this one. The Trigger decides when it's released, "
						.. "and it's cast from wherever this spell is at that moment. Add a Trigger, then click any spell in your bag.",
				}
			end,
		parent = payloadHolder,
	}).Position =
		UDim2.fromOffset(10, 0)
	Widgets.label({
		Text = if needsPayload then "PICK ONE" else "PAYLOAD",
		TextSize = 10,
		Font = Theme.Bold,
		TextColor3 = if needsPayload then C.Gold else C.Dim,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 14),
		Position = UDim2.fromOffset(0, 50),
		Parent = payloadHolder,
	})

	local row2 = Create("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -16, 0, 66),
		Position = UDim2.fromOffset(12, 104),
		Parent = forgeFrame,
	}, { Create.list(Enum.FillDirection.Horizontal, 6) })
	for i = 1, Config.Spell.MaxModifiers do
		local id = draft.mods[i]
		forgeSlot(row2, "MOD " .. i, id, function()
			table.remove(draft.mods, i)
			refresh()
		end, i, "Modifier")
	end

	-- preview
	local preview = Create("Frame", {
		Name = "Preview",
		BackgroundColor3 = C.Ink,
		BackgroundTransparency = 0.5,
		Size = UDim2.new(1, -24, 0, 96),
		Position = UDim2.fromOffset(12, 176),
		Parent = forgeFrame,
	}, { Create.corner(8), Create.padding(8, 6) })
	local recipe = draftRecipe()
	local function guide(text: string, color: Color3)
		Widgets.label({
			Text = text,
			RichText = true,
			TextWrapped = true,
			TextSize = 12,
			TextColor3 = color,
			TextYAlignment = Enum.TextYAlignment.Top,
			Size = UDim2.fromScale(1, 1),
			Parent = preview,
		})
	end
	if needsPayload then
		guide(
			"<b>Now pick the PAYLOAD.</b> A trigger releases a second spell, the payload, when it fires. "
				.. "Click any spell in your bag (Spells tab) to pack it inside this one."
				.. (if draft.form then "" else " This spell still needs a FORM too."),
			C.Gold
		)
		recipe = nil
	elseif payload and not draft.trigger then
		guide(
			"<b>Add a TRIGGER.</b> The payload needs one to decide when it's released: "
				.. "On Hit, On Expire, Timer, Pulse... (Parts tab, Trigger parts)",
			C.Gold
		)
		recipe = nil
	elseif not recipe then
		guide(
			"Every spell needs a <b>FORM</b> (Bolt, Orb, Nova...). Add an <b>ELEMENT</b> and up to "
				.. Config.Spell.MaxModifiers
				.. " <b>MODIFIERS</b>. Optional: a <b>TRIGGER</b> + <b>PAYLOAD</b> makes this spell release a second spell when it hits or ends.",
			C.Dim
		)
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
			local stats = Create("Frame", {
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 1, -22),
				Position = UDim2.fromOffset(0, 22),
				Parent = preview,
			}, {
				Create("UIGridLayout", {
					CellSize = UDim2.new(0.5, -4, 0, 16),
					CellPadding = UDim2.fromOffset(6, 2),
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
			})
			for i, line in lines do
				if i > 8 then
					break
				end
				Widgets.label({
					Text = "<font color='#a096b9'>" .. line[1] .. "</font>  " .. line[2],
					RichText = true,
					TextSize = 12,
					TextTruncate = Enum.TextTruncate.AtEnd,
					LayoutOrder = i,
					Parent = stats,
				})
			end
		end
	end

	-- (forging adds a spell to the bag, unless its payload comes out of the bag)
	local inv = inventory()
	local maxSpells = Config.Inventory.MaxSpells
	local bagFull = inv ~= nil and #inv.spells >= maxSpells and payload == nil
	local forgeButton =
		Widgets.button(if bagFull then "Spell bag full (" .. maxSpells .. "/" .. maxSpells .. ")" else "Forge Spell", {
			size = UDim2.new(0.66, -16, 0, 36),
			position = UDim2.new(0, 12, 1, -46),
			color = if recipe and not bagFull then C.Gold else C.Panel3,
			textColor = if recipe and not bagFull then C.Ink else C.Dim,
			textSize = if bagFull then 13 else 16,
			onClick = function()
				if bagFull then
					State.toast(
						"Your spell bag is full. Select a spell in the Spells tab and press Drop or Dismantle to make room"
							.. (if State.practice() then ", or press Restock Spell Lab." else "."),
						C.Bad
					)
					return
				end
				if needsPayload then
					State.toast("Pick a payload first: click a spell in your bag", C.Bad)
					return
				end
				if not recipe then
					State.toast(
						if payload then "Add a Trigger part for the payload" else "Add a Form part first",
						C.Bad
					)
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
						bagTab = "Spells"
					end
					refresh()
				end
			end,
			parent = forgeFrame,
		})
	forgeButton.Name = "ForgeButton"

	Widgets.button("Clear", {
		size = UDim2.new(0.34, -12, 0, 36),
		position = UDim2.new(0.66, 0, 1, -46),
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
		size = UDim2.fromOffset(100, 30),
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
	local window = Widgets.window(gui, {
		title = "Spellbook",
		icon = "📖",
		subtitle = "Pick a spell, then click a wand slot  ·  wands cast left to right  ·  right-click a slotted spell to unslot it",
		size = Vector2.new(1210, 660),
		onClose = function()
			InventoryController.close()
		end,
	})
	local body = window.body
	restockButton = Widgets.button("♻️ Restock Spell Lab", {
		size = UDim2.fromOffset(170, 32),
		color = Color3.fromRGB(56, 116, 88),
		textSize = 13,
		onClick = function()
			clearDraft()
			selected = nil
			invoke("ResetPractice", {})
		end,
		parent = window.right,
	})

	local function column(x: number, width: number): Frame
		return Widgets.panel({
			Size = UDim2.new(0, width, 1, 0),
			Position = UDim2.fromOffset(x, 0),
			BackgroundColor3 = C.Panel,
			Parent = body,
		})
	end

	-- wands
	local wandCol = column(0, 440)
	local wandHead = Widgets.sectionHeader(wandCol, "Wands", "keys 1-4 switch", 0)
	wandHead.Position = UDim2.fromOffset(12, 8)
	wandHead.Size = UDim2.new(1, -24, 0, 22)
	wandList = Create("ScrollingFrame", {
		Name = "Wands",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, -14, 1, -42),
		Position = UDim2.fromOffset(10, 36),
		ScrollBarThickness = 5,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = wandCol,
	}, { Create.list(Enum.FillDirection.Vertical, 8), Create.padding(2, 2) })

	-- the bag: spells, parts and potions on separate tabs
	local bagCol = column(450, 384)
	local tabsHolder = Create("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -20, 0, 34),
		Position = UDim2.fromOffset(10, 8),
		Parent = bagCol,
	})
	bagTabs = Widgets.tabs(
		tabsHolder,
		{
			{ "Spells", "✨ Spells" },
			{ "Parts", "🧩 Parts" },
			{ "Potions", "🧪 Potions" },
		},
		116,
		function(id)
			Sounds.play("Click")
			bagTab = id
			refresh()
		end
	)
	for _, name in { "Spells", "Parts", "Potions" } do
		bagPages[name] = Create("ScrollingFrame", {
			Name = name .. "Page",
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(1, -14, 1, -54),
			Position = UDim2.fromOffset(10, 48),
			ScrollBarThickness = 5,
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			CanvasSize = UDim2.new(),
			Visible = name == bagTab,
			Parent = bagCol,
		}, { Create.list(Enum.FillDirection.Vertical, 8), Create.padding(2, 2) })
	end

	-- forge and details
	forgeFrame = Widgets.panel({
		Name = "Spellforge",
		Size = UDim2.new(0, 330, 0, 330),
		Position = UDim2.fromOffset(844, 0),
		BackgroundColor3 = C.Panel,
		Parent = body,
	})
	local details = Widgets.panel({
		Name = "Details",
		Size = UDim2.new(0, 330, 1, -340),
		Position = UDim2.fromOffset(844, 340),
		BackgroundColor3 = C.Panel,
		Parent = body,
	})
	local detailsScroll = Create("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, -20, 1, -54),
		Position = UDim2.fromOffset(12, 8),
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
		Size = UDim2.new(1, -20, 0, 32),
		Position = UDim2.new(0, 10, 1, -40),
		Parent = details,
	}, { Create.list(Enum.FillDirection.Horizontal, 6) })
end

function InventoryController.open()
	if isOpen or not State.canAct() then
		return
	end
	isOpen = true
	gui.Enabled = true
	local inv = inventory()
	if inv and #inv.spells == 0 and bagTab == "Spells" then
		bagTab = "Parts" -- nothing to slot yet: show what you can forge with
	end
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
