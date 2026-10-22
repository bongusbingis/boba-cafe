---> services
local BadgeService = game:GetService("BadgeService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

---> types
export type BadgeInfo = {
	Name: string,
	Description: string,
	IconImageId: number,
	IsEnabled: boolean,
}

---> modules
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Knit = require(Packages.Knit)
local RankUtil = require(Shared.Utility.RankUtil)
local Titles = require(Shared.Configuration.Titles)

---> variables
local Service = Knit.CreateService({ Name = "BadgeService", Client = {} })
Service.Badges = {
	Welcome = 2124469255,
	MetTheOwner = 2124491880,
	MetTheCoOwner = 2124640228,
	MetADeveloper = 2124640227,
	FirstQuest = 2124640229,
	FirstStaff = 2124640230,
	Celebrity = 2124640231,
	SakuraIsland = 2124640232,
	TreasureChest = 2124774045,
	ShinyPet = 2124774046,
	HalloweenEvent = 2124837610,
	Slipped = 2150110926,
	FirstPaycheck = 2150110897,
	LevelUp = 2150110948,
}

local LEGACY_BADGES = Titles.VETERAN_BADGES -- Defined in Titles.luau (DEC-035 Q3, DEC-037 Q12)
Service.LEGACY_BADGES = LEGACY_BADGES

local ClientAwardableBadges = {
	"Slipped",
}

local owners = {
	183587408, -- flezent
	454881159, -- amelia
	176353970, -- jack
}
local devs = {
	196806612, -- owen
	177424228, -- jimmy
	433630923, -- ollie
	58773791, -- poof
	3249046002, -- justin
}

local defaultBadgeInfo: BadgeInfo = { Name = "Unknown Name", Description = "", IconImageId = 0, IsEnabled = false }

local badgeOwnershipCache = {}
local badgeInfoCache = {}

---> functions
--[=[
    Awards a "Met" badge to everyone in the server.
]=]
function Service:_awardMetBadge(playerJoining: Player, metWho: string)
	if table.find(owners, playerJoining.UserId) or table.find(devs, playerJoining.UserId) then
		for _, p in Players:GetPlayers() do
			self:AwardBadgeByName(p, metWho)
		end
	else
		self:AwardBadgeByName(playerJoining, metWho)
	end
end

--[=[
    Checks if the owner (Flezent) is in the game.
]=]
function Service:_isOwnerInGame(): boolean
	return Players:GetPlayerByUserId(183587408) ~= nil
end

--[=[
    Checks if the co-owner (Amelia) is in the game.
]=]
function Service:_isCoOwnerInGame(): boolean
	return Players:GetPlayerByUserId(454881159) ~= nil
end

--[=[
    Checks if a developer is in the game.
]=]
function Service:_isDeveloperInGame(): boolean
	for _, v in devs do
		if Players:GetPlayerByUserId(v) ~= nil then
			return true
		end
	end
	return false
end

--[=[
    Checks whether a player has a badge, using cached data where possible.

    @yields
    @param player Player
    @param badgeId number
    @return boolean
]=]
function Service:PlayerHasBadgeAsync(player: Player, badgeId: number): boolean
	if not badgeOwnershipCache[player.UserId] then
		badgeOwnershipCache[player.UserId] = {}
	end

	if not badgeOwnershipCache[player.UserId][badgeId] then
		local success, result = pcall(function()
			return (self._badgeService or BadgeService):UserHasBadgeAsync(player.UserId, badgeId)
		end)
		if success then
			badgeOwnershipCache[player.UserId][badgeId] = result
		else
			return false
		end
	end

	return badgeOwnershipCache[player.UserId][badgeId]
end

--[=[
    Checks if a player owns any legacy badge from before the revival fresh start.
    If true, sets player attribute IsVeteran = true and returns true.

    @yields
    @param player Player
    @return boolean
]=]
function Service:CheckVeteranStatusAsync(player: Player): boolean
	if not player then
		return false
	end

	if player:GetAttribute("IsVeteran") == true then
		return true
	end

	local badgeService = self._badgeService or BadgeService
	local badgesToCheck = self.LEGACY_BADGES or LEGACY_BADGES
	for _, badgeId in badgesToCheck do
		local success, hasBadge = pcall(function()
			return badgeService:UserHasBadgeAsync(player.UserId, badgeId)
		end)

		if success and hasBadge == true then
			if player.UserId then
				if not badgeOwnershipCache[player.UserId] then
					badgeOwnershipCache[player.UserId] = {}
				end
				badgeOwnershipCache[player.UserId][badgeId] = true
			end
			player:SetAttribute("IsVeteran", true)
			pcall(function()
				local progressionService = Knit.GetService("ProgressionService")
				if progressionService and progressionService.GrantTitle then
					progressionService:GrantTitle(player, "Veteran")
				end
			end)
			return true
		end
	end

	return false
end

--[=[
    Checks whether a player has a badge , using cached data where possible.

    @param userId number
    @param badgeId number
    @return boolean
]=]
function Service:UserHasBadgeAsync(userId: number, badgeId: number): boolean
	local player = Players:GetPlayerByUserId(userId)
	if player then
		return self:PlayerHasBadgeAsync(player, badgeId)
	else
		return false
	end
end

--[=[
    Awards the given badge to the player, provided they don't own it already.

    @param player Player
    @param badgeId number
]=]
function Service:AwardBadge(player: Player, badgeId: number)
	if self:PlayerHasBadgeAsync(player, badgeId) then
		return
	end

	local success, err = pcall(function()
		BadgeService:AwardBadge(player.UserId, badgeId)
	end)
	if success then
		if not badgeOwnershipCache[player.UserId] then
			badgeOwnershipCache[player.UserId] = {}
		end
		badgeOwnershipCache[player.UserId][badgeId] = true
	else
		warn("[BadgeService] Failed to award badge", badgeId, "to", player.Name, err)
	end
end

--[=[
    Awards a badge by name (if it exists).

    @param player Player
    @param name string
]=]
function Service:AwardBadgeByName(player: Player, name: string)
	if self.Badges[name] then
		return self:AwardBadge(player, self.Badges[name])
	end

	error("Invalid badge: " .. name)
	return
end

--[=[
    Gets info about a given badge.

    @param badgeId number
]=]
function Service:GetBadgeInfoAsync(badgeId: number): BadgeInfo
	if not badgeInfoCache[badgeId] then
		local success, result = pcall(function()
			return BadgeService:GetBadgeInfoAsync(badgeId)
		end)
		if success then
			badgeInfoCache[badgeId] = result
		else
			return defaultBadgeInfo
		end
	end
	return badgeInfoCache[badgeId]
end

--[=[
    Requests to send the requested badge to the user.

    @param badgeName string
]=]

function Service.Client:AwardBadgeByName(player: Player, name: string)
	if not table.find(ClientAwardableBadges, name) then
		return
	end

	self.Server:AwardBadgeByName(player, name)
end

function Service:KnitStart()
	local function onPlayerAdded(player: Player)
		task.spawn(function()
			self:CheckVeteranStatusAsync(player)
		end)

		if RunService:IsStudio() then
			warn(`[{script.Name}]`, "- Not running BadgeService in Studio.")
			return
		end

		-- award welcome badge to everyone
		self:AwardBadgeByName(player, "Welcome")

		-- award met badges
		if self:_isOwnerInGame() then
			self:_awardMetBadge(player, "MetTheOwner")
		end
		if self:_isCoOwnerInGame() then
			self:_awardMetBadge(player, "MetTheCoOwner")
		end
		if self:_isDeveloperInGame() then
			self:_awardMetBadge(player, "MetADeveloper")
		end

		if RankUtil:CanUseOrderingSystem(player) then
			self:AwardBadgeByName(player, "FirstStaff")
		end
	end

	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
	Players.PlayerAdded:Connect(onPlayerAdded)

	Players.PlayerRemoving:Connect(function(player: Player)
		badgeOwnershipCache[player.UserId] = nil
	end)
end

return Service
