-- A hands-on tutorial in the Spell Lab (the hub on your first visit): open the Spellbook, forge a spell from parts,
-- slot it into a wand, blast a training dummy, then build a spell with a trigger + payload.
-- Each step finishes itself when you do the thing, and the next UI element glows.
-- Shown automatically on a player's first visit; replay it from the Grimoire.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Remotes = require(Shared.Remotes)
local UI = script.Parent.Parent.UI
local Create = require(UI.Create)
local Theme = require(UI.Theme)
local Widgets = require(UI.Widgets)
local State = require(script.Parent.State)
local Sounds = require(script.Parent.Sounds)
local InventoryController = require(script.Parent.InventoryController)
local FXController = require(script.Parent.FXController)

local TutorialController = {}

local C = Theme.Colors
local player = Players.LocalPlayer

type Step = {
	title: string,
	text: string,
	highlight: string?, -- name of a GUI element to make glow
	manual: boolean?, -- needs a Next button instead of finishing itself
	enter: (() -> ())?,
	done: (() -> boolean)?,
}

local gui: ScreenGui
local panel: Frame
local titleLabel: TextLabel
local bodyLabel: TextLabel
local progressLabel: TextLabel
local nextButton: TextButton
local glow: Frame? = nil

local running = false
local stepIndex = 0
local lastForged: string? = nil
local hitDummy = false

local function inventorySpell(uid: string?)
	local inv = State.inventory
	if not inv or not uid then
		return nil
	end
	for _, spell in inv.spells do
		if spell.uid == uid then
			return spell
		end
	end
	for _, wand in inv.wands do
		if wand then
			for _, slot in wand.slots do
				if slot and slot.uid == uid then
					return slot
				end
			end
		end
	end
	return nil
end

local function slotted(uid: string?): boolean
	local inv = State.inventory
	if not inv or not uid then
		return false
	end
	for _, wand in inv.wands do
		if wand then
			for _, slot in wand.slots do
				if slot and slot.uid == uid then
					return true
				end
			end
		end
	end
	return false
end

local steps: { Step } = {
	{
		title = "Welcome to Arcanum Plaza!",
		text = "This is the hub. Outside a match you're in the <b>Spell Lab</b>: you carry copies of every spell part, so you can practise as long as you like. Let's craft your first spell!",
		manual = true,
	},
	{
		title = "Open your Spellbook",
		text = "Press <b>B</b> or click the glowing <b>📖 Spellbook</b> button.",
		highlight = "SpellbookButton",
		done = function()
			return InventoryController.isOpen()
		end,
	},
	{
		title = "1. Pick a Form",
		text = "Every spell starts with a <b>Form</b>, its shape. Click the glowing <b>🔹 Bolt</b> part in your bag (middle column).",
		highlight = "Part_Bolt",
		done = function()
			return InventoryController.getDraft().form ~= nil
		end,
	},
	{
		title = "2. Add an Element",
		text = "Elements add an effect. Click <b>🔥 Fire</b> to make it set enemies ablaze.",
		highlight = "Part_Fire",
		done = function()
			return InventoryController.getDraft().element ~= nil
		end,
	},
	{
		title = "3. Add a Modifier",
		text = "Modifiers change how a spell behaves. Click <b>💥 Explosive</b>. You can add up to 4, even the same one twice!",
		highlight = "Part_Explosive",
		done = function()
			return #InventoryController.getDraft().mods > 0
		end,
	},
	{
		title = "4. Forge it!",
		text = "Check the preview on the right, then press <b>Forge Spell</b>. The parts are used up and your new spell appears in your bag.",
		highlight = "ForgeButton",
		enter = function()
			lastForged = nil
		end,
		done = function()
			return lastForged ~= nil
		end,
	},
	{
		title = "5. Put it in a wand",
		text = "Your new spell is selected. Click the glowing <b>empty slot</b> on your Spell Lab Staff to equip it. Wands cast their spells left to right.",
		highlight = "Slot_1_2",
		done = function()
			return slotted(lastForged)
		end,
	},
	{
		title = "6. Try it out!",
		text = "Close the Spellbook (<b>B</b>), head east through the gate to the <b>Practice Range</b>, and <b>hold Left Click</b> on a training dummy.",
		enter = function()
			hitDummy = false
		end,
		done = function()
			return hitDummy
		end,
	},
	{
		title = "7. Spells inside spells",
		text = "<b>Triggers</b> cast a whole second spell. In the Spellbook add <b>🔹 Bolt</b> + <b>🎇 On Hit</b>, then click any spell in your bag and press <b>Use as payload</b>. Forge it and see what happens!",
		highlight = "Part_OnHit",
		enter = function()
			lastForged = nil
		end,
		done = function()
			local spell = inventorySpell(lastForged)
			return spell ~= nil and spell.recipe.payload ~= nil
		end,
	},
	{
		title = "You're ready, mage!",
		text = "Open the <b>📜 Grimoire (H)</b> any time to read about every part and spell. Pick your class at the <b>Class Altar</b> in the gazebo. When you're ready, walk through the <b>portal</b> (or press <b>⚔ Join Game</b>) to queue for the next match. Good luck!",
		manual = true,
	},
}

local function clearGlow()
	if glow then
		glow:Destroy()
		glow = nil
	end
end

local function findTarget(name: string): GuiObject?
	local playerGui = player:FindFirstChild("PlayerGui")
	if not playerGui then
		return nil
	end
	local found = playerGui:FindFirstChild(name, true)
	if found and found:IsA("GuiObject") and found.Visible then
		return found
	end
	return nil
end

local function finish(markDone: boolean)
	running = false
	clearGlow()
	gui.Enabled = false
	if markDone then
		Remotes.event("TutorialDone"):FireServer()
	end
end

local function showStep(i: number)
	stepIndex = i
	clearGlow()
	local step = steps[i]
	if not step then
		finish(true)
		return
	end
	if step.enter then
		step.enter()
	end
	titleLabel.Text = step.title
	bodyLabel.Text = step.text
	progressLabel.Text = string.format("Step %d of %d", i, #steps)
	nextButton.Visible = step.manual == true
	nextButton.Text = if i == #steps then "Let's go!" else "Next"
	Sounds.play("Pickup")
end

local function update()
	if not running then
		return
	end
	-- only in the Spell Lab; hide (but remember the step) during a match
	local inLab = State.practice()
	gui.Enabled = inLab
	if not inLab then
		clearGlow()
		return
	end
	-- dock low on the left so the Spellbook stays usable
	panel.Position = if InventoryController.isOpen() then UDim2.new(0, 16, 1, -14) else UDim2.new(0, 16, 0.62, 0)
	panel.AnchorPoint = if InventoryController.isOpen() then Vector2.new(0, 1) else Vector2.new(0, 0.5)

	local step = steps[stepIndex]
	if not step then
		return
	end
	if step.done and step.done() then
		showStep(stepIndex + 1)
		return
	end
	-- make the next thing to click glow
	if step.highlight then
		if InventoryController.isOpen() then
			InventoryController.reveal(step.highlight) -- (switches the bag to the right tab)
		end
		local target = findTarget(step.highlight)
		if target and (not glow or glow.Parent ~= target) then
			clearGlow()
			local g = Create("Frame", {
				Name = "TutorialGlow",
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 10, 1, 10),
				Position = UDim2.fromOffset(-5, -5),
				ZIndex = 50,
				Parent = target,
			}, { Create.corner(10), Create.stroke(C.Gold, 4) })
			glow = g
		end
		if glow then
			local stroke = glow:FindFirstChildOfClass("UIStroke")
			if stroke then
				stroke.Transparency = 0.5 + 0.5 * math.sin(os.clock() * 6)
			end
		end
	else
		clearGlow()
	end
end

function TutorialController.start()
	running = true
	showStep(1)
	gui.Enabled = State.practice()
	if not State.practice() then
		State.toast("The tutorial starts when you're out of the match", C.Dim)
	end
end

function TutorialController.isRunning(): boolean
	return running
end

local function build()
	gui = Widgets.screen("Tutorial", 40)
	gui.Enabled = false
	local root = Widgets.scaledRoot(gui)
	panel = Widgets.panel({
		Size = UDim2.fromOffset(380, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Position = UDim2.new(0, 16, 0.62, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = Color3.fromRGB(30, 22, 48),
		Parent = root,
	})
	local stroke = panel:FindFirstChildOfClass("UIStroke") :: UIStroke
	stroke.Color = C.Gold
	stroke.Thickness = 2
	Create.padding(14, 12).Parent = panel
	Create.list(Enum.FillDirection.Vertical, 6).Parent = panel
	progressLabel = Widgets.label({
		Text = "",
		TextSize = 12,
		Font = Theme.Bold,
		TextColor3 = C.Gold,
		Size = UDim2.new(1, 0, 0, 14),
		LayoutOrder = 1,
		Parent = panel,
	})
	titleLabel = Widgets.label({
		Text = "",
		TextSize = 19,
		Font = Theme.Black,
		TextWrapped = true,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, 22),
		LayoutOrder = 2,
		Parent = panel,
	})
	bodyLabel = Widgets.label({
		Text = "",
		RichText = true,
		TextSize = 15,
		TextWrapped = true,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, 18),
		LayoutOrder = 3,
		Parent = panel,
	})
	local buttons = Create("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 32),
		LayoutOrder = 4,
		Parent = panel,
	}, { Create.list(Enum.FillDirection.Horizontal, 8) })
	nextButton = Widgets.button("Next", {
		size = UDim2.fromOffset(120, 32),
		color = C.Accent,
		layoutOrder = 1,
		onClick = function()
			showStep(stepIndex + 1)
		end,
		parent = buttons,
	})
	Widgets.button("Skip tutorial", {
		size = UDim2.fromOffset(130, 32),
		color = C.Panel3,
		textSize = 13,
		layoutOrder = 2,
		onClick = function()
			finish(true)
		end,
		parent = buttons,
	})
end

function TutorialController.init()
	build()
	InventoryController.Forged:Connect(function(uid)
		lastForged = uid
	end)
	FXController.Hit:Connect(function()
		hitDummy = true
	end)
	RunService.RenderStepped:Connect(update)

	-- First visit: start automatically once saved data has loaded.
	task.spawn(function()
		local waited = 0
		while not player:GetAttribute("StatsLoaded") and waited < 15 do
			task.wait(0.5)
			waited += 0.5
		end
		task.wait(2)
		if not player:GetAttribute("TutorialDone") and not running then
			TutorialController.start()
		end
	end)
end

return TutorialController
