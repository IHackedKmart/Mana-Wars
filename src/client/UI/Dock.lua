-- The stack of menu buttons down the left of the screen (Spellbook, Grimoire, class, wardrobe,
-- auction house, coins). Buttons from different controllers share it, so a hidden button
-- never leaves a gap, and the whole stack tucks away while a full-screen window is open.

local Create = require(script.Parent.Create)
local Widgets = require(script.Parent.Widgets)

local Dock = {}

Dock.WIDTH = 236

local frame: Frame? = nil

function Dock.get(): Frame
	if frame then
		return frame
	end
	local gui = Widgets.screen("Dock", 4)
	local root = Widgets.scaledRoot(gui)
	local f = Create("Frame", {
		Name = "Dock",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(Dock.WIDTH, 420),
		Position = UDim2.fromOffset(16, 64),
		Parent = root,
	}, { Create.list(Enum.FillDirection.Vertical, 6) })
	frame = f
	return f
end

function Dock.setVisible(visible: boolean)
	Dock.get().Visible = visible
end

return Dock
