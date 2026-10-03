--[[
	Client + server integration test (run from the repo root with Lune):

		lune run tools/sim/client

	Boots the REAL client (src/client/init.client.lua: HUD, Spellbook, Grimoire, tutorial, chests,
	lobby, map vote, storm, effects) and the REAL server inventory / casting / chest / class / vote
	services in one process, connected through fake remotes (tools/sim/mock.luau). It then plays
	through a match by "clicking" UI buttons: forging a spell in the Spellforge, slotting it into a
	wand, looting a chest, casting spells with the mouse, voting for a map, picking a class, reading
	the Grimoire and finishing the Spell Lab tutorial on a training dummy, and joining / leaving the
	queue from the hub.
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

-- a fake Roblox store: remembers which game passes were prompted and which are owned
local ownedPasses: { [number]: boolean } = {}
local promptedPass: number? = nil
local Marketplace = {
	PromptGamePassPurchaseFinished = Mock.signal(),
	UserOwnsGamePassAsync = function(_, _userId, passId)
		return ownedPasses[passId] == true
	end,
	PromptGamePassPurchase = function(_, _player, passId)
		promptedPass = passId
	end,
	PromptPremiumPurchase = function() end,
}

-- an in-memory DataStore (profiles and the auction mailbox); no MemoryStore, so the auction
-- house runs its in-server fallback
local dataStores: { [string]: { [string]: any } } = {}
local DataStores = {
	GetDataStore = function(_, name)
		dataStores[name] = dataStores[name] or {}
		local data = dataStores[name]
		return {
			GetAsync = function(_, key)
				return data[key]
			end,
			UpdateAsync = function(_, key, fn)
				local result = fn(data[key])
				if result ~= nil then
					data[key] = result
				end
				return result
			end,
		}
	end,
}

local server = Mock.realm({
	RunService = Mock.runService(true),
	Players = PlayersService,
	TweenService = Mock.TweenService,
	Lighting = Instance.new("Lighting"),
	MarketplaceService = Marketplace,
	DataStoreService = DataStores,
}, true)

local Combatants = server.load("Server/Services/Combatants")
local GameState = server.load("Server/Services/GameState")
local FX = server.load("Server/Services/FX")
local InventoryService = server.load("Server/Services/InventoryService")
local ChestService = server.load("Server/Services/ChestService")
local CastingService = server.load("Server/Services/CastingService")
local VoteService = server.load("Server/Services/VoteService")
local QueueService = server.load("Server/Services/QueueService")
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
		"VoteService",
		"QueueService",
		"DataService",
		"WardrobeService",
		"AuctionService",
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
local PromptService = { PromptTriggered = Mock.signal() }
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
	ProximityPromptService = PromptService,
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
local GrimoireController = client.load("Client/Controllers/GrimoireController")
local TutorialController = client.load("Client/Controllers/TutorialController")

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

local function key(code)
	UIS.InputBegan:Fire({ UserInputType = Enum.UserInputType.Keyboard, KeyCode = code }, false)
	UIS.InputEnded:Fire({ UserInputType = Enum.UserInputType.Keyboard, KeyCode = code })
	Mock.step(0.1, true)
end

local function holdMouse(seconds: number)
	UIS.InputBegan:Fire({ UserInputType = Enum.UserInputType.MouseButton1, KeyCode = Enum.KeyCode.Unknown }, false)
	Mock.step(seconds, true)
	UIS.InputEnded:Fire({ UserInputType = Enum.UserInputType.MouseButton1, KeyCode = Enum.KeyCode.Unknown })
	Mock.step(0.5, true)
end

-- a lobby ProximityPrompt (lectern / class altar) being used
local function usePrompt(action: string)
	local prompt = Instance.new("ProximityPrompt")
	prompt:SetAttribute("LobbyAction", action)
	PromptService.PromptTriggered:Fire(prompt, player)
	Mock.step(0.1, true)
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
local bonus = InventoryService.giveKit(me, "Pyromancer")
check((me.inventory.parts[bonus] or 0) >= 1, "the kit should hand out its random bonus part")
Mock.step(0.5, true)
checkWarnings("boot")
check(State.inventory ~= nil, "client should receive the inventory")
check(
	State.inventory and State.inventory.wands[1] and State.inventory.wands[1].name == "Emberheart Rod",
	"kit wand on client"
)

-- 2. Spellforge: Bolt + Fire + Explosive -> "Bursting Ember Bolt"
-- (start from a known set of parts; the kit's bonus part is random)
table.clear(me.inventory.parts)
me.inventory.parts.Bolt = 1
me.inventory.parts.Fire = 2
me.inventory.parts.Explosive = 1
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
holdMouse(2)
checkWarnings("casting")
check((Mock.remoteCounts["CastRequest"] or 0) > 0, "holding the mouse should send cast requests")
check((Mock.remoteCounts["FX:Cast"] or 0) > 0, "the server should accept casts")
check(dummy.humanoid.Health < 100, "the dummy should take damage")
check(State.wand ~= nil, "the client should track wand mana")
local fxFolder = Mock.workspace:FindFirstChild("ClientFX")
check(fxFolder ~= nil, "client effects folder")

-- hotkeys: wand switching, potions, spellbook toggle. Tab belongs to Roblox's player list,
-- so it must NOT open the spellbook; B does.
key(Enum.KeyCode.Two)
key(Enum.KeyCode.Z)
key(Enum.KeyCode.Tab)
check(not InventoryController.isOpen(), "Tab should no longer open the spellbook")
key(Enum.KeyCode.B)
check(InventoryController.isOpen() and book.Enabled, "B should open the spellbook")
key(Enum.KeyCode.B)
check(not InventoryController.isOpen(), "B should close the spellbook again")
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

-- 8. Out of the match, in the hub: the vote is for queued players only. Join Game, vote, leave and
--    rejoin, then pick a class at the altar.
local function hudText(prefix: string): boolean
	for _, inst in gui("HUD"):GetDescendants() do
		if inst.ClassName == "TextLabel" and string.sub(textOf(inst) or "", 1, #prefix) == prefix then
			return true
		end
	end
	return false
end
player:SetAttribute("Alive", false)
player:SetAttribute("InMatch", false)
me.inMatch = false
me.alive = false
local ballot = VoteService.begin(Mock.Random.new(7), Mock.clock.t + 25, "Verdant")
GameState.setPhase("Voting", Mock.clock.t + 25)
Mock.step(0.5, true)
local lobby = gui("Lobby")
local votePanel = lobby:FindFirstChild("MapVote", true)
local joinButton = lobby:FindFirstChild("JoinButton", true)
local leaveButton = lobby:FindFirstChild("LeaveButton", true)
check(State.inHub(), "a player out of the match and not queued is in the hub")
check(joinButton and joinButton.Visible and not leaveButton.Visible, "the hub should show Join Game")
check(string.find(joinButton.Text, "JOIN GAME", 1, true) ~= nil, "join button text")
check(not votePanel.Visible, "players in the hub should not see the vote")
check(not VoteService.vote(player, ballot[1].id), "players in the hub can't vote")
check(hudText("Match starting in"), "the hub HUD should say a match is starting")
clickNamed(lobby, "JoinButton")
Mock.step(0.6, true)
check(me.queued and State.queued(), "Join Game should put the player in the queue")
check(not joinButton.Visible and leaveButton.Visible, "queued players should see Leave queue")
check(hudText("Map vote"), "queued players should see the vote timer")
check(votePanel and votePanel.Visible, "the map vote should be on screen")
check(#ballot == 3, "three maps on the ballot")
for _, def in ballot do
	check(def.id ~= "Verdant", "the map just played should not be on the ballot")
end
local pick = ballot[2]
clickNamed(lobby, "Vote_" .. pick.id)
check(VoteService.payload().counts[pick.id] == 1, "clicking a map card should cast a vote")
-- changing your mind moves the vote
clickNamed(lobby, "Vote_" .. ballot[1].id)
local counts = VoteService.payload().counts
check(counts[ballot[1].id] == 1 and counts[pick.id] == 0, "a second click should move the vote")
-- leaving the queue withdraws the vote; rejoin and vote again
clickNamed(lobby, "LeaveButton")
check(not me.queued and joinButton.Visible and not votePanel.Visible, "Leave queue should go back to the hub")
check(VoteService.payload().counts[ballot[1].id] == 0, "leaving the queue should withdraw the vote")
clickNamed(lobby, "JoinButton")
clickNamed(lobby, "Vote_" .. ballot[1].id)
check(VoteService.payload().counts[ballot[1].id] == 1, "voting again after rejoining")
check(#QueueService.waiting() == 1, "one player in the queue")
root.CFrame = CFrame.new(0, 3, 0) -- (joining moved the character to the library; put it back for the tests below)
local winner = VoteService.finish(Mock.Random.new(1))
check(winner.id == ballot[1].id, "the map with the most votes should win")
Mock.step(0.2, true)
check(not votePanel.Visible, "the vote panel should hide when voting closes")
checkWarnings("map vote")

-- The kit shop: tiers from free to $25, buy a kit with a game pass, then pick it.
local ServerConfig = server.load("Shared/Config")
local ClassService = server.load("Server/Services/ClassService")
ServerConfig.Kits.GamePassIds.Stormcaller = 5555
ServerConfig.Kits.StudioUnlocksAll = false -- the fake engine says it's Studio; test the real shop
ClassService.refresh(player)
Mock.step(0.1, true)
usePrompt("ClassPicker")
local kitList = lobby:FindFirstChild("KitList", true)
check(kitList ~= nil and kitList.Visible ~= false, "the altar should open the kit shop")
for _, tierName in { "Novice", "Copper", "Silver", "Gold", "Arcane", "Astral", "Archmage" } do
	check(lobby:FindFirstChild("Tier_" .. tierName, true) ~= nil, "the shop should list the " .. tierName .. " tier")
end
local function kitStatus(id: string): string
	local card = lobby:FindFirstChild("Kit_" .. id, true)
	local status = card and card:FindFirstChild("Status")
	return if status then textOf(status) or "" else ""
end
check(string.find(kitStatus("Stormcaller"), "R$240", 1, true) ~= nil, "unowned kits show their price")
check(string.find(kitStatus("Apprentice"), "SELECTED", 1, true) ~= nil, "the free kit starts selected")
-- not on sale (no game pass id yet)
clickNamed(lobby, "Kit_Archmage")
check(player:GetAttribute("Class") == "Apprentice", "an unbuyable kit can't be picked")
-- buy one: the store prompt opens, the purchase goes through, the kit is owned and picked
clickNamed(lobby, "Kit_Stormcaller")
check(promptedPass == 5555, "clicking an unowned kit should prompt its game pass")
check(player:GetAttribute("Class") == "Apprentice", "nothing changes until the purchase finishes")
ownedPasses[5555] = true
Marketplace.PromptGamePassPurchaseFinished:Fire(player, 5555, true)
Mock.step(0.2, true)
check(player:GetAttribute("Class") == "Stormcaller", "buying a kit should select it")
check(
	string.find(tostring(player:GetAttribute("OwnedKits")), "Stormcaller", 1, true) ~= nil,
	"owned kits are published"
)
check(string.find(kitStatus("Stormcaller"), "SELECTED", 1, true) ~= nil, "the shop should show the new kit as selected")
clickNamed(lobby, "Kit_Apprentice")
check(player:GetAttribute("Class") == "Apprentice", "switching back to the free kit")
clickNamed(lobby, "Kit_Stormcaller")
checkWarnings("kit shop")
check(player:GetAttribute("Class") == "Stormcaller", "an owned kit can be picked again")
-- ownership is remembered from the store on the next join
ClassService.refresh(player)
check(ClassService.owns(player, "Stormcaller") and not ClassService.owns(player, "Archmage"), "ownership check")
click(lobby, "⚡  Class: Stormcaller")

-- 9. Spectating during a match.
GameState.setPhase("Battle", 0)
Mock.step(0.2, true)
click(lobby, "👁  Spectate the match")
Mock.step(1.5, true)
checkWarnings("spectate")

-- 10. The Grimoire: H toggles it, a lectern opens it, every chapter renders.
GameState.setPhase("Voting", Mock.clock.t + 25)
Mock.step(0.5, true)
key(Enum.KeyCode.H)
local grimoire = gui("Grimoire")
check(grimoire and grimoire.Enabled and GrimoireController.isOpen(), "H should open the Grimoire")
for _, chapterId in
	{ "Welcome", "Crafting", "Wands", "Forms", "Elements", "Modifiers", "Triggers", "Library", "Classes", "Controls" }
do
	clickNamed(grimoire, chapterId)
	local page = grimoire:FindFirstChild("Page", true)
	check(page and #page:GetDescendants() > 5, "Grimoire chapter '" .. chapterId .. "' should have content")
	checkWarnings("grimoire " .. chapterId)
end
key(Enum.KeyCode.H)
check(not grimoire.Enabled, "H should close the Grimoire")
usePrompt("Grimoire")
check(grimoire.Enabled, "a lectern should open the Grimoire")
click(grimoire, "✕")
check(not grimoire.Enabled, "the ✕ should close the Grimoire")

-- 11. The Spell Lab tutorial, start to finish, on a training dummy.
me.practice = true
InventoryService.reset(me)
InventoryService.givePractice(me)
player:SetAttribute("Practice", true)
dummy.isDummy = true
dummy.humanoid.Health = dummy.humanoid.MaxHealth
dummyRoot.CFrame = CFrame.new(0, 3, -25)
Mock.step(0.5, true)
check(State.practice() and State.canAct(), "the lobby player should be in the Spell Lab")
check((State.inventory.parts.OnHit or 0) >= 1, "the Spell Lab should hand out every part")

-- start it from the Grimoire's Controls chapter, like a player would
key(Enum.KeyCode.H)
clickNamed(grimoire, "Controls")
click(grimoire, "▶  Replay the tutorial")
local tutorial = gui("Tutorial")
check(TutorialController.isRunning() and tutorial.Enabled, "the tutorial should start")
check(not grimoire.Enabled, "replaying the tutorial should close the Grimoire")

local function tutorialStep(): string
	for _, inst in tutorial:GetDescendants() do
		if inst.ClassName == "TextLabel" then
			local text = textOf(inst)
			if text and string.match(text, "^Step %d+ of %d+$") then
				return text
			end
		end
	end
	return "?"
end
local function expectStep(n: number, what: string)
	Mock.step(0.1, true)
	local text = tutorialStep()
	check(
		string.match(text, "^Step " .. n .. " of"),
		"tutorial should be on step " .. n .. " (" .. what .. "), got " .. text
	)
end
local function glowingOn(name: string): boolean
	local target = playerGui:FindFirstChild(name, true)
	return target ~= nil and target:FindFirstChild("TutorialGlow") ~= nil
end

expectStep(1, "welcome")
click(tutorial, "Next")
expectStep(2, "open the spellbook")
Mock.step(0.1, true)
check(glowingOn("SpellbookButton"), "the Spellbook button should glow")
key(Enum.KeyCode.B)
expectStep(3, "form")
check(glowingOn("Part_Bolt"), "the Bolt part should glow")
clickNamed(book, "Part_Bolt")
expectStep(4, "element")
clickNamed(book, "Part_Fire")
expectStep(5, "modifier")
clickNamed(book, "Part_Explosive")
expectStep(6, "forge")
check(glowingOn("ForgeButton"), "the Forge button should glow")
click(book, "Forge Spell")
expectStep(7, "slot it")
check(glowingOn("Slot_1_2"), "the empty wand slot should glow")
clickNamed(book, "Slot_1_2")
expectStep(8, "hit a dummy")
local tutorialSpell = me.inventory.wands[1].slots[2]
check(tutorialSpell and tutorialSpell.name == "Bursting Ember Bolt", "the forged spell should be in the staff")
key(Enum.KeyCode.B)
check(not InventoryController.isOpen(), "B should close the spellbook")
InventoryService.handle(player, "Equip", { index = 1 })
local dummyBefore = dummy.humanoid.Health
holdMouse(2)
check(dummy.humanoid.Health < dummyBefore, "practice spells should hurt the training dummy")
check(dummy.humanoid.Health >= 1, "training dummies never die")
expectStep(9, "trigger + payload")
key(Enum.KeyCode.B)
clickNamed(book, "Part_Bolt")
clickNamed(book, "Part_OnHit")
local showcase = nil
for _, spell in me.inventory.spells do
	if spell.name == "Fireball" then
		showcase = spell
	end
end
check(showcase ~= nil, "the Spell Lab bag should have showcase spells")
if showcase then
	clickNamed(book, "Spell_" .. showcase.uid)
	click(book, "Use as payload")
end
click(book, "Forge Spell")
checkWarnings("tutorial forge with payload")
expectStep(10, "done")
click(tutorial, "Let's go!")
check(not TutorialController.isRunning() and not tutorial.Enabled, "the tutorial should close at the end")
check((Mock.remoteCounts["TutorialDone"] or 0) >= 1, "finishing the tutorial should tell the server")

-- the restock button refills the Spell Lab
click(book, "♻ Restock Spell Lab")
check((me.inventory.parts.Explosive or 0) == 3, "restocking should refill the parts")
key(Enum.KeyCode.B)
checkWarnings("tutorial")

-- 12. A full queue is first come, first served: whoever just played goes to the back of the line.
do
	local extra = {}
	for i = 1, 3 do
		local p = Instance.new("Player")
		p.Name = "Queuer" .. i
		p.DisplayName = p.Name
		p.Character = Instance.new("Model", Mock.workspace)
		Combatants.create(p.Name, p)
		table.insert(extra, p)
	end
	local everyone = { extra[1], extra[2], extra[3] }
	local getPlayers = PlayersService.GetPlayers
	PlayersService.GetPlayers = function()
		return everyone
	end
	-- join in the order 2, 3, 1 (a few seconds apart)
	for _, i in { 2, 3, 1 } do
		QueueService.join(extra[i])
		Mock.step(1, true)
	end
	local function order(): string
		local names = {}
		for _, p in QueueService.waiting() do
			table.insert(names, p.Name)
		end
		return table.concat(names, ",")
	end
	check(order() == "Queuer2,Queuer3,Queuer1", "the queue should keep joining order, got " .. order())
	QueueService.backOfLine(Combatants.forPlayer(extra[2]))
	check(order() == "Queuer3,Queuer1,Queuer2", "a player who just got a match goes to the back, got " .. order())
	PlayersService.GetPlayers = getPlayers
	checkWarnings("queue order")
end

-- 13. The Tailor's Loom: the starter outfit, opening a coffer, unpicking and re-stitching a robe,
--     wearing it, and salvaging a part. Outfits are locked during a match.
local DataService = server.load("Server/Services/DataService")
local WardrobeService = server.load("Server/Services/WardrobeService")
local AuctionService = server.load("Server/Services/AuctionService")
local Cosmetics = server.load("Shared/Cosmetics")
local Remotes = server.load("Shared/Remotes")
local Rarity = server.load("Shared/Rarity")
local OutfitBuilder = server.load("Shared/OutfitBuilder")
do
	player:SetAttribute("InMatch", false)
	player:SetAttribute("Alive", false)
	player:SetAttribute("Queued", false)
	player:SetAttribute("Practice", false)
	local playersFolder = Instance.new("Folder")
	playersFolder.Name = "Players"
	player.Parent = playersFolder -- (profiles only load for players still in the game)
	DataService.load(player)
	Mock.step(0.2, true)
	local w = State.wardrobe
	check(w.coins == 60, "new players start with 60 Enchanted Coins, got " .. tostring(w.coins))
	check(#w.garments == 2 and w.equipped.Robe and w.equipped.Hat, "new players wear a starter robe and hat")
	check(player:GetAttribute("Coins") == 60, "the coin count should be on the player for the hub pill")

	usePrompt("Coffers")
	local loom = gui("Wardrobe")
	check(loom and loom.Enabled, "the Coffer stall should open the Tailor's Loom")
	check(State.menus.wardrobe == true, "the loom should count as an open menu")
	checkWarnings("open the loom")
	clickNamed(loom, "Open_1")
	check(State.wardrobe.coins == 10, "the Tattered Satchel costs 50, coins now " .. tostring(State.wardrobe.coins))
	check(#State.wardrobe.parts == 1, "the satchel holds one part")
	local got = State.wardrobe.parts[1]
	check(got and loom:FindFirstChild("Got_" .. got.uid, true) ~= nil, "the new part should be revealed")
	clickNamed(loom, "Open_1")
	check(#State.wardrobe.parts == 1 and State.wardrobe.coins == 10, "can't open a coffer without the coins")
	checkWarnings("coffers")

	-- unpick the starter robe, then stitch it back together at the Tailor
	WardrobeService.addCoins(player, 2000, "test")
	Mock.step(0.1, true)
	clickNamed(loom, "Tab_Wardrobe")
	local robeUid = State.wardrobe.equipped.Robe
	clickNamed(loom, "Garment_" .. robeUid)
	clickNamed(loom, "UnbindButton")
	check(State.wardrobe.equipped.Robe == nil, "unpicking the worn robe takes it off")
	check(#State.wardrobe.parts == 4, "unpicking returns the robe's 3 parts")
	checkWarnings("unpick")
	clickNamed(loom, "Tab_Tailor")
	clickNamed(loom, "Mode_Robe")
	for _, part in State.wardrobe.parts do
		if part.box == 0 then -- the starter pieces
			clickNamed(loom, "Pick_" .. part.uid)
		end
	end
	clickNamed(loom, "CraftButton")
	check(#State.wardrobe.garments == 2, "stitching should make a robe")
	local newRobe = nil
	for _, g in State.wardrobe.garments do
		if g.kind == "Robe" then
			newRobe = g
		end
	end
	check(newRobe ~= nil and newRobe.uid ~= robeUid, "the stitched robe is a new garment")
	checkWarnings("craft")
	if newRobe then
		clickNamed(loom, "Tab_Wardrobe")
		clickNamed(loom, "Garment_" .. newRobe.uid)
		clickNamed(loom, "WearButton")
		check(State.wardrobe.equipped.Robe == newRobe.uid, "Wear should equip the robe")
	end
	-- the outfit's enchantments reach combat stats
	check((me.gear.manaRegen or 0) > 0 and (me.gear.speed or 0) > 0, "worn enchantments should set the gear stats")
	local before = State.wardrobe.coins
	clickNamed(loom, "Part_" .. got.uid)
	clickNamed(loom, "SalvageButton")
	check(#State.wardrobe.parts == 0, "salvaging removes the part")
	check(State.wardrobe.coins == before + Cosmetics.SalvageValue[Rarity.rank(got.rarity)], "salvaging pays coins")
	checkWarnings("wear and salvage")

	-- outfits are locked once you're in a match (and the loom closes)
	player:SetAttribute("InMatch", true)
	Mock.step(1.5, true)
	check(not loom.Enabled, "the loom closes when a match starts")
	local okLocked = Remotes.func("WardrobeAction").OnServerInvoke(player, "Unequip", { kind = "Hat" })
	check(okLocked == false, "can't change outfits mid-match")
	player:SetAttribute("InMatch", false)
	Mock.step(0.1, true)
	checkWarnings("match lock")
end

-- Outfits on real-shaped bodies (R15 and R6): plain starter gear has no aura; a matched Mythic
-- robe and hat glow, give off particles and leave a trail.
do
	local function body(r15: boolean)
		local m = Instance.new("Model", Mock.workspace)
		m.Name = if r15 then "R15Body" else "R6Body"
		local hum = Instance.new("Humanoid", m)
		hum.HipHeight = 2
		local function limb(name: string, size, pos)
			local p = Instance.new("Part", m)
			p.Name = name
			p.Size = size
			p.CFrame = CFrame.new(pos.X, pos.Y, pos.Z)
		end
		limb("HumanoidRootPart", Vector3.new(2, 2, 1), Vector3.new(0, 3, 0))
		limb("Head", Vector3.new(1.2, 1.2, 1.2), Vector3.new(0, 5, 0))
		if r15 then
			limb("UpperTorso", Vector3.new(2, 1.6, 1), Vector3.new(0, 3.6, 0))
			limb("LowerTorso", Vector3.new(2, 0.4, 1), Vector3.new(0, 2.6, 0))
			limb("LeftLowerArm", Vector3.new(0.9, 1, 0.9), Vector3.new(-1.5, 2.8, 0))
			limb("RightLowerArm", Vector3.new(0.9, 1, 0.9), Vector3.new(1.5, 2.8, 0))
		else
			limb("Torso", Vector3.new(2, 2, 1), Vector3.new(0, 3, 0))
			limb("Left Arm", Vector3.new(1, 2, 1), Vector3.new(-1.5, 3, 0))
			limb("Right Arm", Vector3.new(1, 2, 1), Vector3.new(1.5, 3, 0))
		end
		return m
	end
	local function garment(kind: string, rarity: string, aura: string?)
		local parts = {}
		for _, slot in Cosmetics.Garments[kind].slots do
			local part = Cosmetics.rollPart(Mock.Random.new(3), 5, slot, rarity)
			part.aura = if slot == "Sigil" or slot == "Gem" then aura else nil
			parts[slot] = part
		end
		return Cosmetics.craft(kind, parts)
	end
	local function count(m, class: string): number
		local n = 0
		for _, d in m:GetDescendants() do
			if d:IsA(class) then
				n += 1
			end
		end
		return n
	end
	for _, r15 in { true, false } do
		local m = body(r15)
		local c: any = { name = m.Name, model = m, gear = {} }
		local label = if r15 then "R15" else "R6"
		WardrobeService.dressWith(c, garment("Robe", "Common", nil), garment("Hat", "Common", nil))
		local outfit = m:FindFirstChild("Outfit")
		check(outfit ~= nil and count(outfit, "BasePart") >= 6, label .. ": the robe and hat should be built")
		check(count(m, "ParticleEmitter") == 0 and count(m, "Trail") == 0, label .. ": plain gear has no aura")
		local aura = Cosmetics.Auras[#Cosmetics.Auras].id
		WardrobeService.dressWith(c, garment("Robe", "Mythic", aura), garment("Hat", "Mythic", aura))
		check(#m:GetChildren() > 0 and count(m, "ParticleEmitter") >= 2, label .. ": Mythic auras give off particles")
		check(count(m, "PointLight") >= 2, label .. ": Mythic auras glow")
		check(count(m, "Trail") == 1, label .. ": a matched aura on robe and hat leaves one trail")
		check((c.gear.health or 0) > 0 or next(c.gear) ~= nil, label .. ": Mythic gear has enchantments")
		WardrobeService.dressWith(c, nil, nil)
		check(
			m:FindFirstChild("Outfit") == nil and count(m, "ParticleEmitter") == 0 and count(m, "Trail") == 0,
			label .. ": undressing removes the outfit and its auras"
		)
		m:Destroy()
	end
	checkWarnings("outfits")
end

-- 14. The auction house: list a part from the Sell tab, see it under My listings, have another
--     player buy it, sell to an offline seller through the mailbox, and take back an expired one.
do
	local function givePart(target, rarity: string)
		local part = Cosmetics.rollPart(Mock.Random.new(7), 2, "Gem", rarity)
		WardrobeService.giveItem(target, "Part", part)
		Mock.step(0.1, true)
		return part
	end
	usePrompt("Auction")
	local house = gui("AuctionHouse")
	check(house and house.Enabled, "the pavilion should open the auction house")
	check(not gui("Wardrobe").Enabled, "only one of the two windows at a time")
	checkWarnings("open the auction house")
	local part = givePart(player, "Rare")
	clickNamed(house, "Tab_Sell")
	clickNamed(house, "Sell_" .. part.uid)
	local priceBox = house:FindFirstChild("PriceBox", true)
	priceBox.Text = "120"
	clickNamed(house, "ListButton")
	local listingId = next(State.wardrobe.listings)
	check(listingId ~= nil, "listing should be recorded on the seller")
	check(#State.wardrobe.parts == 0, "a listed part is held in escrow")
	clickNamed(house, "Tab_Mine")
	check(listingId and house:FindFirstChild("Mine_" .. listingId, true) ~= nil, "My listings shows it")
	clickNamed(house, "Tab_Browse")
	Mock.step(0.2, true)
	check(listingId and house:FindFirstChild("Listing_" .. listingId, true) ~= nil, "Browse shows it")
	checkWarnings("list")

	-- a second player buys it
	local buyer = Instance.new("Player")
	buyer.Name = "Buyer"
	buyer.DisplayName = "Buyer"
	buyer.UserId = 2
	buyer.Parent = player.Parent
	DataService.load(buyer)
	WardrobeService.addCoins(buyer, 500, nil)
	local sellerCoins = State.wardrobe.coins
	local okBuy = AuctionService.buy(buyer, listingId)
	Mock.step(0.1, true)
	check(okBuy == true, "the buyer should get the part")
	check(WardrobeService.coins(buyer) == 60 + 500 - 120, "the buyer pays the price")
	check(State.wardrobe.coins == sellerCoins + 108, "the seller gets the price minus the 10% fee")
	check(next(State.wardrobe.listings) == nil, "a sold listing is cleared")
	local again = AuctionService.buy(buyer, listingId)
	check(again == false, "a listing can only be bought once")

	-- sold while the seller is away: the coins wait in the mailbox
	local part2 = givePart(player, "Uncommon")
	local okList = Remotes.func("AuctionAction")
		.OnServerInvoke(player, "List", { kind = "Part", uid = part2.uid, price = 50 })
	check(okList == true, "listing through the remote")
	local id2 = next(State.wardrobe.listings)
	local getPlayers = PlayersService.GetPlayers
	PlayersService.GetPlayers = function()
		return { buyer }
	end
	sellerCoins = State.wardrobe.coins
	check(AuctionService.buy(buyer, id2) == true, "buying from an offline seller")
	PlayersService.GetPlayers = getPlayers
	Mock.step(0.1, true)
	check(State.wardrobe.coins == sellerCoins, "an offline seller isn't paid directly")
	AuctionService.reconcile(player)
	Mock.step(0.1, true)
	check(State.wardrobe.coins == sellerCoins + 45, "the mailbox pays the seller when they're back")
	check(next(State.wardrobe.listings) == nil, "the mailbox clears the listing")

	-- take one back, and let another expire
	local part3 = givePart(player, "Common")
	Remotes.func("AuctionAction").OnServerInvoke(player, "List", { kind = "Part", uid = part3.uid, price = 10 })
	local id3 = next(State.wardrobe.listings)
	clickNamed(house, "Tab_Mine")
	clickNamed(house, "Cancel_" .. id3)
	check(next(State.wardrobe.listings) == nil and #State.wardrobe.parts == 1, "Take back returns the part")
	Remotes.func("AuctionAction").OnServerInvoke(player, "List", { kind = "Part", uid = part3.uid, price = 10 })
	local id4 = next(State.wardrobe.listings)
	DataService.profile(player).wardrobe.listings[id4].expires = 0
	AuctionService.reconcile(player)
	Mock.step(0.1, true)
	check(next(State.wardrobe.listings) == nil and #State.wardrobe.parts == 1, "expired listings come back")
	-- worn garments can't be sold
	local okWorn = AuctionService.list(player, "Garment", State.wardrobe.equipped.Hat, 100)
	check(okWorn == false, "worn garments can't be listed")
	checkWarnings("auction")

	-- the profile survives a rejoin (saved on leave, then loaded again)
	local coins = State.wardrobe.coins
	DataService.save(player, true)
	DataService.load(player)
	Mock.step(0.2, true)
	check(State.wardrobe.coins == coins, "coins should be saved")
	check(#State.wardrobe.garments == 2 and State.wardrobe.equipped.Robe ~= nil, "the wardrobe should be saved")
	checkWarnings("rejoin")
end

if failures > 0 then
	print(failures .. " failure(s)")
	process.exit(1)
end
print("client integration test passed")
