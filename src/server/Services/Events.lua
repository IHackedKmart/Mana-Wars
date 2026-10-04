-- A tiny server-side event bus. Game services announce what happened ("Kill", "ChestOpened",
-- "Coins"...) and the achievement, leaderboard and analytics services listen, so the game code
-- doesn't have to know about any of them (and nothing ends up requiring itself in a loop).
--
-- Events (all start with the player they're about):
--   Kill(player)                            Win(player)
--   MatchFinished(player, place, outOf, kills, mapId, classId, mode)   ("Survival" or "Royale")
--   DuelFinished(player, won, rivalIsBot)   ModeQueued(player, mode)
--   ChestOpened(player, tier)               Forged(player)
--   CofferOpened(player, boxId)             FamiliarFound(player, familiar)
--   Crafted(player, garment)                AuctionSold(player, price)   AuctionBought(player, price)
--   TutorialDone(player)                    QueueJoined(player)
--   KitPicked(player, classId)              PassPurchased(player, classId)
--   Coins(player, delta, transactionType, sku, balance)   (delta < 0 when spending)
--   DailyClaimed(player, streak, coins)     AchievementUnlocked(player, achievement)

local Events = {}

local listeners: { [string]: { (...any) -> () } } = {}

function Events.on(name: string, callback: (...any) -> ())
	listeners[name] = listeners[name] or {}
	table.insert(listeners[name], callback)
end

-- Calls every listener in its own thread, so a slow or broken one can't hold up the game.
function Events.fire(name: string, ...: any)
	local list = listeners[name]
	if not list then
		return
	end
	for _, callback in list do
		task.spawn(callback, ...)
	end
end

return Events
