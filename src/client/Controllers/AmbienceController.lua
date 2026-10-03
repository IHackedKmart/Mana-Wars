-- Per-map weather drawn around the camera while you're on the island:
-- snow on Frostpeak, falling ash on Ashen Wastes, drifting dust on Sandsea, glowing spores in Fungal Hollow.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)

local AmbienceController = {}

local WEATHER: { [string]: { [string]: any } } = {
	Snow = {
		Color = ColorSequence.new(Color3.fromRGB(245, 250, 255)),
		Size = NumberSequence.new(0.35),
		Transparency = NumberSequence.new(0.1, 0.4),
		Lifetime = NumberRange.new(4, 6),
		Rate = 160,
		Speed = NumberRange.new(8, 12),
		SpreadAngle = Vector2.new(15, 15),
		LightEmission = 0.2,
	},
	Ash = {
		Color = ColorSequence.new(Color3.fromRGB(90, 85, 85), Color3.fromRGB(255, 140, 60)),
		Size = NumberSequence.new(0.3, 0.15),
		Transparency = NumberSequence.new(0.2, 0.7),
		Lifetime = NumberRange.new(4, 7),
		Rate = 110,
		Speed = NumberRange.new(3, 6),
		SpreadAngle = Vector2.new(30, 30),
		LightEmission = 0.3,
	},
	Spores = {
		Color = ColorSequence.new(Color3.fromRGB(110, 255, 220), Color3.fromRGB(210, 130, 255)),
		Size = NumberSequence.new(0.25, 0.05),
		Transparency = NumberSequence.new(0, 0.6),
		Lifetime = NumberRange.new(5, 9),
		Rate = 60,
		Speed = NumberRange.new(0.5, 2),
		SpreadAngle = Vector2.new(180, 180),
		LightEmission = 1,
	},
	Dust = {
		Color = ColorSequence.new(Color3.fromRGB(225, 200, 150)),
		Size = NumberSequence.new(1.2, 2.2),
		Transparency = NumberSequence.new(0.75, 1),
		Lifetime = NumberRange.new(4, 6),
		Rate = 35,
		Speed = NumberRange.new(4, 7),
		SpreadAngle = Vector2.new(60, 10),
		LightEmission = 0,
	},
}

local emitterPart: Part
local emitter: ParticleEmitter
local current = ""

local function setWeather(name: string)
	if name == current then
		return
	end
	current = name
	local def = WEATHER[name]
	emitter.Enabled = def ~= nil
	if def then
		for key, value in def do
			(emitter :: any)[key] = value
		end
	end
end

function AmbienceController.init()
	emitterPart = Instance.new("Part")
	emitterPart.Name = "Weather"
	emitterPart.Anchored = true
	emitterPart.CanCollide = false
	emitterPart.CanQuery = false
	emitterPart.CanTouch = false
	emitterPart.Transparency = 1
	emitterPart.Size = Vector3.new(90, 1, 90)
	emitterPart.Parent = workspace
	emitter = Instance.new("ParticleEmitter")
	emitter.EmissionDirection = Enum.NormalId.Bottom
	emitter.Enabled = false
	emitter.Parent = emitterPart

	RunService.RenderStepped:Connect(function()
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		local pos = camera.CFrame.Position
		-- no weather up in the lobby (or while the lobby is watching through the window)
		local onIsland = pos.Y < Config.Arena.LobbyHeight - 100
		setWeather(if onIsland then tostring(ReplicatedStorage:GetAttribute("MapWeather") or "") else "")
		emitterPart.CFrame = CFrame.new(pos + Vector3.new(0, 25, 0))
	end)
end

return AmbienceController
