--!strict
--[[
	ModerationService.luau
	Knit service managing player moderation, bans, warnings, and action logs.
	Integrates with Roblox engine Ban API (Players:BanAsync / UnbanAsync)
	and DataService player profile action logs.
]]

---> services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

---> dependencies
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Knit = require(Packages.Knit)
local RankUtil = require(Shared.Utility.RankUtil)
local WorldPath = require(Shared.Utility.WorldPath)
local Zone = require(Packages.Zone)

---> types
export type ModerationActionType =
	"Permanent Ban"
	| "Temporary Ban"
	| "Kick"
	| "Warning"
	| "Timeout"
	| "Untimeout"
	| "Pet Name Reset"

export type BanStatus = {
	DisplayReason: string,
	PrivateReason: string,
	StartTime: string,
	Duration: number,
	Ban: boolean,
	PlaceId: number,
}

---> service declaration
---> timeout tuning (timeout command: bars clock-in and the kitchen, with a reason)
local TIMEOUT_MIN_MINUTES = 1
local TIMEOUT_MAX_MINUTES = 1440 -- 24 h
local TIMEOUT_CHECK_SECONDS = 2 -- fail-open profile read budget for the clock-in gate
local TIMEOUT_REGIONS_PATH = { "KitchenTimeoutRegions" } -- workspace folder of region parts
local TIMEOUT_SPAWN_PATH = { "Map", "SpawnLocation" } -- where timed-out players land
local TIMEOUT_DEFAULT_REASON = "Disrupting other players."

local ModerationService = Knit.CreateService({
	Name = "ModerationService",
	Client = {
		FlightSignal = Knit.CreateSignal(),
	},
	_timeouts = {} :: { [number]: any }, -- userId -> TimeoutData session cache
	_timeoutZones = {} :: { any }, -- held Zone handles for the kitchen regions
	_timeoutSpawn = nil :: BasePart?, -- resolved in KnitStart
})

---> private helpers
function ModerationService:_getEstTimestamp(timestamp: number?): number
	local base = timestamp or os.time()
	return base - 14400 -- 4 hours behind UTC (EST daylight savings / 18000 standard)
end

function ModerationService:_getFormattedTimeInEST(timestamp: number): string
	local date = os.date("!*t", timestamp)
	local identifier = (date.hour / 12) >= 1 and "PM" or "AM"
	local twelveHour = date.hour % 12
	if twelveHour == 0 then
		twelveHour = 12
	end
	local minStr = if date.min < 10 then "0" .. tostring(date.min) else tostring(date.min)

	return string.format("%d/%d/%d at %d:%s %s EST", date.month, date.day, date.year, twelveHour, minStr, identifier)
end

function ModerationService:_getPrivateReasonFromIssuer(issuedBy: string): string
	return string.format("Issued by [%s] on %s", issuedBy, self:_getFormattedTimeInEST(self:_getEstTimestamp()))
end

function ModerationService:_getCurrentUserBanStatus(userId: number): BanStatus?
	local success, pages = pcall(function()
		return Players:GetBanHistoryAsync(userId)
	end)
	if success and pages then
		local page = pages:GetCurrentPage()
		if page and #page > 0 then
			return page[1] :: BanStatus
		end
	end
	return nil
end

---> public methods
function ModerationService:CheckBanStatus(userId: number): (boolean, BanStatus?)
	local status = self:_getCurrentUserBanStatus(userId)
	if status then
		return status.Ban, status
	end
	return false, nil
end

function ModerationService:TrackModeration(
	player: Player,
	displayReason: string,
	issuedBy: string,
	typeOfModeration: ModerationActionType
)
	local DataService = Knit.GetService("DataService")
	DataService:GetDataAsync(player)
		:andThen(function(playerData: any)
			if not playerData then
				return
			end
			if not playerData.ActionLog then
				playerData.ActionLog = {}
			end
			table.insert(playerData.ActionLog, {
				Timestamp = self:_getEstTimestamp(os.time()),
				Reason = displayReason,
				IssuedBy = issuedBy,
				Type = typeOfModeration,
			})
		end)
		:catch(warn)
end

function ModerationService:BanAsync(
	userId: number,
	displayReason: string,
	issuedBy: string,
	durationInSeconds: number,
	applyToAlts: boolean?
): (boolean, string)
	local isBanned = self:CheckBanStatus(userId)
	if isBanned then
		return false, "This player is already banned."
	end

	local inGamePlayer = Players:GetPlayerByUserId(userId)
	if inGamePlayer then
		local modType: ModerationActionType = if durationInSeconds < 0 then "Permanent Ban" else "Temporary Ban"
		self:TrackModeration(inGamePlayer, displayReason, issuedBy, modType)
	end

	local banSuccess, banErr = pcall(function()
		Players:BanAsync({
			UserIds = { userId },
			Duration = durationInSeconds,
			DisplayReason = displayReason,
			PrivateReason = self:_getPrivateReasonFromIssuer(issuedBy),
			ExcludeAltAccounts = if applyToAlts == true then false else true,
		})
	end)

	if banSuccess then
		pcall(function()
			local LogService = Knit.GetService("LogService")
			LogService:AddAdminLog(
				issuedBy,
				if durationInSeconds < 0 then "Permanent Ban" else "Temporary Ban",
				string.format("Target: %d | Reason: %s", userId, displayReason)
			)
		end)
		return true, "Player was successfully banned."
	else
		warn("[ModerationService] BanAsync failed:", banErr)
		return false, tostring(banErr)
	end
end

function ModerationService:UnbanAsync(userId: number): (boolean, string)
	local isBanned = self:CheckBanStatus(userId)
	if not isBanned then
		return false, "This player has no active ban on their account."
	end

	local unbanSuccess, unbanErr = pcall(function()
		Players:UnbanAsync({
			UserIds = { userId },
			ApplyToUniverse = true,
		})
	end)

	if unbanSuccess then
		pcall(function()
			local LogService = Knit.GetService("LogService")
			LogService:AddAdminLog("Moderator", "Unban", string.format("Target: %d", userId))
		end)
		return true, "Player was successfully unbanned."
	else
		warn("[ModerationService] UnbanAsync failed:", unbanErr)
		return false, tostring(unbanErr)
	end
end

function ModerationService:GetActionLogAsync(userId: number): { any }
	local inGamePlayer = Players:GetPlayerByUserId(userId)
	if inGamePlayer then
		local DataService = Knit.GetService("DataService")
		local ok, playerData = pcall(function()
			local _, data = DataService:GetDataAsync(inGamePlayer):await()
			return data
		end)
		if ok and playerData and playerData.ActionLog then
			return playerData.ActionLog
		end
	end

	local DataService = Knit.GetService("DataService")
	local ok, offlineData = pcall(function()
		return DataService:ViewProfileAsync(userId)
	end)
	if ok and offlineData and offlineData.ActionLog then
		return offlineData.ActionLog
	end

	return {}
end

-- Pure: is this timeout record active right now? Returns (active, remainingSeconds).
function ModerationService.CheckTimeout(record: any, now: number): (boolean, number)
	if typeof(record) ~= "table" then
		return false, 0
	end
	local expiresAt = record.ExpiresAt
	if typeof(expiresAt) ~= "number" then
		return false, 0
	end
	local remaining = expiresAt - now
	if remaining <= 0 then
		return false, 0
	end
	return true, remaining
end

-- Player-facing denial line for a timeout record.
function ModerationService.TimeoutMessage(record: any, remainingSeconds: number): string
	local minutesLeft = math.max(1, math.ceil(remainingSeconds / 60))
	local reason = TIMEOUT_DEFAULT_REASON
	if typeof(record) == "table" and typeof(record.Reason) == "string" and record.Reason ~= "" then
		reason = record.Reason
	end
	return string.format("Timed out for %d more minute(s): %s", minutesLeft, reason)
end

-- Cache-first timeout check for the clock-in gate. Fails open when profiles are
-- unreachable; stale records are cleared on sight.
function ModerationService:IsTimedOut(player: Player): (boolean, string?)
	local cached = self._timeouts[player.UserId]
	local active, remaining = ModerationService.CheckTimeout(cached, os.time())
	if active then
		return true, ModerationService.TimeoutMessage(cached, remaining)
	end
	if cached ~= nil then
		self._timeouts[player.UserId] = nil
	end
	local ok, proxy = pcall(function()
		local success, data = Knit.GetService("DataService"):GetDataAsync(player):timeout(TIMEOUT_CHECK_SECONDS):await()
		return if success then data else nil
	end)
	if not ok or proxy == nil then
		return false, nil
	end
	local record = proxy.Timeout
	active, remaining = ModerationService.CheckTimeout(record, os.time())
	if not active then
		if typeof(record) == "table" then
			pcall(function()
				proxy:SetValue({ "Timeout" }, false)
			end)
		end
		return false, nil
	end
	self._timeouts[player.UserId] = record
	return true, ModerationService.TimeoutMessage(record, remaining)
end

-- Issues a profile-persisted timeout: no clock-in, no kitchen, for `minutes`.
function ModerationService:TimeoutAsync(
	userId: number,
	minutes: any,
	displayReason: string,
	issuedBy: string
): (boolean, string)
	local durationMinutes = if typeof(minutes) == "number" then math.floor(minutes) else 15
	if durationMinutes < TIMEOUT_MIN_MINUTES or durationMinutes > TIMEOUT_MAX_MINUTES then
		return false, "Minutes must be between 1 and 1440."
	end
	local target = Players:GetPlayerByUserId(userId)
	if target == nil then
		return false, "The player must be in the server to time out."
	end
	local ok, proxy = pcall(function()
		local success, data = Knit.GetService("DataService"):GetDataAsync(target):timeout(TIMEOUT_CHECK_SECONDS):await()
		return if success then data else nil
	end)
	if not ok or proxy == nil then
		return false, "Couldn't load that player's data. Try again."
	end
	local reason = displayReason
	if typeof(reason) ~= "string" or reason == "" then
		reason = TIMEOUT_DEFAULT_REASON
	end
	local now = os.time()
	local record = {
		Reason = reason,
		IssuedBy = issuedBy,
		IssuedAt = now,
		ExpiresAt = now + durationMinutes * 60,
	}
	local wrote = pcall(function()
		proxy:SetValue({ "Timeout" }, record)
	end)
	if not wrote then
		return false, "Couldn't save the timeout. Try again."
	end
	self._timeouts[userId] = record
	self:TrackModeration(target, reason, issuedBy, "Timeout")
	local logService = Knit.GetService("LogService")
	if logService ~= nil then
		pcall(function()
			logService:AddAdminLog(
				issuedBy,
				"Timeout",
				string.format("Target: %s (%d), %d min: %s", target.Name, userId, durationMinutes, reason)
			)
		end)
	end
	-- Clock out first so stations and prompts refuse immediately, then eject.
	local shiftService = Knit.GetService("ShiftService")
	if shiftService ~= nil and shiftService:IsClockedIn(target) then
		shiftService:SetClockedIn(target, false)
	end
	if not self:_ejectFromKitchen(target, record) then
		self:_notifyTimeout(target, record)
	end
	return true, string.format("%s timed out for %d minute(s).", target.Name, durationMinutes)
end

-- Lifts a timeout early. Expired records report as absent.
function ModerationService:LiftTimeout(userId: number, issuedBy: string): (boolean, string)
	local target = Players:GetPlayerByUserId(userId)
	if target == nil then
		return false, "The player must be in the server to untimeout."
	end
	local ok, proxy = pcall(function()
		local success, data = Knit.GetService("DataService"):GetDataAsync(target):timeout(TIMEOUT_CHECK_SECONDS):await()
		return if success then data else nil
	end)
	if not ok or proxy == nil then
		return false, "Couldn't load that player's data. Try again."
	end
	local record = proxy.Timeout
	local active = ModerationService.CheckTimeout(record, os.time())
	self._timeouts[userId] = nil
	if not active then
		if typeof(record) == "table" then
			pcall(function()
				proxy:SetValue({ "Timeout" }, false)
			end)
		end
		return false, "That player has no active timeout."
	end
	pcall(function()
		proxy:SetValue({ "Timeout" }, false)
	end)
	self:TrackModeration(target, "Timeout lifted early.", issuedBy, "Untimeout")
	local logService = Knit.GetService("LogService")
	if logService ~= nil then
		pcall(function()
			logService:AddAdminLog(issuedBy, "Untimeout", string.format("Target: %s (%d)", target.Name, userId))
		end)
	end
	self:_notifyTimeoutLifted(target)
	return true, string.format("%s is no longer timed out.", target.Name)
end

function ModerationService:_notifyTimeout(player: Player, record: any)
	local _, remaining = ModerationService.CheckTimeout(record, os.time())
	local dialogService = Knit.GetService("DialogService")
	if dialogService ~= nil then
		pcall(function()
			dialogService:Notify(player, { Text = ModerationService.TimeoutMessage(record, remaining) })
		end)
	end
end

function ModerationService:_notifyTimeoutLifted(player: Player)
	local dialogService = Knit.GetService("DialogService")
	if dialogService ~= nil then
		pcall(function()
			dialogService:Notify(player, { Text = "Your timeout was lifted. Please keep it fair." })
		end)
	end
end

function ModerationService:_kitchenRegionParts(): { BasePart }
	local folder = WorldPath.find(workspace, TIMEOUT_REGIONS_PATH)
	if folder == nil then
		return {}
	end
	local parts = {}
	for _, child in folder:GetChildren() do
		if child:IsA("BasePart") then
			table.insert(parts, child)
		end
	end
	return parts
end

function ModerationService:_pointInKitchen(position: Vector3): boolean
	for _, part in self:_kitchenRegionParts() do
		local localPoint = part.CFrame:PointToObjectSpace(position)
		local half = part.Size / 2
		if
			math.abs(localPoint.X) <= half.X
			and math.abs(localPoint.Y) <= half.Y
			and math.abs(localPoint.Z) <= half.Z
		then
			return true
		end
	end
	return false
end

-- Teleports a timed-out player standing in the kitchen to spawn. Returns teleported.
function ModerationService:_ejectFromKitchen(player: Player, record: any): boolean
	local character = player.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	if root == nil or not root:IsA("BasePart") then
		return false
	end
	if not self:_pointInKitchen(root.Position) then
		return false
	end
	local spawn = self._timeoutSpawn
	if spawn == nil then
		return false
	end
	character:PivotTo(spawn.CFrame + Vector3.new(0, 3, 0))
	self:_notifyTimeout(player, record)
	return true
end

function ModerationService:_watchKitchenTimeouts()
	local parts = self:_kitchenRegionParts()
	if #parts == 0 then
		-- KnitStart runs once, so a plain warn here fires once.
		warn(
			"[ModerationService] KitchenTimeoutRegions missing; timeout teleport-out disabled (clock-in block still enforced)."
		)
		return
	end
	local spawn = WorldPath.find(workspace, TIMEOUT_SPAWN_PATH)
	if spawn == nil or not spawn:IsA("BasePart") then
		warn(
			"[ModerationService] Map SpawnLocation missing; timeout teleport-out disabled (clock-in block still enforced)."
		)
		return
	end
	self._timeoutSpawn = spawn
	for _, part in parts do
		local zone = Zone.new(part)
		table.insert(self._timeoutZones, zone)
		zone.playerEntered:Connect(function(enteredPlayer: Player)
			task.spawn(function()
				local timedOut = self:IsTimedOut(enteredPlayer)
				if timedOut then
					local record = self._timeouts[enteredPlayer.UserId]
					if not self:_ejectFromKitchen(enteredPlayer, record) then
						self:_notifyTimeout(enteredPlayer, record)
					end
				end
			end)
		end)
	end
end

ModerationService._isServerLocked = false

function ModerationService:SetFlight(player: Player, enabled: boolean)
	self.Client.FlightSignal:Fire(player, enabled)
end

function ModerationService:SetServerLocked(locked: boolean)
	self._isServerLocked = locked
end

function ModerationService:IsServerLocked(): boolean
	return self._isServerLocked
end

function ModerationService:PlayerAdded(player: Player)
	if self._isServerLocked then
		if RunService:IsStudio() or player:GetAttribute("IsAdmin") == true then
			return
		end
		local ok, isMR = pcall(function()
			return RankUtil.IsMR(player)
		end)
		if not ok or not isMR then
			player:Kick("The server is locked.")
		end
	end
	-- Warm the timeout cache so the clock-in gate rarely yields.
	task.spawn(function()
		local ok, proxy = pcall(function()
			local success, data =
				Knit.GetService("DataService"):GetDataAsync(player):timeout(TIMEOUT_CHECK_SECONDS):await()
			return if success then data else nil
		end)
		if ok and proxy ~= nil then
			local active = ModerationService.CheckTimeout(proxy.Timeout, os.time())
			if active then
				self._timeouts[player.UserId] = proxy.Timeout
			end
		end
	end)
end

function ModerationService:KnitInit() end

function ModerationService:KnitStart()
	self:_watchKitchenTimeouts()
	print("[ModerationService] Initialized successfully.")
end

function ModerationService:PlayerRemoving(player: Player)
	self._timeouts[player.UserId] = nil
end

return ModerationService
