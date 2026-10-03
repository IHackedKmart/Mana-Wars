-- Executes compiled spells: spawns projectiles, fires beams, novas, chains, meteors,
-- blinks, shields and walls, and resolves everything that happens on impact
-- (explosions, zones, vortexes, shards, lightning arcs, swaps, rewinds, fractal splits
-- and trigger payloads).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Geometry = require(Shared.Util.Geometry)
local SpellTypes = require(Shared.Spells.SpellTypes)
local Combatants = require(script.Parent.Combatants)
local WorldQuery = require(script.Parent.WorldQuery)
local DamageService = require(script.Parent.DamageService)
local StatusService = require(script.Parent.StatusService)
local ProjectileService = require(script.Parent.ProjectileService)
local ZoneService = require(script.Parent.ZoneService)
local FX = require(script.Parent.FX)

type Spec = SpellTypes.Spec
type Combatant = Combatants.Combatant
type CastCtx = ProjectileService.CastCtx

local SpellExecutor = {}

local rng = Random.new()
local ECHO_DELAY = 0.3
local MAX_TRIGGERS_PER_EVENT = 4
local ARC_RANGE = 18
local SKYFALL_RANGE = 160
local SKYFALL_HEIGHT = 55

-- Chaos spells roll one of these on every hit.
local CHAOS_STATUSES: { SpellTypes.StatusDef } = {
	{ kind = "Burn", dps = 5, duration = 3 },
	{ kind = "Chill", slow = 0.35, duration = 2.5, maxStacks = 3 },
	{ kind = "Venom", dps = 2, duration = 6, maxStacks = 5 },
}

local function now(): number
	return workspace:GetServerTimeNow()
end

local castPayloadRef: (Spec, CastCtx, Vector3, Vector3, Vector3?) -> ()

---------------------------------------------------------------------------
-- Damage helpers
---------------------------------------------------------------------------

local function arcFrom(spec: Spec, ctx: CastCtx, from: Combatant, pos: Vector3, damage: number)
	local skip: { [Combatant]: boolean } = { [from] = true, [ctx.caster] = true }
	local points = { pos }
	for _ = 1, spec.arc do
		local nextC = Combatants.nearest(pos, ARC_RANGE, skip)
		if not nextC then
			break
		end
		skip[nextC] = true
		local p = Combatants.centerOf(nextC)
		table.insert(points, p)
		DamageService.apply(nextC, damage, {
			attacker = ctx.caster,
			element = spec.element,
			crit = spec.crit,
			lifesteal = spec.lifesteal + ctx.vampiric,
			spellName = spec.name,
			hitPos = p,
		})
		pos = p
	end
	if #points > 1 then
		FX.all("Chain", points, spec.color, spec.color2, 0.25, spec.element)
	end
end

-- Transpose: the caster and the target trade places.
local function swapPlaces(spec: Spec, caster: Combatant, target: Combatant)
	local t = now()
	if t - caster.lastSwap < 0.4 or target.isDummy or not Combatants.canAct(caster) then
		return
	end
	local a, b = caster.root, target.root
	local casterModel, targetModel = caster.model, target.model
	if not a or not b or not casterModel or not targetModel then
		return
	end
	caster.lastSwap = t
	local from, to = a.CFrame, b.CFrame
	casterModel:PivotTo(to + Vector3.new(0, 0.5, 0))
	targetModel:PivotTo(from + Vector3.new(0, 0.5, 0))
	FX.all("Blink", from.Position, to.Position, spec.color, spec.color2, spec.element)
	FX.all("Blink", to.Position, from.Position, spec.color2, spec.color, spec.element)
end

-- Chrono: send the target back to where they stood a moment ago.
local function rewind(spec: Spec, target: Combatant)
	local t = now()
	if t - target.lastRewind < 1.5 or target.isDummy or not target.model or not target.root then
		return
	end
	local cf = Combatants.cframeAgo(target, spec.rewind, t)
	if not cf then
		return
	end
	target.lastRewind = t
	local from = (target.root :: BasePart).Position;
	(target.model :: Model):PivotTo(cf)
	FX.all("Blink", from, cf.Position, spec.color, spec.color2, spec.element)
end

-- Everything a hit does besides damage: kill triggers, rewinds and swaps.
local function afterHit(
	spec: Spec,
	ctx: CastCtx,
	target: Combatant,
	pos: Vector3,
	dir: Vector3,
	killed: boolean,
	direct: boolean
)
	if killed then
		if spec.trigger == "OnKill" then
			castPayloadRef(spec, ctx, pos, dir)
		end
		return
	end
	if not DamageService.canHurt(target, ctx.caster) then
		return
	end
	if spec.rewind > 0 then
		rewind(spec, target)
	end
	if spec.swap and direct then
		swapPlaces(spec, ctx.caster, target)
	end
end

local function chaosRoll(spec: Spec): (number, SpellTypes.StatusDef?)
	if not spec.chaos then
		return 1, spec.status
	end
	return rng:NextNumber(0.25, 2.5), CHAOS_STATUSES[rng:NextInteger(1, #CHAOS_STATUSES)]
end

function SpellExecutor.hitCombatant(
	spec: Spec,
	ctx: CastCtx,
	target: Combatant,
	pos: Vector3,
	dir: Vector3,
	mult: number?
)
	local damage = spec.damage * spec.directMult * (mult or 1)
	if damage <= 0 and spec.directMult <= 0 then
		return
	end
	local roll, status = chaosRoll(spec)
	damage *= roll
	local _, killed = DamageService.apply(target, damage, {
		attacker = ctx.caster,
		element = spec.element,
		crit = spec.crit,
		knockDir = dir,
		knockback = spec.knockback,
		lift = spec.lift,
		lifesteal = spec.lifesteal + ctx.vampiric,
		siphon = ctx.siphon,
		wandUid = ctx.wandUid,
		status = status,
		mark = spec.mark,
		spellName = spec.name,
		hitPos = pos,
	})
	if spec.arc > 0 then
		arcFrom(spec, ctx, target, pos, damage * 0.5)
	end
	afterHit(spec, ctx, target, pos, dir, killed, true)
end

function SpellExecutor.explode(spec: Spec, ctx: CastCtx, pos: Vector3)
	local radius = spec.explodeRadius
	local damage = spec.damage * math.max(spec.explodeMult, 0.0001)
	FX.all("Boom", pos, radius, spec.color, spec.color2, spec.element)
	for _, c in Combatants.active() do
		local center = Combatants.centerOf(c)
		local dist = (center - pos).Magnitude
		if dist <= radius + 1.5 then
			local falloff = 1 - 0.5 * math.clamp(dist / math.max(radius, 1), 0, 1)
			local away = Geometry.safeUnit(center - pos + Vector3.new(0, 1, 0), Vector3.yAxis)
			local roll, status = chaosRoll(spec)
			local _, killed = DamageService.apply(c, damage * falloff * roll, {
				attacker = ctx.caster,
				element = spec.element,
				crit = spec.crit,
				knockDir = away,
				knockback = spec.knockback * 1.1 + 10,
				lift = spec.lift + 18,
				lifesteal = spec.lifesteal + ctx.vampiric,
				status = status,
				mark = spec.mark,
				spellName = spec.name,
				hitPos = center,
			})
			afterHit(spec, ctx, c, center, away, killed, false)
		end
	end
end

local function vortex(spec: Spec, ctx: CastCtx, pos: Vector3)
	FX.all("Vortex", pos, 16, spec.color, spec.color2, spec.element)
	for _, c in Combatants.withinRadius(pos, 16, ctx.caster) do
		if not DamageService.canHurt(c, ctx.caster) then
			continue
		end
		local to = pos - Combatants.centerOf(c)
		local flat = Vector3.new(to.X, 0, to.Z)
		if flat.Magnitude > 1 then
			DamageService.knock(c, flat.Unit * spec.vortex + Vector3.new(0, 12, 0))
		end
	end
end

local function shards(spec: Spec, ctx: CastCtx, pos: Vector3, normal: Vector3, dir: Vector3, hitBody: boolean)
	local shard = spec.shard
	if not shard or spec.shatter <= 0 then
		return
	end
	local base = if hitBody then dir else Geometry.reflect(dir, normal)
	local n = spec.shatter
	for i = 1, n do
		local yaw = if n > 1 then -35 + 70 * (i - 1) / (n - 1) else 0
		local d = Geometry.fan(base, yaw, rng:NextNumber(-8, 8))
		ProjectileService.spawn(shard, ctx, pos + normal * 0.6, d)
	end
end

---------------------------------------------------------------------------
-- Trigger plumbing
---------------------------------------------------------------------------

-- `aimAt` (optional): a target point for payloads that land somewhere (Meteor, Rampart).
function SpellExecutor.castPayload(spec: Spec, ctx: CastCtx, pos: Vector3, dir: Vector3, aimAt: Vector3?)
	local payload = spec.payload
	if not payload or ctx.budget.n <= 0 then
		return
	end
	ctx.budget.n -= 1
	SpellExecutor.cast(payload, ctx, pos, Geometry.safeUnit(dir), false, aimAt)
end
castPayloadRef = SpellExecutor.castPayload

-- Fractal: when a spell ends it splits into three smaller copies of itself (bouncing off
-- whatever it hit), which may split again.
local function splitFractal(spec: Spec, ctx: CastCtx, pos: Vector3, dir: Vector3, normal: Vector3?)
	local child = spec.fractalChild
	if not child then
		return
	end
	local base = Geometry.safeUnit(if normal then Geometry.reflect(dir, normal) else dir, Vector3.new(0, 0, -1))
	local start = pos + (normal or Vector3.zero) * 0.8
	local reach = if child.kind == "Nova" then child.radius * 0.9 elseif child.kind == "Meteor" then 8 else 0
	for i = 1, 3 do
		if not ProjectileService.takeSplit(ctx) then
			break
		end
		local d = Geometry.fan(base, -40 + 40 * (i - 1), rng:NextNumber(-5, 20))
		SpellExecutor.cast(child, ctx, start + Geometry.flat(d) * reach, d, false)
	end
end

-- Anything ending on impact: explosion, zone, vortex, shards, OnHit trigger.
function SpellExecutor.onImpact(spec: Spec, ctx: CastCtx, pos: Vector3, normal: Vector3, dir: Vector3, hitC: Combatant?)
	if spec.explodeRadius > 0 and spec.explodeMult > 0 then
		SpellExecutor.explode(spec, ctx, pos + normal * 0.3)
	end
	if spec.zoneOnImpact then
		ZoneService.create(spec, ctx.caster, pos)
	end
	if spec.vortex > 0 then
		vortex(spec, ctx, pos)
	end
	if spec.shard then
		shards(spec, ctx, pos, normal, dir, hitC ~= nil)
	end
	if spec.trigger == "OnHit" then
		local outDir = if hitC then dir else Geometry.reflect(dir, normal)
		SpellExecutor.castPayload(spec, ctx, pos + normal * 0.6, outDir)
	end
end

function SpellExecutor.onPierce(spec: Spec, ctx: CastCtx, pos: Vector3, dir: Vector3)
	if spec.trigger == "OnHit" then
		SpellExecutor.castPayload(spec, ctx, pos, dir)
	end
end

-- `normal` is set when the spell ended by hitting the world (Fractal copies bounce off it).
function SpellExecutor.onEnd(spec: Spec, ctx: CastCtx, pos: Vector3, dir: Vector3, normal: Vector3?)
	if spec.trigger == "OnExpire" then
		SpellExecutor.castPayload(spec, ctx, pos, dir)
	end
	splitFractal(spec, ctx, pos, dir, normal)
end

function SpellExecutor.zoneAt(spec: Spec, ctx: CastCtx, pos: Vector3)
	ZoneService.create(spec, ctx.caster, pos)
end

-- For forms that resolve instantly, Timer/Pulse/OnExpire all fire at the end point.
local function instantEndTriggers(spec: Spec, ctx: CastCtx, pos: Vector3, dir: Vector3, normal: Vector3?)
	if spec.trigger == "OnExpire" or spec.trigger == "Timer" or spec.trigger == "Pulse" then
		SpellExecutor.castPayload(spec, ctx, pos, dir)
	end
	splitFractal(spec, ctx, pos, dir, normal)
end

---------------------------------------------------------------------------
-- Forms
---------------------------------------------------------------------------

local function doBeam(spec: Spec, ctx: CastCtx, origin: Vector3, dir: Vector3, range: number?, bounces: number?)
	local remaining = range or spec.range
	local pos = origin
	local d = dir
	local pierceLeft = spec.pierce
	local bouncesLeft = bounces or spec.bounces
	local hitSet: { [Combatant]: boolean } = {}
	local points = { origin }
	local triggers = 0
	local radius = math.max(0.3, spec.size * 0.5)
	local endPos = origin
	local endNormal = -dir
	local worldNormal: Vector3? = nil -- set when the beam ends on a wall (Fractal bounces off it)
	local stopped = false

	for _ = 1, 12 do
		if remaining <= 0.5 then
			break
		end
		local delta = d * remaining
		local world = if spec.phasing then nil else WorldQuery.raycast(pos, delta)
		local segEnd = if world then world.Position else pos + delta
		local hits = WorldQuery.sweep(pos, segEnd, radius, function(c)
			return c == ctx.caster or hitSet[c] == true
		end)
		for _, h in hits do
			local hitPos = pos:Lerp(segEnd, h.t)
			hitSet[h.c] = true
			SpellExecutor.hitCombatant(spec, ctx, h.c, hitPos, d, nil)
			if spec.trigger == "OnHit" and triggers < MAX_TRIGGERS_PER_EVENT then
				triggers += 1
				SpellExecutor.castPayload(spec, ctx, hitPos, d)
			end
			if pierceLeft > 0 then
				pierceLeft -= 1
			else
				endPos = hitPos
				endNormal = -d
				stopped = true
				break
			end
		end
		if stopped then
			table.insert(points, endPos)
			SpellExecutor.onImpact(spec, ctx, endPos, endNormal, d, nil)
			break
		end
		table.insert(points, segEnd)
		remaining -= (segEnd - pos).Magnitude
		endPos = segEnd
		if world then
			if bouncesLeft > 0 then
				bouncesLeft -= 1
				d = Geometry.reflect(d, world.Normal)
				pos = world.Position + world.Normal * 0.1
				if spec.trigger == "OnBounce" and triggers < MAX_TRIGGERS_PER_EVENT * 2 then
					triggers += 1
					SpellExecutor.castPayload(spec, ctx, pos, d)
				end
				-- Hydra beams branch at every reflection
				for k = 1, spec.hydra do
					if not ProjectileService.takeSplit(ctx) then
						break
					end
					local branch = Geometry.fan(d, (if k % 2 == 1 then 1 else -1) * (20 + 8 * k), 0)
					task.defer(doBeam, spec, ctx, pos, branch, remaining, bouncesLeft)
				end
			else
				endNormal = world.Normal
				worldNormal = world.Normal
				SpellExecutor.onImpact(spec, ctx, world.Position, world.Normal, d, nil)
				break
			end
		else
			break
		end
	end
	FX.all("Beam", points, spec.color, spec.color2, spec.size, spec.element)
	instantEndTriggers(spec, ctx, endPos + endNormal * 0.5, d, worldNormal)
end

local function doNova(spec: Spec, ctx: CastCtx, center: Vector3, dir: Vector3)
	FX.all("Nova", center, spec.radius, spec.color, spec.color2, spec.element)
	local triggers = 0
	for _, c in Combatants.withinRadius(center, spec.radius + 1.5, ctx.caster) do
		local p = Combatants.centerOf(c)
		local away = Geometry.safeUnit(p - center, dir)
		SpellExecutor.hitCombatant(spec, ctx, c, p, away, nil)
		if spec.trigger == "OnHit" and triggers < MAX_TRIGGERS_PER_EVENT then
			triggers += 1
			SpellExecutor.castPayload(spec, ctx, p, away)
		end
	end
	if spec.explodeRadius > 0 and spec.explodeMult > 0 then
		SpellExecutor.explode(spec, ctx, center)
	end
	if spec.zoneOnImpact then
		ZoneService.create(spec, ctx.caster, center)
	end
	if spec.vortex > 0 then
		vortex(spec, ctx, center)
	end
	if spec.shard then
		shards(spec, ctx, center, Vector3.yAxis, dir, true)
	end
	instantEndTriggers(spec, ctx, center, dir)
end

local function doChain(spec: Spec, ctx: CastCtx, origin: Vector3, dir: Vector3, firstTaken: { [Combatant]: boolean })
	local first: Combatant? = nil
	local bestScore = math.huge
	for _, c in Combatants.active() do
		if c ~= ctx.caster and not firstTaken[c] then
			local to = Combatants.centerOf(c) - origin
			local dist = to.Magnitude
			if dist > 0.1 and dist <= spec.range then
				local dot = to.Unit:Dot(dir)
				if dot > 0.55 and (spec.phasing or WorldQuery.lineOfSight(origin, Combatants.centerOf(c))) then
					local score = dist * (2 - dot)
					if score < bestScore then
						first, bestScore = c, score
					end
				end
			end
		end
	end

	if not first then
		local reach = spec.range * 0.45
		local world = WorldQuery.raycast(origin, dir * reach)
		local stop = if world then world.Position else origin + dir * reach
		FX.all("Chain", { origin, stop }, spec.color, spec.color2, 0.15, spec.element)
		instantEndTriggers(spec, ctx, stop, dir)
		return
	end
	firstTaken[first] = true

	local hitSet: { [Combatant]: boolean } = { [ctx.caster] = true }
	local points = { origin }
	local current: Combatant? = first
	local jumps = spec.chainJumps
	local mult = 1
	local triggers = 0
	local lastPos = origin
	local lastDir = dir
	while current do
		hitSet[current] = true
		local p = Combatants.centerOf(current)
		lastDir = Geometry.safeUnit(p - lastPos, dir)
		lastPos = p
		table.insert(points, p)
		SpellExecutor.hitCombatant(spec, ctx, current, p, lastDir, mult)
		if spec.explodeRadius > 0 and spec.explodeMult > 0 then
			SpellExecutor.explode(spec, ctx, p)
		end
		if spec.trigger == "OnHit" and triggers < MAX_TRIGGERS_PER_EVENT then
			triggers += 1
			SpellExecutor.castPayload(spec, ctx, p, lastDir)
		end
		if jumps <= 0 then
			break
		end
		jumps -= 1
		mult *= 0.85
		local nextC = Combatants.nearest(p, spec.chainRange, hitSet)
		if nextC and not spec.phasing and not WorldQuery.lineOfSight(p, Combatants.centerOf(nextC)) then
			nextC = nil
		end
		current = nextC
	end
	FX.all("Chain", points, spec.color, spec.color2, spec.size, spec.element)
	if spec.zoneOnImpact then
		ZoneService.create(spec, ctx.caster, lastPos)
	end
	if spec.vortex > 0 then
		vortex(spec, ctx, lastPos)
	end
	instantEndTriggers(spec, ctx, lastPos, lastDir)
end

local function doMeteor(
	spec: Spec,
	ctx: CastCtx,
	origin: Vector3,
	_dir: Vector3,
	index: number,
	count: number,
	fromCaster: boolean?,
	aimAt: Vector3?
)
	-- Cast from a wand: land on the spot the caster clicked (world raycasts ignore bodies,
	-- so a ray "through" an enemy would otherwise land far behind them).
	-- Cast by a trigger: fall straight down onto the trigger point.
	local target: Vector3
	if fromCaster and ctx.aimPoint then
		local aim = ctx.aimPoint :: Vector3
		local offset = aim - origin
		if offset.Magnitude > spec.range then
			aim = origin + offset.Unit * spec.range
		end
		local blocked = WorldQuery.raycast(origin, aim - origin)
		target = if blocked then blocked.Position else aim
		target = WorldQuery.groundBelow(target + Vector3.new(0, 2, 0), 250) or target
	elseif aimAt then
		-- aimed by a sentry: land on its target
		target = WorldQuery.groundBelow(aimAt + Vector3.new(0, 2, 0), 250) or aimAt
	else
		target = WorldQuery.groundBelow(origin + Vector3.new(0, 2, 0), 250) or origin
	end
	if count > 1 then
		local angle = (index / count) * math.pi * 2
		target += Vector3.new(math.cos(angle), 0, math.sin(angle)) * 8
	end
	local start = target + Vector3.new(rng:NextNumber(-14, 14), spec.meteorHeight, rng:NextNumber(-14, 14))
	FX.all("Warn", target, math.max(spec.explodeRadius, 4), spec.color)
	ProjectileService.spawn(spec, ctx, start, Geometry.safeUnit(target - start, -Vector3.yAxis))
end

local function doBlink(spec: Spec, ctx: CastCtx, origin: Vector3, dir: Vector3, toPoint: Vector3?)
	local caster = ctx.caster
	if not Combatants.canAct(caster) or not caster.model then
		return
	end
	local root = caster.root :: BasePart
	local start = root.Position
	local dest: Vector3
	if toPoint then
		-- Skyfall blink: land on the aim point
		dest = toPoint + Vector3.new(0, 3.2, 0)
	elseif spec.depth > 1 then
		-- cast by a trigger: teleport to where the parent spell was
		dest = origin + Vector3.new(0, 2.5, 0)
	else
		local reach = spec.blinkDistance
		local world = WorldQuery.raycast(start, dir * reach)
		if world then
			dest = world.Position - dir * 2.5 + world.Normal * 1.5
		else
			dest = start + dir * reach
		end
	end
	local ground = WorldQuery.groundBelow(dest + Vector3.new(0, 1, 0), 4)
	if ground then
		dest = ground + Vector3.new(0, 3.2, 0)
	end
	local flat = Geometry.flat(dir)
	local look = if flat.Magnitude > 1e-3 then flat.Unit else root.CFrame.LookVector;
	(caster.model :: Model):PivotTo(CFrame.lookAt(dest, dest + look))
	FX.all("Blink", start, dest, spec.color, spec.color2, spec.element)
	SpellExecutor.onImpact(spec, ctx, dest, Vector3.yAxis, dir, nil)
	SpellExecutor.onEnd(spec, ctx, dest, dir)
	if spec.trigger == "Timer" or spec.trigger == "Pulse" then
		SpellExecutor.castPayload(spec, ctx, dest, dir)
	end
end

local function doAegis(spec: Spec, ctx: CastCtx)
	local caster = ctx.caster
	if not Combatants.canAct(caster) then
		return
	end
	StatusService.addShield(caster, spec.shieldAmount, spec.shieldDuration, {
		color = spec.color,
		thorns = spec.status,
		onEnd = function(pos: Vector3, look: Vector3)
			if spec.trigger and spec.payload and Combatants.canAct(caster) then
				SpellExecutor.castPayload(spec, ctx, pos, look)
			end
		end,
	})
	FX.all("Shield", caster.model, spec.color)
end

-- Rampart: a solid wall rises on the aim point (or where a trigger fired it), facing the caster.
local function doWall(
	spec: Spec,
	ctx: CastCtx,
	origin: Vector3,
	dir: Vector3,
	fromCaster: boolean?,
	index: number,
	count: number,
	aimAt: Vector3?
)
	local casterPos = if ctx.caster.root then (ctx.caster.root :: BasePart).Position else origin
	local ground: Vector3
	local facing: Vector3
	if fromCaster and ctx.aimPoint then
		local aim = ctx.aimPoint :: Vector3
		local offset = aim - casterPos
		if offset.Magnitude > spec.range then
			aim = casterPos + offset.Unit * spec.range
		end
		ground = WorldQuery.groundBelow(aim + Vector3.new(0, 3, 0), 80) or aim
		facing = Geometry.flat(ground - casterPos)
	elseif aimAt then
		ground = WorldQuery.groundBelow(aimAt + Vector3.new(0, 3, 0), 80) or aimAt
		facing = Geometry.flat(ground - origin)
	else
		ground = WorldQuery.groundBelow(origin + Vector3.new(0, 2, 0), 40) or origin
		facing = Geometry.flat(dir)
	end
	facing = if facing.Magnitude > 1e-3 then facing.Unit else Vector3.new(0, 0, -1)
	if count > 1 then
		local right = facing:Cross(Vector3.yAxis)
		ground += right * (index - (count + 1) / 2) * spec.wallWidth * 1.02
	end
	-- shove anyone standing where the wall rises
	for _, c in Combatants.withinRadius(ground, spec.wallWidth / 2 + 2, ctx.caster) do
		local along = (Combatants.centerOf(c) - ground):Dot(facing)
		if math.abs(along) < 3 and DamageService.canHurt(c, ctx.caster) then
			local side = if along >= 0 then 1 else -1
			DamageService.knock(c, facing * side * (spec.knockback + 20) + Vector3.new(0, 25, 0))
		end
	end
	ZoneService.createWall(spec, ground, facing, function(center: Vector3)
		instantEndTriggers(spec, ctx, center, facing, nil)
	end)
	FX.all(
		"Nova",
		ground + Vector3.new(0, 0.5, 0),
		math.min(spec.wallWidth * 0.6, 16),
		spec.color,
		spec.color2,
		spec.element
	)
	SpellExecutor.onImpact(spec, ctx, ground + Vector3.new(0, 0.5, 0), Vector3.yAxis, facing, nil)
end

-- Skyfall: where on the ground the spell comes down (the aim point, within range).
local function skyTarget(ctx: CastCtx, origin: Vector3): Vector3?
	local aim = ctx.aimPoint
	if not aim then
		return nil
	end
	local from = if ctx.caster.root then (ctx.caster.root :: BasePart).Position else origin
	local offset = aim - from
	if offset.Magnitude > SKYFALL_RANGE then
		aim = from + offset.Unit * SKYFALL_RANGE
	end
	return WorldQuery.groundBelow(aim + Vector3.new(0, 3, 0), 250) or aim
end

local function castFromSky(spec: Spec, ctx: CastCtx, ground: Vector3, dir: Vector3, count: number)
	local kind = spec.kind
	FX.all("Warn", ground, math.max(spec.explodeRadius, spec.radius, 4), spec.color)
	local function spot(i: number): Vector3
		if count <= 1 then
			return ground
		end
		local angle = (i / count) * math.pi * 2
		local r = 3 + count * 0.6
		return ground + Vector3.new(math.cos(angle) * r, 0, math.sin(angle) * r)
	end
	if kind == "Projectile" then
		for i = 1, count do
			local target = spot(i)
			local start = target + Vector3.new(rng:NextNumber(-6, 6), SKYFALL_HEIGHT, rng:NextNumber(-6, 6))
			ProjectileService.spawn(spec, ctx, start, Geometry.safeUnit(target - start, -Vector3.yAxis))
		end
	elseif kind == "Beam" then
		for i = 1, count do
			doBeam(spec, ctx, spot(i) + Vector3.new(0, 80, 0), -Vector3.yAxis, 90, nil)
		end
	elseif kind == "Nova" then
		for i = 1, count do
			task.delay((i - 1) * 0.12, doNova, spec, ctx, spot(i) + Vector3.new(0, 1.5, 0), dir)
		end
	elseif kind == "Chain" then
		local taken: { [Combatant]: boolean } = {}
		for i = 1, count do
			doChain(spec, ctx, spot(i) + Vector3.new(0, 30, 0), -Vector3.yAxis, taken)
		end
	elseif kind == "Blink" then
		doBlink(spec, ctx, ground, dir, ground)
	end
end

local function echoless(spec: Spec): Spec
	local cached = (spec :: any)._echoless
	if cached then
		return cached
	end
	local copy = table.clone(spec)
	copy.echo = 0
	(spec :: any)._echoless = copy
	return copy
end

local function holdless(spec: Spec): Spec
	local cached = (spec :: any)._holdless
	if cached then
		return cached
	end
	local copy = table.clone(spec)
	copy.hold = 0
	(spec :: any)._holdless = copy
	return copy
end

-- Where a re-cast from the wand starts (for echoes and delayed instant spells).
local function wandOrigin(ctx: CastCtx, dir: Vector3, fallback: Vector3): Vector3
	local model = ctx.caster.model
	local head = model and model:FindFirstChild("Head") :: BasePart?
	return if head then head.Position + dir * 2.2 else fallback
end

-- Casts a compiled spell. `fromCaster` is true for spells cast straight from a wand.
-- `aimAt` is an optional target point for payloads fired by a sentry.
function SpellExecutor.cast(
	spec: Spec,
	ctx: CastCtx,
	origin: Vector3,
	dir: Vector3,
	fromCaster: boolean?,
	aimAt: Vector3?
)
	local kind = spec.kind
	-- Stasis on an instant spell: it simply goes off later
	local delayed = spec.hold > 0 and kind ~= "Projectile" and kind ~= "Meteor"
	if delayed then
		local later = holdless(spec)
		task.delay(spec.hold, function()
			if Combatants.canAct(ctx.caster) then
				local o = if fromCaster then wandOrigin(ctx, dir, origin) else origin
				SpellExecutor.cast(later, ctx, o, dir, fromCaster, aimAt)
			end
		end)
		return
	end
	local count = if kind == "Blink" or kind == "Aegis" then 1 else spec.count
	local sky = if spec.skyfall
			and fromCaster
			and not spec.orbit
			and (kind == "Projectile" or kind == "Beam" or kind == "Nova" or kind == "Chain" or kind == "Blink")
		then skyTarget(ctx, origin)
		else nil
	local dirs: { Vector3 } = {}
	if count <= 1 then
		dirs[1] = dir
	else
		local spread = math.max(spec.spread, 6)
		for i = 1, count do
			local yaw = -spread / 2 + spread * (i - 1) / (count - 1)
			dirs[i] = Geometry.fan(dir, yaw, 0)
		end
	end

	if sky then
		castFromSky(spec, ctx, sky, dir, count)
	elseif kind == "Projectile" then
		local baseAngle = math.atan2(dir.Z, dir.X)
		for i, d in dirs do
			ProjectileService.spawn(spec, ctx, origin, d, {
				orbitAngle = if spec.orbit then baseAngle + (i - 1) * (math.pi * 2 / count) else nil,
			})
		end
	elseif kind == "Beam" then
		for _, d in dirs do
			doBeam(spec, ctx, origin, d)
		end
	elseif kind == "Nova" then
		local center = origin
		if fromCaster and ctx.caster.root then
			center = (ctx.caster.root :: BasePart).Position
		end
		for i = 1, count do
			if i == 1 then
				doNova(spec, ctx, center, dir)
			else
				task.delay((i - 1) * 0.12, doNova, spec, ctx, center, dir)
			end
		end
	elseif kind == "Chain" then
		local taken: { [Combatant]: boolean } = {}
		for _, d in dirs do
			doChain(spec, ctx, origin, d, taken)
		end
	elseif kind == "Meteor" then
		for i, d in dirs do
			doMeteor(spec, ctx, origin, d, i, count, fromCaster, aimAt)
		end
	elseif kind == "Blink" then
		doBlink(spec, ctx, origin, dir, nil)
	elseif kind == "Aegis" then
		doAegis(spec, ctx)
	elseif kind == "Wall" then
		for i = 1, count do
			doWall(spec, ctx, origin, dir, fromCaster, i, count, aimAt)
		end
	end

	if spec.echo > 0 then
		local again = echoless(spec)
		for e = 1, spec.echo do
			task.delay(ECHO_DELAY * e, function()
				if not Combatants.canAct(ctx.caster) then
					return
				end
				local o = if fromCaster then wandOrigin(ctx, dir, origin) else origin
				SpellExecutor.cast(again, ctx, o, dir, fromCaster)
			end)
		end
	end
end

function SpellExecutor.init()
	ProjectileService.setExecutor(SpellExecutor :: any)
end

return SpellExecutor
