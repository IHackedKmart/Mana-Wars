--!strict
-- Achievements: lifetime goals that pay out Enchanted Coins once. Progress comes from the
-- player's saved stats (see AchievementService.statOf). To also hand out a Roblox badge, create
-- one on the Creator Dashboard and put its id in Config.Achievements.BadgeIds under the same id.

export type Achievement = {
	id: string,
	name: string,
	icon: string,
	description: string,
	stat: string, -- which lifetime stat counts toward it
	goal: number,
	reward: number, -- Enchanted Coins
}

local Achievements = {}

Achievements.List = {
	{
		id = "Graduate",
		name = "Apprentice No More",
		icon = "📖",
		description = "Finish the tutorial.",
		stat = "tutorial",
		goal = 1,
		reward = 5,
	},
	{
		id = "FirstBlood",
		name = "First Blood",
		icon = "⚔️",
		description = "Defeat another mage.",
		stat = "kills",
		goal = 1,
		reward = 5,
	},
	{
		id = "Duelist",
		name = "Duelist",
		icon = "🗡️",
		description = "Defeat 25 mages.",
		stat = "kills",
		goal = 25,
		reward = 15,
	},
	{
		id = "Ruin",
		name = "Archmage of Ruin",
		icon = "💀",
		description = "Defeat 100 mages.",
		stat = "kills",
		goal = 100,
		reward = 40,
	},
	{
		id = "Victor",
		name = "Victor",
		icon = "🏆",
		description = "Win a match.",
		stat = "wins",
		goal = 1,
		reward = 10,
	},
	{
		id = "Champion",
		name = "Champion",
		icon = "👑",
		description = "Win 10 matches.",
		stat = "wins",
		goal = 10,
		reward = 30,
	},
	{
		id = "Legend",
		name = "Living Legend",
		icon = "🌟",
		description = "Win 50 matches.",
		stat = "wins",
		goal = 50,
		reward = 100,
	},
	{
		id = "Survivor",
		name = "Survivor",
		icon = "🥉",
		description = "Finish a match in the top 3.",
		stat = "top3",
		goal = 1,
		reward = 5,
	},
	{
		id = "Regular",
		name = "Regular",
		icon = "🎮",
		description = "Play 25 matches.",
		stat = "matches",
		goal = 25,
		reward = 15,
	},
	{
		id = "Spellwright",
		name = "Spellwright",
		icon = "🔮",
		description = "Forge 10 spells in the Spellforge.",
		stat = "forged",
		goal = 10,
		reward = 10,
	},
	{
		id = "TreasureHunter",
		name = "Treasure Hunter",
		icon = "📦",
		description = "Open 100 chests in matches.",
		stat = "chests",
		goal = 100,
		reward = 15,
	},
	{
		id = "CofferCollector",
		name = "Coffer Collector",
		icon = "🎁",
		description = "Open 10 coffers.",
		stat = "coffers",
		goal = 10,
		reward = 10,
	},
	{
		id = "Tailor",
		name = "Tailor",
		icon = "🧵",
		description = "Stitch your own robe or hat at the Tailor's Loom.",
		stat = "crafted",
		goal = 1,
		reward = 5,
	},
	{
		id = "BeastFriend",
		name = "Beast Friend",
		icon = "🐾",
		description = "Find 5 familiars.",
		stat = "familiars",
		goal = 5,
		reward = 10,
	},
	{
		id = "Shiny",
		name = "Something Shiny",
		icon = "✨",
		description = "Find a Shiny familiar.",
		stat = "shiny",
		goal = 1,
		reward = 20,
	},
	{
		id = "Merchant",
		name = "Merchant",
		icon = "⚖️",
		description = "Sell something at the auction house.",
		stat = "sold",
		goal = 1,
		reward = 5,
	},
	{
		id = "Devoted",
		name = "Devoted",
		icon = "📅",
		description = "Claim the daily reward 7 days in a row.",
		stat = "streak",
		goal = 7,
		reward = 15,
	},
} :: { Achievement }

Achievements.ById = {} :: { [string]: Achievement }
for _, a in Achievements.List do
	Achievements.ById[a.id] = a
end

-- Every stat any achievement counts.
Achievements.Stats = {} :: { string }
do
	local seen = {}
	for _, a in Achievements.List do
		if not seen[a.stat] then
			seen[a.stat] = true
			table.insert(Achievements.Stats, a.stat)
		end
	end
end

function Achievements.totalReward(): number
	local total = 0
	for _, a in Achievements.List do
		total += a.reward
	end
	return total
end

return Achievements
