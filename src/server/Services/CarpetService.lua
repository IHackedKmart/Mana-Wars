-- The battle royale's magic carpet. Everyone in the match rides one enormous flying carpet in a
-- straight line across the island, high above it, and jumps off wherever they like (or is tipped
-- off at the far end). Jumpers glide down on a little rug of their own and can't fight, or be
-- hurt, until they land.
--   * Each player's own client flies their character along with the carpet and steers the glide
--     (see CarpetController), so the ride is smooth; the server checks the rider is roughly where
--     their seat is and decides when they have landed.
--   * Bots ride anchored in their seats, hop off at a random moment and glide down along a path
--     the server moves them on.
-- The carpet's path is published as ReplicatedStorage attributes; clients draw the carpet itself.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Combatants = require(script.Parent.Combatants)
local GameState = require(script.Parent.GameState)
local FX = require(script.Parent.FX)

type Combatant = Combatants.Combatant

local CarpetService = {}

local R = Config.Royale
local COLUMNS = 5
local SPACING = 4.5
local SEAT_HEIGHT = 2.6
local STRAY = 45 -- a rider this far from their seat has left the carpet (one way or another)
local GLIDE_TIMEOUT = 60

type Rider = {
	seat: Vector3,
	state: string, -- "Riding" | "Gliding" | "Landed"
	since: number,
	rug: BasePart?,
	-- bots only: when they hop off, and the path they glide down
	dropAt: number?,
	glideFrom: Vector3?,
	glideTo: Vector3?,
	glideTime: number?,
}

type Ride = {
	from: Vector3,
	to: Vector3,
	dir: Vector3,
	start: number,
	duration: number,
	riders: { [Combatant]: Rider },
	groundAt: (number, number) -> number,
	pickLanding: (Vector3, Random) -> Vector3,
	rng: Random,
}

local ride: Ride? = nil
local stepper: RBXScriptConnection? = nil

local function now(): number
	return workspace:GetServerTimeNow()
end

-- A straight line across the island at carpet height, through a point near (not always on) the
-- middle, so every match flies over different realms.
function CarpetService.path(radius: number, rng: Random): (Vector3, Vector3)
	local angle = rng:NextNumber(0, math.pi * 2)
	local dir = Vector3.new(math.cos(angle), 0, math.sin(angle))
	local side = Vector3.new(-dir.Z, 0, dir.X) * rng:NextNumber(-0.3, 0.3) * radius
	local up = Vector3.new(0, R.CarpetAltitude, 0)
	local reach = radius * 0.85
	return side - dir * reach + up, side + dir * reach + up
end

-- Where seat `i` of `count` is on the carpet (carpet space: X across, Z along the way it flies).
function CarpetService.seatOffset(i: number, count: number): Vector3
	local rows = math.ceil(count / COLUMNS)
	local col = (i - 1) % COLUMNS
	local row = (i - 1) // COLUMNS
	return Vector3.new((col - (COLUMNS - 1) / 2) * SPACING, SEAT_HEIGHT, (row - (rows - 1) / 2) * SPACING)
end

-- How big the carpet is for `count` riders.
function CarpetService.size(count: number): Vector3
	local rows = math.max(2, math.ceil(count / COLUMNS))
	return Vector3.new(COLUMNS * SPACING + 3, 0.6, rows * SPACING + 5)
end

function CarpetService.cframeAt(t: number): CFrame
	local r = ride :: Ride
	local alpha = math.clamp((t - r.start) / r.duration, 0, 1)
	local pos = r.from:Lerp(r.to, alpha)
	return CFrame.lookAt(pos, pos + r.dir)
end

function CarpetService.seatCFrame(c: Combatant): CFrame?
	local r = ride
	local rider = r and r.riders[c]
	if not r or not rider then
		return nil
	end
	return CarpetService.cframeAt(now()) * CFrame.new(rider.seat)
end

function CarpetService.active(): boolean
	return ride ~= nil
end

function CarpetService.stateOf(c: Combatant): string?
	local r = ride
	local rider = r and r.riders[c]
	return if rider then rider.state else nil
end

local function setFlags(c: Combatant, rider: Rider?)
	if c.player then
		c.player:SetAttribute("Riding", rider ~= nil and rider.state == "Riding")
		c.player:SetAttribute("Gliding", rider ~= nil and rider.state == "Gliding")
		c.player:SetAttribute("CarpetSeat", if rider then rider.seat else nil)
	end
end

local function removeRug(rider: Rider)
	if rider.rug then
		rider.rug:Destroy()
		rider.rug = nil
	end
end

-- A little rug under the glider's feet (everyone can see who is still coming down).
local function addRug(c: Combatant, rider: Rider)
	local root = c.root
	if not root or rider.rug then
		return
	end
	local rug = Instance.new("Part")
	rug.Name = "GlideRug"
	rug.Size = Vector3.new(4, 0.3, 5.5)
	rug.Material = Enum.Material.Fabric
	rug.Color = Color3.fromRGB(170, 40, 60)
	rug.CanCollide = false
	rug.CanQuery = false
	rug.CanTouch = false
	rug.Massless = true
	rug.CFrame = root.CFrame * CFrame.new(0, -3.1, 0)
	local trim = Instance.new("Part")
	trim.Name = "Trim"
	trim.Size = Vector3.new(4.4, 0.2, 5.9)
	trim.Material = Enum.Material.Fabric
	trim.Color = Color3.fromRGB(240, 190, 70)
	trim.CanCollide = false
	trim.CanQuery = false
	trim.CanTouch = false
	trim.Massless = true
	trim.CFrame = rug.CFrame * CFrame.new(0, -0.1, 0)
	for _, p in { rug, trim } do
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = p
		weld.Parent = p
		p.Anchored = false
	end
	trim.Parent = rug
	rug.Parent = c.model
	rider.rug = rug
end

local function land(c: Combatant, rider: Rider)
	rider.state = "Landed"
	rider.since = now()
	removeRug(rider)
	c.dropping = nil
	if c.isBot and c.root then
		local root = c.root :: BasePart
		root.Anchored = false
		root.AssemblyLinearVelocity = Vector3.zero
	end
	if c.humanoid then
		(c.humanoid :: Humanoid).Sit = false
	end
	setFlags(c, nil)
end

-- Off the carpet: start gliding down.
local function glide(c: Combatant, rider: Rider)
	local r = ride :: Ride
	rider.state = "Gliding"
	rider.since = now()
	c.dropping = "gliding"
	if c.humanoid then
		(c.humanoid :: Humanoid).Sit = false
	end
	addRug(c, rider)
	if c.isBot and c.root then
		local from = (c.root :: BasePart).Position
		local target = r.pickLanding(from, r.rng)
		local ground = r.groundAt(target.X, target.Z)
		local fall = math.max(10, from.Y - ground)
		local time = fall / R.GlideFallSpeed
		-- (a glider covers at most GlideSpeed studs a second sideways)
		local flat = Vector3.new(target.X - from.X, 0, target.Z - from.Z)
		local reach = time * R.GlideSpeed * 0.9
		if flat.Magnitude > reach then
			flat = flat.Unit * reach
		end
		local x, z = from.X + flat.X, from.Z + flat.Z
		rider.glideFrom = from
		rider.glideTo = Vector3.new(x, r.groundAt(x, z) + 3, z)
		rider.glideTime = time
	end
	setFlags(c, rider)
end

-- A player asked to jump off.
function CarpetService.jump(c: Combatant): boolean
	local r = ride
	local rider = r and r.riders[c]
	if not r or not rider or rider.state ~= "Riding" or now() < r.start then
		return false
	end
	glide(c, rider)
	return true
end

-- Every frame: bots ride in their seats and glide down their paths.
local function step()
	local r = ride
	if not r then
		return
	end
	local t = now()
	local carpet = CarpetService.cframeAt(t)
	for c, rider in r.riders do
		if not c.isBot or not c.root or not (c.root :: BasePart).Parent then
			continue
		end
		local root = c.root :: BasePart
		if rider.state == "Riding" then
			root.Anchored = true
			root.CFrame = carpet * CFrame.new(rider.seat)
		elseif rider.state == "Gliding" and rider.glideFrom and rider.glideTo then
			local from, to = rider.glideFrom :: Vector3, rider.glideTo :: Vector3
			local alpha = math.clamp((t - rider.since) / (rider.glideTime :: number), 0, 1)
			local pos = from:Lerp(to, alpha)
			local flat = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
			local look = if flat.Magnitude > 1 then flat.Unit else Vector3.new(0, 0, -1)
			root.CFrame = CFrame.lookAt(pos, pos + look)
		end
	end
end

-- Puts everyone on the carpet. Bots are moved to their seats now; players are spawned by the
-- caller at CarpetService.seatCFrame. The carpet hovers at the start of its path until `startAt`.
function CarpetService.begin(
	riders: { Combatant },
	from: Vector3,
	to: Vector3,
	startAt: number,
	groundAt: (number, number) -> number,
	pickLanding: (Vector3, Random) -> Vector3,
	rng: Random
)
	CarpetService.stop()
	local flat = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
	local r: Ride = {
		from = from,
		to = to,
		dir = if flat.Magnitude > 0 then flat.Unit else Vector3.new(0, 0, -1),
		start = startAt,
		duration = R.CarpetTime,
		riders = {},
		groundAt = groundAt,
		pickLanding = pickLanding,
		rng = rng,
	}
	ride = r
	GameState.setPublic("CarpetFrom", from)
	GameState.setPublic("CarpetTo", to)
	GameState.setPublic("CarpetStart", startAt)
	GameState.setPublic("CarpetDuration", R.CarpetTime)
	GameState.setPublic("CarpetSize", CarpetService.size(#riders))
	GameState.setPublic("CarpetActive", true)
	for i, c in riders do
		local rider: Rider = {
			seat = CarpetService.seatOffset(i, #riders),
			state = "Riding",
			since = startAt,
		}
		if c.isBot then
			-- most bots hop off somewhere along the way; a few stay on to the very end
			rider.dropAt = startAt + R.CarpetTime * rng:NextNumber(0.08, 1.02)
		end
		r.riders[c] = rider
		c.dropping = "riding"
		setFlags(c, rider)
		if c.isBot and c.root then
			local root = c.root :: BasePart
			root.Anchored = true
			root.CFrame = CarpetService.cframeAt(now()) * CFrame.new(rider.seat)
			if c.humanoid then
				(c.humanoid :: Humanoid).Sit = true
			end
		end
	end
	stepper = RunService.Heartbeat:Connect(step)
end

-- Called a few times a second by the match: tips everyone off at the end of the path, notices
-- riders who have left their seat and gliders who have landed. Returns true once the carpet has
-- crossed the island and everybody is on the ground.
function CarpetService.update(): boolean
	local r = ride
	if not r then
		return true
	end
	local t = now()
	local over = t >= r.start + r.duration
	local carpet = CarpetService.cframeAt(t)
	local everyoneDown = true
	for c, rider in r.riders do
		if not Combatants.isActive(c) then
			r.riders[c] = nil
			c.dropping = nil
			removeRug(rider)
			continue
		end
		local root = c.root :: BasePart
		if rider.state == "Riding" then
			if over then
				glide(c, rider)
				if c.player then
					FX.announceTo(c.player, "Toast", { text = "🧞 End of the line! Everybody off the carpet" })
				end
			elseif c.isBot then
				if t >= (rider.dropAt :: number) and t >= r.start then
					glide(c, rider)
				end
			elseif t >= r.start then
				-- (a player whose client isn't flying them along has fallen off, or jumped)
				local seat = (carpet * CFrame.new(rider.seat)).Position
				if (root.Position - seat).Magnitude > STRAY then
					glide(c, rider)
				end
			end
		end
		if rider.state == "Gliding" then
			local pos = root.Position
			local landed
			if c.isBot then
				landed = t - rider.since >= (rider.glideTime :: number)
			else
				-- (on the ground, or standing on something: a roof, a tower, a tree)
				local floor = (c.humanoid :: Humanoid).FloorMaterial
				local standing = floor ~= nil and floor ~= Enum.Material.Air and t - rider.since > 0.5
				landed = pos.Y - r.groundAt(pos.X, pos.Z) < 5 or standing
			end
			if landed or t - rider.since > GLIDE_TIMEOUT then
				land(c, rider)
			end
		end
		if rider.state ~= "Landed" then
			everyoneDown = false
		end
	end
	if over and everyoneDown then
		GameState.setPublic("CarpetActive", false)
	end
	return over and everyoneDown
end

-- Takes someone off the carpet for good (they died or left).
function CarpetService.forget(c: Combatant)
	local r = ride
	local rider = r and r.riders[c]
	if r and rider then
		removeRug(rider)
		r.riders[c] = nil
		c.dropping = nil
		setFlags(c, nil)
	end
end

function CarpetService.stop()
	if stepper then
		stepper:Disconnect()
		stepper = nil
	end
	local r = ride
	if r then
		for c, rider in r.riders do
			removeRug(rider)
			c.dropping = nil
			setFlags(c, nil)
		end
	end
	ride = nil
	GameState.setPublic("CarpetActive", false)
end

function CarpetService.init()
	Remotes.event("RoyaleAction").OnServerEvent:Connect(function(player: Player, action: any)
		local c = Combatants.forPlayer(player)
		if c and action == "Jump" then
			CarpetService.jump(c)
		end
	end)
end

return CarpetService
