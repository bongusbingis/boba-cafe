--!strict
--[[
    Module: ShiftService
    Description: Server-owned "clocked in" state. A clocked-in player works as a
                 barista (kitchen stations, claiming and queueing for orders); a
                 clocked-out player is a customer. Anyone may clock in or out at any
                 time. The state lives on the player as the `ClockedIn` attribute so
                 the client HUD and Teams.server.luau can read it.
--]]

---> services

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")

---> dependencies

local Knit = require(Packages.Knit)
local GoodSignal = require(Packages.GoodSignal)

---> types

export type SetClockedInResult = {
	Success: boolean,
	Message: string?,
}

---> constants

local CLOCKED_IN_ATTRIBUTE = "ClockedIn"
local DEFAULT_CLOCKED_IN = true -- new players start as baristas
local TOGGLE_COOLDOWN_SECONDS = 2

---> service

local ShiftService = Knit.CreateService({
	Name = "ShiftService",
	Client = {},

	-- Server-side signal: fires (player: Player, clockedIn: boolean) after a change.
	ClockedInChanged = GoodSignal.new(),

	_toggleDebounces = {} :: { [number]: boolean },
})

---> public

function ShiftService:IsClockedIn(player: Player): boolean
	return player:GetAttribute(CLOCKED_IN_ATTRIBUTE) == true
end

-- Server-authoritative setter. Does not rate-limit; use the Client method for
-- player requests.
function ShiftService:SetClockedIn(player: Player, clockedIn: boolean)
	if player:GetAttribute(CLOCKED_IN_ATTRIBUTE) == clockedIn then
		return
	end
	player:SetAttribute(CLOCKED_IN_ATTRIBUTE, clockedIn)
	self.ClockedInChanged:Fire(player, clockedIn)
end

---> client

function ShiftService.Client:SetClockedIn(player: Player, clockedIn: any): SetClockedInResult
	if typeof(clockedIn) ~= "boolean" then
		return { Success = false, Message = "Invalid request." }
	end

	local server = self.Server
	if server._toggleDebounces[player.UserId] then
		return { Success = false, Message = "Please wait before switching again." }
	end

	server._toggleDebounces[player.UserId] = true
	task.delay(TOGGLE_COOLDOWN_SECONDS, function()
		server._toggleDebounces[player.UserId] = nil
	end)

	server:SetClockedIn(player, clockedIn)
	return { Success = true, Message = if clockedIn then "Clocked in." else "Clocked out." }
end

---> lifecycle

function ShiftService:PlayerAdded(player: Player)
	-- Respect a value that is already set (for example by a Studio test).
	if player:GetAttribute(CLOCKED_IN_ATTRIBUTE) == nil then
		self:SetClockedIn(player, DEFAULT_CLOCKED_IN)
	end
end

function ShiftService:PlayerRemoving(player: Player)
	self._toggleDebounces[player.UserId] = nil
end

return ShiftService
