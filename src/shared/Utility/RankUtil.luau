--[[
    Author: bongusbingis
    Module: RankUtil.lua
    Created: 10/27/2024
    Updated: 04/05/2026

    A lightweight, server-cache-first rank utility module.
    Ranks and roles are eagerly pre-fetched on PlayerAdded to minimize
    latency on first access. All public async methods yield the calling
    thread and follow the *Async naming convention accordingly.

    Usage:
        local RankUtil = require(path.to.RankUtil)

        -- Eager pre-fetch happens automatically on PlayerAdded.
        -- Direct access (instant, no yield if already cached):
        local rankData = RankUtil:GetRankAndRoleAsync(player)

        -- Convenience rank-check functions (also yield if cache is cold):
        if RankUtil.IsHR(player) then ... end
--]]

---> services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

---> dependencies
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Promise = require(Packages:WaitForChild("Promise"))

---> types
type RankAndRole = {
	Rank: number,
	Role: string,
	LastFetched: number,
}

-- Each slot in the cache is either a resolved RankAndRole, or a pending
-- Promise that will resolve to one. This prevents stampedes where multiple
-- callers simultaneously request the same player's rank before the first
-- network round-trip has returned.
type CacheEntry = RankAndRole | typeof(Promise.new(function() end))

type GroupConfig = {
	GroupId: number,
}

---> module declaration
local RankUtil = {}

---> constants
local MAX_RETRIES: number = 3
local CACHE_TTL_SECONDS: number = 200 -- seconds before a re-fetch
local PREFETCH_TIMEOUT_SECONDS: number = 10 -- max wait for eager pre-fetch

local FALLBACK_RANK_AND_ROLE: RankAndRole = {
	Rank = 1,
	Role = "Customer",
	LastFetched = 0, -- 0 so the next request will attempt a re-fetch
}

local BOBA_CONFIG: GroupConfig = {
	GroupId = 3174578,
}

-- Cache
-- Key:   player.UserId  (number)
-- Value: RankAndRole    (resolved) OR Promise (pending)

local Cache: { [number]: CacheEntry } = {}

---> private

-- Returns true when a cache entry is a resolved RankAndRole table (not a Promise).
local function isResolved(entry: CacheEntry): boolean
	return type(entry) == "table" and entry.Rank ~= nil
end

-- Returns true when a resolved entry is still considered fresh.
local function isFresh(entry: RankAndRole): boolean
	return (os.time() - entry.LastFetched) < CACHE_TTL_SECONDS
end

-- Core fetch — wraps the two Roblox API calls in a retried Promise.
-- Returns Promise<RankAndRole>.
local function fetchRankAndRole(player: Player, config: GroupConfig)
	return Promise.retry(function()
		return Promise.new(function(resolve, reject)
			local ok, rankOrErr = pcall(function()
				return player:GetRankInGroupAsync(config.GroupId)
			end)
			if not ok then
				reject(rankOrErr)
				return
			end

			local ok2, roleOrErr = pcall(function()
				return player:GetRoleInGroupAsync(config.GroupId)
			end)
			if not ok2 then
				reject(roleOrErr)
				return
			end

			resolve({
				Rank = rankOrErr :: number,
				Role = roleOrErr :: string,
				LastFetched = os.time(),
			})
		end)
	end, MAX_RETRIES)
end

-- Ensures the cache for a player is warm, returning Promise<RankAndRole>.
-- If a fetch is already in-flight, the same Promise is returned (no stampede).
-- If the cache is fresh, resolves immediately with the cached value.
local function ensureCached(player: Player, config: GroupConfig)
	local entry = Cache[player.UserId]

	-- In-flight Promise — reuse it.
	if entry ~= nil and not isResolved(entry) then
		return entry
	end

	-- Fresh resolved entry — wrap in an already-resolved Promise.
	if entry ~= nil and isResolved(entry) and isFresh(entry :: RankAndRole) then
		return Promise.resolve(entry)
	end

	-- Stale or missing — start a new fetch and store the Promise immediately
	-- so concurrent callers share it rather than each firing their own request.
	local pending = fetchRankAndRole(player, config)
		:andThen(function(rankAndRole: RankAndRole)
			if player.Parent then
				Cache[player.UserId] = rankAndRole
				if rankAndRole.Rank > 10 then
					player:SetAttribute("IsAdmin", true)
				end
			end
			return rankAndRole
		end)
		:catch(function(...)
			warn(
				"[RankUtil] Failed to fetch rank — falling back to Customer.",
				player.Name,
				player.UserId,
				MAX_RETRIES,

				...
			)
			-- Do NOT cache the fallback; next call will retry.
			return FALLBACK_RANK_AND_ROLE
		end)

	Cache[player.UserId] = pending
	return pending
end

-- Eager pre-fetch on PlayerAdded
-- Fires the moment a player joins so the cache is warm before any script
-- downstream calls GetRankAndRoleAsync.
local function onPlayerAdded(player: Player)
	Promise.race({
		ensureCached(player, BOBA_CONFIG),
		Promise.delay(PREFETCH_TIMEOUT_SECONDS):andThen(function()
			return Promise.reject("prefetch timed out")
		end),
	}):catch(function(err)
		warn(string.format("[RankUtil] Pre-fetch timed out or failed for %s: %s", player.Name, tostring(err)))
	end)
end

for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end
Players.PlayerAdded:Connect(onPlayerAdded)

Players.PlayerRemoving:Connect(function(player: Player)
	Cache[player.UserId] = nil
end)

---> public

--- Yields until rank and role are available. Near-instant if cache is warm.
function RankUtil:GetRankAndRoleAsync(player: Player): RankAndRole
	local _, result = ensureCached(player, BOBA_CONFIG):await()
	return result :: RankAndRole
end

--- Yields until rank is available. Near-instant if cache is warm.
function RankUtil:GetRankAsync(player: Player): number
	return self:GetRankAndRoleAsync(player).Rank
end

--- Yields until role is available. Near-instant if cache is warm.
function RankUtil:GetRoleAsync(player: Player): string
	return self:GetRankAndRoleAsync(player).Role
end

--- Forces an immediate cache invalidation and re-fetch for a player.
--- Useful after a rank change event from an admin system.
function RankUtil:InvalidateCache(player: Player)
	Cache[player.UserId] = nil
	task.spawn(onPlayerAdded, player)
end

local function makeRankCheck(minRank: number, config: GroupConfig?)
	return function(self, player: Player): boolean
		local _, result = ensureCached(player or Players.LocalPlayer, config or BOBA_CONFIG):await()
		return (result :: RankAndRole).Rank >= minRank
	end
end

RankUtil.CanUseOrderingSystem = makeRankCheck(7)
RankUtil.CanEnterKitchen = makeRankCheck(8)
RankUtil.IsMR = makeRankCheck(11)
RankUtil.IsHR = makeRankCheck(16)
RankUtil.IsSHR = makeRankCheck(19)

return RankUtil
