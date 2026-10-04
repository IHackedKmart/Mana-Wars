-- Server-wide match state that several services read. MatchService is the only writer.
-- Public bits are mirrored to ReplicatedStorage attributes so clients can display them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameState = {
	phase = "Waiting", -- Waiting | Voting | Gathering | Loading | Countdown | Grace | Carpet | Battle | Ended
	mode = "Survival", -- what the main arena is playing: "Survival" or "Royale"
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
	return GameState.phase == "Grace" or GameState.phase == "Battle" or GameState.phase == "Carpet"
end

-- Whether this combatant may cast and drink potions right now: duelists follow their duel,
-- battle royale mages can't while riding the carpet or gliding down, everyone else the main match.
function GameState.combatAllowedFor(c: any): boolean
	if c.duel then
		return c.duel.state == "Fight"
	end
	if c.dropping then
		return false
	end
	return GameState.combatAllowed()
end

return GameState
