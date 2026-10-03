--[[
	A tiny fake Roblox engine for running Mana Wars code under Lune.

	Provides: an Instance tree (properties, children, attributes, working signals),
	a controllable clock + task scheduler, Roblox's Random, fake RemoteEvents that connect a
	server realm and a client realm in the same process, a flat-ground workspace with raycasts,
	and a module loader that resolves `require(script.Parent.X)` against src/.
]]

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

local Vector3 = roblox.Vector3
local Vector2 = roblox.Vector2

local Mock = {}

---------------------------------------------------------------------------
-- CFrame (Lune's lookAt flips directions exactly along -Z; Roblox does not)
---------------------------------------------------------------------------

local function lookAt(at, target, up)
	local look = target - at
	if look.Magnitude < 1e-9 then
		return roblox.CFrame.new(at)
	end
	look = look.Unit
	local right = look:Cross(up or Vector3.yAxis)
	if right.Magnitude < 1e-6 then
		right = look:Cross(Vector3.zAxis)
	end
	right = right.Unit
	return roblox.CFrame.fromMatrix(at, right, right:Cross(look), -look)
end
local CFrame = setmetatable({ lookAt = lookAt }, { __index = roblox.CFrame })
Mock.CFrame = CFrame

---------------------------------------------------------------------------
-- Clock, scheduler, warnings
---------------------------------------------------------------------------

Mock.clock = { t = 1000 }
Mock.warnings = {} :: { string }
local delayed: { { at: number, fn: any, args: { any } } } = {}

local mockTask = {}
function mockTask.spawn(fn, ...)
	local co = if type(fn) == "thread" then fn else coroutine.create(fn)
	local ok, err = coroutine.resume(co, ...)
	if not ok then
		table.insert(Mock.warnings, "task error: " .. tostring(err) .. "\n" .. debug.traceback(co))
	end
	return co
end
mockTask.defer = mockTask.spawn
function mockTask.delay(seconds, fn, ...)
	table.insert(delayed, { at = Mock.clock.t + (seconds or 0), fn = fn, args = table.pack(...) })
end
function mockTask.wait(seconds)
	-- Only legal inside a coroutine: resume it later on the simulated clock.
	local co = coroutine.running()
	table.insert(delayed, {
		at = Mock.clock.t + (seconds or 0),
		fn = co,
		args = table.pack(),
	})
	return coroutine.yield()
end
Mock.task = mockTask

function Mock.clearDelayed()
	table.clear(delayed)
end

function Mock.runDelayed()
	local i = 1
	while i <= #delayed do
		local d = delayed[i]
		if d.at <= Mock.clock.t then
			table.remove(delayed, i)
			if type(d.fn) == "thread" then
				local ok, err = coroutine.resume(d.fn)
				if not ok then
					table.insert(Mock.warnings, "task error: " .. tostring(err))
				end
			else
				mockTask.spawn(d.fn, table.unpack(d.args, 1, d.args.n))
			end
		else
			i += 1
		end
	end
end

---------------------------------------------------------------------------
-- Signals
---------------------------------------------------------------------------

function Mock.signal()
	local handlers = {}
	local sig = { __signal = true }
	function sig:Connect(fn)
		table.insert(handlers, fn)
		return {
			Disconnect = function()
				local i = table.find(handlers, fn)
				if i then
					table.remove(handlers, i)
				end
			end,
		}
	end
	sig.Once = sig.Connect
	function sig:Fire(...)
		for _, fn in table.clone(handlers) do
			mockTask.spawn(fn, ...)
		end
	end
	function sig:Wait()
		return nil
	end
	return sig
end

---------------------------------------------------------------------------
-- Instances
---------------------------------------------------------------------------

local PART_CLASSES = {
	Part = true,
	WedgePart = true,
	TrussPart = true,
	SpawnLocation = true,
	BasePart = true,
	MeshPart = true,
}
local SUPER = {
	Part = "BasePart",
	WedgePart = "BasePart",
	TrussPart = "BasePart",
	MeshPart = "BasePart",
	SpawnLocation = "Part",
	BasePart = "PVInstance",
	Model = "PVInstance",
	UIGridLayout = "UIGridStyleLayout",
	UIListLayout = "UIGridStyleLayout",
	TextButton = "GuiButton",
	ImageButton = "GuiButton",
	GuiButton = "GuiObject",
	TextLabel = "GuiObject",
	Frame = "GuiObject",
	ScrollingFrame = "GuiObject",
	ScreenGui = "LayerCollector",
	BillboardGui = "LayerCollector",
	SurfaceGui = "LayerCollector",
}
local DEFAULTS = {
	Humanoid = { Health = 100, MaxHealth = 100, WalkSpeed = 16, AutoRotate = true, DisplayName = "" },
	TextButton = { Visible = true, Text = "", Size = roblox.UDim2.new(), Position = roblox.UDim2.new() },
	TextLabel = { Visible = true, Text = "", Size = roblox.UDim2.new(), Position = roblox.UDim2.new() },
	Frame = { Visible = true, Size = roblox.UDim2.new(), Position = roblox.UDim2.new() },
	ScrollingFrame = { Visible = true, Size = roblox.UDim2.new(), Position = roblox.UDim2.new() },
	ScreenGui = { Enabled = true },
	UIScale = { Scale = 1 },
	ParticleEmitter = { Enabled = true },
}

local function isA(className: string, target: string): boolean
	if target == "Instance" then
		return true
	end
	local c: string? = className
	while c do
		if c == target then
			return true
		end
		c = SUPER[c]
	end
	return false
end

local InstanceMeta = {}
local methods = {}

function methods:GetChildren()
	return table.clone(rawget(self, "_children"))
end
function methods:GetDescendants()
	local out = {}
	local function walk(inst)
		for _, child in rawget(inst, "_children") do
			table.insert(out, child)
			walk(child)
		end
	end
	walk(self)
	return out
end
function methods:FindFirstChild(name, recursive)
	for _, child in rawget(self, "_children") do
		if child.Name == name then
			return child
		end
	end
	if recursive then
		for _, child in rawget(self, "_children") do
			local found = child:FindFirstChild(name, true)
			if found then
				return found
			end
		end
	end
	return nil
end
methods.WaitForChild = methods.FindFirstChild
function methods:FindFirstChildOfClass(className)
	for _, child in rawget(self, "_children") do
		if rawget(child, "ClassName") == className then
			return child
		end
	end
	return nil
end
function methods:FindFirstChildWhichIsA(className)
	for _, child in rawget(self, "_children") do
		if isA(rawget(child, "ClassName"), className) then
			return child
		end
	end
	return nil
end
function methods:FindFirstAncestorOfClass(className)
	local p = self.Parent
	while p do
		if rawget(p, "ClassName") == className then
			return p
		end
		p = p.Parent
	end
	return nil
end
function methods:IsA(className)
	return isA(rawget(self, "ClassName"), className)
end
function methods:IsDescendantOf(other)
	local p = self.Parent
	while p do
		if p == other then
			return true
		end
		p = p.Parent
	end
	return false
end
function methods:Destroy()
	self.Parent = nil
	rawset(self, "_destroyed", true)
	for _, child in table.clone(rawget(self, "_children")) do
		child:Destroy()
	end
end
function methods:ClearAllChildren()
	for _, child in table.clone(rawget(self, "_children")) do
		child:Destroy()
	end
end
function methods:SetAttribute(name, value)
	rawget(self, "_attributes")[name] = value
	local sig = rawget(self, "_attrSignals")[name]
	if sig then
		sig:Fire()
	end
end
function methods:GetAttribute(name)
	return rawget(self, "_attributes")[name]
end
function methods:GetAttributeChangedSignal(name)
	local sigs = rawget(self, "_attrSignals")
	sigs[name] = sigs[name] or Mock.signal()
	return sigs[name]
end
function methods:GetPropertyChangedSignal(name)
	return self:_signal("Changed:" .. name)
end
function methods:_signal(name)
	local sigs = rawget(self, "_signals")
	sigs[name] = sigs[name] or Mock.signal()
	return sigs[name]
end
function methods:PivotTo(cf)
	local root = self:FindFirstChild("HumanoidRootPart") or rawget(self, "_props").PrimaryPart
	if root then
		root.CFrame = cf
	end
end
function methods:GetPivot()
	local root = self:FindFirstChild("HumanoidRootPart") or rawget(self, "_props").PrimaryPart
	return if root then root.CFrame else CFrame.new()
end
function methods:SetNetworkOwner() end
function methods:Play() end
function methods:Stop() end
function methods:Emit() end
function methods:AdjustSpeed() end
function methods:LoadAnimation()
	return Mock.Instance.new("AnimationTrack")
end
function methods:Clone()
	local copy = Mock.Instance.new(rawget(self, "ClassName"))
	for k, v in rawget(self, "_props") do
		if k ~= "Parent" then
			copy[k] = v
		end
	end
	for _, child in rawget(self, "_children") do
		child:Clone().Parent = copy
	end
	return copy
end
-- Humanoid / character helpers
function methods:MoveTo() end
function methods:Move() end
function methods:ChangeState() end
function methods:EquipTool(tool)
	tool.Parent = self.Parent
end
function methods:UnequipTools() end
function methods:TakeDamage(amount)
	self.Health -= amount
end

local SIGNAL_NAMES = {
	Activated = true,
	MouseButton1Click = true,
	MouseButton2Click = true,
	MouseEnter = true,
	MouseLeave = true,
	Triggered = true,
	Died = true,
	Touched = true,
	Changed = true,
	CharacterAdded = true,
	ChildAdded = true,
	OnClientEvent = true,
	OnServerEvent = true,
	Completed = true,
}

InstanceMeta.__index = function(self, key)
	local m = methods[key]
	if m then
		return m
	end
	if SIGNAL_NAMES[key] then
		return self:_signal(key)
	end
	local props = rawget(self, "_props")
	if key == "Position" and PART_CLASSES[rawget(self, "ClassName")] then
		return (props.CFrame or CFrame.new()).Position
	end
	local value = props[key]
	if value ~= nil then
		return value
	end
	if key == "AssemblyLinearVelocity" or key == "WorldPosition" then
		return Vector3.zero
	elseif key == "CFrame" then
		return CFrame.new()
	elseif key == "Size" and PART_CLASSES[rawget(self, "ClassName")] then
		return Vector3.new(4, 1, 2)
	elseif key == "AbsoluteSize" then
		return Vector2.new(1280, 720)
	elseif key == "AbsolutePosition" then
		return Vector2.new(0, 0)
	elseif key == "Character" then
		return nil
	end
	return nil
end
InstanceMeta.__newindex = function(self, key, value)
	local props = rawget(self, "_props")
	if key == "Parent" then
		local old = props.Parent
		if old == value then
			return
		end
		if old then
			local siblings = rawget(old, "_children")
			local i = table.find(siblings, self)
			if i then
				table.remove(siblings, i)
			end
		end
		props.Parent = value
		if value then
			table.insert(rawget(value, "_children"), self)
		end
	elseif key == "Position" and PART_CLASSES[rawget(self, "ClassName")] then
		props.CFrame = CFrame.new(value)
	else
		props[key] = value
	end
end
InstanceMeta.__tostring = function(self)
	return rawget(self, "ClassName") .. "(" .. tostring(rawget(self, "_props").Name) .. ")"
end

Mock.Instance = {}
function Mock.Instance.new(className: string, parent: any?)
	local inst = setmetatable({
		ClassName = className,
		_props = { Name = className },
		_children = {},
		_attributes = {},
		_attrSignals = {},
		_signals = {},
	}, InstanceMeta)
	for k, v in DEFAULTS[className] or {} do
		inst[k] = v
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

function Mock.isInstance(v): boolean
	return type(v) == "table" and getmetatable(v) == InstanceMeta
end

function Mock.typeof(v)
	if Mock.isInstance(v) then
		return "Instance"
	end
	if type(v) == "table" and rawget(v, "__signal") then
		return "RBXScriptSignal"
	end
	return typeof(v)
end

---------------------------------------------------------------------------
-- Random
---------------------------------------------------------------------------

local Random = {}
Random.__index = Random
local seedCounter = 12345
function Random.new(seed)
	seedCounter += 7919
	local s = math.floor(seed or seedCounter) % 2147483647
	if s <= 0 then
		s += 2147483646
	end
	return setmetatable({ state = s }, Random)
end
function Random:_next()
	self.state = (self.state * 16807) % 2147483647
	return (self.state - 1) / 2147483646
end
function Random:NextNumber(a, b)
	local r = self:_next()
	if a == nil then
		return r
	end
	return a + (b - a) * r
end
function Random:NextInteger(a, b)
	return math.min(b, a + math.floor((b - a + 1) * self:_next()))
end
Mock.Random = Random

---------------------------------------------------------------------------
-- Remotes shared by both realms
---------------------------------------------------------------------------

Mock.remoteCounts = {} :: { [string]: number }
Mock.localPlayer = nil :: any
local remotes = {}

local function count(name: string, kind: any)
	local key = if type(kind) == "string" then name .. ":" .. kind else name
	Mock.remoteCounts[key] = (Mock.remoteCounts[key] or 0) + 1
end

local function makeRemote(name: string)
	local r = {
		Name = name,
		OnServerEvent = Mock.signal(),
		OnClientEvent = Mock.signal(),
		OnServerInvoke = nil,
	}
	function r:FireAllClients(...)
		count(name, (...))
		r.OnClientEvent:Fire(...)
	end
	function r:FireClient(player, ...)
		count(name, (...))
		if player == Mock.localPlayer then
			r.OnClientEvent:Fire(...)
		end
	end
	function r:FireServer(...)
		count(name, (...))
		r.OnServerEvent:Fire(Mock.localPlayer, ...)
	end
	function r:InvokeServer(...)
		count(name, (...))
		assert(r.OnServerInvoke, "no server handler for " .. name)
		return r.OnServerInvoke(Mock.localPlayer, ...)
	end
	return r
end

Mock.Remotes = {}
function Mock.Remotes.event(name)
	remotes[name] = remotes[name] or makeRemote(name)
	return remotes[name]
end
Mock.Remotes.unreliable = Mock.Remotes.event
Mock.Remotes.func = Mock.Remotes.event

---------------------------------------------------------------------------
-- The world: flat floor at y = 0 and a wall at z = -80
---------------------------------------------------------------------------

local Instance = Mock.Instance
local floorPart = Instance.new("Part")
floorPart.Name = "Floor"
local wallPart = Instance.new("Part")
wallPart.Name = "Wall"
Mock.WALL_Z = -80

local function planeHit(origin, dir, radius)
	local best = nil
	if dir.Y < -1e-6 then
		local t = (radius - origin.Y) / dir.Y
		if t >= 0 and t <= 1 then
			local p = origin + dir * t
			best = { t = t, Position = Vector3.new(p.X, 0, p.Z), Normal = Vector3.yAxis, Instance = floorPart }
		end
	end
	if dir.Z < -1e-6 then
		local t = (Mock.WALL_Z + radius - origin.Z) / dir.Z
		if t >= 0 and t <= 1 and (not best or t < best.t) then
			local p = origin + dir * t
			best = { t = t, Position = Vector3.new(p.X, p.Y, Mock.WALL_Z), Normal = Vector3.zAxis, Instance = wallPart }
		end
	end
	if best then
		return {
			Position = best.Position,
			Normal = best.Normal,
			Instance = best.Instance,
			Distance = (best.Position - origin).Magnitude,
			Material = roblox.Enum.Material.Plastic,
		}
	end
	return nil
end

local workspace = Instance.new("Workspace")
workspace.Name = "Workspace"
local terrain = Instance.new("Terrain", workspace)
terrain.Name = "Terrain"
rawset(workspace, "Terrain", terrain)
rawset(workspace, "GetServerTimeNow", function()
	return Mock.clock.t
end)
rawset(workspace, "Raycast", function(_, origin, dir)
	return planeHit(origin, dir, 0)
end)
rawset(workspace, "Spherecast", function(_, origin, radius, dir)
	return planeHit(origin, dir, radius)
end)
local camera = Instance.new("Camera", workspace)
camera.ViewportSize = Vector2.new(1280, 720)
camera.CFrame = CFrame.lookAt(Vector3.new(0, 8, 12), Vector3.new(0, 3, -30))
rawset(camera, "ViewportPointToRay", function(self, x, y)
	-- simple pinhole camera looking down -Z from its CFrame
	local cf = self.CFrame
	local nx = (x / 1280 - 0.5) * 1.6
	local ny = -(y / 720 - 0.5) * 0.9
	local dir = (cf.LookVector + cf.RightVector * nx + cf.UpVector * ny).Unit
	return { Origin = cf.Position, Direction = dir }
end)
workspace.CurrentCamera = camera
Mock.workspace = workspace

Mock.RaycastParams = {
	new = function()
		return {}
	end,
}

---------------------------------------------------------------------------
-- Module loader (one cache per realm, so client and server get their own copies)
---------------------------------------------------------------------------

local ROOTS = { Shared = "src/shared", Server = "src/server", Client = "src/client" }

local function makeNode(nodes, path)
	local n = nodes[path]
	if n then
		return n
	end
	n = setmetatable({ __path = path }, {
		__index = function(self, key)
			local p = rawget(self, "__path")
			if key == "Parent" then
				local parent = string.match(p, "^(.*)/[^/]+$")
				return if parent then makeNode(nodes, parent) else nil
			elseif key == "WaitForChild" or key == "FindFirstChild" then
				return function(_, name)
					return makeNode(nodes, p .. "/" .. name)
				end
			elseif key == "Name" then
				return string.match(p, "([^/]+)$")
			end
			return makeNode(nodes, p .. "/" .. key)
		end,
	})
	nodes[path] = n
	return n
end

-- Read every source file up front: fs.readFile yields inside Lune, which would strand
-- modules first required from inside a simulated task.
local sources: { [string]: string } = {}
local function preload(dir: string)
	for _, name in fs.readDir(dir) do
		local full = dir .. "/" .. name
		if fs.isDir(full) then
			preload(full)
		elseif string.match(name, "%.luau?$") then
			sources[full] = fs.readFile(full)
		end
	end
end
for _, dir in ROOTS do
	preload(dir)
end

local function fileFor(path: string): string?
	local rootName, rest = string.match(path, "^([^/]+)/?(.*)$")
	local base = ROOTS[rootName]
	if not base then
		return nil
	end
	local full = if rest ~= "" then base .. "/" .. rest else base
	for _, candidate in
		{
			full .. ".lua",
			full .. ".luau",
			full .. "/init.lua",
			full .. "/init.luau",
			full .. "/init.client.lua",
			full .. "/init.server.lua",
		}
	do
		if sources[candidate] then
			return candidate
		end
	end
	return nil
end

export type Realm = {
	load: (string) -> any,
	node: (string) -> any,
	env: { [string]: any },
}

-- services: name -> mock service object for game:GetService
function Mock.realm(services: { [string]: any }, isServer: boolean): Realm
	local nodes = {}
	local cache = {}
	local env: { [string]: any }

	local function realmRequire(target)
		local path = rawget(target, "__path")
		assert(path, "require expects a module node, got " .. tostring(target))
		if path == "Shared/Remotes" then
			return Mock.Remotes
		end
		if cache[path] ~= nil then
			return cache[path]
		end
		local file = fileFor(path)
		assert(file, "no module for " .. path)
		local moduleEnv = table.clone(env)
		moduleEnv.script = makeNode(nodes, path)
		local chunk = luau.load(sources[file], { debugName = file, environment = moduleEnv })
		local result = chunk()
		cache[path] = result
		return result
	end

	local repAttributes = Mock.repAttributes
	local replicated = setmetatable({}, {
		__index = function(_, key)
			if key == "Shared" then
				return makeNode(nodes, "Shared")
			elseif key == "WaitForChild" or key == "FindFirstChild" then
				return function(_, name)
					return makeNode(nodes, name)
				end
			elseif key == "SetAttribute" then
				return function(_, name, value)
					repAttributes[name] = value
				end
			elseif key == "GetAttribute" then
				return function(_, name)
					return repAttributes[name]
				end
			elseif key == "GetAttributeChangedSignal" then
				return function()
					return Mock.signal()
				end
			end
			return nil
		end,
	})
	local allServices = table.clone(services)
	allServices.ReplicatedStorage = replicated
	local game = {
		GetService = function(_, name)
			local s = allServices[name]
			assert(s, "service not mocked: " .. name)
			return s
		end,
		BindToClose = function() end,
	}

	env = {
		game = game,
		workspace = Mock.workspace,
		Instance = Mock.Instance,
		Random = Mock.Random,
		RaycastParams = Mock.RaycastParams,
		task = Mock.task,
		typeof = Mock.typeof,
		require = realmRequire,
		warn = function(...)
			local parts = {}
			for i = 1, select("#", ...) do
				parts[i] = tostring(select(i, ...))
			end
			table.insert(Mock.warnings, table.concat(parts, " "))
		end,
		print = function() end,
		Vector3 = Vector3,
		Vector2 = Vector2,
		CFrame = CFrame,
		Color3 = roblox.Color3,
		ColorSequence = roblox.ColorSequence,
		ColorSequenceKeypoint = roblox.ColorSequenceKeypoint,
		NumberSequence = roblox.NumberSequence,
		NumberSequenceKeypoint = roblox.NumberSequenceKeypoint,
		NumberRange = roblox.NumberRange,
		UDim = roblox.UDim,
		UDim2 = roblox.UDim2,
		Region3 = roblox.Region3,
		Enum = roblox.Enum,
		TweenInfo = {
			new = function()
				return {}
			end,
		},
	}
	local _ = isServer
	return {
		load = function(path)
			return realmRequire(makeNode(nodes, path))
		end,
		node = function(path)
			return makeNode(nodes, path)
		end,
		env = env,
	}
end

Mock.repAttributes = {}

---------------------------------------------------------------------------
-- Common service mocks
---------------------------------------------------------------------------

Mock.Heartbeat = Mock.signal()
Mock.RenderStepped = Mock.signal()
local renderBindings = {}

function Mock.runService(isServer: boolean)
	return {
		Heartbeat = Mock.Heartbeat,
		RenderStepped = Mock.RenderStepped,
		Stepped = Mock.signal(),
		IsServer = function()
			return isServer
		end,
		IsClient = function()
			return not isServer
		end,
		IsStudio = function()
			return true
		end,
		BindToRenderStep = function(_, name, _priority, fn)
			renderBindings[name] = fn
		end,
		UnbindFromRenderStep = function(_, name)
			renderBindings[name] = nil
		end,
	}
end

Mock.TweenService = {
	Create = function(_, inst, _info, goal)
		return {
			Play = function()
				-- jump straight to the goal so code that reads the result still works
				for k, v in goal do
					inst[k] = v
				end
			end,
			Completed = Mock.signal(),
		}
	end,
}

-- Advance the whole simulated game: delayed tasks, server heartbeat, client frames.
function Mock.step(seconds: number, clientToo: boolean?)
	local dt = 1 / 60
	for _ = 1, math.max(1, math.floor(seconds / dt + 0.5)) do
		Mock.clock.t += dt
		Mock.runDelayed()
		Mock.Heartbeat:Fire(dt)
		if clientToo then
			Mock.RenderStepped:Fire(dt)
			for _, fn in renderBindings do
				fn(dt)
			end
		end
	end
end

return Mock
