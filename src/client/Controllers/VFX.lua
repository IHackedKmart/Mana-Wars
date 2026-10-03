-- Building blocks for spell effects, and how each element looks.
-- Everything is client-side (parented to workspace.ClientFX) and cleans itself up.
--   * glowing parts that grow and fade, flashes of light, shockwave rings
--   * particle bursts built from Roblox's stock particle textures (no uploaded assets needed)
--   * jagged lightning with forks
--   * cheap rock / ice debris, simulated here instead of by the physics engine
-- A load meter scales particle counts down when lots of spells go off at once.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local VFX = {}

VFX.Textures = {
	sparkles = "rbxasset://textures/particles/sparkles_main.dds",
	fire = "rbxasset://textures/particles/fire_main.dds",
	sparks = "rbxasset://textures/particles/fire_sparks_main.dds",
	smoke = "rbxasset://textures/particles/smoke_main.dds",
}

export type Style = {
	texture: string, -- the element's signature particle
	rise: number, -- upward pull on its particles (negative falls)
	drag: number,
	spin: number, -- particle rotation speed
	white: number, -- how white-hot cores burn (0 = pure colour; negative = dark cores)
	smoky: boolean, -- explosions leave smoke
	extra: string?, -- an element flourish: arcs, rocks, shards, embers, swirl, bubbles, implode, rays, droplets, rainbow, clock, motes
	light: number, -- light brightness multiplier
}

local function style(t: { [string]: any }): Style
	return {
		texture = t.texture or "sparkles",
		rise = t.rise or 0,
		drag = t.drag or 3,
		spin = t.spin or 90,
		white = t.white or 0.5,
		smoky = t.smoky == true,
		extra = t.extra,
		light = t.light or 1,
	}
end

VFX.Styles = {
	Neutral = style({ white = 0.6 }),
	Arcane = style({ rise = 1, spin = 160, white = 0.45, extra = "motes", light = 1.1 }),
	Fire = style({ texture = "fire", rise = 9, drag = 2, white = 0.75, smoky = true, extra = "embers", light = 1.5 }),
	Frost = style({ rise = -4, spin = 40, white = 0.55, extra = "shards" }),
	Earth = style({ texture = "smoke", rise = -8, drag = 2, white = 0.05, smoky = true, extra = "rocks", light = 0.6 }),
	Wind = style({ texture = "smoke", rise = 3, drag = 1, spin = 300, white = 0.5, extra = "swirl", light = 0.5 }),
	Poison = style({ texture = "smoke", rise = 2, drag = 4, white = 0.1, smoky = true, extra = "bubbles", light = 0.8 }),
	Lightning = style({ texture = "sparks", drag = 1, spin = 0, white = 0.9, extra = "arcs", light = 1.8 }),
	Void = style({ spin = 220, white = -0.7, extra = "implode", light = 0.7 }),
	Radiant = style({ rise = 3, white = 0.85, extra = "rays", light = 1.8 }),
	Blood = style({ texture = "sparks", rise = -26, drag = 1, white = 0.15, extra = "droplets", light = 0.8 }),
	Chaos = style({ spin = 260, white = 0.5, extra = "rainbow", light = 1.2 }),
	Chrono = style({ spin = 30, white = 0.6, extra = "clock", light = 1.1 }),
} :: { [string]: Style }

function VFX.style(element: string?): Style
	return VFX.Styles[element or "Neutral"] or VFX.Styles.Neutral
end

local folder: Instance? = nil
local rng = Random.new()
local load = 0 -- recent heavy effects (decays over time)

function VFX.setFolder(f: Instance)
	folder = f
end

-- 1 normally; lower when many effects are on screen at once.
function VFX.quality(): number
	return math.clamp(1.4 - load / 24, 0.35, 1)
end

function VFX.addLoad(amount: number)
	load += amount
end

---------------------------------------------------------------------------
-- Parts
---------------------------------------------------------------------------

function VFX.part(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do
		(p :: any)[k] = v
	end
	p.Parent = folder or workspace
	return p
end

function VFX.ball(position: Vector3, size: number, color: Color3, transparency: number?): Part
	return VFX.part({
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(size, size, size),
		CFrame = CFrame.new(position),
		Color = color,
		Transparency = transparency or 0,
	})
end

-- Tweens a part (to `goal`, fading out) and removes it.
function VFX.fade(part: BasePart, duration: number, goal: { [string]: any }, easing: Enum.EasingStyle?)
	goal.Transparency = 1
	TweenService:Create(part, TweenInfo.new(duration, easing or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal)
		:Play()
	Debris:AddItem(part, duration + 0.05)
end

-- A flat disc lying in the plane facing `normal` (default: flat on the ground).
function VFX.disc(position: Vector3, diameter: number, thickness: number, color: Color3, normal: Vector3?): Part
	local n = normal or Vector3.yAxis
	local cf = if math.abs(n.Y) > 0.99
		then CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
		else CFrame.lookAt(position, position + n) * CFrame.Angles(0, math.rad(90), 0)
	return VFX.part({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(thickness, diameter, diameter),
		CFrame = cf,
		Color = color,
	})
end

-- An expanding shockwave ring: a glowing rim (ForceField) around a quick neon flash.
function VFX.ring(position: Vector3, radius: number, color: Color3, duration: number, normal: Vector3?)
	local rim = VFX.disc(position, 1, 0.25, color, normal)
	rim.Material = Enum.Material.ForceField
	rim.Transparency = 0
	VFX.fade(rim, duration, { Size = Vector3.new(0.25, radius * 2, radius * 2) }, Enum.EasingStyle.Quart)
	local sheet = VFX.disc(position, 1, 0.12, color, normal)
	sheet.Transparency = 0.35
	VFX.fade(sheet, duration * 0.6, { Size = Vector3.new(0.05, radius * 1.7, radius * 1.7) }, Enum.EasingStyle.Quart)
end

-- A brief flash of light at a position.
function VFX.flashLight(position: Vector3, color: Color3, range: number, brightness: number, duration: number)
	local holder = VFX.part({
		Size = Vector3.new(0.2, 0.2, 0.2),
		CFrame = CFrame.new(position),
		Transparency = 1,
	})
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = math.min(range, 60)
	light.Brightness = brightness
	light.Shadows = false
	light.Parent = holder
	TweenService:Create(light, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Brightness = 0,
	}):Play()
	Debris:AddItem(holder, duration + 0.05)
end

-- A white-hot core that blooms into colour.
function VFX.flash(position: Vector3, size: number, color: Color3, duration: number, white: number?)
	local w = white or 0.6
	local core = VFX.ball(
		position,
		size * 0.3,
		if w >= 0 then color:Lerp(Color3.new(1, 1, 1), w) else color:Lerp(Color3.new(0, 0, 0), -w)
	)
	VFX.fade(core, duration, { Size = Vector3.one * size }, Enum.EasingStyle.Quint)
end

---------------------------------------------------------------------------
-- Particles
---------------------------------------------------------------------------

export type EmitterOptions = {
	texture: string?,
	color: Color3,
	color2: Color3?,
	size: number,
	sizeEnd: number?, -- default 0 (shrinks away)
	transparency: number?, -- starting transparency, fades to 1
	lifetime: number,
	lifetimeMin: number?,
	speed: number,
	speedMin: number?,
	spread: number?,
	accel: Vector3?,
	drag: number?,
	rate: number?,
	light: number?, -- LightEmission
	rot: number?, -- RotSpeed range (+/-)
	locked: boolean?,
	zoffset: number?,
	direction: Enum.NormalId?,
}

function VFX.emitter(parent: Instance, o: EmitterOptions): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Texture = VFX.Textures[o.texture or "sparkles"] or VFX.Textures.sparkles
	e.Color = if o.color2 then ColorSequence.new(o.color, o.color2) else ColorSequence.new(o.color)
	local sizeEnd = o.sizeEnd or 0
	e.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, o.size * 0.6),
		NumberSequenceKeypoint.new(0.15, o.size),
		NumberSequenceKeypoint.new(1, sizeEnd),
	})
	e.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, o.transparency or 0),
		NumberSequenceKeypoint.new(0.7, math.min(1, (o.transparency or 0) + 0.3)),
		NumberSequenceKeypoint.new(1, 1),
	})
	e.Lifetime = NumberRange.new(o.lifetimeMin or o.lifetime * 0.6, o.lifetime)
	e.Speed = NumberRange.new(o.speedMin or o.speed * 0.5, o.speed)
	local spread = o.spread or 180
	e.SpreadAngle = Vector2.new(spread, spread)
	e.Acceleration = o.accel or Vector3.zero
	e.Drag = o.drag or 0
	e.Rate = o.rate or 0
	e.LightEmission = o.light or 1
	e.LightInfluence = if (o.light or 1) < 0.3 then 1 else 0
	local rot = o.rot or 0
	e.RotSpeed = NumberRange.new(-rot, rot)
	e.Rotation = NumberRange.new(0, 360)
	e.LockedToPart = o.locked == true
	e.ZOffset = o.zoffset or 0
	if o.direction then
		e.EmissionDirection = o.direction
	end
	e.Parent = parent
	return e
end

-- A one-off burst of `count` particles at a position (scaled by the load meter).
function VFX.burst(position: Vector3, o: EmitterOptions, count: number)
	local n = math.floor(count * VFX.quality() + 0.5)
	if n <= 0 then
		return
	end
	local attachment = Instance.new("Attachment")
	attachment.WorldPosition = position
	attachment.Parent = workspace.Terrain
	local e = VFX.emitter(attachment, o)
	e:Emit(n)
	Debris:AddItem(attachment, o.lifetime + 0.2)
end

-- The element's signature particles flying out of a point.
function VFX.elementBurst(position: Vector3, element: string?, color: Color3, color2: Color3, power: number)
	local s = VFX.style(element)
	local smoke = s.texture == "smoke"
	VFX.burst(position, {
		texture = s.texture,
		color = color,
		color2 = color2,
		size = (if smoke then 1.6 else 1) * math.clamp(power * 0.18, 0.5, 3),
		sizeEnd = if smoke then power * 0.25 else 0,
		transparency = if smoke then 0.35 else 0,
		lifetime = if smoke then 1.1 else 0.7,
		speed = power * 2.2,
		accel = Vector3.new(0, s.rise, 0),
		drag = s.drag,
		light = if smoke then 0.2 else 1,
		rot = s.spin,
	}, 10 + power * 2)
end

-- Fast bright sparks that arc down under gravity.
function VFX.sparks(position: Vector3, color: Color3, power: number, count: number)
	VFX.burst(position, {
		texture = "sparks",
		color = Color3.new(1, 1, 1):Lerp(color, 0.35),
		color2 = color,
		size = math.clamp(power * 0.08, 0.2, 0.8),
		lifetime = 0.9,
		lifetimeMin = 0.3,
		speed = power * 4,
		accel = Vector3.new(0, -40, 0),
		drag = 1.5,
		rot = 0,
	}, count)
end

-- Billowing smoke that rises and spreads.
function VFX.smoke(position: Vector3, color: Color3, power: number, count: number)
	VFX.burst(position, {
		texture = "smoke",
		color = color:Lerp(Color3.fromRGB(40, 36, 40), 0.75),
		color2 = Color3.fromRGB(90, 86, 90),
		size = math.clamp(power * 0.35, 1.5, 7),
		sizeEnd = math.clamp(power * 0.9, 3, 16),
		transparency = 0.45,
		lifetime = 2.4,
		lifetimeMin = 1.4,
		speed = power * 0.8,
		accel = Vector3.new(0, 4, 0),
		drag = 2.5,
		light = 0,
		rot = 30,
	}, count)
end

---------------------------------------------------------------------------
-- Lightning
---------------------------------------------------------------------------

local function segment(a: Vector3, b: Vector3, color: Color3, width: number, life: number)
	local length = (b - a).Magnitude
	if length < 0.05 then
		return
	end
	local seg = VFX.part({
		Size = Vector3.new(width, width, length),
		CFrame = CFrame.lookAt(a:Lerp(b, 0.5), b),
		Color = color,
	})
	VFX.fade(seg, life, { Size = Vector3.new(width * 0.2, width * 0.2, length) })
end

-- A jagged bolt from a to b. `forks` is the chance per joint of a short side branch.
function VFX.bolt(a: Vector3, b: Vector3, color: Color3, width: number, life: number, jitter: number?, forks: number?)
	local span = (b - a).Magnitude
	local segments = math.clamp(math.floor(span / 3), 2, 14)
	local j = jitter or math.clamp(span * 0.06, 0.6, 2.2)
	local last = a
	for i = 1, segments do
		local point = a:Lerp(b, i / segments)
		if i < segments then
			point += Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1), rng:NextNumber(-1, 1)) * j
		end
		segment(last, point, color, width, life)
		if forks and i < segments and rng:NextNumber() < forks then
			local dir = (point - last).Unit
			local side = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1), rng:NextNumber(-1, 1))
			local tip = point + (dir + side).Unit * rng:NextNumber(1.5, 4)
			segment(point, tip, color, width * 0.5, life * 0.8)
		end
		last = point
	end
end

-- Little arcs crackling around a point.
function VFX.crackle(position: Vector3, color: Color3, radius: number, count: number)
	for _ = 1, math.max(1, math.floor(count * VFX.quality() + 0.5)) do
		local dir = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1), rng:NextNumber(-1, 1))
		if dir.Magnitude > 1e-3 then
			VFX.bolt(position, position + dir.Unit * radius * rng:NextNumber(0.5, 1), color, 0.12, 0.12, 0.5, nil)
		end
	end
end

---------------------------------------------------------------------------
-- Debris: rock and ice chunks, simulated by hand (no physics, no collisions with players)
---------------------------------------------------------------------------

type Chunk = { part: BasePart, vel: Vector3, spin: Vector3, floor: number, age: number, life: number }
local chunks: { Chunk } = {}

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

-- The ground height under a point (or nil if there's nothing within `depth`).
function VFX.groundBelow(position: Vector3, depth: number): number?
	local ignore: { Instance } = {}
	if folder then
		table.insert(ignore, folder)
	end
	for _, name in { "Bots" } do
		local f = workspace:FindFirstChild(name)
		if f then
			table.insert(ignore, f)
		end
	end
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(ignore, p.Character)
		end
	end
	rayParams.FilterDescendantsInstances = ignore
	local hit = workspace:Raycast(position + Vector3.new(0, 0.5, 0), Vector3.new(0, -depth, 0), rayParams)
	return if hit then hit.Position.Y else nil
end

function VFX.chunks(
	position: Vector3,
	count: number,
	color: Color3,
	material: Enum.Material,
	size: number,
	speed: number,
	floor: number?
)
	local n = math.floor(count * VFX.quality() + 0.5)
	if VFX.quality() < 0.6 then
		n = math.min(n, 2)
	end
	for _ = 1, n do
		local s = size * rng:NextNumber(0.5, 1.2)
		local part = VFX.part({
			Size = Vector3.new(s, s * rng:NextNumber(0.6, 1), s * rng:NextNumber(0.6, 1)),
			CFrame = CFrame.new(position) * CFrame.Angles(rng:NextNumber(0, 6.3), rng:NextNumber(0, 6.3), 0),
			Color = color,
			Material = material,
		})
		local dir = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(0.4, 1.4), rng:NextNumber(-1, 1)).Unit
		table.insert(chunks, {
			part = part,
			vel = dir * speed * rng:NextNumber(0.6, 1.1),
			spin = Vector3.new(rng:NextNumber(-8, 8), rng:NextNumber(-8, 8), rng:NextNumber(-8, 8)),
			floor = floor or (position.Y - 50),
			age = 0,
			life = rng:NextNumber(1.2, 1.8),
		})
	end
end

-- Moves the debris and lets the load meter cool down. Call every frame.
function VFX.step(dt: number)
	load = math.max(0, load - dt * 12)
	for i = #chunks, 1, -1 do
		local c = chunks[i]
		c.age += dt
		if c.age > c.life or not c.part.Parent then
			if c.part.Parent then
				VFX.fade(c.part, 0.3, { Size = c.part.Size * 0.3 })
			end
			table.remove(chunks, i)
			continue
		end
		c.vel += Vector3.new(0, -60 * dt, 0)
		local pos = c.part.Position + c.vel * dt
		if pos.Y < c.floor + c.part.Size.Y / 2 then
			pos = Vector3.new(pos.X, c.floor + c.part.Size.Y / 2, pos.Z)
			c.vel = Vector3.new(c.vel.X * 0.5, math.abs(c.vel.Y) * 0.3, c.vel.Z * 0.5)
			c.spin *= 0.5
		end
		local r = c.spin * dt
		c.part.CFrame = CFrame.new(pos) * (c.part.CFrame - c.part.Position) * CFrame.Angles(r.X, r.Y, r.Z)
	end
end

---------------------------------------------------------------------------
-- Element flourishes (the extra bit that makes each element look like itself)
---------------------------------------------------------------------------

local function rainbow(): Color3
	return Color3.fromHSV(rng:NextNumber(), 0.8, 1)
end

-- `power` is roughly the radius of the effect in studs.
function VFX.flourish(position: Vector3, element: string?, color: Color3, color2: Color3, power: number, floor: number?)
	local s = VFX.style(element)
	local extra = s.extra
	if extra == "arcs" then
		VFX.crackle(position, Color3.new(1, 1, 1):Lerp(color, 0.3), power * 1.2, 3 + power * 0.4)
	elseif extra == "rocks" then
		VFX.chunks(
			position,
			4 + power * 0.5,
			Color3.fromRGB(110, 92, 74),
			Enum.Material.Slate,
			0.5 + power * 0.06,
			14 + power * 2,
			floor
		)
		VFX.smoke(position, Color3.fromRGB(150, 125, 95), power, 4 + power * 0.4)
	elseif extra == "shards" then
		VFX.chunks(
			position,
			4 + power * 0.4,
			Color3.fromRGB(190, 235, 255),
			Enum.Material.Glass,
			0.35 + power * 0.04,
			16 + power * 2,
			floor
		)
		VFX.burst(position, {
			color = Color3.new(1, 1, 1),
			color2 = color,
			size = 0.5,
			lifetime = 1.6,
			speed = power * 1.2,
			accel = Vector3.new(0, -4, 0),
			drag = 2,
			rot = 60,
		}, 10 + power)
	elseif extra == "embers" then
		VFX.burst(position, {
			texture = "sparks",
			color = Color3.fromRGB(255, 220, 120),
			color2 = Color3.fromRGB(255, 80, 20),
			size = 0.35,
			lifetime = 2,
			lifetimeMin = 1,
			speed = power * 1.5,
			accel = Vector3.new(0, 6, 0),
			drag = 2,
		}, 8 + power)
	elseif extra == "swirl" then
		VFX.burst(position, {
			texture = "smoke",
			color = Color3.new(1, 1, 1),
			color2 = color,
			size = 1.2,
			sizeEnd = power * 0.4,
			transparency = 0.6,
			lifetime = 0.8,
			speed = power * 3,
			drag = 3,
			rot = 400,
			light = 0.3,
		}, 8 + power * 0.6)
	elseif extra == "bubbles" then
		VFX.burst(position, {
			color = color,
			color2 = Color3.fromRGB(200, 255, 120),
			size = 0.6,
			sizeEnd = 0.9,
			transparency = 0.2,
			lifetime = 1.8,
			speed = power * 0.6,
			accel = Vector3.new(0, 3, 0),
			drag = 1,
		}, 8 + power * 0.6)
	elseif extra == "implode" then
		-- dark motes rushing back in
		local attachment = Instance.new("Attachment")
		attachment.WorldPosition = position
		attachment.Parent = workspace.Terrain
		local e = VFX.emitter(attachment, {
			color = color,
			color2 = Color3.new(0, 0, 0),
			size = 0.7,
			lifetime = 0.5,
			speed = -power * 2.4,
			light = 0.6,
			rot = 200,
		})
		e.Shape = Enum.ParticleEmitterShape.Sphere
		e.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
		e:Emit(math.floor((12 + power) * VFX.quality()))
		Debris:AddItem(attachment, 0.7)
		local core = VFX.ball(position, power * 0.5, Color3.new(0, 0, 0), 0)
		core.Material = Enum.Material.SmoothPlastic
		VFX.fade(core, 0.35, { Size = Vector3.one * 0.1 }, Enum.EasingStyle.Back)
	elseif extra == "rays" then
		local n = math.floor(5 + power * 0.25)
		for i = 1, n do
			local yaw = (i / n) * math.pi * 2 + rng:NextNumber(-0.2, 0.2)
			local pitch = rng:NextNumber(-0.5, 0.9)
			local dir = Vector3.new(math.cos(yaw) * math.cos(pitch), math.sin(pitch), math.sin(yaw) * math.cos(pitch))
			local length = power * rng:NextNumber(1.2, 2)
			local ray = VFX.part({
				Size = Vector3.new(0.25, 0.25, 1),
				CFrame = CFrame.lookAt(position, position + dir) * CFrame.new(0, 0, -0.5),
				Color = Color3.new(1, 1, 1):Lerp(color, 0.25),
				Transparency = 0.15,
			})
			VFX.fade(ray, 0.4, {
				Size = Vector3.new(0.05, 0.05, length),
				CFrame = CFrame.lookAt(position, position + dir) * CFrame.new(0, 0, -length / 2),
			})
		end
	elseif extra == "droplets" then
		VFX.burst(position, {
			texture = "sparks",
			color = Color3.fromRGB(200, 20, 30),
			color2 = Color3.fromRGB(90, 0, 10),
			size = 0.45,
			lifetime = 1,
			speed = power * 3,
			accel = Vector3.new(0, -50, 0),
			drag = 0.5,
			light = 0.4,
		}, 10 + power)
	elseif extra == "rainbow" then
		for _ = 1, 3 do
			VFX.burst(position, {
				color = rainbow(),
				color2 = rainbow(),
				size = 0.7,
				lifetime = 0.9,
				speed = power * 2.5,
				drag = 2,
				rot = 300,
			}, 5 + power * 0.4)
		end
	elseif extra == "clock" then
		-- two rings turning in opposite directions, like clock hands sweeping
		for i = 1, 2 do
			local n = Vector3.new(rng:NextNumber(-0.3, 0.3), 1, rng:NextNumber(-0.3, 0.3)).Unit
			local ring = VFX.disc(position, power * (1 + i * 0.4), 0.2, if i == 1 then color else color2, n)
			ring.Material = Enum.Material.ForceField
			VFX.fade(ring, 0.7, {
				CFrame = ring.CFrame * CFrame.Angles(math.rad(if i == 1 then 180 else -180), 0, 0),
				Size = Vector3.new(0.2, power * (1.6 + i * 0.4), power * (1.6 + i * 0.4)),
			}, Enum.EasingStyle.Sine)
		end
	elseif extra == "motes" then
		VFX.burst(position, {
			color = color,
			color2 = Color3.new(1, 1, 1),
			size = 0.4,
			lifetime = 1.4,
			speed = power * 1.4,
			accel = Vector3.new(0, 1.5, 0),
			drag = 3,
			rot = 180,
		}, 10 + power)
	end
end

return VFX
