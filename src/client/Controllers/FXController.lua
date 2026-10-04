-- Draws every spell. The server only sends compact events; all parts here are local
-- to this client (workspace.ClientFX) so effects cost no network bandwidth.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage.Shared
local Remotes = require(Shared.Remotes)
local ProjectileSim = require(Shared.ProjectileSim)
local SpellParts = require(Shared.Spells.SpellParts)
local Signal = require(Shared.Util.Signal)
local Sounds = require(script.Parent.Sounds)
local VFX = require(script.Parent.VFX)

local FXController = {}

FXController.Hurt = Signal.new() -- (amount: number)
FXController.Hit = Signal.new() -- (amount: number, crit: boolean)

local player = Players.LocalPlayer

type VisualProj = {
	state: ProjectileSim.State,
	part: BasePart,
	caster: Model?,
	form: string,
	life: number,
	spin: number,
	visualPos: Vector3,
	flat: boolean,
	element: string?,
	color2: Color3,
	crackle: number, -- seconds until the next spark of lightning (Lightning projectiles)
}

local projectiles: { [number]: VisualProj } = {}
local rng = Random.new()
local shake = 0

local function rgb(c: any, fallback: Color3?): Color3
	if type(c) == "table" and #c == 3 then
		return Color3.fromRGB(c[1], c[2], c[3])
	end
	return fallback or Color3.new(1, 1, 1)
end

local fxPart = VFX.part
local ball = VFX.ball
local tweenAway = VFX.fade

-- Quick sparkle burst (pickups, potions and the like).
local function burst(position: Vector3, color: Color3, count: number, speed: number)
	VFX.burst(position, {
		color = color,
		color2 = Color3.new(1, 1, 1):Lerp(color, 0.5),
		size = 0.7,
		lifetime = 0.7,
		lifetimeMin = 0.3,
		speed = speed,
		drag = 4,
		rot = 120,
	}, count)
end

local function addShake(position: Vector3, strength: number)
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local dist = (camera.CFrame.Position - position).Magnitude
	shake = math.max(shake, strength * math.clamp(1 - dist / 140, 0, 1))
end

-- The colour of a white-hot (or, for Void, black) core.
local function coreColor(color: Color3, style: VFX.Style): Color3
	return if style.white >= 0
		then color:Lerp(Color3.new(1, 1, 1), style.white)
		else color:Lerp(Color3.new(0, 0, 0), -style.white)
end

---------------------------------------------------------------------------
-- Projectiles
---------------------------------------------------------------------------

-- Layers every projectile gets on top of its form: a glow halo, the element's own particles,
-- a hot inner streak and a bright light.
local function dressProjectile(part: Part, form: string, element: string?, c: Color3, c2: Color3, s: number)
	local style = VFX.style(element)
	-- halo: a soft glow sprite that sits on the projectile
	VFX.emitter(part, {
		color = c,
		color2 = c2,
		size = s * 2.4,
		sizeEnd = s * 1.6,
		transparency = 0.45,
		lifetime = 0.12,
		speed = 0,
		speedMin = 0,
		rate = 24,
		locked = true,
		rot = 90,
		zoffset = -0.5,
	})
	-- the element's particles shed along the flight path
	local smoke = style.texture == "smoke"
	VFX.emitter(part, {
		texture = style.texture,
		color = c,
		color2 = c2,
		size = s * (if smoke then 1.1 else 0.75),
		sizeEnd = if smoke then s * 2.2 else 0,
		transparency = if smoke then 0.5 else 0.1,
		lifetime = if smoke then 0.9 else 0.5,
		speed = 2,
		speedMin = 0.3,
		accel = Vector3.new(0, style.rise, 0),
		drag = style.drag,
		rate = math.floor(36 * VFX.quality()),
		light = if smoke then 0.2 else 1,
		rot = style.spin,
	})
	if element == "Fire" then
		VFX.emitter(part, {
			texture = "fire",
			color = Color3.fromRGB(255, 230, 150),
			color2 = c,
			size = s * 1.5,
			transparency = 0.1,
			lifetime = 0.3,
			speed = 1.5,
			accel = Vector3.new(0, 10, 0),
			rate = 45,
			rot = 60,
		})
	elseif element == "Frost" then
		VFX.emitter(part, {
			color = Color3.new(1, 1, 1),
			color2 = c,
			size = s * 0.35,
			lifetime = 1.2,
			speed = 1,
			accel = Vector3.new(0, -3, 0),
			rate = 14,
			rot = 40,
		})
	elseif element == "Void" then
		local inward = VFX.emitter(part, {
			color = c,
			color2 = Color3.new(0, 0, 0),
			size = s * 0.5,
			lifetime = 0.35,
			speed = -s * 5,
			speedMin = -s * 3,
			rate = 30,
			light = 0.5,
			rot = 200,
		})
		inward.Shape = Enum.ParticleEmitterShape.Sphere
		inward.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
	elseif element == "Radiant" or element == "Chrono" or element == "Arcane" then
		VFX.emitter(part, {
			color = Color3.new(1, 1, 1),
			color2 = c,
			size = s * 0.4,
			lifetime = 0.8,
			speed = 0.6,
			rate = 12,
			rot = 180,
		})
	end
	if form ~= "Spark" then
		-- a thin white-hot streak inside the coloured trail
		local a0 = Instance.new("Attachment")
		a0.Position = Vector3.new(0, s * 0.12, 0)
		a0.Parent = part
		local a1 = Instance.new("Attachment")
		a1.Position = Vector3.new(0, -s * 0.12, 0)
		a1.Parent = part
		local streak = Instance.new("Trail")
		streak.Attachment0 = a0
		streak.Attachment1 = a1
		streak.Color = ColorSequence.new(coreColor(c, style))
		streak.Transparency = NumberSequence.new(0, 1)
		streak.LightEmission = 1
		streak.FaceCamera = true
		streak.Lifetime = 0.12
		streak.Parent = part
	end
	local light = Instance.new("PointLight")
	light.Color = c
	light.Range = math.clamp(s * 9, 7, 22)
	light.Brightness = 2.2 * style.light
	light.Shadows = false
	light.Parent = part
end

local function buildProjectile(vis: { [string]: any }): (Part, number, boolean)
	local c = rgb(vis.c)
	local c2 = rgb(vis.c2, c)
	local s = math.max(0.3, vis.s or 1)
	local form = vis.f
	local style = VFX.style(vis.e)
	local spin = 0
	local flat = false
	local part: Part
	if form == "Grenade" then
		part = ball(Vector3.zero, s, c:Lerp(Color3.new(0, 0, 0), 0.55))
		part.Material = Enum.Material.SmoothPlastic
		local sparks = Instance.new("Sparkles")
		sparks.SparkleColor = c
		sparks.Parent = part
	elseif form == "Mine" then
		part = fxPart({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.5, s * 1.8, s * 1.8), Color = c })
		flat = true
	elseif form == "Cloud" then
		part = ball(Vector3.zero, s, c, 0.25)
		part.Material = Enum.Material.Glass
	elseif form == "Boomerang" then
		part = fxPart({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.35, s * 1.8, s * 1.8), Color = c })
		spin = 25
	elseif form == "Sawblade" then
		part = fxPart({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, s * 1.6, s * 1.6), Color = c })
		part.Material = Enum.Material.Metal
		local edge = Instance.new("Sparkles")
		edge.SparkleColor = c2
		edge.Parent = part
		spin = 40
	elseif form == "Swarm" then
		part = ball(Vector3.zero, s, c, 0.05)
		VFX.emitter(part, {
			color = c2,
			size = s * 0.8,
			transparency = 0.3,
			lifetime = 0.3,
			lifetimeMin = 0.15,
			speed = 0.5,
			speedMin = 0,
			rate = 25,
		})
	elseif form == "Tornado" then
		-- a spinning funnel of debris
		part = fxPart({
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(s * 2.4, s * 1.1, s * 1.1),
			Color = c,
			Transparency = 0.55,
			Material = Enum.Material.ForceField,
		})
		local debris = VFX.emitter(part, {
			texture = "smoke",
			color = c,
			color2 = c2,
			size = 0.6,
			sizeEnd = 0.2,
			transparency = 0.2,
			lifetime = 1.2,
			speed = 8,
			speedMin = 4,
			rate = 60,
			light = 0.3,
			rot = 200,
		})
		debris.SpreadAngle = Vector2.new(180, 20)
		flat = true
		spin = 18
	elseif form == "BlackHole" then
		part = ball(Vector3.zero, s, Color3.new(0, 0, 0))
		part.Material = Enum.Material.SmoothPlastic
		local disk = VFX.emitter(part, {
			color = c,
			color2 = c2,
			size = s * 0.5,
			lifetime = 0.8,
			lifetimeMin = 0.4,
			speed = -s * 3,
			speedMin = -s * 6, -- particles fall inward
			rate = 80,
		})
		disk.Shape = Enum.ParticleEmitterShape.Sphere
		disk.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
	elseif form == "Sentry" then
		-- a floating eye with a glowing, pulsing iris
		part = ball(Vector3.zero, s, Color3.fromRGB(240, 235, 225))
		part.Material = Enum.Material.SmoothPlastic
		VFX.emitter(part, {
			color = c,
			color2 = c2,
			size = s * 0.9,
			sizeEnd = s * 0.4,
			transparency = 0.1,
			lifetime = 0.5,
			lifetimeMin = 0.3,
			speed = 0,
			speedMin = 0,
			rate = 20,
			locked = true,
		})
	elseif form == "Meteor" then
		part = ball(Vector3.zero, s, c:Lerp(Color3.new(0, 0, 0), 0.6))
		part.Material = Enum.Material.Basalt
		local fire = Instance.new("Fire")
		fire.Size = s * 3
		fire.Heat = 12
		fire.Color = c
		fire.SecondaryColor = c2
		fire.Parent = part
		VFX.emitter(part, {
			texture = "smoke",
			color = Color3.fromRGB(60, 50, 50),
			size = s * 1.4,
			sizeEnd = s * 3,
			transparency = 0.4,
			lifetime = 1.4,
			speed = 1,
			rate = 30,
			light = 0,
			rot = 40,
		})
	elseif form == "Orb" then
		part = ball(Vector3.zero, s, c, 0.25)
	elseif form == "Wisp" then
		part = ball(Vector3.zero, s, c, 0.1)
	else
		part = ball(Vector3.zero, s, c)
	end
	if part.Material == Enum.Material.Neon and part.Shape == Enum.PartType.Ball then
		-- burning core: brighter towards white (or black, for the void)
		part.Color = coreColor(c, style)
	end
	dressProjectile(part, form, vis.e, c, c2, s)

	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, s * 0.45, 0)
	a0.Parent = part
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -s * 0.45, 0)
	a1.Parent = part
	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Color = ColorSequence.new(c, c2)
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.05),
		NumberSequenceKeypoint.new(0.5, 0.5),
		NumberSequenceKeypoint.new(1, 1),
	})
	trail.LightEmission = 1
	trail.FaceCamera = true
	trail.Lifetime = if form == "Spark" then 0.12 elseif form == "Orb" or form == "Meteor" then 0.45 else 0.28
	trail.WidthScale = NumberSequence.new(1, 0)
	trail.Parent = part
	return part, spin, flat
end

local targetCache: { BasePart } = {}
local targetCacheTime = 0

local function refreshTargets()
	local now = os.clock()
	if now - targetCacheTime < 0.5 then
		return
	end
	targetCacheTime = now
	table.clear(targetCache)
	for _, p in Players:GetPlayers() do
		local char = p.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if root and p:GetAttribute("Alive") then
			table.insert(targetCache, root :: BasePart)
		end
	end
	local bots = workspace:FindFirstChild("Bots")
	if bots then
		for _, model in bots:GetChildren() do
			local root = model:FindFirstChild("HumanoidRootPart")
			if root then
				table.insert(targetCache, root :: BasePart)
			end
		end
	end
end

local function homingTarget(p: VisualProj): Vector3?
	local pos = p.state.pos
	local forward = if p.state.vel.Magnitude > 1e-3 then p.state.vel.Unit else nil
	local best, bestScore = nil, math.huge
	for _, root in targetCache do
		if root.Parent and root.Parent ~= p.caster then
			local to = root.Position - pos
			local dist = to.Magnitude
			if dist < 80 and dist > 0.1 then
				local facing = if forward then forward:Dot(to.Unit) else 1
				if facing > -0.3 then
					local score = dist * (1.6 - facing * 0.6)
					if score < bestScore then
						best, bestScore = root.Position, score
					end
				end
			end
		end
	end
	return best
end

local function removeProjectile(id: number, position: Vector3?, kind: string?)
	local p = projectiles[id]
	if not p then
		return
	end
	projectiles[id] = nil
	local part = p.part
	if position then
		part.CFrame = CFrame.new(position)
	end
	local pos = part.Position
	local color = rgb(nil, part.Color)
	local light = part:FindFirstChildOfClass("PointLight")
	if light then
		color = light.Color -- the projectile's own colour (its core may be white-hot)
	end
	if kind == "impact" then
		local style = VFX.style(p.element)
		local power = math.clamp(part.Size.Y * 3, 2.5, 9)
		VFX.flash(pos, power * 1.3, color, 0.2, style.white)
		local dir = if p.state.vel.Magnitude > 0.1 then -p.state.vel.Unit else Vector3.yAxis
		VFX.ring(pos, power * 0.9, color, 0.28, dir)
		VFX.elementBurst(pos, p.element, color, p.color2, power)
		VFX.sparks(pos, color, power, 5 + power)
		VFX.flashLight(pos, color, power * 4, 4 * style.light, 0.25)
		if VFX.quality() > 0.5 then
			VFX.flourish(pos, p.element, color, p.color2, power * 0.6, VFX.groundBelow(pos, 12))
		end
		VFX.addLoad(1)
	elseif kind == "expire" or kind == "fizzle" then
		VFX.burst(pos, {
			color = color,
			color2 = p.color2,
			size = math.clamp(part.Size.Y * 0.6, 0.3, 1.2),
			lifetime = 0.5,
			speed = 4,
			drag = 3,
			rot = 90,
		}, 8)
	end
	for _, child in part:GetDescendants() do
		if child:IsA("ParticleEmitter") then
			child.Enabled = false
		elseif child:IsA("Fire") or child:IsA("Sparkles") or child:IsA("PointLight") then
			child:Destroy()
		end
	end
	part.Transparency = 1
	Debris:AddItem(part, 1.2)
end

local function stepProjectiles(dt: number)
	VFX.step(dt)
	refreshTargets()
	for id, p in projectiles do
		local casterPos: Vector3? = nil
		if p.caster then
			local root = p.caster:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root then
				casterPos = root.Position
			end
		end
		local target = if p.state.homing > 0 and not p.state.returning then homingTarget(p) else nil
		ProjectileSim.step(p.state, dt, casterPos, target)
		p.visualPos = p.visualPos:Lerp(p.state.pos, math.min(1, dt * 22))
		local cf
		if p.flat then
			cf = CFrame.new(p.visualPos) * CFrame.Angles(0, 0, math.rad(90))
		elseif p.state.vel.Magnitude > 0.1 then
			cf = CFrame.lookAt(p.visualPos, p.visualPos + p.state.vel)
		else
			cf = CFrame.new(p.visualPos)
		end
		if p.spin ~= 0 then
			cf = CFrame.new(p.visualPos) * CFrame.Angles(0, p.state.age * p.spin, math.rad(90))
		end
		p.part.CFrame = cf
		if p.element == "Lightning" then
			-- crackling arcs leaping off the bolt
			p.crackle -= dt
			if p.crackle <= 0 then
				p.crackle = rng:NextNumber(0.06, 0.14) / VFX.quality()
				VFX.crackle(p.visualPos, Color3.new(1, 1, 1):Lerp(p.color2, 0.4), p.part.Size.Y * 1.6 + 0.6, 1)
			end
		end
		if p.state.age > p.life + 2 then
			removeProjectile(id, nil, nil)
		end
	end
end

---------------------------------------------------------------------------
-- One-shot effects
---------------------------------------------------------------------------

local handlers: { [string]: (...any) -> () } = {}

-- Lets other controllers draw their own FX events (e.g. FamiliarController's "FamiliarNip").
function FXController.on(kind: string, handler: (...any) -> ())
	handlers[kind] = handler
end

handlers["P+"] = function(id: number, pos: Vector3, vel: Vector3, seed: number, orbitAngle: number, caster: Model?, vis)
	local speed = vel.Magnitude
	local state = ProjectileSim.new({
		pos = pos,
		dir = if speed > 1e-3 then vel.Unit else Vector3.new(0, 0, -1),
		speed = speed,
		gravity = vis.g,
		homing = vis.h,
		accelerate = vis.a,
		erratic = vis.r,
		orbit = vis.o,
		orbitRadius = vis.or_,
		orbitAngle = orbitAngle,
		boomerangAt = vis.b,
		hold = vis.d,
		hover = vis.hv,
		seed = seed,
	})
	local part, spin, flat = buildProjectile(vis)
	part.CFrame = CFrame.new(pos)
	local c = rgb(vis.c)
	projectiles[id] = {
		state = state,
		part = part,
		caster = caster,
		form = vis.f,
		life = vis.l or 3,
		spin = spin,
		visualPos = pos,
		flat = flat,
		element = vis.e,
		color2 = rgb(vis.c2, c),
		crackle = 0,
	}
end

handlers["P-"] = function(id: number, pos: Vector3, kind: string)
	removeProjectile(id, pos, kind)
end

handlers.Beam = function(points: { Vector3 }, c, c2, size: number, element: string?)
	local color = rgb(c)
	local glow = rgb(c2, color)
	local style = VFX.style(element)
	local width = math.clamp((size or 0.5) * 0.8, 0.25, 3)
	local core = coreColor(color, style)
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local length = (b - a).Magnitude
		if length > 0.05 then
			if element == "Lightning" then
				VFX.bolt(a, b, core, width * 0.6, 0.25, width * 1.2, 0.25)
				VFX.bolt(a, b, glow, width * 0.25, 0.18, width * 1.6, 0.15)
			else
				local cf = CFrame.lookAt(a:Lerp(b, 0.5), b)
				local inner = fxPart({ Size = Vector3.new(width, width, length), CFrame = cf, Color = core })
				tweenAway(inner, 0.26, { Size = Vector3.new(0.05, 0.05, length) })
				local outer = fxPart({
					Size = Vector3.new(width * 2.4, width * 2.4, length),
					CFrame = cf,
					Color = glow,
					Transparency = 0.5,
				})
				tweenAway(outer, 0.34, { Size = Vector3.new(width * 3.4, width * 3.4, length) })
				-- a spiralling sheath for the thicker beams
				if width >= 0.6 then
					local sheath = fxPart({
						Shape = Enum.PartType.Cylinder,
						Size = Vector3.new(length, width * 3.2, width * 3.2),
						CFrame = cf * CFrame.Angles(0, math.rad(90), 0),
						Color = color,
						Material = Enum.Material.ForceField,
					})
					tweenAway(sheath, 0.4, { Size = Vector3.new(length, width * 5, width * 5) })
				end
			end
			-- the element's particles all along the beam
			local steps = math.clamp(math.floor(length / 6), 1, 10)
			for j = 1, steps do
				VFX.burst(a:Lerp(b, (j - 0.5) / steps), {
					texture = style.texture,
					color = color,
					color2 = glow,
					size = width * 0.9,
					sizeEnd = if style.texture == "smoke" then width * 2 else 0,
					transparency = if style.texture == "smoke" then 0.4 else 0,
					lifetime = 0.5,
					speed = 3,
					accel = Vector3.new(0, style.rise, 0),
					drag = 3,
					light = if style.texture == "smoke" then 0.2 else 1,
					rot = style.spin,
				}, 3)
			end
		end
	end
	local start, finish = points[1], points[#points]
	if start then
		VFX.flash(start, width * 3, color, 0.15, style.white)
	end
	if finish then
		VFX.flash(finish, width * 4, color, 0.2, style.white)
		VFX.elementBurst(finish, element, color, glow, 4 + width * 2)
		VFX.sparks(finish, color, 4 + width * 2, 8)
		VFX.flashLight(finish, color, 16, 3 * style.light, 0.3)
		Sounds.at("Cast", start or finish, 0.8)
	end
	VFX.addLoad(1)
end

handlers.Boom = function(pos: Vector3, radius: number, c, c2, element: string?)
	local color = rgb(c)
	local color2 = rgb(c2, color)
	local style = VFX.style(element)
	local r = math.max(radius, 1)
	local floor = VFX.groundBelow(pos, r + 4)
	-- 1. a white-hot flash, then the fireball, then a slower outer shell
	VFX.flash(pos, r * 1.1, color, 0.18, style.white)
	local fireball = ball(pos, 1, color, 0.05)
	tweenAway(fireball, 0.42, { Size = Vector3.one * r * 1.9 }, Enum.EasingStyle.Quart)
	local shell = ball(pos, 1, color2, 0.55)
	shell.Material = Enum.Material.ForceField
	tweenAway(shell, 0.6, { Size = Vector3.one * r * 2.5 }, Enum.EasingStyle.Quart)
	-- 2. a shockwave racing along the ground (or around the blast in mid-air)
	if floor and pos.Y - floor < r + 2 then
		local ground = Vector3.new(pos.X, floor + 0.15, pos.Z)
		VFX.ring(ground, r * 1.6, color, 0.5, nil)
		VFX.burst(ground, {
			texture = "smoke",
			color = Color3.fromRGB(150, 140, 130):Lerp(color, 0.2),
			size = r * 0.25 + 1,
			sizeEnd = r * 0.6 + 2,
			transparency = 0.5,
			lifetime = 1.2,
			speed = r * 3,
			drag = 4,
			light = 0,
			rot = 40,
		}, 10 + r)
	else
		VFX.ring(pos, r * 1.4, color, 0.45, Vector3.new(0.3, 1, 0.2).Unit)
	end
	-- 3. the element's particles, sparks and (for burning things) smoke
	VFX.elementBurst(pos, element, color, color2, r)
	VFX.sparks(pos, color, r, 10 + r * 1.5)
	if style.smoky then
		VFX.smoke(pos, color, r, 5 + r * 0.6)
	end
	VFX.flourish(pos, element, color, color2, r, floor)
	-- 4. light, sound and shake
	VFX.flashLight(pos, color, r * 4 + 8, 7 * style.light, 0.5)
	local explosion = Instance.new("Explosion")
	explosion.Position = pos
	explosion.BlastPressure = 0
	explosion.BlastRadius = 0
	explosion.DestroyJointPercentage = 0
	explosion.Visible = false
	explosion.Parent = workspace
	Sounds.at("Boom", pos, math.clamp(r / 10, 0.4, 1.2))
	addShake(pos, math.clamp(r / 8, 0.35, 1.5))
	VFX.addLoad(2)
end

handlers.Nova = function(pos: Vector3, radius: number, c, c2, element: string?)
	local color = rgb(c)
	local color2 = rgb(c2, color)
	local style = VFX.style(element)
	local r = math.max(radius, 1)
	VFX.flash(pos, r * 0.6, color, 0.16, style.white)
	VFX.ring(pos, r, color, 0.4, nil)
	task.delay(0.08, function()
		VFX.ring(pos, r * 0.75, color2, 0.35, nil)
	end)
	local dome = ball(pos, 2, color2, 0.6)
	dome.Material = Enum.Material.ForceField
	tweenAway(dome, 0.35, { Size = Vector3.one * r * 2 })
	-- radial streaks flying outwards
	local n = math.floor(math.clamp(r * 0.8, 6, 16) * VFX.quality())
	for i = 1, n do
		local yaw = (i / n) * math.pi * 2 + rng:NextNumber(-0.15, 0.15)
		local dir = Vector3.new(math.cos(yaw), rng:NextNumber(-0.05, 0.25), math.sin(yaw)).Unit
		local streak = fxPart({
			Size = Vector3.new(0.3, 0.3, 2),
			CFrame = CFrame.lookAt(pos, pos + dir) * CFrame.new(0, 0, -1),
			Color = coreColor(color, style),
		})
		tweenAway(streak, 0.32, {
			Size = Vector3.new(0.08, 0.08, r * 0.5),
			CFrame = CFrame.lookAt(pos, pos + dir) * CFrame.new(0, 0, -r * 0.85),
		})
	end
	VFX.elementBurst(pos, element, color, color2, r)
	VFX.flourish(pos, element, color, color2, r * 0.7, VFX.groundBelow(pos, 6))
	VFX.flashLight(pos, color, r * 3 + 6, 5 * style.light, 0.35)
	addShake(pos, 0.6)
	Sounds.at("Boom", pos, 0.6)
	VFX.addLoad(1.5)
end

handlers.Chain = function(points: { Vector3 }, c, c2, width: number, element: string?)
	local color = rgb(c)
	local glow = rgb(c2, color)
	local style = VFX.style(element)
	local w = math.clamp(width or 0.35, 0.15, 1)
	local core = coreColor(color, style)
	local function draw(life: number)
		for i = 1, #points - 1 do
			VFX.bolt(points[i], points[i + 1], core, w, life, nil, 0.3)
			VFX.bolt(points[i], points[i + 1], glow, w * 0.45, life * 0.7, nil, nil)
		end
	end
	draw(0.22)
	task.delay(0.07, draw, 0.16) -- a second flicker
	for i = 2, #points do
		VFX.flash(points[i], 2.2, color, 0.15, style.white)
		VFX.sparks(points[i], color, 4, 6)
		VFX.flashLight(points[i], color, 14, 3 * style.light, 0.25)
	end
	if points[1] then
		Sounds.at("Hitmarker", points[1], 0.7)
	end
	VFX.addLoad(1)
end

handlers.Zone = function(_id: number, pos: Vector3, radius: number, duration: number, c, c2, element)
	local color = rgb(c)
	local color2 = rgb(c2, color)
	local style = VFX.style(element)
	local base = pos + Vector3.new(0, 0.2, 0)
	local flat = CFrame.new(base) * CFrame.Angles(0, 0, math.rad(90))
	local disc = fxPart({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.3, radius * 2, radius * 2),
		CFrame = flat,
		Color = color,
		Transparency = 0.7,
		Material = Enum.Material.ForceField,
	})
	-- the glowing edge, pulsing gently
	local edge = fxPart({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.6, radius * 2 + 0.6, radius * 2 + 0.6),
		CFrame = flat * CFrame.new(-0.05, 0, 0),
		Color = color2,
		Transparency = 0.2,
		Material = Enum.Material.ForceField,
	})
	TweenService:Create(
		edge,
		TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Transparency = 0.6 }
	):Play()
	-- the element's particles boiling up out of the ground
	local smoke = style.texture == "smoke"
	local emitter = VFX.emitter(disc, {
		texture = style.texture,
		color = color,
		color2 = color2,
		size = if smoke then 2 else 1.2,
		sizeEnd = if smoke then 3.5 else 0,
		transparency = if smoke then 0.55 else 0.25,
		lifetime = 1.6,
		lifetimeMin = 0.8,
		speed = 3,
		speedMin = 1,
		accel = Vector3.new(0, 3 + math.max(style.rise, 0), 0),
		drag = 1,
		rate = math.clamp(radius * 4, 10, 80) * VFX.quality(),
		light = if smoke then 0.2 else 0.8,
		rot = style.spin,
	})
	emitter.EmissionDirection = Enum.NormalId.Right
	emitter.Shape = Enum.ParticleEmitterShape.Cylinder
	emitter.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
	local motes = VFX.emitter(disc, {
		color = Color3.new(1, 1, 1),
		color2 = color,
		size = 0.35,
		lifetime = 2,
		speed = 2,
		accel = Vector3.new(0, 2, 0),
		rate = math.clamp(radius * 1.5, 4, 30) * VFX.quality(),
		rot = 120,
	})
	motes.EmissionDirection = Enum.NormalId.Right
	motes.Shape = Enum.ParticleEmitterShape.Cylinder
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = math.min(radius * 2 + 6, 40)
	light.Brightness = 1.2 * style.light
	light.Shadows = false
	light.Parent = disc
	VFX.ring(base, radius, color, 0.4, nil)
	task.delay(math.max(0, duration - 0.4), function()
		emitter.Enabled = false
		motes.Enabled = false
		tweenAway(disc, 0.4, {})
		tweenAway(edge, 0.4, {})
	end)
end

local function swirl(pos: Vector3, color: Color3, color2: Color3)
	-- a column of motes spinning up where the caster appears / vanishes
	VFX.burst(pos, {
		color = color,
		color2 = color2,
		size = 0.6,
		lifetime = 0.7,
		speed = 7,
		accel = Vector3.new(0, 14, 0),
		drag = 4,
		rot = 400,
	}, 24)
	local column = fxPart({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(8, 3, 3),
		CFrame = CFrame.new(pos + Vector3.new(0, 1.5, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = color,
		Transparency = 0.25,
	})
	tweenAway(column, 0.35, { Size = Vector3.new(12, 0.2, 0.2) })
end

handlers.Blink = function(from: Vector3, to: Vector3, c, c2, element: string?)
	local color = rgb(c)
	local color2 = rgb(c2, color)
	local style = VFX.style(element)
	for _, p in { from, to } do
		local puff = ball(p, 3, color, 0.2)
		puff.Material = Enum.Material.ForceField
		tweenAway(puff, 0.4, { Size = Vector3.one * 8 })
		swirl(p, color, color2)
		VFX.flashLight(p, color, 16, 3 * style.light, 0.35)
	end
	VFX.bolt(from, to, coreColor(color, style), 0.3, 0.3, nil, 0.2)
	VFX.elementBurst(to, element, color, color2, 4)
	Sounds.at("Blink", to)
end

handlers.Warn = function(pos: Vector3, radius: number, c)
	local danger = rgb(c):Lerp(Color3.fromRGB(255, 40, 40), 0.5)
	local ring = fxPart({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.2, radius * 2, radius * 2),
		CFrame = CFrame.new(pos + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = danger,
		Transparency = 0.5,
	})
	tweenAway(ring, 0.9, { Size = Vector3.new(0.2, radius * 0.5, radius * 0.5) })
	local rim = fxPart({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.4, radius * 2, radius * 2),
		CFrame = CFrame.new(pos + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = danger,
		Material = Enum.Material.ForceField,
	})
	tweenAway(rim, 0.9, {})
	VFX.flashLight(pos + Vector3.new(0, 2, 0), danger, radius * 2 + 4, 2, 0.9)
end

handlers.Vortex = function(pos: Vector3, radius: number, c, c2, element: string?)
	local color = rgb(c)
	local color2 = rgb(c2, color)
	local style = VFX.style(element)
	local ring = fxPart({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.4, radius * 2.4, radius * 2.4),
		CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90)),
		Color = color,
		Transparency = 0.3,
		Material = Enum.Material.ForceField,
	})
	tweenAway(ring, 0.45, {
		Size = Vector3.new(0.4, 1, 1),
		CFrame = ring.CFrame * CFrame.Angles(math.rad(270), 0, 0),
	}, Enum.EasingStyle.Quad)
	-- everything gets sucked in towards the eye
	local attachment = Instance.new("Attachment")
	attachment.WorldPosition = pos
	attachment.Parent = workspace.Terrain
	local inward = VFX.emitter(attachment, {
		texture = if style.texture == "smoke" then "smoke" else "sparkles",
		color = color,
		color2 = color2,
		size = 0.9,
		transparency = if style.texture == "smoke" then 0.5 else 0.1,
		lifetime = 0.5,
		speed = -radius * 2.2,
		speedMin = -radius * 1.6,
		rot = 300,
		light = if style.texture == "smoke" then 0.2 else 1,
	})
	inward.Shape = Enum.ParticleEmitterShape.Sphere
	inward.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
	inward:Emit(math.floor((20 + radius) * VFX.quality()))
	Debris:AddItem(attachment, 0.7)
	local eye = ball(pos, 2.5, coreColor(color, style), 0.1)
	tweenAway(eye, 0.45, { Size = Vector3.one * 0.3 }, Enum.EasingStyle.Back)
	VFX.flashLight(pos, color, radius * 2, 3 * style.light, 0.45)
	VFX.addLoad(1)
end

local function tipOf(model: Model?): Vector3?
	if not model then
		return nil
	end
	local tool = model:FindFirstChildOfClass("Tool")
	local handle = tool and tool:FindFirstChild("Handle")
	local tip = handle and handle:FindFirstChild("Tip")
	if tip and tip:IsA("Attachment") then
		return tip.WorldPosition
	end
	local head = model:FindFirstChild("Head") :: BasePart?
	return if head then head.Position else nil
end

handlers.Cast = function(model: Model?, c, element: string?)
	local pos = tipOf(model)
	if not pos then
		return
	end
	local color = rgb(c)
	local style = VFX.style(element)
	VFX.flash(pos, 2, color, 0.14, style.white)
	-- a little magic circle at the wand tip, facing where the caster looks
	local root = model and model:FindFirstChild("HumanoidRootPart") :: BasePart?
	local look = if root then root.CFrame.LookVector else Vector3.new(0, 0, -1)
	local circle = VFX.disc(pos + look * 0.4, 0.6, 0.08, color, look)
	circle.Material = Enum.Material.ForceField
	tweenAway(circle, 0.3, {
		Size = Vector3.new(0.08, 3.2, 3.2),
		CFrame = circle.CFrame * CFrame.Angles(math.rad(120), 0, 0),
	})
	VFX.burst(pos, {
		texture = style.texture,
		color = color,
		color2 = Color3.new(1, 1, 1),
		size = 0.35,
		lifetime = 0.35,
		speed = 6,
		drag = 5,
		rot = style.spin,
		light = if style.texture == "smoke" then 0.3 else 1,
	}, 6)
	if model == player.Character then
		Sounds.play("Cast", 0.2)
	else
		Sounds.at("Cast", pos, 0.6)
	end
end

handlers.Shield = function(model: Model?, c)
	local root = model and model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		local color = rgb(c)
		local bubble = ball(root.Position, 4, color, 0.1)
		bubble.Material = Enum.Material.ForceField
		tweenAway(bubble, 0.5, { Size = Vector3.one * 9 })
		VFX.burst(root.Position, {
			color = Color3.new(1, 1, 1),
			color2 = color,
			size = 0.5,
			lifetime = 0.8,
			speed = 6,
			drag = 3,
			rot = 90,
		}, 16)
		VFX.flashLight(root.Position, color, 14, 2.5, 0.4)
	end
end

handlers.Potion = function(model: Model?, c)
	local root = model and model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		local color = rgb(c)
		burst(root.Position, color, 20, 6)
		VFX.burst(root.Position - Vector3.new(0, 2, 0), {
			color = color,
			color2 = Color3.new(1, 1, 1),
			size = 0.4,
			lifetime = 1.2,
			speed = 3,
			accel = Vector3.new(0, 9, 0),
			drag = 2,
			rot = 200,
		}, 14)
		Sounds.at("Potion", root.Position)
	end
end

handlers.Cannon = function()
	Sounds.play("Cannon")
end

handlers.Gong = function()
	Sounds.play("Gong")
end

handlers.NoMana = function()
	Sounds.play("NoMana")
end

---------------------------------------------------------------------------
-- Damage numbers
---------------------------------------------------------------------------

local function elementColor(element: string): Color3
	local part = SpellParts.get(element)
	if part then
		return Color3.fromRGB(part.color[1], part.color[2], part.color[3]):Lerp(Color3.new(1, 1, 1), 0.25)
	end
	return Color3.new(1, 1, 1)
end

local function damageNumber(pos: Vector3, amount: number, crit: boolean, element: string)
	local attachment = Instance.new("Attachment")
	attachment.WorldPosition = pos + Vector3.new(rng:NextNumber(-1, 1), 1.5, rng:NextNumber(-1, 1))
	attachment.Parent = workspace.Terrain
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(if crit then 110 else 80, if crit then 40 else 30)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = 250
	gui.Parent = attachment
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.Text = if crit then tostring(amount) .. "!" else tostring(amount)
	label.TextColor3 = if crit then Color3.fromRGB(255, 215, 80) else elementColor(element)
	label.TextStrokeTransparency = 0.2
	label.Parent = gui
	TweenService:Create(gui, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		StudsOffsetWorldSpace = Vector3.new(0, 3, 0),
	}):Play()
	TweenService:Create(label, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	}):Play()
	Debris:AddItem(attachment, 0.9)
end

function FXController.init()
	local existing = workspace:FindFirstChild("ClientFX")
	if existing then
		existing:Destroy()
	end
	local f = Instance.new("Folder")
	f.Name = "ClientFX"
	f.Parent = workspace
	VFX.setFolder(f)

	Remotes.event("FX").OnClientEvent:Connect(function(kind: string, ...)
		local handler = handlers[kind]
		if handler then
			local ok, err = pcall(handler, ...)
			if not ok then
				warn("[FX] " .. kind .. ": " .. tostring(err))
			end
		end
	end)

	Remotes.unreliable("FXSync").OnClientEvent:Connect(function(batch)
		for _, entry in batch do
			local p = projectiles[entry[1]]
			if p then
				p.state.pos = entry[2]
				p.state.vel = entry[3]
				p.state.stuck = entry[4] == true
				local speed = (entry[3] :: Vector3).Magnitude
				if speed > 1e-3 then
					p.state.speed = speed
				end
			end
		end
	end)

	Remotes.unreliable("DamageNumber").OnClientEvent:Connect(function(pos, amount, crit, element, isSelf)
		if isSelf then
			FXController.Hurt:Fire(amount)
			if amount > 0 then
				Sounds.play("Hurt", 0.2)
				shake = math.max(shake, math.clamp(amount / 25, 0.15, 0.8))
			end
		else
			if amount > 0 then
				damageNumber(pos, amount, crit, element)
				VFX.sparks(pos, elementColor(element), if crit then 6 else 3, if crit then 10 else 4)
			end
			FXController.Hit:Fire(amount, crit)
			Sounds.play(if crit then "Crit" else "Hitmarker", 0.15)
		end
	end)

	RunService.RenderStepped:Connect(stepProjectiles)
	RunService:BindToRenderStep("ManaWarsShake", Enum.RenderPriority.Camera.Value + 1, function(dt)
		if shake <= 0.01 then
			shake = 0
			return
		end
		local camera = workspace.CurrentCamera
		if camera then
			local s = shake * 0.02
			camera.CFrame *= CFrame.Angles(rng:NextNumber(-s, s), rng:NextNumber(-s, s), 0)
		end
		shake = math.max(0, shake - dt * 3)
	end)
end

return FXController
