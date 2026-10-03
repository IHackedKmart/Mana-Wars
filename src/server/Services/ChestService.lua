-- Chests and loot satchels: spawning, rolling loot, opening, taking items,
-- the classic mid-game refill, and the satchel a mage drops on death.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Items = require(Shared.Items)
local LootTables = require(Shared.LootTables)
local Structures = require(script.Parent.Parent.Map.Structures)
local Combatants = require(script.Parent.Combatants)
local GameState = require(script.Parent.GameState)
local InventoryService = require(script.Parent.InventoryService)

type Combatant = Combatants.Combatant
type LootEntry = Items.LootEntry

export type Chest = {
	id: string,
	model: Model,
	lid: BasePart?,
	lidClosed: CFrame?,
	tier: string,
	title: string,
	entries: { LootEntry },
	position: Vector3,
	opened: boolean,
	isSatchel: boolean,
	viewers: { [Player]: boolean },
	prompt: ProximityPrompt,
}

local ChestService = {}

local chests: { [string]: Chest } = {}
local nextId = 0
local contentsEvent = Remotes.event("ChestContents")
local rng = Random.new()

local function folderFor(isSatchel: boolean): Instance
	if isSatchel then
		local f = workspace:FindFirstChild("Satchels")
		if not f then
			f = Instance.new("Folder")
			f.Name = "Satchels"
			f.Parent = workspace
		end
		return f :: Instance
	end
	local arena = workspace:FindFirstChild("Arena")
	local f = arena and arena:FindFirstChild("Chests")
	if not f then
		f = Instance.new("Folder")
		f.Name = "Chests"
		f.Parent = arena or workspace
	end
	return f :: Instance
end

local function sendContents(player: Player, chest: Chest?)
	if chest then
		contentsEvent:FireClient(player, chest.id, chest.title, chest.entries, chest.tier)
	end
end

local function broadcast(chest: Chest)
	for player in chest.viewers do
		if player.Parent then
			sendContents(player, chest)
		else
			chest.viewers[player] = nil
		end
	end
end

local function swingLid(chest: Chest, open: boolean)
	local lid, closed = chest.lid, chest.lidClosed
	if not lid or not closed then
		return
	end
	local hinge = closed * CFrame.new(0, -0.4, 1.15)
	local target = if open then hinge * CFrame.Angles(1.15, 0, 0) * (hinge:Inverse() * closed) else closed
	TweenService:Create(lid, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { CFrame = target })
		:Play()
end

local function destroyChest(chest: Chest)
	chests[chest.id] = nil
	for player in chest.viewers do
		if player.Parent then
			contentsEvent:FireClient(player, chest.id, nil)
		end
	end
	chest.model:Destroy()
end

local function open(player: Player, chest: Chest)
	local c = Combatants.forPlayer(player)
	if not c or not Combatants.isActive(c) then
		return
	end
	if not chest.opened then
		chest.opened = true
		swingLid(chest, true)
		chest.prompt.ActionText = if chest.isSatchel then "Loot" else "Search"
	end
	chest.viewers[player] = true
	sendContents(player, chest)
end

local function register(
	model: Model,
	tier: string,
	title: string,
	entries: { LootEntry },
	isSatchel: boolean,
	lid: BasePart?
): Chest
	nextId += 1
	local id = "chest" .. nextId
	local primary = model.PrimaryPart :: BasePart
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = if isSatchel then "Loot" else "Open"
	prompt.ObjectText = title
	prompt.HoldDuration = if isSatchel then 0 else 0.25
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = primary

	local chest: Chest = {
		id = id,
		model = model,
		lid = lid,
		lidClosed = if lid then lid.CFrame else nil,
		tier = tier,
		title = title,
		entries = entries,
		position = primary.Position,
		opened = false,
		isSatchel = isSatchel,
		viewers = {},
		prompt = prompt,
	}
	model:SetAttribute("ChestId", id)
	chests[id] = chest
	prompt.Triggered:Connect(function(player)
		open(player, chest)
	end)
	return chest
end

function ChestService.spawnArenaChests(spots: { Structures.ChestSpot })
	local folder = folderFor(false)
	for _, spot in spots do
		local tier = LootTables.Tiers[spot.tier] and spot.tier or "Outer"
		local model, lid = Structures.chest(folder, spot.cframe, tier)
		register(model, tier, LootTables.Tiers[tier].displayName, LootTables.rollChest(rng, tier), false, lid)
	end
end

-- Classic survival games refill: every chest gets brand new (better) loot.
function ChestService.refill()
	for _, chest in chests do
		if not chest.isSatchel then
			local tier = if chest.tier == "Outer" then "Refill" else chest.tier
			chest.entries = LootTables.rollChest(rng, tier)
			if chest.opened then
				chest.opened = false
				swingLid(chest, false)
				chest.prompt.ActionText = "Open"
			end
			broadcast(chest)
		end
	end
end

function ChestService.dropSatchel(position: Vector3, entries: { LootEntry }, label: string): Chest?
	if #entries == 0 then
		return nil
	end
	local model = Structures.satchel(folderFor(true), position, label)
	return register(model, "Satchel", label, entries, true, nil)
end

function ChestService.clear()
	for _, chest in chests do
		destroyChest(chest)
	end
	table.clear(chests)
	local satchels = workspace:FindFirstChild("Satchels")
	if satchels then
		satchels:ClearAllChildren()
	end
end

local function inReach(c: Combatant, chest: Chest): boolean
	if not Combatants.isActive(c) then
		return false
	end
	return ((c.root :: BasePart).Position - chest.position).Magnitude <= Config.Inventory.ChestReach
end

local function afterTake(chest: Chest)
	if chest.isSatchel and #chest.entries == 0 then
		task.delay(0.3, function()
			if chests[chest.id] and #chest.entries == 0 then
				destroyChest(chest)
			end
		end)
	end
	broadcast(chest)
end

-- Takes one entry. Returns ok + message.
function ChestService.take(c: Combatant, chest: Chest, index: number): (boolean, string?)
	local entry = chest.entries[index]
	if not entry then
		return false, "Already taken"
	end
	local taken, reason = InventoryService.addLoot(c, entry)
	if taken <= 0 then
		return false, reason
	end
	if (entry.kind == "Part" or entry.kind == "Consumable") and (entry.count or 1) > taken then
		entry.count = (entry.count or 1) - taken
	else
		table.remove(chest.entries, index)
	end
	return true, nil
end

function ChestService.takeAll(c: Combatant, chest: Chest): (boolean, string?)
	local lastReason: string? = nil
	local any = false
	local i = 1
	while i <= #chest.entries do
		local before = #chest.entries
		local ok, reason = ChestService.take(c, chest, i)
		if ok then
			any = true
		else
			lastReason = reason
		end
		if #chest.entries == before then
			i += 1
		end
	end
	return any, if any then nil else lastReason
end

-- Bots: nearest chest with loot, and a helper to empty it.
function ChestService.nearestWithLoot(position: Vector3, maxDistance: number, ignore: { [string]: boolean }?): Chest?
	local best, bestDist = nil, maxDistance
	for id, chest in chests do
		if #chest.entries > 0 and not (ignore and ignore[id]) then
			local d = (chest.position - position).Magnitude
			if d < bestDist then
				best, bestDist = chest, d
			end
		end
	end
	return best
end

function ChestService.botLoot(c: Combatant, chest: Chest)
	if not chest.opened then
		chest.opened = true
		swingLid(chest, true)
	end
	ChestService.takeAll(c, chest)
	afterTake(chest)
	InventoryService.botOrganize(c)
end

function ChestService.get(id: string): Chest?
	return chests[id]
end

function ChestService.init()
	InventoryService.dropHandler = function(c: Combatant, entries: { LootEntry })
		local root = c.root
		if not root then
			return
		end
		local pos = root.Position + root.CFrame.LookVector * 3 - Vector3.new(0, 1.5, 0)
		ChestService.dropSatchel(pos, entries, c.name .. "'s drop")
	end

	Remotes.func("ChestAction").OnServerInvoke = function(player, action, chestId, index)
		if type(action) ~= "string" or type(chestId) ~= "string" then
			return false, "Bad request"
		end
		local chest = chests[chestId]
		if not chest then
			return false, "That chest is gone"
		end
		if action == "Close" then
			chest.viewers[player] = nil
			return true, nil
		end
		local c = Combatants.forPlayer(player)
		if not c or not inReach(c, chest) then
			chest.viewers[player] = nil
			return false, "Too far away"
		end
		if not GameState.combatAllowed() then
			return false, "Not now"
		end
		local ok, message
		if action == "Take" then
			if type(index) ~= "number" or index ~= math.floor(index) then
				return false, "Bad item"
			end
			ok, message = ChestService.take(c, chest, index)
		elseif action == "TakeAll" then
			ok, message = ChestService.takeAll(c, chest)
		else
			return false, "Unknown action"
		end
		if ok then
			InventoryService.sync(c)
		end
		afterTake(chest)
		return ok, message
	end
end

return ChestService
