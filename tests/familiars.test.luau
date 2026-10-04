-- Familiar tests. Run with: python3 tools/run_tests.py
local Familiars = __require(Shared.Familiars)
local Cosmetics = __require(Shared.Cosmetics)
local Rarity = __require(Shared.Rarity)

test("every species is well formed", function()
	local ids = {}
	for _, s in Familiars.Species do
		expect(not ids[s.id], "duplicate species " .. s.id)
		ids[s.id] = true
		expect(Rarity.Info[s.minRarity] ~= nil, s.id .. " rarity")
		expect(Familiars.PowerById[s.power] ~= nil, s.id .. " power " .. s.power)
		expect(#s.variants >= 2, s.id .. " needs colour variants")
		expect(type(s.blurb) == "string" and #s.blurb > 10, s.id .. " blurb")
		if s.power == "attuned" then
			expect(s.element ~= nil, s.id .. " attuned familiars need an element")
		end
	end
	expect(#Familiars.Species >= 20, "a good bunch of species")
	-- every rarity has species that start there
	for _, rarity in Rarity.Order do
		local n = 0
		for _, s in Familiars.Species do
			if s.minRarity == rarity then
				n += 1
			end
		end
		expect(n >= 2, "species starting at " .. rarity .. ": " .. n)
	end
	expect(Familiars.varietyCount() > 300, "variety " .. Familiars.varietyCount())
end)

test("familiars come out of every coffer at the disclosed rate, from the right pools", function()
	local rng = Random.new(7)
	for boxId, box in Cosmetics.Boxes do
		local n, hits = 20000, 0
		for _ = 1, n do
			if Familiars.rollIsFamiliar(rng, boxId) then
				hits += 1
			end
		end
		local expected = Familiars.ChancePerItem[boxId]
		expect(math.abs(hits / n * 100 - expected) < 1, box.name .. " familiar rate " .. hits / n * 100)
		local shiny = 0
		for _ = 1, 2000 do
			local f = Familiars.roll(rng, boxId, Cosmetics.rollRarity(rng, box), nil)
			local s = Familiars.SpeciesById[f.species]
			expect(s ~= nil, "species")
			expect(Familiars.allowed(s, f.rarity, boxId), s.name .. " can't come from the " .. box.name)
			expect(box.odds[f.rarity] ~= nil, "rarity outside the coffer's odds")
			local okVariant = false
			for _, v in s.variants do
				okVariant = okVariant or v.id == f.variant
			end
			expect(okVariant, "variant " .. f.variant)
			expect(f.name == Familiars.familiarName(f) and #f.name > 3, "name")
			if f.shiny then
				shiny += 1
			end
		end
		expect(shiny > 10 and shiny < 110, "shiny count " .. shiny)
	end
	-- the Mythic-only species never leave the Celestial Reliquary
	for boxId = 1, 4 do
		for _ = 1, 300 do
			local f = Familiars.roll(rng, boxId, "Mythic", nil)
			expect(f.species ~= "StarWhale" and f.species ~= "EclipseCat", "reliquary exclusive in box " .. boxId)
		end
	end
end)

test("powers start at Rare, grow with rarity and stay small", function()
	for _, s in Familiars.Species do
		for r, rarity in Rarity.Order do
			if r >= Rarity.rank(s.minRarity) then
				local f = { species = s.id, rarity = rarity }
				local power, value = Familiars.powerOf(f)
				if r < 3 then
					expect(
						power == nil and Familiars.powerText(f) == nil,
						s.name .. " should be just for show at " .. rarity
					)
					expect(Familiars.statOf(f) == nil, "no stats below Rare")
				else
					expect(power ~= nil and power.id == s.power, s.name .. " power at " .. rarity)
					expect(value == power.values[r - 2], "value by rarity")
					expect(Familiars.powerText(f) ~= nil, "power text")
				end
			end
		end
	end
	for _, p in Familiars.Powers do
		expect(#p.values == 4, p.id .. " needs Rare..Mythic values")
		for i = 2, 4 do
			expect(p.values[i] > p.values[i - 1], p.id .. " grows with rarity")
		end
		if p.percent then
			expect(p.values[4] <= 0.1, p.id .. " stays minor: " .. p.values[4])
		end
	end
	expect(Familiars.PowerById.nip.values[4] <= 5, "nips are small")
	local stat, amount = Familiars.statOf({ species = "PaperCrane", rarity = "Epic" })
	expect(stat == "elem:Wind" and amount == 0.04, "attuned familiars add element damage")
	expect(Cosmetics.EnchantById["elem:Wind"] ~= nil, "Wind attunement is a real gear stat")
	for _, s in Familiars.Species do
		local st = Familiars.statOf({ species = s.id, rarity = "Mythic" })
		if st then
			expect(Cosmetics.EnchantById[st] ~= nil, s.id .. " stat " .. st .. " must be a gear stat")
		end
	end
end)

test("familiar looks survive the trip to clients", function()
	local rng = Random.new(3)
	for _ = 1, 200 do
		local f = Familiars.roll(rng, 5, Rarity.Order[rng:NextInteger(1, 6)], nil)
		local look = Familiars.decode(Familiars.encode(f))
		expect(look ~= nil, "decodes")
		if look then
			expect(look.species == f.species and look.rarity == f.rarity, "species and rarity")
			expect(look.variant == f.variant and look.shiny == f.shiny, "variant and shiny")
		end
	end
	expect(Familiars.decode("Nope|Rare|x|0") == nil, "unknown species")
	expect(Familiars.decode("Wisp|Godly|Azure|0") == nil, "unknown rarity")
	expect(Familiars.decode(42) == nil, "not a string")
end)
