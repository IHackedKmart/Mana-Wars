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

State.InventoryChanged = Signal.new()
State.WandChanged = Signal.new()
State.Toast = Signal.new()
State.MenusChanged = Signal.new()

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
	Remotes.event("Announce").OnClientEvent:Connect(function(kind, data)
		if kind == "Toast" and type(data) == "table" and type(data.text) == "string" then
			State.toast(data.text)
		end
	end)
end

return State
