-- Builds familiar models out of parts (no meshes needed) and poses them every frame: flapping
-- wings, wagging tails, swaying tentacles, slithering eels, orbiting crystal shards.
-- Rarer familiars get grander effects: a glow from Rare, sparkles from Epic, an elemental aura
-- from Legendary and a trail at Mythic. Shiny ones shed golden sparkles.
-- Used by FamiliarController (familiars following characters) and the Wardrobe preview.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Familiars = require(Shared.Familiars)
local Rarity = require(Shared.Rarity)
local VFX = require(script.Parent.VFX)

local FamiliarBuilder = {}

export type Piece = {
	part: BasePart,
	pivot: CFrame, -- joint, relative to the familiar's origin (its feet / centre)
	offset: CFrame, -- the part, relative to its joint
	anim: string?,
	phase: number,
	speed: number,
}

export type Rig = {
	model: Model,
	pieces: { Piece },
	core: BasePart, -- the main body part (effects hang off it)
	flies: boolean,
	height: number, -- roughly how tall it is
	look: Familiars.Look,
}

local M = Enum.Material

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

---------------------------------------------------------------------------
-- Construction helpers
---------------------------------------------------------------------------

type Ctx = {
	rig: Rig,
	s: number, -- scale
	main: Color3,
	accent: Color3,
	eye: Color3,
	glowEyes: boolean,
}

type PieceOptions = {
	shape: string?, -- "Ball" | "Block" | "Cylinder" | "Wedge"
	material: Enum.Material?,
	transparency: number?,
	anim: string?,
	phase: number?,
	speed: number?,
	pivot: Vector3?, -- joint position (default: at the part)
	rot: Vector3?, -- extra rotation of the part, in degrees
}

local function piece(ctx: Ctx, name: string, size: Vector3, pos: Vector3, color: Color3, o: PieceOptions?): BasePart
	local opts: PieceOptions = o or {}
	local s = ctx.s
	local part: BasePart
	if opts.shape == "Wedge" then
		part = Instance.new("WedgePart")
	else
		local p = Instance.new("Part")
		if opts.shape == "Ball" then
			p.Shape = Enum.PartType.Ball
		elseif opts.shape == "Cylinder" then
			p.Shape = Enum.PartType.Cylinder
		end
		part = p
	end
	part.Name = name
	part.Size = size * s
	part.Color = color
	part.Material = opts.material or M.SmoothPlastic
	part.Transparency = opts.transparency or 0
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Parent = ctx.rig.model
	local pivotPos = (opts.pivot or pos) * s
	local rot = opts.rot or Vector3.zero
	table.insert(ctx.rig.pieces, {
		part = part,
		pivot = CFrame.new(pivotPos),
		offset = CFrame.new(pos * s - pivotPos) * CFrame.Angles(math.rad(rot.X), math.rad(rot.Y), math.rad(rot.Z)),
		anim = opts.anim,
		phase = opts.phase or 0,
		speed = opts.speed or 1,
	})
	return part
end

local function ball(ctx: Ctx, name: string, size: Vector3, pos: Vector3, color: Color3, o: PieceOptions?): BasePart
	local opts: PieceOptions = o or {}
	opts.shape = "Ball"
	return piece(ctx, name, size, pos, color, opts)
end

-- A pair of eyes, mirrored on X. Glowing (neon) for fancy familiars.
local function eyes(ctx: Ctx, pos: Vector3, size: number)
	for side = -1, 1, 2 do
		ball(ctx, "Eye", Vector3.one * size, Vector3.new(pos.X * side, pos.Y, pos.Z), ctx.eye, {
			material = if ctx.glowEyes then M.Neon else M.SmoothPlastic,
		})
	end
end

local function wings(
	ctx: Ctx,
	size: Vector3,
	joint: Vector3,
	reach: number,
	color: Color3,
	speed: number,
	o: { shape: string?, material: Enum.Material?, transparency: number?, back: number? }?
)
	local opts = o or {}
	for side = -1, 1, 2 do
		piece(ctx, "Wing", size, Vector3.new((joint.X + reach) * side, joint.Y, joint.Z + (opts.back or 0)), color, {
			shape = opts.shape or "Ball",
			material = opts.material,
			transparency = opts.transparency,
			pivot = Vector3.new(joint.X * side, joint.Y, joint.Z),
			anim = if side < 0 then "flapL" else "flapR",
			speed = speed,
		})
	end
end

local function legs(ctx: Ctx, size: Vector3, xs: number, zs: { number }, y: number, color: Color3)
	for i, z in zs do
		for side = -1, 1, 2 do
			piece(ctx, "Leg", size, Vector3.new(xs * side, y, z), color, {
				pivot = Vector3.new(xs * side, y + size.Y / 2, z),
				anim = "walk",
				phase = (if side < 0 then 0 else math.pi) + i * math.pi,
			})
		end
	end
end

local function emitterOn(ctx: Ctx, part: BasePart, opts: VFX.EmitterOptions): ParticleEmitter
	local scaled = table.clone(opts)
	scaled.size *= ctx.s
	if scaled.sizeEnd then
		scaled.sizeEnd *= ctx.s
	end
	return VFX.emitter(part, scaled)
end

local function flame(ctx: Ctx, part: BasePart, color: Color3, size: number)
	emitterOn(ctx, part, {
		texture = "fire",
		color = Color3.new(1, 1, 1):Lerp(color, 0.4),
		color2 = color,
		size = size,
		lifetime = 0.4,
		speed = 1.5,
		accel = Vector3.new(0, 6, 0),
		rate = 22,
		rot = 60,
		transparency = 0.1,
	})
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 6
	light.Brightness = 1.2
	light.Shadows = false
	light.Parent = part
end

---------------------------------------------------------------------------
-- Bodies. Origin = between the feet (walkers) or the centre (fliers); facing -Z.
---------------------------------------------------------------------------

local Bodies: { [string]: (ctx: Ctx) -> BasePart } = {}

Bodies.rabbit = function(ctx)
	local core = ball(ctx, "Body", Vector3.new(1, 0.8, 1.2), Vector3.new(0, 0.5, 0.05), ctx.main)
	ball(ctx, "Head", Vector3.one * 0.75, Vector3.new(0, 0.95, -0.5), ctx.main)
	for side = -1, 1, 2 do
		piece(ctx, "Ear", Vector3.new(0.17, 0.62, 0.1), Vector3.new(0.16 * side, 1.55, -0.42), ctx.main, {
			pivot = Vector3.new(0.14 * side, 1.25, -0.45),
			anim = "ear",
			phase = side,
			rot = Vector3.new(-10, 0, -12 * side),
		})
		piece(ctx, "EarInner", Vector3.new(0.09, 0.45, 0.04), Vector3.new(0.16 * side, 1.55, -0.48), ctx.accent, {
			pivot = Vector3.new(0.14 * side, 1.25, -0.45),
			anim = "ear",
			phase = side,
			rot = Vector3.new(-10, 0, -12 * side),
		})
	end
	eyes(ctx, Vector3.new(0.17, 1.02, -0.84), 0.13)
	ball(ctx, "Nose", Vector3.one * 0.09, Vector3.new(0, 0.92, -0.88), ctx.accent)
	ball(ctx, "Tail", Vector3.one * 0.32, Vector3.new(0, 0.6, 0.66), Color3.new(1, 1, 1), { anim = "wag" })
	legs(ctx, Vector3.new(0.22, 0.25, 0.32), 0.25, { -0.3, 0.35 }, 0.12, ctx.main)
	return core
end

Bodies.toad = function(ctx)
	local core = ball(ctx, "Body", Vector3.new(1.3, 0.8, 1.1), Vector3.new(0, 0.42, 0), ctx.main)
	ball(ctx, "Belly", Vector3.new(1, 0.5, 0.8), Vector3.new(0, 0.3, -0.18), ctx.accent)
	for side = -1, 1, 2 do
		ball(ctx, "EyeBump", Vector3.one * 0.36, Vector3.new(0.3 * side, 0.82, -0.32), ctx.main)
		ball(ctx, "Leg", Vector3.new(0.42, 0.3, 0.62), Vector3.new(0.58 * side, 0.16, 0.18), ctx.main, {
			anim = "walk",
			phase = side,
		})
	end
	eyes(ctx, Vector3.new(0.3, 0.88, -0.46), 0.17)
	piece(ctx, "Mouth", Vector3.new(0.62, 0.04, 0.05), Vector3.new(0, 0.5, -0.54), Color3.fromRGB(40, 30, 30))
	return core
end

Bodies.mouse = function(ctx)
	local core = ball(ctx, "Body", Vector3.new(0.8, 0.65, 1.1), Vector3.new(0, 0.36, 0), ctx.main)
	ball(ctx, "Head", Vector3.one * 0.56, Vector3.new(0, 0.52, -0.56), ctx.main)
	for side = -1, 1, 2 do
		piece(ctx, "Ear", Vector3.new(0.05, 0.36, 0.36), Vector3.new(0.22 * side, 0.82, -0.5), ctx.accent, {
			shape = "Cylinder",
			rot = Vector3.new(0, 90, 0),
			anim = "ear",
			phase = side,
		})
	end
	eyes(ctx, Vector3.new(0.13, 0.58, -0.8), 0.1)
	ball(ctx, "Nose", Vector3.one * 0.09, Vector3.new(0, 0.5, -0.86), ctx.accent)
	piece(ctx, "Tail", Vector3.new(0.06, 0.06, 0.9), Vector3.new(0, 0.3, 0.95), ctx.accent, {
		pivot = Vector3.new(0, 0.3, 0.5),
		anim = "wag",
	})
	piece(ctx, "Candle", Vector3.new(0.38, 0.2, 0.2), Vector3.new(0, 0.98, -0.5), Color3.fromRGB(250, 240, 215), {
		shape = "Cylinder",
		rot = Vector3.new(0, 0, 90),
	})
	local wick =
		ball(ctx, "Flame", Vector3.new(0.14, 0.22, 0.14), Vector3.new(0, 1.28, -0.5), Color3.fromRGB(255, 190, 80), {
			material = M.Neon,
		})
	flame(ctx, wick, Color3.fromRGB(255, 150, 50), 0.25)
	legs(ctx, Vector3.new(0.14, 0.18, 0.18), 0.22, { -0.25, 0.3 }, 0.08, ctx.accent)
	return core
end

Bodies.wisp = function(ctx)
	local core = ball(ctx, "Core", Vector3.one * 0.6, Vector3.zero, ctx.main:Lerp(Color3.new(1, 1, 1), 0.4), {
		material = M.Neon,
	})
	ball(ctx, "Shell", Vector3.one * 1.05, Vector3.zero, ctx.main, { material = M.ForceField, transparency = 0.1 })
	eyes(ctx, Vector3.new(0.12, 0.06, -0.28), 0.1)
	for i = 1, 3 do
		ball(ctx, "Mote", Vector3.one * 0.14, Vector3.new(0.7, 0, 0), ctx.accent, {
			material = M.Neon,
			pivot = Vector3.zero,
			anim = "orbit",
			phase = i * math.pi * 2 / 3,
			speed = 1.6,
		})
	end
	local light = Instance.new("PointLight")
	light.Color = ctx.main
	light.Range = 7
	light.Brightness = 1
	light.Shadows = false
	light.Parent = core
	return core
end

local function catLike(ctx: Ctx, snout: boolean, fireTail: boolean): BasePart
	local core = ball(ctx, "Body", Vector3.new(0.8, 0.75, 1.3), Vector3.new(0, 0.62, 0.05), ctx.main)
	ball(ctx, "Belly", Vector3.new(0.6, 0.5, 0.95), Vector3.new(0, 0.5, -0.05), ctx.accent)
	ball(ctx, "Head", Vector3.one * 0.7, Vector3.new(0, 1.05, -0.62), ctx.main)
	for side = -1, 1, 2 do
		piece(ctx, "Ear", Vector3.new(0.12, 0.32, 0.24), Vector3.new(0.21 * side, 1.46, -0.6), ctx.main, {
			shape = "Wedge",
			rot = Vector3.new(0, if side < 0 then 90 else -90, 0),
			anim = "ear",
			phase = side,
		})
	end
	eyes(ctx, Vector3.new(0.15, 1.1, -0.93), 0.12)
	if snout then
		piece(ctx, "Snout", Vector3.new(0.3, 0.22, 0.38), Vector3.new(0, 0.95, -1.02), ctx.accent)
		ball(ctx, "Nose", Vector3.one * 0.1, Vector3.new(0, 1.02, -1.2), Color3.fromRGB(30, 25, 25))
	else
		ball(ctx, "Nose", Vector3.one * 0.08, Vector3.new(0, 1, -0.97), ctx.accent)
	end
	if fireTail then
		ball(ctx, "Tail", Vector3.new(0.42, 0.42, 0.95), Vector3.new(0, 0.85, 0.95), ctx.main, {
			pivot = Vector3.new(0, 0.7, 0.55),
			anim = "wag",
			rot = Vector3.new(25, 0, 0),
		})
		local tip = ball(ctx, "TailTip", Vector3.one * 0.3, Vector3.new(0, 1.05, 1.35), ctx.accent, {
			material = M.Neon,
			pivot = Vector3.new(0, 0.7, 0.55),
			anim = "wag",
		})
		flame(ctx, tip, ctx.main, 0.4)
	else
		piece(ctx, "Tail", Vector3.new(0.13, 0.13, 0.8), Vector3.new(0, 1.02, 0.85), ctx.main, {
			pivot = Vector3.new(0, 0.75, 0.55),
			anim = "wag",
			rot = Vector3.new(40, 0, 0),
		})
	end
	legs(ctx, Vector3.new(0.17, 0.42, 0.17), 0.25, { -0.4, 0.42 }, 0.21, ctx.main)
	return core
end

Bodies.cat = function(ctx)
	return catLike(ctx, false, false)
end

Bodies.fox = function(ctx)
	return catLike(ctx, true, true)
end

Bodies.crane = function(ctx)
	local core = piece(ctx, "Body", Vector3.new(0.45, 0.4, 1), Vector3.zero, ctx.main, { shape = "Wedge" })
	piece(ctx, "Neck", Vector3.new(0.14, 0.55, 0.3), Vector3.new(0, 0.38, -0.55), ctx.main, {
		shape = "Wedge",
		rot = Vector3.new(0, 180, 0),
	})
	piece(ctx, "Head", Vector3.new(0.14, 0.18, 0.35), Vector3.new(0, 0.7, -0.75), ctx.accent, {
		shape = "Wedge",
		rot = Vector3.new(0, 180, 0),
	})
	piece(ctx, "Tail", Vector3.new(0.14, 0.35, 0.5), Vector3.new(0, 0.2, 0.65), ctx.main, { shape = "Wedge" })
	wings(ctx, Vector3.new(0.9, 0.05, 0.62), Vector3.new(0.18, 0.12, 0), 0.45, ctx.main, 1.4, { shape = "Block" })
	return core
end

Bodies.slime = function(ctx)
	local core = ball(ctx, "Body", Vector3.new(1.2, 0.9, 1.2), Vector3.new(0, 0.45, 0), ctx.main, {
		material = M.Glass,
		transparency = 0.25,
	})
	ball(ctx, "Core", Vector3.one * 0.4, Vector3.new(0, 0.45, 0.05), ctx.accent, { material = M.Neon })
	eyes(ctx, Vector3.new(0.2, 0.58, -0.52), 0.14)
	ball(ctx, "Shine", Vector3.new(0.18, 0.12, 0.1), Vector3.new(-0.3, 0.75, -0.42), Color3.new(1, 1, 1), {
		material = M.Neon,
	})
	return core
end

Bodies.moth = function(ctx)
	local core = ball(ctx, "Body", Vector3.new(0.3, 0.3, 0.85), Vector3.zero, ctx.main)
	ball(ctx, "Head", Vector3.one * 0.3, Vector3.new(0, 0.05, -0.48), Color3.new(1, 1, 1))
	eyes(ctx, Vector3.new(0.09, 0.08, -0.6), 0.09)
	for side = -1, 1, 2 do
		piece(ctx, "Antenna", Vector3.new(0.04, 0.04, 0.4), Vector3.new(0.1 * side, 0.25, -0.7), ctx.accent, {
			rot = Vector3.new(35, 20 * side, 0),
		})
	end
	wings(ctx, Vector3.new(0.95, 0.04, 0.75), Vector3.new(0.12, 0.05, -0.1), 0.45, ctx.main, 0.8, {
		transparency = 0.05,
	})
	wings(ctx, Vector3.new(0.6, 0.04, 0.5), Vector3.new(0.1, 0.03, 0.25), 0.3, ctx.main, 0.8, { back = 0.15 })
	wings(ctx, Vector3.new(0.28, 0.06, 0.28), Vector3.new(0.12, 0.07, -0.1), 0.55, ctx.accent, 0.8, {
		material = M.Neon,
	})
	return core
end

Bodies.owl = function(ctx)
	local core = ball(ctx, "Body", Vector3.new(0.9, 1.1, 0.85), Vector3.zero, ctx.main)
	ball(ctx, "Face", Vector3.new(0.72, 0.6, 0.2), Vector3.new(0, 0.2, -0.36), ctx.main:Lerp(Color3.new(1, 1, 1), 0.5))
	for side = -1, 1, 2 do
		ball(ctx, "EyeRing", Vector3.new(0.3, 0.3, 0.08), Vector3.new(0.17 * side, 0.25, -0.46), ctx.accent, {
			material = M.Neon,
		})
		piece(ctx, "Tuft", Vector3.new(0.1, 0.28, 0.2), Vector3.new(0.27 * side, 0.6, -0.2), ctx.main, {
			shape = "Wedge",
			rot = Vector3.new(0, 180, -15 * side),
		})
	end
	eyes(ctx, Vector3.new(0.17, 0.25, -0.5), 0.13)
	piece(ctx, "Beak", Vector3.new(0.1, 0.16, 0.12), Vector3.new(0, 0.08, -0.5), Color3.fromRGB(230, 180, 90), {
		shape = "Wedge",
		rot = Vector3.new(180, 0, 0),
	})
	wings(ctx, Vector3.new(0.85, 0.07, 0.55), Vector3.new(0.4, 0.05, 0.05), 0.4, ctx.main, 1.1)
	return core
end

Bodies.book = function(ctx)
	local core = piece(ctx, "Spine", Vector3.new(0.18, 0.18, 1.15), Vector3.zero, ctx.accent, { material = M.Metal })
	for side = -1, 1, 2 do
		local anim = if side < 0 then "pagesL" else "pagesR"
		piece(ctx, "Cover", Vector3.new(0.75, 0.07, 1.15), Vector3.new(0.38 * side, 0, 0), ctx.main, {
			pivot = Vector3.zero,
			anim = anim,
		})
		piece(
			ctx,
			"Pages",
			Vector3.new(0.65, 0.12, 1.02),
			Vector3.new(0.34 * side, 0.08, 0),
			Color3.fromRGB(245, 235, 210),
			{
				pivot = Vector3.zero,
				anim = anim,
			}
		)
		piece(ctx, "Corner", Vector3.new(0.14, 0.08, 0.14), Vector3.new(0.68 * side, -0.01, -0.52), ctx.accent, {
			pivot = Vector3.zero,
			anim = anim,
			material = M.Metal,
		})
	end
	ball(ctx, "Eye", Vector3.one * 0.26, Vector3.new(0, 0.12, -0.45), ctx.accent, { material = M.Neon })
	ball(ctx, "Pupil", Vector3.one * 0.12, Vector3.new(0, 0.14, -0.56), Color3.fromRGB(20, 15, 20))
	return core
end

Bodies.eel = function(ctx)
	local head = ball(ctx, "Head", Vector3.new(0.45, 0.42, 0.6), Vector3.new(0, 0, -0.35), ctx.main, {
		anim = "slither",
		phase = 0,
	})
	eyes(ctx, Vector3.new(0.14, 0.1, -0.6), 0.1)
	for i = 1, 6 do
		local size = 0.42 - i * 0.04
		ball(ctx, "Segment", Vector3.one * size, Vector3.new(0, 0, i * 0.32), ctx.main, {
			anim = "slither",
			phase = i * 0.8,
		})
		if i % 2 == 0 then
			piece(ctx, "Fin", Vector3.new(0.05, 0.22, 0.25), Vector3.new(0, size * 0.55, i * 0.32), ctx.accent, {
				shape = "Wedge",
				anim = "slither",
				phase = i * 0.8,
				material = M.Neon,
			})
		end
	end
	piece(ctx, "TailFin", Vector3.new(0.05, 0.35, 0.3), Vector3.new(0, 0, 2.2), ctx.accent, {
		shape = "Wedge",
		anim = "slither",
		phase = 7 * 0.8,
		material = M.Neon,
	})
	return head
end

Bodies.crystal = function(ctx)
	local core = piece(ctx, "Heart", Vector3.new(0.5, 0.75, 0.5), Vector3.zero, ctx.main, {
		material = M.Glass,
		transparency = 0.15,
		rot = Vector3.new(0, 45, 0),
		anim = "spin",
		speed = 0.5,
		pivot = Vector3.zero,
	})
	ball(ctx, "Glow", Vector3.one * 0.28, Vector3.zero, ctx.accent, { material = M.Neon })
	eyes(ctx, Vector3.new(0.09, 0.1, -0.24), 0.08)
	for i = 1, 4 do
		piece(ctx, "Shard", Vector3.new(0.18, 0.42, 0.18), Vector3.new(0.75, math.sin(i) * 0.15, 0), ctx.main, {
			material = M.Glass,
			transparency = 0.1,
			pivot = Vector3.zero,
			anim = "orbit",
			phase = i * math.pi / 2,
			speed = 1.2,
			rot = Vector3.new(0, 45, 15),
		})
	end
	return core
end

Bodies.jelly = function(ctx)
	local core = ball(ctx, "Bell", Vector3.new(1.1, 0.75, 1.1), Vector3.new(0, 0.3, 0), ctx.main, {
		material = M.Glass,
		transparency = 0.3,
		anim = "pulse",
	})
	ball(ctx, "Glow", Vector3.one * 0.4, Vector3.new(0, 0.3, 0), ctx.accent, { material = M.Neon, anim = "pulse" })
	eyes(ctx, Vector3.new(0.18, 0.32, -0.48), 0.1)
	for i = 1, 6 do
		local a = i / 6 * math.pi * 2
		local x, z = math.cos(a) * 0.32, math.sin(a) * 0.32
		piece(ctx, "Tentacle", Vector3.new(0.07, 0.95, 0.07), Vector3.new(x, -0.45, z), ctx.accent, {
			pivot = Vector3.new(x, 0.02, z),
			anim = "sway",
			phase = i,
			transparency = 0.15,
		})
	end
	return core
end

Bodies.raven = function(ctx)
	local core = ball(ctx, "Body", Vector3.new(0.6, 0.6, 1), Vector3.zero, ctx.main)
	ball(ctx, "Head", Vector3.one * 0.45, Vector3.new(0, 0.25, -0.55), ctx.main)
	piece(ctx, "Beak", Vector3.new(0.12, 0.12, 0.3), Vector3.new(0, 0.22, -0.85), Color3.fromRGB(50, 50, 55), {
		shape = "Wedge",
		rot = Vector3.new(0, 180, 0),
	})
	eyes(ctx, Vector3.new(0.13, 0.32, -0.7), 0.09)
	piece(ctx, "Tail", Vector3.new(0.4, 0.07, 0.55), Vector3.new(0, 0, 0.7), ctx.main, { anim = "wag" })
	wings(ctx, Vector3.new(1.05, 0.07, 0.55), Vector3.new(0.25, 0.1, 0), 0.5, ctx.main, 1.3)
	return core
end

Bodies.skull = function(ctx)
	local core = ball(ctx, "Cranium", Vector3.new(0.85, 0.8, 0.85), Vector3.new(0, 0.1, 0), ctx.main)
	piece(ctx, "Jaw", Vector3.new(0.55, 0.2, 0.45), Vector3.new(0, -0.32, -0.12), ctx.main, { anim = "chatter" })
	for side = -1, 1, 2 do
		ball(ctx, "Socket", Vector3.one * 0.26, Vector3.new(0.18 * side, 0.1, -0.33), Color3.fromRGB(15, 10, 15))
	end
	ball(ctx, "Glint", Vector3.one * 0.1, Vector3.new(0.18, 0.1, -0.44), ctx.accent, { material = M.Neon })
	ball(ctx, "Glint", Vector3.one * 0.1, Vector3.new(-0.18, 0.1, -0.44), ctx.accent, { material = M.Neon })
	piece(ctx, "Nose", Vector3.new(0.12, 0.14, 0.08), Vector3.new(0, -0.08, -0.4), Color3.fromRGB(15, 10, 15), {
		shape = "Wedge",
	})
	return core
end

Bodies.dragon = function(ctx)
	local head = ball(ctx, "Head", Vector3.new(0.55, 0.45, 0.7), Vector3.new(0, 0.15, -0.55), ctx.main, {
		anim = "slither",
		phase = 0,
		speed = 0.6,
	})
	piece(ctx, "Snout", Vector3.new(0.35, 0.25, 0.35), Vector3.new(0, 0.08, -0.95), ctx.main, {
		anim = "slither",
		phase = 0,
		speed = 0.6,
	})
	for side = -1, 1, 2 do
		piece(ctx, "Horn", Vector3.new(0.08, 0.3, 0.25), Vector3.new(0.16 * side, 0.45, -0.4), ctx.accent, {
			shape = "Wedge",
			rot = Vector3.new(-30, 0, 0),
			anim = "slither",
			phase = 0,
			speed = 0.6,
		})
	end
	eyes(ctx, Vector3.new(0.17, 0.24, -0.82), 0.1)
	for i = 1, 4 do
		local size = 0.58 - i * 0.08
		ball(ctx, "Segment", Vector3.one * size, Vector3.new(0, 0, i * 0.4), ctx.main, {
			anim = "slither",
			phase = i * 0.8,
			speed = 0.6,
		})
		ball(
			ctx,
			"Belly",
			Vector3.new(size * 0.7, size * 0.5, size * 0.8),
			Vector3.new(0, -size * 0.25, i * 0.4),
			ctx.accent,
			{
				anim = "slither",
				phase = i * 0.8,
				speed = 0.6,
			}
		)
	end
	piece(ctx, "TailTip", Vector3.new(0.06, 0.3, 0.35), Vector3.new(0, 0, 2), ctx.accent, {
		shape = "Wedge",
		anim = "slither",
		phase = 5 * 0.8,
		speed = 0.6,
	})
	wings(
		ctx,
		Vector3.new(1.2, 0.06, 0.8),
		Vector3.new(0.25, 0.25, 0.3),
		0.6,
		ctx.main:Lerp(Color3.new(0, 0, 0), 0.2),
		0.55,
		{
			shape = "Wedge",
		}
	)
	return head
end

Bodies.phoenix = function(ctx)
	local core = ball(ctx, "Body", Vector3.new(0.6, 0.6, 0.9), Vector3.zero, ctx.main, { material = M.Neon })
	ball(ctx, "Head", Vector3.one * 0.42, Vector3.new(0, 0.28, -0.5), ctx.main, { material = M.Neon })
	piece(ctx, "Beak", Vector3.new(0.1, 0.1, 0.22), Vector3.new(0, 0.25, -0.75), ctx.accent, {
		shape = "Wedge",
		rot = Vector3.new(0, 180, 0),
	})
	eyes(ctx, Vector3.new(0.12, 0.34, -0.66), 0.08)
	for i = -1, 1 do
		piece(
			ctx,
			"Crest",
			Vector3.new(0.06, 0.3, 0.18),
			Vector3.new(i * 0.07, 0.55, -0.42 + math.abs(i) * 0.06),
			ctx.accent,
			{
				shape = "Wedge",
				material = M.Neon,
				rot = Vector3.new(-20, 0, i * 15),
			}
		)
		piece(ctx, "TailFeather", Vector3.new(0.12, 0.05, 1), Vector3.new(i * 0.2, -0.05, 0.9), ctx.accent, {
			material = M.Neon,
			pivot = Vector3.new(0, 0, 0.4),
			anim = "wag",
			rot = Vector3.new(0, i * 18, 0),
		})
	end
	wings(ctx, Vector3.new(1, 0.06, 0.55), Vector3.new(0.25, 0.1, 0), 0.5, ctx.main, 1.2, { material = M.Neon })
	flame(ctx, core, ctx.main, 0.5)
	return core
end

Bodies.kirin = function(ctx)
	local core = ball(ctx, "Body", Vector3.new(0.8, 0.75, 1.4), Vector3.new(0, 0.95, 0.05), ctx.main)
	piece(
		ctx,
		"Neck",
		Vector3.new(0.35, 0.6, 0.35),
		Vector3.new(0, 1.35, -0.55),
		ctx.main,
		{ rot = Vector3.new(-25, 0, 0) }
	)
	ball(ctx, "Head", Vector3.new(0.42, 0.42, 0.65), Vector3.new(0, 1.65, -0.8), ctx.main)
	piece(ctx, "Horn", Vector3.new(0.4, 0.09, 0.09), Vector3.new(0, 2, -0.85), ctx.accent, {
		shape = "Cylinder",
		material = M.Neon,
		rot = Vector3.new(0, 0, 75),
	})
	eyes(ctx, Vector3.new(0.15, 1.72, -0.98), 0.08)
	for i = 0, 3 do
		piece(ctx, "Mane", Vector3.new(0.08, 0.28, 0.2), Vector3.new(0, 1.62 - i * 0.18, -0.5 + i * 0.12), ctx.accent, {
			shape = "Wedge",
			material = M.Neon,
			rot = Vector3.new(0, 180, 0),
		})
	end
	piece(ctx, "Tail", Vector3.new(0.12, 0.12, 0.75), Vector3.new(0, 1.05, 0.95), ctx.accent, {
		material = M.Neon,
		pivot = Vector3.new(0, 1.1, 0.7),
		anim = "wag",
		rot = Vector3.new(-30, 0, 0),
	})
	legs(ctx, Vector3.new(0.15, 0.65, 0.15), 0.25, { -0.45, 0.5 }, 0.33, ctx.main)
	for i, z in { -0.45, 0.5 } do
		for side = -1, 1, 2 do
			piece(ctx, "Hoof", Vector3.new(0.18, 0.08, 0.18), Vector3.new(0.25 * side, 0.04, z), ctx.accent, {
				pivot = Vector3.new(0.25 * side, 0.66, z),
				anim = "walk",
				phase = (if side < 0 then 0 else math.pi) + i * math.pi,
				material = M.Neon,
			})
		end
	end
	return core
end

Bodies.whale = function(ctx)
	local core = ball(ctx, "Body", Vector3.new(1.5, 1, 2.3), Vector3.zero, ctx.main, { anim = "swim" })
	ball(
		ctx,
		"Belly",
		Vector3.new(1.15, 0.6, 1.9),
		Vector3.new(0, -0.25, -0.1),
		ctx.main:Lerp(Color3.new(1, 1, 1), 0.35),
		{
			anim = "swim",
		}
	)
	eyes(ctx, Vector3.new(0.55, 0.05, -0.8), 0.12)
	for side = -1, 1, 2 do
		piece(ctx, "Fin", Vector3.new(0.6, 0.06, 0.35), Vector3.new(0.85 * side, -0.25, -0.2), ctx.main, {
			shape = "Ball",
			pivot = Vector3.new(0.6 * side, -0.2, -0.2),
			anim = if side < 0 then "flapL" else "flapR",
			speed = 0.35,
		})
		piece(ctx, "Fluke", Vector3.new(0.6, 0.07, 0.45), Vector3.new(0.3 * side, 0.1, 1.45), ctx.main, {
			shape = "Ball",
			pivot = Vector3.new(0, 0.05, 1.1),
			anim = "fluke",
			rot = Vector3.new(0, -20 * side, 0),
		})
	end
	-- a constellation on its back
	for i = 1, 7 do
		local z = -0.8 + i * 0.25
		ball(
			ctx,
			"Star",
			Vector3.one * 0.09,
			Vector3.new(math.sin(i * 2.1) * 0.35, 0.46 - math.abs(z) * 0.12, z),
			ctx.accent,
			{
				material = M.Neon,
				anim = "swim",
			}
		)
	end
	return core
end

---------------------------------------------------------------------------
-- Rarity and shiny effects
---------------------------------------------------------------------------

local function addEffects(ctx: Ctx, core: BasePart, look: Familiars.Look, species: Familiars.Species)
	local r = Rarity.rank(look.rarity)
	local main, accent = ctx.main, ctx.accent
	local style = VFX.style(species.element)
	if r >= 3 then
		local light = Instance.new("PointLight")
		light.Name = "RarityGlow"
		light.Color = accent:Lerp(main, 0.5)
		light.Range = 5 + r * 1.5
		light.Brightness = 0.4 + (r - 3) * 0.35
		light.Shadows = false
		light.Parent = core
	end
	if r >= 4 then
		emitterOn(ctx, core, {
			color = Color3.new(1, 1, 1),
			color2 = accent,
			size = 0.22,
			lifetime = 1,
			speed = 0.8,
			rate = 3 + (r - 4) * 3,
			rot = 120,
		})
	end
	if r >= 5 then
		local smoke = style.texture == "smoke"
		emitterOn(ctx, core, {
			texture = style.texture,
			color = main,
			color2 = accent,
			size = if smoke then 0.5 else 0.35,
			sizeEnd = if smoke then 0.9 else 0,
			transparency = if smoke then 0.5 else 0.1,
			lifetime = 0.9,
			speed = 0.8,
			accel = Vector3.new(0, style.rise * 0.3, 0),
			drag = 2,
			rate = if r >= 6 then 16 else 8,
			light = if smoke then 0.2 else 1,
			rot = style.spin,
		})
	end
	if r >= 6 then
		local a0 = Instance.new("Attachment")
		a0.Position = Vector3.new(0, 0.25 * ctx.s, 0)
		a0.Parent = core
		local a1 = Instance.new("Attachment")
		a1.Position = Vector3.new(0, -0.25 * ctx.s, 0)
		a1.Parent = core
		local trail = Instance.new("Trail")
		trail.Name = "MythicTrail"
		trail.Attachment0 = a0
		trail.Attachment1 = a1
		trail.Color = ColorSequence.new(accent, main)
		trail.Transparency = NumberSequence.new(0.3, 1)
		trail.LightEmission = 1
		trail.FaceCamera = true
		trail.Lifetime = 0.5
		trail.Parent = core
	end
	if look.shiny then
		emitterOn(ctx, core, {
			color = Color3.fromRGB(255, 225, 120),
			color2 = Color3.new(1, 1, 1),
			size = 0.3,
			lifetime = 0.8,
			speed = 1.2,
			rate = 7,
			rot = 200,
		}).Name =
			"ShinySparkles"
	end
end

---------------------------------------------------------------------------
-- API
---------------------------------------------------------------------------

-- Builds a familiar (a Model of anchored parts) under `parent`. `effects` adds particles and
-- lights (leave them off for previews in a ViewportFrame, which can't show them).
function FamiliarBuilder.build(look: Familiars.Look, parent: Instance, effects: boolean): Rig?
	local species = Familiars.SpeciesById[look.species]
	local body = species and Bodies[species.body]
	if not species or not body then
		return nil
	end
	local variant = Familiars.variantOf(look)
	local r = Rarity.rank(look.rarity)
	local model = Instance.new("Model")
	model.Name = "Familiar_" .. species.id
	local rig: Rig = {
		model = model,
		pieces = {},
		core = nil :: any,
		flies = species.flies,
		height = 1.4 * species.size,
		look = look,
	}
	local main = rgb(variant.rgb)
	if look.shiny then
		main = main:Lerp(Color3.fromRGB(255, 215, 110), 0.25)
	end
	local ctx: Ctx = {
		rig = rig,
		s = species.size * (0.85 + r * 0.04),
		main = main,
		accent = rgb(variant.accent),
		eye = if r >= 4 then rgb(variant.accent) else Color3.fromRGB(25, 20, 25),
		glowEyes = r >= 4,
	}
	rig.core = body(ctx)
	if effects then
		addEffects(ctx, rig.core, look, species)
	end
	model.PrimaryPart = rig.core
	model.Parent = parent
	return rig
end

local function animCF(p: Piece, t: number, moving: number): CFrame
	local a = p.anim
	if not a then
		return CFrame.identity
	end
	local tt = t * p.speed + p.phase
	if a == "flapL" then
		return CFrame.Angles(0, 0, -0.15 + math.sin(tt * 11) * 0.65)
	elseif a == "flapR" then
		return CFrame.Angles(0, 0, 0.15 - math.sin(tt * 11) * 0.65)
	elseif a == "wag" then
		return CFrame.Angles(0, math.sin(tt * 6) * (0.35 + moving * 0.2), 0)
	elseif a == "ear" then
		return CFrame.Angles(math.sin(tt * 2.2) * 0.12, 0, 0)
	elseif a == "walk" then
		return CFrame.Angles(math.sin(t * 11 + p.phase) * 0.7 * moving, 0, 0)
	elseif a == "sway" then
		return CFrame.Angles(math.sin(tt * 2.4) * 0.35, 0, math.cos(tt * 1.9) * 0.25)
	elseif a == "orbit" then
		return CFrame.Angles(0, tt, 0)
	elseif a == "spin" then
		return CFrame.Angles(0, tt, 0)
	elseif a == "slither" then
		return CFrame.new(math.sin(t * 4 * p.speed - p.phase) * 0.22, math.sin(t * 3 * p.speed - p.phase) * 0.1, 0)
	elseif a == "pagesL" then
		return CFrame.Angles(0, 0, 0.35 + math.sin(tt * 5) * 0.35)
	elseif a == "pagesR" then
		return CFrame.Angles(0, 0, -0.35 - math.sin(tt * 5) * 0.35)
	elseif a == "pulse" then
		return CFrame.new(0, math.sin(tt * 2.6) * 0.08, 0)
	elseif a == "chatter" then
		return CFrame.new(0, -math.abs(math.sin(tt * 3)) * 0.08, 0)
	elseif a == "fluke" then
		return CFrame.Angles(math.sin(tt * 1.6) * 0.35, 0, 0)
	elseif a == "swim" then
		return CFrame.Angles(math.sin(tt * 1.6) * 0.05, 0, 0)
	end
	return CFrame.identity
end

-- Places every part of the familiar for time `t`. `cf` is where its origin is and which way it
-- faces; `moving` (0..1) drives walk cycles.
function FamiliarBuilder.pose(rig: Rig, cf: CFrame, t: number, moving: number)
	for _, p in rig.pieces do
		p.part.CFrame = cf * p.pivot * animCF(p, t, moving) * p.offset
	end
end

function FamiliarBuilder.destroy(rig: Rig)
	rig.model:Destroy()
end

-- Every body type, for tests.
function FamiliarBuilder.bodies(): { string }
	local list = {}
	for name in Bodies do
		table.insert(list, name)
	end
	table.sort(list)
	return list
end

return FamiliarBuilder
