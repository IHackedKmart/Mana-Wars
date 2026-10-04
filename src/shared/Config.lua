--!strict
-- Central tuning knobs for Mana Wars. Almost every number that affects pacing lives here.

local Config = {}

Config.GameName = "Mana Wars"

-- Match flow ---------------------------------------------------------------
Config.Match = {
	MinPlayers = 2, -- real players needed to start when bots are disabled
	MaxParticipants = 12, -- one per spawn pedestal
	VoteTime = 30, -- map vote in the library once someone has joined the queue (others can still join)
	VoteOptions = 3, -- how many maps are offered in each vote
	PedestalCountdown = 10, -- frozen on pedestals before the gong
	GracePeriod = 5, -- a short breather after the gong (no PvP) without making the cornucopia free loot
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
-- Outside a match (in the hub or the library) every player gets a sandbox kit to try spells on dummies.
Config.Practice = {
	Enabled = true,
	PartCopies = 3, -- copies of every spell part in the practice kit
	DummyHealth = 500,
	DummyRegenDelay = 3, -- seconds after the last hit before a dummy heals back up
	MovingDummySpeed = 0.6, -- how fast the hub's moving dummies slide along their rails
}

-- Hub & queue ------------------------------------------------------------------
-- Everyone spawns in the hub (Arcanum Plaza). Walking through its portal joins the queue and moves
-- you to the library, where the next match's map vote happens. Only queued players are put in matches.
Config.Queue = {
	StayQueuedAfterMatch = true, -- after a match you wait in the library for the next one (leave any time)
	FullQueueVoteTime = 10, -- once every pedestal is spoken for, the vote is cut down to this many seconds
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
	MaxSplits = 40, -- cap on Hydra / Fractal copies spawned by one cast
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

-- Kits (classes) for sale ---------------------------------------------------------
-- Every paid kit in src/shared/Classes.lua is its own game pass. Create the passes on the Creator
-- Dashboard (Monetization -> Passes) at the tier's price, then paste each pass id here.
-- A kit with id 0 can't be bought yet (the shop says "coming soon").
-- A player owns a kit if ANY of these are true:
--   * they own its game pass
--   * they have Roblox Premium and the kit's tier is <= PremiumFreeTier (0 turns this off)
--   * the game is running in Studio and StudioUnlocksAll = true (so you can test every kit)
Config.Kits = {
	GamePassIds = {
		-- Copper ($0.99, 80 R$)
		Cryomancer = 0,
		Geomancer = 0,
		Windwalker = 0,
		-- Silver ($2.99, 240 R$)
		Pyromancer = 0,
		Plaguebringer = 0,
		Stormcaller = 0,
		-- Gold ($4.99, 400 R$)
		Voidwalker = 0,
		Bloodmage = 0,
		Lightbringer = 0,
		-- Arcane ($9.99, 800 R$)
		Artificer = 0,
		Chronomancer = 0,
		Swarmlord = 0,
		-- Astral ($14.99, 1200 R$)
		Stormlord = 0,
		VoidArchon = 0,
		-- Archmage ($24.99, 2000 R$)
		Archmage = 0,
		Harbinger = 0,
	} :: { [string]: number },
	PremiumFreeTier = 1, -- Roblox Premium members get every Copper kit for free
	StudioUnlocksAll = true,
}

-- Enchanted Coins, Coffers and the auction house ---------------------------------
Config.Economy = {
	CoinsForFirst = 12, -- 1st place earns 12 coins, 2nd 11 ... 12th earns 1 (never less than 1)
	StarterCoins = 60, -- enough for a first Tattered Satchel
	MaxParts = 250, -- wardrobe space
	MaxGarments = 60,
	MaxFamiliars = 60,
	AuctionFee = 0.1, -- the auction house keeps 10% of every sale
	AuctionHours = 48, -- unsold listings come back after this long
	MaxListings = 10, -- per player
	MaxPrice = 1000000,
}

Config.DataStoreName = "ManaWars_Stats_v1"

return Config
