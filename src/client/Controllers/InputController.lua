-- Casting and hotkeys.
--   PC:      hold Left Mouse to cast at the cursor, 1-4 wands, B spellbook, H grimoire, Z/X/C/V potions
--            (Tab is left alone: Roblox uses it for the player list)
--   Mobile:  on-screen Cast button (aims at screen centre), tap the hotbar to switch wands
--   Gamepad: R2 cast, L1/R1 switch wands, Y spellbook

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage.Shared
local Remotes = require(Shared.Remotes)
local Consumables = require(Shared.Consumables)
local Config = require(Shared.Config)
local State = require(script.Parent.State)

local InputController = {}

InputController.onToggleInventory = nil :: (() -> ())?
InputController.onToggleGrimoire = nil :: (() -> ())?

local player = Players.LocalPlayer
local castRemote = Remotes.event("CastRequest")
local equipRemote = Remotes.event("EquipWand")
local potionRemote = Remotes.event("UseConsumable")

local holding = false
local awaitingUntil = 0
local faceUntil = 0
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = true

local KEY_WANDS = {
	[Enum.KeyCode.One] = 1,
	[Enum.KeyCode.Two] = 2,
	[Enum.KeyCode.Three] = 3,
	[Enum.KeyCode.Four] = 4,
}

local KEY_POTIONS: { [Enum.KeyCode]: string } = {}
for _, c in Consumables.List do
	local key = (Enum.KeyCode :: any)[c.key]
	if key then
		KEY_POTIONS[key] = c.id
	end
end

local function usesCenterAim(): boolean
	return UserInputService.TouchEnabled and not UserInputService.MouseEnabled
		or UserInputService:GetLastInputType() == Enum.UserInputType.Gamepad1
end

function InputController.aimScreenPoint(): Vector2
	local camera = workspace.CurrentCamera
	if usesCenterAim() then
		return camera.ViewportSize / 2
	end
	return UserInputService:GetMouseLocation()
end

function InputController.aimPoint(): Vector3
	local camera = workspace.CurrentCamera
	local screen = InputController.aimScreenPoint()
	local ray = camera:ViewportPointToRay(screen.X, screen.Y)
	local ignore: { Instance } = {}
	if player.Character then
		table.insert(ignore, player.Character)
	end
	local fx = workspace:FindFirstChild("ClientFX")
	if fx then
		table.insert(ignore, fx)
	end
	rayParams.FilterDescendantsInstances = ignore
	local result = workspace:Raycast(ray.Origin, ray.Direction * 1500, rayParams)
	if result then
		return result.Position
	end
	return ray.Origin + ray.Direction * 1500
end

local function canCast(): boolean
	if not State.canAct() or State.anyMenuOpen() then
		return false
	end
	if State.practice() then
		return true
	end
	local phase = State.phase()
	return phase == "Grace" or phase == "Battle"
end

function InputController.equip(index: number)
	local inv = State.inventory
	if not inv or not inv.wands[index] or not State.canAct() then
		return
	end
	if inv.equipped ~= index then
		inv.equipped = index
		equipRemote:FireServer(index)
		State.InventoryChanged:Fire()
	end
end

function InputController.cycle(step: number)
	local inv = State.inventory
	if not inv then
		return
	end
	for i = 1, Config.Inventory.MaxWands do
		local index = (inv.equipped - 1 + step * i) % Config.Inventory.MaxWands + 1
		if inv.wands[index] then
			InputController.equip(index)
			return
		end
	end
end

function InputController.usePotion(id: string)
	if State.canAct() then
		potionRemote:FireServer(id)
	end
end

local function toggleInventory()
	if InputController.onToggleInventory then
		InputController.onToggleInventory()
	end
end

local function step()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local hum = character and character:FindFirstChildOfClass("Humanoid")

	if holding and canCast() then
		local w = State.wand
		local ready = w == nil or State.now() >= w.nextCastAt - 0.03
		if ready and os.clock() >= awaitingUntil then
			castRemote:FireServer(InputController.aimPoint())
			awaitingUntil = os.clock() + 0.15
		end
		faceUntil = os.clock() + 0.35
	end

	-- face where you are casting, like shift-lock, while the button is held
	if root and hum then
		if os.clock() < faceUntil and canCast() then
			hum.AutoRotate = false
			local aim = InputController.aimPoint()
			local flat = Vector3.new(aim.X - root.Position.X, 0, aim.Z - root.Position.Z)
			if flat.Magnitude > 0.5 then
				root.CFrame = CFrame.lookAt(root.Position, root.Position + flat)
			end
		elseif not hum.AutoRotate then
			hum.AutoRotate = true
		end
	end

	-- custom crosshair replaces the mouse cursor while fighting
	local fighting = State.canAct() and not State.anyMenuOpen()
	UserInputService.MouseIconEnabled = not fighting or usesCenterAim()
end

function InputController.init()
	State.WandChanged:Connect(function()
		awaitingUntil = 0
	end)

	UserInputService.InputBegan:Connect(function(input, processed)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.KeyCode == Enum.KeyCode.ButtonR2 then
			if not processed then
				holding = true
			end
			return
		end
		if processed then
			return
		end
		local wand = KEY_WANDS[input.KeyCode]
		if wand then
			InputController.equip(wand)
		elseif input.KeyCode == Enum.KeyCode.B or input.KeyCode == Enum.KeyCode.ButtonY then
			toggleInventory()
		elseif input.KeyCode == Enum.KeyCode.H then
			if InputController.onToggleGrimoire then
				InputController.onToggleGrimoire()
			end
		elseif input.KeyCode == Enum.KeyCode.ButtonR1 or input.KeyCode == Enum.KeyCode.Q then
			InputController.cycle(1)
		elseif input.KeyCode == Enum.KeyCode.ButtonL1 then
			InputController.cycle(-1)
		elseif KEY_POTIONS[input.KeyCode] then
			InputController.usePotion(KEY_POTIONS[input.KeyCode])
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.KeyCode == Enum.KeyCode.ButtonR2 then
			holding = false
		end
	end)

	if UserInputService.TouchEnabled then
		ContextActionService:BindAction("ManaWarsCast", function(_, inputState)
			holding = inputState == Enum.UserInputState.Begin or inputState == Enum.UserInputState.Change
			return Enum.ContextActionResult.Sink
		end, true)
		ContextActionService:SetTitle("ManaWarsCast", "Cast")
		ContextActionService:SetPosition("ManaWarsCast", UDim2.new(1, -150, 1, -190))
		ContextActionService:BindAction("ManaWarsBag", function(_, inputState)
			if inputState == Enum.UserInputState.Begin then
				toggleInventory()
			end
			return Enum.ContextActionResult.Sink
		end, true)
		ContextActionService:SetTitle("ManaWarsBag", "Bag")
		ContextActionService:SetPosition("ManaWarsBag", UDim2.new(1, -230, 1, -120))
	end

	Remotes.event("Knockback").OnClientEvent:Connect(function(velocity: Vector3)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local hum = character and character:FindFirstChildOfClass("Humanoid")
		if root and hum and typeof(velocity) == "Vector3" then
			if velocity.Y > 8 then
				hum:ChangeState(Enum.HumanoidStateType.Freefall)
			end
			root.AssemblyLinearVelocity += velocity
		end
	end)

	RunService.RenderStepped:Connect(step)
end

return InputController
