--[[
    Author: bongusbingis
    Module: GamepassUtil.lua
    Created: 10/27/2024
    Updated: 04/06/2026

    Usage:
        local GamepassUtil = require(path.to.GamepassUtil)

        -- check ownership
        local owns = GamepassUtil:PlayerOwnsPassAsync(player, 12345678)
        local owns = GamepassUtil:PlayerOwnsPassAsync(player, "Faster Walk Speed")

        -- warm cache for all passes upfront
        GamepassUtil:PrefetchAllPassesAsync(player)

        -- server-only: grant pass without a purchase (e.g. after purchase callback)
        GamepassUtil:GrantPassToCache(player, 12345678)
--]]

-- Services
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Dependencies
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Promise = require(Packages:WaitForChild("Promise"))

---> gamepass defs
local Gamepasses: { [number]: GamepassDefinition } = require(Shared.Configuration.Gamepasses)

---> types
export type GamepassDefinition = {
	Name: string,
	Description: string,
	Icon: string,
}

---> per-player cache: maps passId -> ownership boolean or a pending promise
type PassOwnershipEntry = boolean | typeof(Promise.new(function() end))
type PlayerCache = { [number]: PassOwnershipEntry }

---> module declaration
local GamepassUtil = {}

---> constants
local MAX_RETRIES = 3
local STUDIO_PASSES_ENABLED = true
local _studioWarningPrinted = false

---> cache
-----> key: player.UserId (number)
-----> value: PlayerCache ({ [passId]: boolean | Promise })
local Cache: { [number]: PlayerCache } = {}

---> private
local function getOrCreatePlayerCache(userId: number): PlayerCache
	if not Cache[userId] then
		Cache[userId] = {}
	end
	return Cache[userId]
end

local function isResolved(entry: PassOwnershipEntry): boolean
	return type(entry) == "boolean"
end

local function fetchOwnership(player: Player, passId: number)
	return Promise.retry(function()
		return Promise.new(function(resolve, reject)
			local ok, result = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, passId)
			end)
			if ok then
				resolve(result)
			else
				reject(result)
			end
		end)
	end, MAX_RETRIES)
end

local function ensureCached(player: Player, passId: number)
	if RunService:IsStudio() and STUDIO_PASSES_ENABLED then
		if not _studioWarningPrinted then
			print("[GamepassUtil] STUDIO_PASSES_ENABLED is true — all passes resolve as owned")
			_studioWarningPrinted = true
		end
		return Promise.resolve(true)
	end

	local playerCache = getOrCreatePlayerCache(player.UserId)
	local entry = playerCache[passId]

	if entry ~= nil and not isResolved(entry) then
		return entry
	end

	if entry ~= nil and isResolved(entry) then
		return Promise.resolve(entry)
	end

	local pending = fetchOwnership(player, passId)
		:andThen(function(owns: boolean)
			if player.Parent then
				playerCache[passId] = owns
			end
			return owns
		end)
		:catch(function(err)
			warn(
				string.format(
					"[GamepassUtil] Failed to check pass %d for %s (%d) after %d retries — defaulting to false.",
					passId,
					player.Name,
					player.UserId,
					MAX_RETRIES
				),
				err
			)
			return false
		end)

	playerCache[passId] = pending
	return pending
end

local function resolvePassId(passIdOrName: number | string): number?
	if type(passIdOrName) == "number" then
		return Gamepasses[passIdOrName] and passIdOrName or nil
	end
	for passId, data in Gamepasses do
		if data.Name == passIdOrName then
			return passId
		end
	end
	return nil
end

Players.PlayerRemoving:Connect(function(player: Player)
	Cache[player.UserId] = nil
end)

---> public
function GamepassUtil:PlayerOwnsPassAsync(player: Player, passIdOrName: number | string): boolean
	local passId = resolvePassId(passIdOrName)
	if not passId then
		warn(string.format("[GamepassUtil] Unknown pass '%s' — returning false.", tostring(passIdOrName)))
		return false
	end

	local _, owns = ensureCached(player, passId):await()
	return owns == true
end

function GamepassUtil:PrefetchAllPassesAsync(player: Player)
	local fetches = {}
	for passId in Gamepasses do
		table.insert(fetches, ensureCached(player, passId))
	end
	return Promise.allSettled(fetches)
end

function GamepassUtil:GetPassData(passIdOrName: number | string): (GamepassDefinition?, number?)
	local passId = resolvePassId(passIdOrName)
	if not passId then
		return nil, nil
	end
	return Gamepasses[passId], passId
end

if RunService:IsServer() then
	function GamepassUtil:GrantPassToCache(player: Player, passId: number)
		local playerCache = getOrCreatePlayerCache(player.UserId)
		playerCache[passId] = true
	end
end

GamepassUtil.Gamepasses = Gamepasses

return GamepassUtil
