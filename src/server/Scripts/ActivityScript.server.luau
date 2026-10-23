local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RankUtil = require(ReplicatedStorage.Shared.Utility.RankUtil)

-- Secrets stored in Roblox Open Cloud (Creator Dashboard -> Settings -> Secrets).
local WEB_APP_URL_SECRET = "ACTIVITY_WEBHOOK_URL"
local SECRET_KEY_SECRET = "ACTIVITY_SECRET"

local function getSecret(name: string): Secret?
	local ok, secret = pcall(function()
		return HttpService:GetSecret(name)
	end)
	return if ok and secret ~= nil then secret else nil
end

-- Players recorded as middle-rank+ staff at join, keyed by UserId.
local TrackedStaff = {}

local function sendEvent(player, action)
	local url = getSecret(WEB_APP_URL_SECRET)
	if not url then
		return
	end

	local authSecret = getSecret(SECRET_KEY_SECRET)
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
