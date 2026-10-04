-- Proximity chat, client side. The server filters who receives each message (ChatService); here we
-- fade chat bubbles out at the same range and tell the player how chat works.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local ChatController = {}

local function note(): string
	if Config.Chat.Proximity then
		return string.format("💬 Proximity chat: only mages within %d studs can hear you.", Config.Chat.Range)
	end
	return "💬 Chat reaches everyone in the server."
end

function ChatController.init()
	local ok, service = pcall(function()
		return game:GetService("TextChatService")
	end)
	if not ok or not service then
		return
	end
	local textChat = service :: TextChatService
	task.spawn(function()
		local bubbles = textChat:FindFirstChildOfClass("BubbleChatConfiguration")
		if bubbles and Config.Chat.Proximity then
			bubbles.MaxDistance = Config.Chat.Range
		end
		local channels = textChat:WaitForChild("TextChannels", 30)
		local general = channels and channels:WaitForChild("RBXGeneral", 30)
		if general and general:IsA("TextChannel") then
			pcall(function()
				general:DisplaySystemMessage(note())
			end)
		end
	end)
end

ChatController.note = note

return ChatController
