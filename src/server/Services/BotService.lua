-- AI mages that fill empty slots. They loot chests, slot spells into their wands,
-- fight anyone they can see, drink potions, and run from the storm.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Combatants = require(script.Parent.Combatants)
local GameState = require(script.Parent.GameState)
local CastingService = require(script.Parent.CastingService)
local InventoryService = require(script.Parent.InventoryService)
local ChestService = require(script.Parent.ChestService)
local MapService = require(script.Parent.MapService)
local WorldQuery = require(script.Parent.WorldQuery)

type Combatant = Combatants.Combatant

local BotService = {}

local bots: { Combatant } = {}
local rng = Random.new()
local running = false

local ANIMATIONS = {
	idle = "rbxassetid://507766666",
	walk = "rbxassetid://507777826",
	run = "rbxassetid://507767714",
	hold = "rbxassetid://507768375",
}

local ROBES = {
	Color3.fromRGB(70, 50, 120),
	Color3.fromRGB(120, 30, 40),
	Color3.fromRGB(30, 80, 120),
	Color3.fromRGB(40, 90, 50),
	Color3.fromRGB(90, 70, 40),
	Color3.fromRGB(30, 30, 40),
	Color3.fromRGB(150, 120, 60),
}
local SKINS = {
	Color3.fromRGB(255, 220, 190),
	Color3.fromRGB(230, 180, 140),
	Color3.fromRGB(180, 130, 95),
	Color3.fromRGB(120, 80, 55),
	Color3.fromRGB(90, 60, 40),
}

local function now(): number
	return workspace:GetServerTimeNow()
end

local function folder(): Folder
	local f = workspace:FindFirstChild("Bots")
	if not f then
		local newFolder = Instance.new("Folder")
		newFolder.Name = "Bots"
		newFolder.Parent = workspace
		return newFolder
	end
	return f :: Folder
end

local function addHat(model: Model, color: Color3)
	local head = model:FindFirstChild("Head") :: BasePart?
	if not head then
		return
	end
	local layers = { { 2.6, 0.25 }, { 1.5, 0.9 }, { 1.05, 0.8 }, { 0.6, 0.7 }, { 0.25, 0.5 } }
	local y = head.Size.Y / 2
	for i, layer in layers do
		local p = Instance.new("Part")
		p.Name = "Hat" .. i
		p.Shape = Enum.PartType.Cylinder
		p.Size = Vector3.new(layer[2], layer[1], layer[1])
		p.Color = color
		p.Material = Enum.Material.Fabric
		p.CanCollide = false
		p.CanQuery = false
		p.Massless = true
		y += layer[2] / 2
		p.CFrame = head.CFrame * CFrame.new(0, y, 0) * CFrame.Angles(0, 0, math.rad(90))
		y += layer[2] / 2
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = head
		weld.Part1 = p
		weld.Parent = p
		p.Parent = model
	end
end

local function makeModel(name: string): Model?
	local robe = ROBES[rng:NextInteger(1, #ROBES)]
	local skin = SKINS[rng:NextInteger(1, #SKINS)]
	local desc = Instance.new("HumanoidDescription")
	desc.HeadColor = skin
	desc.LeftArmColor = robe
	desc.RightArmColor = robe
	desc.TorsoColor = robe
	desc.LeftLegColor = robe:Lerp(Color3.new(0, 0, 0), 0.3)
	desc.RightLegColor = robe:Lerp(Color3.new(0, 0, 0), 0.3)
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
	end)
	if not ok or not model then
		warn("[Bots] could not build a bot body: " .. tostring(model))
		return nil
	end
	model.Name = name
	addHat(model, robe)
	return model
end

local function loadAnimations(c: Combatant)
	local hum = c.humanoid :: Humanoid
	local animator = hum:FindFirstChildOfClass("Animator")
	if not animator then
		local a = Instance.new("Animator")
		a.Parent = hum
		animator = a
	end
	local tracks = {}
	for key, id in ANIMATIONS do
		local anim = Instance.new("Animation")
		anim.AnimationId = id
		local ok, track = pcall(function()
			return (animator :: Animator):LoadAnimation(anim)
		end)
		if ok and track then
			tracks[key] = track
		end
	end
	if tracks.hold then
		tracks.hold.Priority = Enum.AnimationPriority.Action
		tracks.hold:Play()
	end
	if tracks.idle then
		tracks.idle:Play()
	end
	(c.bot :: any).tracks = tracks;
	(c.bot :: any).moving = false
end

local function animate(c: Combatant)
	local b = c.bot :: any
	local tracks = b.tracks
	if not tracks or not c.root then
		return
	end
	local v = (c.root :: BasePart).AssemblyLinearVelocity
	local speed = Vector3.new(v.X, 0, v.Z).Magnitude
	local moving = speed > 1.5
	if moving ~= b.moving then
		b.moving = moving
		if moving then
			if tracks.idle then
				tracks.idle:Stop(0.2)
			end
			if tracks.walk then
				tracks.walk:Play(0.2)
			end
		else
			if tracks.walk then
				tracks.walk:Stop(0.2)
			end
			if tracks.idle then
				tracks.idle:Play(0.2)
			end
		end
	end
	if moving and tracks.walk then
		tracks.walk:AdjustSpeed(math.clamp(speed / 14, 0.5, 1.6))
	end
end

function BotService.spawn(name: string, cframe: CFrame): Combatant?
	local model = makeModel(name)
	if not model then
		return nil
	end
	local c = Combatants.create(name, nil)
	c.bot = {
		skill = rng:NextNumber(0.45, 0.85),
		reaction = rng:NextNumber(0.12, 0.4),
		sight = rng:NextNumber(85, 125),
		nextShot = 0,
		nextTargetCheck = 0,
		target = nil,
		chest = nil,
		skipChests = {},
		wander = nil,
		wanderUntil = 0,
		strafeDir = if rng:NextNumber() < 0.5 then 1 else -1,
		strafeFlip = 0,
		lastPos = cframe.Position,
		stuckCheck = 0,
		stuckCount = 0,
	}
	model:PivotTo(cframe)
	model.Parent = folder()
	Combatants.setModel(c, model)
	local hum = c.humanoid :: Humanoid
	hum.MaxHealth = Config.Combat.MaxHealth
	hum.Health = Config.Combat.MaxHealth
	hum.DisplayName = name
	hum.NameDisplayDistance = 70
	hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOn
	pcall(function()
		(c.root :: BasePart):SetNetworkOwner(nil)
	end)
	loadAnimations(c)
	table.insert(bots, c)
	return c
end

local function pickWander(): Vector3
	local center = GameState.stormCenter
	local radius = math.min(GameState.stormRadius * 0.7, MapService.radius() * 0.7)
	local wet = MapService.liquidLevel() + 1
	local x, z, y = center.X, center.Z, MapService.groundAt(center.X, center.Z)
	-- prefer dry ground (lakes, rivers and lava are no place to wander into)
	for _ = 1, 8 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local dist = rng:NextNumber(0, radius)
		x = center.X + math.cos(angle) * dist
		z = center.Z + math.sin(angle) * dist
		y = MapService.groundAt(x, z)
		if y > wet then
			break
		end
	end
	return Vector3.new(x, y + 3, z)
end

local function eyeOf(c: Combatant): Vector3
	local head = (c.model :: Model):FindFirstChild("Head") :: BasePart?
	return if head then head.Position else (c.root :: BasePart).Position + Vector3.new(0, 1.5, 0)
end

local function think(c: Combatant)
	if not Combatants.isActive(c) then
		return
	end
	local b = c.bot :: any
	local hum = c.humanoid :: Humanoid
	local root = c.root :: BasePart
	local pos = root.Position
	local t = now()
	animate(c)

	-- frozen on a pedestal / in a duel countdown, or still coming down from the carpet
	if c.locked or c.dropping or (not c.duel and GameState.phase == "Countdown") then
		hum:Move(Vector3.zero)
		return
	end
	local duel = c.duel

	if hum.Health < 45 and (c.inventory.consumables.HealingDraught or 0) > 0 then
		InventoryService.useConsumable(c, "HealingDraught")
	end

	local center = GameState.stormCenter
	local toCenter = Vector3.new(center.X - pos.X, 0, center.Z - pos.Z)
	-- (duelists are far from the main arena's storm)
	local outside = duel == nil and toCenter.Magnitude > GameState.stormRadius - 12

	if t >= b.nextTargetCheck then
		b.nextTargetCheck = t + 0.5
		b.target = nil
		local fighting = if duel
			then duel.state == "Fight"
			else GameState.phase == "Battle" or GameState.phase == "Carpet"
		if fighting then
			local eye = eyeOf(c)
			local best, bestDist = nil, b.sight
			for _, other in Combatants.active() do
				-- only rivals in the same fight (a duel, or the main match) who have landed
				if other ~= c and other.duel == duel and not other.dropping then
					local d = ((other.root :: BasePart).Position - pos).Magnitude
					if d < bestDist and WorldQuery.lineOfSight(eye, eyeOf(other)) then
						best, bestDist = other, d
					end
				end
			end
			b.target = best
		end
	end
	local target = b.target
	if target and not Combatants.isActive(target) then
		b.target = nil
		target = nil
	end

	local dest: Vector3? = nil
	if outside then
		dest = Vector3.new(center.X, pos.Y, center.Z) - toCenter.Unit * math.min(GameState.stormRadius * 0.4, 60)
	end

	if target then
		local tp = (target.root :: BasePart).Position
		local to = tp - pos
		local dist = to.Magnitude
		if t >= b.nextShot then
			local vel = (target.root :: BasePart).AssemblyLinearVelocity
			local lead = vel * math.clamp(dist / 110, 0, 0.8) * b.skill
			local err = (1 - b.skill) * (4 + dist * 0.08)
			local aimPos = tp
				+ lead
				+ Vector3.new(rng:NextNumber(-err, err), rng:NextNumber(-err, err) * 0.5, rng:NextNumber(-err, err))
			local ok = CastingService.tryCast(c, aimPos)
			b.nextShot = t + (if ok then rng:NextNumber(0.05, 0.25) else 0.2) + b.reaction
		end
		if not dest then
			if dist > 55 then
				dest = tp
			elseif dist < 18 then
				dest = pos - Vector3.new(to.X, 0, to.Z).Unit * 12
			else
				if t >= b.strafeFlip then
					b.strafeDir = -b.strafeDir
					b.strafeFlip = t + rng:NextNumber(0.8, 2)
				end
				local side = Vector3.new(-to.Z, 0, to.X)
				if side.Magnitude > 0.01 then
					dest = pos + side.Unit * (10 * b.strafeDir)
				end
			end
		end
		hum.AutoRotate = false
		root.CFrame = CFrame.lookAt(pos, Vector3.new(tp.X, pos.Y, tp.Z))
		if rng:NextNumber() < 0.025 then
			hum.Jump = true
		end
	elseif duel then
		-- no line of sight in a duel: go and find the opponent
		hum.AutoRotate = true
		local rival = if duel.a == c then duel.b else duel.a
		if rival and Combatants.isActive(rival) then
			dest = (rival.root :: BasePart).Position
		end
	else
		hum.AutoRotate = true
		if not dest then
			local chest = b.chest
			if chest and (#chest.entries == 0 or not ChestService.get(chest.id)) then
				chest = nil
			end
			if not chest then
				chest = ChestService.nearestWithLoot(pos, 170, b.skipChests)
				b.chest = chest
			end
			if chest then
				if (chest.position - pos).Magnitude < 7 then
					ChestService.botLoot(c, chest)
					b.skipChests[chest.id] = true
					b.chest = nil
				else
					dest = chest.position
				end
			end
		end
		if not dest then
			if not b.wander or (b.wander - pos).Magnitude < 8 or t > b.wanderUntil then
				b.wander = pickWander()
				b.wanderUntil = t + 12
			end
			dest = b.wander
		end
	end

	if t >= b.stuckCheck then
		if dest and (pos - b.lastPos).Magnitude < 1.5 then
			hum.Jump = true
			b.stuckCount += 1
			if b.stuckCount >= 3 then
				if b.chest then
					b.skipChests[b.chest.id] = true
				end
				b.chest = nil
				b.wander = pickWander()
				b.stuckCount = 0
			end
		else
			b.stuckCount = 0
		end
		b.lastPos = pos
		b.stuckCheck = t + 1
	end

	if dest then
		hum:MoveTo(dest)
	end
end

function BotService.all(): { Combatant }
	return bots
end

-- Removes every bot from the main arena (bots fighting a duel are left alone).
function BotService.removeAll()
	for i = #bots, 1, -1 do
		local c = bots[i]
		if not c.duel then
			if c.model then
				c.model:Destroy()
			end
			Combatants.remove(c)
			table.remove(bots, i)
		end
	end
end

function BotService.remove(c: Combatant)
	local i = table.find(bots, c)
	if i then
		table.remove(bots, i)
	end
	if c.model then
		c.model:Destroy()
	end
	Combatants.remove(c)
end

function BotService.init()
	if running then
		return
	end
	running = true
	task.spawn(function()
		while running do
			for _, c in table.clone(bots) do
				local ok, err = pcall(think, c)
				if not ok then
					warn("[Bots] " .. tostring(err))
				end
			end
			task.wait(0.15)
		end
	end)
end

return BotService
