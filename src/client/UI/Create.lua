-- Declarative-ish instance builder:
--   Create("TextButton", { Text = "Hi", Activated = function() ... end }, { child1, child2 })
-- Function values for RBXScriptSignal properties are connected instead of assigned.

local Create = {}

local function apply(inst: Instance, props: { [string]: any }?)
	if not props then
		return
	end
	local parent = nil
	for key, value in props do
		if key == "Parent" then
			parent = value
		elseif type(value) == "function" and typeof((inst :: any)[key]) == "RBXScriptSignal" then
			(inst :: any)[key]:Connect(value)
		else
			(inst :: any)[key] = value
		end
	end
	if parent then
		inst.Parent = parent
	end
end

-- Roblox fills new text objects with "Label" / "Button" / "TextBox"; start them empty instead
local TEXT_CLASSES = { TextLabel = true, TextButton = true, TextBox = true }

local function new(className: string, props: { [string]: any }?, children: { Instance }?): any
	local inst = Instance.new(className)
	if TEXT_CLASSES[className] then
		(inst :: any).Text = ""
	end
	if children then
		for _, child in children do
			child.Parent = inst
		end
	end
	apply(inst, props)
	return inst
end

setmetatable(Create, {
	__call = function(_, className: string, props: { [string]: any }?, children: { Instance }?)
		return new(className, props, children)
	end,
})

function Create.corner(radius: number?): UICorner
	return new("UICorner", { CornerRadius = UDim.new(0, radius or 8) })
end

function Create.stroke(color: Color3, thickness: number?, transparency: number?): UIStroke
	return new("UIStroke", {
		Color = color,
		Thickness = thickness or 1.5,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function Create.padding(px: number, py: number?): UIPadding
	local y = py or px
	return new("UIPadding", {
		PaddingLeft = UDim.new(0, px),
		PaddingRight = UDim.new(0, px),
		PaddingTop = UDim.new(0, y),
		PaddingBottom = UDim.new(0, y),
	})
end

function Create.list(direction: Enum.FillDirection?, gap: number?, align: Enum.HorizontalAlignment?): UIListLayout
	return new("UIListLayout", {
		FillDirection = direction or Enum.FillDirection.Vertical,
		Padding = UDim.new(0, gap or 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = align or Enum.HorizontalAlignment.Left,
	})
end

function Create.grid(cell: number, gap: number?): UIGridLayout
	return new("UIGridLayout", {
		CellSize = UDim2.fromOffset(cell, cell),
		CellPadding = UDim2.fromOffset(gap or 6, gap or 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
end

function Create.apply(inst: Instance, props: { [string]: any })
	apply(inst, props)
end

return Create
