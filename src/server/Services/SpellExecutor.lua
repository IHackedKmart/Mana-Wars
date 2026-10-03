-- Executes compiled spells: spawns projectiles, fires beams, novas, chains, meteors,
-- blinks and shields, and resolves everything that happens on impact
-- (explosions, zones, vortexes, shards, lightning arcs and trigger payloads).

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
		FX.all("Chain", points, spec.color, spec.color2, 0.25)
	end
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
	DamageService.apply(target, damage, {
		attacker = ctx.caster,
		element = spec.element,
		crit = spec.crit,
		knockDir = dir,
		knockback = spec.knockback,
		lift = spec.lift,
		lifesteal = spec.lifesteal + ctx.vampiric,
		siphon = ctx.siphon,
		wandUid = ctx.wandUid,
		status = spec.status,
		mark = spec.mark,
		spellName = spec.name,
		hitPos = pos,
	})
	if spec.arc > 0 then
		arcFrom(spec, ctx, target, pos, damage * 0.5)
	end
end

function SpellExecutor.explode(spec: Spec, ctx: CastCtx, pos: Vector3)
	local radius = spec.explodeRadius
	local damage = spec.damage * math.max(spec.explodeMult, 0.0001)
	FX.all("Boom", pos, radius, spec.color, spec.color2)
	for _, c in Combatants.active() do
		local center = Combatants.centerOf(c)
		local dist = (center - pos).Magnitude
		if dist <= radius + 1.5 then
			local falloff = 1 - 0.5 * math.clamp(dist / math.max(radius, 1), 0, 1)
			local away = Geometry.safeUnit(center - pos + Vector3.new(0, 1, 0), Vector3.yAxis)
			DamageService.apply(c, damage * falloff, {
				attacker = ctx.caster,
				element = spec.element,
				crit = spec.crit,
				knockDir = away,
				knockback = spec.knockback * 1.1 + 10,
				lift = spec.lift + 18,
				lifesteal = spec.lifesteal + ctx.vampiric,
				status = spec.status,
				mark = spec.mark,
				spellName = spec.name,
				hitPos = center,
			})
		end
	end
end

local function vortex(spec: Spec, ctx: CastCtx, pos: Vector3)
	FX.all("Vortex", pos, 16, spec.color, spec.color2)
	for _, c in Combatants.withinRadius(pos, 16, ctx.caster) do
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

function SpellExecutor.castPayload(spec: Spec, ctx: CastCtx, pos: Vector3, dir: Vector3)
	local payload = spec.payload
	if not payload or ctx.budget.n <= 0 then
		return
	end
	ctx.budget.n -= 1
	SpellExecutor.cast(payload, ctx, pos, Geometry.safeUnit(dir), false)
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

function SpellExecutor.onEnd(spec: Spec, ctx: CastCtx, pos: Vector3, dir: Vector3)
	if spec.trigger == "OnExpire" then
		SpellExecutor.castPayload(spec, ctx, pos, dir)
	end
end

function SpellExecutor.zoneAt(spec: Spec, ctx: CastCtx, pos: Vector3)
	ZoneService.create(spec, ctx.caster, pos)
end

-- For forms that resolve instantly, Timer/Pulse/OnExpire all fire at the end point.
local function instantEndTriggers(spec: Spec, ctx: CastCtx, pos: Vector3, dir: Vector3)
	if spec.trigger == "OnExpire" or spec.trigger == "Timer" or spec.trigger == "Pulse" then
		SpellExecutor.castPayload(spec, ctx, pos, dir)
	end
end

---------------------------------------------------------------------------
-- Forms
---------------------------------------------------------------------------

local function doBeam(spec: Spec, ctx: CastCtx, origin: Vector3, dir: Vector3)
	local remaining = spec.range
	local pos = origin
	local d = dir
	local pierceLeft = spec.pierce
	local bouncesLeft = spec.bounces
	local hitSet: { [Combatant]: boolean } = {}
	local points = { origin }
	local triggers = 0
	local radius = math.max(0.3, spec.size * 0.5)
	local endPos = origin
	local endNormal = -dir
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
			else
				endNormal = world.Normal
				SpellExecutor.onImpact(spec, ctx, world.Position, world.Normal, d, nil)
				break
			end
		else
			break
		end
	end
	FX.all("Beam", points, spec.color, spec.color2, spec.size)
	instantEndTriggers(spec, ctx, endPos + endNormal * 0.5, d)
end

local function doNova(spec: Spec, ctx: CastCtx, center: Vector3, dir: Vector3)
	FX.all("Nova", center, spec.radius, spec.color, spec.color2)
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
		FX.all("Chain", { origin, stop }, spec.color, spec.color2, 0.15)
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
	FX.all("Chain", points, spec.color, spec.color2, spec.size)
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
	dir: Vector3,
	index: number,
	count: number,
	fromCaster: boolean?
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

local function doBlink(spec: Spec, ctx: CastCtx, origin: Vector3, dir: Vector3)
	local caster = ctx.caster
	if not Combatants.isActive(caster) or not caster.model then
		return
	end
	local root = caster.root :: BasePart
	local start = root.Position
	local dest: Vector3
	if spec.depth > 1 then
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
	FX.all("Blink", start, dest, spec.color, spec.color2)
	SpellExecutor.onImpact(spec, ctx, dest, Vector3.yAxis, dir, nil)
	SpellExecutor.onEnd(spec, ctx, dest, dir)
	if spec.trigger == "Timer" or spec.trigger == "Pulse" then
		SpellExecutor.castPayload(spec, ctx, dest, dir)
	end
end

local function doAegis(spec: Spec, ctx: CastCtx)
	local caster = ctx.caster
	if not Combatants.isActive(caster) then
		return
	end
	StatusService.addShield(caster, spec.shieldAmount, spec.shieldDuration, {
		color = spec.color,
		thorns = spec.status,
		onEnd = function(pos: Vector3, look: Vector3)
			if spec.trigger and spec.payload and Combatants.isActive(caster) then
				SpellExecutor.castPayload(spec, ctx, pos, look)
			end
		end,
	})
	FX.all("Shield", caster.model, spec.color)
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

-- Casts a compiled spell. `fromCaster` is true for spells cast straight from a wand.
function SpellExecutor.cast(spec: Spec, ctx: CastCtx, origin: Vector3, dir: Vector3, fromCaster: boolean?)
	local kind = spec.kind
	local count = if kind == "Blink" or kind == "Aegis" then 1 else spec.count
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

	if kind == "Projectile" then
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
			doMeteor(spec, ctx, origin, d, i, count, fromCaster)
		end
	elseif kind == "Blink" then
		doBlink(spec, ctx, origin, dir)
	elseif kind == "Aegis" then
		doAegis(spec, ctx)
	end

	if spec.echo > 0 then
		local again = echoless(spec)
		for e = 1, spec.echo do
			task.delay(ECHO_DELAY * e, function()
				if not Combatants.isActive(ctx.caster) then
					return
				end
				local o = origin
				if fromCaster then
					local head = (ctx.caster.model :: Model):FindFirstChild("Head") :: BasePart?
					if head then
						o = head.Position + dir * 2.2
					end
				end
				SpellExecutor.cast(again, ctx, o, dir, fromCaster)
			end)
		end
	end
end

function SpellExecutor.init()
	ProjectileService.setExecutor(SpellExecutor :: any)
end

return SpellExecutor
