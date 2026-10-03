--!strict
-- Central tuning knobs for Mana Wars. Almost every number that affects pacing lives here.

local Config = {}

Config.GameName = "Mana Wars"

-- Match flow ---------------------------------------------------------------
Config.Match = {
	MinPlayers = 2, -- real players needed to start when bots are disabled
	MaxParticipants = 24, -- one per spawn pedestal
	VoteTime = 25, -- map vote in the lobby once enough players are present
	VoteOptions = 3, -- how many maps are offered in each vote
	PedestalCountdown = 10, -- frozen on pedestals before the gong
	GracePeriod = 20, -- seconds of no player-vs-player damage after the gong
	ChestRefillAt = 240, -- seconds after the gong; classic survival-games refill
	StormStartAt = 150, -- seconds after the gong when the mana storm begins closing
	StormShrinkTime = 300, -- seconds for the storm to reach its final radius
	StormFinalRadius = 30,
	StormDamagePerSecond = 5,
	SuddenDeathAt = 600, -- after this the storm hits much harder
	HardTimeLimit = 780, -- the match is called a draw after this many seconds
	EndScreenTime = 9,
	RespawnToLobbyDelay = 4,
}

-- Bots fill empty slots so that small servers (and solo testing) still get a real match.
Config.Bots = {
	Enabled = true,
	FillTo = 8, -- total participants (players + bots); busy servers need no bots at all
	MinRealPlayers = 1, -- bots only join if at least this many humans are queued
	Names = {
		"Mordwyn",
		"Ashka",
		"Velric",
		"Thessaly",
		"Grimble",
		"Oona",
		"Kazrik",
		"Sable",
		"Pell",
		"Wyndra",
		"Corvin",
		"Ysolde",
	},
}

-- Arena ------------------------------------------------------------------
-- Map size, chest counts and decoration live in src/server/Map/MapDefs.lua (one entry per map).
Config.Arena = {
	CornucopiaRadius = 34, -- flat plaza in the middle
	PedestalRadius = 46,
	CornucopiaChests = 10,
	ChestSpacing = 55, -- minimum distance between scattered chests
	LobbyHeight = 420,
}

-- Lobby practice ("Spell Lab") ------------------------------------------------
-- While waiting in the lobby every player gets a sandbox kit to try spells on dummies.
Config.Practice = {
	Enabled = true,
	PartCopies = 3, -- copies of every spell part in the practice kit
	DummyHealth = 500,
	DummyRegenDelay = 3, -- seconds after the last hit before a dummy heals back up
}

-- Combat -----------------------------------------------------------------
Config.Combat = {
	MaxHealth = 100,
	BaseWalkSpeed = 16,
	BaseJumpHeight = 7.2,
	SelfDamageMultiplier = 0.25, -- your own explosions hurt you a little
	CritMultiplier = 2,
	BaseCritChance = 0.05,
	MarkedDamageBonus = 0.15,
	CastTolerance = 0.06, -- seconds of latency forgiveness on cast cooldowns
	MaxProjectiles = 400, -- hard cap on simultaneous server projectiles
	MaxTriggerFanout = 24, -- cap on payload casts spawned by one trigger event
}

-- Inventory ----------------------------------------------------------------
Config.Inventory = {
	MaxWands = 4,
	MaxSpells = 30,
	MaxPartStack = 99,
	MaxConsumableStack = 9,
	ChestReach = 14, -- studs; how close you must stand to loot a chest
}

-- Spellcrafting ------------------------------------------------------------
Config.Spell = {
	MaxModifiers = 4,
	MaxDepth = 3, -- a spell may carry a payload that carries a payload (3 layers total)
	PayloadDelayFactor = 0.5, -- payload cast delay is partially added to the parent
}

-- Premium classes ------------------------------------------------------------
-- A player can pick a premium class if ANY of these are true:
--   * they have Roblox Premium (when UseRobloxPremium = true)
--   * they own the game pass with id ClassesGamePassId (when it is not 0)
--   * the game is running in Studio and StudioUnlocksAll = true
Config.Premium = {
	UseRobloxPremium = true,
	ClassesGamePassId = 0, -- put your game pass id here after you create one
	StudioUnlocksAll = true,
}

Config.DataStoreName = "ManaWars_Stats_v1"

return Config
