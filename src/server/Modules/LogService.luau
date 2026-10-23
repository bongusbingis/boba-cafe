--!strict
--[[
	LogService.luau
	Knit service capturing and managing server logs:
	- Admin logs (Cmdr commands and moderation actions)
	- Chat logs (in-game text messages)
	- Join logs (player join and leave events)
	Maintains a rolling ring buffer of up to 1500 records per log category,
	and provides methods for authorized staff to query and view them.
]]

---> services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")
local TextService = game:GetService("TextService")

---> dependencies
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Knit = require(Packages.Knit)
local RankUtil = require(Shared.Utility.RankUtil)

---> constants
local MAX_LOGS = 1500

---> types
export type LogEntry = {
	Timestamp: number,
	TimeFormatted: string,
	Author: string,
	UserId: number,
	Text: string,
	Category: string?,
}

---> service declaration
local LogService = Knit.CreateService({
	Name = "LogService",
	Client = {
		OpenLogsSignal = Knit.CreateSignal(),
	},
})

---> state
LogService._adminLogs = {} :: { LogEntry }
LogService._chatLogs = {} :: { LogEntry }
LogService._joinLogs = {} :: { LogEntry }
LogService._chatDedupe = {} :: { [string]: number }

---> private helpers
function LogService:_getEstTimestamp(timestamp: number?): number
	local base = timestamp or os.time()
	return base - 14400 -- EST daylight savings / UTC-4
end

function LogService:_formatEst(timestamp: number): string
	local date = os.date("!*t", timestamp)
	local twelveHour = date.hour % 12
	if twelveHour == 0 then
		twelveHour = 12
	end
	local identifier = if (date.hour / 12) >= 1 then "PM" else "AM"
	local minStr = if date.min < 10 then "0" .. tostring(date.min) else tostring(date.min)
	local secStr = if date.sec < 10 then "0" .. tostring(date.sec) else tostring(date.sec)

	return string.format("%d/%d %d:%s:%s %s", date.month, date.day, twelveHour, minStr, secStr, identifier)
end

function LogService:_pushLog(list: { LogEntry }, entry: LogEntry)
	-- Insert at front so newest logs appear first
	table.insert(list, 1, entry)
	if #list > MAX_LOGS then
		table.remove(list, #list)
	end
end

function LogService:_isAuthorized(player: Player): boolean
	if RunService:IsStudio() then
		return true
	end
	if player:GetAttribute("IsAdmin") == true then
		return true
	end
	local ok, isMR = pcall(function()
		return RankUtil.IsMR(player)
	end)
	return ok and isMR == true
end

---> public server methods
function LogService:AddAdminLog(executor: Player | string, action: string, details: string?)
	local authorName = if typeof(executor) == "Instance" and executor:IsA("Player")
		then executor.Name
		else tostring(executor)
	local userId = if typeof(executor) == "Instance" and executor:IsA("Player") then executor.UserId else 0
	local now = self:_getEstTimestamp(os.time())

	local fullText = if details and details ~= "" then string.format("%s (%s)", action, details) else action

	self:_pushLog(self._adminLogs, {
		Timestamp = now,
		TimeFormatted = self:_formatEst(now),
		Author = authorName,
		UserId = userId,
		Text = fullText,
		Category = "Admin",
	})
end

function LogService:AddChatLog(player: Player, message: string)
	if not message or message == "" then
		return
	end

	-- Simple dedupe in case both TextChatService and Chatted fire for the same message
	local dedupeKey = string.format("%d_%s", player.UserId, message)
	local nowClock = os.clock()
	if self._chatDedupe[dedupeKey] and (nowClock - self._chatDedupe[dedupeKey]) < 0.5 then
		return
	end
	self._chatDedupe[dedupeKey] = nowClock

	local now = self:_getEstTimestamp(os.time())
	self:_pushLog(self._chatLogs, {
		Timestamp = now,
		TimeFormatted = self:_formatEst(now),
		Author = player.Name,
		UserId = player.UserId,
		Text = message,
		Category = "Chat",
	})
end

function LogService:AddJoinLog(player: Player, action: "Joined" | "Left")
	local now = self:_getEstTimestamp(os.time())
	local ageText = if action == "Joined" then string.format("Account Age: %d days", player.AccountAge) else ""

	self:_pushLog(self._joinLogs, {
		Timestamp = now,
		TimeFormatted = self:_formatEst(now),
		Author = player.Name,
		UserId = player.UserId,
		Text = if ageText ~= "" then string.format("%s - %s", action, ageText) else action,
		Category = action,
	})
end

function LogService:GetLogs(player: Player, logType: string): { LogEntry }
	if not self:_isAuthorized(player) then
		return {}
	end

	local normalized = string.lower(logType or "admin")
	if normalized == "chat" or normalized == "chatlogs" then
		return self._chatLogs
	elseif normalized == "join" or normalized == "joinlogs" or normalized == "joins" then
		return self._joinLogs
	else
		return self._adminLogs
	end
end

function LogService:OpenLogsForPlayer(player: Player, defaultTab: string?)
	if not self:_isAuthorized(player) then
		return
	end
	self.Client.OpenLogsSignal:Fire(player, defaultTab or "Admin")
end

---> client methods
function LogService.Client:GetLogs(player: Player, logType: string): { LogEntry }
	return self.Server:GetLogs(player, logType)
end

function LogService.Client:OpenLogs(player: Player, defaultTab: string?)
	self.Server:OpenLogsForPlayer(player, defaultTab)
end

---> lifecycle
function LogService:PlayerAdded(player: Player)
	self:AddJoinLog(player, "Joined")
	player.Chatted:Connect(function(message: string)
		if RunService:IsStudio() then
			self:AddChatLog(player, message)
			return
		end
		task.spawn(function()
			local filterOk, filterResult = pcall(function()
				return TextService:FilterStringAsync(message, player.UserId)
			end)
			if filterOk and filterResult then
				local broadcastOk, filtered = pcall(function()
					return filterResult:GetNonChatStringForBroadcastAsync()
				end)
				if broadcastOk and typeof(filtered) == "string" and filtered ~= "" then
					self:AddChatLog(player, filtered)
				end
			end
		end)
	end)
end

function LogService:PlayerRemoving(player: Player)
	self:AddJoinLog(player, "Left")
end

function LogService:KnitInit()
	-- Connect TextChatService if enabled
	local ok, textChannels = pcall(function()
		return TextChatService:FindFirstChild("TextChannels")
	end)
	if ok and textChannels then
		local function hookChannel(channel: Instance)
			if channel:IsA("TextChannel") then
				channel.MessageReceived:Connect(function(msg: TextChatMessage)
					local source = msg.TextSource
					if source then
						local player = Players:GetPlayerByUserId(source.UserId)
						if player then
							local filtered = if msg.FilteredText and msg.FilteredText ~= ""
								then msg.FilteredText
								elseif RunService:IsStudio() then msg.Text
								else nil
							if filtered then
								self:AddChatLog(player, filtered)
							end
						end
					end
				end)
			end
		end

		for _, ch in textChannels:GetChildren() do
			hookChannel(ch)
		end
		textChannels.ChildAdded:Connect(hookChannel)
	end

	TextChatService.DescendantAdded:Connect(function(descendant: Instance)
		if descendant:IsA("TextChannel") then
			descendant.MessageReceived:Connect(function(msg: TextChatMessage)
				local source = msg.TextSource
				if source then
					local player = Players:GetPlayerByUserId(source.UserId)
					if player then
						local filtered = if msg.FilteredText and msg.FilteredText ~= ""
							then msg.FilteredText
							elseif RunService:IsStudio() then msg.Text
							else nil
						if filtered then
							self:AddChatLog(player, filtered)
						end
					end
				end
			end)
		end
	end)
end

function LogService:KnitStart()
	-- Periodically clean up old dedupe entries
	task.spawn(function()
		while true do
			task.wait(60)
			local now = os.clock()
			for k, timestamp in self._chatDedupe do
				if now - timestamp > 10 then
					self._chatDedupe[k] = nil
				end
			end
		end
	end)
	print("[LogService] Initialized successfully.")
end

return LogService
