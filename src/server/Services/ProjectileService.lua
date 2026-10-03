-- Authoritative projectile simulation. Every frame each projectile moves (ProjectileSim),
-- then is swept against combatant capsules and raycast against the world.
-- Clients get a spawn message and simulate the same motion; anything world-dependent
-- (bounces, sticking, homing) is corrected through the FXSync unreliable remote.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local ProjectileSim = require(Shared.ProjectileSim)
local Geometry = require(Shared.Util.Geometry)
local SpellTypes = require(Shared.Spells.SpellTypes)
local Combatants = require(script.Parent.Combatants)
local WorldQuery = require(script.Parent.WorldQuery)
local DamageService = require(script.Parent.DamageService)
local FX = require(script.Parent.FX)

type Spec = SpellTypes.Spec
type Combatant = Combatants.Combatant

export type CastCtx = {
	caster: Combatant,
	wandUid: string?,
	siphon: number,
	vampiric: number,
	budget: { n: number, splits: number? }, -- payload casts / Hydra + Fractal copies left for this cast
	aimPoint: Vector3?, -- where the caster clicked (used by Meteor and Skyfall)
}

type Proj = {
	id: number,
	spec: Spec,
	ctx: CastCtx,
	state: ProjectileSim.State,
	radius: number,
	hit: { [Combatant]: boolean },
	pierceLeft: number,
	bouncesLeft: number,
	timerFired: boolean,
	nextPulse: number,
	pulses: number,
	armedAt: number?,
	dead: boolean,
	complex: boolean,
	lastSync: number,
	target: Combatant?,
	targetTime: number,
	nextShot: number, -- sentry fire time (projectile age)
	nextField: number, -- pull / aura tick (projectile age)
	proxFired: boolean,
	bounceTriggers: number,
}

local ProjectileService = {}

-- The executor handles everything that happens when a projectile hits or ends.
-- It is injected at startup because it also spawns projectiles (require cycle).
type Executor = {
	hitCombatant: (Spec, CastCtx, Combatant, Vector3, Vector3, number?) -> (),
	onImpact: (Spec, CastCtx, Vector3, Vector3, Vector3, Combatant?) -> (),
	onPierce: (Spec, CastCtx, Vector3, Vector3) -> (),
	onEnd: (Spec, CastCtx, Vector3, Vector3, Vector3?) -> (),
	explode: (Spec, CastCtx, Vector3) -> (),
	castPayload: (Spec, CastCtx, Vector3, Vector3, Vector3?) -> (),
	zoneAt: (Spec, CastCtx, Vector3) -> (),
}
local executor: Executor

local active: { Proj } = {}
local nextId = 0
local fxSync = Remotes.unreliable("FXSync")
local syncBatch: { any } = {}
local seedRng = Random.new()

local MAX_PULSES = 6
local PULSE_INTERVAL = 0.6
local TIMER_DELAY = 0.5
local SYNC_INTERVAL = 0.1
local FIELD_TICK = 0.2
local PROXIMITY_RADIUS = 9
local MAX_BOUNCE_TRIGGERS = 8

local function now(): number
	return workspace:GetServerTimeNow()
end

function ProjectileService.setExecutor(e: Executor)
	executor = e
end

-- Compact visual description sent once per projectile.
local function visualOf(spec: Spec): { [string]: any }
	local cached = (spec :: any)._vis
	if cached then
		return cached
	end
	local vis = {
		f = spec.form,
		e = spec.element,
		c = spec.color,
		c2 = spec.color2,
		s = spec.size,
		g = spec.gravity,
		h = spec.homing,
		a = spec.accelerate,
		r = spec.erratic,
		o = spec.orbit,
		or_ = spec.orbitRadius,
		b = spec.boomerangAt,
		l = spec.lifetime,
		d = spec.hold,
		hv = spec.hover,
	}
	(spec :: any)._vis = vis
	return vis
end

export type SpawnOptions = {
	orbitAngle: number?,
	bouncesLeft: number?, -- Hydra copies keep the bounces their parent had left
	noHold: boolean?, -- split-off copies don't freeze again (Stasis)
}

-- Hydra and Fractal copies come out of a per-cast budget so they can't run away forever.
function ProjectileService.takeSplit(ctx: CastCtx): boolean
	local left = ctx.budget.splits
	if left == nil then
		left = Config.Combat.MaxSplits
	end
	if left <= 0 then
		return false
	end
	ctx.budget.splits = left - 1
	return true
end

function ProjectileService.spawn(spec: Spec, ctx: CastCtx, origin: Vector3, dir: Vector3, opts: SpawnOptions?): boolean
	if #active >= Config.Combat.MaxProjectiles then
		return false
	end
	nextId += 1
	local seed = seedRng:NextInteger(1, 2 ^ 30)
	local orbitAngle = opts and opts.orbitAngle or math.atan2(dir.Z, dir.X)
	local state = ProjectileSim.new({
		pos = origin,
		dir = Geometry.safeUnit(dir),
		speed = spec.speed,
		gravity = spec.gravity,
		homing = spec.homing,
		accelerate = spec.accelerate,
		erratic = spec.erratic,
		orbit = spec.orbit,
		orbitRadius = spec.orbitRadius,
		orbitAngle = orbitAngle,
		boomerangAt = spec.boomerangAt,
		hold = if opts and opts.noHold then 0 else spec.hold,
		hover = spec.hover,
		seed = seed,
	})
	local p: Proj = {
		id = nextId,
		spec = spec,
		ctx = ctx,
		state = state,
		radius = math.max(0.25, spec.size * 0.5),
		hit = {},
		pierceLeft = spec.pierce,
		bouncesLeft = if opts and opts.bouncesLeft then opts.bouncesLeft else spec.bounces,
		timerFired = false,
		nextPulse = PULSE_INTERVAL,
		pulses = 0,
		armedAt = nil,
		dead = false,
		complex = spec.homing > 0 or spec.orbit or spec.boomerangAt > 0 or spec.erratic > 0 or spec.accelerate > 0,
		lastSync = now(),
		target = nil,
		targetTime = 0,
		nextShot = state.hold + spec.hover,
		nextField = 0,
		proxFired = false,
		bounceTriggers = 0,
	}
	table.insert(active, p)
	local vis = visualOf(spec)
	if state.hold ~= spec.hold then
		vis = table.clone(vis)
		vis.d = state.hold
	end
	FX.all("P+", p.id, origin, state.vel, seed, orbitAngle, ctx.caster.model, vis)
	return true
end

local function kill(p: Proj, pos: Vector3, kind: string)
	if p.dead then
		return
	end
	p.dead = true
	FX.all("P-", p.id, pos, kind)
end

local function syncNow(p: Proj)
	p.lastSync = now()
	table.insert(syncBatch, { p.id, p.state.pos, p.state.vel, p.state.stuck })
end

-- The nearest enemy this projectile can see (sentries, auto-aimed payloads, proximity fuses).
local function nearestVisible(p: Proj, range: number): Combatant?
	local pos = p.state.pos
	local best, bestDist = nil, range
	for _, c in Combatants.active() do
		if c ~= p.ctx.caster and DamageService.canHurt(c, p.ctx.caster) then
			local center = Combatants.centerOf(c)
			local dist = (center - pos).Magnitude
			if dist < bestDist and (p.spec.phasing or WorldQuery.lineOfSight(pos, center)) then
				best, bestDist = c, dist
			end
		end
	end
	return best
end

-- A hovering sentry aims its payloads at the nearest enemy (and tells meteors / walls where).
local function aimDir(p: Proj, fallback: Vector3): (Vector3, Vector3?)
	if p.spec.hover > 0 then
		local target = nearestVisible(p, math.max(p.spec.turretRange, 40))
		if target then
			local at = Combatants.centerOf(target)
			return Geometry.safeUnit(at - p.state.pos, fallback), at
		end
	end
	return fallback, nil
end

-- Magnetic pull and damaging auras (Tornado, Black Hole) while the projectile flies.
local function fieldTick(p: Proj)
	local spec = p.spec
	local pos = p.state.pos
	local caster = p.ctx.caster
	local reach = math.max(spec.auraRadius, if spec.pull > 0 then 14 + spec.size * 2 else 0)
	for _, c in Combatants.withinRadius(pos, reach + 1.5, caster) do
		if DamageService.canHurt(c, caster) then
			local center = Combatants.centerOf(c)
			local to = pos - center
			local flat = Vector3.new(to.X, 0, to.Z)
			if spec.pull > 0 and flat.Magnitude > 1.5 then
				DamageService.knock(c, flat.Unit * spec.pull * 0.6 + Vector3.new(0, 4, 0))
			end
			if spec.auraDps > 0 and to.Magnitude <= spec.auraRadius + 1.5 then
				local swirl = Vector3.new(-flat.Z, 0, flat.X)
				DamageService.apply(c, spec.auraDps * FIELD_TICK, {
					attacker = caster,
					element = spec.element,
					noCrit = true,
					status = spec.status,
					knockDir = if swirl.Magnitude > 1e-3 then swirl.Unit else nil,
					knockback = if spec.auraLift > 0 then 10 else 0,
					lift = spec.auraLift,
					lifesteal = spec.lifesteal + p.ctx.vampiric,
					spellName = spec.name,
					hitPos = center,
				})
			end
		end
	end
end

local function findTarget(p: Proj): Combatant?
	local pos = p.state.pos
	local vel = p.state.vel
	local forward = if vel.Magnitude > 1e-3 then vel.Unit else nil
	local best, bestScore = nil, math.huge
	local caster = p.ctx.caster
	for _, c in Combatants.active() do
		if c ~= caster then
			local to = (c.root :: BasePart).Position - pos
			local dist = to.Magnitude
			if dist < 80 and dist > 0.1 then
				local facing = if forward then forward:Dot(to.Unit) else 1
				if facing > -0.3 then
					local score = dist * (1.6 - facing * 0.6)
					if score < bestScore then
						best, bestScore = c, score
					end
				end
			end
		end
	end
	return best
end

local function impact(p: Proj, pos: Vector3, normal: Vector3, hitC: Combatant?)
	local dir = Geometry.safeUnit(p.state.vel, -normal)
	executor.onImpact(p.spec, p.ctx, pos, normal, dir, hitC)
	executor.onEnd(p.spec, p.ctx, pos, dir, if hitC then nil else normal)
	kill(p, pos, "impact")
end

local function expire(p: Proj)
	local spec = p.spec
	local pos = p.state.pos
	local dir = Geometry.safeUnit(p.state.vel)
	if spec.explodeOnExpire and spec.explodeRadius > 0 then
		executor.explode(spec, p.ctx, pos)
	end
	if spec.form == "Cloud" and spec.zoneOnImpact and not p.state.stuck then
		executor.zoneAt(spec, p.ctx, pos)
	end
	executor.onEnd(spec, p.ctx, pos, dir)
	kill(p, pos, "expire")
end

local function onCombatantHit(p: Proj, c: Combatant, pos: Vector3)
	p.hit[c] = true
	local spec = p.spec
	local dir = Geometry.safeUnit(p.state.vel)
	executor.hitCombatant(spec, p.ctx, c, pos, dir, nil)
	-- bombs, mines and flasks burst on contact with a body (black holes and tornadoes don't)
	if spec.directMult == 0 and spec.pierce < 50 and (spec.explodeRadius > 0 or spec.zoneOnImpact) then
		impact(p, pos, -dir, c)
		return
	end
	if p.pierceLeft > 0 then
		p.pierceLeft -= 1
		executor.onPierce(spec, p.ctx, pos, dir)
		return
	end
	impact(p, pos, -dir, c)
end

local function onWorldHit(p: Proj, result: RaycastResult)
	local s = p.state
	local spec = p.spec
	local n = result.Normal
	if spec.stick and not s.stuck then
		s.stuck = true
		s.pos = result.Position + n * p.radius
		s.vel = Vector3.zero
		p.armedAt = now() + spec.armTime
		syncNow(p)
		return
	end
	if p.bouncesLeft > 0 then
		p.bouncesLeft -= 1
		local v = Geometry.reflect(s.vel, n)
		if spec.gravity > 0 then
			v *= 0.72
		end
		s.vel = v
		s.pos = result.Position + n * (p.radius + 0.05)
		syncNow(p)
		if spec.trigger == "OnBounce" and p.bounceTriggers < MAX_BOUNCE_TRIGGERS then
			p.bounceTriggers += 1
			executor.castPayload(spec, p.ctx, s.pos, Geometry.safeUnit(v, n))
		end
		-- Hydra: every bounce splits off more copies, each with the bounces this one has left
		for k = 1, spec.hydra do
			if v.Magnitude < 1 or not ProjectileService.takeSplit(p.ctx) then
				break
			end
			local yaw = (if k % 2 == 1 then 1 else -1) * (18 + 10 * k)
			local d = Geometry.fan(v.Unit, yaw, seedRng:NextNumber(-6, 6))
			ProjectileService.spawn(spec, p.ctx, s.pos, d, { bouncesLeft = p.bouncesLeft, noHold = true })
		end
		return
	end
	impact(p, result.Position, n, nil)
end

local function stepProjectile(p: Proj, dt: number)
	local s = p.state
	local spec = p.spec
	local caster = p.ctx.caster
	local casterRoot = caster.root
	local casterPos: Vector3? = nil
	if casterRoot and Combatants.canAct(caster) then
		casterPos = casterRoot.Position
	end
	if s.orbit and not casterPos then
		s.orbit = false
		if s.vel.Magnitude < 1 then
			s.vel = Vector3.new(0, 0, -spec.speed)
		end
	end

	local targetPos: Vector3? = nil
	if s.homing > 0 and not s.returning and not s.stuck then
		local t = now()
		if t - p.targetTime > 0.2 then
			p.target = findTarget(p)
			p.targetTime = t
		end
		local target = p.target
		if target and Combatants.isActive(target) then
			targetPos = (target.root :: BasePart).Position
		end
	end

	local prev = s.pos
	ProjectileSim.step(s, dt, casterPos, targetPos)

	if not s.stuck then
		local newPos = s.pos
		local delta = newPos - prev
		local length = delta.Magnitude
		if length > 1e-4 then
			local hits = WorldQuery.sweep(prev, newPos, p.radius, function(c)
				return c == caster or p.hit[c] == true
			end)
			local world: RaycastResult? = nil
			if not spec.phasing and not s.orbit then
				world = WorldQuery.spherecast(prev, p.radius * 0.8, delta)
			end
			local worldT = if world then (world.Position - prev).Magnitude / length else math.huge
			for _, h in hits do
				if p.dead or h.t > worldT then
					break
				end
				onCombatantHit(p, h.c, prev:Lerp(newPos, h.t))
			end
			if not p.dead and world then
				onWorldHit(p, world)
			end
		end
	end
	if p.dead then
		return
	end

	-- boomerang caught by its thrower
	if s.returning and casterPos and (s.pos - casterPos).Magnitude < 3.5 then
		executor.onEnd(spec, p.ctx, s.pos, Geometry.safeUnit(s.vel))
		kill(p, s.pos, "fizzle")
		return
	end

	-- armed mines watch for anyone walking close
	if s.stuck and spec.proximity > 0 and p.armedAt and now() >= p.armedAt then
		for _, c in Combatants.withinRadius(s.pos, spec.proximity + 1.5, caster) do
			impact(p, s.pos, Vector3.yAxis, c)
			return
		end
	end

	-- sentries shoot at the nearest enemy they can see
	local shot = spec.turretShot
	if shot and s.age >= p.nextShot then
		p.nextShot += spec.turretRate
		local target = nearestVisible(p, spec.turretRange)
		if target then
			local d = Geometry.safeUnit(Combatants.centerOf(target) - s.pos, Vector3.new(0, 0, -1))
			ProjectileService.spawn(shot, p.ctx, s.pos + d * (p.radius + 0.6), d)
		end
	end

	-- magnetic pull and damaging auras
	if (spec.pull > 0 or spec.auraDps > 0) and s.age >= p.nextField then
		p.nextField += FIELD_TICK
		fieldTick(p)
	end

	-- proximity fuse
	if spec.trigger == "Proximity" and not p.proxFired then
		local near = nearestVisible(p, PROXIMITY_RADIUS)
		if near then
			p.proxFired = true
			local d = Geometry.safeUnit(Combatants.centerOf(near) - s.pos, Geometry.safeUnit(s.vel))
			executor.castPayload(spec, p.ctx, s.pos, d)
		end
	end

	-- timed triggers (a hovering sentry aims them at enemies)
	if spec.trigger == "Timer" and not p.timerFired and s.age >= s.hold + TIMER_DELAY then
		p.timerFired = true
		local d, at = aimDir(p, Geometry.safeUnit(s.vel))
		executor.castPayload(spec, p.ctx, s.pos, d, at)
	elseif spec.trigger == "Pulse" and s.age >= s.hold + p.nextPulse and p.pulses < MAX_PULSES then
		p.pulses += 1
		p.nextPulse += PULSE_INTERVAL
		local d, at = aimDir(p, Geometry.safeUnit(s.vel, Vector3.new(0, 0, -1)))
		executor.castPayload(spec, p.ctx, s.pos, d, at)
	end

	if s.age >= spec.lifetime then
		expire(p)
		return
	end
	if s.pos.Y < -80 or s.pos.Magnitude > 2500 then
		kill(p, s.pos, "fizzle")
		return
	end
	if p.complex and now() - p.lastSync >= SYNC_INTERVAL then
		syncNow(p)
	end
end

function ProjectileService.clear()
	for _, p in active do
		kill(p, p.state.pos, "fizzle")
	end
	table.clear(active)
end

function ProjectileService.count(): number
	return #active
end

function ProjectileService.init()
	RunService.Heartbeat:Connect(function(dt)
		if #active == 0 then
			return
		end
		WorldQuery.refresh()
		local i = 1
		-- projectiles spawned by triggers during this loop are appended and stepped next frame
		local n = #active
		while i <= n do
			local p = active[i]
			if not p.dead then
				local ok, err = pcall(stepProjectile, p, dt)
				if not ok then
					warn("[Projectile] " .. tostring(err))
					kill(p, p.state.pos, "fizzle")
				end
			end
			i += 1
		end
		-- compact
		local alive = {}
		for _, p in active do
			if not p.dead then
				table.insert(alive, p)
			end
		end
		active = alive
		if #syncBatch > 0 then
			fxSync:FireAllClients(syncBatch)
			syncBatch = {}
		end
	end)
end

return ProjectileService
