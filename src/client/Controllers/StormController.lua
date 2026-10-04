-- Draws the shrinking Mana Storm wall locally from replicated attributes, and tints the screen
-- while you are caught outside it. In a battle royale the storm's centre moves from circle to
-- circle, and a faint white wall marks the next circle.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local StormController = {}

local SEGMENTS = 72
local HEIGHT = 600
local player = Players.LocalPlayer

local folder: Folder
local segments: { Part } = {}
local nextSegments: { Part } = {}
local shownRadius = 0
local lastRadius = -1
local shownCenter = Vector3.zero
local lastCenter = Vector3.zero
local nextShown: Vector3? = nil -- (centre X/Z + radius in Y, of the next circle last drawn)
local tint: ColorCorrectionEffect
local outside = false

local function layout(center: Vector3, radius: number, list: { Part }?)
	local parts = list or segments
	local count = #parts
	local width = (2 * math.pi * radius) / count + 1
	for i, seg in parts do
		local angle = (i / count) * math.pi * 2
		local pos = Vector3.new(
			center.X + math.cos(angle) * radius,
			center.Y + HEIGHT / 2 - 100,
			center.Z + math.sin(angle) * radius
		)
		seg.Size = Vector3.new(width, HEIGHT, if parts == segments then 1 else 0.4)
		seg.CFrame = CFrame.lookAt(pos, Vector3.new(center.X, pos.Y, center.Z))
	end
end

-- The battle royale's next circle: a faint white wall where the storm will stop.
local function updateNext(active: boolean)
	local center = ReplicatedStorage:GetAttribute("StormNextCenter")
	local radius = tonumber(ReplicatedStorage:GetAttribute("StormNextRadius"))
	local show = active and typeof(center) == "Vector3" and radius ~= nil and radius > 1
	if not show then
		if nextShown then
			nextShown = nil
			for _, seg in nextSegments do
				seg.Transparency = 1
			end
		end
		return
	end
	local key = Vector3.new(center.X, radius :: number, center.Z)
	if nextShown and (nextShown - key).Magnitude < 0.05 then
		return
	end
	nextShown = key
	layout(center, radius :: number, nextSegments)
	for _, seg in nextSegments do
		seg.Transparency = 0.75
	end
end

function StormController.init()
	folder = Instance.new("Folder")
	folder.Name = "ClientStorm"
	folder.Parent = workspace
	for i = 1, SEGMENTS do
		local seg = Instance.new("Part")
		seg.Name = "Storm" .. i
		seg.Anchored = true
		seg.CanCollide = false
		seg.CanQuery = false
		seg.CanTouch = false
		seg.CastShadow = false
		seg.Material = Enum.Material.ForceField
		seg.Color = Color3.fromRGB(190, 90, 255)
		seg.Transparency = 1
		seg.Parent = folder
		segments[i] = seg
	end
	for i = 1, 48 do
		local seg = Instance.new("Part")
		seg.Name = "NextCircle" .. i
		seg.Anchored = true
		seg.CanCollide = false
		seg.CanQuery = false
		seg.CanTouch = false
		seg.CastShadow = false
		seg.Material = Enum.Material.Neon
		seg.Color = Color3.fromRGB(235, 240, 255)
		seg.Transparency = 1
		seg.Parent = folder
		nextSegments[i] = seg
	end

	tint = Instance.new("ColorCorrectionEffect")
	tint.Name = "StormTint"
	tint.Enabled = true
	tint.TintColor = Color3.new(1, 1, 1)
	tint.Parent = Lighting

	RunService.RenderStepped:Connect(function(dt)
		local active = ReplicatedStorage:GetAttribute("StormActive") == true
		local radius = ReplicatedStorage:GetAttribute("StormRadius") or 1e5
		local center = ReplicatedStorage:GetAttribute("StormCenter") or Vector3.zero
		if not active or radius > 5000 then
			if lastRadius ~= -1 then
				for _, seg in segments do
					seg.Transparency = 1
				end
				lastRadius = -1
			end
			shownRadius = radius
		else
			if lastRadius == -1 then
				shownRadius = radius
				shownCenter = center
				for _, seg in segments do
					seg.Transparency = 0
				end
			end
			local ease = math.min(1, dt * 4)
			shownRadius += (radius - shownRadius) * ease
			shownCenter = shownCenter:Lerp(center, ease)
			if math.abs(shownRadius - lastRadius) > 0.05 or (shownCenter - lastCenter).Magnitude > 0.05 then
				lastRadius = shownRadius
				lastCenter = shownCenter
				layout(shownCenter, shownRadius)
			end
		end
		updateNext(active)

		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local isOutside = false
		if active and root and player:GetAttribute("Alive") and player:GetAttribute("Mode") ~= "Duel" then
			local d = Vector3.new(root.Position.X - center.X, 0, root.Position.Z - center.Z).Magnitude
			isOutside = d > radius
		end
		if isOutside ~= outside then
			outside = isOutside
			TweenService:Create(tint, TweenInfo.new(0.5), {
				TintColor = if outside then Color3.fromRGB(235, 190, 255) else Color3.new(1, 1, 1),
				Saturation = if outside then -0.35 else 0,
			}):Play()
		end
	end)
end

return StormController
