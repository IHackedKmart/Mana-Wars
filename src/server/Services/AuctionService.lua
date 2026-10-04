-- The auction house: players sell cosmetic parts, finished robes / hats and familiars for
-- Enchanted Coins.
--
-- Listings live in a MemoryStore sorted map shared by every server, so the market is global.
-- Selling is escrowed: the item leaves the seller's wardrobe when it's listed. Buying claims the
-- listing atomically (two buyers can never both get it), the buyer pays and receives the item,
-- and the seller is paid (minus the house's cut) directly if they're in this server, otherwise
-- through a DataStore mailbox they collect on their next visit. Unsold items come back after
-- Config.Economy.AuctionHours, or when the seller cancels.
--
-- Where MemoryStore / DataStores aren't available (Studio without API access) everything falls
-- back to an in-server market, so it still works for testing.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local DataService = require(script.Parent.DataService)
local WardrobeService = require(script.Parent.WardrobeService)
local Events = require(script.Parent.Events)

local AuctionService = {}

local E = Config.Economy
local rng = Random.new()
local SALE = { type = "Shop", sku = "AuctionSale" } -- how sales show up in analytics

export type Listing = {
	id: string,
	seller: number,
	sellerName: string,
	kind: string, -- "Part" | "Garment" | "Familiar"
	item: any,
	price: number,
	created: number,
	expires: number,
	sold: any, -- nil while for sale; buyer id / "cancelled" / "expired" once claimed
	soldAt: number?,
}

local function now(): number
	return os.time()
end

---------------------------------------------------------------------------
-- Storage (MemoryStore, or an in-server fallback)
---------------------------------------------------------------------------

type Store = {
	set: (id: string, listing: Listing, ttl: number) -> boolean,
	get: (id: string) -> Listing?,
	range: (count: number) -> { Listing },
	claim: (id: string, fn: (Listing?) -> Listing?, ttl: number) -> Listing?,
	remove: (id: string) -> (),
	global: boolean,
}

local function localStore(): Store
	local data: { [string]: { value: Listing, expires: number } } = {}
	local function live(id: string): Listing?
		local entry = data[id]
		if entry and entry.expires > now() then
			return entry.value
		end
		data[id] = nil
		return nil
	end
	return {
		global = false,
		set = function(id, listing, ttl)
			data[id] = { value = table.clone(listing), expires = now() + ttl }
			return true
		end,
		get = function(id)
			local v = live(id)
			return if v then table.clone(v) else nil
		end,
		range = function(count)
			local ids = {}
			for id in data do
				if live(id) then
					table.insert(ids, id)
				end
			end
			table.sort(ids, function(a, b)
				return a > b
			end)
			local out = {}
			for i = 1, math.min(count, #ids) do
				table.insert(out, table.clone(data[ids[i]].value))
			end
			return out
		end,
		claim = function(id, fn, ttl)
			local current = live(id)
			local updated = fn(if current then table.clone(current) else nil)
			if updated then
				data[id] = { value = updated, expires = now() + ttl }
			end
			return updated
		end,
		remove = function(id)
			data[id] = nil
		end,
	}
end

local function memoryStore(): Store?
	local ok, service = pcall(function()
		return game:GetService("MemoryStoreService")
	end)
	if not ok or not service then
		return nil
	end
	local map: any
	local probe = pcall(function()
		map = (service :: any):GetSortedMap(DataService.storeName("ManaWars_Auction_v1"))
		map:GetRangeAsync(Enum.SortDirection.Descending, 1)
	end)
	if not probe then
		return nil
	end
	return {
		global = true,
		set = function(id, listing, ttl)
			return (pcall(function()
				map:SetAsync(id, listing, ttl)
			end))
		end,
		get = function(id)
			local okGet, value = pcall(function()
				return map:GetAsync(id)
			end)
			return if okGet then value else nil
		end,
		range = function(count)
			local okRange, items = pcall(function()
				return map:GetRangeAsync(Enum.SortDirection.Descending, count)
			end)
			local out = {}
			if okRange and items then
				for _, entry in items do
					table.insert(out, entry.value)
				end
			end
			return out
		end,
		claim = function(id, fn, ttl)
			local okClaim, result = pcall(function()
				return map:UpdateAsync(id, fn, ttl)
			end)
			return if okClaim then result else nil
		end,
		remove = function(id)
			pcall(function()
				map:RemoveAsync(id)
			end)
		end,
	}
end

-- Mailbox: sale proceeds for sellers who weren't in the buyer's server. { sold = { [id] = coins } }
type Mailbox = {
	send: (userId: number, listingId: string, coins: number) -> boolean,
	take: (userId: number) -> { [string]: number },
}

local function localMailbox(): Mailbox
	local boxes: { [number]: { [string]: number } } = {}
	return {
		send = function(userId, listingId, coins)
			boxes[userId] = boxes[userId] or {}
			boxes[userId][listingId] = coins
			return true
		end,
		take = function(userId)
			local box = boxes[userId] or {}
			boxes[userId] = nil
			return box
		end,
	}
end

local function dataStoreMailbox(): Mailbox?
	local store: DataStore? = nil
	local ok = pcall(function()
		store = DataStoreService:GetDataStore(DataService.storeName("ManaWars_Mailbox_v1"));
		(store :: DataStore):GetAsync("probe")
	end)
	if not ok or not store then
		return nil
	end
	local s = store :: DataStore
	return {
		send = function(userId, listingId, coins)
			return (
				pcall(function()
					s:UpdateAsync("u" .. userId, function(box)
						local b = if type(box) == "table" then box else {}
						b.sold = if type(b.sold) == "table" then b.sold else {}
						b.sold[listingId] = coins
						return b
					end)
				end)
			)
		end,
		take = function(userId)
			local taken = {}
			local okTake = pcall(function()
				s:UpdateAsync("u" .. userId, function(box)
					taken = if type(box) == "table" and type(box.sold) == "table" then box.sold else {}
					return if next(taken) ~= nil then {} else nil -- (nothing to clear: skip the write)
				end)
			end)
			-- only pay out what was actually cleared from the mailbox
			return if okTake then taken else {}
		end,
	}
end

local store: Store = localStore()
local mailbox: Mailbox = localMailbox()

local function ttl(): number
	return math.floor(E.AuctionHours * 3600 + 7 * 86400)
end

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

local function playerById(userId: number): Player?
	for _, p in Players:GetPlayers() do
		if p.UserId == userId then
			return p
		end
	end
	return nil
end

local function countListings(player: Player): number
	local profile = DataService.profile(player)
	local n = 0
	if profile then
		for _ in profile.wardrobe.listings do
			n += 1
		end
	end
	return n
end

local function newId(player: Player): string
	return string.format("%013d_%d_%04d", math.floor(now() * 1000), player.UserId, rng:NextInteger(0, 9999))
end

-- What the browser sees (no internal state).
local function public(l: Listing, viewer: Player): { [string]: any }
	return {
		id = l.id,
		sellerName = l.sellerName,
		kind = l.kind,
		item = l.item,
		price = l.price,
		expires = l.expires,
		mine = l.seller == viewer.UserId,
	}
end

-- Pays a seller who is in this server (their record of the listing goes away).
local function creditSale(seller: Player, id: string, coins: number, itemName: string?)
	local profile = DataService.profile(seller)
	if not profile then
		return false
	end
	local record = profile.wardrobe.listings[id]
	profile.wardrobe.listings[id] = nil
	WardrobeService.addCoins(
		seller,
		coins,
		"sold " .. (itemName or (if record and record.item then record.item.name else "an item")),
		SALE
	)
	Events.fire("AuctionSold", seller, coins)
	task.spawn(DataService.save, seller)
	return true
end

---------------------------------------------------------------------------
-- Actions
---------------------------------------------------------------------------

local browseCache: { at: number, listings: { Listing } } = { at = -math.huge, listings = {} }

function AuctionService.browse(player: Player): { { [string]: any } }
	if os.clock() - browseCache.at > 3 then
		browseCache = { at = os.clock(), listings = store.range(200) }
	end
	local out = {}
	local t = now()
	for _, l in browseCache.listings do
		if l.sold == nil and l.expires > t then
			table.insert(out, public(l, player))
		end
	end
	return out
end

function AuctionService.list(player: Player, kind: any, uid: any, price: any): (boolean, string)
	local profile = DataService.profile(player)
	if not profile then
		return false, "Still loading"
	end
	kind = WardrobeService.kindOf(kind)
	price = math.floor(tonumber(price) or 0)
	if price < 1 or price > E.MaxPrice then
		return false, "Pick a price between 1 and " .. E.MaxPrice
	end
	if countListings(player) >= E.MaxListings then
		return false, "You can only have " .. E.MaxListings .. " listings at once"
	end
	local item = WardrobeService.takeItem(player, kind, uid)
	if not item then
		return false, "You can't sell that (is it worn?)"
	end
	-- items from the dev panel stay out of the real market
	local test = item.dev == true
	if kind == "Garment" and type(item.parts) == "table" then
		for _, p in item.parts do
			test = test or p.dev == true
		end
	end
	if test then
		WardrobeService.giveItem(player, kind, item)
		return false, "Test items from the dev panel can't be sold"
	end
	local t = now()
	local listing: Listing = {
		id = newId(player),
		seller = player.UserId,
		sellerName = player.DisplayName,
		kind = kind,
		item = item,
		price = price,
		created = t,
		expires = t + math.floor(E.AuctionHours * 3600),
		sold = nil,
	}
	-- record it on the seller first (and save), so a crash can never lose or duplicate the item
	profile.wardrobe.listings[listing.id] = { kind = kind, item = item, price = price, expires = listing.expires }
	DataService.save(player)
	if not store.set(listing.id, listing, ttl()) then
		profile.wardrobe.listings[listing.id] = nil
		WardrobeService.giveItem(player, kind, item)
		task.spawn(DataService.save, player)
		return false, "The auction house is busy, try again"
	end
	browseCache.at = -math.huge
	WardrobeService.sync(player)
	return true, "Listed " .. item.name .. " for " .. price .. " coins"
end

function AuctionService.buy(player: Player, id: any): (boolean, string)
	if type(id) ~= "string" or not DataService.profile(player) then
		return false, "Bad request"
	end
	local listing = store.get(id)
	local t = now()
	if not listing or listing.sold ~= nil or listing.expires <= t then
		browseCache.at = -math.huge
		return false, "That listing is gone"
	end
	if listing.seller == player.UserId then
		return false, "That's your own listing"
	end
	if not WardrobeService.hasRoom(player, listing.kind) then
		return false, "Your wardrobe is full"
	end
	if not WardrobeService.spendCoins(player, listing.price, { type = "Shop", sku = "AuctionPurchase" }) then
		return false, "You need " .. listing.price .. " Enchanted Coins"
	end
	local claimed = store.claim(id, function(current)
		if current and current.sold == nil and current.expires > now() then
			current.sold = player.UserId
			current.soldAt = now()
			return current
		end
		return nil
	end, ttl())
	if not claimed then
		WardrobeService.addCoins(player, listing.price, nil, { type = "Shop", sku = "AuctionRefund" }) -- refund
		browseCache.at = -math.huge
		return false, "Someone beat you to it"
	end
	WardrobeService.giveItem(player, claimed.kind, claimed.item)
	Events.fire("AuctionBought", player, claimed.price)
	task.spawn(DataService.save, player)
	-- pay the seller: the house keeps its cut
	local proceeds = claimed.price - math.floor(claimed.price * E.AuctionFee)
	local seller = playerById(claimed.seller)
	-- (negative seller ids are the dev panel's Test Merchant: nobody to pay)
	local paid = claimed.seller < 0 or (seller ~= nil and creditSale(seller, id, proceeds, claimed.item.name))
	for _ = 1, 3 do
		if paid then
			break
		end
		paid = mailbox.send(claimed.seller, id, proceeds)
	end
	if paid then
		store.remove(id)
	end
	-- (if the payment couldn't be posted, the sold listing stays put and the seller's own server
	-- pays them from it later; see reconcile)
	browseCache.at = -math.huge
	return true, "Bought " .. claimed.item.name .. " for " .. claimed.price .. " coins"
end

function AuctionService.cancel(player: Player, id: any): (boolean, string)
	local profile = DataService.profile(player)
	if type(id) ~= "string" or not profile then
		return false, "Bad request"
	end
	local record = profile.wardrobe.listings[id]
	if not record then
		return false, "That isn't your listing"
	end
	local claimed = store.claim(id, function(current)
		if current and current.sold == nil and current.seller == player.UserId then
			current.sold = "cancelled"
			return current
		end
		return nil
	end, ttl())
	if not claimed then
		return false, "Too late, it's being sold"
	end
	profile.wardrobe.listings[id] = nil
	WardrobeService.giveItem(player, record.kind, record.item)
	task.spawn(DataService.save, player)
	store.remove(id)
	browseCache.at = -math.huge
	return true, "Took " .. record.item.name .. " off the market"
end

-- Collects sale proceeds from the mailbox and takes back expired listings. Safe to run often.
local GRACE = 600 -- seconds a vanished listing waits for a late sale notice before coming back

function AuctionService.reconcile(player: Player)
	local profile = DataService.profile(player)
	if not profile then
		return
	end
	local listings = profile.wardrobe.listings
	local t = now()
	local changed = false
	-- 1. expired listings we can still claim come straight back
	for id, record in listings do
		if record.expires <= t then
			local claimed = store.claim(id, function(current)
				if current and current.sold == nil then
					current.sold = "expired"
					return current
				end
				return nil
			end, ttl())
			if claimed then
				listings[id] = nil
				WardrobeService.giveItem(player, record.kind, record.item)
				store.remove(id)
				changed = true
			end
		end
	end
	-- 2. sales that happened in other servers
	for id, coins in mailbox.take(player.UserId) do
		local record = listings[id]
		listings[id] = nil
		WardrobeService.addCoins(
			player,
			coins,
			"sold " .. (if record and record.item then record.item.name else "an item"),
			SALE
		)
		Events.fire("AuctionSold", player, coins)
		changed = true
	end
	-- 3. loose ends: sold listings whose payment never arrived, and listings that vanished
	--    without a sale notice (e.g. the store expired them)
	for id, record in listings do
		local current = store.get(id)
		if current and type(current.sold) == "number" and t - (current.soldAt or t) > GRACE then
			listings[id] = nil
			WardrobeService.addCoins(
				player,
				current.price - math.floor(current.price * E.AuctionFee),
				"sold " .. record.item.name,
				SALE
			)
			Events.fire("AuctionSold", player, current.price)
			store.remove(id)
			changed = true
		elseif current == nil and record.expires <= t then
			record.missingSince = record.missingSince or t
			if t - record.missingSince > GRACE then
				listings[id] = nil
				WardrobeService.giveItem(player, record.kind, record.item)
			end
			changed = true
		end
	end
	if changed then
		DataService.markDirty(player)
		WardrobeService.sync(player)
	end
end

-- Dev tool: puts an item up for sale from the "Test Merchant", so buying can be tested alone.
function AuctionService.devAddListing(kind: string, item: any, price: number): boolean
	local t = now()
	local listing: Listing = {
		id = string.format("%013d_0_%04d", math.floor(t * 1000), rng:NextInteger(0, 9999)),
		seller = -1,
		sellerName = "Test Merchant",
		kind = kind,
		item = item,
		price = math.max(1, math.floor(price)),
		created = t,
		expires = t + math.floor(E.AuctionHours * 3600),
		sold = nil,
	}
	local ok = store.set(listing.id, listing, ttl())
	browseCache.at = -math.huge
	return ok
end

function AuctionService.isGlobal(): boolean
	return store.global
end

function AuctionService.init()
	local ms = memoryStore()
	if ms then
		store = ms
	end
	local mb = dataStoreMailbox()
	if mb then
		mailbox = mb
	end
	if not store.global then
		print("[Auction] MemoryStore unavailable: running an in-server auction house")
	end
	ReplicatedStorage:SetAttribute("AuctionGlobal", store.global)

	Remotes.func("AuctionAction").OnServerInvoke = function(player: Player, action: any, args: any)
		args = if type(args) == "table" then args else {}
		if player:GetAttribute("InMatch") == true and action ~= "Browse" then
			return false, "Finish your match first"
		end
		if action == "Browse" then
			return true, nil, AuctionService.browse(player)
		elseif action == "List" then
			return AuctionService.list(player, args.kind, args.uid, args.price)
		elseif action == "Buy" then
			return AuctionService.buy(player, args.id)
		elseif action == "Cancel" then
			return AuctionService.cancel(player, args.id)
		end
		return false, "Unknown action"
	end

	DataService.onLoaded(function(player)
		AuctionService.reconcile(player)
	end)
	task.spawn(function()
		while true do
			task.wait(60)
			for _, player in Players:GetPlayers() do
				local profile = DataService.profile(player)
				if profile and next(profile.wardrobe.listings) ~= nil then
					task.spawn(AuctionService.reconcile, player)
				end
			end
		end
	end)
end

return AuctionService
