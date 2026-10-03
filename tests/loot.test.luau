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
local Config = __require(Shared.Config)

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
	expect(Classes.ById[Classes.Default] ~= nil and Classes.ById[Classes.Default].tier == 0, "free default class")
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

test("kit tiers run from 99 cents to 25 dollars and every paid kit can be sold", function()
	local lastRobux = -1
	for i, tier in Classes.Tiers do
		expect(tier.id == i - 1, "tiers are numbered 0..n in order")
		expect(tier.robux > lastRobux, tier.name .. " should cost more than the tier below")
		lastRobux = tier.robux
		local total = 0
		for rarity, pct in tier.bonusOdds do
			expect(Rarity.Info[rarity] ~= nil, tier.name .. " odds use an unknown rarity " .. rarity)
			total += pct
		end
		expect(total == 100, tier.name .. " bonus odds should add up to 100%, got " .. total)
	end
	expect(Classes.Tiers[2].usd == "$0.99" and Classes.Tiers[#Classes.Tiers].usd == "$24.99", "price range")
	local perTier = {}
	for _, class in Classes.List do
		perTier[class.tier] = (perTier[class.tier] or 0) + 1
		expect(Classes.tierInfo(class.tier).id == class.tier, class.id .. " has an unknown tier")
		if class.tier > 0 then
			expect(Config.Kits.GamePassIds[class.id] ~= nil, class.id .. " needs a game pass entry in Config.Kits")
		end
	end
	for _, tier in Classes.Tiers do
		expect((perTier[tier.id] or 0) >= 1, tier.name .. " has no kits")
	end
	for id in Config.Kits.GamePassIds do
		expect(Classes.ById[id] ~= nil and Classes.ById[id].tier > 0, "game pass for unknown or free kit " .. id)
	end
end)

test("higher tiers give better kits and rarer bonus parts", function()
	-- best wand rarity never goes down as the price goes up
	local bestByTier = {}
	for _, class in Classes.List do
		for _, w in class.kit.wands do
			local r = Rarity.rank(w.template.rarity)
			bestByTier[class.tier] = math.max(bestByTier[class.tier] or 0, r)
		end
	end
	for t = 1, #Classes.Tiers - 1 do
		expect(bestByTier[t] >= bestByTier[t - 1], "tier " .. t .. " kits should not be worse than tier " .. t - 1)
	end
	-- the bonus part follows the advertised odds
	local rng = Random.new(99)
	local lastAverage = 0
	for _, tier in Classes.Tiers do
		local class = nil
		for _, c in Classes.List do
			if c.tier == tier.id then
				class = c
			end
		end
		local sum, n = 0, 2000
		for _ = 1, n do
			local id = Classes.rollBonusPart(class, rng)
			local part = SpellParts.ById[id]
			expect(part ~= nil, "bonus part must exist: " .. tostring(id))
			expect(tier.bonusOdds[part.rarity] ~= nil, tier.name .. " rolled a " .. part.rarity .. " part")
			sum += Rarity.rank(part.rarity)
		end
		local average = sum / n
		expect(average >= lastAverage, tier.name .. " bonus parts should be at least as rare as the tier below")
		lastAverage = average
	end
	local copper = Classes.oddsText(1)
	expect(copper == "75% Common · 25% Uncommon", "odds text: " .. copper)
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
