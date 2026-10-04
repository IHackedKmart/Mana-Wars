-- Familiars following their mages. The server puts a "Familiar" attribute on each character
-- (species|rarity|colour|shiny); every client builds and animates the familiars itself, so they
-- move smoothly and cost no network traffic. Fliers hover by your shoulder, walkers trot at
-- your heels.
-- Your own familiar also shows its power on your screen:
--   Keen Nose  - outlines the nearest unopened chest in range (and looks at it)
--   Night Eyes - every 12s, outlines the nearest enemy in range for a moment
-- and the server's "FamiliarNip" effect makes a familiar dart at whoever it nipped.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Familiars = require(ReplicatedStorage.Shared.Familiars)
local FamiliarBuilder = require(script.Parent.FamiliarBuilder)
local FXController = require(script.Parent.FXController)
local VFX = require(script.Parent.VFX)
local Sounds = require(script.Parent.Sounds)
local State = require(script.Parent.State)

local FamiliarController = {}

type Entry = {
	code: string,
	rig: FamiliarBuilder.Rig,
	pos: Vector3,
	facing: Vector3,
	seed: number,
	dart: { target: Vector3, t0: number }?,
	lookAt: Vector3?, -- something to stare at while idle (Keen Nose)
}

local player = Players.LocalPlayer
local entries: { [Model]: Entry } = {}
local folder: Folder
local rng = Random.new()
local clock = 0
local chestHighlight: Highlight
local spotHighlight: Highlight
local spotUntil = 0
local nextSpot = 0

-- Every model that might have a familiar: player characters and bots.
local function owners(): { Model }
	local list = {}
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(list, p.Character)
		end
	end
	local bots = workspace:FindFirstChild("Bots")
	if bots then
		for _, m in bots:GetChildren() do
			if m:IsA("Model") then
				table.insert(list, m)
			end
		end
	end
	return list
end

-- Builds familiars for new owners, rebuilds changed ones and removes the ones whose owner left.
function FamiliarController.refresh()
	local seen: { [Model]: boolean } = {}
	for _, model in owners() do
		local code = model:GetAttribute("Familiar")
		local look = Familiars.decode(code)
		local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
		if look and root then
			seen[model] = true
			local e = entries[model]
			if e and e.code ~= code then
				FamiliarBuilder.destroy(e.rig)
				entries[model] = nil
				e = nil
			end
			if not e then
				local rig = FamiliarBuilder.build(look, folder, true)
				if rig then
					entries[model] = {
						code = code :: string,
						rig = rig,
						pos = root.Position + root.CFrame.RightVector * 2,
						facing = root.CFrame.LookVector,
						seed = rng:NextNumber(0, 10),
						dart = nil,
						lookAt = nil,
					}
				end
			end
		end
	end
	for model, e in entries do
		if not seen[model] then
			FamiliarBuilder.destroy(e.rig)
			entries[model] = nil
		end
	end
end

function FamiliarController.count(): number
	local n = 0
	for _ in entries do
		n += 1
	end
	return n
end

local function groundY(model: Model, root: BasePart): number
	local hum = model:FindFirstChildOfClass("Humanoid")
	if hum and hum.RigType == Enum.HumanoidRigType.R15 then
		return root.Position.Y - hum.HipHeight - root.Size.Y / 2
	end
	return root.Position.Y - 3
end

local function flat(v: Vector3, fallback: Vector3): Vector3
	local f = Vector3.new(v.X, 0, v.Z)
	return if f.Magnitude > 1e-3 then f.Unit else fallback
end

local function step(dt: number)
	clock += dt
	local camera = workspace.CurrentCamera
	local camPos = if camera then camera.CFrame.Position else nil
	for model, e in entries do
		local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root then
			continue
		end
		local rig = e.rig
		local ownerCF = root.CFrame
		local side, back = ownerCF.RightVector, -ownerCF.LookVector
		local target: Vector3
		if rig.flies then
			target = root.Position
				+ side * 2.3
				+ back * 1.6
				+ Vector3.new(0, 1.3 + math.sin(clock * 2 + e.seed) * 0.25, 0)
		else
			local p = root.Position + side * 1.9 + back * 2.2
			target = Vector3.new(p.X, groundY(model, root), p.Z)
		end
		if camPos and (target - camPos).Magnitude > 260 then
			continue -- too far away to see: don't spend time animating it
		end
		local gap = target - e.pos
		if gap.Magnitude > 40 then
			e.pos = target -- the owner teleported
		else
			e.pos = e.pos:Lerp(target, 1 - math.exp(-dt * 6))
		end
		local pos = e.pos
		local face = flat(gap, flat(ownerCF.LookVector, Vector3.new(0, 0, -1)))
		local moving = math.clamp(gap.Magnitude / 2.5, 0, 1)
		if moving < 0.3 and e.lookAt then
			face = flat(e.lookAt - pos, face)
		end
		local dart = e.dart
		if dart then
			-- a quick lunge at whoever it nipped, and back
			local k = (clock - dart.t0) / 0.45
			if k >= 1 then
				e.dart = nil
			else
				local out = if k < 0.35 then k / 0.35 else 1 - (k - 0.35) / 0.65
				pos = pos:Lerp(dart.target, out * 0.85)
				face = flat(dart.target - e.pos, face)
			end
		end
		e.facing = e.facing:Lerp(face, 1 - math.exp(-dt * 8))
		if e.facing.Magnitude < 0.05 then
			e.facing = face
		end
		local hop = if rig.flies then 0 else math.abs(math.sin(clock * 9 + e.seed)) * 0.22 * moving
		local at = pos + Vector3.new(0, hop, 0)
		FamiliarBuilder.pose(rig, CFrame.lookAt(at, at + e.facing), clock, moving)
	end
end

---------------------------------------------------------------------------
-- Your own familiar's power, shown on your screen
---------------------------------------------------------------------------

local function myPower(): (string?, number)
	local character = player.Character
	local look = character and Familiars.decode(character:GetAttribute("Familiar"))
	if not look then
		return nil, 0
	end
	local power, value = Familiars.powerOf(look)
	return if power then power.id else nil, value
end

local function nearestChest(from: Vector3, range: number): Model?
	local arena = workspace:FindFirstChild("Arena")
	local chests = arena and arena:FindFirstChild("Chests")
	if not chests then
		return nil
	end
	local best, bestDist = nil, range
	for _, m in chests:GetChildren() do
		if m:IsA("Model") and m:GetAttribute("ChestId") and not m:GetAttribute("Opened") then
			local d = (m:GetPivot().Position - from).Magnitude
			if d < bestDist then
				best, bestDist = m, d
			end
		end
	end
	return best
end

local function nearestEnemy(from: Vector3, range: number): Model?
	local best, bestDist = nil, range
	local function consider(model: Model?)
		local root = model and model:FindFirstChild("HumanoidRootPart") :: BasePart?
		local hum = model and model:FindFirstChildOfClass("Humanoid")
		if model and root and hum and hum.Health > 0 then
			local d = (root.Position - from).Magnitude
			if d < bestDist then
				best, bestDist = model, d
			end
		end
	end
	for _, p in Players:GetPlayers() do
		if p ~= player and p:GetAttribute("Alive") == true then
			consider(p.Character)
		end
	end
	local bots = workspace:FindFirstChild("Bots")
	if bots then
		for _, m in bots:GetChildren() do
			if m:IsA("Model") and m:GetAttribute("InMatch") then
				consider(m)
			end
		end
	end
	return best
end

local function updatePowers()
	local power, value = myPower()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local mine = character and entries[character]
	local inMatch = State.alive()
	-- Keen Nose
	local chest = if power == "chestSense" and root and inMatch then nearestChest(root.Position, value) else nil
	chestHighlight.Adornee = chest
	chestHighlight.Enabled = chest ~= nil
	if mine then
		mine.lookAt = if chest then chest:GetPivot().Position else nil
	end
	-- Night Eyes
	if clock > spotUntil then
		spotHighlight.Enabled = false
		spotHighlight.Adornee = nil
	end
	if power == "spotter" and root and inMatch and clock >= nextSpot then
		local enemy = nearestEnemy(root.Position, value)
		if enemy then
			spotHighlight.Adornee = enemy
			spotHighlight.Enabled = true
			spotUntil = clock + 2.5
			nextSpot = clock + Familiars.SpotterCooldown
		else
			nextSpot = clock + 1
		end
	end
end

local function highlight(name: string, fill: Color3, outline: Color3): Highlight
	local h = Instance.new("Highlight")
	h.Name = name
	h.FillColor = fill
	h.FillTransparency = 0.8
	h.OutlineColor = outline
	h.OutlineTransparency = 0
	h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	h.Enabled = false
	h.Parent = folder
	return h
end

function FamiliarController.init()
	local existing = workspace:FindFirstChild("Familiars")
	if existing then
		existing:Destroy()
	end
	local f = Instance.new("Folder")
	f.Name = "Familiars"
	f.Parent = workspace
	folder = f
	chestHighlight = highlight("KeenNose", Color3.fromRGB(255, 220, 120), Color3.fromRGB(255, 235, 160))
	spotHighlight = highlight("NightEyes", Color3.fromRGB(255, 60, 60), Color3.fromRGB(255, 120, 120))

	FXController.on("FamiliarNip", function(owner: Model?, target: Vector3, color, element: string?)
		local e = owner and entries[owner]
		if e then
			e.dart = { target = target, t0 = clock }
		end
		local c = if type(color) == "table" then Color3.fromRGB(color[1], color[2], color[3]) else Color3.new(1, 1, 1)
		task.delay(0.15, function()
			VFX.elementBurst(target, element, c, Color3.new(1, 1, 1), 2.5)
			VFX.sparks(target, c, 3, 6)
		end)
		Sounds.at("Hitmarker", target, 0.5)
	end)

	local sinceRefresh, sincePowers = 0, 0
	RunService.RenderStepped:Connect(function(dt)
		sinceRefresh += dt
		sincePowers += dt
		if sinceRefresh > 0.5 then
			sinceRefresh = 0
			FamiliarController.refresh()
		end
		if sincePowers > 0.5 then
			sincePowers = 0
			updatePowers()
		end
		step(dt)
	end)
end

return FamiliarController
