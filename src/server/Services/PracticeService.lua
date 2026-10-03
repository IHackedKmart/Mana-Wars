-- Training dummies on the hub's Practice Range and the library's Practice Terrace. They take
-- damage (with damage numbers and status effects) only from players practising in the Spell Lab,
-- never die, and heal back to full a few seconds after the last hit. A couple on the hub range
-- slide back and forth on rails so players can practise leading their shots.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Build = require(script.Parent.Parent.Map.Build)
local Combatants = require(script.Parent.Combatants)
local MapService = require(script.Parent.MapService)

type Combatant = Combatants.Combatant

local PracticeService = {}

local dummies: { Combatant } = {}
local movers: { { model: Model, base: CFrame, travel: Vector3, phase: number } } = {}
local STRAW = Color3.fromRGB(205, 175, 105)
local BURLAP = Color3.fromRGB(170, 140, 95)

local function buildDummy(spot: CFrame, parent: Instance): Model
	local model = Build.model("TrainingDummy", parent)
	local function piece(
		name: string,
		size: Vector3,
		offset: CFrame,
		material: Enum.Material,
		color: Color3,
		shape: Enum.PartType?
	): Part
		local p =
			Build.part({ Name = name, Size = size, CFrame = spot * offset, Material = material, Color = color }, model)
		if shape then
			p.Shape = shape
		end
		return p
	end
	piece("Post", Vector3.new(0.8, 4, 0.8), CFrame.new(0, 2, 0), Enum.Material.Wood, Color3.fromRGB(100, 70, 45))
	piece("Torso", Vector3.new(2.6, 3, 1.6), CFrame.new(0, 5.2, 0), Enum.Material.Fabric, STRAW)
	piece("Head", Vector3.new(1.9, 1.9, 1.9), CFrame.new(0, 7.7, 0), Enum.Material.Fabric, BURLAP, Enum.PartType.Ball)
	piece(
		"Arm",
		Vector3.new(3.4, 0.8, 0.8),
		CFrame.new(-2.6, 5.9, 0) * CFrame.Angles(0, 0, math.rad(-15)),
		Enum.Material.Wood,
		Color3.fromRGB(100, 70, 45)
	)
	piece(
		"Arm",
		Vector3.new(3.4, 0.8, 0.8),
		CFrame.new(2.6, 5.9, 0) * CFrame.Angles(0, 0, math.rad(15)),
		Enum.Material.Wood,
		Color3.fromRGB(100, 70, 45)
	)
	-- bullseye on the chest (the dummy faces along spot's look vector)
	local ring = piece(
		"Target",
		Vector3.new(0.15, 2, 2),
		CFrame.new(0, 5.3, -0.85) * CFrame.Angles(0, math.rad(90), 0),
		Enum.Material.Neon,
		Color3.fromRGB(230, 60, 60),
		Enum.PartType.Cylinder
	)
	ring.CanCollide = false
	local dot = piece(
		"Bullseye",
		Vector3.new(0.2, 0.9, 0.9),
		CFrame.new(0, 5.3, -0.9) * CFrame.Angles(0, math.rad(90), 0),
		Enum.Material.Neon,
		Color3.new(1, 1, 1),
		Enum.PartType.Cylinder
	)
	dot.CanCollide = false

	local root = piece(
		"HumanoidRootPart",
		Vector3.new(2, 2, 1),
		CFrame.new(0, 5.2, 0),
		Enum.Material.SmoothPlastic,
		Color3.new(1, 1, 1)
	)
	root.Transparency = 1
	root.CanCollide = false
	model.PrimaryPart = root

	local hum = Instance.new("Humanoid")
	hum.RequiresNeck = false
	hum.BreakJointsOnDeath = false
	hum.MaxHealth = Config.Practice.DummyHealth
	hum.Health = Config.Practice.DummyHealth
	hum.DisplayName = "Training Dummy"
	hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOn
	hum.NameDisplayDistance = 80
	hum.HealthDisplayDistance = 80
	hum.Parent = model
	pcall(function()
		hum:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
	end)
	return model
end

function PracticeService.dummies(): { Combatant }
	return dummies
end

function PracticeService.init()
	if not Config.Practice.Enabled then
		return
	end
	local function add(spot: CFrame, parent: Instance, travel: Vector3?)
		local model = buildDummy(spot, parent)
		local c = Combatants.create(if travel then "Moving Dummy" else "Training Dummy", nil)
		c.isDummy = true
		c.inMatch = true
		c.alive = true
		Combatants.setModel(c, model)
		table.insert(dummies, c)
		if travel then
			local hum = model:FindFirstChildOfClass("Humanoid")
			if hum then
				hum.DisplayName = "Moving Dummy"
			end
			table.insert(movers, { model = model, base = model:GetPivot(), travel = travel, phase = #movers * 1.9 })
		end
	end
	local hub = MapService.hub
	if hub then
		for _, spot in hub.dummySpots do
			add(spot.cframe, hub.model, spot.travel)
		end
	end
	local lobby = MapService.lobby
	if lobby then
		for _, spot in lobby.dummySpots do
			add(spot, lobby.model, nil)
		end
	end

	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		if #movers > 0 then
			local t = workspace:GetServerTimeNow() * Config.Practice.MovingDummySpeed
			for _, m in movers do
				m.model:PivotTo(m.base + m.travel * math.sin(t + m.phase))
			end
		end
		acc += dt
		if acc < 0.5 then
			return
		end
		acc = 0
		local t = workspace:GetServerTimeNow()
		for _, c in dummies do
			local hum = c.humanoid
			local idle = t - c.lastAttackTime > Config.Practice.DummyRegenDelay
			if hum and hum.Health < hum.MaxHealth and (idle or hum.Health < 1) then
				hum.Health = hum.MaxHealth
			end
		end
	end)
end

return PracticeService
