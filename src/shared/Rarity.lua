--!strict
-- Rarity tiers shared by wands, spells and spell parts.

export type RarityName = string -- "Common" | "Uncommon" | "Rare" | "Epic" | "Legendary" | "Mythic"

export type RarityInfo = {
	rank: number,
	color: { number },
	weight: number,
}

local Rarity = {}

Rarity.Order = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic" } :: { RarityName }

Rarity.Info = {
	Common = { rank = 1, color = { 200, 200, 200 }, weight = 100 },
	Uncommon = { rank = 2, color = { 96, 210, 96 }, weight = 45 },
	Rare = { rank = 3, color = { 70, 145, 255 }, weight = 18 },
	Epic = { rank = 4, color = { 180, 90, 255 }, weight = 6 },
	Legendary = { rank = 5, color = { 255, 175, 40 }, weight = 1.6 },
	Mythic = { rank = 6, color = { 255, 70, 100 }, weight = 0.35 },
} :: { [string]: RarityInfo }

function Rarity.rank(name: string): number
	local info = Rarity.Info[name]
	return if info then info.rank else 1
end

function Rarity.fromRank(rank: number): RarityName
	local clamped = math.clamp(math.floor(rank), 1, #Rarity.Order)
	return Rarity.Order[clamped]
end

-- Luck bends the distribution toward rarer tiers. 0 = default odds.
function Rarity.weightFor(name: string, luck: number?): number
	local info = Rarity.Info[name]
	if not info then
		return 0
	end
	return info.weight * (1 + (luck or 0)) ^ (info.rank - 1)
end

-- rng must provide NextNumber(min, max) (Roblox Random or a compatible shim).
function Rarity.roll(rng: any, luck: number?, maxRank: number?): RarityName
	local total = 0
	for _, name in Rarity.Order do
		if Rarity.Info[name].rank <= (maxRank or 99) then
			total += Rarity.weightFor(name, luck)
		end
	end
	local pick = rng:NextNumber(0, total)
	for _, name in Rarity.Order do
		if Rarity.Info[name].rank <= (maxRank or 99) then
			pick -= Rarity.weightFor(name, luck)
			if pick <= 0 then
				return name
			end
		end
	end
	return "Common"
end

return Rarity
