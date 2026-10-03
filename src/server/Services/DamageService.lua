-- The single place damage is dealt: grace period, self-damage, crits, marks, shields,
-- lifesteal, mana siphon, knockback, damage numbers and kill credit all happen here.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local SpellTypes = require(ReplicatedStorage.Shared.Spells.SpellTypes)
local Combatants = require(script.Parent.Combatants)
local GameState = require(script.Parent.GameState)
local StatusService = require(script.Parent.StatusService)

type Combatant = Combatants.Combatant

export type DamageInfo = {
	attacker: Combatant?,
	element: string?,
	crit: number?,
	isDot: boolean?,
	isStorm: boolean?,
	selfCost: boolean?,
	noCrit: boolean?,
	knockDir: Vector3?,
	knockback: number?,
	lift: number?,
	lifesteal: number?,
	siphon: number?,
	wandUid: string?,
	status: SpellTypes.StatusDef?,
	mark: number?,
	spellName: string?,
	hitPos: Vector3?,
}

local DamageService = {}

-- Injected by CastingService (avoids a require cycle): restore mana to a wand.
DamageService.onSiphon = nil :: ((Combatant, string, number) -> ())?

local knockbackEvent = Remotes.event("Knockback")
local damageNumber = Remotes.unreliable("DamageNumber")
local rng = Random.new()

function DamageService.knock(target: Combatant, velocity: Vector3)
	if velocity.Magnitude < 1 then
		return
	end
	if target.player then
		knockbackEvent:FireClient(target.player, velocity)
	elseif target.root then
		local root = target.root :: BasePart
		root.AssemblyLinearVelocity += velocity
	end
end

function DamageService.heal(target: Combatant, amount: number)
	local hum = target.humanoid
	if hum and hum.Health > 0 and amount > 0 then
		hum.Health = math.min(hum.MaxHealth, hum.Health + amount)
	end
end

-- Whether `attacker` may affect `target` right now (damage, pulls, swaps, rewinds).
function DamageService.canHurt(target: Combatant, attacker: Combatant?, isStorm: boolean?): boolean
	local hum = target.humanoid
	if not hum or hum.Health <= 0 or not target.alive or not target.inMatch then
		return false
	end
	if target.isDummy then
		-- training dummies only react to spells from the Spell Lab
		return attacker ~= nil and attacker.practice
	end
	-- practice spells never hurt anyone real, even if they somehow reach the arena
	if attacker and attacker.practice then
		return false
	end
	if not GameState.combatAllowed() then
		return false
	end
	-- grace period: players (and bots) cannot hurt each other yet
	if GameState.phase == "Grace" and attacker and attacker ~= target and not isStorm then
		return false
	end
	return true
end

-- Returns the damage actually dealt to health, and whether the hit was a kill
-- (for a training dummy: knocked down to its last hit point).
function DamageService.apply(target: Combatant, amount: number, info: DamageInfo): (number, boolean)
	local attacker = info.attacker
	local isSelf = attacker == target
	if not DamageService.canHurt(target, attacker, info.isStorm) then
		return 0, false
	end
	local hum = target.humanoid :: Humanoid

	local crit = false
	local lifesteal = info.lifesteal or 0
	if isSelf then
		if not info.selfCost then
			amount *= Config.Combat.SelfDamageMultiplier
		end
	else
		-- robe / hat enchantments: elemental attunement, precision, leeching, warding
		if attacker and not info.isStorm then
			amount *= 1 + (attacker.gear["elem:" .. (info.element or "")] or 0)
			if not info.isDot then
				lifesteal += attacker.gear.lifesteal or 0
			end
		end
		if not info.isStorm then
			amount *= 1 - (target.gear.ward or 0)
		end
		if not info.isDot and not info.noCrit and not info.isStorm then
			local chance = Config.Combat.BaseCritChance
				+ (info.crit or 0)
				+ (if attacker then attacker.gear.crit or 0 else 0)
			if rng:NextNumber() < chance then
				amount *= Config.Combat.CritMultiplier
				crit = true
			end
		end
		if StatusService.isMarked(target) then
			amount *= 1 + Config.Combat.MarkedDamageBonus
		end
	end

	if amount > 0 and not info.selfCost then
		amount = StatusService.absorb(target, amount, attacker)
	end

	local dealt = math.min(hum.Health, math.max(0, amount))
	if target.isDummy then
		-- dummies never die; PracticeService heals them back up
		dealt = math.min(dealt, hum.Health - 1)
	end
	if dealt > 0 then
		hum.Health -= dealt
	end
	local shown = if target.isDummy then math.max(0, amount) else dealt

	if attacker and not isSelf then
		target.lastAttacker = attacker
		target.lastAttackTime = workspace:GetServerTimeNow()
		target.lastSpellName = info.spellName or target.lastSpellName
		if dealt > 0 and lifesteal > 0 then
			DamageService.heal(attacker, dealt * lifesteal)
		end
		if info.siphon and info.siphon > 0 and info.wandUid and DamageService.onSiphon and not info.isDot then
			DamageService.onSiphon(attacker, info.wandUid, info.siphon)
		end
	end
	if info.isStorm then
		target.lastSpellName = "the Mana Storm"
	end

	if not info.isDot and hum.Health > 0 then
		if info.status then
			StatusService.apply(target, info.status, attacker)
		end
		if info.mark and info.mark > 0 then
			StatusService.mark(target, info.mark)
		end
	end

	if info.knockDir and (info.knockback or 0) > 0 then
		local flat = Vector3.new(info.knockDir.X, 0, info.knockDir.Z)
		local push = if flat.Magnitude > 1e-3 then flat.Unit * (info.knockback :: number) else Vector3.zero
		local up = (info.lift or 0) + math.min(25, (info.knockback :: number) * 0.3)
		DamageService.knock(target, push + Vector3.new(0, up, 0))
	end

	-- floating numbers for the attacker, a hurt flash for the victim
	local pos = info.hitPos or (if target.root then (target.root :: BasePart).Position else Vector3.zero)
	if dealt > 0 or amount > 0 then
		if attacker and attacker.player and not isSelf then
			damageNumber:FireClient(
				attacker.player,
				pos,
				math.floor(shown + 0.5),
				crit,
				info.element or "Neutral",
				false
			)
		end
		if target.player and (dealt >= 1 or not info.isDot) then
			damageNumber:FireClient(target.player, pos, math.floor(dealt + 0.5), crit, info.element or "Neutral", true)
		end
	end
	local killed = dealt > 0 and (hum.Health <= 0 or (target.isDummy and hum.Health <= 1))
	return dealt, killed
end

function DamageService.init()
	StatusService.dealDamage = function(c, amount, info)
		local dealt = DamageService.apply(c, amount, info :: any)
		return dealt
	end
end

return DamageService
