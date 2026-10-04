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

-- Game modes (see src/shared/Modes.lua) ----------------------------------------
-- 1v1 duels run in their own floating arenas, alongside whatever the main arena is doing.
Config.Duel = {
	MaxArenas = 6, -- duels that can run at once
	ArenaRadius = 44,
	BotAfter = 15, -- seconds alone in the duel queue before a bot takes you on
	Countdown = 3,
	SuddenDeathAt = 75, -- seconds into the fight: the arena starts burning both mages
	SuddenDeathDps = 6,
	TimeLimit = 150, -- then the healthier mage wins (a draw if level)
	WinCoins = 3,
	LoseCoins = 1,
	WandRarity = "Rare", -- both duelists get the same wand
	SpellRarities = { "Common", "Uncommon", "Rare", "Epic" }, -- the random spell comes from these
}

-- Battle royale: up to 50 mages drop from a flying carpet onto an enormous island.
-- (Set the place's Max Players to 50 or more for full lobbies; Survival Games still takes 12.)
Config.Royale = {
	MaxParticipants = 50,
	FillTo = 20, -- bots top a battle royale up to this many mages (busy servers need none)
	MinRealPlayers = 1,
	GatherTime = 30, -- the queue stays open this long once someone joins
	CarpetAltitude = 330,
	CarpetTime = 50, -- seconds for the carpet to cross; anyone still aboard is dropped at the end
	GlideFallSpeed = 32, -- studs per second while gliding down
	GlideSpeed = 55, -- sideways steering speed while gliding
	-- the storm circles (timed from the carpet's take-off): each one is shown on the map, waits, then
	-- the storm shrinks to it (a share of the island's radius); outside it burns for `dps`
	Circles = {
		{ wait = 100, shrink = 60, radius = 0.62, dps = 2 },
		{ wait = 55, shrink = 45, radius = 0.36, dps = 4 },
		{ wait = 40, shrink = 40, radius = 0.18, dps = 6 },
		{ wait = 30, shrink = 30, radius = 0.07, dps = 10 },
		{ wait = 20, shrink = 30, radius = 0, dps = 15 },
	},
	ChestRefillAt = 300,
	HardTimeLimit = 1000,
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
	CornucopiaRadius = 50, -- flat plaza in the middle
	PedestalRadius = 72, -- where players start: far enough apart (~38 studs) that nobody is swarmed at the gong
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
	SpellDamageMultiplier = 0.6, -- every spell hits for this share of its listed power (raise for faster fights)
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

-- Chat -----------------------------------------------------------------------
-- Proximity chat: text messages only reach players within Range studs of the speaker, and chat
-- bubbles fade out at the same distance. (Voice chat is spatial by itself once it's turned on in
-- the experience's settings.)
Config.Chat = {
	Proximity = true, -- false = everyone in the server sees every message
	Range = 70, -- studs
}

-- Daily reward, achievements, leaderboard, analytics -----------------------------
Config.Rewards = {
	DailyCoins = 3, -- Enchanted Coins for the first visit of each day (days start at midnight UTC)
}

Config.Achievements = {
	-- achievement id -> Roblox badge id. Create badges on the Creator Dashboard (your experience ->
	-- Engagement -> Badges) and paste their ids here, e.g. { Victor = 2150000001 }. Achievements work
	-- without badges; ones with an id here also award the badge (including to players who unlocked
	-- them before you added it).
	BadgeIds = {} :: { [string]: number },
}

Config.Leaderboard = {
	Size = 10, -- names shown per column on the Hall of Champions board
	RefreshSeconds = 120, -- how often each server re-reads the global top lists
}

Config.Analytics = {
	Enabled = true, -- send events to Roblox's analytics (Creator Dashboard -> Analytics)
}

-- Developer tools ----------------------------------------------------------
-- The 🛠️ Dev panel (free coins, every item and familiar, kit unlocks, match controls) opens for:
-- everyone in Studio, the experience's owner in live servers, and the user ids listed here
-- (add yours if the game belongs to a group). The server checks every request, so nobody else can use it.
Config.Dev = {
	Enabled = true, -- false turns the panel off in live servers (it always works in Studio)
	AdminUserIds = {} :: { number }, -- e.g. { 12345678 } to let a friend test too
	SeparateStudioData = true, -- Studio play tests save to their own stores, so test coins never reach the live game
}

return Config
