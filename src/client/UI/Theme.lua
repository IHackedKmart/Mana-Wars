-- Colours and fonts for every screen. Tweak here to re-skin the whole UI.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Rarity = require(ReplicatedStorage.Shared.Rarity)

local Theme = {}

Theme.Font = Enum.Font.GothamMedium
Theme.Bold = Enum.Font.GothamBold
Theme.Black = Enum.Font.GothamBlack
Theme.Title = Enum.Font.Fantasy

Theme.Colors = {
	Background = Color3.fromRGB(17, 14, 29),
	Panel = Color3.fromRGB(29, 24, 46),
	Panel2 = Color3.fromRGB(40, 34, 61),
	Panel3 = Color3.fromRGB(56, 47, 84),
	Stroke = Color3.fromRGB(108, 86, 168),
	Accent = Color3.fromRGB(146, 96, 240),
	Gold = Color3.fromRGB(255, 205, 90),
	GoldDeep = Color3.fromRGB(176, 128, 46),
	Ink = Color3.fromRGB(9, 7, 16),
	Text = Color3.fromRGB(236, 230, 248),
	Dim = Color3.fromRGB(160, 150, 185),
	Good = Color3.fromRGB(120, 230, 140),
	Bad = Color3.fromRGB(255, 95, 95),
	Mana = Color3.fromRGB(90, 160, 255),
	Health = Color3.fromRGB(235, 70, 90),
	Shield = Color3.fromRGB(150, 210, 255),
}

Theme.CategoryColors = {
	Form = Color3.fromRGB(90, 140, 230),
	Element = Color3.fromRGB(230, 120, 60),
	Modifier = Color3.fromRGB(90, 200, 160),
	Trigger = Color3.fromRGB(230, 190, 70),
}

function Theme.rgb(c: { number }?): Color3
	if not c then
		return Color3.new(1, 1, 1)
	end
	return Color3.fromRGB(c[1], c[2], c[3])
end

function Theme.rarity(name: string?): Color3
	local info = Rarity.Info[name or "Common"] or Rarity.Info.Common
	return Theme.rgb(info.color)
end

function Theme.darken(c: Color3, amount: number): Color3
	return c:Lerp(Color3.new(0, 0, 0), amount)
end

function Theme.lighten(c: Color3, amount: number): Color3
	return c:Lerp(Color3.new(1, 1, 1), amount)
end

return Theme
