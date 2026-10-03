--[[
	Client + server integration test (run from the repo root with Lune):

		lune run tools/sim/client

	Boots the REAL client (src/client/init.client.lua: HUD, Spellbook, chests, lobby, storm,
	effects) and the REAL server inventory / casting / chest / class services in one process,
	connected through fake remotes (tools/sim/mock.luau). It then plays through a match by
	"clicking" UI buttons: forging a spell in the Spellforge, slotting it into a wand, looting a
	chest, casting spells with the mouse, picking a class and watching the storm close.
	Any runtime error or warning on either side fails the run.
]]

local process = require("@lune/process")
local roblox = require("@lune/roblox")
local Mock = require("./mock")

local Vector3 = roblox.Vector3
local Vector2 = roblox.Vector2
local CFrame = Mock.CFrame
local Instance = Mock.Instance
local Enum = roblox.Enum

local failures = 0
local function fail(msg: string)
	failures += 1
	print("FAIL  " .. msg)
end
local function check(cond: any, msg: string)
	if not cond then
		fail(msg)
	end
end

---------------------------------------------------------------------------
-- Players
---------------------------------------------------------------------------

local player = Instance.new("Player")
player.Name = "Tester"
player.DisplayName = "Tester"
player.UserId = 1
player.MembershipType = Enum.MembershipType.None
local playerGui = Instance.new("PlayerGui", player)
playerGui.Name = "PlayerGui"
Mock.localPlayer = player

local PlayersService = {
	LocalPlayer = player,
	PlayerAdded = Mock.signal(),
	PlayerRemoving = Mock.signal(),
	PlayerMembershipChanged = Mock.signal(),
	GetPlayers = function()
		return { player }
	end,
}

---------------------------------------------------------------------------
-- Server realm
---------------------------------------------------------------------------

local server = Mock.realm({
	RunService = Mock.runService(true),
	Players = PlayersService,
	TweenService = Mock.TweenService,
	MarketplaceService = {
		PromptGamePassPurchaseFinished = Mock.signal(),
		UserOwnsGamePassAsync = function()
			return false
		end,
		PromptGamePassPurchase = function() end,
		PromptPremiumPurchase = function() end,
	},
}, true)

local Combatants = server.load("Server/Services/Combatants")
local GameState = server.load("Server/Services/GameState")
local FX = server.load("Server/Services/FX")
local InventoryService = server.load("Server/Services/InventoryService")
local ChestService = server.load("Server/Services/ChestService")
local CastingService = server.load("Server/Services/CastingService")
local Structures = server.load("Server/Map/Structures")
for _, name in
	{
		"StatusService",
		"DamageService",
		"ProjectileService",
		"ZoneService",
		"SpellExecutor",
		"CastingService",
		"InventoryService",
		"ChestService",
		"ClassService",
	}
do
	local module = server.load("Server/Services/" .. name)
	if module.init then
		module.init()
	end
end

-- the local player's character
local character = Instance.new("Model", Mock.workspace)
character.Name = "Tester"
local root = Instance.new("Part", character)
root.Name = "HumanoidRootPart"
root.CFrame = CFrame.new(0, 3, 0)
local head = Instance.new("Part", character)
head.Name = "Head"
head.CFrame = CFrame.new(0, 4.5, 0)
local humanoid = Instance.new("Humanoid", character)
player.Character = character

local me = Combatants.create(player.DisplayName, player)
Combatants.setModel(me, character)
me.inMatch = true
me.alive = true
player:SetAttribute("Class", "Apprentice")
player:SetAttribute("PremiumAccess", true)
player:SetAttribute("InMatch", true)
player:SetAttribute("Alive", true)

-- a dummy to shoot at
local dummyModel = Instance.new("Model", Mock.workspace)
dummyModel.Name = "Dummy"
local dummyRoot = Instance.new("Part", dummyModel)
dummyRoot.Name = "HumanoidRootPart"
dummyRoot.CFrame = CFrame.new(0, 3, -25)
Instance.new("Humanoid", dummyModel)
local dummy = Combatants.create("Dummy", nil)
Combatants.setModel(dummy, dummyModel)
dummy.inMatch = true
dummy.alive = true

GameState.setPhase("Battle", Mock.clock.t + 100)
GameState.setPublic("MatchStartedAt", Mock.clock.t)
GameState.setPublic("AliveCount", 2)

---------------------------------------------------------------------------
-- Client realm
---------------------------------------------------------------------------

local soundService = Instance.new("SoundService")
rawset(soundService, "PlayLocalSound", function() end)
local UIS = {
	TouchEnabled = false,
	MouseEnabled = true,
	KeyboardEnabled = true,
	MouseIconEnabled = true,
	InputBegan = Mock.signal(),
	InputEnded = Mock.signal(),
	GetMouseLocation = function()
		return Vector2.new(640, 360)
	end,
	GetLastInputType = function()
		return Enum.UserInputType.MouseMovement
	end,
}
local client = Mock.realm({
	RunService = Mock.runService(false),
	Players = PlayersService,
	TweenService = Mock.TweenService,
	UserInputService = UIS,
	ContextActionService = {
		BindAction = function() end,
		SetTitle = function() end,
		SetPosition = function() end,
		UnbindAction = function() end,
	},
	StarterGui = { SetCoreGuiEnabled = function() end },
	SoundService = soundService,
	Debris = { AddItem = function() end },
	Lighting = Instance.new("Lighting"),
	GuiService = {
		GetGuiInset = function()
			return Vector2.zero, Vector2.zero
		end,
	},
}, false)

client.load("Client") -- runs src/client/init.client.lua
local State = client.load("Client/Controllers/State")
local InventoryController = client.load("Client/Controllers/InventoryController")

---------------------------------------------------------------------------
-- UI helpers
---------------------------------------------------------------------------

local function gui(name: string)
	return playerGui:FindFirstChild(name)
end

local function textOf(inst): string?
	local ok, text = pcall(function()
		return inst.Text
	end)
	return if ok then text else nil
end

-- A clickable thing whose own text, or a child label's text, matches.
local function findButton(container, text: string)
	for _, inst in container:GetDescendants() do
		if inst.ClassName == "TextButton" then
			if textOf(inst) == text then
				return inst
			end
			for _, child in inst:GetChildren() do
				if child.ClassName == "TextLabel" and textOf(child) == text then
					return inst
				end
			end
		end
	end
	return nil
end

local function click(container, text: string)
	local button = findButton(container, text)
	if not button then
		fail("no button '" .. text .. "' in " .. tostring(container))
		return false
	end
	button.Activated:Fire()
	Mock.step(0.05, true)
	return true
end

local function clickNamed(container, name: string)
	local target = container:FindFirstChild(name, true)
	if not target then
		fail("no element named '" .. name .. "'")
		return false
	end
	target.Activated:Fire()
	Mock.step(0.05, true)
	return true
end

local reported = 0
local function checkWarnings(label: string)
	for i = reported + 1, #Mock.warnings do
		fail(label .. ": " .. Mock.warnings[i])
	end
	reported = #Mock.warnings
end

---------------------------------------------------------------------------
-- Scenario
---------------------------------------------------------------------------

-- 1. Spawn with a class kit: HUD should show the wand.
InventoryService.giveKit(me, "Pyromancer")
Mock.step(0.5, true)
checkWarnings("boot")
check(State.inventory ~= nil, "client should receive the inventory")
check(
	State.inventory and State.inventory.wands[1] and State.inventory.wands[1].name == "Emberheart Rod",
	"kit wand on client"
)

-- 2. Spellforge: Bolt + Fire + Explosive -> "Bursting Ember Bolt"
me.inventory.parts.Bolt = 1
InventoryService.sync(me)
Mock.step(0.1, true)
InventoryController.open()
Mock.step(0.1, true)
local book = gui("Spellbook")
check(book and book.Enabled, "spellbook should open")
checkWarnings("open spellbook")
clickNamed(book, "Part_Bolt")
clickNamed(book, "Part_Fire")
clickNamed(book, "Part_Explosive")
check(book:FindFirstChild("Forge_FORM", true) ~= nil, "spellforge slots should exist")
click(book, "Forge Spell")
checkWarnings("forge")
local forged = nil
for _, spell in me.inventory.spells do
	if spell.name == "Bursting Ember Bolt" then
		forged = spell
	end
end
check(forged ~= nil, "the forged spell should be in the server-side bag")
check(me.inventory.parts.Bolt == nil and me.inventory.parts.Explosive == nil, "forging should consume the parts")

-- 3. Slot it: the newly forged spell is auto-selected, so clicking empty slot 3 places it.
clickNamed(book, "Slot_1_3")
checkWarnings("slot spell")
check(
	forged and me.inventory.wands[1].slots[3] and me.inventory.wands[1].slots[3].uid == forged.uid,
	"spell should be slotted into wand slot 3"
)

-- 4. Dismantle a premade spell from the bag after unslotting it.
local firstSpell = me.inventory.wands[1].slots[1]
InventoryService.handle(player, "Unslot", { wand = 1, slot = 1 })
Mock.step(0.1, true)
InventoryController.open()
Mock.step(0.1, true)
if firstSpell then
	clickNamed(book, "Spell_" .. firstSpell.uid)
	click(book, "Dismantle")
end
checkWarnings("dismantle")
check(firstSpell and (me.inventory.parts.Bolt or 0) >= 1, "dismantling Firebolt should give back a Bolt part")

-- the other detail actions
click(book, "✕")
check(not book.Enabled, "spellbook should close")

-- 5. Loot a chest through the chest window.
ChestService.spawnArenaChests({ { cframe = CFrame.new(3, 1, 3), tier = "Cornucopia" } })
local chestModel = nil
for _, inst in Mock.workspace:GetDescendants() do
	if inst.ClassName == "Model" and inst:GetAttribute("ChestId") then
		chestModel = inst
	end
end
check(chestModel ~= nil, "chest model should exist")
if chestModel then
	local prompt = chestModel.PrimaryPart:FindFirstChildOfClass("ProximityPrompt")
	prompt.Triggered:Fire(player)
	Mock.step(0.1, true)
	local chestGui = gui("Chest")
	check(chestGui and chestGui.Enabled, "chest window should open")
	local chest = ChestService.get(chestModel:GetAttribute("ChestId"))
	local before = #chest.entries
	click(chestGui, "Take All  [F]")
	checkWarnings("loot chest")
	check(#chest.entries < before, "taking all should empty (most of) the chest")
	local closeButton = findButton(chestGui, "✕")
	if closeButton then
		closeButton.Activated:Fire()
	end
	Mock.step(0.1, true)
end

-- 6. Equip and cast with the mouse; effects should be drawn and the dummy hurt.
InventoryService.handle(player, "Equip", { index = 1 })
UIS.InputBegan:Fire({ UserInputType = Enum.UserInputType.MouseButton1, KeyCode = Enum.KeyCode.Unknown }, false)
Mock.step(2, true)
UIS.InputEnded:Fire({ UserInputType = Enum.UserInputType.MouseButton1, KeyCode = Enum.KeyCode.Unknown })
Mock.step(1, true)
checkWarnings("casting")
check((Mock.remoteCounts["CastRequest"] or 0) > 0, "holding the mouse should send cast requests")
check((Mock.remoteCounts["FX:Cast"] or 0) > 0, "the server should accept casts")
check(dummy.humanoid.Health < 100, "the dummy should take damage")
check(State.wand ~= nil, "the client should track wand mana")
local fxFolder = Mock.workspace:FindFirstChild("ClientFX")
check(fxFolder ~= nil, "client effects folder")

-- hotkeys: wand switching, potions, inventory toggle
UIS.InputBegan:Fire({ UserInputType = Enum.UserInputType.Keyboard, KeyCode = Enum.KeyCode.Two }, false)
UIS.InputBegan:Fire({ UserInputType = Enum.UserInputType.Keyboard, KeyCode = Enum.KeyCode.Z }, false)
UIS.InputBegan:Fire({ UserInputType = Enum.UserInputType.Keyboard, KeyCode = Enum.KeyCode.Tab }, false)
Mock.step(0.2, true)
UIS.InputBegan:Fire({ UserInputType = Enum.UserInputType.Keyboard, KeyCode = Enum.KeyCode.Tab }, false)
Mock.step(0.2, true)
checkWarnings("hotkeys")

-- 7. Announcements, damage numbers and the storm.
FX.announce("Banner", { title = "Chests refilled!", subtitle = "Fresh loot" })
FX.announce("Kill", { victim = "Dummy", killer = "Tester", spell = "Fireball", remaining = 1 })
FX.announce("Kill", { victim = "Someone", spell = "the Mana Storm" })
FX.announce("Winner", { name = "Tester", isBot = false, kills = 3 })
FX.all("Cannon")
GameState.setPublic("StormCenter", Vector3.new(0, 13, 0))
GameState.setPublic("StormRadius", 60)
GameState.setPublic("StormActive", true)
Mock.step(1, true)
GameState.setPublic("StormRadius", 1)
Mock.step(1, true)
checkWarnings("announcements and storm")
local storm = Mock.workspace:FindFirstChild("ClientStorm")
check(storm and #storm:GetChildren() > 0, "storm wall segments should exist")

-- 8. Back in the lobby: pick a class from the class picker.
player:SetAttribute("Alive", false)
player:SetAttribute("InMatch", false)
GameState.setPhase("Intermission", Mock.clock.t + 20)
Mock.step(2.5, true)
local lobby = gui("Lobby")
click(lobby, "📖  Class: Apprentice")
click(lobby, "Stormcaller")
checkWarnings("class picker")
check(player:GetAttribute("Class") == "Stormcaller", "picking a class should update the server")

-- 9. Spectating during a match.
GameState.setPhase("Battle", 0)
Mock.step(0.2, true)
click(lobby, "👁  Spectate")
Mock.step(1.5, true)
checkWarnings("spectate")

if failures > 0 then
	print(failures .. " failure(s)")
	process.exit(1)
end
print("client integration test passed")
