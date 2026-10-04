-- Client-side cache of everything the UI shows: inventory, equipped wand state,
-- match attributes, and which menus are open (casting is blocked while one is).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Items = require(Shared.Items)
local Remotes = require(Shared.Remotes)
local Signal = require(Shared.Util.Signal)

export type WandState = {
	uid: string,
	mana: number,
	manaMax: number,
	regen: number,
	t: number,
	nextCastAt: number,
	rechargeUntil: number,
	deckPos: number,
	order: { number },
}

local State = {}

local player = Players.LocalPlayer

State.inventory = nil :: Items.Inventory?
State.wand = nil :: WandState?
State.menus = {} :: { [string]: boolean }
-- coins, cosmetic parts, garments, what's worn and auction listings (see WardrobeService.sync)
State.wardrobe = { coins = 0, parts = {}, garments = {}, familiars = {}, equipped = {}, listings = {} } :: {
	[string]: any,
}

State.InventoryChanged = Signal.new()
State.WandChanged = Signal.new()
State.Toast = Signal.new()
State.MenusChanged = Signal.new()
State.WardrobeChanged = Signal.new()
State.AchievementsChanged = Signal.new()
State.PlayMenuRequested = Signal.new() -- the server (the Plaza portal) asks to show the game mode menu
-- achievement progress and the daily reward streak (see AchievementService.snapshot)
State.achievements = nil :: { stats: { [string]: number }, unlocked: { [string]: number }, daily: { [string]: any } }?

function State.now(): number
	return workspace:GetServerTimeNow()
end

function State.phase(): string
	return ReplicatedStorage:GetAttribute("Phase") or "Waiting"
end

function State.phaseEndsAt(): number
	return ReplicatedStorage:GetAttribute("PhaseEndsAt") or 0
end

function State.alive(): boolean
	return player:GetAttribute("Alive") == true
end

function State.inMatch(): boolean
	return player:GetAttribute("InMatch") == true
end

-- Joined the game: waiting in the library for the next match (or fighting in one).
function State.queued(): boolean
	return player:GetAttribute("Queued") == true
end

-- The game mode this player is queued for ("Survival", "Duel" or "Royale"), if queued.
function State.queuedMode(): string?
	if not State.queued() then
		return nil
	end
	local mode = player:GetAttribute("QueuedMode")
	return if type(mode) == "string" then mode else nil
end

-- Hanging out in the hub (Arcanum Plaza): not queued and not in a match.
function State.inHub(): boolean
	return not State.queued() and not State.inMatch()
end

-- In the Spell Lab (practising on dummies in the hub or the library, outside a match).
function State.practice(): boolean
	return player:GetAttribute("Practice") == true and not State.alive()
end

-- Can cast, open the spellbook and drink potions: alive in a match, or practising outside one.
function State.canAct(): boolean
	if not (State.alive() or State.practice()) then
		return false
	end
	local character = player.Character
	local hum = character and character:FindFirstChildOfClass("Humanoid")
	return hum ~= nil and hum.Health > 0
end

function State.equippedWand(): Items.WandItem?
	local inv = State.inventory
	if not inv then
		return nil
	end
	local wand = inv.wands[inv.equipped]
	return if wand then wand else nil
end

-- Mana is regenerated locally between server updates.
function State.mana(): (number, number)
	local w = State.wand
	if not w then
		return 0, 1
	end
	local mana = math.min(w.manaMax, w.mana + w.regen * (State.now() - w.t))
	return mana, w.manaMax
end

function State.setMenu(name: string, open: boolean)
	if State.menus[name] == open then
		return
	end
	State.menus[name] = open or nil
	State.MenusChanged:Fire()
end

function State.anyMenuOpen(): boolean
	return next(State.menus) ~= nil
end

function State.toast(text: string, color: Color3?)
	State.Toast:Fire(text, color)
end

function State.init()
	Remotes.event("InventoryUpdated").OnClientEvent:Connect(function(inventory)
		State.inventory = inventory
		State.InventoryChanged:Fire()
	end)
	Remotes.event("WandState").OnClientEvent:Connect(function(state)
		State.wand = state
		State.WandChanged:Fire()
	end)
	Remotes.event("WardrobeUpdated").OnClientEvent:Connect(function(snapshot)
		if type(snapshot) == "table" then
			snapshot.familiars = snapshot.familiars or {}
			State.wardrobe = snapshot
			State.WardrobeChanged:Fire()
		end
	end)
	Remotes.event("AchievementsUpdated").OnClientEvent:Connect(function(snapshot)
		if type(snapshot) == "table" then
			State.achievements = snapshot
			State.AchievementsChanged:Fire()
		end
	end)
	Remotes.event("Announce").OnClientEvent:Connect(function(kind, data)
		if kind == "Toast" and type(data) == "table" and type(data.text) == "string" then
			State.toast(data.text)
		elseif kind == "PlayMenu" then
			State.PlayMenuRequested:Fire()
		end
	end)
end

return State
