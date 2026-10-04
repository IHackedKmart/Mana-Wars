-- Proximity chat. The server decides who each text message reaches: only players within
-- Config.Chat.Range studs of the speaker (and the speaker themselves). The Plaza, the library and
-- the arena are far apart, so each has its own conversation, and in a match you only talk to
-- whoever is near you. Chat bubbles fade out at the same distance.
-- Voice chat needs no code: Roblox voice is spatial (you hear people near you) once voice is
-- enabled for the experience.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local ChatService = {}

local function rootOf(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- Can `listener` see what `speaker` says?
function ChatService.inRange(speaker: Player, listener: Player): boolean
	if speaker == listener or not Config.Chat.Proximity then
		return true
	end
	local a, b = rootOf(speaker), rootOf(listener)
	if not a or not b then
		return false -- (between lives: you can't be heard until you're back in the world)
	end
	return (a.Position - b.Position).Magnitude <= Config.Chat.Range
end

-- The TextChannel.ShouldDeliverCallback: called once per listener for every message.
function ChatService.shouldDeliver(message: any, textSource: any): boolean
	local from = message and message.TextSource
	local speaker = from and Players:GetPlayerByUserId(from.UserId)
	local listener = textSource and Players:GetPlayerByUserId(textSource.UserId)
	if not speaker or not listener then
		return true -- system messages and the like
	end
	return ChatService.inRange(speaker, listener)
end

function ChatService.init()
	local ok, service = pcall(function()
		return game:GetService("TextChatService")
	end)
	if not ok or not service then
		return
	end
	local textChat = service :: TextChatService
	task.spawn(function()
		local channels = textChat:WaitForChild("TextChannels", 30)
		local general = channels and channels:WaitForChild("RBXGeneral", 30)
		if general and general:IsA("TextChannel") then
			general.ShouldDeliverCallback = ChatService.shouldDeliver
		else
			warn("[Chat] no RBXGeneral channel: proximity chat is off (is TextChatService enabled?)")
		end
		local bubbles = textChat:FindFirstChildOfClass("BubbleChatConfiguration")
		if bubbles and Config.Chat.Proximity then
			bubbles.MaxDistance = Config.Chat.Range
		end
	end)
end

return ChatService
