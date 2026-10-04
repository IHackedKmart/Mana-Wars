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

-- A soft top-to-bottom shade (a UIGradient multiplies the background colour).
local function shade(parent: Instance, bottom: number?)
	local b = bottom or 0.78
	Create("UIGradient", {
		Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.new(b, b, b)),
		Rotation = 90,
		Parent = parent,
	})
end
Widgets.shade = shade

function Widgets.panel(props: { [string]: any }): Frame
	local frame = Create("Frame", {
		BackgroundColor3 = C.Panel,
		BorderSizePixel = 0,
	}, { Create.corner(10), Create.stroke(C.Stroke, 1.5, 0.45) })
	shade(frame, 0.82)
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
		TextStrokeTransparency = 0.85,
		BackgroundColor3 = base,
		AutoButtonColor = false,
		Size = o.size or UDim2.fromOffset(120, 34),
		Position = o.position or UDim2.new(),
		AnchorPoint = o.anchor or Vector2.zero,
		LayoutOrder = o.layoutOrder or 0,
	}, { Create.corner(8), Create.stroke(C.Ink, 1, 0.55) })
	shade(button, 0.74)
	-- hover: a light sheen on top, so whatever colour the code sets the button to is kept
	local sheen = Create("Frame", {
		Name = "Sheen",
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 0,
		Parent = button,
	}, { Create.corner(8) })
	button.MouseEnter:Connect(function()
		TweenService:Create(sheen, TweenInfo.new(0.12), { BackgroundTransparency = 0.86 }):Play()
	end)
	button.MouseLeave:Connect(function()
		TweenService:Create(sheen, TweenInfo.new(0.12), { BackgroundTransparency = 1 }):Play()
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

---------------------------------------------------------------------------
-- Windows (every full-screen menu shares this frame)
---------------------------------------------------------------------------

export type WindowOptions = {
	title: string,
	subtitle: string?,
	icon: string?,
	size: Vector2,
	onClose: (() -> ())?,
}

export type Window = {
	root: Frame,
	scrim: Frame,
	panel: Frame,
	body: Frame,
	header: Frame,
	right: Frame, -- header area left of the close button, for coins / extra buttons
	title: TextLabel,
	subtitle: TextLabel,
	close: TextButton,
}

-- A framed window: dims the screen behind it, a gold-trimmed panel, an icon + title +
-- subtitle header with a gilded divider, a close button, and a body frame for the content.
function Widgets.window(gui: ScreenGui, o: WindowOptions): Window
	local root = Widgets.scaledRoot(gui)
	local scrim = Create("Frame", {
		Name = "Scrim",
		BackgroundColor3 = C.Ink,
		BackgroundTransparency = 0.42,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Active = true, -- clicks don't fall through to the world UI behind
		Parent = root,
	})
	local panel = Create("Frame", {
		Name = "Window",
		BackgroundColor3 = C.Background,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(o.size.X, o.size.Y),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Parent = root,
	}, { Create.corner(14), Create.stroke(C.GoldDeep, 2, 0.1) })
	Create("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
			ColorSequenceKeypoint.new(0.12, Color3.fromRGB(235, 232, 245)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(190, 185, 205)),
		}),
		Rotation = 90,
		Parent = panel,
	})
	-- an inner hairline for a double-border look
	Create("Frame", {
		Name = "Inlay",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -10, 1, -10),
		Position = UDim2.fromOffset(5, 5),
		ZIndex = 0,
		Parent = panel,
	}, { Create.corner(11), Create.stroke(C.Stroke, 1, 0.55) })

	local header = Create("Frame", {
		Name = "Header",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 62),
		Parent = panel,
	})
	local x = 22
	if o.icon then
		Create("TextLabel", {
			Name = "Icon",
			BackgroundTransparency = 1,
			Text = o.icon,
			TextScaled = true,
			Font = Theme.Bold,
			Size = UDim2.fromOffset(34, 34),
			Position = UDim2.fromOffset(20, 14),
			Parent = header,
		})
		x = 64
	end
	local title = Widgets.label({
		Name = "Title",
		Text = o.title,
		Font = Theme.Title,
		TextSize = 30,
		TextColor3 = C.Gold,
		TextStrokeTransparency = 0.55,
		Size = UDim2.new(0.5, 0, 0, 32),
		Position = UDim2.fromOffset(x, 8),
		Parent = header,
	})
	local subtitle = Widgets.label({
		Name = "Subtitle",
		Text = o.subtitle or "",
		TextSize = 12,
		TextColor3 = C.Dim,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Size = UDim2.new(1, -x - 330, 0, 16),
		Position = UDim2.fromOffset(x + 1, 40),
		Parent = header,
	})
	-- gilded divider that fades at both ends
	local divider = Create("Frame", {
		Name = "Divider",
		BackgroundColor3 = C.Gold,
		BorderSizePixel = 0,
		Size = UDim2.new(1, -40, 0, 2),
		Position = UDim2.fromOffset(20, 61),
		Parent = panel,
	})
	Create("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.15, 0.25),
			NumberSequenceKeypoint.new(0.85, 0.25),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Parent = divider,
	})
	local close = Widgets.button("X", {
		size = UDim2.fromOffset(36, 36),
		position = UDim2.new(1, -52, 0, 13),
		color = C.Panel3,
		textSize = 16,
		onClick = function()
			if o.onClose then
				o.onClose()
			end
		end,
		parent = header,
	})
	close.Name = "Close"
	close.Font = Theme.Black
	close.TextSize = 18
	local right = Create("Frame", {
		Name = "HeaderRight",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(420, 36),
		Position = UDim2.new(1, -62, 0, 13),
		AnchorPoint = Vector2.new(1, 0),
		Parent = header,
	}, { Create.list(Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Right) })
	local list = right:FindFirstChildOfClass("UIListLayout") :: UIListLayout
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	local body = Create("Frame", {
		Name = "Body",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -36, 1, -84),
		Position = UDim2.fromOffset(18, 72),
		Parent = panel,
	})
	return {
		root = root,
		scrim = scrim,
		panel = panel,
		body = body,
		header = header,
		right = right,
		title = title,
		subtitle = subtitle,
		close = close,
	}
end

-- A section heading: gold small caps on the left, an optional note on the right, a hairline under.
function Widgets.sectionHeader(parent: Instance, text: string, note: string?, order: number?): Frame
	local frame = Create("Frame", {
		Name = "Section",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 22),
		LayoutOrder = order or 0,
		Parent = parent,
	})
	Widgets.label({
		Name = "Heading",
		Text = string.upper(text),
		Font = Theme.Black,
		TextSize = 12,
		TextColor3 = C.Gold,
		Size = UDim2.new(1, 0, 0, 18),
		Parent = frame,
	})
	if note then
		Widgets.label({
			Name = "Note",
			Text = note,
			TextSize = 11,
			TextColor3 = C.Dim,
			TextXAlignment = Enum.TextXAlignment.Right,
			Size = UDim2.new(1, 0, 0, 18),
			Parent = frame,
		})
	end
	local line = Create("Frame", {
		BackgroundColor3 = C.Gold,
		BackgroundTransparency = 0.7,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 1),
		Position = UDim2.fromOffset(0, 19),
		Parent = frame,
	})
	Create("UIGradient", {
		Transparency = NumberSequence.new(0, 1),
		Parent = line,
	})
	return frame
end

-- A small rounded stat pill, e.g. "💧 800 +250/s".
function Widgets.chip(parent: Instance, text: string, color: Color3?, order: number?): TextLabel
	local chip = Widgets.label({
		Name = "Chip",
		Text = text,
		Font = Theme.Bold,
		TextSize = 11,
		TextColor3 = color or C.Text,
		TextXAlignment = Enum.TextXAlignment.Center,
		BackgroundColor3 = C.Ink,
		BackgroundTransparency = 0.45,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 18),
		LayoutOrder = order or 0,
		Parent = parent,
	})
	Create.corner(9).Parent = chip
	Create.padding(7, 0).Parent = chip
	return chip
end

export type TabsHandle = { buttons: { [string]: TextButton }, set: (id: string) -> () }

-- A row of tab buttons named "Tab_<id>"; the selected one is lit in the accent colour.
function Widgets.tabs(parent: Instance, defs: { { any } }, width: number, onSelect: (id: string) -> ()): TabsHandle
	local row = Create("Frame", {
		Name = "Tabs",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 34),
		Parent = parent,
	}, { Create.list(Enum.FillDirection.Horizontal, 6) })
	local handle: TabsHandle = { buttons = {}, set = function(_id: string) end }
	for i, def in defs do
		local id, label = def[1], def[2]
		local b = Widgets.button(label, {
			size = UDim2.fromOffset(width, 32),
			color = C.Panel2,
			textSize = 14,
			layoutOrder = i,
			onClick = function()
				onSelect(id)
			end,
			parent = row,
		})
		b.Name = "Tab_" .. id
		handle.buttons[id] = b
	end
	handle.set = function(current: string)
		for id, b in handle.buttons do
			local on = id == current
			b.BackgroundColor3 = if on then C.Accent else C.Panel2
			b.TextColor3 = if on then Color3.new(1, 1, 1) else C.Dim
		end
	end
	return handle
end

export type CardOptions = {
	name: string?,
	width: number?,
	icon: string?,
	iconColor: Color3?,
	wandColor: Color3?,
	gemColor: Color3?,
	rarity: string?, -- border, glow and the strip at the bottom
	caption: string?,
	captionColor: Color3?,
	count: number?,
	badge: string?, -- top-left marker (⚙️ trigger, 🐾 summoned, a hotkey...)
	empty: boolean?,
	selected: boolean?,
	highlight: boolean?,
	layoutOrder: number?,
	onClick: (() -> ())?,
	onRightClick: (() -> ())?,
	info: (() -> ItemInfo.Info?)?,
	parent: Instance?,
}

-- An item card: the icon in a tinted well with its name underneath, a rarity-coloured border
-- and strip, and an optional count. Easier to read than a bare icon tile.
function Widgets.card(o: CardOptions): TextButton
	local w = o.width or 78
	local h = w + 24
	local rarityColor = if o.rarity then Theme.rarity(o.rarity) else C.Stroke
	local tint = o.iconColor or C.Panel3
	local card = Create("TextButton", {
		Name = o.name or "Card",
		Text = "",
		AutoButtonColor = false,
		Size = UDim2.fromOffset(w, h),
		BackgroundColor3 = if o.empty then C.Panel else C.Panel2,
		LayoutOrder = o.layoutOrder or 0,
	}, {
		Create.corner(10),
		Create.stroke(
			if o.selected then C.Gold elseif o.highlight then Color3.new(1, 1, 1) else rarityColor,
			if o.selected then 3 else 1.5,
			if o.empty then 0.7 elseif o.selected then 0 else 0.25
		),
	})
	shade(card, 0.8)
	local well = Create("Frame", {
		Name = "Well",
		BackgroundColor3 = if o.empty then C.Ink else Theme.darken(tint, 0.55),
		BorderSizePixel = 0,
		Size = UDim2.new(1, -10, 0, w - 18),
		Position = UDim2.fromOffset(5, 5),
		Parent = card,
	}, { Create.corner(8) })
	Create("UIGradient", {
		Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(150, 150, 160)),
		Rotation = 90,
		Parent = well,
	})
	if o.wandColor then
		Create("Frame", {
			Size = UDim2.new(0.11, 0, 0.72, 0),
			Position = UDim2.fromScale(0.5, 0.55),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Rotation = 40,
			BackgroundColor3 = o.wandColor,
			BorderSizePixel = 0,
			Parent = well,
		}, { Create.corner(4) })
		Create("Frame", {
			Size = UDim2.fromScale(0.24, 0.24),
			Position = UDim2.fromScale(0.68, 0.26),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = o.gemColor or C.Accent,
			BorderSizePixel = 0,
			Parent = well,
		}, { Create.corner(100), Create.stroke(Color3.new(1, 1, 1), 1, 0.5) })
	elseif o.icon then
		Create("TextLabel", {
			Name = "Icon",
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(0.66, 0.66),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Text = o.icon,
			TextScaled = true,
			Font = Theme.Bold,
			TextColor3 = Color3.new(1, 1, 1),
			Parent = well,
		})
	end
	if o.rarity and not o.empty then
		Create("Frame", {
			Name = "RarityStrip",
			BackgroundColor3 = rarityColor,
			BorderSizePixel = 0,
			Size = UDim2.new(1, -16, 0, 2),
			Position = UDim2.new(0, 8, 1, -3),
			Parent = card,
		}, { Create.corner(1) })
	end
	if o.caption then
		Create("TextLabel", {
			Name = "Caption",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -6, 0, 26),
			Position = UDim2.new(0, 3, 1, -30),
			Text = o.caption,
			TextWrapped = true,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Font = Theme.Bold,
			TextSize = 10,
			TextColor3 = o.captionColor or (if o.empty then C.Dim else C.Text),
			Parent = card,
		})
	end
	if o.count and o.count > 1 then
		local badge = Create("TextLabel", {
			Name = "Count",
			BackgroundColor3 = C.Ink,
			BackgroundTransparency = 0.25,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 16),
			Position = UDim2.new(1, -4, 0, 4),
			AnchorPoint = Vector2.new(1, 0),
			Text = "x" .. o.count,
			Font = Theme.Black,
			TextSize = 11,
			TextColor3 = Color3.new(1, 1, 1),
			ZIndex = 3,
			Parent = card,
		}, { Create.corner(8) })
		Create.padding(5, 0).Parent = badge
	end
	if o.badge then
		Create("TextLabel", {
			Name = "Badge",
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(20, 20),
			Position = UDim2.fromOffset(4, 3),
			Text = o.badge,
			TextScaled = true,
			Font = Theme.Black,
			TextColor3 = C.Gold,
			TextStrokeTransparency = 0.4,
			ZIndex = 3,
			Parent = card,
		})
	end
	if o.onClick then
		card.Activated:Connect(o.onClick)
	end
	if o.onRightClick then
		card.MouseButton2Click:Connect(o.onRightClick)
	end
	if o.info then
		Widgets.attachTooltip(card, o.info)
	end
	if o.parent then
		card.Parent = o.parent
	end
	return card
end

-- Grid of cards: a frame with a UIGridLayout sized for cards `width` wide.
function Widgets.cardGrid(parent: Instance, width: number, order: number?, name: string?): Frame
	return Create("Frame", {
		Name = name or "Cards",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = order or 0,
		Parent = parent,
	}, {
		Create("UIGridLayout", {
			CellSize = UDim2.fromOffset(width, width + 24),
			CellPadding = UDim2.fromOffset(8, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
end

export type RowOptions = {
	name: string?,
	icon: string?,
	iconColor: Color3?,
	rarity: string?,
	title: string,
	subtitle: string?,
	selected: boolean?,
	layoutOrder: number?,
	height: number?,
	onClick: (() -> ())?,
	info: (() -> ItemInfo.Info?)?,
	parent: Instance?,
}

-- A one-line item: icon well, name in its rarity colour, a dim second line. For pick lists.
function Widgets.itemRow(o: RowOptions): TextButton
	local h = o.height or 46
	local rarityColor = if o.rarity then Theme.rarity(o.rarity) else C.Stroke
	local row = Create("TextButton", {
		Name = o.name or "Row",
		Text = "",
		AutoButtonColor = false,
		Size = UDim2.new(1, -4, 0, h),
		BackgroundColor3 = if o.selected then C.Panel3 else C.Panel2,
		LayoutOrder = o.layoutOrder or 0,
	}, {
		Create.corner(8),
		Create.stroke(
			if o.selected then C.Gold else rarityColor,
			if o.selected then 2 else 1,
			if o.selected then 0 else 0.55
		),
	})
	shade(row, 0.82)
	local well = Create("Frame", {
		BackgroundColor3 = Theme.darken(o.iconColor or C.Panel3, 0.5),
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(h - 10, h - 10),
		Position = UDim2.fromOffset(5, 5),
		Parent = row,
	}, { Create.corner(6) })
	if o.icon then
		Create("TextLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(0.72, 0.72),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Text = o.icon,
			TextScaled = true,
			Font = Theme.Bold,
			TextColor3 = Color3.new(1, 1, 1),
			Parent = well,
		})
	end
	Widgets.label({
		Text = o.title,
		Font = Theme.Bold,
		TextSize = 12,
		TextColor3 = Theme.lighten(rarityColor, 0.2),
		TextTruncate = Enum.TextTruncate.AtEnd,
		Size = UDim2.new(1, -h - 6, 0, 16),
		Position = UDim2.fromOffset(h + 2, if o.subtitle then 6 else (h - 16) / 2),
		Parent = row,
	})
	if o.subtitle then
		Widgets.label({
			Text = o.subtitle,
			TextSize = 11,
			TextColor3 = C.Dim,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Size = UDim2.new(1, -h - 6, 0, 14),
			Position = UDim2.fromOffset(h + 2, 24),
			Parent = row,
		})
	end
	if o.onClick then
		row.Activated:Connect(o.onClick)
	end
	if o.info then
		Widgets.attachTooltip(row, o.info)
	end
	if o.parent then
		row.Parent = o.parent
	end
	return row
end

return Widgets
