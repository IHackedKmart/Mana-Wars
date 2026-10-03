-- Robe / hat cosmetics tests. Run with: python3 tools/run_tests.py
local Cosmetics = __require(Shared.Cosmetics)
local Rarity = __require(Shared.Rarity)

test("coffers cost 50 to 1000 coins and their odds add up", function()
	local prices = {}
	for i, box in Cosmetics.Boxes do
		expect(box.id == i, "boxes are numbered in order")
		table.insert(prices, box.price)
		local total = 0
		for rarity, pct in box.odds do
			expect(Rarity.Info[rarity] ~= nil, box.name .. " unknown rarity " .. rarity)
			total += pct
		end
		expect(math.abs(total - 100) < 1e-6, box.name .. " odds add up to " .. total)
	end
	expect(table.concat(prices, ",") == "50,100,300,500,1000", "prices " .. table.concat(prices, ","))
	-- the 50-coin satchel almost never beats Common
	expect(Cosmetics.Boxes[1].odds.Common >= 95, "satchel should be nearly all Common")
end)

test("rolled parts are well formed and respect rarity and coffer pools", function()
	local rng = Random.new(42)
	local seen = {}
	for boxId = 1, #Cosmetics.Boxes do
		for _ = 1, 1500 do
			local part = Cosmetics.rollPart(rng, boxId)
			local r = Rarity.rank(part.rarity)
			expect(Cosmetics.Slots[part.slot] ~= nil, "slot " .. tostring(part.slot))
			expect(Cosmetics.Boxes[boxId].odds[part.rarity] ~= nil, "rarity not in the coffer's odds")
			local design = Cosmetics.DesignById[part.slot][part.design]
			expect(design ~= nil, "design " .. part.slot .. "/" .. part.design)
			expect(Rarity.rank(design.minRarity) <= r, "design above its rarity")
			if design.boxes then
				expect(table.find(design.boxes, boxId) ~= nil, design.name .. " is exclusive to other coffers")
			else
				expect(boxId >= (design.minBox or 1), design.name .. " from too cheap a coffer")
			end
			local color = Cosmetics.ColorById[part.color]
			expect(color ~= nil and Rarity.rank(color.minRarity) <= r, "colour")
			local material = Cosmetics.MaterialById[part.material]
			expect(material ~= nil and table.find(material.slots, part.slot) ~= nil, "material for slot")
			if part.slot == "Sigil" or part.slot == "Gem" then
				local aura = part.aura and Cosmetics.AuraById[part.aura]
				expect(aura ~= nil and Rarity.rank(aura.minRarity) <= r, "aura")
			else
				expect(part.aura == nil, "only sigils and gems carry auras")
			end
			expect(#part.enchants == Cosmetics.EnchantCount[r], "enchant count by rarity")
			local stats = {}
			for _, e in part.enchants do
				local def = Cosmetics.EnchantById[e.stat]
				expect(def ~= nil and e.amount == def.values[r], "enchant value")
				expect(not stats[e.stat], "duplicate enchant")
				stats[e.stat] = true
			end
			expect(type(part.name) == "string" and #part.name > 3, "name")
			seen[part.slot .. ":" .. part.design .. ":" .. part.color .. ":" .. part.material .. ":" .. tostring(
				part.aura
			)] =
				true
		end
	end
	local distinct = 0
	for _ in seen do
		distinct += 1
	end
	print(
		string.format("      distinct parts in 7500 rolls: %d, possible looks: %d", distinct, Cosmetics.varietyCount())
	)
	expect(distinct > 1000, "there should be hundreds and hundreds of different parts")
	expect(Cosmetics.varietyCount() > 10000, "thousands of possible looks")
end)

test("pricier coffers roll rarer parts", function()
	local rng = Random.new(7)
	local last = 0
	for boxId = 1, #Cosmetics.Boxes do
		local sum = 0
		for _ = 1, 3000 do
			sum += Rarity.rank(Cosmetics.rollRarity(rng, Cosmetics.Boxes[boxId]))
		end
		local avg = sum / 3000
		expect(avg > last, Cosmetics.Boxes[boxId].name .. " should beat the cheaper coffer")
		last = avg
	end
end)

local function part(slot, rarity, aura)
	local rng = Random.new(#slot + #rarity)
	local p = Cosmetics.rollPart(rng, 5, slot, rarity)
	if aura then
		p.aura = aura
	end
	return p
end

test("auras only shine one tier above the garment they're sewn into", function()
	local legendaryOnRags = Cosmetics.craft("Robe", {
		Cloth = part("Cloth", "Common"),
		Trim = part("Trim", "Common"),
		Sigil = part("Sigil", "Legendary", "Inferno"),
	})
	expect(Cosmetics.resonance(legendaryOnRags.parts) == 2, "(1+1+5)/3 rounds down to 2")
	expect(Cosmetics.auraLevel(legendaryOnRags) == 3, "a legendary sigil on rags only glimmers")
	expect(legendaryOnRags.rarity == "Uncommon", "garment rarity is its resonance")

	local fullLegendary = Cosmetics.craft("Robe", {
		Cloth = part("Cloth", "Legendary"),
		Trim = part("Trim", "Legendary"),
		Sigil = part("Sigil", "Legendary", "Inferno"),
	})
	expect(Cosmetics.auraLevel(fullLegendary) == 5, "a full legendary robe billows")

	local commonSigil = Cosmetics.craft("Robe", {
		Cloth = part("Cloth", "Mythic"),
		Trim = part("Trim", "Mythic"),
		Sigil = part("Sigil", "Common", "Embers"),
	})
	expect(Cosmetics.auraLevel(commonSigil) == 1, "a common sigil never shows particles, even on mythic cloth")

	-- matched aura on robe + hat adds a trail
	local hat = Cosmetics.craft("Hat", {
		Shape = part("Shape", "Legendary"),
		Band = part("Band", "Legendary"),
		Gem = part("Gem", "Legendary", "Inferno"),
	})
	expect(Cosmetics.matchedTrail(fullLegendary, hat) == "Inferno", "matching auras trail")
	expect(Cosmetics.matchedTrail(legendaryOnRags, hat) == nil, "a faint aura doesn't trail")
end)

test("crafting needs one part per slot", function()
	expect(not Cosmetics.validate("Robe", { Cloth = part("Cloth", "Common") }), "incomplete robe")
	expect(not Cosmetics.validate("Hat", {
		Shape = part("Shape", "Common"),
		Band = part("Band", "Common"),
		Gem = part("Sigil", "Common"),
	}), "wrong part in a slot")
	expect(
		Cosmetics.validate("Hat", {
			Shape = part("Shape", "Common"),
			Band = part("Band", "Common"),
			Gem = part("Gem", "Common"),
		}),
		"complete hat"
	)
end)

test("outfit stats add up and are capped", function()
	local function withEnchant(slot, stat, amount)
		local p = part(slot, "Mythic")
		p.enchants = { { stat = stat, amount = amount } }
		return p
	end
	local robe = Cosmetics.craft("Robe", {
		Cloth = withEnchant("Cloth", "speed", 0.08),
		Trim = withEnchant("Trim", "speed", 0.08),
		Sigil = withEnchant("Sigil", "health", 10),
	})
	local hat = Cosmetics.craft("Hat", {
		Shape = withEnchant("Shape", "elem:Fire", 0.12),
		Band = withEnchant("Band", "elem:Fire", 0.12),
		Gem = withEnchant("Gem", "fortune", 0.1),
	})
	local gear = Cosmetics.gear({ robe, hat })
	expect(gear.speed == Cosmetics.EnchantById.speed.cap, "speed capped at " .. gear.speed)
	expect(gear["elem:Fire"] == 0.2, "fire attunement capped")
	expect(gear.health == 10 and gear.fortune == 0.1, "other stats add up")
	expect(Cosmetics.enchantText({ stat = "speed", amount = 0.05 }) == "+5% movement speed", "enchant text")
end)

test("the starter outfit is complete", function()
	local parts = Cosmetics.starterParts()
	local bySlot = {}
	for _, p in parts do
		bySlot[p.slot] = p
	end
	local robe = { Cloth = bySlot.Cloth, Trim = bySlot.Trim, Sigil = bySlot.Sigil }
	local hat = { Shape = bySlot.Shape, Band = bySlot.Band, Gem = bySlot.Gem }
	expect(Cosmetics.validate("Robe", robe) and Cosmetics.validate("Hat", hat), "starter robe + hat")
end)
