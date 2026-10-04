-- Enchanted Coins and the wardrobe: opening Coffers, stitching parts into robes and hats,
-- wearing them, summoning familiars, salvaging junk, and dressing characters (plus the stats
-- their enchantments and familiars give).
-- The data lives in the player's profile (DataService); the auction house moves items and coins
-- through the helpers at the bottom.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Rarity = require(Shared.Rarity)
local Cosmetics = require(Shared.Cosmetics)
local Familiars = require(Shared.Familiars)
local OutfitBuilder = require(Shared.OutfitBuilder)
local Combatants = require(script.Parent.Combatants)
local DataService = require(script.Parent.DataService)
local Events = require(script.Parent.Events)
local FX = require(script.Parent.FX)

type Combatant = Combatants.Combatant
type Garment = Cosmetics.Garment
type CosmeticPart = Cosmetics.CosmeticPart

local WardrobeService = {}

local E = Config.Economy
local rng = Random.new()
local updated = Remotes.event("WardrobeUpdated")

local function wardrobeOf(player: Player): DataService.Wardrobe?
	local profile = DataService.profile(player)
	return profile and profile.wardrobe
end

local function findIndex(list: { any }, uid: string): number?
	for i, item in list do
		if item.uid == uid then
			return i
		end
	end
	return nil
end

-- Sends the whole wardrobe to its owner (it's small: a few hundred plain tables at most).
function WardrobeService.sync(player: Player)
	local profile = DataService.profile(player)
	if not profile then
		return
	end
	player:SetAttribute("Coins", profile.coins)
	updated:FireClient(player, {
		coins = profile.coins,
		parts = profile.wardrobe.parts,
		garments = profile.wardrobe.garments,
		familiars = profile.wardrobe.familiars,
		equipped = profile.wardrobe.equipped,
		listings = profile.wardrobe.listings,
	})
end

local function changed(player: Player)
	DataService.markDirty(player)
	WardrobeService.sync(player)
end

---------------------------------------------------------------------------
-- Coins
---------------------------------------------------------------------------

function WardrobeService.coins(player: Player): number
	local profile = DataService.profile(player)
	return if profile then profile.coins else 0
end

-- Where coins came from or went to, for analytics: a transaction type ("Gameplay", "Shop",
-- "TimedReward", "Onboarding"; "Dev" is never reported) and what it was for.
export type CoinFlow = { type: string, sku: string? }

function WardrobeService.addCoins(player: Player, amount: number, reason: string?, source: CoinFlow?)
	local profile = DataService.profile(player)
	if not profile or amount <= 0 then
		return
	end
	profile.coins += math.floor(amount)
	changed(player)
	local flow = source or { type = "Gameplay", sku = "Other" }
	Events.fire("Coins", player, math.floor(amount), flow.type, flow.sku, profile.coins)
	if reason then
		FX.announceTo(
			player,
			"Toast",
			{ text = "💰 +" .. math.floor(amount) .. " Enchanted Coins  (" .. reason .. ")" }
		)
	end
end

function WardrobeService.spendCoins(player: Player, amount: number, sink: CoinFlow?): boolean
	local profile = DataService.profile(player)
	if not profile or profile.coins < amount then
		return false
	end
	profile.coins -= amount
	changed(player)
	local flow = sink or { type = "Shop", sku = "Other" }
	Events.fire("Coins", player, -amount, flow.type, flow.sku, profile.coins)
	return true
end

local function ordinal(n: number): string
	local suffix = "th"
	if n % 100 < 11 or n % 100 > 13 then
		suffix = ({ "st", "nd", "rd" })[n % 10] or "th"
	end
	return n .. suffix
end

-- Match rewards: in Survival Games 1st place gets 12 and 12th gets 1; a battle royale passes its
-- own `forFirst` and counts places among real players only (`among` = "players" for the toast).
-- Fortune enchantments add a bonus.
function WardrobeService.awardPlacement(c: Combatant, place: number, outOf: number, forFirst: number?, among: string?)
	local player = c.player
	if not player then
		return
	end
	local base = math.max(1, (forFirst or E.CoinsForFirst) + 1 - place)
	local bonus = math.floor(base * (c.gear.fortune or 0) + 0.5)
	WardrobeService.addCoins(
		player,
		base + bonus,
		ordinal(place)
			.. " of "
			.. outOf
			.. (if among then " " .. among else "")
			.. (if bonus > 0 then ", +" .. bonus .. " Fortune" else ""),
		{ type = "Gameplay", sku = "MatchPlacement" }
	)
end

---------------------------------------------------------------------------
-- Items (also used by the auction house)
---------------------------------------------------------------------------

-- Item kinds: "Part" (robe / hat part), "Garment" (a stitched robe or hat) or "Familiar".
local function kindOf(kind: any): string
	return if kind == "Garment" or kind == "Familiar" then kind else "Part"
end
WardrobeService.kindOf = kindOf

local function listOf(w: DataService.Wardrobe, kind: string): { any }
	if kind == "Garment" then
		return w.garments
	elseif kind == "Familiar" then
		return w.familiars
	end
	return w.parts
end

function WardrobeService.hasRoom(player: Player, kind: string, count: number?): boolean
	local w = wardrobeOf(player)
	if not w then
		return false
	end
	local limit = if kind == "Garment" then E.MaxGarments elseif kind == "Familiar" then E.MaxFamiliars else E.MaxParts
	return #listOf(w, kindOf(kind)) + (count or 1) <= limit
end

local function isWorn(w: DataService.Wardrobe, uid: string): boolean
	for _, worn in w.equipped do
		if worn == uid then
			return true
		end
	end
	return false
end

-- Removes and returns an item ("Part", "Garment" or "Familiar"). Worn garments and the
-- summoned familiar can't be taken.
function WardrobeService.takeItem(player: Player, kind: string, uid: string): any
	local w = wardrobeOf(player)
	if not w or type(uid) ~= "string" then
		return nil
	end
	local list = listOf(w, kindOf(kind))
	local i = findIndex(list, uid)
	if not i or isWorn(w, uid) then
		return nil
	end
	local item = table.remove(list, i)
	changed(player)
	return item
end

function WardrobeService.giveItem(player: Player, kind: string, item: any)
	local w = wardrobeOf(player)
	if not w then
		return
	end
	table.insert(listOf(w, kindOf(kind)), item)
	changed(player)
end

---------------------------------------------------------------------------
-- Dressing characters
---------------------------------------------------------------------------

local function wornGarments(player: Player): (Garment?, Garment?, Familiars.Familiar?)
	local w = wardrobeOf(player)
	if not w then
		return nil, nil, nil
	end
	local robe, hat, familiar
	for _, g in w.garments do
		if g.uid == w.equipped.Robe then
			robe = g
		elseif g.uid == w.equipped.Hat then
			hat = g
		end
	end
	for _, f in w.familiars do
		if f.uid == w.equipped.Familiar then
			familiar = f
		end
	end
	return robe, hat, familiar
end

-- Hides the avatar's own hats while a crafted hat is worn.
local function setAccessoryHats(character: Model, visible: boolean)
	for _, acc in character:GetChildren() do
		if acc:IsA("Accessory") then
			local ok, isHat = pcall(function()
				return acc.AccessoryType == Enum.AccessoryType.Hat
			end)
			local handle = acc:FindFirstChild("Handle") :: BasePart?
			if ok and isHat and handle then
				handle.Transparency = if visible then 0 else 1
			end
		end
	end
end

-- Builds a combatant's outfit on their body, sends for their familiar, and works out the
-- stats they give.
function WardrobeService.dressWith(c: Combatant, robe: Garment?, hat: Garment?, familiar: Familiars.Familiar?)
	local garments = {}
	if robe then
		table.insert(garments, robe)
	end
	if hat then
		table.insert(garments, hat)
	end
	local gear = Cosmetics.gear(garments)
	-- a Rare+ familiar's small bonus goes on top of the outfit's
	local stat, amount = nil, 0
	if familiar then
		stat, amount = Familiars.statOf(familiar)
	end
	if stat then
		gear[stat] = (gear[stat] or 0) + amount
	end
	-- a duel is a level playing field: you still look the part, but your outfit's and familiar's
	-- bonuses only count in Survival Games and the Battle Royale
	c.gear = if c.duel then {} else gear
	c.familiar = familiar
	local model = c.model
	if not model then
		return
	end
	-- clients build and animate the familiar themselves (FamiliarController)
	model:SetAttribute("Familiar", if familiar then Familiars.encode(familiar) else nil)
	OutfitBuilder.strip(model)
	local rig = OutfitBuilder.rigOf(model)
	if rig and (robe or hat) then
		local ok, err = pcall(OutfitBuilder.build, rig, robe, hat, true)
		if not ok then
			warn("[Wardrobe] couldn't dress " .. c.name .. ": " .. tostring(err))
		end
	end
	setAccessoryHats(model, hat == nil)
	-- avatar accessories can finish loading after we dress the character
	model:SetAttribute("CustomHat", hat ~= nil)
	if not model:GetAttribute("HatWatch") then
		model:SetAttribute("HatWatch", true)
		model.ChildAdded:Connect(function(child)
			if child:IsA("Accessory") and model:GetAttribute("CustomHat") then
				task.defer(setAccessoryHats, model, false)
			end
		end)
	end
end

function WardrobeService.dress(c: Combatant)
	if not c.player then
		return
	end
	local robe, hat, familiar = wornGarments(c.player)
	WardrobeService.dressWith(c, robe, hat, familiar)
end

-- A random outfit for a bot: cheap gear, so they look different without being strong.
function WardrobeService.dressBot(c: Combatant, botRng: Random)
	local function garment(kind: string): Garment
		local parts = {}
		for _, slot in Cosmetics.Garments[kind].slots do
			local rarity = Rarity.fromRank(botRng:NextInteger(1, 3))
			parts[slot] = Cosmetics.rollPart(botRng, botRng:NextInteger(1, 3), slot, rarity)
		end
		return Cosmetics.craft(kind, parts)
	end
	-- about a third of bots bring a (humble) familiar along
	local familiar = nil
	if botRng:NextNumber() < 0.35 then
		local box = botRng:NextInteger(1, 3)
		familiar = Familiars.roll(botRng, box, Rarity.fromRank(botRng:NextInteger(1, 3)), nil)
	end
	WardrobeService.dressWith(c, garment("Robe"), if botRng:NextNumber() < 0.8 then garment("Hat") else nil, familiar)
end

local function redress(player: Player)
	local c = Combatants.forPlayer(player)
	if c and c.model then
		WardrobeService.dress(c)
	end
end

---------------------------------------------------------------------------
-- Actions
---------------------------------------------------------------------------

local function openBox(player: Player, boxId: any): (boolean, string, any?)
	local box = Cosmetics.Boxes[tonumber(boxId) or 0]
	if not box then
		return false, "Unknown coffer"
	end
	if not WardrobeService.hasRoom(player, "Part", box.parts) then
		return false, "Your wardrobe is full: salvage or sell some parts first"
	end
	if not WardrobeService.hasRoom(player, "Familiar", box.parts) then
		return false, "Your familiar roost is full: salvage or sell some familiars first"
	end
	-- (the dev panel's "free coffers" switch; set by the server only)
	local free = player:GetAttribute("DevFreeCoffers") == true
	if not free and not WardrobeService.spendCoins(player, box.price, { type = "Shop", sku = "Coffer" .. box.id }) then
		return false, "You need " .. box.price .. " Enchanted Coins"
	end
	local got = {}
	for _ = 1, box.parts do
		-- each item has a small chance to be a familiar instead of a part (same rarity odds)
		if Familiars.rollIsFamiliar(rng, box.id) then
			local familiar = Familiars.roll(rng, box.id, Cosmetics.rollRarity(rng, box), nil)
			WardrobeService.giveItem(player, "Familiar", familiar)
			table.insert(got, familiar)
			Events.fire("FamiliarFound", player, familiar)
		else
			local part = Cosmetics.rollPart(rng, box.id)
			WardrobeService.giveItem(player, "Part", part)
			table.insert(got, part)
		end
	end
	Events.fire("CofferOpened", player, box.id)
	return true, "Opened " .. box.name, got
end

local function craft(player: Player, kind: any, picks: any): (boolean, string, any?)
	local w = wardrobeOf(player)
	if not w or type(kind) ~= "string" or type(picks) ~= "table" then
		return false, "Bad request"
	end
	local garment = Cosmetics.Garments[kind]
	if not garment then
		return false, "Unknown garment"
	end
	if #w.garments >= E.MaxGarments then
		return false, "Your wardrobe is full"
	end
	local parts: { [string]: CosmeticPart } = {}
	for _, slot in garment.slots do
		local uid = picks[slot]
		local i = type(uid) == "string" and findIndex(w.parts, uid) or nil
		if not i then
			return false, "Pick a " .. Cosmetics.Slots[slot].label:lower()
		end
		parts[slot] = w.parts[i]
	end
	local ok, err = Cosmetics.validate(kind, parts)
	if not ok then
		return false, err or "Those parts don't fit together"
	end
	for _, part in parts do
		table.remove(w.parts, findIndex(w.parts, part.uid) :: number)
	end
	local made = Cosmetics.craft(kind, parts)
	table.insert(w.garments, made)
	changed(player)
	Events.fire("Crafted", player, made)
	return true, "Made " .. made.name, made.uid
end

local function unbind(player: Player, uid: any): (boolean, string)
	local w = wardrobeOf(player)
	if not w or type(uid) ~= "string" then
		return false, "Bad request"
	end
	local i = findIndex(w.garments, uid)
	if not i then
		return false, "Unknown garment"
	end
	if not WardrobeService.hasRoom(player, "Part", 3) then
		return false, "No room for the parts"
	end
	local g = table.remove(w.garments, i) :: Garment
	for kind, worn in w.equipped do
		if worn == uid then
			w.equipped[kind] = nil
		end
	end
	for _, part in g.parts do
		table.insert(w.parts, part)
	end
	changed(player)
	redress(player)
	return true, "Unpicked " .. g.name .. " into its parts"
end

local function equip(player: Player, uid: any): (boolean, string)
	local w = wardrobeOf(player)
	if not w or type(uid) ~= "string" then
		return false, "Bad request"
	end
	local i = findIndex(w.garments, uid)
	if not i then
		local f = findIndex(w.familiars, uid)
		if not f then
			return false, "Unknown item"
		end
		local familiar = w.familiars[f]
		w.equipped.Familiar = familiar.uid
		changed(player)
		redress(player)
		return true, familiar.name .. " is following you"
	end
	local g = w.garments[i]
	w.equipped[g.kind] = g.uid
	changed(player)
	redress(player)
	return true, "Now wearing " .. g.name
end

local function unequip(player: Player, kind: any): (boolean, string)
	local w = wardrobeOf(player)
	if not w or type(kind) ~= "string" or not (Cosmetics.Garments[kind] or kind == "Familiar") then
		return false, "Bad request"
	end
	w.equipped[kind] = nil
	changed(player)
	redress(player)
	return true, if kind == "Familiar" then "Your familiar is resting" else "Took off your " .. kind:lower()
end

local function salvage(player: Player, kind: any, uid: any): (boolean, string)
	kind = kindOf(kind)
	local item = WardrobeService.takeItem(player, kind, uid)
	if not item then
		return false, "You can't salvage that (is it worn?)"
	end
	local value = 0
	if kind == "Garment" then
		for _, part in item.parts do
			value += Cosmetics.SalvageValue[Rarity.rank(part.rarity)] or 1
		end
	elseif kind == "Familiar" then
		value = Familiars.SalvageValue[Rarity.rank(item.rarity)] or 1
	else
		value = Cosmetics.SalvageValue[Rarity.rank(item.rarity)] or 1
	end
	WardrobeService.addCoins(player, value, nil, { type = "Gameplay", sku = "Salvage" })
	return true, "Salvaged " .. item.name .. " for " .. value .. " coins"
end

-- New mages get a plain robe and hat (already stitched and worn) and some coins to start with.
local function giveStarter(player: Player, profile: DataService.Profile)
	if profile.starter then
		return
	end
	profile.starter = true
	profile.coins += E.StarterCoins
	Events.fire("Coins", player, E.StarterCoins, "Onboarding", "StarterCoins", profile.coins)
	local bySlot = {}
	for _, part in Cosmetics.starterParts() do
		bySlot[part.slot] = part
	end
	for _, kind in Cosmetics.GarmentOrder do
		local parts = {}
		for _, slot in Cosmetics.Garments[kind].slots do
			parts[slot] = bySlot[slot]
		end
		local g = Cosmetics.craft(kind, parts)
		table.insert(profile.wardrobe.garments, g)
		profile.wardrobe.equipped[kind] = g.uid
	end
	DataService.markDirty(player)
end

WardrobeService.giveStarter = giveStarter
WardrobeService.redress = function(player: Player)
	redress(player)
end

function WardrobeService.init()
	DataService.onLoaded(function(player, profile)
		giveStarter(player, profile)
		WardrobeService.sync(player)
		redress(player)
	end)
	Remotes.func("WardrobeAction").OnServerInvoke = function(player: Player, action: any, args: any)
		if not DataService.profile(player) then
			return false, "Your wardrobe is still loading"
		end
		args = if type(args) == "table" then args else {}
		if player:GetAttribute("InMatch") == true and action ~= "OpenBox" then
			-- your outfit's stats are locked in once the match starts
			return false, "Finish your match first"
		end
		if action == "OpenBox" then
			return openBox(player, args.box)
		elseif action == "Craft" then
			return craft(player, args.kind, args.parts)
		elseif action == "Unbind" then
			return unbind(player, args.uid)
		elseif action == "Equip" then
			return equip(player, args.uid)
		elseif action == "Unequip" then
			return unequip(player, args.kind)
		elseif action == "Salvage" then
			return salvage(player, args.kind, args.uid)
		end
		return false, "Unknown action"
	end
	Players.PlayerAdded:Connect(function(player)
		player:SetAttribute("Coins", 0)
	end)
end

return WardrobeService
