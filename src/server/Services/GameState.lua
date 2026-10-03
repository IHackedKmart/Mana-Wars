-- Server-wide match state that several services read. MatchService is the only writer.
-- Public bits are mirrored to ReplicatedStorage attributes so clients can display them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameState = {
	phase = "Waiting", -- Waiting | Voting | Loading | Countdown | Grace | Battle | Ended
	pvp = false,
	matchStartedAt = 0,
	stormCenter = Vector3.new(0, 0, 0),
	stormRadius = 10000,
	stormDps = 0,
	arena = nil :: { [string]: any }?,
}

function GameState.setPhase(phase: string, endsAt: number?)
	GameState.phase = phase
	GameState.pvp = phase == "Battle"
	ReplicatedStorage:SetAttribute("Phase", phase)
	ReplicatedStorage:SetAttribute("PhaseEndsAt", endsAt or 0)
end

function GameState.setPublic(name: string, value: any)
	ReplicatedStorage:SetAttribute(name, value)
end

-- Damage can only happen while a match is actually being fought.
function GameState.combatAllowed(): boolean
	return GameState.phase == "Grace" or GameState.phase == "Battle"
end

return GameState
