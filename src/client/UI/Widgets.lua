-- Reusable UI pieces: item tiles, buttons, bars, info cards, the hover tooltip,
-- and a resolution-independent root frame so the UI fits phones and monitors.

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Create = require(script.Parent.Create)
local Theme = require(script.Parent.Theme)
local ItemInfo = require(script.Parent.ItemInfo)

local Widgets = {}

local C = Theme.Colors
local REFERENCE = Vector2.new(1280, 720)

---------------------------------------------------------------------------
-- Scaling root
---------------------------------------------------------------------------

-- Returns a full-screen frame whose children are designed for 1280x720 and scaled to fit.
function Widgets.scaledRoot(screenGui: ScreenGui): Frame
	local root = Create("Frame", {
		Name = "Root",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = screenGui,
	})
	local scale = Create("UIScale", { Parent = root })
	local function update()
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		local vp = camera.ViewportSize
		local s = math.clamp(math.min(vp.X / REFERENCE.X, vp.Y / REFERENCE.Y), 0.5, 1.3)
		scale.Scale = s
		root.Size = UDim2.fromScale(1 / s, 1 / s)
	end
	update()
	local camera = workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(update)
	end
	return root
end

function Widgets.screen(name: string, displayOrder: number?): ScreenGui
	local player = game:GetService("Players").LocalPlayer
	return Create("ScreenGui", {
		Name = name,
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = displayOrder or 0,
		Parent = player:WaitForChild("PlayerGui"),
	})
end

---------------------------------------------------------------------------
-- Basic pieces
---------------------------------------------------------------------------

function Widgets.label(props: { [string]: any }): TextLabel
	local defaults = {
		BackgroundTransparency = 1,
		Font = Theme.Font,
		TextColor3 = C.Text,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
	}
	for k, v in props do
		defaults[k] = v
	end
	return Create("TextLabel", defaults)
end

function Widgets.panel(props: { [string]: any }): Frame
	local frame = Create("Frame", {
		BackgroundColor3 = C.Panel,
		BorderSizePixel = 0,
	}, { Create.corner(10), Create.stroke(C.Stroke, 1.5, 0.3) })
	Create.apply(frame, props)
	return frame
end

export type ButtonOptions = {
	size: UDim2?,
	color: Color3?,
	textColor: Color3?,
	textSize: number?,
	layoutOrder: number?,
	position: UDim2?,
	anchor: Vector2?,
	onClick: (() -> ())?,
	parent: Instance?,
}

function Widgets.button(text: string, opts: ButtonOptions?): TextButton
	local o: ButtonOptions = opts or {}
	local base = o.color or C.Accent
	local button = Create("TextButton", {
		Text = text,
		Font = Theme.Bold,
		TextSize = o.textSize or 15,
		TextColor3 = o.textColor or Color3.new(1, 1, 1),
		BackgroundColor3 = base,
		AutoButtonColor = false,
		Size = o.size or UDim2.fromOffset(120, 34),
		Position = o.position or UDim2.new(),
		AnchorPoint = o.anchor or Vector2.zero,
		LayoutOrder = o.layoutOrder or 0,
	}, { Create.corner(8) })
	button.MouseEnter:Connect(function()
		TweenService:Create(button, TweenInfo.new(0.12), { BackgroundColor3 = base:Lerp(Color3.new(1, 1, 1), 0.18) })
			:Play()
	end)
	button.MouseLeave:Connect(function()
		TweenService:Create(button, TweenInfo.new(0.12), { BackgroundColor3 = base }):Play()
	end)
	if o.onClick then
		button.Activated:Connect(o.onClick)
	end
	if o.parent then
		button.Parent = o.parent
	end
	return button
end

export type Bar = { frame: Frame, fill: Frame, set: (number) -> (), label: TextLabel }

function Widgets.bar(color: Color3, size: UDim2, parent: Instance?): Bar
	local frame = Create("Frame", {
		Size = size,
		BackgroundColor3 = Color3.fromRGB(20, 18, 30),
		BorderSizePixel = 0,
		Parent = parent,
	}, { Create.corner(6), Create.stroke(Color3.fromRGB(0, 0, 0), 1.5, 0.4) })
	local fill = Create("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Parent = frame,
	}, {
		Create.corner(6),
		Create("UIGradient", {
			Color = ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.25), color),
			Rotation = 90,
		}),
	})
	local label = Widgets.label({
		Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		Font = Theme.Bold,
		TextSize = 13,
		TextStrokeTransparency = 0.5,
		ZIndex = 3,
		Parent = frame,
	})
	return {
		frame = frame,
		fill = fill,
		label = label,
		set = function(alpha: number)
			fill.Size = UDim2.fromScale(math.clamp(alpha, 0, 1), 1)
			fill.Visible = alpha > 0.001
		end,
	}
end

---------------------------------------------------------------------------
-- Info card (used by the tooltip and the details panels)
---------------------------------------------------------------------------

function Widgets.fillInfo(container: Frame, info: ItemInfo.Info?)
	for _, child in container:GetChildren() do
		if not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
			child:Destroy()
		end
	end
	if not container:FindFirstChildOfClass("UIListLayout") then
		Create.list(Enum.FillDirection.Vertical, 3).Parent = container
	end
	if not info then
		return
	end
	local order = 0
	local function nextOrder(): number
		order += 1
		return order
	end
	Widgets.label({
		Text = info.title,
		Font = Theme.Bold,
		TextSize = 17,
		TextColor3 = info.color,
		TextWrapped = true,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, 20),
		LayoutOrder = nextOrder(),
		Parent = container,
	})
	if info.subtitle then
		Widgets.label({
			Text = info.subtitle,
			TextSize = 12,
			TextColor3 = C.Dim,
			Size = UDim2.new(1, 0, 0, 15),
			LayoutOrder = nextOrder(),
			Parent = container,
		})
	end
	if info.lines then
		for _, line in info.lines do
			local row = Create("Frame", {
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 16),
				LayoutOrder = nextOrder(),
				Parent = container,
			})
			Widgets.label({
				Text = line[1],
				TextSize = 13,
				TextColor3 = C.Dim,
				Size = UDim2.fromScale(0.5, 1),
				Parent = row,
			})
			Widgets.label({
				Text = line[2],
				TextSize = 13,
				Font = Theme.Bold,
				TextXAlignment = Enum.TextXAlignment.Right,
				Size = UDim2.fromScale(0.5, 1),
				Position = UDim2.fromScale(0.5, 0),
				TextTruncate = Enum.TextTruncate.AtEnd,
				Parent = row,
			})
		end
	end
	if info.body then
		Widgets.label({
			Text = info.body,
			TextSize = 13,
			TextColor3 = Color3.fromRGB(205, 198, 225),
			TextWrapped = true,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, 0, 0, 16),
			LayoutOrder = nextOrder(),
			Parent = container,
		})
	end
end

---------------------------------------------------------------------------
-- Tooltip
---------------------------------------------------------------------------

local tooltip: Frame? = nil
local tooltipOwner: GuiObject? = nil

function Widgets.initTooltip()
	if tooltip then
		return
	end
	local gui = Widgets.screen("Tooltip", 50)
	local root = Widgets.scaledRoot(gui)
	local frame = Widgets.panel({
		Name = "Tooltip",
		Size = UDim2.fromOffset(270, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Color3.fromRGB(20, 17, 32),
		Visible = false,
		ZIndex = 20,
		Parent = root,
	})
	Create.padding(10, 8).Parent = frame
	tooltip = frame
	RunService.RenderStepped:Connect(function()
		local tip = frame
		if not tip.Visible then
			return
		end
		if tooltipOwner and (not tooltipOwner.Parent or not tooltipOwner.Visible) then
			tip.Visible = false
			return
		end
		-- the tooltip ScreenGui ignores the top-bar inset, so raw mouse coordinates line up
		local mouse = UserInputService:GetMouseLocation()
		local scale = (root:FindFirstChildOfClass("UIScale") :: UIScale).Scale
		local x = mouse.X / scale + 18
		local y = mouse.Y / scale + 12
		local size = tip.AbsoluteSize / scale
		local screen = root.AbsoluteSize / scale
		if x + size.X > screen.X - 8 then
			x = mouse.X / scale - size.X - 12
		end
		if y + size.Y > screen.Y - 8 then
			y = screen.Y - size.Y - 8
		end
		tip.Position = UDim2.fromOffset(x, y)
	end)
end

function Widgets.attachTooltip(gui: GuiObject, getInfo: () -> ItemInfo.Info?)
	if UserInputService.TouchEnabled and not UserInputService.MouseEnabled then
		return
	end
	gui.MouseEnter:Connect(function()
		local tip = tooltip
		if not tip then
			return
		end
		local info = getInfo()
		if not info then
			return
		end
		tooltipOwner = gui
		Widgets.fillInfo(tip, info)
		tip.Visible = true
	end)
	gui.MouseLeave:Connect(function()
		if tooltipOwner == gui and tooltip then
			tooltip.Visible = false
			tooltipOwner = nil
		end
	end)
end

function Widgets.hideTooltip()
	if tooltip then
		tooltip.Visible = false
		tooltipOwner = nil
	end
end

---------------------------------------------------------------------------
-- Item tiles
---------------------------------------------------------------------------

export type TileOptions = {
	name: string?,
	size: number?,
	icon: string?,
	iconColor: Color3?,
	border: Color3?,
	count: number?,
	corner: string?,
	wandColor: Color3?,
	gemColor: Color3?,
	empty: boolean?,
	selected: boolean?,
	highlight: boolean?,
	layoutOrder: number?,
	label: string?,
	onClick: (() -> ())?,
	onRightClick: (() -> ())?,
	info: (() -> ItemInfo.Info?)?,
	parent: Instance?,
}

function Widgets.tile(o: TileOptions): TextButton
	local size = o.size or 52
	local tint = o.iconColor or C.Panel3
	local button = Create("TextButton", {
		Name = o.name or "Tile",
		Text = "",
		AutoButtonColor = false,
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = if o.empty then Color3.fromRGB(22, 19, 34) else Theme.darken(tint, 0.62),
		LayoutOrder = o.layoutOrder or 0,
	}, {
		Create.corner(8),
		Create.stroke(
			if o.selected then C.Gold elseif o.highlight then Color3.new(1, 1, 1) else (o.border or C.Stroke),
			if o.selected then 3 else 2,
			if o.empty then 0.6 else 0
		),
	})
	if not o.empty then
		Create("UIGradient", {
			Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(170, 170, 170)),
			Rotation = 90,
			Parent = button,
		})
	end
	if o.wandColor then
		-- a little diagonal wand with a gem
		Create("Frame", {
			Size = UDim2.new(0.12, 0, 0.75, 0),
			Position = UDim2.fromScale(0.5, 0.55),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Rotation = 40,
			BackgroundColor3 = o.wandColor,
			BorderSizePixel = 0,
			Parent = button,
		}, { Create.corner(4) })
		Create("Frame", {
			Size = UDim2.fromScale(0.28, 0.28),
			Position = UDim2.fromScale(0.74, 0.24),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = o.gemColor or C.Accent,
			BorderSizePixel = 0,
			Parent = button,
		}, { Create.corner(100), Create.stroke(Color3.new(1, 1, 1), 1, 0.5) })
	elseif o.icon then
		Create("TextLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(0.7, 0.7),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Text = o.icon,
			TextScaled = true,
			Font = Theme.Bold,
			TextColor3 = Color3.new(1, 1, 1),
			Parent = button,
		})
	end
	if o.corner then
		Create("TextLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(0.38, 0.38),
			Position = UDim2.fromScale(0.02, 0.02),
			Text = o.corner,
			TextScaled = true,
			Font = Theme.Bold,
			TextColor3 = Color3.new(1, 1, 1),
			ZIndex = 2,
			Parent = button,
		})
	end
	if o.count and o.count > 1 then
		Create("TextLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(size - 6, 14),
			Position = UDim2.new(0, 2, 1, -15),
			Text = "x" .. o.count,
			TextXAlignment = Enum.TextXAlignment.Right,
			Font = Theme.Black,
			TextSize = 12,
			TextColor3 = Color3.new(1, 1, 1),
			TextStrokeTransparency = 0.3,
			ZIndex = 3,
			Parent = button,
		})
	end
	if o.label then
		Create("TextLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 12),
			Position = UDim2.new(0, 0, 1, -13),
			Text = o.label,
			Font = Theme.Bold,
			TextSize = 10,
			TextColor3 = C.Dim,
			ZIndex = 3,
			Parent = button,
		})
	end
	if o.onClick then
		button.Activated:Connect(o.onClick)
	end
	if o.onRightClick then
		button.MouseButton2Click:Connect(o.onRightClick)
	end
	if o.info then
		Widgets.attachTooltip(button, o.info)
	end
	if o.parent then
		button.Parent = o.parent
	end
	return button
end

function Widgets.clear(container: Instance, keepLayouts: boolean?)
	for _, child in container:GetChildren() do
		if
			not (
				keepLayouts
				and (
					child:IsA("UIGridStyleLayout")
					or child:IsA("UIPadding")
					or child:IsA("UICorner")
					or child:IsA("UIStroke")
				)
			)
		then
			child:Destroy()
		end
	end
end

return Widgets
