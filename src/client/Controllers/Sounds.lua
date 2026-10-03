-- Sound effects. These use sounds that ship with every Roblox client so the game works
-- out of the box. Swap any id for a Creator Store sound ("rbxassetid://123...") to upgrade.

local Debris = game:GetService("Debris")
local SoundService = game:GetService("SoundService")

local Sounds = {}

Sounds.Ids = {
	Cast = { id = "rbxasset://sounds/swordlunge.wav", volume = 0.35, pitch = 1.4 },
	Hitmarker = { id = "rbxasset://sounds/clickfast.wav", volume = 0.6, pitch = 1.2 },
	Crit = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.5, pitch = 1.6 },
	Hurt = { id = "rbxasset://sounds/collide.wav", volume = 0.5, pitch = 1 },
	Click = { id = "rbxasset://sounds/button.wav", volume = 0.5, pitch = 1 },
	Pickup = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.4, pitch = 1.1 },
	Forge = { id = "rbxasset://sounds/unsheath.wav", volume = 0.6, pitch = 0.8 },
	Blink = { id = "rbxasset://sounds/Rocket whoosh 01.wav", volume = 0.6, pitch = 1.5 },
	Boom = { id = "rbxasset://sounds/Rocket shot.wav", volume = 0.5, pitch = 0.7 },
	Cannon = { id = "rbxasset://sounds/Rocket shot.wav", volume = 1, pitch = 0.35 },
	Gong = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.8, pitch = 0.3 },
	NoMana = { id = "rbxasset://sounds/snap.mp3", volume = 0.6, pitch = 0.8 },
	Freeze = { id = "rbxasset://sounds/glassbreak.wav", volume = 0.5, pitch = 1.2 },
	Potion = { id = "rbxasset://sounds/impact_water.mp3", volume = 0.6, pitch = 1.3 },
	Death = { id = "rbxasset://sounds/uuhhh.mp3", volume = 0.6, pitch = 1 },
}

local cache: { [string]: Sound } = {}

local function base(name: string): Sound?
	local def = Sounds.Ids[name]
	if not def then
		return nil
	end
	local sound = cache[name]
	if not sound then
		local s = Instance.new("Sound")
		s.Name = name
		s.SoundId = def.id
		s.Volume = def.volume
		s.PlaybackSpeed = def.pitch
		s.Parent = SoundService
		cache[name] = s
		sound = s
	end
	return sound
end

-- 2D sound (UI, your own hits)
function Sounds.play(name: string, pitchJitter: number?)
	local sound = base(name)
	if not sound then
		return
	end
	if pitchJitter then
		local def = Sounds.Ids[name]
		sound.PlaybackSpeed = def.pitch * (1 + (math.random() - 0.5) * pitchJitter)
	end
	SoundService:PlayLocalSound(sound)
end

-- 3D sound at a position in the world
function Sounds.at(name: string, position: Vector3, volumeScale: number?)
	local sound = base(name)
	if not sound then
		return
	end
	local attachment = Instance.new("Attachment")
	attachment.WorldPosition = position
	attachment.Parent = workspace.Terrain
	local s = sound:Clone()
	s.Volume = sound.Volume * (volumeScale or 1)
	s.PlaybackSpeed = sound.PlaybackSpeed * (0.92 + math.random() * 0.16)
	s.RollOffMaxDistance = 300
	s.Parent = attachment
	s:Play()
	Debris:AddItem(attachment, 4)
end

return Sounds
