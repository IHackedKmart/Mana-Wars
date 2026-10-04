-- Developer tools behind the 🛠️ Dev panel: free coins and coffers, every cosmetic and familiar,
-- every kit, a full spell loadout, god mode, infinite mana and match controls, so everything can
-- be tested without spending anything.
-- Who gets it: everyone in Studio; in live servers the experience's owner and the user ids in
-- Config.Dev.AdminUserIds. Every request is checked here on the server.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Rarity = require(Shared.Rarity)
local Cosmetics = require(Shared.Cosmetics)
local Familiars = require(Shared.Familiars)
local PremadeSpells = require(Shared.Spells.PremadeSpells)
local LootTables = require(Shared.LootTables)
local WandGenerator = require(Shared.WandGenerator)
local Combatants = require(script.Parent.Combatants)
local DataService = require(script.Parent.DataService)
local WardrobeService = require(script.Parent.WardrobeService)
local AuctionService = require(script.Parent.AuctionService)
local ClassService = require(script.Parent.ClassService)
local InventoryService = require(script.Parent.InventoryService)
local MatchService = require(script.Parent.MatchService)
local QueueService = require(script.Parent.QueueService)
local ChestService = require(script.Parent.ChestService)

type Combatant = Combatants.Combatant

local DevService = {}

local rng = Random.new()

local function studio(): boolean
	local ok, result = pcall(function()
		return RunService:IsStudio()
	end)
	return ok and result == true
end

function DevService.isDev(player: Player): boolean
	if studio() then
		return true
	end
	if not Config.Dev.Enabled then
		return false
	end
	if table.find(Config.Dev.AdminUserIds, player.UserId) then
		return true
	end
	-- the experience's owner (for a group-owned game, add your id to Config.Dev.AdminUserIds)
	local ok, allowed = pcall(function()
		return game.CreatorType == Enum.CreatorType.User and player.UserId == game.CreatorId
	end)
	return ok and allowed == true
end

---------------------------------------------------------------------------
-- Building items
---------------------------------------------------------------------------

-- The priciest coffer whose odds include this rarity (widest choice of designs).
local function boxFor(rarity: string): number
	local best = 1
	for _, box in Cosmetics.Boxes do
		if box.odds[rarity] then
			best = box.id
		end
	end
	return best
end

local function part(slot: string, rarity: string, design: any?, aura: string?): Cosmetics.CosmeticPart
	local box = boxFor(rarity)
	if design and design.boxes then
		box = design.boxes[1]
	elseif design and design.minBox then
		box = math.max(box, design.minBox)
	end
	local p = Cosmetics.rollPart(rng, box, slot, rarity)
	if design then
		p.design = design.id
	end
	if aura and (slot == "Sigil" or slot == "Gem") then
		p.aura = aura
	end
	p.name = Cosmetics.partName(p)
	return p
end

local function randomAura(rarity: string): string
	local options = {}
	for _, a in Cosmetics.Auras do
		if Rarity.rank(a.minRarity) <= Rarity.rank(rarity) then
			table.insert(options, a.id)
		end
	end
	return options[rng:NextInteger(1, #options)]
end

-- A finished robe and hat of one rarity, sharing an aura (so Epic+ sets leave a trail).
local function outfit(rarity: string, aura: string?): (Cosmetics.Garment, Cosmetics.Garment)
	local a = aura or randomAura(rarity)
	local function garment(kind: string): Cosmetics.Garment
		local parts = {}
		for _, slot in Cosmetics.Garments[kind].slots do
			parts[slot] = part(slot, rarity, nil, a)
		end
		return Cosmetics.craft(kind, parts)
	end
	return garment("Robe"), garment("Hat")
end

local function wardrobeOf(player: Player): DataService.Wardrobe?
	local profile = DataService.profile(player)
	return profile and profile.wardrobe
end

local function giveAll(player: Player, kind: string, items: { any })
	local w = wardrobeOf(player)
	if not w then
		return
	end
	local list = if kind == "Garment" then w.garments elseif kind == "Familiar" then w.familiars else w.parts
	for _, item in items do
		item.dev = true -- test items: kept out of the auction house
		table.insert(list, item)
	end
	DataService.markDirty(player)
	WardrobeService.sync(player)
end

local function familiarsAt(rarity: string, shiny: boolean): { Familiars.Familiar }
	local list = {}
	for _, s in Familiars.Species do
		if Rarity.rank(s.minRarity) <= Rarity.rank(rarity) then
			local f = Familiars.roll(rng, 5, rarity, s.id)
			f.shiny = shiny
			f.name = Familiars.familiarName(f)
			table.insert(list, f)
		end
	end
	return list
end

local function combatantOf(player: Player): Combatant?
	return Combatants.forPlayer(player)
end

local function validRarity(r: any): string
	return if type(r) == "string" and Rarity.Info[r] then r else "Mythic"
end

---------------------------------------------------------------------------
-- Actions
---------------------------------------------------------------------------

-- Everything at once: kits, coins, free coffers, every cosmetic design and aura, outfits of every
-- rarity (a Mythic one worn), every familiar species (a Mythic one summoned) and the in-match loadout.
function DevService.unlockAll(player: Player): (boolean, string)
	local profile = DataService.profile(player)
	if not profile then
		return false, "Your profile is still loading"
	end
	ClassService.setDevMode(player, "all")
	player:SetAttribute("DevFreeCoffers", true)
	player:SetAttribute("DevLoadout", true)
	WardrobeService.addCoins(player, 100000, nil, { type = "Dev" })
	local c = combatantOf(player)
	if c and Combatants.canAct(c) then
		InventoryService.giveDevLoadout(c)
	end
	-- the collection only once (press it again and it just tops up coins); Reset clears it
	for _, f in profile.wardrobe.familiars do
		if f.dev then
			return true,
				"Every kit, +100,000 coins, free coffers and the loadout are on (you already have the full collection)"
		end
	end

	-- one part for every design, at the rarity it first appears
	local parts = {}
	for _, slot in Cosmetics.SlotOrder do
		for _, design in Cosmetics.Designs[slot] do
			table.insert(parts, part(slot, design.minRarity, design, nil))
		end
	end
	-- a Mythic sigil and gem for every aura (stitch matching pairs for trails)
	for _, aura in Cosmetics.Auras do
		table.insert(parts, part("Sigil", "Mythic", nil, aura.id))
		table.insert(parts, part("Gem", "Mythic", nil, aura.id))
	end
	giveAll(player, "Part", parts)

	-- a finished robe and hat at every rarity, and a matched Mythic set to wear
	local garments = {}
	for _, rarity in Rarity.Order do
		local robe, hat = outfit(rarity, nil)
		table.insert(garments, robe)
		table.insert(garments, hat)
	end
	local robe, hat = outfit("Mythic", "Prismatic")
	table.insert(garments, robe)
	table.insert(garments, hat)
	giveAll(player, "Garment", garments)

	-- every species at the rarity it first appears, plus a Shiny Mythic of each
	local familiars = {}
	for _, s in Familiars.Species do
		local f = Familiars.roll(rng, 5, s.minRarity, s.id)
		f.shiny = false
		f.name = Familiars.familiarName(f)
		table.insert(familiars, f)
		if s.minRarity ~= "Mythic" then
			local m = Familiars.roll(rng, 5, "Mythic", s.id)
			m.shiny = true
			m.name = Familiars.familiarName(m)
			table.insert(familiars, m)
		end
	end
	local dragon = Familiars.roll(rng, 5, "Mythic", "Dragonling")
	dragon.shiny = true
	dragon.name = Familiars.familiarName(dragon)
	table.insert(familiars, dragon)
	giveAll(player, "Familiar", familiars)

	local w = profile.wardrobe
	w.equipped.Robe = robe.uid
	w.equipped.Hat = hat.uid
	w.equipped.Familiar = dragon.uid
	DataService.markDirty(player)
	WardrobeService.sync(player)
	WardrobeService.redress(player)
	return true,
		string.format(
			"Unlocked everything: every kit, 100,000 coins, free coffers, %d parts, %d outfit pieces, %d familiars, and a full loadout every match",
			#parts,
			#garments,
			#familiars
		)
end

local actions: { [string]: (Player, { [string]: any }) -> (boolean, string, any?) } = {}

actions.UnlockAll = function(player)
	return DevService.unlockAll(player)
end

actions.Status = function(player)
	return true,
		"",
		{
			kits = ClassService.devModeOf(player),
			freeCoffers = player:GetAttribute("DevFreeCoffers") == true,
			loadout = player:GetAttribute("DevLoadout") == true,
			god = (combatantOf(player) or {} :: any).devGod == true,
			mana = (combatantOf(player) or {} :: any).devMana == true,
			bots = Config.Bots.FillTo,
		}
end

-- Economy -------------------------------------------------------------------

actions.Coins = function(player, args)
	local amount = math.clamp(math.floor(tonumber(args.amount) or 0), 0, 10000000)
	if amount <= 0 then
		local profile = DataService.profile(player)
		if profile then
			profile.coins = 0
			DataService.markDirty(player)
			WardrobeService.sync(player)
		end
		return true, "Coins set to 0"
	end
	WardrobeService.addCoins(player, amount, nil, { type = "Dev" })
	return true, "+" .. amount .. " coins"
end

actions.FreeCoffers = function(player, args)
	player:SetAttribute("DevFreeCoffers", args.on == true)
	return true, if args.on == true then "Coffers are free for you" else "Coffers cost coins again"
end

actions.GiveParts = function(player, args)
	local rarity = validRarity(args.rarity)
	local parts = {}
	for _, slot in Cosmetics.SlotOrder do
		table.insert(parts, part(slot, rarity, nil, nil))
	end
	giveAll(player, "Part", parts)
	return true, "Gave a " .. rarity .. " part for every slot"
end

actions.GiveOutfit = function(player, args)
	local rarity = validRarity(args.rarity)
	local robe, hat = outfit(rarity, nil)
	giveAll(player, "Garment", { robe, hat })
	local w = wardrobeOf(player)
	if w then
		w.equipped.Robe = robe.uid
		w.equipped.Hat = hat.uid
		WardrobeService.sync(player)
		WardrobeService.redress(player)
	end
	return true, "Now wearing a " .. rarity .. " outfit"
end

actions.GiveFamiliars = function(player, args)
	local rarity = validRarity(args.rarity)
	local list = familiarsAt(rarity, args.shiny == true)
	giveAll(player, "Familiar", list)
	return true, "Gave " .. #list .. " " .. rarity .. (if args.shiny == true then " Shiny" else "") .. " familiars"
end

-- Kits and loot ---------------------------------------------------------------

actions.Kits = function(player, args)
	local mode = if args.mode == "all" or args.mode == "locked" then args.mode else "normal"
	ClassService.setDevMode(player, mode)
	return true,
		if mode == "all"
			then "Every kit unlocked"
			elseif mode == "locked" then "Kits locked: only ones you really bought (test the shop)"
			else "Kits back to normal"
end

actions.Loadout = function(player, args)
	player:SetAttribute("DevLoadout", args.on == true)
	local c = combatantOf(player)
	if args.on == true and c and Combatants.canAct(c) then
		InventoryService.giveDevLoadout(c)
	end
	return true, if args.on == true then "Full loadout now and at the start of every match" else "Loadout off"
end

actions.GiveSpell = function(player, args)
	local c = combatantOf(player)
	if not c or type(args.id) ~= "string" or not PremadeSpells.ById[args.id] then
		return false, "Unknown spell"
	end
	local taken, reason = InventoryService.addLoot(c, { kind = "Spell", spell = LootTables.premadeSpell(args.id) })
	InventoryService.sync(c)
	return taken > 0, if taken > 0 then "Added " .. PremadeSpells.ById[args.id].name else (reason or "No room")
end

actions.GiveWand = function(player, args)
	local c = combatantOf(player)
	if not c then
		return false, "No character"
	end
	local rarity = validRarity(args.rarity)
	local taken, reason =
		InventoryService.addLoot(c, { kind = "Wand", wand = WandGenerator.generate(rng, rarity, nil) })
	InventoryService.sync(c)
	return taken > 0, if taken > 0 then "Added a " .. rarity .. " wand" else (reason or "No room")
end

actions.God = function(player, args)
	local c = combatantOf(player)
	if c then
		c.devGod = args.on == true
	end
	return true, if args.on == true then "God mode on: you take no damage" else "God mode off"
end

actions.Mana = function(player, args)
	local c = combatantOf(player)
	if c then
		c.devMana = args.on == true
	end
	return true, if args.on == true then "Infinite mana on" else "Infinite mana off"
end

-- Match -----------------------------------------------------------------------

actions.StartMatch = function(player)
	QueueService.join(player)
	MatchService.devSkip()
	return true, "Joined the queue and skipped the vote"
end

actions.Skip = function()
	MatchService.devSkip()
	return true, "Skipping ahead (vote, countdown or grace period)"
end

actions.Advance = function(_, args)
	local seconds = math.clamp(tonumber(args.seconds) or 60, 1, 3600)
	MatchService.devAdvance(seconds)
	return true, "The match clock jumped " .. seconds .. "s ahead"
end

actions.EndMatch = function()
	MatchService.devEnd()
	return true, "Ending the match"
end

actions.Bots = function(_, args)
	local fill = math.clamp(math.floor(tonumber(args.fill) or 8), 1, Config.Match.MaxParticipants)
	Config.Bots.FillTo = fill
	return true,
		if fill <= 1 then "No bots in the next match" else "Bots will fill the next match to " .. fill .. " mages"
end

actions.KillBots = function()
	local n = 0
	for _, c in Combatants.all() do
		if c.isBot and c.alive and c.inMatch and c.humanoid then
			(c.humanoid :: Humanoid).Health = 0
			n += 1
		end
	end
	return true, "Knocked out " .. n .. " bots"
end

actions.Refill = function()
	ChestService.refill()
	return true, "Every chest refilled"
end

-- Auction and profile -----------------------------------------------------------

actions.FakeListings = function()
	local n = 0
	for i = 1, 6 do
		local rarity = Rarity.Order[rng:NextInteger(1, #Rarity.Order)]
		local kind, item
		if i % 3 == 0 then
			kind, item = "Familiar", familiarsAt(rarity, false)[1]
		elseif i % 3 == 1 then
			local robe = outfit(rarity, nil)
			kind, item = "Garment", robe
		else
			kind, item = "Part", Cosmetics.rollPart(rng, boxFor(rarity), nil, rarity)
		end
		if item then
			item.dev = true -- (bought test items can't be resold to real players)
		end
		if item and AuctionService.devAddListing(kind, item, 10 * Rarity.rank(rarity) ^ 2) then
			n += 1
		end
	end
	return true, n .. " items from the Test Merchant are up for sale"
end

actions.ResetProfile = function(player)
	local profile = DataService.profile(player)
	if not profile then
		return false, "Your profile is still loading"
	end
	DataService.reset(player)
	ClassService.setDevMode(player, "normal")
	player:SetAttribute("DevFreeCoffers", nil)
	player:SetAttribute("DevLoadout", nil)
	WardrobeService.giveStarter(player, profile)
	WardrobeService.sync(player)
	WardrobeService.redress(player)
	return true, "Profile reset: you're a brand new mage again"
end

function DevService.handle(player: Player, action: any, args: any): (boolean, string, any?)
	if not DevService.isDev(player) then
		return false, "Dev tools are for the game's owner"
	end
	local fn = type(action) == "string" and actions[action]
	if not fn then
		return false, "Unknown dev action"
	end
	local ok, success, message, extra = pcall(fn, player, if type(args) == "table" then args else {})
	if not ok then
		warn("[Dev] " .. tostring(action) .. " failed: " .. tostring(success))
		return false, "That didn't work: " .. tostring(success)
	end
	return success, message, extra
end

function DevService.init()
	Remotes.func("DevAction").OnServerInvoke = DevService.handle
	local function mark(player: Player)
		if DevService.isDev(player) then
			player:SetAttribute("Dev", true)
		end
	end
	Players.PlayerAdded:Connect(mark)
	for _, player in Players:GetPlayers() do
		mark(player)
	end
end

return DevService
