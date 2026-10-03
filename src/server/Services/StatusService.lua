-- Burning, venom, chill/freeze, radiant marks, shields, haste and regeneration.
-- Owns WalkSpeed/JumpHeight so slows, freezes and pedestal locks never fight each other.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local SpellTypes = require(ReplicatedStorage.Shared.Spells.SpellTypes)
local Combatants = require(script.Parent.Combatants)

type Combatant = Combatants.Combatant
type StatusDef = SpellTypes.StatusDef

local StatusService = {}

-- Injected by DamageService to avoid a require cycle.
StatusService.dealDamage = nil :: ((Combatant, number, { [string]: any }) -> number)?

local TICK = 0.25

local function now(): number
	return workspace:GetServerTimeNow()
end

local function rgb(c: { number }?): Color3
	if c then
		return Color3.fromRGB(c[1], c[2], c[3])
	end
	return Color3.new(1, 1, 1)
end

function StatusService.updateMovement(c: Combatant)
	local hum = c.humanoid
	if not hum then
		return
	end
	local s = c.status
	local t = now()
	local speed = Config.Combat.BaseWalkSpeed
	local frozen = (s.frozenUntil or 0) > t
	if s.haste and s.haste.untilT > t then
		speed *= s.haste.mult
	end
	if s.chill and s.chill.untilT > t then
		speed *= 1 - s.chill.slow
	end
	if frozen or c.locked then
		speed = 0
	end
	hum.WalkSpeed = speed
	hum.UseJumpPower = false
	hum.JumpHeight = if frozen or c.locked then 0 else Config.Combat.BaseJumpHeight
end

local function setInstance(
	parent: Instance?,
	name: string,
	className: string,
	enabled: boolean,
	configure: ((any) -> ())?
)
	if not parent then
		return
	end
	local existing = parent:FindFirstChild(name)
	if enabled then
		if not existing then
			existing = Instance.new(className)
			existing.Name = name
			if configure then
				configure(existing)
			end
			existing.Parent = parent
		end
	elseif existing then
		existing:Destroy()
	end
end

function StatusService.refreshVisuals(c: Combatant)
	local model, root = c.model, c.root
	if not model or not root then
		return
	end
	local s = c.status
	local t = now()

	setInstance(root, "StatusFire", "Fire", s.burn ~= nil and s.burn.untilT > t, function(fire: Fire)
		fire.Size = 5
		fire.Heat = 8
		fire.Color = Color3.fromRGB(255, 120, 30)
		fire.SecondaryColor = Color3.fromRGB(255, 220, 80)
	end)

	setInstance(
		root,
		"StatusVenom",
		"ParticleEmitter",
		s.venom ~= nil and s.venom.untilT > t,
		function(p: ParticleEmitter)
			p.Color = ColorSequence.new(Color3.fromRGB(120, 230, 60))
			p.LightEmission = 0.3
			p.Size = NumberSequence.new(0.5, 0)
			p.Lifetime = NumberRange.new(0.8, 1.4)
			p.Rate = 14
			p.Speed = NumberRange.new(2, 4)
			p.SpreadAngle = Vector2.new(40, 40)
			p.Acceleration = Vector3.new(0, 4, 0)
		end
	)

	setInstance(root, "StatusHaste", "Sparkles", s.haste ~= nil and s.haste.untilT > t, function(sp: Sparkles)
		sp.SparkleColor = Color3.fromRGB(150, 255, 200)
	end)

	-- One highlight shows the most important visual state.
	local frozen = (s.frozenUntil or 0) > t
	local marked = (s.markUntil or 0) > t
	local chilled = s.chill ~= nil and s.chill.untilT > t
	local hl = model:FindFirstChild("StatusHighlight") :: Highlight?
	if frozen or marked or chilled then
		if not hl then
			local newHl = Instance.new("Highlight")
			newHl.Name = "StatusHighlight"
			newHl.Parent = model
			hl = newHl
		end
		local h = hl :: Highlight
		if frozen then
			h.FillColor = Color3.fromRGB(170, 230, 255)
			h.FillTransparency = 0.25
			h.OutlineColor = Color3.new(1, 1, 1)
			h.DepthMode = Enum.HighlightDepthMode.Occluded
		elseif marked then
			h.FillColor = Color3.fromRGB(255, 225, 120)
			h.FillTransparency = 0.7
			h.OutlineColor = Color3.fromRGB(255, 200, 60)
			h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		else
			h.FillColor = Color3.fromRGB(140, 210, 255)
			h.FillTransparency = 0.7
			h.OutlineColor = Color3.fromRGB(180, 230, 255)
			h.DepthMode = Enum.HighlightDepthMode.Occluded
		end
	elseif hl then
		hl:Destroy()
	end

	local shield = s.shield
	local bubble = model:FindFirstChild("ShieldBubble") :: BasePart?
	if shield and shield.amount > 0 and shield.untilT > t then
		if not bubble then
			local b = Instance.new("Part")
			b.Name = "ShieldBubble"
			b.Shape = Enum.PartType.Ball
			b.Size = Vector3.new(7.5, 7.5, 7.5)
			b.Material = Enum.Material.ForceField
			b.Color = shield.color
			b.CanCollide = false
			b.CanQuery = false
			b.CanTouch = false
			b.Massless = true
			b.CFrame = root.CFrame
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = root
			weld.Part1 = b
			weld.Parent = b
			b.Parent = model
		end
	elseif bubble then
		bubble:Destroy()
	end
end

function StatusService.apply(target: Combatant, def: StatusDef, source: Combatant?)
	local s = target.status
	local t = now()
	if def.kind == "Burn" then
		local dps = def.dps or 4
		if s.burn and s.burn.untilT > t then
			dps = math.max(dps, s.burn.dps)
		end
		s.burn = { dps = dps, untilT = t + def.duration, source = source }
	elseif def.kind == "Venom" then
		local stacks = 1
		if s.venom and s.venom.untilT > t then
			stacks = math.min(def.maxStacks or 5, s.venom.stacks + 1)
		end
		s.venom = { stacks = stacks, dps = def.dps or 1.5, untilT = t + def.duration, source = source }
	elseif def.kind == "Chill" then
		if (s.frozenUntil or 0) > t then
			return
		end
		local stacks = 1
		if s.chill and s.chill.untilT > t then
			stacks = s.chill.stacks + 1
		end
		if stacks >= (def.maxStacks or 3) then
			s.chill = nil
			s.frozenUntil = t + 1.25
		else
			s.chill = { stacks = stacks, slow = def.slow or 0.35, untilT = t + def.duration }
		end
		StatusService.updateMovement(target)
	end
	StatusService.refreshVisuals(target)
end

function StatusService.mark(target: Combatant, duration: number)
	target.status.markUntil = math.max(target.status.markUntil or 0, now() + duration)
	StatusService.refreshVisuals(target)
end

function StatusService.isMarked(target: Combatant): boolean
	return (target.status.markUntil or 0) > now()
end

export type ShieldOptions = {
	color: { number }?,
	thorns: StatusDef?,
	onEnd: ((Vector3, Vector3) -> ())?,
}

local function endShield(c: Combatant)
	local shield = c.status.shield
	if not shield then
		return
	end
	c.status.shield = nil
	StatusService.refreshVisuals(c)
	if shield.onEnd and c.root then
		local root = c.root :: BasePart
		task.spawn(shield.onEnd, root.Position + Vector3.new(0, 1, 0), root.CFrame.LookVector)
	end
end

function StatusService.addShield(c: Combatant, amount: number, duration: number, opts: ShieldOptions?)
	local old = c.status.shield
	if old and old.onEnd then
		endShield(c)
	end
	c.status.shield = {
		amount = amount,
		untilT = now() + duration,
		color = rgb(opts and opts.color or { 150, 200, 255 }),
		thorns = opts and opts.thorns,
		onEnd = opts and opts.onEnd,
	}
	StatusService.refreshVisuals(c)
end

-- Soaks damage into the shield. Returns the damage left over.
function StatusService.absorb(c: Combatant, amount: number, attacker: Combatant?): number
	local shield = c.status.shield
	if not shield or shield.untilT <= now() then
		return amount
	end
	local soaked = math.min(shield.amount, amount)
	shield.amount -= soaked
	if shield.thorns and attacker and attacker ~= c then
		StatusService.apply(attacker, shield.thorns, c)
	end
	if shield.amount <= 0 then
		endShield(c)
	end
	return amount - soaked
end

function StatusService.shieldAmount(c: Combatant): number
	local shield = c.status.shield
	if shield and shield.untilT > now() then
		return shield.amount
	end
	return 0
end

function StatusService.addHaste(c: Combatant, mult: number, duration: number)
	c.status.haste = { mult = mult, untilT = now() + duration }
	StatusService.updateMovement(c)
	StatusService.refreshVisuals(c)
end

function StatusService.addRegen(c: Combatant, hps: number, duration: number)
	c.status.regen = { hps = hps, untilT = now() + duration }
end

function StatusService.clear(c: Combatant)
	c.status = {}
	c.locked = false
	StatusService.refreshVisuals(c)
	StatusService.updateMovement(c)
end

local function tick()
	local t = now()
	for _, c in Combatants.all() do
		local hum = c.humanoid
		if hum and c.alive and hum.Health > 0 then
			local s = c.status
			local changed = false
			local damage = StatusService.dealDamage
			if s.burn then
				if s.burn.untilT > t then
					if damage then
						damage(c, s.burn.dps * TICK, { attacker = s.burn.source, isDot = true, element = "Fire" })
					end
				else
					s.burn = nil
					changed = true
				end
			end
			if s.venom then
				if s.venom.untilT > t then
					if damage then
						damage(
							c,
							s.venom.dps * s.venom.stacks * TICK,
							{ attacker = s.venom.source, isDot = true, element = "Poison" }
						)
					end
				else
					s.venom = nil
					changed = true
				end
			end
			if s.regen then
				if s.regen.untilT > t then
					hum.Health = math.min(hum.MaxHealth, hum.Health + s.regen.hps * TICK)
				else
					s.regen = nil
				end
			end
			if s.chill and s.chill.untilT <= t then
				s.chill = nil
				changed = true
			end
			if s.frozenUntil and s.frozenUntil <= t then
				s.frozenUntil = nil
				changed = true
			end
			if s.markUntil and s.markUntil <= t then
				s.markUntil = nil
				changed = true
			end
			if s.haste and s.haste.untilT <= t then
				s.haste = nil
				changed = true
			end
			if s.shield and s.shield.untilT <= t then
				endShield(c)
			end
			if changed then
				StatusService.updateMovement(c)
				StatusService.refreshVisuals(c)
			end
		end
	end
end

function StatusService.init()
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc >= TICK then
			acc -= TICK
			tick()
		end
	end)
end

return StatusService
