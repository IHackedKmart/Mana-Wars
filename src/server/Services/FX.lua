-- Thin wrapper over the FX remote so services can say FX.all("Boom", ...) without
-- touching remotes directly. All visuals are drawn by the client (FXController).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local FX = {}

local fxEvent = Remotes.event("FX")
local announce = Remotes.event("Announce")

function FX.all(kind: string, ...)
	fxEvent:FireAllClients(kind, ...)
end

function FX.to(player: Player?, kind: string, ...)
	if player then
		fxEvent:FireClient(player, kind, ...)
	end
end

-- Banners, kill feed, toasts. data is a plain table.
function FX.announce(kind: string, data: { [string]: any }?)
	announce:FireAllClients(kind, data or {})
end

function FX.announceTo(player: Player?, kind: string, data: { [string]: any }?)
	if player then
		announce:FireClient(player, kind, data or {})
	end
end

return FX
