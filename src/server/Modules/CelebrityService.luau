--[[
    Module: CelebrityService
    Description: Celebrity membership and private islands.

    Membership is a subscription, so it is read from SubscriptionService rather than
    tracked here — see SubscriptionsConfig.Celebrity.

    Expected world layout (workspace.Assets.Celebrity):

        Celebrity
        ├── IslandTemplate   Model cloned once per celebrity
        ├── Spawns           Folder of BaseParts; each is one island plot
        └── Islands          Folder loaded islands are parented into (created if absent)

    Each loaded island is named "Island_<userId>" so it can be found again. A plot is
    released when its owner leaves or their subscription lapses.
--]]

---> services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

---> dependencies
local Packages = ReplicatedStorage:WaitForChild("Packages")

local Knit = require(Packages.Knit)

---> module declaration
local CelebrityService = Knit.CreateService({
    Name = "CelebrityService",
    Client = {
        --- Fired when a player's island is loaded or unloaded.
        IslandChanged = Knit.CreateSignal(),
    },
})

---> constants

local SUBSCRIPTION_NAME = "Celebrity"
local FOLDER_NAME = "Celebrity"
local ISLANDS_FOLDER = "Islands"
local SPAWNS_FOLDER = "Spawns"
local TEMPLATE_NAME = "IslandTemplate"

---> state

-- userId -> the plot part their island occupies.
local occupiedPlots: { [number]: BasePart } = {}
-- userId -> loaded island model.
local islands: { [number]: Model } = {}

---> private

local function getRoot(): Instance?
    local assets = workspace:FindFirstChild("Assets")
    return assets and assets:FindFirstChild(FOLDER_NAME)
end

local function getIslandsFolder(root: Instance): Folder
    local folder = root:FindFirstChild(ISLANDS_FOLDER)
    if folder then
        return folder :: Folder
    end

    local created = Instance.new("Folder")
    created.Name = ISLANDS_FOLDER
    created.Parent = root
    return created
end

--- First plot not currently occupied, or nil when the island area is full.
local function findFreePlot(root: Instance): BasePart?
    local spawns = root:FindFirstChild(SPAWNS_FOLDER)
    if not spawns then
        return nil
    end

    local taken = {}
    for _, plot in occupiedPlots do
        taken[plot] = true
    end

    for _, plot in spawns:GetChildren() do
        if plot:IsA("BasePart") and not taken[plot] then
            return plot
        end
    end

    return nil
end

---> public

--- Whether the player currently holds an active Celebrity subscription.
function CelebrityService:IsCelebrity(player: Player): boolean
    local subscriptionService = Knit.GetService("SubscriptionService")
    if not subscriptionService then
        return false
    end

    return subscriptionService:IsActive(player, SUBSCRIPTION_NAME)
end

--- Spawns the player's island on a free plot. Idempotent.
function CelebrityService:LoadIsland(player: Player): boolean
    if islands[player.UserId] then
        return true
    end

    local root = getRoot()
    if not root then
        return false
    end

    local template = root:FindFirstChild(TEMPLATE_NAME)
    if not template or not template:IsA("Model") then
        warn(`[CelebrityService] No {TEMPLATE_NAME} in workspace.Assets.{FOLDER_NAME}.`)
        return false
    end

    local plot = findFreePlot(root)
    if not plot then
        warn(`[CelebrityService] No free island plot for {player.Name}.`)
        return false
    end

    local island = template:Clone()
    island.Name = `Island_{player.UserId}`
    island:PivotTo(plot.CFrame)
    island.Parent = getIslandsFolder(root)

    -- Tagging the owner lets island-side scripts and prompts identify who it belongs to
    -- without a service lookup.
    island:SetAttribute("OwnerUserId", player.UserId)

    islands[player.UserId] = island
    occupiedPlots[player.UserId] = plot

    self.Client.IslandChanged:FireAll(player.UserId, true)
    return true
end

--- Despawns the player's island and frees its plot.
function CelebrityService:UnloadIsland(player: Player)
    local island = islands[player.UserId]
    if island then
        island:Destroy()
    end

    islands[player.UserId] = nil
    occupiedPlots[player.UserId] = nil

    self.Client.IslandChanged:FireAll(player.UserId, false)
end

--- The island model belonging to `userId`, if loaded.
function CelebrityService:GetIsland(userId: number): Model?
    return islands[userId]
end

--- Teleports `player` to `targetUserId`'s island. Returns (success, message).
function CelebrityService:VisitIsland(player: Player, targetUserId: number): (boolean, string)
    local island = islands[targetUserId]
    if not island then
        return false, "That island isn't loaded right now."
    end

    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not root then
        return false, "You need to be spawned in."
    end

    -- Land slightly above the island's pivot so the player does not clip into it.
    character:PivotTo(island:GetPivot() + Vector3.new(0, 5, 0))

    local target = Players:GetPlayerByUserId(targetUserId)
    if target and target ~= player then
        -- Meeting a celebrity is a tracked statistic.
        local statisticsService = Knit.GetService("StatisticsService")
        if statisticsService then
            statisticsService:IncrementStat(player, "CelebritiesMet", 1)
        end
    end

    return true, "Teleported!"
end

--- Claims the Roblox Premium trial for the Celebrity subscription.
function CelebrityService:ClaimPremiumTrial(player: Player): boolean
    local subscriptionService = Knit.GetService("SubscriptionService")
    if not subscriptionService then
        return false
    end

    local claimed = subscriptionService:ClaimPremiumTrial(player, SUBSCRIPTION_NAME)
    if claimed then
        self:LoadIsland(player)
    end

    return claimed
end

---> client

function CelebrityService.Client:IsCelebrity(player: Player): boolean
    return self.Server:IsCelebrity(player)
end

function CelebrityService.Client:VisitIsland(player: Player, targetUserId: number): (boolean, string)
    if typeof(targetUserId) ~= "number" then
        return false, "Invalid island."
    end

    return self.Server:VisitIsland(player, targetUserId)
end

--- Celebrities currently in the server with an island loaded, for the Island page.
function CelebrityService.Client:GetLoadedIslands(): { { UserId: number, Name: string } }
    local result = {}

    for userId in islands do
        local owner = Players:GetPlayerByUserId(userId)
        table.insert(result, {
            UserId = userId,
            Name = if owner then owner.DisplayName else tostring(userId),
        })
    end

    return result
end

function CelebrityService.Client:ClaimPremiumTrial(player: Player): boolean
    return self.Server:ClaimPremiumTrial(player)
end

---> lifecycle

function CelebrityService:PlayerAdded(player: Player)
    task.spawn(function()
        if self:IsCelebrity(player) then
            self:LoadIsland(player)
        end
    end)
end

function CelebrityService:PlayerRemoving(player: Player)
    self:UnloadIsland(player)
end

function CelebrityService:KnitStart()
    if not getRoot() then
        warn(`[CelebrityService] No workspace.Assets.{FOLDER_NAME} folder — islands disabled.`)
    end
end

return CelebrityService
