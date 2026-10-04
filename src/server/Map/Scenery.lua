-- Big set dressing that isn't a landmark: bridges where roads cross rivers, the volcano's smoking
-- crater, and the aurora over Frostpeak.

local Build = require(script.Parent.Build)
local MapDefs = require(script.Parent.MapDefs)

type Style = MapDefs.Style

local Scenery = {}

local M = Enum.Material
local rgb = Color3.fromRGB

local function block(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	material: Enum.Material,
	color: Color3,
	noCollide: boolean?
): Part
	local p = Build.part({ Name = name, Size = size, CFrame = cf, Material = material, Color = color }, parent)
	if noCollide then
		p.CanCollide = false
	end
	return p
end

-- A gently arched wooden bridge from `a` to `b` (both on the banks).
local function bridge(parent: Instance, a: Vector3, b: Vector3, style: Style)
	local model = Build.model("Bridge", parent)
	local flat = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
	local len = flat.Magnitude
	local deck = math.max(a.Y, b.Y) + 0.4
	local arch = math.min(3, len * 0.06)
	local n = math.max(2, math.ceil(len / 5))
	local planks = style.wood:Lerp(Color3.new(1, 1, 1), 0.15)
	local function pointAt(t: number): Vector3
		local p = a:Lerp(b, t)
		return Vector3.new(p.X, deck + math.sin(t * math.pi) * arch, p.Z)
	end
	for i = 0, n - 1 do
		local p0, p1 = pointAt(i / n), pointAt((i + 1) / n)
		local mid = (p0 + p1) / 2
		local cf = CFrame.lookAt(mid, p1)
		local segLen = (p1 - p0).Magnitude + 0.3
		block(model, "Deck", Vector3.new(6, 0.6, segLen), cf, M.WoodPlanks, if i % 2 == 0 then planks else style.wood)
		for side = -1, 1, 2 do
			block(
				model,
				"Rail",
				Vector3.new(0.4, 0.4, segLen),
				cf * CFrame.new(side * 2.8, 2.4, 0),
				M.Wood,
				style.wood,
				true
			)
			block(
				model,
				"Post",
				Vector3.new(0.6, 2.8, 0.6),
				cf * CFrame.new(side * 2.8, 1.1, -segLen / 2),
				M.Wood,
				style.wood,
				true
			)
		end
	end
	for side = -1, 1, 2 do
		local cf = CFrame.lookAt(pointAt(1), pointAt(1) + flat)
		block(model, "Post", Vector3.new(0.6, 2.8, 0.6), cf * CFrame.new(side * 2.8, 1.1, 0), M.Wood, style.wood, true)
	end
end

-- Walks every road and bridges each stretch that crosses water. Returns how many bridges it built.
function Scenery.bridges(
	parent: Instance,
	paths: { { Vector3 } },
	heightAt: (number, number) -> number,
	liquidLevel: number,
	style: Style
): number
	local count = 0
	for _, line in paths do
		-- sample the road every 2 studs
		local samples: { Vector3 } = {}
		for i = 1, #line - 1 do
			local a, b = line[i], line[i + 1]
			local len = (Vector3.new(b.X, 0, b.Z) - Vector3.new(a.X, 0, a.Z)).Magnitude
			local steps = math.max(1, math.ceil(len / 2))
			for s = 0, steps - 1 do
				local p = a:Lerp(b, s / steps)
				table.insert(samples, Vector3.new(p.X, heightAt(p.X, p.Z), p.Z))
			end
		end
		local i = 1
		while i <= #samples do
			if samples[i].Y < liquidLevel + 0.8 then
				local first = i
				while i <= #samples and samples[i].Y < liquidLevel + 0.8 do
					i += 1
				end
				local last = i - 1
				local startAt = samples[math.max(1, first - 2)]
				local endAt = samples[math.min(#samples, last + 2)]
				local span = (endAt - startAt).Magnitude
				-- only real crossings: land on both sides and not a whole lake
				if first > 1 and last < #samples and span < 90 then
					bridge(parent, startAt, endAt, style)
					count += 1
				end
			end
			i += 1
		end
	end
	return count
end

-- Smoke, embers and a red glow rising out of the volcano's crater.
function Scenery.volcano(parent: Instance, crater: Vector3, radius: number)
	local model = Build.model("Volcano", parent)
	local plume = Build.part({
		Name = "Plume",
		Size = Vector3.new(radius * 1.2, 2, radius * 1.2),
		CFrame = CFrame.new(crater + Vector3.new(0, 6, 0)),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
	}, model)
	Build.make("ParticleEmitter", {
		Name = "Smoke",
		Color = ColorSequence.new(rgb(80, 70, 70), rgb(40, 36, 38)),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 10), NumberSequenceKeypoint.new(1, 40) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1) }),
		Lifetime = NumberRange.new(10, 16),
		Rate = 6,
		Speed = NumberRange.new(10, 16),
		SpreadAngle = Vector2.new(12, 12),
		RotSpeed = NumberRange.new(-20, 20),
		Rotation = NumberRange.new(0, 360),
		EmissionDirection = Enum.NormalId.Top,
	}, plume)
	Build.make("ParticleEmitter", {
		Name = "Embers",
		Color = ColorSequence.new(rgb(255, 180, 60), rgb(255, 70, 30)),
		LightEmission = 1,
		Size = NumberSequence.new(0.8, 0),
		Lifetime = NumberRange.new(2, 4),
		Rate = 30,
		Speed = NumberRange.new(20, 34),
		SpreadAngle = Vector2.new(25, 25),
		Acceleration = Vector3.new(0, -12, 0),
		EmissionDirection = Enum.NormalId.Top,
	}, plume)
	Build.make("PointLight", { Color = rgb(255, 90, 30), Range = 60, Brightness = 4 }, plume)
	block(
		model,
		"Glow",
		Vector3.new(radius * 1.4, 0.4, radius * 1.4),
		CFrame.new(crater + Vector3.new(0, 0.6, 0)),
		M.Neon,
		rgb(255, 96, 24),
		true
	)
end

-- Curtains of green, teal and violet light hanging over the far side of the island.
function Scenery.aurora(parent: Instance, radius: number, height: number, rng: Random)
	local model = Build.model("Aurora", parent)
	local colors = {
		{ rgb(90, 255, 170), rgb(150, 110, 255) },
		{ rgb(80, 230, 255), rgb(200, 120, 255) },
		{ rgb(140, 255, 140), rgb(90, 200, 255) },
	}
	local facing = rng:NextNumber(0, math.pi * 2)
	for c = 1, 3 do
		local arc = radius * (0.7 + c * 0.18)
		local y = height + c * 22
		local segments = 18
		for s = 0, segments - 1 do
			local a = facing + (s / segments - 0.5) * 1.8
			local wave = math.sin(s * 0.9 + c) * 14
			local pos =
				Vector3.new(math.cos(a) * (arc + wave), y + math.sin(s * 0.6 + c * 2) * 8, math.sin(a) * (arc + wave))
			local cf = CFrame.lookAt(pos, Vector3.new(0, pos.Y, 0))
			local width = 2 * math.pi * arc * 1.8 / (2 * math.pi) / segments + 6
			local low = block(model, "Curtain", Vector3.new(width, 26, 0.5), cf, M.Neon, colors[c][1], true)
			low.Transparency = 0.62
			low.CastShadow = false
			low.CanQuery = false
			local high = block(
				model,
				"Curtain",
				Vector3.new(width, 22, 0.5),
				cf * CFrame.new(0, 24, 0),
				M.Neon,
				colors[c][2],
				true
			)
			high.Transparency = 0.8
			high.CastShadow = false
			high.CanQuery = false
		end
	end
end

return Scenery
