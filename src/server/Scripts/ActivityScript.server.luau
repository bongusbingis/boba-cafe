local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

local WEB_APP_URL =
	"https://script.google.com/macros/s/AKfycbwUcq1gnY4QkogsfVj9P0VCZeDu7rKTK_UDhPCELJG0Xk3hZiM_QQlfteDBaOu5WVRO/exec"
local SECRET = "0d82fcd9-164d-4d50-aab7-03aa9fcde6cb"

-- Replace these example IDs with your actual moderator IDs.
local MODERATORS = {
	[123456789] = true,
	[987654321] = true,
}

local function sendEvent(player, action)
	local payload = {
		secret = SECRET,
		username = player.Name,
		uid = tostring(player.UserId),
		action = action,
	}

	task.spawn(function()
		local ok, result = pcall(function()
			return HttpService:RequestAsync({
				Url = WEB_APP_URL,
				Method = "POST",
				Headers = {
					["Content-Type"] = "application/json",
				},
				Body = HttpService:JSONEncode(payload),
			})
		end)

		if not ok then
			warn("Mod tracker failed:", player.Name, result)
		end
	end)
end

Players.PlayerAdded:Connect(function(player)
	--if MODERATORS[player.UserId] then
	sendEvent(player, "join")
	--end
end)

Players.PlayerRemoving:Connect(function(player)
	--if MODERATORS[player.UserId] then
	sendEvent(player, "leave")
	--end
end)
