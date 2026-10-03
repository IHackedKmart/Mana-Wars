-- Wand casting rules, Noita style: each wand is a deck of spells that it cycles
-- through left to right. Every cast draws `spellsPerCast` spells, pays their mana,
-- waits the cast delay, and after the last spell the wand recharges.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Items = require(Shared.Items)
local SpellBuilder = require(Shared.Spells.SpellBuilder)
local SpellTypes = require(Shared.Spells.SpellTypes)
local Geometry = require(Shared.Util.Geometry)
local Combatants = require(script.Parent.Combatants)
local GameState = require(script.Parent.GameState)
local WorldQuery = require(script.Parent.WorldQuery)
local DamageService = require(script.Parent.DamageService)
local SpellExecutor = require(script.Parent.SpellExecutor)
local FX = require(script.Parent.FX)

type Combatant = Combatants.Combatant
type WandState = Combatants.WandState
type Spec = SpellTypes.Spec

local CastingService = {}

local wandStateEvent = Remotes.event("WandState")
local rng = Random.new()
local compileCache: { [string]: Spec } = {}

local function now(): number
	return workspace:GetServerTimeNow()
end

local function buildOrder(wand: Items.WandItem): { number }
	local order = {}
	for i = 1, wand.stats.capacity do
		if wand.slots[i] then
			table.insert(order, i)
		end
	end
	if wand.stats.shuffle then
		for i = #order, 2, -1 do
			local j = rng:NextInteger(1, i)
			order[i], order[j] = order[j], order[i]
		end
	end
	return order
end

function CastingService.state(c: Combatant, wand: Items.WandItem): WandState
	local st = c.wandStates[wand.uid]
	local t = now()
	if not st then
		st = {
			mana = wand.stats.manaMax,
			manaTime = t,
			order = nil,
			deckPos = 1,
			nextCastAt = 0,
			rechargeUntil = 0,
		}
		c.wandStates[wand.uid] = st
	end
	local s = st :: WandState
	s.mana = math.min(wand.stats.manaMax, s.mana + wand.stats.manaRegen * (t - s.manaTime))
	s.manaTime = t
	return s
end

local function findWand(c: Combatant, uid: string): Items.WandItem?
	for _, wand in c.inventory.wands do
		if wand and wand.uid == uid then
			return wand
		end
	end
	return nil
end

function CastingService.sendState(c: Combatant)
	local player = c.player
	if not player then
		return
	end
	local inv = c.inventory
	local wand = inv.wands[inv.equipped]
	if not wand then
		wandStateEvent:FireClient(player, nil)
		return
	end
	local st = CastingService.state(c, wand)
	wandStateEvent:FireClient(player, {
		uid = wand.uid,
		mana = st.mana,
		manaMax = wand.stats.manaMax,
		regen = wand.stats.manaRegen,
		t = st.manaTime,
		nextCastAt = st.nextCastAt,
		rechargeUntil = st.rechargeUntil,
		deckPos = st.deckPos,
		order = st.order or buildOrder(wand),
	})
end

-- Called whenever a wand's slots change so the deck is rebuilt on the next cast.
function CastingService.resetDeck(c: Combatant, wandUid: string)
	local st = c.wandStates[wandUid]
	if st then
		st.order = nil
		st.deckPos = 1
	end
end

function CastingService.addMana(c: Combatant, wandUid: string, amount: number)
	local wand = findWand(c, wandUid)
	if not wand then
		return
	end
	local st = CastingService.state(c, wand)
	st.mana = math.min(wand.stats.manaMax, st.mana + amount)
end

function CastingService.refillAll(c: Combatant)
	for _, wand in c.inventory.wands do
		if wand then
			local st = CastingService.state(c, wand)
			st.mana = wand.stats.manaMax
		end
	end
	CastingService.sendState(c)
end

function CastingService.compile(wand: Items.WandItem, spell: Items.SpellItem): Spec?
	local key = wand.uid .. "|" .. spell.uid
	local cached = compileCache[key]
	if cached then
		return cached
	end
	local spec = SpellBuilder.compile(spell.recipe, Items.wandContext(wand))
	if spec then
		compileCache[key] = spec
	end
	return spec
end

function CastingService.clearCache()
	table.clear(compileCache)
end

-- Where the spell leaves the wand and which way it goes.
local function aim(c: Combatant, target: Vector3): (Vector3, Vector3)
	local model = c.model :: Model
	local root = c.root :: BasePart
	local head = model:FindFirstChild("Head") :: BasePart?
	local eye = if head then head.Position else root.Position + Vector3.new(0, 1.5, 0)
	local look = target - eye
	if look.Magnitude < 2 then
		look = root.CFrame.LookVector
	end
	local dir = look.Unit
	local origin = eye + dir * 2.2 - Vector3.new(0, 0.3, 0)
	local blocked = WorldQuery.raycast(eye, origin - eye)
	if blocked then
		origin = blocked.Position - dir * 0.4
	end
	local final = target - origin
	if final.Magnitude > 3 then
		dir = final.Unit
	end
	return origin, dir
end

-- Attempts a cast for any combatant. Returns success and a reason when it fails.
function CastingService.tryCast(c: Combatant, target: Vector3): (boolean, string?)
	if not Combatants.canAct(c) or c.locked then
		return false, "inactive"
	end
	-- match fighters cast during the grace period and the battle; the lobby Spell Lab always works
	if not c.practice and not GameState.combatAllowed() then
		return false, "not now"
	end
	if (c.status.frozenUntil or 0) > now() then
		return false, "frozen"
	end
	local inv = c.inventory
	local wand = inv.wands[inv.equipped]
	if not wand then
		return false, "no wand"
	end
	local st = CastingService.state(c, wand)
	local t = now()
	if t < st.nextCastAt - Config.Combat.CastTolerance then
		return false, "cooldown"
	end
	if not st.order or #st.order == 0 then
		st.order = buildOrder(wand)
		st.deckPos = 1
	end
	local order = st.order :: { number }
	if #order == 0 then
		return false, "empty wand"
	end

	-- draw spells from the deck
	local drawn: { Spec } = {}
	local pos = st.deckPos
	for _ = 1, wand.stats.spellsPerCast do
		if pos > #order then
			break
		end
		local spell = wand.slots[order[pos]]
		if spell then
			local spec = CastingService.compile(wand, spell)
			if spec then
				table.insert(drawn, spec)
			end
		end
		pos += 1
	end
	if #drawn == 0 then
		st.order = nil
		return false, "empty wand"
	end

	local mana, delay, recharge, hpCost = 0, 0, 0, 0
	for _, spec in drawn do
		mana += spec.mana
		delay += spec.castDelay
		recharge += spec.recharge
		hpCost += spec.hpCost
	end
	if st.mana < mana then
		CastingService.sendState(c)
		return false, "no mana"
	end
	st.mana -= mana
	st.deckPos = pos

	local wait = math.max(0.04, wand.stats.castDelay + delay)
	if pos > #order then
		local rechargeTime = math.max(0.05, wand.stats.rechargeTime + recharge)
		wait = math.max(wait, rechargeTime)
		st.rechargeUntil = t + rechargeTime
		st.deckPos = 1
		if wand.stats.shuffle then
			st.order = buildOrder(wand)
		end
	end
	st.nextCastAt = t + wait

	if hpCost > 0 then
		DamageService.apply(c, hpCost, { attacker = c, selfCost = true, isDot = true, element = "Blood" })
		if not Combatants.canAct(c) then
			return true, nil
		end
	end

	local origin, dir = aim(c, target)
	dir = Geometry.jitter(dir, wand.stats.spread, rng)
	local ctx = {
		caster = c,
		wandUid = wand.uid,
		siphon = Items.perkValue(wand, "Siphon"),
		vampiric = Items.perkValue(wand, "Vampiric"),
		budget = { n = Config.Combat.MaxTriggerFanout },
		aimPoint = target,
	}
	FX.all("Cast", c.model, drawn[1].color)
	for _, spec in drawn do
		local ok, err = pcall(SpellExecutor.cast, spec, ctx, origin, dir, true)
		if not ok then
			warn("[Cast] " .. tostring(err))
		end
	end
	CastingService.sendState(c)
	return true, nil
end

local function finiteVector(v: any): boolean
	if typeof(v) ~= "Vector3" then
		return false
	end
	return v.X == v.X
		and v.Y == v.Y
		and v.Z == v.Z
		and math.abs(v.X) < 1e5
		and math.abs(v.Y) < 1e5
		and math.abs(v.Z) < 1e5
end

function CastingService.init()
	DamageService.onSiphon = CastingService.addMana

	Remotes.event("CastRequest").OnServerEvent:Connect(function(player, target)
		if not finiteVector(target) then
			return
		end
		local c = Combatants.forPlayer(player)
		if c then
			local ok, reason = CastingService.tryCast(c, target)
			if not ok and reason == "no mana" then
				FX.to(player, "NoMana")
			end
		end
	end)
end

return CastingService
