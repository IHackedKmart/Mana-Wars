-- Registry of everything that can fight: real players and bots share one shape,
-- so the spell, damage and loot code never has to care which one it is dealing with.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Items = require(Shared.Items)

export type WandState = {
	mana: number,
	manaTime: number,
	order: { number }?,
	deckPos: number,
	nextCastAt: number,
	rechargeUntil: number,
}

export type Combatant = {
	id: string,
	name: string,
	player: Player?,
	isBot: boolean,
	model: Model?,
	humanoid: Humanoid?,
	root: BasePart?,
	inventory: Items.Inventory,
	wandStates: { [string]: WandState },
	classId: string,
	inMatch: boolean,
	alive: boolean,
	kills: number,
	lastAttacker: Combatant?,
	lastAttackTime: number,
	lastSpellName: string?,
	status: { [string]: any },
	locked: boolean,
	practice: boolean, -- in the Spell Lab (hub or library): may cast at dummies, can't be hurt
	queued: boolean, -- joined the game: waits in the library and is put in the next match
	queuedAt: number, -- place in line when more players are queued than there are pedestals
	isDummy: boolean, -- a training dummy on a practice range
	history: { { t: number, cf: CFrame } }, -- recent positions, for Chrono's rewind
	lastRewind: number,
	lastSwap: number,
	gear: { [string]: number }, -- stat bonuses from the robe and hat being worn (see Cosmetics)
	place: number?, -- finishing place in the current match (1 = winner)
	familiar: any?, -- the familiar following them (see Familiars), for its power
	bot: { [string]: any }?,
}

local Combatants = {}

local byId: { [string]: Combatant } = {}
local byPlayer: { [Player]: Combatant } = {}
local byModel: { [Model]: Combatant } = {}
local modelList: { Model } = {}
local nextId = 0

local function rebuildModelList()
	table.clear(modelList)
	for model in byModel do
		table.insert(modelList, model)
	end
end

function Combatants.create(name: string, player: Player?): Combatant
	nextId += 1
	local c: Combatant = {
		id = "c" .. nextId,
		name = name,
		player = player,
		isBot = player == nil,
		model = nil,
		humanoid = nil,
		root = nil,
		inventory = Items.newInventory(),
		wandStates = {},
		classId = "Apprentice",
		inMatch = false,
		alive = false,
		kills = 0,
		lastAttacker = nil,
		lastAttackTime = 0,
		lastSpellName = nil,
		status = {},
		locked = false,
		practice = false,
		queued = false,
		queuedAt = 0,
		isDummy = false,
		history = {},
		lastRewind = 0,
		lastSwap = 0,
		gear = {},
		place = nil,
		familiar = nil,
		bot = nil,
	}
	byId[c.id] = c
	if player then
		byPlayer[player] = c
	end
	return c
end

function Combatants.remove(c: Combatant)
	byId[c.id] = nil
	if c.player then
		byPlayer[c.player] = nil
	end
	if c.model then
		byModel[c.model] = nil
		rebuildModelList()
	end
end

function Combatants.setModel(c: Combatant, model: Model?)
	if c.model then
		byModel[c.model] = nil
	end
	c.model = model
	c.humanoid = nil
	c.root = nil
	if model then
		byModel[model] = c
		c.humanoid = model:FindFirstChildOfClass("Humanoid")
		c.root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	end
	rebuildModelList()
end

function Combatants.get(id: string): Combatant?
	return byId[id]
end

function Combatants.forPlayer(player: Player): Combatant?
	return byPlayer[player]
end

function Combatants.fromModel(model: Instance?): Combatant?
	if model and model:IsA("Model") then
		return byModel[model]
	end
	return nil
end

-- Walks up from any part (an arm, an accessory...) to the combatant that owns it.
function Combatants.fromPart(part: Instance?): Combatant?
	local current = part
	while current and current ~= workspace do
		if current:IsA("Model") and byModel[current] then
			return byModel[current]
		end
		current = current.Parent
	end
	return nil
end

function Combatants.all(): { Combatant }
	local list = {}
	for _, c in byId do
		table.insert(list, c)
	end
	return list
end

function Combatants.models(): { Model }
	return modelList
end

-- A combatant that is in the match, alive, and has a body.
function Combatants.isActive(c: Combatant): boolean
	return c.inMatch
		and c.alive
		and c.humanoid ~= nil
		and c.root ~= nil
		and c.humanoid.Health > 0
		and c.root.Parent ~= nil
end

-- Anyone allowed to cast right now: living match fighters, or players practising in the lobby.
function Combatants.canAct(c: Combatant): boolean
	local hum, root = c.humanoid, c.root
	if not hum or not root or hum.Health <= 0 or root.Parent == nil then
		return false
	end
	return (c.inMatch and c.alive) or c.practice
end

function Combatants.active(): { Combatant }
	local list = {}
	for _, c in byId do
		if Combatants.isActive(c) then
			table.insert(list, c)
		end
	end
	return list
end

function Combatants.withinRadius(position: Vector3, radius: number, exclude: Combatant?): { Combatant }
	local list = {}
	for _, c in byId do
		if c ~= exclude and Combatants.isActive(c) then
			local root = c.root :: BasePart
			if (root.Position - position).Magnitude <= radius then
				table.insert(list, c)
			end
		end
	end
	return list
end

function Combatants.nearest(position: Vector3, maxRange: number, exclude: { [Combatant]: boolean }?): Combatant?
	local best, bestDist = nil, maxRange
	for _, c in byId do
		if Combatants.isActive(c) and not (exclude and exclude[c]) then
			local d = ((c.root :: BasePart).Position - position).Magnitude
			if d < bestDist then
				best, bestDist = c, d
			end
		end
	end
	return best
end

-- Position history (sampled a few times a second by StatusService) so Chrono spells can rewind.
local HISTORY_SECONDS = 4.5

function Combatants.recordHistory(t: number)
	for _, c in byId do
		local root = c.root
		if root and Combatants.isActive(c) and not c.isDummy then
			local h = c.history
			table.insert(h, { t = t, cf = root.CFrame })
			while #h > 0 and t - h[1].t > HISTORY_SECONDS do
				table.remove(h, 1)
			end
		elseif #c.history > 0 then
			table.clear(c.history)
		end
	end
end

-- Where this combatant stood `seconds` ago (nil if we don't know).
function Combatants.cframeAgo(c: Combatant, seconds: number, t: number): CFrame?
	local want = t - seconds
	local best: CFrame? = nil
	for _, entry in c.history do
		if entry.t <= want then
			best = entry.cf
		else
			break
		end
	end
	return best or (if c.history[1] then c.history[1].cf else nil)
end

-- Approximate body as a vertical capsule around the root part.
Combatants.CapsuleDown = 2.6
Combatants.CapsuleUp = 1.9
Combatants.CapsuleRadius = 1.4

function Combatants.capsule(c: Combatant): (Vector3, Vector3)
	local p = (c.root :: BasePart).Position
	return p - Vector3.new(0, Combatants.CapsuleDown, 0), p + Vector3.new(0, Combatants.CapsuleUp, 0)
end

function Combatants.centerOf(c: Combatant): Vector3
	return (c.root :: BasePart).Position
end

return Combatants
