-- The battle royale's magic carpet, on this screen: draws the carpet flying across the island (from
-- the path the server publishes), keeps you in your seat on it, jumps you off (SPACE, the mobile
-- jump button or the JUMP button) and steers your glide down. While you're up there the names of
-- the island's places float over them, so you can pick where to land.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local UI = script.Parent.Parent.UI
local Create = require(UI.Create)
local Theme = require(UI.Theme)
local Widgets = require(UI.Widgets)
local State = require(script.Parent.State)

local CarpetController = {}

local C = Theme.Colors
local R = Config.Royale
local player = Players.LocalPlayer
local rgb = Color3.fromRGB

local carpet: Model? = nil
local carpetSize: Vector3? = nil
local gui: ScreenGui
local jumpButton: TextButton
local hint: TextLabel
local lastJump = 0
local labelsShown = false

-- Where the carpet is at time `t` (nil when there's no carpet flying).
function CarpetController.cframeAt(t: number): CFrame?
	local from = ReplicatedStorage:GetAttribute("CarpetFrom")
	local to = ReplicatedStorage:GetAttribute("CarpetTo")
	local start = tonumber(ReplicatedStorage:GetAttribute("CarpetStart"))
	local duration = tonumber(ReplicatedStorage:GetAttribute("CarpetDuration"))
	if typeof(from) ~= "Vector3" or typeof(to) ~= "Vector3" or not start or not duration then
		return nil
	end
	local alpha = math.clamp((t - start) / math.max(duration, 0.001), 0, 1)
	local pos = from:Lerp(to, alpha)
	local flat = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
	local dir = if flat.Magnitude > 0 then flat.Unit else Vector3.new(0, 0, -1)
	return CFrame.lookAt(pos, pos + dir)
end

local function piece(model: Model, name: string, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material?)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = size
	p.Material = material or Enum.Material.Fabric
	p.Color = color
	p.CFrame = offset
	p.Parent = model
	return p
end

-- A great woven carpet: a crimson field with a gold border, a midnight-blue inner panel, a glowing
-- medallion in the middle, tassels at both ends and a trail of sparkles underneath.
local function buildCarpet(size: Vector3): Model
	local model = Instance.new("Model")
	model.Name = "MagicCarpet"
	local w, l = size.X, size.Z
	local base = piece(model, "Rug", Vector3.new(w, 0.6, l), CFrame.new(), rgb(150, 28, 48))
	model.PrimaryPart = base
	-- the gold border, then the patterned panels
	for side = -1, 1, 2 do
		piece(model, "Border", Vector3.new(1, 0.7, l), CFrame.new(side * (w / 2 - 0.5), 0.02, 0), rgb(232, 180, 64))
		piece(model, "Border", Vector3.new(w, 0.7, 1), CFrame.new(0, 0.02, side * (l / 2 - 0.5)), rgb(232, 180, 64))
	end
	piece(model, "Panel", Vector3.new(w - 5, 0.66, l - 5), CFrame.new(0, 0.01, 0), rgb(36, 40, 110))
	piece(model, "PanelTrim", Vector3.new(w - 7, 0.68, l - 7), CFrame.new(0, 0.02, 0), rgb(120, 24, 40))
	piece(model, "Field", Vector3.new(w - 8, 0.7, l - 8), CFrame.new(0, 0.03, 0), rgb(48, 52, 136))
	for i = -2, 2 do
		local diamond = piece(
			model,
			"Diamond",
			Vector3.new(2.2, 0.72, 2.2),
			CFrame.new(0, 0.04, i * (l - 10) / 5) * CFrame.Angles(0, math.rad(45), 0),
			if i == 0 then rgb(255, 214, 110) else rgb(232, 180, 64)
		)
		if i == 0 then
			diamond.Material = Enum.Material.Neon
			diamond.Size = Vector3.new(3.4, 0.72, 3.4)
		end
	end
	-- tassels along the front and back edges
	for side = -1, 1, 2 do
		for x = -w / 2 + 1.5, w / 2 - 1.5, 2.5 do
			piece(
				model,
				"Tassel",
				Vector3.new(0.4, 0.3, 1.6),
				CFrame.new(x, -0.1, side * (l / 2 + 0.8)),
				rgb(240, 196, 80)
			)
		end
	end
	-- sparkles trailing under it, and a warm glow
	local glow = piece(model, "Glow", Vector3.new(w - 2, 0.2, l - 2), CFrame.new(0, -0.45, 0), rgb(255, 170, 90))
	glow.Transparency = 1
	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Name = "Sparkles"
	sparkles.Color = ColorSequence.new(rgb(255, 230, 140), rgb(200, 140, 255))
	sparkles.LightEmission = 1
	sparkles.Size = NumberSequence.new(0.6, 0)
	sparkles.Lifetime = NumberRange.new(1.5, 2.5)
	sparkles.Rate = 60
	sparkles.Speed = NumberRange.new(1, 3)
	sparkles.EmissionDirection = Enum.NormalId.Bottom
	sparkles.Parent = glow
	local light = Instance.new("PointLight")
	light.Color = rgb(255, 200, 120)
	light.Range = 30
	light.Brightness = 1.5
	light.Parent = glow
	-- everything was laid out around the rug: weld it all on, so moving the rug moves the carpet
	for _, p in model:GetChildren() do
		if p:IsA("BasePart") and p ~= base then
			p.Anchored = false
			p.Massless = true
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = base
			weld.Part1 = p
			weld.Parent = p
		end
	end
	model.Parent = workspace
	return model
end

local function showLabels(show: boolean)
	if show == labelsShown then
		return
	end
	labelsShown = show
	local arena = workspace:FindFirstChild("Arena")
	local locations = arena and arena:FindFirstChild("Locations")
	if not locations then
		return
	end
	for _, anchor in locations:GetChildren() do
		local label = anchor:FindFirstChildOfClass("BillboardGui")
		if label then
			label.Enabled = show
		end
	end
end

local function jump()
	if player:GetAttribute("Riding") ~= true then
		return
	end
	local start = tonumber(ReplicatedStorage:GetAttribute("CarpetStart")) or 0
	local t = State.now()
	if t < start or t - lastJump < 0.5 then
		return
	end
	lastJump = t
	Remotes.event("RoyaleAction"):FireServer("Jump")
end

local function step()
	local t = State.now()
	local active = ReplicatedStorage:GetAttribute("CarpetActive") == true
	local cf = if active then CarpetController.cframeAt(t) else nil
	local size = ReplicatedStorage:GetAttribute("CarpetSize")
	-- (a gentle bob as it flies, riders included)
	local bob = CFrame.new(0, math.sin(t * 1.3) * 0.6, 0) * CFrame.Angles(math.sin(t * 0.9) * 0.02, 0, 0)

	-- the carpet itself
	if cf and typeof(size) == "Vector3" then
		if carpet and carpetSize ~= size then
			carpet:Destroy()
			carpet = nil
		end
		if not carpet then
			carpet = buildCarpet(size)
			carpetSize = size
		end
		local rug = (carpet :: Model).PrimaryPart
		if rug then
			rug.CFrame = cf * bob
		end
	elseif carpet then
		carpet:Destroy()
		carpet = nil
	end

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local hum = character and character:FindFirstChildOfClass("Humanoid")
	local riding = player:GetAttribute("Riding") == true
	local gliding = player:GetAttribute("Gliding") == true
	local seat = player:GetAttribute("CarpetSeat")

	-- riding: sit in your seat as the carpet flies
	if riding and cf and root and hum and typeof(seat) == "Vector3" then
		root.CFrame = cf * bob * CFrame.new(seat)
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
		if not hum.Sit then
			hum.Sit = true
		end
	end

	-- gliding: fall gently, steer with the usual movement keys
	if gliding and root and hum then
		if hum.Sit then
			hum.Sit = false
		end
		local v = root.AssemblyLinearVelocity or Vector3.zero
		local move = hum.MoveDirection or Vector3.zero
		local flat = if move.Magnitude > 0.1 then move.Unit * R.GlideSpeed else Vector3.new(v.X, 0, v.Z) * 0.96
		root.AssemblyLinearVelocity = Vector3.new(flat.X, math.max(v.Y, -R.GlideFallSpeed), flat.Z)
	end

	-- the buttons and hints
	local start = tonumber(ReplicatedStorage:GetAttribute("CarpetStart")) or 0
	jumpButton.Visible = riding and t >= start
	hint.Visible = riding or gliding
	if riding then
		hint.Text = if t < start
			then "🧞  All aboard! The carpet takes off in " .. math.max(1, math.ceil(start - t)) .. "s"
			else "🧞  Pick a spot and jump!  Names float over every town and castle"
	elseif gliding then
		hint.Text = "🍃  Gliding down: steer with your movement keys. Nobody can hurt you until you land"
	end
	showLabels((riding or gliding) and State.inMatch())
end

function CarpetController.init()
	gui = Widgets.screen("Carpet", 6)
	-- (between the toasts in the middle of the screen and the wand bar)
	jumpButton = Widgets.button("🧞  JUMP OFF  (SPACE)", {
		size = UDim2.fromOffset(300, 56),
		position = UDim2.new(0.5, -150, 1, -230),
		color = Theme.rgb({ 70, 120, 220 }),
		textSize = 24,
		onClick = jump,
		parent = gui,
	})
	jumpButton.Name = "JumpButton"
	jumpButton.Visible = false
	Create.stroke(C.Gold, 2, 0.1).Parent = jumpButton
	hint = Widgets.label({
		Name = "CarpetHint",
		Size = UDim2.fromOffset(720, 28),
		Position = UDim2.new(0.5, -360, 1, -264),
		TextSize = 18,
		Font = Theme.Bold,
		TextColor3 = C.Gold,
		TextStrokeTransparency = 0.3,
		TextXAlignment = Enum.TextXAlignment.Center,
		Visible = false,
		Parent = gui,
	})

	-- SPACE on a keyboard, the jump button on a phone or a gamepad's A all ask to jump
	UserInputService.JumpRequest:Connect(jump)
	RunService.RenderStepped:Connect(step)
end

return CarpetController
