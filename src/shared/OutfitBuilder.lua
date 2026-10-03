--!strict
-- Builds robes and hats out of simple parts, welded to a character (R15 or R6) or placed on a
-- preview mannequin. Also adds the particle auras and the matched-set trail.
-- Shared so the server dresses real characters and the client dresses the Tailor's preview.

local Cosmetics = require(script.Parent.Cosmetics)

type Garment = Cosmetics.Garment
type CosmeticPart = Cosmetics.CosmeticPart

local OutfitBuilder = {}

export type Rig = {
	torso: BasePart, -- UpperTorso (R15) or Torso (R6)
	hips: BasePart, -- LowerTorso (R15) or Torso (R6); the hip joint is at its bottom
	head: BasePart,
	leftArm: BasePart?, -- the forearm (R15) or arm (R6), for cuffs
	rightArm: BasePart?,
	legLength: number, -- from the bottom of `hips` to the ground
	weld: boolean, -- weld to the body (live character) or just place (preview)
	parent: Instance,
}

local TEXTURES = {
	sparkles = "rbxasset://textures/particles/sparkles_main.dds",
	fire = "rbxasset://textures/particles/fire_main.dds",
	sparks = "rbxasset://textures/particles/fire_sparks_main.dds",
	smoke = "rbxasset://textures/particles/smoke_main.dds",
}
OutfitBuilder.Textures = TEXTURES

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

local function colorOf(part: CosmeticPart?): Color3
	local def = part and Cosmetics.ColorById[part.color]
	return if def then rgb(def.rgb) else Color3.fromRGB(120, 120, 130)
end

local function materialOf(part: CosmeticPart?): Enum.Material
	local def = part and Cosmetics.MaterialById[part.material]
	if def then
		local ok, mat = pcall(function()
			return (Enum.Material :: any)[def.enum]
		end)
		if ok and mat then
			return mat
		end
	end
	return Enum.Material.Fabric
end

-- One piece: placed at anchor.CFrame * offset and welded if building on a live character.
local function piece(
	rig: Rig,
	anchor: BasePart,
	name: string,
	size: Vector3,
	offset: CFrame,
	color: Color3,
	material: Enum.Material,
	shape: Enum.PartType?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	if shape then
		p.Shape = shape
	end
	p.CFrame = anchor.CFrame * offset
	p.Color = color
	p.Material = material
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if rig.weld then
		p.Anchored = false
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = anchor
		weld.Part1 = p
		weld.Parent = p
	else
		p.Anchored = true
	end
	if material == Enum.Material.Glass or material == Enum.Material.ForceField then
		p.Transparency = 0.25
	end
	p.Parent = rig.parent
	return p
end

-- An upright cylinder (Roblox cylinders lie along X).
local UPRIGHT = CFrame.Angles(0, 0, math.rad(90))
local function disc(
	rig: Rig,
	anchor: BasePart,
	name: string,
	diameter: number,
	height: number,
	offset: CFrame,
	color: Color3,
	material: Enum.Material
): Part
	return piece(
		rig,
		anchor,
		name,
		Vector3.new(height, diameter, diameter),
		offset * UPRIGHT,
		color,
		material,
		Enum.PartType.Cylinder
	)
end

local function ball(
	rig: Rig,
	anchor: BasePart,
	name: string,
	size: number,
	offset: CFrame,
	color: Color3,
	material: Enum.Material
): Part
	return piece(rig, anchor, name, Vector3.new(size, size, size), offset, color, material, Enum.PartType.Ball)
end

---------------------------------------------------------------------------
-- Robes
---------------------------------------------------------------------------

type SkirtInfo = { bottomY: number, bottomDiameter: number, length: number }

local function buildRobe(rig: Rig, robe: Garment)
	local cloth, trim, sigil = robe.parts.Cloth, robe.parts.Trim, robe.parts.Sigil
	local main, mainMat = colorOf(cloth), materialOf(cloth)
	local accent, accentMat = colorOf(trim), materialOf(trim)
	local torso, hips = rig.torso, rig.hips
	local ts = torso.Size
	local width = math.max(ts.X, 1.6)
	local depth = math.max(ts.Z, 0.8)
	local design = cloth and cloth.design or "Straight"

	-- body: covers the torso (and the R15 lower torso)
	local drop = if hips ~= torso then hips.Size.Y else 0
	piece(
		rig,
		torso,
		"RobeBody",
		Vector3.new(width + 0.16, ts.Y + drop + 0.1, depth + 0.16),
		CFrame.new(0, -drop / 2, 0),
		main,
		mainMat
	)

	-- skirt: from the hip joint (bottom of `hips`) down toward the feet
	local hipY = -hips.Size.Y / 2
	local L = rig.legLength * 0.94
	local r0 = width * 0.62
	local skirt: SkirtInfo = { bottomY = hipY - L, bottomDiameter = r0 * 2 + 0.1, length = L }
	local function tiers(radii: { number }, length: number)
		local h = length / #radii
		for i, r in radii do
			disc(rig, hips, "RobeSkirt", r * 2, h + 0.02, CFrame.new(0, hipY - h * (i - 0.5), 0), main, mainMat)
		end
		skirt.bottomY = hipY - length
		skirt.bottomDiameter = radii[#radii] * 2
		skirt.length = length
	end

	if
		design == "Bell"
		or design == "Royal"
		or design == "Archmage"
		or design == "Crystal"
		or design == "Celestial"
	then
		tiers({ r0, r0 + 0.18, r0 + 0.4 }, L)
	elseif design == "Battle" then
		tiers({ r0, r0 + 0.12 }, L * 0.55)
		for side = -1, 1, 2 do
			piece(
				rig,
				hips,
				"Tabard",
				Vector3.new(width * 0.6, L * 0.85, 0.12),
				CFrame.new(0, hipY - L * 0.42, side * (r0 + 0.1)),
				main:Lerp(Color3.new(0, 0, 0), 0.15),
				mainMat
			)
		end
	elseif design == "Monk" then
		tiers({ r0 + 0.1 }, L)
	else
		tiers({ r0 }, L)
	end

	if design == "Patchwork" then
		for i, o in { Vector3.new(0.6, -0.5, -1), Vector3.new(-0.7, -1.2, -1), Vector3.new(0.3, -1.4, 1) } do
			piece(
				rig,
				hips,
				"Patch",
				Vector3.new(0.5, 0.45, 0.08),
				CFrame.new(o.X, hipY + o.Y, o.Z * (r0 + 0.02)),
				main:Lerp(Color3.fromHSV(i * 0.31 % 1, 0.4, 0.6), 0.45),
				Enum.Material.Fabric
			)
		end
	elseif design == "Cloak" or design == "Royal" then
		-- a cape hanging from the shoulders
		piece(
			rig,
			torso,
			"Cape",
			Vector3.new(width + 0.3, ts.Y + drop + L * 0.85, 0.14),
			CFrame.new(0, ts.Y / 2 - (ts.Y + drop + L * 0.85) / 2, depth / 2 + 0.2) * CFrame.Angles(math.rad(-6), 0, 0),
			main:Lerp(Color3.new(0, 0, 0), 0.2),
			mainMat
		)
		if design == "Royal" then
			piece(
				rig,
				hips,
				"Train",
				Vector3.new(width * 0.9, 0.12, 1.6),
				CFrame.new(0, skirt.bottomY + 0.08, r0 + 0.8),
				main,
				mainMat
			)
		end
	elseif design == "Archmage" or design == "Crystal" then
		-- shoulder pads and a tall collar
		for side = -1, 1, 2 do
			piece(
				rig,
				torso,
				"Pauldron",
				Vector3.new(0.9, 0.35, depth + 0.4),
				CFrame.new(side * (width / 2 + 0.25), ts.Y / 2 + 0.05, 0) * CFrame.Angles(0, 0, math.rad(side * -18)),
				accent,
				accentMat
			)
		end
		piece(
			rig,
			torso,
			"Collar",
			Vector3.new(width * 0.9, 1.1, 0.14),
			CFrame.new(0, ts.Y / 2 + 0.45, depth / 2 + 0.05) * CFrame.Angles(math.rad(15), 0, 0),
			main,
			mainMat
		)
		if design == "Crystal" then
			for side = -1, 1, 2 do
				piece(
					rig,
					torso,
					"Shard",
					Vector3.new(0.25, 0.9, 0.25),
					CFrame.new(side * (width / 2 + 0.35), ts.Y / 2 + 0.5, 0) * CFrame.Angles(0, 0, math.rad(side * -25)),
					main,
					Enum.Material.Glass
				)
			end
		end
	elseif design == "Shadow" then
		for i = 1, 8 do
			local a = (i / 8) * math.pi * 2
			local len = 0.4 + (i % 3) * 0.25
			piece(
				rig,
				hips,
				"Tatter",
				Vector3.new(0.35, len, 0.08),
				CFrame.new(math.cos(a) * r0, skirt.bottomY - len / 2 + 0.05, math.sin(a) * r0)
					* CFrame.Angles(0, -a + math.pi / 2, 0),
				main:Lerp(Color3.new(0, 0, 0), 0.3),
				mainMat
			)
		end
	elseif design == "Celestial" then
		for i, h in { -0.2, -0.9 } do
			disc(
				rig,
				hips,
				"StarRing",
				r0 * 2 + 0.7 + i * 0.3,
				0.06,
				CFrame.new(0, hipY + h, 0) * CFrame.Angles(math.rad(i * 8), 0, 0),
				accent,
				Enum.Material.Neon
			)
		end
	elseif design == "Monk" then
		piece(
			rig,
			torso,
			"Sash",
			Vector3.new(0.35, ts.Y * 1.25, depth + 0.24),
			CFrame.Angles(0, 0, math.rad(35)),
			accent,
			accentMat
		)
	end

	-- trim: hems, belt, cuffs, collar
	local style = trim and trim.design or "Hem"
	local hemMat = accentMat
	if style == "Runic" or style == "Starlit" then
		hemMat = Enum.Material.Neon
	elseif style == "Gilded" or style == "Chain" then
		hemMat = if accentMat == Enum.Material.Fabric or accentMat == Enum.Material.Leather
			then Enum.Material.Metal
			else accentMat
	end
	local hemThick = if style == "Fur" then 0.4 else 0.2
	disc(
		rig,
		hips,
		"Hem",
		skirt.bottomDiameter + (if style == "Fur" then 0.3 else 0.1),
		hemThick,
		CFrame.new(0, skirt.bottomY + hemThick / 2, 0),
		accent,
		hemMat
	)
	if style == "Double" or style == "Embroidered" or style == "Starlit" then
		disc(
			rig,
			hips,
			"Hem",
			skirt.bottomDiameter + 0.08,
			0.12,
			CFrame.new(0, skirt.bottomY + 0.45, 0),
			accent,
			hemMat
		)
	end
	piece(
		rig,
		hips,
		"Belt",
		Vector3.new(width + 0.3, 0.24, depth + 0.3),
		-- at the waist: low on an R6 torso, at the top of an R15 lower torso
		CFrame.new(0, if hips == torso then -hips.Size.Y / 2 + 0.3 else hips.Size.Y / 2 - 0.05, 0),
		accent,
		hemMat
	)
	if style ~= "Hem" then
		for _, arm in { rig.leftArm, rig.rightArm } do
			if arm then
				piece(
					rig,
					arm,
					"Cuff",
					Vector3.new(arm.Size.X + 0.16, if style == "Fur" then 0.35 else 0.22, arm.Size.Z + 0.16),
					CFrame.new(0, -arm.Size.Y / 2 + 0.25, 0),
					accent,
					hemMat
				)
			end
		end
	end
	if style == "Fur" or style == "Gilded" or style == "Starlit" then
		piece(
			rig,
			torso,
			"TrimCollar",
			Vector3.new(width * 0.75, 0.3, depth + 0.3),
			CFrame.new(0, ts.Y / 2 + 0.02, 0),
			accent,
			hemMat
		)
	end
	if style == "Runic" or style == "Embroidered" then
		piece(
			rig,
			torso,
			"Stripe",
			Vector3.new(0.18, ts.Y + drop, 0.04),
			CFrame.new(0, -drop / 2, -depth / 2 - 0.1),
			accent,
			hemMat
		)
	end
	if style == "Starlit" then
		for i = 1, 6 do
			local a = (i / 6) * math.pi * 2
			local r = skirt.bottomDiameter / 2 + 0.06
			piece(
				rig,
				hips,
				"TrimStar",
				Vector3.new(0.2, 0.2, 0.06),
				CFrame.new(math.cos(a) * r, skirt.bottomY + 0.3, math.sin(a) * r)
					* CFrame.Angles(0, -a + math.pi / 2, math.rad(45)),
				Color3.new(1, 1, 1),
				Enum.Material.Neon
			)
		end
	end

	-- sigil: a badge on the chest with the emblem glyph
	if sigil then
		local glyph = Cosmetics.DesignById.Sigil[sigil.design]
		local badge = piece(
			rig,
			torso,
			"Sigil",
			Vector3.new(0.75, 0.75, 0.08),
			CFrame.new(0, ts.Y * 0.15, -depth / 2 - 0.14),
			colorOf(sigil),
			materialOf(sigil)
		)
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Front
		gui.PixelsPerStud = 60
		gui.LightInfluence = 0
		gui.Parent = badge
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.Text = if glyph and glyph.glyph then glyph.glyph else "✦"
		label.TextScaled = true
		label.Font = Enum.Font.GothamBold
		label.TextColor3 = Color3.fromRGB(255, 235, 170)
		label.TextStrokeTransparency = 0.4
		label.Parent = gui
	end
end

---------------------------------------------------------------------------
-- Hats
---------------------------------------------------------------------------

local function buildHat(rig: Rig, hat: Garment)
	local shape, band, gem = hat.parts.Shape, hat.parts.Band, hat.parts.Gem
	local main, mainMat = colorOf(shape), materialOf(shape)
	local accent, accentMat = colorOf(band), materialOf(band)
	local head = rig.head
	local hs = head.Size.Y -- R15 ~1.2, R6 1
	local top = hs / 2
	local design = shape and shape.design or "Pointed"
	local bandStyle = band and band.design or "Plain"
	if bandStyle == "Runic" or bandStyle == "Starlit" then
		accentMat = Enum.Material.Neon
	elseif bandStyle == "Gilded" or bandStyle == "Studded" then
		accentMat = if accentMat == Enum.Material.Fabric or accentMat == Enum.Material.Leather
			then Enum.Material.Metal
			else accentMat
	elseif bandStyle == "Crystal" then
		accentMat = Enum.Material.Glass
	end

	-- where the band sits (height + diameter) and where the gem goes, per shape
	local bandY, bandD = top - 0.05, hs * 1.22
	local gemAt = CFrame.new(0, top - 0.02, -hs * 0.62)

	local function cone(baseD: number, tiers: number, tierH: number, bend: number)
		local y = top
		for i = 1, tiers do
			local d = baseD * (1 - (i - 1) / tiers) + 0.08
			local lean = if i > tiers - 2 then bend * (i - (tiers - 2)) else 0
			disc(rig, head, "HatCone", d, tierH + 0.02, CFrame.new(0, y + tierH / 2, lean), main, mainMat)
			y += tierH
		end
	end

	if design == "Pointed" or design == "Witch" then
		local brim = if design == "Witch" then hs * 2.9 else hs * 2.3
		disc(rig, head, "Brim", brim, 0.12, CFrame.new(0, top - 0.02, 0), main, mainMat)
		cone(hs * 1.18, if design == "Witch" then 6 else 5, 0.34, if design == "Witch" then 0.28 else 0.14)
		bandY, bandD = top + 0.12, hs * 1.22
		gemAt = CFrame.new(0, top + 0.12, -hs * 0.62)
	elseif design == "Straw" then
		disc(rig, head, "Brim", hs * 2.6, 0.1, CFrame.new(0, top - 0.02, 0), main, Enum.Material.Sand)
		disc(rig, head, "Crown", hs * 1.15, 0.45, CFrame.new(0, top + 0.22, 0), main, Enum.Material.Sand)
		bandY = top + 0.1
		gemAt = CFrame.new(0, top + 0.1, -hs * 0.6)
	elseif design == "Hood" then
		piece(
			rig,
			head,
			"HoodTop",
			Vector3.new(hs * 1.35, 0.25, hs * 1.35),
			CFrame.new(0, top + 0.1, 0.05),
			main,
			mainMat
		)
		piece(
			rig,
			head,
			"HoodBack",
			Vector3.new(hs * 1.35, hs * 1.35, 0.25),
			CFrame.new(0, 0.05, hs * 0.62),
			main,
			mainMat
		)
		for side = -1, 1, 2 do
			piece(
				rig,
				head,
				"HoodSide",
				Vector3.new(0.22, hs * 1.2, hs * 1.3),
				CFrame.new(side * hs * 0.66, 0.05, 0.05),
				main,
				mainMat
			)
		end
		piece(
			rig,
			head,
			"HoodPeak",
			Vector3.new(hs * 0.5, 0.35, 0.5),
			CFrame.new(0, top + 0.3, hs * 0.45),
			main,
			mainMat
		)
		bandY, bandD = top + 0.1, 0
		gemAt = CFrame.new(0, top + 0.05, -hs * 0.6)
	elseif design == "Cap" then
		piece(
			rig,
			head,
			"Beret",
			Vector3.new(hs * 1.45, hs * 0.45, hs * 1.45),
			CFrame.new(0.1, top + 0.08, 0) * CFrame.Angles(0, 0, math.rad(-10)),
			main,
			mainMat,
			Enum.PartType.Ball
		)
		piece(
			rig,
			head,
			"Feather",
			Vector3.new(0.08, 1.3, 0.3),
			CFrame.new(hs * 0.45, top + 0.6, 0.25) * CFrame.Angles(math.rad(-30), 0, math.rad(-25)),
			accent,
			Enum.Material.Fabric
		)
		bandY, bandD = top - 0.02, hs * 1.2
	elseif design == "TopHat" then
		disc(rig, head, "Brim", hs * 1.9, 0.1, CFrame.new(0, top, 0), main, mainMat)
		disc(rig, head, "Crown", hs * 1.12, hs * 1.15, CFrame.new(0, top + hs * 0.58, 0), main, mainMat)
		bandY, bandD = top + 0.2, hs * 1.16
		gemAt = CFrame.new(0, top + 0.2, -hs * 0.58)
	elseif design == "Circlet" or design == "Crown" or design == "Halo" or design == "Starcrown" then
		local ringMat = if mainMat == Enum.Material.Fabric or mainMat == Enum.Material.Leather
			then Enum.Material.Metal
			else mainMat
		disc(rig, head, "Circlet", hs * 1.2, 0.18, CFrame.new(0, top - 0.25, 0), main, ringMat)
		bandY, bandD = top - 0.1, 0
		gemAt = CFrame.new(0, top - 0.25, -hs * 0.62)
		if design == "Crown" then
			for i = 1, 7 do
				local a = (i / 7) * math.pi * 2
				piece(
					rig,
					head,
					"CrownSpike",
					Vector3.new(0.2, 0.45, 0.2),
					CFrame.new(math.cos(a) * hs * 0.56, top + 0.05, math.sin(a) * hs * 0.56)
						* CFrame.Angles(0, 0, math.rad(45)),
					main,
					ringMat
				)
			end
		elseif design == "Halo" then
			for i = 1, 14 do
				local a = (i / 14) * math.pi * 2
				ball(
					rig,
					head,
					"HaloBead",
					0.2,
					CFrame.new(math.cos(a) * hs * 0.6, top + 0.65, math.sin(a) * hs * 0.6),
					Color3.fromRGB(255, 240, 180),
					Enum.Material.Neon
				)
			end
		elseif design == "Starcrown" then
			for i = 1, 5 do
				local a = (i / 5) * math.pi * 2
				local at = CFrame.new(math.cos(a) * hs * 0.55, top + 0.55, math.sin(a) * hs * 0.55)
				for k = 0, 1 do
					piece(
						rig,
						head,
						"CrownStar",
						Vector3.new(0.12, 0.38, 0.12),
						at * CFrame.Angles(0, 0, math.rad(45 + k * 90)),
						Color3.fromRGB(255, 250, 220),
						Enum.Material.Neon
					)
				end
			end
		end
	elseif design == "Tricorn" then
		disc(rig, head, "Crown", hs * 1.12, 0.4, CFrame.new(0, top + 0.18, 0), main, mainMat)
		for i = 1, 3 do
			local a = (i / 3) * math.pi * 2 + math.pi / 2
			piece(
				rig,
				head,
				"Brim",
				Vector3.new(hs * 1.2, 0.3, 0.15),
				CFrame.new(math.cos(a) * hs * 0.6, top + 0.15, math.sin(a) * hs * 0.6)
					* CFrame.Angles(0, -a + math.pi / 2, 0)
					* CFrame.Angles(math.rad(-25), 0, 0),
				main,
				mainMat
			)
		end
		bandY, bandD = top + 0.05, hs * 1.15
	elseif design == "Horned" then
		piece(
			rig,
			head,
			"Helm",
			Vector3.new(hs * 1.3, hs * 1.0, hs * 1.3),
			CFrame.new(0, top - 0.1, 0),
			main,
			mainMat,
			Enum.PartType.Ball
		)
		for side = -1, 1, 2 do
			for k = 1, 3 do
				piece(
					rig,
					head,
					"Horn",
					Vector3.new(0.3 - k * 0.06, 0.4, 0.3 - k * 0.06),
					CFrame.new(side * (hs * 0.55 + k * 0.18), top + k * 0.26, 0)
						* CFrame.Angles(0, 0, math.rad(side * -(20 + k * 12))),
					Color3.fromRGB(235, 225, 200),
					Enum.Material.SmoothPlastic
				)
			end
		end
		bandY, bandD = top - 0.3, hs * 1.32
	elseif design == "Mitre" then
		for side = -1, 1, 2 do
			piece(
				rig,
				head,
				"Mitre",
				Vector3.new(hs * 0.95, hs * 1.3, 0.3),
				CFrame.new(0, top + hs * 0.6, side * 0.12) * CFrame.Angles(math.rad(side * 9), 0, 0),
				main,
				mainMat
			)
		end
		bandY, bandD = top + 0.05, hs * 1.05
	end

	-- the band
	if bandD > 0 then
		disc(rig, head, "Band", bandD, 0.16, CFrame.new(0, bandY, 0), accent, accentMat)
		if bandStyle == "Braided" then
			disc(rig, head, "Band", bandD, 0.08, CFrame.new(0, bandY + 0.14, 0), accent, accentMat)
		elseif bandStyle == "Ribbon" then
			for side = -1, 1, 2 do
				piece(
					rig,
					head,
					"Bow",
					Vector3.new(0.12, 0.3, 0.3),
					CFrame.new(bandD / 2 + 0.05, bandY, side * 0.16) * CFrame.Angles(math.rad(side * 30), 0, 0),
					accent,
					accentMat
				)
			end
		elseif bandStyle == "Studded" or bandStyle == "Starlit" then
			for i = 1, 8 do
				local a = (i / 8) * math.pi * 2
				ball(
					rig,
					head,
					"Stud",
					0.12,
					CFrame.new(math.cos(a) * bandD / 2, bandY, math.sin(a) * bandD / 2),
					if bandStyle == "Starlit" then Color3.new(1, 1, 1) else accent,
					if bandStyle == "Starlit" then Enum.Material.Neon else Enum.Material.Metal
				)
			end
		end
	end

	-- the gem
	if gem then
		local c, m = colorOf(gem), materialOf(gem)
		local g = gem.design
		if g == "Bead" or g == "Acorn" then
			ball(rig, head, "Gem", 0.24, gemAt, c, m)
		elseif g == "Orb" or g == "Moon" or g == "Singularity" then
			ball(rig, head, "Gem", 0.36, gemAt, if g == "Singularity" then Color3.new(0, 0, 0) else c, m)
			if g == "Singularity" then
				for i = 1, 6 do
					local a = (i / 6) * math.pi * 2
					ball(
						rig,
						head,
						"GemRing",
						0.08,
						gemAt * CFrame.new(math.cos(a) * 0.3, math.sin(a) * 0.3, 0),
						c,
						Enum.Material.Neon
					)
				end
			end
		elseif g == "Diamond" or g == "Prism" then
			piece(
				rig,
				head,
				"Gem",
				Vector3.new(0.28, 0.28, 0.28),
				gemAt * CFrame.Angles(math.rad(45), 0, math.rad(45)),
				c,
				if g == "Prism" then Enum.Material.Glass else m
			)
		elseif g == "Star" then
			for k = 0, 1 do
				piece(
					rig,
					head,
					"Gem",
					Vector3.new(0.12, 0.42, 0.08),
					gemAt * CFrame.Angles(0, 0, math.rad(45 + k * 90)),
					c,
					m
				)
			end
		elseif g == "Eye" then
			ball(rig, head, "Gem", 0.34, gemAt, Color3.fromRGB(245, 240, 230), Enum.Material.SmoothPlastic)
			ball(rig, head, "Iris", 0.17, gemAt * CFrame.new(0, 0, -0.12), c, Enum.Material.Neon)
		elseif g == "Skull" then
			piece(rig, head, "Gem", Vector3.new(0.32, 0.32, 0.22), gemAt, c, m)
			for side = -1, 1, 2 do
				piece(
					rig,
					head,
					"SkullEye",
					Vector3.new(0.08, 0.08, 0.04),
					gemAt * CFrame.new(side * 0.07, 0.03, -0.12),
					Color3.new(0, 0, 0),
					Enum.Material.SmoothPlastic
				)
			end
		elseif g == "Heart" then
			for side = -1, 1, 2 do
				ball(rig, head, "Gem", 0.22, gemAt * CFrame.new(side * 0.08, 0.05, 0), c, Enum.Material.Neon)
			end
			piece(
				rig,
				head,
				"Gem",
				Vector3.new(0.22, 0.22, 0.12),
				gemAt * CFrame.new(0, -0.07, 0) * CFrame.Angles(0, 0, math.rad(45)),
				c,
				Enum.Material.Neon
			)
		end
	end
end

---------------------------------------------------------------------------
-- Auras
---------------------------------------------------------------------------

local function rainbow(): ColorSequence
	local keys = {}
	for i = 0, 5 do
		table.insert(keys, ColorSequenceKeypoint.new(i / 5, Color3.fromHSV(i / 6, 0.7, 1)))
	end
	return ColorSequence.new(keys)
end

-- Adds an aura's particles at `anchor` (an attachment's parent part). level 3-6.
function OutfitBuilder.addAura(
	anchor: BasePart,
	offset: Vector3,
	auraId: string,
	level: number,
	parent: Instance?
): Attachment?
	local def = Cosmetics.AuraById[auraId]
	if not def or level < 3 then
		return nil
	end
	local scale = ({ [3] = 0.3, [4] = 0.6, [5] = 1, [6] = 1.4 })[math.clamp(level, 3, 6)]
	local attachment = Instance.new("Attachment")
	attachment.Name = "Aura_" .. auraId
	attachment.Position = offset
	attachment.Parent = parent or anchor
	local c1, c2 = rgb(def.colors[1]), rgb(def.colors[2] or def.colors[1])
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "AuraParticles"
	emitter.Texture = TEXTURES[def.texture] or TEXTURES.sparkles
	emitter.Color = if def.rainbow then rainbow() else ColorSequence.new(c1, c2)
	emitter.LightEmission = if def.texture == "smoke" then 0.1 else 0.8
	emitter.LightInfluence = if def.texture == "smoke" then 1 else 0
	local size = def.size * (0.6 + scale * 0.4)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, size * 0.6),
		NumberSequenceKeypoint.new(0.3, size),
		NumberSequenceKeypoint.new(1, if def.texture == "smoke" then size * 1.8 else 0),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, if def.texture == "smoke" then 0.55 else 0.1),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Lifetime = NumberRange.new(def.lifetime * 0.7, def.lifetime)
	emitter.Rate = def.rate * scale
	emitter.Speed = if def.inward
		then NumberRange.new(-def.speed * 1.2, -def.speed * 0.6)
		else NumberRange.new(def.speed * 0.5, def.speed)
	emitter.SpreadAngle = Vector2.new(def.spread, def.spread)
	emitter.Acceleration = Vector3.new(0, def.rise, 0)
	emitter.RotSpeed = NumberRange.new(-60, 60)
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.Drag = 1
	emitter.LockedToPart = false
	emitter.Parent = attachment
	if def.inward then
		emitter.Shape = Enum.ParticleEmitterShape.Sphere
		emitter.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
		emitter.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	end
	if def.crackle or level >= 6 then
		-- a second, faster layer: electric crackle, or the blazing tier's extra flourish
		local extra = Instance.new("ParticleEmitter")
		extra.Name = "AuraFlourish"
		extra.Texture = TEXTURES.sparks
		extra.Color = ColorSequence.new(Color3.new(1, 1, 1), c1)
		extra.LightEmission = 1
		extra.LightInfluence = 0
		extra.Size = NumberSequence.new(0.15 * (0.6 + scale * 0.4), 0)
		extra.Lifetime = NumberRange.new(0.08, 0.2)
		extra.Rate = (if def.crackle then 30 else 14) * scale
		extra.Speed = NumberRange.new(10, 18)
		extra.SpreadAngle = Vector2.new(180, 180)
		extra.Parent = attachment
	end
	if def.light and level >= 4 then
		local light = Instance.new("PointLight")
		light.Name = "AuraLight"
		light.Color = c1
		light.Range = 6 + scale * 6
		light.Brightness = 0.6 + scale * 0.8
		light.Shadows = false
		light.Parent = attachment
	end
	return attachment
end

-- A ribbon of the aura streaming behind the wearer (robe and hat with the same aura).
function OutfitBuilder.addTrail(torso: BasePart, auraId: string, parent: Instance?): Trail?
	local def = Cosmetics.AuraById[auraId]
	if not def then
		return nil
	end
	local top = Instance.new("Attachment")
	top.Name = "TrailTop"
	top.Position = Vector3.new(0, torso.Size.Y * 0.45, 0.3)
	top.Parent = parent or torso
	local bottom = Instance.new("Attachment")
	bottom.Name = "TrailBottom"
	bottom.Position = Vector3.new(0, -torso.Size.Y * 1.4, 0.3)
	bottom.Parent = parent or torso
	local trail = Instance.new("Trail")
	trail.Name = "AuraTrail"
	trail.Attachment0 = top
	trail.Attachment1 = bottom
	trail.Color = if def.rainbow
		then rainbow()
		else ColorSequence.new(rgb(def.colors[1]), rgb(def.colors[2] or def.colors[1]))
	trail.Transparency = NumberSequence.new(0.35, 1)
	trail.LightEmission = if def.texture == "smoke" then 0.1 else 1
	trail.Lifetime = 0.45
	trail.MinLength = 0.1
	trail.FaceCamera = true
	trail.WidthScale = NumberSequence.new(1, 0.2)
	if def.crackle then
		trail.Texture = TEXTURES.sparks
		trail.TextureMode = Enum.TextureMode.Wrap
		trail.TextureLength = 2
	end
	trail.Parent = parent or torso
	return trail
end

---------------------------------------------------------------------------
-- Entry points
---------------------------------------------------------------------------

-- Dresses a rig. Returns the folder holding everything (destroy it to undress).
function OutfitBuilder.build(rig: Rig, robe: Garment?, hat: Garment?, withAuras: boolean): Folder
	local folder = Instance.new("Folder")
	folder.Name = "Outfit"
	folder.Parent = rig.parent
	local r: Rig = table.clone(rig)
	r.parent = folder
	if robe then
		buildRobe(r, robe)
	end
	if hat then
		buildHat(r, hat)
	end
	if withAuras then
		if robe then
			local aura = Cosmetics.auraOf(robe)
			if aura then
				OutfitBuilder.addAura(rig.torso, Vector3.new(0, 0, 0), aura, Cosmetics.auraLevel(robe), nil)
			end
		end
		if hat then
			local aura = Cosmetics.auraOf(hat)
			if aura then
				OutfitBuilder.addAura(
					rig.head,
					Vector3.new(0, rig.head.Size.Y * 0.9, 0),
					aura,
					Cosmetics.auraLevel(hat),
					nil
				)
			end
		end
		local matched = Cosmetics.matchedTrail(robe, hat)
		if matched then
			OutfitBuilder.addTrail(rig.torso, matched, nil)
		end
	end
	return folder
end

-- Removes an outfit (and its auras) from a body.
function OutfitBuilder.strip(model: Instance)
	local old = model:FindFirstChild("Outfit")
	if old then
		old:Destroy()
	end
	for _, d in model:GetDescendants() do
		local aura = d:IsA("Attachment")
			and (string.sub(d.Name, 1, 5) == "Aura_" or d.Name == "TrailTop" or d.Name == "TrailBottom")
		if aura or (d:IsA("Trail") and d.Name == "AuraTrail") then
			d:Destroy()
		end
	end
end

-- The rig of a Roblox character (R15 or R6), or nil if it isn't fully built.
function OutfitBuilder.rigOf(character: Model): Rig?
	local hum = character:FindFirstChildOfClass("Humanoid")
	local head = character:FindFirstChild("Head") :: BasePart?
	if not hum or not head then
		return nil
	end
	local upper = character:FindFirstChild("UpperTorso") :: BasePart?
	if upper then
		local lower = character:FindFirstChild("LowerTorso") :: BasePart?
		if not lower then
			return nil
		end
		return {
			torso = upper,
			hips = lower,
			head = head,
			leftArm = character:FindFirstChild("LeftLowerArm") :: BasePart?,
			rightArm = character:FindFirstChild("RightLowerArm") :: BasePart?,
			legLength = math.max(1.2, hum.HipHeight),
			weld = true,
			parent = character :: Instance,
		}
	end
	local torso = character:FindFirstChild("Torso") :: BasePart?
	if not torso then
		return nil
	end
	return {
		torso = torso,
		hips = torso,
		head = head,
		leftArm = character:FindFirstChild("Left Arm") :: BasePart?,
		rightArm = character:FindFirstChild("Right Arm") :: BasePart?,
		legLength = 2,
		weld = true,
		parent = character :: Instance,
	}
end

return OutfitBuilder
