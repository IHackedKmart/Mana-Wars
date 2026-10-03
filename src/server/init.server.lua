-- Mana Wars server entry point. Services are initialised in dependency order.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Create remotes before anything else so clients can find them.
require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))

local Services = script:WaitForChild("Services")

local order = {
	"DataService",
	"MapService",
	"StatusService",
	"DamageService",
	"ProjectileService",
	"ZoneService",
	"SpellExecutor",
	"CastingService",
	"InventoryService",
	"ChestService",
	"ClassService",
	"PracticeService",
	"VoteService",
	"BotService",
	"MatchService",
}

local loaded = {}
for _, name in order do
	local module = require(Services:WaitForChild(name)) :: any
	loaded[name] = module
	if module.init then
		module.init()
	end
end

loaded.MatchService.start()
print("[Mana Wars] server ready")
