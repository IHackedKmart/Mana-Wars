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
local FX = require(script.Parent.FX)

type Spec = SpellTypes.Spec
type Combatant = Combatants.Combatant

export type CastCtx = {
	caster: Combatant,
	wandUid: string?,
	siphon: number,
	vampiric: number,
	budget: { n: number },
	aimPoint: Vector3?, -- where the caster clicked (used by Meteor)
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
}

local ProjectileService = {}

-- The executor handles everything that happens when a projectile hits or ends.
-- It is injected at startup because it also spawns projectiles (require cycle).
type Executor = {
	hitCombatant: (Spec, CastCtx, Combatant, Vector3, Vector3, number?) -> (),
	onImpact: (Spec, CastCtx, Vector3, Vector3, Vector3, Combatant?) -> (),
	onPierce: (Spec, CastCtx, Vector3, Vector3) -> (),
	onEnd: (Spec, CastCtx, Vector3, Vector3) -> (),
	explode: (Spec, CastCtx, Vector3) -> (),
	castPayload: (Spec, CastCtx, Vector3, Vector3) -> (),
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
	}
	(spec :: any)._vis = vis
	return vis
end

export type SpawnOptions = { orbitAngle: number? }

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
		bouncesLeft = spec.bounces,
		timerFired = false,
		nextPulse = PULSE_INTERVAL,
		pulses = 0,
		armedAt = nil,
		dead = false,
		complex = spec.homing > 0 or spec.orbit or spec.boomerangAt > 0 or spec.erratic > 0 or spec.accelerate > 0,
		lastSync = now(),
		target = nil,
		targetTime = 0,
	}
	table.insert(active, p)
	FX.all("P+", p.id, origin, state.vel, seed, orbitAngle, ctx.caster.model, visualOf(spec))
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
	executor.onEnd(p.spec, p.ctx, pos, dir)
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
	-- bombs, mines and flasks burst on contact with a body
	if spec.directMult == 0 and (spec.explodeRadius > 0 or spec.zoneOnImpact) then
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
	if casterRoot and casterRoot.Parent and caster.alive then
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

	-- timed triggers
	if spec.trigger == "Timer" and not p.timerFired and s.age >= TIMER_DELAY then
		p.timerFired = true
		executor.castPayload(spec, p.ctx, s.pos, Geometry.safeUnit(s.vel))
	elseif spec.trigger == "Pulse" and s.age >= p.nextPulse and p.pulses < MAX_PULSES then
		p.pulses += 1
		p.nextPulse += PULSE_INTERVAL
		executor.castPayload(spec, p.ctx, s.pos, Geometry.safeUnit(s.vel, Vector3.new(0, 0, -1)))
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
