--[[
	Headless combat simulation (run from the repo root with Lune):

		lune run tools/sim/combat

	Loads the REAL server combat modules with a fake engine (tools/sim/mock.luau): a flat floor
	plus one wall instead of terrain, fake remotes, and a simulated clock. Then it casts every
	premade spell and thousands of random crafted spells at target dummies, stepping the server
	frame by frame. Any runtime error or warning fails the run.

	MANA_FUZZ=5000 lune run tools/sim/combat   -- more random spells
]]

local process = require("@lune/process")
local roblox = require("@lune/roblox")
local Mock = require("./mock")

local Vector3 = roblox.Vector3
local CFrame = Mock.CFrame
local Instance = Mock.Instance

local server = Mock.realm({
	RunService = Mock.runService(true),
	Players = {
		PlayerRemoving = Mock.signal(),
		PlayerAdded = Mock.signal(),
		GetPlayers = function()
			return {}
		end,
	},
	TweenService = Mock.TweenService,
}, true)

local Combatants = server.load("Server/Services/Combatants")
local GameState = server.load("Server/Services/GameState")
local StatusService = server.load("Server/Services/StatusService")
local DamageService = server.load("Server/Services/DamageService")
local ProjectileService = server.load("Server/Services/ProjectileService")
local ZoneService = server.load("Server/Services/ZoneService")
local SpellExecutor = server.load("Server/Services/SpellExecutor")
local CastingService = server.load("Server/Services/CastingService")
local InventoryService = server.load("Server/Services/InventoryService")
local Items = server.load("Shared/Items")
local WandGenerator = server.load("Shared/WandGenerator")
local LootTables = server.load("Shared/LootTables")
local PremadeSpells = server.load("Shared/Spells/PremadeSpells")
local SpellParts = server.load("Shared/Spells/SpellParts")
local SpellBuilder = server.load("Shared/Spells/SpellBuilder")
local SpellNames = server.load("Shared/Spells/SpellNames")
local Config = server.load("Shared/Config")

StatusService.init()
DamageService.init()
ProjectileService.init()
ZoneService.init()
SpellExecutor.init()
CastingService.init()
GameState.setPhase("Battle", 0)

local function body(name: string, position, player: any?)
	local model = Instance.new("Model", Mock.workspace)
	model.Name = name
	local root = Instance.new("Part", model)
	root.Name = "HumanoidRootPart"
	root.CFrame = CFrame.new(position)
	local head = Instance.new("Part", model)
	head.Name = "Head"
	head.CFrame = CFrame.new(position + Vector3.new(0, 1.5, 0))
	Instance.new("Humanoid", model)
	local c = Combatants.create(name, player)
	Combatants.setModel(c, model)
	c.inMatch = true
	c.alive = true
	return c
end

local CASTER_POS = Vector3.new(0, 3, 0)
local TARGET_POS = {
	Vector3.new(0, 3, -30),
	Vector3.new(5, 3, -34),
	Vector3.new(-5, 3, -34),
	Vector3.new(0, 3, -10),
	Vector3.new(8, 3, -6),
}
local caster = body("Caster", CASTER_POS)
local targets = {}
for i, pos in TARGET_POS do
	targets[i] = body("Target" .. i, pos)
end

local function resetWorld()
	ProjectileService.clear()
	ZoneService.clear()
	Mock.clearDelayed()
	for _, c in { caster, table.unpack(targets) } do
		c.humanoid.Health = 100
		c.status = {}
		c.alive = true
		c.inMatch = true
		c.locked = false
		c.wandStates = {}
		c.lastAttacker = nil
	end
	caster.root.CFrame = CFrame.new(CASTER_POS)
	for i, pos in TARGET_POS do
		targets[i].root.CFrame = CFrame.new(pos)
	end
end

local function giveWand(spell)
	local wand = WandGenerator.fromTemplate({
		name = "Test Wand",
		rarity = "Legendary",
		wandType = "Staff",
		stats = { capacity = 1, castDelay = 0.1, rechargeTime = 0.1, manaMax = 100000, manaRegen = 100000, spread = 0 },
	})
	wand.slots[1] = spell
	caster.inventory = Items.newInventory()
	caster.inventory.wands[1] = wand
	caster.inventory.equipped = 1
end

local function damageDealt(): number
	local total = 0
	for _, t in targets do
		total += 100 - t.humanoid.Health
	end
	return total
end

local failures = 0
local reported = 0
local function fail(msg: string)
	failures += 1
	print("FAIL  " .. msg)
end

local function castAndRun(spellItem, label: string, seconds: number?): number
	resetWorld()
	giveWand(spellItem)
	local before = #Mock.warnings
	local ok, reason = CastingService.tryCast(caster, TARGET_POS[1])
	if not ok then
		fail(label .. ": cast refused (" .. tostring(reason) .. ")")
		return 0
	end
	Mock.step(seconds or 3)
	for i = before + 1, #Mock.warnings do
		fail(label .. ": " .. Mock.warnings[i])
	end
	reported = #Mock.warnings
	return damageDealt()
end

-- 1. Every premade spell runs cleanly; every damaging one should hurt somebody.
-- shields and blinks don't hurt on their own; Orbiting Blades only hits things that come close
local utility = { Bulwark = true, EscapeStep = true, BlinkStrike = true, StormShield = true, OrbitingBlades = true }
local hurting = 0
for _, premade in PremadeSpells.List do
	local dealt = castAndRun(Items.newSpell(premade.recipe, premade.name, premade.rarity, premade.id), premade.id, 4)
	if dealt > 0 then
		hurting += 1
	elseif not utility[premade.id] then
		fail(premade.id .. " dealt no damage to the target dummies")
	end
end
print(string.format("premade spells: %d/%d dealt damage", hurting, #PremadeSpells.List))

-- Orbiting projectiles should shred anyone who walks up to the caster.
do
	resetWorld()
	giveWand(LootTables.premadeSpell("OrbitingBlades"))
	CastingService.tryCast(caster, TARGET_POS[1])
	targets[4].root.CFrame = CFrame.new(0, 3, -7)
	Mock.step(2)
	if 100 - targets[4].humanoid.Health <= 0 then
		fail("orbiting blades should hit an adjacent enemy")
	end
end

-- 2. Fuzz: lots of random spells, including deep trigger chains.
local rng = Mock.Random.new(777)
local cats = SpellParts.ByCategory
local function pick(list)
	return list[rng:NextInteger(1, #list)].id
end
local function randomRecipe(depth: number)
	local r = { form = pick(cats.Form), mods = {} }
	if rng:NextNumber() < 0.85 then
		r.element = pick(cats.Element)
	end
	for _ = 1, rng:NextInteger(0, Config.Spell.MaxModifiers) do
		table.insert(r.mods, pick(cats.Modifier))
	end
	if depth < Config.Spell.MaxDepth and rng:NextNumber() < 0.45 then
		r.trigger = pick(cats.Trigger)
		r.payload = randomRecipe(depth + 1)
	end
	return r
end
local FUZZ = tonumber(process.env.MANA_FUZZ) or 1500
local fuzzHurt = 0
for i = 1, FUZZ do
	local recipe = randomRecipe(1)
	local dealt = castAndRun(Items.newSpell(recipe), "fuzz #" .. i .. " " .. SpellNames.generate(recipe), 3)
	if dealt > 0 then
		fuzzHurt += 1
	end
end
print(string.format("fuzz: %d random spells cast, %d dealt damage", FUZZ, fuzzHurt))

-- 3. Wand mechanics: a multicast wand fires two at a time, respects cast delay, then recharges.
resetWorld()
do
	local wand = WandGenerator.fromTemplate({
		name = "Twin",
		rarity = "Rare",
		wandType = "Scepter",
		stats = {
			capacity = 4,
			spellsPerCast = 2,
			castDelay = 0.2,
			rechargeTime = 0.6,
			manaMax = 1000,
			manaRegen = 0,
			spread = 0,
		},
	})
	for s = 1, 4 do
		wand.slots[s] = LootTables.premadeSpell("SparkBolt")
	end
	caster.inventory = Items.newInventory()
	caster.inventory.wands[1] = wand
	local ok1 = CastingService.tryCast(caster, TARGET_POS[1])
	local ok2 = CastingService.tryCast(caster, TARGET_POS[1])
	if not ok1 or ok2 then
		fail("cast delay should block an immediate second cast")
	end
	Mock.step(0.25)
	local ok3 = CastingService.tryCast(caster, TARGET_POS[1])
	local st = CastingService.state(caster, wand)
	if not ok3 or st.deckPos ~= 1 or st.rechargeUntil <= Mock.clock.t then
		fail("after 4 spells in 2 casts the wand should be recharging")
	end
	local spent = 1000 - st.mana
	local sparkMana = SpellBuilder.compile({ form = "Spark", element = "Arcane" }).mana
	if math.abs(spent - sparkMana * 4) > 0.01 then
		fail("mana spent " .. spent .. " expected " .. sparkMana * 4)
	end
	-- out of mana
	st.mana = 0
	Mock.step(1)
	local ok4, reason = CastingService.tryCast(caster, TARGET_POS[1])
	if ok4 or reason ~= "no mana" then
		fail("a wand with no mana should fizzle, got " .. tostring(reason))
	end
end

-- 4. Grace period blocks damage between mages.
resetWorld()
GameState.setPhase("Grace", 0)
castAndRun(LootTables.premadeSpell("Fireball"), "grace fireball", 2)
if damageDealt() > 0 then
	fail("grace period should block damage")
end
GameState.setPhase("Battle", 0)

-- 5. Lobby practice: Spell Lab casters hurt training dummies (in any phase) but never real mages,
--    and dummies never die.
do
	resetWorld()
	GameState.setPhase("Voting", 0)
	local dummy = body("Dummy", Vector3.new(0, 3, -20))
	dummy.isDummy = true
	dummy.humanoid.MaxHealth = 500
	dummy.humanoid.Health = 500
	local trainee = body("Trainee", Vector3.new(0, 3, 0))
	trainee.inMatch = false
	trainee.alive = false
	trainee.practice = true
	trainee.root.CFrame = CFrame.new(0, 3, 0)
	caster.root.CFrame = CFrame.new(300, 3, 300) -- out of the way
	local wand = WandGenerator.fromTemplate({
		name = "Lab",
		rarity = "Rare",
		wandType = "Staff",
		stats = { capacity = 1, castDelay = 0.1, rechargeTime = 0.1, manaMax = 100000, manaRegen = 100000, spread = 0 },
	})
	wand.slots[1] = LootTables.premadeSpell("Fireball")
	trainee.inventory = Items.newInventory()
	trainee.inventory.wands[1] = wand
	-- a real mage standing right behind the dummy must not be hurt by practice spells
	targets[1].root.CFrame = CFrame.new(0, 3, -24)
	for i = 2, #targets do
		targets[i].root.CFrame = CFrame.new(-200, 3, -200 - i * 10) -- clear the firing lane
	end
	local before = #Mock.warnings
	for _ = 1, 30 do
		CastingService.tryCast(trainee, Vector3.new(0, 3, -20))
		Mock.step(0.15)
	end
	Mock.step(2)
	for i = before + 1, #Mock.warnings do
		fail("practice: " .. Mock.warnings[i])
	end
	reported = #Mock.warnings
	if dummy.humanoid.Health >= 500 then
		fail("practice spells should damage the training dummy")
	end
	if dummy.humanoid.Health < 1 then
		fail("training dummies must never die")
	end
	if targets[1].humanoid.Health < 100 then
		fail("practice spells must never hurt real mages")
	end
	if trainee.humanoid.Health < 100 then
		fail("practising mages take no damage (not even from their own explosions)")
	end
	-- and match spells don't hurt dummies
	GameState.setPhase("Battle", 0)
	Mock.step(4) -- let the practice burns run out
	StatusService.clear(dummy)
	dummy.humanoid.Health = 500
	caster.root.CFrame = CFrame.new(0, 3, 10)
	giveWand(LootTables.premadeSpell("Fireball"))
	CastingService.tryCast(caster, Vector3.new(0, 3, -20))
	Mock.step(1.5)
	if dummy.humanoid.Health < 500 then
		fail("match spells should not affect training dummies")
	end
	dummy.alive = false
	dummy.inMatch = false
	trainee.practice = false
	Combatants.remove(dummy)
	Combatants.remove(trainee)
	dummy.model:Destroy()
	trainee.model:Destroy()
end

-- 6. Status effects: burn ticks, frost freezes after three hits, venom stacks.
resetWorld()
do
	local t = targets[1]
	StatusService.apply(t, { kind = "Burn", dps = 4, duration = 3 }, caster)
	Mock.step(3.2)
	local burned = 100 - t.humanoid.Health
	if burned < 10 or burned > 14 then
		fail("burn should deal ~12 damage over 3s, dealt " .. burned)
	end
	for _ = 1, 3 do
		StatusService.apply(t, { kind = "Chill", slow = 0.35, duration = 2.5, maxStacks = 3 }, caster)
	end
	if t.humanoid.WalkSpeed ~= 0 then
		fail("three chills should freeze (walk speed 0), got " .. tostring(t.humanoid.WalkSpeed))
	end
	Mock.step(1.5)
	if t.humanoid.WalkSpeed ~= Config.Combat.BaseWalkSpeed then
		fail("freeze should wear off")
	end
	StatusService.addShield(t, 30, 5, {})
	local dealt = DamageService.apply(t, 20, { attacker = caster, noCrit = true })
	if dealt ~= 0 then
		fail("shield should absorb the hit")
	end
end

-- 7. Inventory: forge, dismantle, slot, unslot through the same entry point the client uses.
do
	local player = Instance.new("Player")
	player.Name = "Tester"
	local c = body("Tester", Vector3.new(40, 3, 40), player)
	InventoryService.reset(c)
	InventoryService.giveKit(c, "Pyromancer")
	local inv = c.inventory
	inv.parts.Bolt = 2
	inv.parts.Fire = 3
	inv.parts.Homing = 1
	inv.parts.OnHit = 1
	inv.parts.Nova = 1
	local ok, msg, novaUid = InventoryService.handle(player, "Forge", { form = "Nova", element = "Fire", mods = {} })
	if not ok then
		fail("forge nova: " .. tostring(msg))
	end
	ok, msg = InventoryService.handle(player, "Forge", {
		form = "Bolt",
		element = "Fire",
		mods = { "Homing" },
		trigger = "OnHit",
		payloadUid = novaUid,
	})
	if not ok then
		fail("forge combo: " .. tostring(msg))
	end
	local combo = inv.spells[#inv.spells]
	if not combo or not combo.recipe.payload or combo.recipe.payload.form ~= "Nova" then
		fail("combo spell should carry the nova payload")
	end
	if inv.parts.Homing ~= nil or inv.parts.OnHit ~= nil then
		fail("forging should consume parts")
	end
	ok = InventoryService.handle(player, "Forge", { form = "Bolt", mods = { "Homing" } })
	if ok then
		fail("forging without the parts should fail")
	end
	ok, msg = InventoryService.handle(player, "PlaceSpell", { uid = combo.uid, wand = 1, slot = 1 })
	if not ok or inv.wands[1].slots[1].uid ~= combo.uid then
		fail("place spell: " .. tostring(msg))
	end
	ok, msg = InventoryService.handle(player, "Unslot", { wand = 1, slot = 1 })
	if not ok then
		fail("unslot: " .. tostring(msg))
	end
	ok, msg = InventoryService.handle(player, "Dismantle", { uid = combo.uid })
	if not ok or (inv.parts.Homing or 0) ~= 1 or (inv.parts.OnHit or 0) ~= 1 then
		fail("dismantle should return parts: " .. tostring(msg))
	end
	local payloadBack = false
	for _, spell in inv.spells do
		if spell.recipe.form == "Nova" then
			payloadBack = true
		end
	end
	if not payloadBack then
		fail("dismantle should return the payload spell")
	end
	for _, bad in
		{
			{ "Forge", { form = "Bolt", mods = { 1, 2 } } },
			{ "PlaceSpell", { uid = "nope", wand = 99, slot = -1 } },
			{ "PlaceSpell", { uid = {}, wand = "1", slot = 1 } },
			{ "Equip", { index = 0.5 } },
			{ "DoesNotExist", {} },
		}
	do
		if InventoryService.handle(player, bad[1], bad[2]) then
			fail("malformed request should be rejected: " .. bad[1])
		end
	end
	inv.consumables.HealingDraught = 1
	c.humanoid.Health = 50
	ok, msg = InventoryService.handle(player, "UseConsumable", { id = "HealingDraught" })
	Mock.step(5)
	if not ok or c.humanoid.Health < 85 then
		fail("healing draught should heal ~40: " .. tostring(msg) .. " health=" .. c.humanoid.Health)
	end
end

-- warnings raised outside castAndRun are failures too
for i = reported + 1, #Mock.warnings do
	fail(Mock.warnings[i])
end

local keys = {}
for k, n in Mock.remoteCounts do
	table.insert(keys, k .. "=" .. n)
end
table.sort(keys)
print("remote traffic: " .. table.concat(keys, ", "))
if failures > 0 then
	print(failures .. " failure(s)")
	process.exit(1)
end
print("combat simulation passed")
