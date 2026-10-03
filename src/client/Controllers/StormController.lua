-- Draws the shrinking Mana Storm wall locally from replicated attributes,
-- and tints the screen while you are caught outside it.

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
local shownRadius = 0
local lastRadius = -1
local tint: ColorCorrectionEffect
local outside = false

local function layout(center: Vector3, radius: number)
	local width = (2 * math.pi * radius) / SEGMENTS + 1
	for i, seg in segments do
		local angle = (i / SEGMENTS) * math.pi * 2
		local pos = Vector3.new(
			center.X + math.cos(angle) * radius,
			center.Y + HEIGHT / 2 - 100,
			center.Z + math.sin(angle) * radius
		)
		seg.Size = Vector3.new(width, HEIGHT, 1)
		seg.CFrame = CFrame.lookAt(pos, Vector3.new(center.X, pos.Y, center.Z))
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
				for _, seg in segments do
					seg.Transparency = 0
				end
			end
			shownRadius += (radius - shownRadius) * math.min(1, dt * 4)
			if math.abs(shownRadius - lastRadius) > 0.05 then
				lastRadius = shownRadius
				layout(center, shownRadius)
			end
		end

		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local isOutside = false
		if active and root and player:GetAttribute("Alive") then
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
