--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Knit = require(Packages.Knit)

return function(context: any, text: string)
	local executor = context.Executor :: Player?
	local senderName = if executor then executor.DisplayName else "Server"
	local senderUserId = if executor then executor.UserId else 0

	local filteredText: string? = nil
	if senderUserId > 0 then
		local ok, result = pcall(function()
			local filterResult = TextService:FilterStringAsync(text, senderUserId)
			return filterResult:GetNonChatStringForBroadcastAsync()
		end)
		if ok and typeof(result) == "string" and result ~= "" then
			filteredText = result
		end
	else
		filteredText = text
	end

	if not filteredText then
		return "Failed to filter announcement message. Announcement was not broadcasted."
	end

	local DialogService = Knit.GetService("DialogService")
	for _, player in Players:GetPlayers() do
		task.spawn(function()
			pcall(function()
				DialogService:CreateDialog(player, "ButtonPrompt", {
					Title = "Server Announcement",
					Text = string.format("[%s]: %s", senderName, filteredText),
					Buttons = { { Text = "Okay" } },
				})
			end)
		end)
	end

	return string.format("Broadcasted server announcement to %d player(s).", #Players:GetPlayers())
end
