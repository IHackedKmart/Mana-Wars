-- Building blocks shared by the hub (Arcanum Plaza) and the library (Arcane Athenaeum):
-- the palette, signs, Grimoire lecterns, the class altar, lanterns, portals and dummy pads.

local Build = require(script.Parent.Build)

local Props = {}

local M = Enum.Material

Props.WOOD = Color3.fromRGB(92, 62, 40)
Props.DARK_WOOD = Color3.fromRGB(62, 42, 30)
Props.STONE = Color3.fromRGB(104, 94, 108)
Props.MARBLE = Color3.fromRGB(226, 220, 210)
Props.GOLD = Color3.fromRGB(212, 175, 55)
Props.ARCANE = Color3.fromRGB(165, 115, 255)
Props.CANDLE = Color3.fromRGB(255, 200, 120)
Props.BOOK_COLORS = {
	Color3.fromRGB(140, 30, 40),
	Color3.fromRGB(40, 70, 140),
	Color3.fromRGB(40, 110, 60),
	Color3.fromRGB(120, 80, 30),
	Color3.fromRGB(90, 40, 120),
	Color3.fromRGB(170, 140, 60),
	Color3.fromRGB(60, 60, 70),
	Color3.fromRGB(150, 70, 40),
}

function Props.part(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	material: Enum.Material,
	color: Color3,
	extra: { [string]: any }?
): Part
	local props: { [string]: any } = { Name = name, Size = size, CFrame = cf, Material = material, Color = color }
	if extra then
		for k, v in extra do
			props[k] = v
		end
	end
	return Build.part(props, parent)
end

local part = Props.part

-- A wooden board with a gold frame. Its text is on the Front face, which points along cf.LookVector.
-- Returns the two labels so callers can update them.
function Props.sign(
	parent: Instance,
	cf: CFrame,
	size: Vector2,
	title: string,
	subtitle: string
): (TextLabel, TextLabel)
	local board = part(parent, "Sign", Vector3.new(size.X, size.Y, 0.6), cf, M.WoodPlanks, Props.DARK_WOOD)
	part(parent, "SignTrim", Vector3.new(size.X + 1, size.Y + 1, 0.4), cf * CFrame.new(0, 0, 0.3), M.Metal, Props.GOLD)
	local gui = Build.make("SurfaceGui", { Face = Enum.NormalId.Front, PixelsPerStud = 20, LightInfluence = 0 }, board)
	local titleLabel = Build.make("TextLabel", {
		Name = "Title",
		Size = UDim2.fromScale(1, 0.62),
		BackgroundTransparency = 1,
		Text = title,
		Font = Enum.Font.Fantasy,
		TextScaled = true,
		TextColor3 = Color3.fromRGB(230, 205, 255),
	}, gui)
	local subLabel = Build.make("TextLabel", {
		Name = "Subtitle",
		Size = UDim2.fromScale(1, 0.32),
		Position = UDim2.fromScale(0, 0.64),
		BackgroundTransparency = 1,
		Text = subtitle,
		Font = Enum.Font.GothamBold,
		TextScaled = true,
		TextColor3 = Color3.fromRGB(255, 220, 140),
	}, gui)
	return titleLabel, subLabel
end

-- A reading stand holding the Grimoire; its prompt opens the encyclopedia on the client.
function Props.lectern(parent: Instance, pos: Vector3, facing: Vector3)
	local model = Build.model("Lectern", parent)
	local cf = CFrame.lookAt(pos, pos + facing)
	part(model, "Stand", Vector3.new(1.4, 3.6, 1.4), cf * CFrame.new(0, 1.8, 0), M.WoodPlanks, Props.WOOD)
	part(model, "Foot", Vector3.new(3, 0.4, 3), cf * CFrame.new(0, 0.2, 0), M.WoodPlanks, Props.DARK_WOOD)
	local desk = part(
		model,
		"Desk",
		Vector3.new(3.2, 0.3, 2.4),
		cf * CFrame.new(0, 3.8, 0) * CFrame.Angles(math.rad(-20), 0, 0),
		M.WoodPlanks,
		Props.WOOD
	)
	for side = -1, 1, 2 do
		part(
			model,
			"Page",
			Vector3.new(1.35, 0.12, 1.8),
			desk.CFrame * CFrame.new(side * 0.72, 0.22, 0) * CFrame.Angles(0, 0, math.rad(side * -6)),
			M.SmoothPlastic,
			Color3.fromRGB(248, 240, 220)
		)
	end
	local glow =
		part(model, "Glow", Vector3.new(0.5, 0.5, 0.5), desk.CFrame * CFrame.new(0, 1.2, 0), M.Neon, Props.ARCANE, {
			Shape = Enum.PartType.Ball,
			CanCollide = false,
		})
	Build.make("PointLight", { Color = Props.ARCANE, Range = 10, Brightness = 1.5 }, glow)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Read"
	prompt.ObjectText = "The Grimoire"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("LobbyAction", "Grimoire")
	prompt.Parent = desk
end

-- A marble altar with a spinning crystal (put in `animated`); its prompt opens the class picker.
function Props.classAltar(parent: Instance, animated: Instance, pos: Vector3)
	local altar = Build.cylinder(
		pos + Vector3.new(0, 1.5, 0),
		7,
		3,
		{ Name = "ClassAltar", Material = M.Marble, Color = Props.MARBLE },
		parent
	)
	Build.cylinder(
		pos + Vector3.new(0, 3.1, 0),
		7.4,
		0.3,
		{ Name = "AltarTrim", Material = M.Metal, Color = Props.GOLD },
		parent
	)
	local crystal = part(
		animated,
		"AltarCrystal",
		Vector3.new(2.4, 4.5, 2.4),
		CFrame.new(pos + Vector3.new(0, 7, 0)) * CFrame.Angles(0, math.rad(45), 0),
		M.Neon,
		Color3.fromRGB(255, 200, 90),
		{
			CanCollide = false,
			Transparency = 0.1,
		}
	)
	crystal:SetAttribute("Spin", 1.2)
	Build.make("PointLight", { Color = crystal.Color, Range = 22, Brightness = 2 }, crystal)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Choose class"
	prompt.ObjectText = "Class Altar"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("LobbyAction", "ClassPicker")
	prompt.Parent = altar
end

-- A lamp post; `pos` is the ground under it.
function Props.lantern(parent: Instance, pos: Vector3, height: number?)
	local h = height or 9
	part(
		parent,
		"LampPost",
		Vector3.new(0.7, h, 0.7),
		CFrame.new(pos + Vector3.new(0, h / 2, 0)),
		M.Metal,
		Color3.fromRGB(45, 40, 38)
	)
	part(
		parent,
		"LampBase",
		Vector3.new(1.6, 0.6, 1.6),
		CFrame.new(pos + Vector3.new(0, 0.3, 0)),
		M.Metal,
		Color3.fromRGB(45, 40, 38)
	)
	part(
		parent,
		"LampCap",
		Vector3.new(2, 0.4, 2),
		CFrame.new(pos + Vector3.new(0, h + 1.9, 0)),
		M.Metal,
		Color3.fromRGB(45, 40, 38)
	)
	local lamp = part(
		parent,
		"Lantern",
		Vector3.new(1.4, 1.6, 1.4),
		CFrame.new(pos + Vector3.new(0, h + 0.9, 0)),
		M.Neon,
		Props.CANDLE,
		{ CanCollide = false }
	)
	Build.make("PointLight", { Color = Props.CANDLE, Range = 26, Brightness = 1.5 }, lamp)
end

-- A stone archway holding a glowing portal sheet. `cf` sits on the floor at the arch's centre and
-- looks out of the portal's front. Returns the portal sheet (holds the ProximityPrompt).
function Props.portal(
	parent: Instance,
	cf: CFrame,
	width: number,
	height: number,
	color: Color3,
	actionText: string,
	objectText: string
): Part
	local model = Build.model("Portal", parent)
	for side = -1, 1, 2 do
		part(
			model,
			"PortalPillar",
			Vector3.new(3, height + 2, 3),
			cf * CFrame.new(side * (width / 2 + 1.5), (height + 2) / 2, 0),
			M.Marble,
			Props.MARBLE
		)
		part(
			model,
			"PortalPillarBase",
			Vector3.new(4.2, 1.6, 4.2),
			cf * CFrame.new(side * (width / 2 + 1.5), 0.8, 0),
			M.Marble,
			Props.MARBLE:Lerp(Color3.new(0, 0, 0), 0.12)
		)
	end
	part(
		model,
		"PortalLintel",
		Vector3.new(width + 9, 3, 4),
		cf * CFrame.new(0, height + 3.5, 0),
		M.Marble,
		Props.MARBLE
	)
	part(model, "PortalTrim", Vector3.new(width + 10, 0.8, 4.4), cf * CFrame.new(0, height + 2, 0), M.Metal, Props.GOLD)
	part(
		model,
		"PortalKeystone",
		Vector3.new(3, 3.4, 4.6),
		cf * CFrame.new(0, height + 4, 0) * CFrame.Angles(0, 0, math.rad(45)),
		M.Neon,
		color
	)
	local sheet = part(
		model,
		"PortalSheet",
		Vector3.new(width, height, 0.6),
		cf * CFrame.new(0, height / 2 + 0.5, 0),
		M.Neon,
		color,
		{
			Transparency = 0.35,
			CanCollide = false,
		}
	)
	Build.make("PointLight", { Color = color, Range = 30, Brightness = 2.2 }, sheet)
	Build.make("ParticleEmitter", {
		Color = ColorSequence.new(color, Color3.new(1, 1, 1)),
		LightEmission = 1,
		Size = NumberSequence.new(0.6, 0),
		Transparency = NumberSequence.new(0.1, 1),
		Lifetime = NumberRange.new(1, 2.2),
		Rate = 30,
		Speed = NumberRange.new(0.5, 2),
		SpreadAngle = Vector2.new(180, 180),
	}, sheet)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "PortalPrompt"
	prompt.ActionText = actionText
	prompt.ObjectText = objectText
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = sheet
	return sheet
end

-- A marble pad with a red rune for a training dummy; returns the spot the dummy stands on,
-- facing `lookAt`.
function Props.dummyPad(parent: Instance, pos: Vector3, lookAt: Vector3): CFrame
	Build.cylinder(
		pos + Vector3.new(0, 0.3, 0),
		7,
		0.6,
		{ Name = "DummyPad", Material = M.Marble, Color = Props.MARBLE },
		parent
	)
	Build.cylinder(
		pos + Vector3.new(0, 0.62, 0),
		6,
		0.1,
		{ Name = "DummyRune", Material = M.Neon, Color = Color3.fromRGB(255, 90, 90), CanCollide = false },
		parent
	)
	local spot = pos + Vector3.new(0, 0.6, 0)
	return CFrame.lookAt(spot, Vector3.new(lookAt.X, spot.Y, lookAt.Z))
end

-- An invisible wall that keeps players in (spells and the camera pass through it).
function Props.barrier(parent: Instance, size: Vector3, cf: CFrame)
	Build.part({ Name = "Barrier", Size = size, CFrame = cf, Transparency = 1, CanQuery = false }, parent)
end

return Props
