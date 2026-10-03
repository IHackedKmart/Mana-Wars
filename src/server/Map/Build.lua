-- Tiny helpers for building anchored geometry from code.

local Build = {}

function Build.make(className: string, props: { [string]: any }?, parent: Instance?): any
	local inst = Instance.new(className)
	if props then
		for key, value in props do
			(inst :: any)[key] = value
		end
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

-- Anchored, smooth part. `props` may set any Part property.
function Build.part(props: { [string]: any }, parent: Instance?): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(p :: any)[key] = value
	end
	if parent then
		p.Parent = parent
	end
	return p
end

function Build.wedge(props: { [string]: any }, parent: Instance?): WedgePart
	local p = Instance.new("WedgePart")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(p :: any)[key] = value
	end
	if parent then
		p.Parent = parent
	end
	return p
end

-- A vertical cylinder (Roblox cylinders lie along X, so rotate them upright).
function Build.cylinder(
	position: Vector3,
	diameter: number,
	height: number,
	props: { [string]: any },
	parent: Instance?
): Part
	local p = Build.part(props, nil)
	p.Shape = Enum.PartType.Cylinder
	p.Size = Vector3.new(height, diameter, diameter)
	p.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
	if parent then
		p.Parent = parent
	end
	return p
end

function Build.color(rgb: { number }): Color3
	return Color3.fromRGB(rgb[1], rgb[2], rgb[3])
end

function Build.model(name: string, parent: Instance?): Model
	local m = Instance.new("Model")
	m.Name = name
	if parent then
		m.Parent = parent
	end
	return m
end

return Build
