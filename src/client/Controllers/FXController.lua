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

local FXController = {}

FXController.Hurt = Signal.new() -- (amount: number)
FXController.Hit = Signal.new() -- (amount: number, crit: boolean)

local player = Players.LocalPlayer
local folder: Folder

type VisualProj = {
	state: ProjectileSim.State,
	part: BasePart,
	caster: Model?,
	form: string,
	life: number,
	spin: number,
	visualPos: Vector3,
	flat: boolean,
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

local function fxPart(props: { [string]: any }): Part
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
	p.Parent = folder
	return p
end

local function ball(position: Vector3, size: number, color: Color3, transparency: number?): Part
	return fxPart({
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(size, size, size),
		CFrame = CFrame.new(position),
		Color = color,
		Transparency = transparency or 0,
	})
end

local function tweenAway(part: BasePart, duration: number, goal: { [string]: any })
	goal.Transparency = 1
	TweenService:Create(part, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal):Play()
	Debris:AddItem(part, duration + 0.05)
end

local function burst(position: Vector3, color: Color3, count: number, speed: number)
	local attachment = Instance.new("Attachment")
	attachment.WorldPosition = position
	attachment.Parent = workspace.Terrain
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(color)
	emitter.LightEmission = 1
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0) })
	emitter.Transparency = NumberSequence.new(0, 1)
	emitter.Lifetime = NumberRange.new(0.3, 0.7)
	emitter.Speed = NumberRange.new(speed * 0.5, speed)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Drag = 4
	emitter.Rate = 0
	emitter.Parent = attachment
	emitter:Emit(count)
	Debris:AddItem(attachment, 1.2)
end

local function addShake(position: Vector3, strength: number)
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local dist = (camera.CFrame.Position - position).Magnitude
	shake = math.max(shake, strength * math.clamp(1 - dist / 120, 0, 1))
end

---------------------------------------------------------------------------
-- Projectiles
---------------------------------------------------------------------------

local function buildProjectile(vis: { [string]: any }): (Part, number, boolean)
	local c = rgb(vis.c)
	local c2 = rgb(vis.c2, c)
	local s = math.max(0.3, vis.s or 1)
	local form = vis.f
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
	elseif form == "Meteor" then
		part = ball(Vector3.zero, s, c:Lerp(Color3.new(0, 0, 0), 0.6))
		part.Material = Enum.Material.Basalt
		local fire = Instance.new("Fire")
		fire.Size = s * 3
		fire.Heat = 12
		fire.Color = c
		fire.SecondaryColor = c2
		fire.Parent = part
	elseif form == "Orb" then
		part = ball(Vector3.zero, s, c, 0.25)
		local emitter = Instance.new("ParticleEmitter")
		emitter.Color = ColorSequence.new(c2)
		emitter.LightEmission = 1
		emitter.Size = NumberSequence.new(s * 0.35, 0)
		emitter.Lifetime = NumberRange.new(0.3, 0.6)
		emitter.Rate = 30
		emitter.Speed = NumberRange.new(1, 3)
		emitter.SpreadAngle = Vector2.new(180, 180)
		emitter.Parent = part
	elseif form == "Wisp" then
		part = ball(Vector3.zero, s, c, 0.1)
		local emitter = Instance.new("ParticleEmitter")
		emitter.Color = ColorSequence.new(c, c2)
		emitter.LightEmission = 1
		emitter.Size = NumberSequence.new(s * 0.6, 0)
		emitter.Transparency = NumberSequence.new(0.2, 1)
		emitter.Lifetime = NumberRange.new(0.4, 0.8)
		emitter.Rate = 40
		emitter.Speed = NumberRange.new(0, 1)
		emitter.Parent = part
	else
		part = ball(Vector3.zero, s, c)
	end

	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, s * 0.35, 0)
	a0.Parent = part
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -s * 0.35, 0)
	a1.Parent = part
	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Color = ColorSequence.new(c, c2)
	trail.Transparency = NumberSequence.new(0.15, 1)
	trail.LightEmission = 1
	trail.FaceCamera = true
	trail.Lifetime = if form == "Spark" then 0.1 elseif form == "Orb" or form == "Meteor" then 0.35 else 0.2
	trail.WidthScale = NumberSequence.new(1, 0)
	trail.Parent = part

	local light = Instance.new("PointLight")
	light.Color = c
	light.Range = math.clamp(s * 6, 4, 16)
	light.Brightness = 1.4
	light.Parent = part
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
	if kind == "impact" then
		local flash = ball(part.Position, part.Size.Y * 1.6 + 0.6, part.Color, 0.1)
		tweenAway(flash, 0.18, { Size = flash.Size * 2.2 })
		burst(part.Position, part.Color, 8, 12)
	end
	for _, child in part:GetChildren() do
		if child:IsA("ParticleEmitter") then
			child.Enabled = false
		elseif child:IsA("Fire") or child:IsA("Sparkles") or child:IsA("PointLight") then
			child:Destroy()
		end
	end
	part.Transparency = 1
	Debris:AddItem(part, 0.5)
end

local function stepProjectiles(dt: number)
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
		if p.state.age > p.life + 2 then
			removeProjectile(id, nil, nil)
		end
	end
end

---------------------------------------------------------------------------
-- One-shot effects
---------------------------------------------------------------------------

local handlers: { [string]: (...any) -> () } = {}

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
		seed = seed,
	})
	local part, spin, flat = buildProjectile(vis)
	part.CFrame = CFrame.new(pos)
	projectiles[id] = {
		state = state,
		part = part,
		caster = caster,
		form = vis.f,
		life = vis.l or 3,
		spin = spin,
		visualPos = pos,
		flat = flat,
	}
end

handlers["P-"] = function(id: number, pos: Vector3, kind: string)
	removeProjectile(id, pos, kind)
end

handlers.Beam = function(points: { Vector3 }, c, c2, size: number)
	local color = rgb(c)
	local glow = rgb(c2, color)
	local width = math.clamp((size or 0.5) * 0.8, 0.25, 3)
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local length = (b - a).Magnitude
		if length > 0.05 then
			local cf = CFrame.lookAt(a:Lerp(b, 0.5), b)
			local core = fxPart({
				Size = Vector3.new(width, width, length),
				CFrame = cf,
				Color = Color3.new(1, 1, 1):Lerp(color, 0.4),
			})
			tweenAway(core, 0.22, { Size = Vector3.new(0.05, 0.05, length) })
			local outer = fxPart({
				Size = Vector3.new(width * 2.2, width * 2.2, length),
				CFrame = cf,
				Color = glow,
				Transparency = 0.55,
			})
			tweenAway(outer, 0.3, { Size = Vector3.new(0.1, 0.1, length) })
		end
	end
	local finish = points[#points]
	if finish then
		burst(finish, color, 10, 14)
	end
	Sounds.at("Cast", points[1], 0.8)
end

handlers.Boom = function(pos: Vector3, radius: number, c, c2)
	local color = rgb(c)
	local inner = ball(pos, 1, Color3.new(1, 1, 1):Lerp(color, 0.3), 0.05)
	tweenAway(inner, 0.25, { Size = Vector3.one * radius * 1.4 })
	local outer = ball(pos, 1, rgb(c2, color), 0.35)
	tweenAway(outer, 0.4, { Size = Vector3.one * radius * 2.1 })
	burst(pos, color, 30, radius * 3)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = radius * 3
	light.Brightness = 5
	light.Parent = inner
	local explosion = Instance.new("Explosion")
	explosion.Position = pos
	explosion.BlastPressure = 0
	explosion.BlastRadius = 0
	explosion.DestroyJointPercentage = 0
	explosion.Visible = false
	explosion.Parent = workspace
	Sounds.at("Boom", pos, math.clamp(radius / 10, 0.4, 1.2))
	addShake(pos, math.clamp(radius / 10, 0.3, 1.2))
end

handlers.Nova = function(pos: Vector3, radius: number, c, c2)
	local color = rgb(c)
	local ring = fxPart({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.6, 2, 2),
		CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90)),
		Color = color,
		Transparency = 0.1,
	})
	tweenAway(ring, 0.35, { Size = Vector3.new(0.2, radius * 2, radius * 2) })
	local dome = ball(pos, 2, rgb(c2, color), 0.5)
	tweenAway(dome, 0.3, { Size = Vector3.one * radius * 1.8 })
	burst(pos, color, 24, radius * 2.5)
	addShake(pos, 0.5)
	Sounds.at("Boom", pos, 0.6)
end

local function lightning(a: Vector3, b: Vector3, color: Color3, width: number, life: number)
	local segments = math.clamp(math.floor((b - a).Magnitude / 4), 2, 10)
	local last = a
	for i = 1, segments do
		local alpha = i / segments
		local point = a:Lerp(b, alpha)
		if i < segments then
			point += Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1), rng:NextNumber(-1, 1)) * 1.4
		end
		local length = (point - last).Magnitude
		if length > 0.05 then
			local seg = fxPart({
				Size = Vector3.new(width, width, length),
				CFrame = CFrame.lookAt(last:Lerp(point, 0.5), point),
				Color = color,
			})
			tweenAway(seg, life, {})
		end
		last = point
	end
end

handlers.Chain = function(points: { Vector3 }, c, c2, width: number)
	local color = rgb(c)
	local glow = rgb(c2, color)
	for i = 1, #points - 1 do
		lightning(points[i], points[i + 1], color, math.clamp(width or 0.35, 0.15, 1), 0.22)
		lightning(points[i], points[i + 1], glow, 0.15, 0.15)
		burst(points[i + 1], color, 6, 10)
	end
	if points[1] then
		Sounds.at("Hitmarker", points[1], 0.7)
	end
end

handlers.Zone = function(_id: number, pos: Vector3, radius: number, duration: number, c, c2, _element)
	local color = rgb(c)
	local disc = fxPart({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.3, radius * 2, radius * 2),
		CFrame = CFrame.new(pos + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = color,
		Transparency = 0.65,
		Material = Enum.Material.ForceField,
	})
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(color, rgb(c2, color))
	emitter.LightEmission = 0.6
	emitter.Size = NumberSequence.new(1.2, 0)
	emitter.Transparency = NumberSequence.new(0.3, 1)
	emitter.Lifetime = NumberRange.new(0.8, 1.6)
	emitter.Rate = math.clamp(radius * 4, 10, 80)
	emitter.Speed = NumberRange.new(1, 4)
	emitter.Acceleration = Vector3.new(0, 3, 0)
	emitter.EmissionDirection = Enum.NormalId.Right
	emitter.Shape = Enum.ParticleEmitterShape.Cylinder
	emitter.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
	emitter.Parent = disc
	task.delay(math.max(0, duration - 0.4), function()
		emitter.Enabled = false
		tweenAway(disc, 0.4, {})
	end)
end

handlers.Blink = function(from: Vector3, to: Vector3, c, c2)
	local color = rgb(c)
	for _, p in { from, to } do
		local puff = ball(p, 3, color, 0.2)
		tweenAway(puff, 0.35, { Size = Vector3.one * 7 })
		burst(p, rgb(c2, color), 16, 10)
	end
	lightning(from, to, color, 0.3, 0.3)
	Sounds.at("Blink", to)
end

handlers.Warn = function(pos: Vector3, radius: number, c)
	local ring = fxPart({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.2, radius * 2, radius * 2),
		CFrame = CFrame.new(pos + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = rgb(c):Lerp(Color3.fromRGB(255, 40, 40), 0.5),
		Transparency = 0.5,
	})
	tweenAway(ring, 0.9, { Size = Vector3.new(0.2, radius * 0.5, radius * 0.5) })
end

handlers.Vortex = function(pos: Vector3, radius: number, c, _c2)
	local ring = fxPart({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.4, radius * 2.4, radius * 2.4),
		CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90)),
		Color = rgb(c),
		Transparency = 0.3,
	})
	tweenAway(ring, 0.4, { Size = Vector3.new(0.4, 1, 1) })
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

handlers.Cast = function(model: Model?, c)
	local pos = tipOf(model)
	if not pos then
		return
	end
	local flash = ball(pos, 0.6, rgb(c), 0)
	tweenAway(flash, 0.14, { Size = Vector3.one * 1.8 })
	if model == player.Character then
		Sounds.play("Cast", 0.2)
	else
		Sounds.at("Cast", pos, 0.6)
	end
end

handlers.Shield = function(model: Model?, c)
	local root = model and model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		local flash = ball(root.Position, 4, rgb(c), 0.3)
		tweenAway(flash, 0.3, { Size = Vector3.one * 9 })
	end
end

handlers.Potion = function(model: Model?, c)
	local root = model and model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		burst(root.Position, rgb(c), 20, 6)
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
	folder = f

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
