local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RankUtil = require(ReplicatedStorage.Shared.Utility.RankUtil)

-- Players recorded as middle-rank+ staff at join, keyed by UserId.
local TrackedStaff = {}

local function sendEvent(player, action)
	local url =
		"https://script.google.com/macros/s/AKfycbwUcq1gnY4QkogsfVj9P0VCZeDu7rKTK_UDhPCELJG0Xk3hZiM_QQlfteDBaOu5WVRO/exec"
	local authSecret = "0d82fcd9-164d-4d50-aab7-03aa9fcde6cb"
	local payload = {
		username = player.Name,
		uid = tostring(player.UserId),
		action = action,
	}

	task.spawn(function()
		local ok, result = pcall(function()
			local headers: { [string]: any } = {
				["Content-Type"] = "application/json",
			}
			if authSecret then
				headers["X-Activity-Secret"] = authSecret
			end
			return HttpService:RequestAsync({
				Url = url,
				Method = "POST",
				Headers = headers,
				Body = HttpService:JSONEncode(payload),
			})
		end)

		if not ok then
			warn("Mod tracker failed:", player.Name, result)
		end
	end)
end

Players.PlayerAdded:Connect(function(player)
	task.spawn(function()
		local ok, isMR = pcall(RankUtil.IsMR, player)
		if not ok or not isMR then
			return
		end
		-- Player may have left while the rank fetch was yielding.
		if not player.Parent then
			return
		end
		TrackedStaff[player.UserId] = true
		sendEvent(player, "join")
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	if TrackedStaff[player.UserId] then
		TrackedStaff[player.UserId] = nil
		sendEvent(player, "leave")
	end
end)
