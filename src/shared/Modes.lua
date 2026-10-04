--!strict
-- The game modes players pick from the Play menu. Survival Games and Battle Royale take turns in
-- the main arena (one big match per server at a time); duels run in their own floating arenas at
-- the same time as everything else.

export type Mode = {
	id: string,
	name: string,
	icon: string,
	players: string, -- shown on the menu card
	tagline: string,
	description: string,
	color: { number },
}

local Modes = {}

Modes.List = {
	{
		id = "Survival",
		name = "Survival Games",
		icon = "⚔️",
		players = "Up to 12 mages",
		tagline = "The classic",
		description = "Vote on one of five islands, start on a pedestal around the cornucopia, loot chests and outlast everyone as the Mana Storm closes in.",
		color = { 196, 132, 36 },
	},
	{
		id = "Duel",
		name = "1v1 Duel",
		icon = "🤺",
		players = "2 mages",
		tagline = "One spell. One potion. One winner.",
		description = "Face a single rival in a floating arena. You each get a random spell and one potion, and kits and outfit bonuses stay home: a fair fight. Starts as soon as an opponent is found.",
		color = { 200, 60, 80 },
	},
	{
		id = "Royale",
		name = "Battle Royale",
		icon = "🧞",
		players = "Up to 50 mages",
		tagline = "Drop from the magic carpet",
		description = "Ride a flying carpet across an enormous island of five lands, jump off wherever you like and glide down. Loot villages, castles and ruins while the storm circle shrinks.",
		color = { 70, 120, 220 },
	},
} :: { Mode }

Modes.ById = {} :: { [string]: Mode }
for _, m in Modes.List do
	Modes.ById[m.id] = m
end

Modes.Default = "Survival"

function Modes.isValid(id: any): boolean
	return type(id) == "string" and Modes.ById[id] ~= nil
end

return Modes
