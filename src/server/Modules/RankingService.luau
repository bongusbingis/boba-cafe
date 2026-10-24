--!strict
--[[
	RankingService.luau
	Knit service and module utilizing Roblox Open Cloud API (v2) to set a user's
	role in the group associated with the authorized account / API key.

	- Reads the API key securely from Creator Hub Secrets via HttpService:GetSecret.
	- Validates rank to strictly allow values in range 6..10.
	- Queries roles from Open Cloud Groups v2, matches rank to role resource path.
	- Queries user membership to ensure the user is in the group and not already at the rank.
	- Updates membership via PATCH /cloud/v2/groups/{groupId}/memberships/{userId}.
	- Automatically invalidates RankUtil server cache for online players on success.
]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Knit = require(Packages.Knit)

local MIN_RANK = 6
local MAX_RANK = 10
local DEFAULT_GROUP_ID = 3174578
local DEFAULT_SECRET_NAME = "OPEN_CLOUD_API_KEY"
local ROLES_CACHE_TTL_SECONDS = 300

local FALLBACK_SECRET_NAMES = {
	DEFAULT_SECRET_NAME,
	"ROBLOX_OPEN_CLOUD_API_KEY",
	"RANKING_API_KEY",
	"OPENCLOUD_API_KEY",
}

export type RoleInfo = {
	path: string,
	id: string,
	displayName: string,
	rank: number,
	memberCount: number?,
}

export type CachedRoles = {
	timestamp: number,
	rolesByRank: { [number]: RoleInfo },
	rolesById: { [string]: RoleInfo },
	allRoles: { RoleInfo },
}

local RankingService = Knit.CreateService({
	Name = "RankingService",
	Client = {},
	MIN_RANK = MIN_RANK,
	MAX_RANK = MAX_RANK,
	_secretName = DEFAULT_SECRET_NAME,
	_customGroupId = nil :: number?,
	_rolesCache = {} :: { [number]: CachedRoles },
})

--- Dependency hooks for unit testing / offline specs.
function RankingService._getSecret(secretName: string): any
	return HttpService:GetSecret(secretName)
end

function RankingService._requestAsync(options: { [string]: any }): { [string]: any }
	return HttpService:RequestAsync(options)
end

--- Configures the secret key name to fetch from Creator Hub Secrets.
function RankingService:SetSecretName(secretName: string)
	assert(typeof(secretName) == "string" and #secretName > 0, "Secret name must be a non-empty string")
	self._secretName = secretName
end

--- Configures a custom default group ID.
function RankingService:SetGroupId(groupId: number)
	assert(typeof(groupId) == "number" and groupId > 0, "Group ID must be a positive integer")
	self._customGroupId = groupId
end

--- Resolves the effective Group ID to target.
function RankingService:GetTargetGroupId(overrideGroupId: number?): number
	if typeof(overrideGroupId) == "number" and overrideGroupId > 0 then
		return overrideGroupId
	end
	if typeof(self._customGroupId) == "number" and self._customGroupId > 0 then
		return self._customGroupId
	end
	if game.CreatorType == Enum.CreatorType.Group and game.CreatorId > 0 then
		return game.CreatorId
	end
	return DEFAULT_GROUP_ID
end

--- Resolves the Roblox Open Cloud Secret object.
function RankingService:_resolveSecret(): (any?, string?)
	local namesToTry = { self._secretName }
	for _, fallback in FALLBACK_SECRET_NAMES do
		if not table.find(namesToTry, fallback) then
			table.insert(namesToTry, fallback)
		end
	end

	for _, name in namesToTry do
		local ok, secret = pcall(function()
			return self._getSecret(name)
		end)
		if ok and secret ~= nil then
			return secret, nil
		end
	end

	return nil,
		string.format(
			"Open Cloud secret '%s' not found. Please create this secret in Creator Hub > Secrets.",
			self._secretName
		)
end

--- Validates whether a rank value is within the allowed 6..10 range.
function RankingService.IsValidRank(rank: any): boolean
	return typeof(rank) == "number" and rank >= MIN_RANK and rank <= MAX_RANK and math.floor(rank) == rank
end

--- Clears the cached group roles.
function RankingService:InvalidateRolesCache(groupId: number?)
	local targetGroupId = self:GetTargetGroupId(groupId)
	self._rolesCache[targetGroupId] = nil
end

--- Fetches all roles for a group from Open Cloud v2 and caches the result.
function RankingService:GetRolesAsync(overrideGroupId: number?): ({ [number]: RoleInfo }?, string?)
	local groupId = self:GetTargetGroupId(overrideGroupId)
	local cached = self._rolesCache[groupId]
	if cached and (os.time() - cached.timestamp) < ROLES_CACHE_TTL_SECONDS then
		return cached.rolesByRank, nil
	end

	local secret, secretErr = self:_resolveSecret()
	if not secret then
		return nil, secretErr
	end

	local url = string.format("https://apis.roblox.com/cloud/v2/groups/%d/roles?maxPageSize=100", groupId)
	local reqOk, response = pcall(function()
		return self._requestAsync({
			Url = url,
			Method = "GET",
			Headers = {
				["x-api-key"] = secret,
				["Content-Type"] = "application/json",
			},
		})
	end)

	if not reqOk then
		return nil, string.format("Failed to request group roles: %s", tostring(response))
	end

	if not response.Success then
		return nil,
			string.format("Open Cloud roles error (%d): %s", response.StatusCode, tostring(response.StatusMessage))
	end

	local decodeOk, decoded = pcall(function()
		return HttpService:JSONDecode(response.Body)
	end)

	if not decodeOk or typeof(decoded) ~= "table" or typeof(decoded.groupRoles) ~= "table" then
		return nil, "Failed to decode group roles response from Open Cloud"
	end

	local rolesByRank: { [number]: RoleInfo } = {}
	local rolesById: { [string]: RoleInfo } = {}
	local allRoles: { RoleInfo } = {}

	for _, roleData in decoded.groupRoles do
		if typeof(roleData) == "table" and typeof(roleData.rank) == "number" then
			local info: RoleInfo = {
				path = tostring(roleData.path),
				id = tostring(roleData.id),
				displayName = tostring(roleData.displayName or ""),
				rank = roleData.rank,
				memberCount = roleData.memberCount,
			}
			rolesByRank[info.rank] = info
			rolesById[info.id] = info
			table.insert(allRoles, info)
		end
	end

	self._rolesCache[groupId] = {
		timestamp = os.time(),
		rolesByRank = rolesByRank,
		rolesById = rolesById,
		allRoles = allRoles,
	}

	return rolesByRank, nil
end

--- Finds the Open Cloud role resource corresponding to a numeric rank.
function RankingService:GetRoleForRankAsync(rank: number, overrideGroupId: number?): (RoleInfo?, string?)
	if not self.IsValidRank(rank) then
		return nil,
			string.format(
				"Invalid rank %s. Rank must be an integer between %d and %d.",
				tostring(rank),
				MIN_RANK,
				MAX_RANK
			)
	end

	local rolesByRank, rolesErr = self:GetRolesAsync(overrideGroupId)
	if not rolesByRank then
		return nil, rolesErr
	end

	local targetRole = rolesByRank[rank]
	if not targetRole then
		local groupId = self:GetTargetGroupId(overrideGroupId)
		return nil, string.format("No group role found with rank %d in group %d", rank, groupId)
	end

	return targetRole, nil
end

--- Fetches the user's membership details in the target group.
function RankingService:GetMemberAsync(playerOrUserId: Player | number, overrideGroupId: number?): (any?, string?)
	local userId: number
	if typeof(playerOrUserId) == "Instance" and playerOrUserId:IsA("Player") then
		userId = playerOrUserId.UserId
	elseif
		typeof(playerOrUserId) == "number"
		and playerOrUserId > 0
		and math.floor(playerOrUserId) == playerOrUserId
	then
		userId = playerOrUserId
	else
		return nil, "Invalid playerOrUserId: expected Player instance or integer UserId"
	end

	local secret, secretErr = self:_resolveSecret()
	if not secret then
		return nil, secretErr
	end

	local groupId = self:GetTargetGroupId(overrideGroupId)
	local filterQuery = HttpService:UrlEncode(string.format("user == 'users/%d'", userId))
	local url = string.format("https://apis.roblox.com/cloud/v2/groups/%d/memberships?filter=%s", groupId, filterQuery)

	local reqOk, response = pcall(function()
		return self._requestAsync({
			Url = url,
			Method = "GET",
			Headers = {
				["x-api-key"] = secret,
				["Content-Type"] = "application/json",
			},
		})
	end)

	if not reqOk then
		return nil, string.format("Failed to query group membership: %s", tostring(response))
	end

	if not response.Success then
		return nil,
			string.format("Open Cloud membership error (%d): %s", response.StatusCode, tostring(response.StatusMessage))
	end

	local decodeOk, decoded = pcall(function()
		return HttpService:JSONDecode(response.Body)
	end)

	if not decodeOk or typeof(decoded) ~= "table" then
		return nil, "Failed to decode group membership response from Open Cloud"
	end

	local memberships = decoded.groupMemberships
	if typeof(memberships) ~= "table" or #memberships == 0 then
		return nil, string.format("User %d is not a member of group %d", userId, groupId)
	end

	return memberships[1], nil
end

--- Internal implementation of setting a user's rank.
function RankingService:_setRankInternalAsync(
	playerOrUserId: Player | number,
	rank: number,
	overrideGroupId: number?
): (boolean, string?)
	if not self.IsValidRank(rank) then
		return false,
			string.format(
				"Invalid rank %s. Allowed rank values are integers from %d to %d.",
				tostring(rank),
				MIN_RANK,
				MAX_RANK
			)
	end

	local userId: number
	local onlinePlayer: Player? = nil

	if typeof(playerOrUserId) == "Instance" and playerOrUserId:IsA("Player") then
		userId = playerOrUserId.UserId
		onlinePlayer = playerOrUserId
	elseif
		typeof(playerOrUserId) == "number"
		and playerOrUserId > 0
		and math.floor(playerOrUserId) == playerOrUserId
	then
		userId = playerOrUserId
		onlinePlayer = Players:GetPlayerByUserId(userId)
	else
		return false, "Invalid playerOrUserId: expected Player instance or integer UserId"
	end

	local groupId = self:GetTargetGroupId(overrideGroupId)

	local secret, secretErr = self:_resolveSecret()
	if not secret then
		return false, secretErr
	end

	-- 1. Resolve target role from Open Cloud
	local targetRole, roleErr = self:GetRoleForRankAsync(rank, groupId)
	if not targetRole then
		return false, roleErr or "Failed to resolve target role"
	end

	-- 2. Query user membership
	local membership, memberErr = self:GetMemberAsync(userId, groupId)
	if not membership then
		return false, memberErr or "User membership could not be verified"
	end

	-- Check if user is already at this role (prevents Open Cloud 400 Bad Request)
	if membership.role == targetRole.path then
		return true, string.format("User %d already has rank %d (%s).", userId, rank, targetRole.displayName)
	end

	-- 3. Execute PATCH request to update role
	local membershipPath = membership.path or string.format("groups/%d/memberships/%d", groupId, userId)
	local updateUrl = string.format("https://apis.roblox.com/cloud/v2/%s", membershipPath)

	local patchPayload = HttpService:JSONEncode({
		role = targetRole.path,
	})

	local reqOk, response = pcall(function()
		return self._requestAsync({
			Url = updateUrl,
			Method = "PATCH",
			Headers = {
				["x-api-key"] = secret,
				["Content-Type"] = "application/json",
			},
			Body = patchPayload,
		})
	end)

	if not reqOk then
		return false, string.format("Failed to send PATCH ranking request: %s", tostring(response))
	end

	if not response.Success then
		local detail = response.StatusMessage
		local decodeOk, errJson = pcall(function()
			return HttpService:JSONDecode(response.Body)
		end)
		if decodeOk and typeof(errJson) == "table" and errJson.message then
			detail = errJson.message
		end
		return false, string.format("Open Cloud ranking error (%d): %s", response.StatusCode, tostring(detail))
	end

	-- Invalidate RankUtil cache for player if currently in the server
	if onlinePlayer and onlinePlayer.Parent ~= nil then
		local ok, RankUtil = pcall(function()
			local Shared = ReplicatedStorage:WaitForChild("Shared")
			return require(Shared.Utility.RankUtil)
		end)
		if ok and RankUtil and typeof(RankUtil.InvalidateCache) == "function" then
			RankUtil:InvalidateCache(onlinePlayer)
		end
	end

	return true, string.format("Successfully set user %d to rank %d (%s).", userId, rank, targetRole.displayName)
end

--- Public method to set rank: supports both colon syntax RankingService:SetRankAsync(player, rank)
--- and dot syntax RankingService.SetRankAsync(player, rank).
function RankingService.SetRankAsync(
	selfOrTarget: any,
	targetOrRank: any,
	rankOrGroupId: any?,
	optionalGroupId: any?
): (boolean, string?)
	local target: Player | number
	local rank: number
	local groupId: number?

	if selfOrTarget == RankingService then
		target = targetOrRank
		rank = rankOrGroupId :: any
		groupId = optionalGroupId
	else
		target = selfOrTarget
		rank = targetOrRank
		groupId = rankOrGroupId :: any
	end

	return RankingService:_setRankInternalAsync(target, rank, groupId)
end

--- Alias for SetRankAsync.
function RankingService.SetRank(
	selfOrTarget: any,
	targetOrRank: any,
	rankOrGroupId: any?,
	optionalGroupId: any?
): (boolean, string?)
	return RankingService.SetRankAsync(selfOrTarget, targetOrRank, rankOrGroupId, optionalGroupId)
end

--- Callable table support: RankingService(player, rank, groupId)
local RankingMeta = {
	__call = function(_self: any, playerOrUserId: Player | number, rank: number, overrideGroupId: number?)
		return RankingService:_setRankInternalAsync(playerOrUserId, rank, overrideGroupId)
	end,
}

setmetatable(RankingService, RankingMeta)

return RankingService
