--!strict
--[[
	EventService.luau
	Knit service managing server-wide events, staff hosting, and automated scheduling
	(REVIVAL-001 M4-EVENTS, DEC-032).
]]

---> services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

---> dependencies
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Knit = require(Packages.Knit)
local EventConfig = require(Shared.Configuration.EventConfig)
local RankUtil = require(Shared.Utility.RankUtil)

---> types
export type ActiveEventStatus = {
	EventName: string?,
	TimeRemaining: number,
	HostCooldownRemaining: number,
}

export type EventService = typeof(Knit.CreateService({
	Name = "EventService",
	Client = {
		EventStarted = Knit.CreateSignal(),
		EventEnded = Knit.CreateSignal(),
	},
}))

---> service declaration
local EventService = Knit.CreateService({
	Name = "EventService",
	Client = {
		EventStarted = Knit.CreateSignal(),
		EventEnded = Knit.CreateSignal(),
	},
})

EventService._activeEvent = nil :: string?
EventService._activeEventDef = nil :: EventConfig.EventDefinition?
EventService._activeEventEndTime = 0 :: number
EventService._activeHost = nil :: Player?
EventService._hostCooldownEnd = 0 :: number
EventService._currentEventToken = nil :: any
EventService._nowOverride = nil :: (() -> number)?
EventService._rankOverride = nil :: ((Player) -> number)?
EventService._startingEvent = false :: boolean
EventService._playerStartDebounce = {} :: { [number]: number }

---> private
function EventService:_getService(name: string): any
	return Knit.GetService(name)
end

function EventService:_now(): number
	if self._nowOverride then
		return self._nowOverride()
	end
	return os.time()
end

function EventService:_getRank(player: Player): number
	if self._rankOverride then
		return self._rankOverride(player)
	end
	return RankUtil:GetRankAsync(player)
end

function EventService:_broadcastNotification(title: string, message: string)
	local ok, dialogService = pcall(function()
		return self:_getService("DialogService")
	end)
	if not ok or not dialogService or typeof(dialogService.Notify) ~= "function" then
		return
	end

	for _, player in Players:GetPlayers() do
		pcall(function()
			dialogService:Notify(
				player,
				{
					Title = title,
					Description = message,
					Text = title .. ": " .. message,
					Image = "",
				} :: any
			)
		end)
	end
end

function EventService:_endEvent(eventName: string, eventDef: EventConfig.EventDefinition)
	if self._activeEvent ~= eventName then
		return
	end

	self._activeEvent = nil
	self._activeEventDef = nil
	self._activeEventEndTime = 0
	self._activeHost = nil
	self._currentEventToken = nil
	self._hostCooldownEnd = self:_now() + EventConfig.HOST_COOLDOWN_SECONDS

	Workspace:SetAttribute(eventDef.Attribute, false)

	local endMessage = `{eventDef.Name} has ended!`
	self:_broadcastNotification(eventDef.Name, endMessage)
	self.Client.EventEnded:FireAll(eventName)
end

---> public
function EventService:GetActiveEvent(): ActiveEventStatus
	local now = self:_now()
	local hostCooldownRemaining = math.max(0, self._hostCooldownEnd - now)

	if self._activeEvent then
		local timeRemaining = math.max(0, self._activeEventEndTime - now)
		return {
			EventName = self._activeEvent,
			TimeRemaining = timeRemaining,
			HostCooldownRemaining = hostCooldownRemaining,
		}
	end

	return {
		EventName = nil,
		TimeRemaining = 0,
		HostCooldownRemaining = hostCooldownRemaining,
	}
end

function EventService:StartEvent(eventName: string, hostPlayer: Player?, durationOverride: number?): (boolean, string?)
	local eventDef = EventConfig.EVENTS[eventName]
	if not eventDef then
		return false, "Unknown event: " .. tostring(eventName)
	end

	if self._activeEvent ~= nil or self._startingEvent then
		return false, "An event is already active"
	end

	local now = self:_now()

	if hostPlayer ~= nil then
		if now < self._hostCooldownEnd then
			return false, "Host cooldown is active"
		end

		self._startingEvent = true
		local okRank, res = pcall(function()
			return self:_getRank(hostPlayer)
		end)
		self._startingEvent = false

		if self._activeEvent ~= nil then
			return false, "An event is already active"
		end

		local isAdmin = hostPlayer:GetAttribute("IsAdmin") == true
		local rank = 0
		if okRank and typeof(res) == "number" then
			rank = res
		end

		if not isAdmin and rank < EventConfig.MIN_STAFF_RANK then
			return false, "Insufficient rank to host an event"
		end
	end

	local duration = durationOverride or EventConfig.EVENT_DURATION_SECONDS
	self._activeEvent = eventName
	self._activeEventDef = eventDef
	self._activeEventEndTime = now + duration
	self._activeHost = hostPlayer

	Workspace:SetAttribute(eventDef.Attribute, true)

	local hostName = if hostPlayer then hostPlayer.DisplayName or hostPlayer.Name else ""
	local hostText = if hostPlayer then ` (Hosted by {hostName})` else ""
	local startMessage = `{eventDef.Name} has started! {eventDef.Description}{hostText}`
	self:_broadcastNotification(eventDef.Name, startMessage)
	self.Client.EventStarted:FireAll(eventName, self._activeEventEndTime)

	local currentEventToken = {}
	self._currentEventToken = currentEventToken

	task.delay(duration, function()
		if self._currentEventToken ~= currentEventToken then
			return
		end
		self:_endEvent(eventName, eventDef)
	end)

	return true, nil
end

function EventService:EndActiveEvent(): boolean
	if not self._activeEvent or not self._activeEventDef then
		return false
	end
	local eventName = self._activeEvent
	local eventDef = self._activeEventDef
	self._currentEventToken = nil
	self:_endEvent(eventName, eventDef)
	return true
end

function EventService:TriggerRandomEvent(): (boolean, string?)
	local keys = {}
	for key in EventConfig.EVENTS do
		table.insert(keys, key)
	end
	if #keys == 0 then
		return false, "No events configured"
	end
	table.sort(keys)
	local pickedKey = keys[math.random(1, #keys)]
	return self:StartEvent(pickedKey, nil)
end

---> client
function EventService.Client:StartEvent(player: Player, eventName: string): (boolean, string?)
	if typeof(eventName) ~= "string" or #eventName > 50 then
		return false, "Invalid event name"
	end

	local server = self.Server
	local now = server:_now()
	local lastAttempt = server._playerStartDebounce[player.UserId] or 0
	if now - lastAttempt < 5 then
		return false, "Please wait before attempting to host again"
	end
	server._playerStartDebounce[player.UserId] = now

	return server:StartEvent(eventName, player)
end

function EventService.Client:GetActiveEvent(_player: Player): ActiveEventStatus
	return self.Server:GetActiveEvent()
end

---> lifecycle
function EventService:PlayerRemoving(player: Player)
	self._playerStartDebounce[player.UserId] = nil
end

function EventService:KnitInit()
	for _, eventDef in EventConfig.EVENTS do
		if Workspace:GetAttribute(eventDef.Attribute) == nil then
			Workspace:SetAttribute(eventDef.Attribute, false)
		end
	end
end

function EventService:KnitStart()
	task.spawn(function()
		while true do
			task.wait(EventConfig.AUTO_EVENT_INTERVAL_SECONDS)
			if self._activeEvent == nil then
				self:TriggerRandomEvent()
			end
		end
	end)
end

return EventService
