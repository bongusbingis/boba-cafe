--!strict
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local mainPath = RunService:IsStudio() and "/api" or "/roblox"
local rankingService = {}
rankingService.__index = rankingService

local host: string
local gameKey: any
local pendingUsers: { [number]: boolean } = {}
local rateLimit: { [string]: number } = {}

local function makeRequest(path: string, method: string, data: any?)
	local url = string.format("%s%s%s", host, mainPath, path)
	local headers: { [string]: any } = { authorization = gameKey }
	local body: string? = nil
	local urlRateLimit = rateLimit[url]

	if urlRateLimit and urlRateLimit > 0 then
		local diff = urlRateLimit - os.time()
		if diff > 0 then
			task.wait(diff)
		end
	end

	if method == "POST" then
		headers["Content-Type"] = "application/json"
		body = HttpService:JSONEncode(data or {})
	end

	local reqSuccess, response = pcall(function()
		return HttpService:RequestAsync({
			Url = url,
			Method = method,
			Headers = headers,
			Body = body,
		})
	end)

	if not reqSuccess then
		warn(`[{script.Name}]`, "- Ranking Network Error: ", response)
		return { error = tostring(response) }
	end

	rateLimit[url] = nil

	local retryAfter = response.Headers and (response.Headers["retry-after"] or response.Headers["Retry-After"])
	if retryAfter then
		local waitSeconds = tonumber(retryAfter) or 5
		urlRateLimit = os.time() + waitSeconds
		rateLimit[url] = urlRateLimit
		task.wait(waitSeconds)

		return makeRequest(path, method, data)
	end

	local decodedBody = nil
	local _, err = pcall(function()
		decodedBody = HttpService:JSONDecode(response.Body)
	end)

	if err then
		warn(`[{script.Name}]`, "- Ranking Error: ", response.Body, err)
		return { error = string.format("Failed to decode response: %s", tostring(response.Body)) }
	else
		if decodedBody and decodedBody.error then
			warn(`[{script.Name}]`, "- Ranking Error: ", decodedBody.error, data)
		end
	end

	return decodedBody
end

function rankingService.setRank(groupId: number, userId: number, rank: number)
	if pendingUsers[userId] then
		return { error = "User is pending a response." }
	end

	pendingUsers[userId] = true
	local response = makeRequest("/setRank", "POST", { groupId = groupId, userId = userId, rank = rank })
	pendingUsers[userId] = false

	return response
end

function rankingService.handleJoinRequest(groupId: number, userId: number, accept: boolean)
	if pendingUsers[userId] then
		return { error = "User is pending a response." }
	end

	pendingUsers[userId] = true
	local response = makeRequest("/handleJoinRequest", "POST", { groupId = groupId, userId = userId, accept = accept })
	pendingUsers[userId] = false

	return response
end

function rankingService.exile(groupId: number, userId: number)
	if pendingUsers[userId] then
		return { error = "User is pending a response." }
	end

	pendingUsers[userId] = true
	local response = makeRequest("/exile", "POST", { groupId = groupId, userId = userId })
	pendingUsers[userId] = false

	return response
end

function rankingService.shout(groupId: number, message: string)
	return makeRequest("/shout", "POST", { groupId = groupId, message = message })
end

return function(initGameKey: any, initHost: string?)
	gameKey = initGameKey
	host = initHost or "https://apibeta.rankingservice.xyz"

	return rankingService
end
