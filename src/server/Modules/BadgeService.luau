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
local Knit = require(Packages.Knit)

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
    LevelUp = 2150110948
}

local ClientAwardableBadges = {
    "Slipped"
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
        for _,p in Players:GetPlayers() do
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
    for _,v in devs do
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
            return BadgeService:UserHasBadgeAsync(player.UserId, badgeId)
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
    if not self:PlayerHasBadgeAsync(player) then
        BadgeService:AwardBadge(player.UserId, badgeId)
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
    Players.PlayerAdded:Connect(function(player: Player)
        if RunService:IsStudio() then 
            warn(`[{script.Name}]`,"- Not running BadgeService in Studio.")
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

        -- if player is a staff member, attempt to award the first staff badge
        Knit.Shared.RankManager:IsCashier(player):andThen(function(isCashier: boolean)
            if isCashier then
                self:AwardBadgeByName(player, "FirstStaff")
            end
        end)
        Knit.Shared.RankManager:IsBarista(player):andThen(function(isBarista: boolean)
            if isBarista then
                self:AwardBadgeByName(player, "FirstStaff")
            end
        end)
    end)

    Players.PlayerRemoving:Connect(function(player: Player)
        badgeOwnershipCache[player.UserId] = nil
    end)
end

return Service