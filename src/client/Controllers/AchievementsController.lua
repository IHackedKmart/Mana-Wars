-- The Achievements window: every achievement with its progress bar and coin reward, plus the daily
-- reward streak. Opened from the 🏆 button in the Plaza / library. The server sends the numbers
-- (AchievementService.snapshot); unlocking and paying out happen on the server.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Achievements = require(ReplicatedStorage.Shared.Achievements)
local UI = script.Parent.Parent.UI
local Create = require(UI.Create)
local Theme = require(UI.Theme)
local Widgets = require(UI.Widgets)
local State = require(script.Parent.State)

local AchievementsController = {}

local C = Theme.Colors

local gui: ScreenGui
local subtitle: TextLabel
local dailyTitle: TextLabel
local dailyText: TextLabel
local list: ScrollingFrame
local isOpen = false
local receivedAt = os.clock()

local function duration(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	local h, m = seconds // 3600, (seconds % 3600) // 60
	if h > 0 then
		return string.format("%dh %dm", h, m)
	end
	return string.format("%dm", math.max(1, m))
end

local function updateDaily()
	local snapshot = State.achievements
	if not snapshot then
		return
	end
	local d = snapshot.daily
	local left = (tonumber(d.nextIn) or 0) - (os.clock() - receivedAt)
	dailyTitle.Text = string.format("Daily reward: +%d 💰 for every day you play", tonumber(d.coins) or 0)
	local streak =
		string.format("Streak: %d day%s (best %d)", d.streak or 0, if d.streak == 1 then "" else "s", d.best or 0)
	if d.claimedToday then
		dailyText.Text = streak .. "  ·  today's reward collected, the next one is ready in " .. duration(left)
	else
		dailyText.Text = streak .. "  ·  your reward for today is on its way"
	end
end

local function row(a: Achievements.Achievement, value: number, unlockedAt: number?, order: number)
	local done = unlockedAt ~= nil
	local frame = Create("Frame", {
		Name = "Achievement_" .. a.id,
		Size = UDim2.new(1, -8, 0, 64),
		BackgroundColor3 = if done then C.Panel3 else C.Panel2,
		LayoutOrder = order,
		Parent = list,
	}, {
		Create.corner(10),
		Create.stroke(if done then C.Gold else C.Stroke, if done then 1.5 else 1, if done then 0.1 else 0.5),
	})
	local tile = Create("Frame", {
		Size = UDim2.fromOffset(48, 48),
		Position = UDim2.fromOffset(8, 8),
		BackgroundColor3 = if done then C.GoldDeep else C.Ink,
		BackgroundTransparency = if done then 0.2 else 0,
		Parent = frame,
	}, { Create.corner(10) })
	Widgets.label({
		Size = UDim2.fromScale(1, 1),
		Text = a.icon,
		TextSize = 28,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTransparency = if done then 0 else 0.35,
		Parent = tile,
	})
	Widgets.label({
		Name = "Name",
		Size = UDim2.new(1, -330, 0, 22),
		Position = UDim2.fromOffset(68, 10),
		Text = a.name,
		Font = Theme.Bold,
		TextSize = 17,
		TextColor3 = if done then C.Gold else C.Text,
		Parent = frame,
	})
	Widgets.label({
		Name = "Description",
		Size = UDim2.new(1, -330, 0, 18),
		Position = UDim2.fromOffset(68, 34),
		Text = a.description,
		TextSize = 14,
		TextColor3 = C.Dim,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = frame,
	})
	-- progress (or a tick) and the reward
	if done then
		Widgets.label({
			Name = "Status",
			Size = UDim2.fromOffset(170, 22),
			Position = UDim2.new(1, -262, 0.5, -11),
			Text = "✅ Unlocked",
			Font = Theme.Bold,
			TextSize = 15,
			TextColor3 = C.Good,
			TextXAlignment = Enum.TextXAlignment.Center,
			Parent = frame,
		})
	else
		local bar = Widgets.bar(C.Accent, UDim2.fromOffset(170, 18), frame)
		bar.frame.Name = "Progress"
		bar.frame.Position = UDim2.new(1, -262, 0.5, -9)
		bar.set(math.clamp(value / a.goal, 0, 1))
		bar.label.Text = string.format("%d / %d", math.min(value, a.goal), a.goal)
	end
	local reward = Widgets.label({
		Name = "Reward",
		Size = UDim2.fromOffset(72, 28),
		Position = UDim2.new(1, -82, 0.5, -14),
		Text = "💰 " .. a.reward,
		Font = Theme.Black,
		TextSize = 15,
		TextColor3 = if done then C.Dim else C.Gold,
		TextXAlignment = Enum.TextXAlignment.Center,
		BackgroundColor3 = C.Ink,
		BackgroundTransparency = 0.2,
		Parent = frame,
	})
	Create.corner(14).Parent = reward
end

local function render()
	if not gui then
		return
	end
	Widgets.clear(list, true)
	local snapshot = State.achievements
	local stats = if snapshot then snapshot.stats else {}
	local unlocked = if snapshot then snapshot.unlocked else {}
	local count, earned = 0, 0
	for i, a in Achievements.List do
		local at = unlocked[a.id]
		if at then
			count += 1
			earned += a.reward
		end
		row(a, stats[a.stat] or 0, at, i)
	end
	subtitle.Text = string.format(
		"%d of %d unlocked  ·  💰 %d of %d earned",
		count,
		#Achievements.List,
		earned,
		Achievements.totalReward()
	)
	updateDaily()
end

function AchievementsController.open()
	isOpen = true
	gui.Enabled = true
	State.setMenu("achievements", true)
	render()
end

function AchievementsController.close()
	isOpen = false
	gui.Enabled = false
	State.setMenu("achievements", false)
end

function AchievementsController.toggle()
	if isOpen then
		AchievementsController.close()
	else
		AchievementsController.open()
	end
end

function AchievementsController.isOpen(): boolean
	return isOpen
end

function AchievementsController.init()
	gui = Widgets.screen("Achievements", 11)
	gui.Enabled = false
	local window = Widgets.window(gui, {
		title = "Achievements",
		icon = "🏆",
		subtitle = "",
		size = Vector2.new(820, 620),
		onClose = function()
			AchievementsController.close()
		end,
	})
	subtitle = window.subtitle
	local body = window.body

	-- the daily reward banner
	local banner = Create("Frame", {
		Name = "Daily",
		Size = UDim2.new(1, 0, 0, 58),
		BackgroundColor3 = C.Panel2,
		Parent = body,
	}, { Create.corner(10), Create.stroke(C.GoldDeep, 1.5, 0.2) })
	Widgets.label({
		Size = UDim2.fromOffset(52, 58),
		Position = UDim2.fromOffset(6, 0),
		Text = "📅",
		TextSize = 30,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = banner,
	})
	dailyTitle = Widgets.label({
		Name = "DailyTitle",
		Size = UDim2.new(1, -70, 0, 22),
		Position = UDim2.fromOffset(62, 8),
		Font = Theme.Black,
		TextSize = 16,
		TextColor3 = C.Gold,
		Parent = banner,
	})
	dailyText = Widgets.label({
		Name = "DailyText",
		Size = UDim2.new(1, -70, 0, 18),
		Position = UDim2.fromOffset(62, 32),
		TextSize = 14,
		TextColor3 = C.Dim,
		Parent = banner,
	})

	list = Create("ScrollingFrame", {
		Name = "List",
		Size = UDim2.new(1, 0, 1, -68),
		Position = UDim2.fromOffset(0, 68),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = C.Stroke,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = body,
	}, { Create.list(Enum.FillDirection.Vertical, 6) })

	State.AchievementsChanged:Connect(function()
		receivedAt = os.clock()
		if isOpen then
			render()
		end
	end)
	-- keep the "next reward in" countdown ticking while the window is open
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if isOpen and acc >= 1 then
			acc = 0
			updateDaily()
		end
	end)
	render()
end

return AchievementsController
