-- Enchanted Coins and the wardrobe: opening Coffers, stitching parts into robes and hats,
-- wearing them, salvaging junk, and dressing characters (plus the stats their enchantments give).
-- The data lives in the player's profile (DataService); the auction house moves items and coins
-- through the helpers at the bottom.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Rarity = require(Shared.Rarity)
local Cosmetics = require(Shared.Cosmetics)
local OutfitBuilder = require(Shared.OutfitBuilder)
local Combatants = require(script.Parent.Combatants)
local DataService = require(script.Parent.DataService)
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

function WardrobeService.addCoins(player: Player, amount: number, reason: string?)
	local profile = DataService.profile(player)
	if not profile or amount <= 0 then
		return
	end
	profile.coins += math.floor(amount)
	changed(player)
	if reason then
		FX.announceTo(
			player,
			"Toast",
			{ text = "🪙 +" .. math.floor(amount) .. " Enchanted Coins  (" .. reason .. ")" }
		)
	end
end

function WardrobeService.spendCoins(player: Player, amount: number): boolean
	local profile = DataService.profile(player)
	if not profile or profile.coins < amount then
		return false
	end
	profile.coins -= amount
	changed(player)
	return true
end

local function ordinal(n: number): string
	local suffix = "th"
	if n % 100 < 11 or n % 100 > 13 then
		suffix = ({ "st", "nd", "rd" })[n % 10] or "th"
	end
	return n .. suffix
end

-- Match rewards: 1st place gets 12, 12th gets 1 (Fortune enchantments add a bonus).
function WardrobeService.awardPlacement(c: Combatant, place: number, outOf: number)
	local player = c.player
	if not player then
		return
	end
	local base = math.max(1, E.CoinsForFirst + 1 - place)
	local bonus = math.floor(base * (c.gear.fortune or 0) + 0.5)
	WardrobeService.addCoins(
		player,
		base + bonus,
		ordinal(place) .. " of " .. outOf .. (if bonus > 0 then ", +" .. bonus .. " Fortune" else "")
	)
end

---------------------------------------------------------------------------
-- Items (also used by the auction house)
---------------------------------------------------------------------------

function WardrobeService.hasRoom(player: Player, kind: string, count: number?): boolean
	local w = wardrobeOf(player)
	if not w then
		return false
	end
	if kind == "Garment" then
		return #w.garments + (count or 1) <= E.MaxGarments
	end
	return #w.parts + (count or 1) <= E.MaxParts
end

local function isWorn(w: DataService.Wardrobe, uid: string): boolean
	for _, worn in w.equipped do
		if worn == uid then
			return true
		end
	end
	return false
end

-- Removes and returns an item ("Part" or "Garment"). Worn garments can't be taken.
function WardrobeService.takeItem(player: Player, kind: string, uid: string): any
	local w = wardrobeOf(player)
	if not w or type(uid) ~= "string" then
		return nil
	end
	local list = if kind == "Garment" then w.garments else w.parts
	local i = findIndex(list, uid)
	if not i or (kind == "Garment" and isWorn(w, uid)) then
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
	table.insert(if kind == "Garment" then w.garments else w.parts, item)
	changed(player)
end

---------------------------------------------------------------------------
-- Dressing characters
---------------------------------------------------------------------------

local function wornGarments(player: Player): (Garment?, Garment?)
	local w = wardrobeOf(player)
	if not w then
		return nil, nil
	end
	local robe, hat
	for _, g in w.garments do
		if g.uid == w.equipped.Robe then
			robe = g
		elseif g.uid == w.equipped.Hat then
			hat = g
		end
	end
	return robe, hat
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

-- Builds a combatant's outfit on their body and works out the stats it gives.
function WardrobeService.dressWith(c: Combatant, robe: Garment?, hat: Garment?)
	local garments = {}
	if robe then
		table.insert(garments, robe)
	end
	if hat then
		table.insert(garments, hat)
	end
	c.gear = Cosmetics.gear(garments)
	local model = c.model
	if not model then
		return
	end
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
	local robe, hat = wornGarments(c.player)
	WardrobeService.dressWith(c, robe, hat)
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
	WardrobeService.dressWith(c, garment("Robe"), if botRng:NextNumber() < 0.8 then garment("Hat") else nil)
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
	if not WardrobeService.spendCoins(player, box.price) then
		return false, "You need " .. box.price .. " Enchanted Coins"
	end
	local got = {}
	for _ = 1, box.parts do
		local part = Cosmetics.rollPart(rng, box.id)
		WardrobeService.giveItem(player, "Part", part)
		table.insert(got, part)
	end
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
		return false, "Unknown garment"
	end
	local g = w.garments[i]
	w.equipped[g.kind] = g.uid
	changed(player)
	redress(player)
	return true, "Now wearing " .. g.name
end

local function unequip(player: Player, kind: any): (boolean, string)
	local w = wardrobeOf(player)
	if not w or type(kind) ~= "string" or not Cosmetics.Garments[kind] then
		return false, "Bad request"
	end
	w.equipped[kind] = nil
	changed(player)
	redress(player)
	return true, "Took off your " .. kind:lower()
end

local function salvage(player: Player, kind: any, uid: any): (boolean, string)
	local item = WardrobeService.takeItem(player, if kind == "Garment" then "Garment" else "Part", uid)
	if not item then
		return false, "You can't salvage that (is it worn?)"
	end
	local value = 0
	if kind == "Garment" then
		for _, part in item.parts do
			value += Cosmetics.SalvageValue[Rarity.rank(part.rarity)] or 1
		end
	else
		value = Cosmetics.SalvageValue[Rarity.rank(item.rarity)] or 1
	end
	WardrobeService.addCoins(player, value, nil)
	return true, "Salvaged " .. item.name .. " for " .. value .. " coins"
end

-- New mages get a plain robe and hat (already stitched and worn) and some coins to start with.
local function giveStarter(player: Player, profile: DataService.Profile)
	if profile.starter then
		return
	end
	profile.starter = true
	profile.coins += E.StarterCoins
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
