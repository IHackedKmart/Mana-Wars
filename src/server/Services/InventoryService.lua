-- Owns every combatant's inventory: wands (with their slotted spells), the spell bag,
-- spell parts and potions. All client requests are validated here, including the
-- Spellforge (crafting spells from parts) and dismantling spells back into parts.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Items = require(Shared.Items)
local Rarity = require(Shared.Rarity)
local Classes = require(Shared.Classes)
local Consumables = require(Shared.Consumables)
local LootTables = require(Shared.LootTables)
local WandGenerator = require(Shared.WandGenerator)
local SpellBuilder = require(Shared.Spells.SpellBuilder)
local SpellParts = require(Shared.Spells.SpellParts)
local PremadeSpells = require(Shared.Spells.PremadeSpells)
local SpellTypes = require(Shared.Spells.SpellTypes)
local Combatants = require(script.Parent.Combatants)
local GameState = require(script.Parent.GameState)
local CastingService = require(script.Parent.CastingService)
local StatusService = require(script.Parent.StatusService)
local FX = require(script.Parent.FX)
local Events = require(script.Parent.Events)

type Combatant = Combatants.Combatant
type WandItem = Items.WandItem
type SpellItem = Items.SpellItem
type LootEntry = Items.LootEntry

local InventoryService = {}

-- Injected by ChestService: spawns a satchel holding dropped items.
InventoryService.dropHandler = nil :: ((Combatant, { LootEntry }) -> ())?

local inventoryEvent = Remotes.event("InventoryUpdated")
local INV = Config.Inventory
local kitRng = Random.new()

---------------------------------------------------------------------------
-- Wand tools (the visible wand in the character's hand)
---------------------------------------------------------------------------

local LENGTH = { Wand = 2.6, Rod = 3.4, Staff = 5.2, Scepter = 3, Focus = 1.6 }
local THICK = { Wand = 0.24, Rod = 0.3, Staff = 0.36, Scepter = 0.3, Focus = 0.45 }

local function buildTool(wand: WandItem): Tool
	local rank = Rarity.rank(wand.rarity)
	local rc = Rarity.Info[wand.rarity].color
	local rarityColor = Color3.fromRGB(rc[1], rc[2], rc[3])
	local len = LENGTH[wand.wandType] or 3
	local thick = THICK[wand.wandType] or 0.3

	local tool = Instance.new("Tool")
	tool.Name = wand.name
	tool.ToolTip = wand.name
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool.ManualActivationOnly = true
	tool:SetAttribute("WandUid", wand.uid)
	tool.Grip = CFrame.new(0, 0, len * 0.28)

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(thick, thick, len)
	handle.Material = if rank >= 5 then Enum.Material.Metal else Enum.Material.Wood
	handle.Color = Color3.fromRGB(wand.color[1], wand.color[2], wand.color[3])
	handle.CanCollide = false
	handle.CanQuery = false
	handle.Massless = true
	handle.CFrame = CFrame.new()
	handle.Parent = tool

	local tipSize = if wand.wandType == "Focus" then 0.9 + rank * 0.06 else 0.4 + rank * 0.07
	local tip = Instance.new("Part")
	tip.Name = "Gem"
	tip.Shape = Enum.PartType.Ball
	tip.Size = Vector3.new(tipSize, tipSize, tipSize)
	tip.Material = Enum.Material.Neon
	tip.Color = rarityColor
	tip.CanCollide = false
	tip.CanQuery = false
	tip.Massless = true
	tip.CFrame = handle.CFrame * CFrame.new(0, 0, -len / 2 - tipSize * 0.3)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = handle
	weld.Part1 = tip
	weld.Parent = tip
	tip.Parent = tool

	if wand.wandType == "Staff" or wand.wandType == "Scepter" then
		local ring = Instance.new("Part")
		ring.Name = "Ring"
		ring.Shape = Enum.PartType.Cylinder
		ring.Size = Vector3.new(0.15, tipSize * 1.6, tipSize * 1.6)
		ring.Material = Enum.Material.Metal
		ring.Color = Color3.fromRGB(212, 175, 55)
		ring.CanCollide = false
		ring.CanQuery = false
		ring.Massless = true
		ring.CFrame = handle.CFrame * CFrame.new(0, 0, -len / 2 + 0.1) * CFrame.Angles(0, math.rad(90), 0)
		local w = Instance.new("WeldConstraint")
		w.Part0 = handle
		w.Part1 = ring
		w.Parent = ring
		ring.Parent = tool
	end
	if rank >= 4 then
		local light = Instance.new("PointLight")
		light.Color = rarityColor
		light.Range = 6 + rank
		light.Brightness = 1.2
		light.Parent = tip
		local sparkle = Instance.new("ParticleEmitter")
		sparkle.Color = ColorSequence.new(rarityColor)
		sparkle.LightEmission = 1
		sparkle.Size = NumberSequence.new(0.18, 0)
		sparkle.Lifetime = NumberRange.new(0.4, 0.8)
		sparkle.Rate = 6 + rank * 2
		sparkle.Speed = NumberRange.new(0.5, 1.5)
		sparkle.SpreadAngle = Vector2.new(180, 180)
		sparkle.Parent = tip
	end
	local tipAttachment = Instance.new("Attachment")
	tipAttachment.Name = "Tip"
	tipAttachment.Position = Vector3.new(0, 0, -len / 2 - tipSize * 0.6)
	tipAttachment.Parent = handle
	return tool
end

local function clearTools(c: Combatant)
	local containers: { Instance } = {}
	if c.model then
		table.insert(containers, c.model)
	end
	if c.player then
		local backpack = c.player:FindFirstChildOfClass("Backpack")
		if backpack then
			table.insert(containers, backpack)
		end
	end
	for _, container in containers do
		for _, child in container:GetChildren() do
			if child:IsA("Tool") then
				child:Destroy()
			end
		end
	end
end

-- Puts the equipped wand in the character's hand (only one tool exists at a time).
function InventoryService.refreshTools(c: Combatant)
	local inv = c.inventory
	local wand = inv.wands[inv.equipped]
	local model = c.model
	local current: Tool? = nil
	if model then
		current = model:FindFirstChildOfClass("Tool")
	end
	if current and wand and current:GetAttribute("WandUid") == wand.uid then
		return
	end
	clearTools(c)
	if not wand or not model or not Combatants.canAct(c) then
		return
	end
	local tool = buildTool(wand)
	tool.Parent = model
end

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

function InventoryService.sync(c: Combatant)
	if c.player then
		inventoryEvent:FireClient(c.player, c.inventory)
	end
	CastingService.sendState(c)
end

function InventoryService.reset(c: Combatant)
	clearTools(c)
	c.inventory = Items.newInventory()
	c.wandStates = {}
	InventoryService.sync(c)
end

local function findSpell(c: Combatant, uid: string): (SpellItem?, string?, number?, number?)
	local inv = c.inventory
	for i, spell in inv.spells do
		if spell.uid == uid then
			return spell, "bag", i, nil
		end
	end
	for wi, wand in inv.wands do
		if wand then
			for si = 1, wand.stats.capacity do
				local spell = wand.slots[si]
				if spell and spell.uid == uid then
					return spell, "wand", wi, si
				end
			end
		end
	end
	return nil, nil, nil, nil
end

local function addPart(c: Combatant, id: string, count: number): number
	local parts = c.inventory.parts
	local have = parts[id] or 0
	local room = INV.MaxPartStack - have
	local taken = math.clamp(count, 0, room)
	if taken > 0 then
		parts[id] = have + taken
	end
	return taken
end

local function addConsumable(c: Combatant, id: string, count: number): number
	local items = c.inventory.consumables
	local have = items[id] or 0
	local taken = math.clamp(count, 0, INV.MaxConsumableStack - have)
	if taken > 0 then
		items[id] = have + taken
	end
	return taken
end

local function freeWandSlot(c: Combatant): number?
	for i = 1, INV.MaxWands do
		if not c.inventory.wands[i] then
			return i
		end
	end
	return nil
end

-- Adds a loot entry. Returns how many units were taken (0 = nothing) and a reason.
function InventoryService.addLoot(c: Combatant, entry: LootEntry): (number, string?)
	local inv = c.inventory
	if entry.kind == "Part" and entry.id and SpellParts.ById[entry.id] then
		local taken = addPart(c, entry.id, entry.count or 1)
		return taken, if taken == 0 then "You can't carry more of that part" else nil
	elseif entry.kind == "Consumable" and entry.id and Consumables.ById[entry.id] then
		local taken = addConsumable(c, entry.id, entry.count or 1)
		return taken, if taken == 0 then "You can't carry more of that potion" else nil
	elseif entry.kind == "Spell" and entry.spell then
		if #inv.spells >= INV.MaxSpells then
			return 0, "Your spell bag is full"
		end
		table.insert(inv.spells, entry.spell)
		return 1, nil
	elseif entry.kind == "Wand" and entry.wand then
		local slot = freeWandSlot(c)
		if not slot then
			return 0, "Your wand belt is full - drop a wand first"
		end
		inv.wands[slot] = entry.wand
		if not inv.wands[inv.equipped] then
			inv.equipped = slot
		end
		InventoryService.refreshTools(c)
		return 1, nil
	end
	return 0, "Unknown item"
end

-- Empties the inventory into loot entries (used when someone dies).
function InventoryService.takeAllAsLoot(c: Combatant): { LootEntry }
	local inv = c.inventory
	local entries: { LootEntry } = {}
	for _, wand in inv.wands do
		if wand then
			table.insert(entries, { kind = "Wand", wand = wand })
		end
	end
	for _, spell in inv.spells do
		table.insert(entries, { kind = "Spell", spell = spell })
	end
	for id, n in inv.parts do
		if n > 0 then
			table.insert(entries, { kind = "Part", id = id, count = n })
		end
	end
	for id, n in inv.consumables do
		if n > 0 then
			table.insert(entries, { kind = "Consumable", id = id, count = n })
		end
	end
	InventoryService.reset(c)
	return entries
end

-- Hands out a class kit, including its random bonus spell part. Returns the bonus part's id.
function InventoryService.giveKit(c: Combatant, classId: string): string
	local class = Classes.ById[classId] or Classes.ById[Classes.Default]
	c.classId = class.id
	local inv = c.inventory
	for i, w in class.kit.wands do
		if i > INV.MaxWands then
			break
		end
		local wand = WandGenerator.fromTemplate(w.template)
		for si, spellId in w.spells do
			if si <= wand.stats.capacity then
				wand.slots[si] = LootTables.premadeSpell(spellId)
			end
		end
		inv.wands[i] = wand
	end
	for _, spellId in class.kit.spells or {} do
		table.insert(inv.spells, LootTables.premadeSpell(spellId))
	end
	for id, n in class.kit.parts or {} do
		addPart(c, id, n)
	end
	for id, n in class.kit.consumables or {} do
		addConsumable(c, id, n)
	end
	local bonus = Classes.rollBonusPart(class, kitRng)
	addPart(c, bonus, 1)
	inv.equipped = 1
	InventoryService.refreshTools(c)
	InventoryService.sync(c)
	return bonus
end

-- The lobby Spell Lab kit: a roomy practice staff, a twin-cast scepter, a few showcase
-- spells and copies of EVERY spell part, so players can learn crafting by experimenting.
local PRACTICE_SPELLS = { "Fireball", "ChainLightning", "MagicMissile", "ClusterBomb", "Meteor", "Singularity" }

function InventoryService.givePractice(c: Combatant)
	local inv = c.inventory
	local staff = WandGenerator.fromTemplate({
		name = "Spell Lab Staff",
		rarity = "Rare",
		wandType = "Staff",
		color = { 70, 50, 110 },
		stats = { capacity = 6, castDelay = 0.15, rechargeTime = 0.4, manaMax = 800, manaRegen = 250, spread = 1 },
	})
	staff.slots[1] = LootTables.premadeSpell("MagicBolt")
	local scepter = WandGenerator.fromTemplate({
		name = "Twincast Practice Scepter",
		rarity = "Epic",
		wandType = "Scepter",
		color = { 200, 170, 90 },
		stats = {
			capacity = 4,
			spellsPerCast = 2,
			castDelay = 0.25,
			rechargeTime = 0.6,
			manaMax = 600,
			manaRegen = 200,
			spread = 2,
		},
	})
	scepter.slots[1] = LootTables.premadeSpell("Firebolt")
	scepter.slots[2] = LootTables.premadeSpell("Frostbolt")
	inv.wands[1] = staff
	inv.wands[2] = scepter
	for _, id in PRACTICE_SPELLS do
		table.insert(inv.spells, LootTables.premadeSpell(id))
	end
	for _, part in SpellParts.List do
		addPart(c, part.id, Config.Practice.PartCopies)
	end
	for _, potion in Consumables.List do
		addConsumable(c, potion.id, 1)
	end
	inv.equipped = 1
	InventoryService.refreshTools(c)
	InventoryService.sync(c)
end

-- Dev panel loadout: a Mythic and a Legendary wand, a bag topped up with premade spells, 20 of
-- every spell part and a full stack of every potion (on top of whatever kit they already have).
function InventoryService.giveDevLoadout(c: Combatant)
	local rng = Random.new()
	for _, rarity in { "Mythic", "Legendary" } do
		InventoryService.addLoot(c, { kind = "Wand", wand = WandGenerator.generate(rng, rarity, nil) })
	end
	local premades = {}
	for _, p in PremadeSpells.List do
		table.insert(premades, p.id)
	end
	for i = #premades, 2, -1 do
		local j = rng:NextInteger(1, i)
		premades[i], premades[j] = premades[j], premades[i]
	end
	for _, id in premades do
		if #c.inventory.spells >= INV.MaxSpells then
			break
		end
		table.insert(c.inventory.spells, LootTables.premadeSpell(id))
	end
	for _, part in SpellParts.List do
		addPart(c, part.id, 20)
	end
	for _, potion in Consumables.List do
		addConsumable(c, potion.id, INV.MaxConsumableStack)
	end
	InventoryService.refreshTools(c)
	InventoryService.sync(c)
end

function InventoryService.equip(c: Combatant, index: number): boolean
	local inv = c.inventory
	if index < 1 or index > INV.MaxWands or not inv.wands[index] then
		return false
	end
	inv.equipped = index
	InventoryService.refreshTools(c)
	CastingService.sendState(c)
	return true
end

---------------------------------------------------------------------------
-- Potions
---------------------------------------------------------------------------

function InventoryService.useConsumable(c: Combatant, id: string): (boolean, string?)
	if not Combatants.canAct(c) or (not c.practice and not GameState.combatAllowed()) then
		return false, "Not now"
	end
	local inv = c.inventory
	if (inv.consumables[id] or 0) <= 0 then
		return false, "You don't have that"
	end
	local t = workspace:GetServerTimeNow()
	if (c.status.potionReady or 0) > t then
		return false, "Too soon"
	end
	local hum = c.humanoid :: Humanoid
	if id == "HealingDraught" then
		if hum.Health >= hum.MaxHealth then
			return false, "Already at full health"
		end
		StatusService.addRegen(c, 10, 4)
	elseif id == "ManaTonic" then
		CastingService.refillAll(c)
	elseif id == "SwiftnessElixir" then
		StatusService.addHaste(c, 1.35, 12)
	elseif id == "StoneskinPotion" then
		StatusService.addShield(c, 30, 10, { color = { 190, 160, 120 } })
	else
		return false, "Unknown potion"
	end
	c.status.potionReady = t + 1
	inv.consumables[id] -= 1
	if inv.consumables[id] <= 0 then
		inv.consumables[id] = nil
	end
	if c.model then
		FX.all("Potion", c.model, Consumables.ById[id].color)
	end
	InventoryService.sync(c)
	return true, nil
end

---------------------------------------------------------------------------
-- Bots: put found spells into wands and hold the best wand
---------------------------------------------------------------------------

function InventoryService.botOrganize(c: Combatant)
	local inv = c.inventory
	for _, wand in inv.wands do
		if wand then
			for si = 1, wand.stats.capacity do
				if not wand.slots[si] and #inv.spells > 0 then
					wand.slots[si] = table.remove(inv.spells, 1) :: SpellItem
					CastingService.resetDeck(c, wand.uid)
				end
			end
		end
	end
	local best, bestScore = inv.equipped, -1
	for i, wand in inv.wands do
		if wand then
			local filled = 0
			for si = 1, wand.stats.capacity do
				if wand.slots[si] then
					filled += 1
				end
			end
			local score = if filled > 0
				then Rarity.rank(wand.rarity) * 10 + filled * 2 + wand.stats.spellsPerCast * 6
				else 0
			if score > bestScore then
				best, bestScore = i, score
			end
		end
	end
	if best ~= inv.equipped then
		InventoryService.equip(c, best)
	end
end

---------------------------------------------------------------------------
-- Client actions
---------------------------------------------------------------------------

local function isString(v: any, maxLen: number?): boolean
	return type(v) == "string" and #v <= (maxLen or 64)
end

local function isIndex(v: any, max: number): boolean
	return type(v) == "number" and v == math.floor(v) and v >= 1 and v <= max
end

local function drop(c: Combatant, entries: { LootEntry })
	if InventoryService.dropHandler then
		InventoryService.dropHandler(c, entries)
	end
end

local actions: { [string]: (Combatant, any) -> (boolean, string?, any) } = {}

actions.Equip = function(c, args)
	if not isIndex(args.index, INV.MaxWands) then
		return false, "Bad wand"
	end
	return InventoryService.equip(c, args.index), nil
end

actions.SwapWands = function(c, args)
	if not isIndex(args.a, INV.MaxWands) or not isIndex(args.b, INV.MaxWands) then
		return false, "Bad wand"
	end
	local inv = c.inventory
	inv.wands[args.a], inv.wands[args.b] = inv.wands[args.b], inv.wands[args.a]
	if inv.equipped == args.a then
		inv.equipped = args.b
	elseif inv.equipped == args.b then
		inv.equipped = args.a
	end
	InventoryService.refreshTools(c)
	return true
end

-- Move a spell (from the bag or another wand slot) into a wand slot, swapping if occupied.
actions.PlaceSpell = function(c, args)
	if not isString(args.uid) or not isIndex(args.wand, INV.MaxWands) or type(args.slot) ~= "number" then
		return false, "Bad request"
	end
	local inv = c.inventory
	local wand = inv.wands[args.wand]
	if not wand or not isIndex(args.slot, wand.stats.capacity) then
		return false, "No such slot"
	end
	local spell, where, a, b = findSpell(c, args.uid)
	if not spell then
		return false, "Spell not found"
	end
	local existing = wand.slots[args.slot]
	if where == "wand" and a == args.wand and b == args.slot then
		return true
	end
	if where == "bag" then
		if existing then
			inv.spells[a :: number] = existing
		else
			table.remove(inv.spells, a :: number)
		end
	else
		local fromWand = inv.wands[a :: number] :: WandItem
		fromWand.slots[b :: number] = if existing then existing else false
		CastingService.resetDeck(c, fromWand.uid)
	end
	wand.slots[args.slot] = spell
	CastingService.resetDeck(c, wand.uid)
	return true
end

actions.Unslot = function(c, args)
	if not isIndex(args.wand, INV.MaxWands) or type(args.slot) ~= "number" then
		return false, "Bad request"
	end
	local inv = c.inventory
	local wand = inv.wands[args.wand]
	if not wand or not isIndex(args.slot, wand.stats.capacity) then
		return false, "No such slot"
	end
	local spell = wand.slots[args.slot]
	if not spell then
		return false, "Slot is empty"
	end
	if #inv.spells >= INV.MaxSpells then
		return false, "Your spell bag is full"
	end
	wand.slots[args.slot] = false
	table.insert(inv.spells, spell)
	CastingService.resetDeck(c, wand.uid)
	return true
end

-- The Spellforge: combine parts (and optionally a payload spell) into a new spell.
actions.Forge = function(c, args)
	if not isString(args.form) then
		return false, "Pick a Form first"
	end
	if args.element ~= nil and not isString(args.element) then
		return false, "Bad element"
	end
	if args.trigger ~= nil and not isString(args.trigger) then
		return false, "Bad trigger"
	end
	local mods: { string } = {}
	if args.mods ~= nil then
		if type(args.mods) ~= "table" or #args.mods > Config.Spell.MaxModifiers then
			return false, "Too many modifiers"
		end
		for i = 1, #args.mods do
			if not isString(args.mods[i]) then
				return false, "Bad modifier"
			end
			table.insert(mods, args.mods[i])
		end
	end
	local recipe: SpellTypes.Recipe = { form = args.form, element = args.element, mods = mods, trigger = args.trigger }
	local inv = c.inventory
	local payloadIndex: number? = nil
	if args.payloadUid ~= nil then
		if not isString(args.payloadUid) then
			return false, "Bad payload"
		end
		for i, spell in inv.spells do
			if spell.uid == args.payloadUid then
				payloadIndex = i
				recipe.payload = Items.deepCopy(spell.recipe)
				break
			end
		end
		if not payloadIndex then
			return false, "The payload spell must be in your bag"
		end
	end
	local ok, err = SpellBuilder.validate(recipe)
	if not ok then
		return false, err
	end
	local need = SpellBuilder.countParts(recipe)
	for id, n in need do
		if (inv.parts[id] or 0) < n then
			local part = SpellParts.ById[id]
			return false, "Missing part: " .. (if part then part.name else id)
		end
	end
	if not payloadIndex and #inv.spells >= INV.MaxSpells then
		return false, "Your spell bag is full"
	end
	for id, n in need do
		inv.parts[id] -= n
		if inv.parts[id] <= 0 then
			inv.parts[id] = nil
		end
	end
	if payloadIndex then
		table.remove(inv.spells, payloadIndex)
	end
	local spell = Items.newSpell(recipe, nil, Items.rarityOfRecipe(recipe, LootTables.partRarity))
	table.insert(inv.spells, spell)
	if c.player then
		Events.fire("Forged", c.player)
	end
	return true, "Forged " .. spell.name, spell.uid
end

-- Breaks a spell in the bag back into its parts (and its payload spell, if any).
actions.Dismantle = function(c, args)
	if not isString(args.uid) then
		return false, "Bad request"
	end
	local spell, where, index = findSpell(c, args.uid)
	if not spell or where ~= "bag" then
		return false, "Take the spell out of the wand first"
	end
	local inv = c.inventory
	table.remove(inv.spells, index :: number)
	for id, n in SpellBuilder.countParts(spell.recipe) do
		addPart(c, id, n)
	end
	local payloadUid = nil
	if spell.recipe.payload then
		local payload = spell.recipe.payload
		local newSpell = Items.newSpell(payload, nil, Items.rarityOfRecipe(payload, LootTables.partRarity))
		table.insert(inv.spells, newSpell)
		payloadUid = newSpell.uid
	end
	return true, "Dismantled " .. spell.name, payloadUid
end

actions.DropWand = function(c, args)
	if not isIndex(args.index, INV.MaxWands) then
		return false, "Bad wand"
	end
	local inv = c.inventory
	local wand = inv.wands[args.index]
	if not wand then
		return false, "No wand there"
	end
	inv.wands[args.index] = false
	if inv.equipped == args.index then
		for i = 1, INV.MaxWands do
			if inv.wands[i] then
				inv.equipped = i
				break
			end
		end
	end
	InventoryService.refreshTools(c)
	drop(c, { { kind = "Wand", wand = wand } })
	return true, "Dropped " .. wand.name
end

actions.DropSpell = function(c, args)
	if not isString(args.uid) then
		return false, "Bad request"
	end
	local spell, where, index = findSpell(c, args.uid)
	if not spell or where ~= "bag" then
		return false, "Only spells in your bag can be dropped"
	end
	table.remove(c.inventory.spells, index :: number)
	drop(c, { { kind = "Spell", spell = spell } })
	return true, "Dropped " .. spell.name
end

actions.DropPart = function(c, args)
	if not isString(args.id) or not SpellParts.ById[args.id] then
		return false, "Bad part"
	end
	local inv = c.inventory
	local have = inv.parts[args.id] or 0
	local n = if type(args.count) == "number" then math.clamp(math.floor(args.count), 1, have) else 1
	if have <= 0 then
		return false, "You don't have that part"
	end
	inv.parts[args.id] = have - n
	if inv.parts[args.id] <= 0 then
		inv.parts[args.id] = nil
	end
	drop(c, { { kind = "Part", id = args.id, count = n } })
	return true
end

-- Lobby only: throw away the practice inventory and get a fresh Spell Lab kit.
actions.ResetPractice = function(c, _args)
	if not c.practice then
		return false, "Only in the Spell Lab"
	end
	InventoryService.reset(c)
	InventoryService.givePractice(c)
	return true, "Spell Lab kit restocked"
end

actions.UseConsumable = function(c, args)
	if not isString(args.id) then
		return false, "Bad potion"
	end
	return InventoryService.useConsumable(c, args.id)
end

function InventoryService.handle(player: Player, action: any, args: any): (boolean, string?, any)
	local c = Combatants.forPlayer(player)
	if not c then
		return false, "Not ready"
	end
	if type(action) ~= "string" or type(args) ~= "table" then
		return false, "Bad request"
	end
	local fn = actions[action]
	if not fn then
		return false, "Unknown action"
	end
	if not Combatants.canAct(c) then
		return false, "You can't do that right now"
	end
	local ok, okResult, message, extra = pcall(fn, c, args)
	if not ok then
		warn("[Inventory] " .. tostring(okResult))
		return false, "Something went wrong"
	end
	if okResult and action ~= "UseConsumable" then
		InventoryService.sync(c)
	end
	return okResult, message, extra
end

function InventoryService.init()
	Remotes.func("InventoryAction").OnServerInvoke = function(player, action, args)
		return InventoryService.handle(player, action, args)
	end
	Remotes.event("EquipWand").OnServerEvent:Connect(function(player, index)
		local c = Combatants.forPlayer(player)
		if c and c.inMatch and c.alive and isIndex(index, INV.MaxWands) then
			InventoryService.equip(c, index)
			if c.player then
				inventoryEvent:FireClient(c.player, c.inventory)
			end
		end
	end)
	Remotes.event("UseConsumable").OnServerEvent:Connect(function(player, id)
		local c = Combatants.forPlayer(player)
		if c and isString(id) then
			local ok, reason = InventoryService.useConsumable(c, id)
			if not ok and reason then
				FX.announceTo(player, "Toast", { text = reason })
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		local c = Combatants.forPlayer(player)
		if c then
			clearTools(c)
		end
	end)
end

return InventoryService
