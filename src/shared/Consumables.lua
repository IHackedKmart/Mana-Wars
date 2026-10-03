--!strict
-- Potions found in chests. Used from the hotbar (Z / X / C / V) or by tapping them.

export type Consumable = {
	id: string,
	name: string,
	icon: string,
	rarity: string,
	key: string,
	color: { number },
	description: string,
}

local Consumables = {}

Consumables.List = {
	{
		id = "HealingDraught",
		name = "Healing Draught",
		icon = "🧪",
		rarity = "Common",
		key = "Z",
		color = { 235, 70, 90 },
		description = "Restores 40 health over 4 seconds.",
	},
	{
		id = "ManaTonic",
		name = "Mana Tonic",
		icon = "💧",
		rarity = "Common",
		key = "X",
		color = { 80, 150, 255 },
		description = "Instantly refills the mana of every wand you carry.",
	},
	{
		id = "SwiftnessElixir",
		name = "Swiftness Elixir",
		icon = "👟",
		rarity = "Uncommon",
		key = "C",
		color = { 120, 255, 170 },
		description = "+35% movement speed for 12 seconds.",
	},
	{
		id = "StoneskinPotion",
		name = "Stoneskin Potion",
		icon = "🧱",
		rarity = "Rare",
		key = "V",
		color = { 190, 160, 120 },
		description = "Grants a 30 point shield for 10 seconds.",
	},
} :: { Consumable }

Consumables.ById = {} :: { [string]: Consumable }
for _, c in Consumables.List do
	Consumables.ById[c.id] = c
end

return Consumables
