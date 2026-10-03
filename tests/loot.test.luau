-- Wand, loot and class tests. Run with: python3 tools/run_tests.py
local WandGenerator = __require(Shared.WandGenerator)
local LootTables = __require(Shared.LootTables)
local Classes = __require(Shared.Classes)
local Items = __require(Shared.Items)
local Rarity = __require(Shared.Rarity)
local Consumables = __require(Shared.Consumables)
local SpellBuilder = __require(Shared.Spells.SpellBuilder)
local PremadeSpells = __require(Shared.Spells.PremadeSpells)
local SpellParts = __require(Shared.Spells.SpellParts)

local function checkWand(wand, label)
	local s = wand.stats
	expect(type(wand.uid) == "string", label .. " uid")
	expect(type(wand.name) == "string" and #wand.name > 0, label .. " name")
	expect(Rarity.Info[wand.rarity] ~= nil, label .. " rarity")
	expect(s.capacity >= 1 and s.capacity <= 10, label .. " capacity " .. s.capacity)
	expect(s.spellsPerCast >= 1 and s.spellsPerCast <= s.capacity, label .. " spellsPerCast")
	expect(s.castDelay > 0 and s.castDelay < 1, label .. " castDelay " .. s.castDelay)
	expect(s.rechargeTime > 0 and s.rechargeTime < 2, label .. " recharge " .. s.rechargeTime)
	expect(s.manaMax >= 50, label .. " manaMax")
	expect(s.manaRegen > 0, label .. " regen")
	expect(s.spread >= 0, label .. " spread")
	expect(#wand.slots == s.capacity, label .. " slots length")
	for i = 1, s.capacity do
		local slot = wand.slots[i]
		expect(slot == false or type(slot) == "table", label .. " slot " .. i)
		if slot then
			expect(SpellBuilder.validate(slot.recipe), label .. " slot spell invalid")
		end
	end
	local seen = {}
	for _, perk in wand.perks do
		expect(not seen[perk.kind], label .. " duplicate perk " .. perk.kind)
		seen[perk.kind] = true
		expect(#WandGenerator.describePerk(perk) > 0, "perk description")
	end
	-- the wand's bonuses must produce a usable compile context
	local ctx = Items.wandContext(wand)
	local spec = SpellBuilder.compile({ form = "Bolt", element = "Fire" }, ctx)
	expect(spec ~= nil and isFinite(spec.damage), label .. " context")
end

test("generated wands are sane across every rarity", function()
	local rng = Random.new(42)
	for _, rarity in Rarity.Order do
		for i = 1, 300 do
			checkWand(WandGenerator.generate(rng, rarity), rarity .. " #" .. i)
		end
	end
end)

test("higher rarity wands are better on average", function()
	local rng = Random.new(7)
	local function avg(rarity, field)
		local total = 0
		for _ = 1, 400 do
			total += WandGenerator.generate(rng, rarity).stats[field]
		end
		return total / 400
	end
	expect(avg("Legendary", "manaMax") > avg("Common", "manaMax"), "mana")
	expect(avg("Legendary", "capacity") > avg("Common", "capacity"), "capacity")
	expect(avg("Legendary", "castDelay") < avg("Common", "castDelay"), "cast delay")
end)

test("chests roll valid loot", function()
	local rng = Random.new(99)
	for tierName, tier in LootTables.Tiers do
		for i = 1, 200 do
			local entries = LootTables.rollChest(rng, tierName)
			expect(#entries >= 1, tierName .. " empty chest")
			for _, entry in entries do
				if entry.kind == "Part" then
					expect(SpellParts.ById[entry.id] ~= nil, "bad part " .. tostring(entry.id))
					expect(entry.count >= 1, "part count")
				elseif entry.kind == "Spell" then
					expect(SpellBuilder.validate(entry.spell.recipe), "bad spell in chest")
					expect(Rarity.Info[entry.spell.rarity] ~= nil, "spell rarity")
				elseif entry.kind == "Wand" then
					checkWand(entry.wand, tierName .. " chest wand")
					expect(Rarity.rank(entry.wand.rarity) <= tier.maxWandRank, "wand above tier cap")
				elseif entry.kind == "Consumable" then
					expect(Consumables.ById[entry.id] ~= nil, "bad consumable")
				else
					error("unknown loot kind " .. tostring(entry.kind))
				end
			end
		end
	end
end)

test("cornucopia chests are luckier than outer chests", function()
	local rng = Random.new(5)
	local function score(tierName)
		local total = 0
		for _ = 1, 400 do
			for _, entry in LootTables.rollChest(rng, tierName) do
				if entry.kind == "Wand" then
					total += Rarity.rank(entry.wand.rarity)
				elseif entry.kind == "Spell" then
					total += Rarity.rank(entry.spell.rarity)
				elseif entry.kind == "Part" then
					total += Rarity.rank(SpellParts.ById[entry.id].rarity)
				end
			end
		end
		return total
	end
	expect(score("Cornucopia") > score("Outer"), "cornucopia should be better")
end)

test("random chest recipes are valid", function()
	local rng = Random.new(2024)
	for i = 1, 3000 do
		local recipe = LootTables.rollRandomRecipe(rng, (i % 4) * 0.7)
		local ok, err = SpellBuilder.validate(recipe)
		expect(ok, "random recipe invalid: " .. tostring(err))
	end
end)

test("class kits reference real content", function()
	expect(Classes.ById[Classes.Default] ~= nil and not Classes.ById[Classes.Default].premium, "free default class")
	for _, class in Classes.List do
		expect(#class.kit.wands >= 1, class.id .. " has no wand")
		for _, w in class.kit.wands do
			local wand = WandGenerator.fromTemplate(w.template)
			checkWand(wand, class.id)
			expect(#w.spells <= wand.stats.capacity, class.id .. " has more spells than slots")
			for _, id in w.spells do
				expect(PremadeSpells.ById[id] ~= nil, class.id .. " unknown spell " .. id)
			end
		end
		for id, n in class.kit.parts or {} do
			expect(SpellParts.ById[id] ~= nil and n > 0, class.id .. " unknown part " .. id)
		end
		for id in class.kit.consumables or {} do
			expect(Consumables.ById[id] ~= nil, class.id .. " unknown consumable " .. id)
		end
	end
end)

test("crafted spell rarity follows its rarest part", function()
	local common = Items.rarityOfRecipe({ form = "Bolt", element = "Fire" }, LootTables.partRarity)
	expect(common == "Common", common)
	local epic = Items.rarityOfRecipe({ form = "Meteor", element = "Fire" }, LootTables.partRarity)
	expect(epic == "Epic", epic)
end)

test("uids are unique", function()
	local seen = {}
	for _ = 1, 5000 do
		local uid = Items.newUid()
		expect(not seen[uid], "duplicate uid")
		seen[uid] = true
	end
end)
