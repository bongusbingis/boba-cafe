--[[
    Module: QuestService
    Description: Daily quests. Four are assigned per player per UTC day, drawn one per
    slot from QuestConfig, and reroll once past their expiry.

    Other systems report progress with :AdvanceQuest(player, tracker, value). Completion,
    rewards and the badge are all decided here — nothing the client sends is trusted.

    The method keeps V3's name because OrderService was already written against it.

    Rollover and counting rules live in Shared.Utility.QuestUtil so they can be tested
    without a Roblox runtime.
--]]

---> services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

---> dependencies
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Packages = ReplicatedStorage:WaitForChild("Packages")

local Knit = require(Packages.Knit)
local QuestConfig = require(Shared.Configuration.QuestConfig)
local QuestUtil = require(Shared.Utility.QuestUtil)
local GamepassUtil = require(Shared.Utility.GamepassUtil)

---> module declaration
local QuestService = Knit.CreateService({
    Name = "QuestService",
    Client = {
        QuestCompleted = Knit.CreateSignal(),
        QuestsChanged = Knit.CreateSignal(),
    },
})

---> constants

-- How often accumulated play time is written, in seconds. PlayTime quests are stated in
-- minutes, so this ticks once a minute.
local PLAYTIME_TICK = 60

---> private

local function getData(player: Player)
    local ok, playerData = Knit.GetService("DataService"):GetDataAsync(player):await()
    if not ok then
        return nil
    end
    return playerData
end

--- Number of slots this player gets. The bonus slot is pass-gated when configured.
local function getSlotsFor(player: Player): { string }
    local slots = QuestConfig.SLOTS

    local passId = QuestConfig.BONUS_SLOT_PASS_ID
    if not passId then
        return slots
    end

    if GamepassUtil:PlayerOwnsPassAsync(player, passId) then
        return slots
    end

    -- Trim the bonus slot.
    local trimmed = table.clone(slots)
    table.remove(trimmed, QuestConfig.BONUS_SLOT_INDEX)
    return trimmed
end

--- Assigns a fresh set of quests and clears progress.
function QuestService:_rollQuests(player: Player, playerData)
    local quests = QuestUtil.rollQuests(QuestConfig.Quests, getSlotsFor(player), function(max)
        return math.random(1, max)
    end)

    playerData:SetValue({ "Quests", "Current" }, quests)
    playerData:SetValue({ "Quests", "Progress" }, {})
    playerData:SetValue({ "Quests", "Expires" }, QuestUtil.getNextExpiry(os.time()))

    self.Client.QuestsChanged:Fire(player, quests)
end

--- Rerolls if the assigned set has expired or is empty.
function QuestService:_ensureQuests(player: Player, playerData)
    local quests = playerData.Quests

    if QuestUtil.hasExpired(quests.Expires, os.time()) or #quests.Current == 0 then
        self:_rollQuests(player, playerData)
    end
end

--- Awards a completed quest. Marking Completed before paying out means a failure in
--- the reward path cannot be replayed for infinite currency.
function QuestService:_completeQuest(player: Player, playerData, index: number, definition)
    local current = playerData.Quests.Current
    local entry = current[index]

    if not entry or entry.Completed then
        return
    end

    entry.Completed = true
    playerData:SetValue({ "Quests", "Current" }, current)

    Knit.GetService("CurrencyService"):Modify(player, "BobaBucks", definition.Reward)

    local badgeService = Knit.GetService("BadgeService")
    if badgeService and QuestConfig.COMPLETION_BADGE_ID then
        pcall(function()
            badgeService:AwardBadge(player, QuestConfig.COMPLETION_BADGE_ID)
        end)
    end

    Knit.GetService("DialogService"):Notify(player, {
        Title = "Quest Complete!",
        Description = `You earned {definition.Reward} Boba Bucks for "{definition.Text}".`,
        Image = "",
    })

    self.Client.QuestCompleted:Fire(player, {
        Id = definition.Id,
        Text = definition.Text,
        Reward = definition.Reward,
    })
end

---> public

--- Reports progress on `tracker`. `value` is a number for Sum trackers, or a unique
--- string id for Unique trackers. Ignored when no active quest watches that tracker.
function QuestService:AdvanceQuest(player: Player, tracker: string, value: number | string)
    local mode = QuestConfig.TRACKERS[tracker]
    if not mode then
        warn(string.format("[QuestService] Unknown tracker '%s'.", tostring(tracker)))
        return
    end

    local playerData = getData(player)
    if not playerData then
        return
    end

    self:_ensureQuests(player, playerData)

    local current = playerData.Quests.Current

    -- Skip the write entirely when nothing active cares about this tracker.
    local watched = false
    for _, entry in current do
        local definition = QuestConfig.getById(entry.Id)
        if definition and definition.Tracker == tracker and not entry.Completed then
            watched = true
            break
        end
    end

    if not watched then
        return
    end

    local progress = QuestUtil.applyProgress(playerData.Quests.Progress, tracker, mode, value)
    playerData:SetValue({ "Quests", "Progress" }, progress)

    for index, entry in current do
        if entry.Completed then
            continue
        end

        local definition = QuestConfig.getById(entry.Id)
        if definition and QuestUtil.isComplete(progress, definition.Tracker, definition.Goal) then
            self:_completeQuest(player, playerData, index, definition)
        end
    end
end

--- The player's quests with progress folded in, for the Quests page.
function QuestService:GetQuests(player: Player)
    local playerData = getData(player)
    if not playerData then
        return {}
    end

    self:_ensureQuests(player, playerData)

    local result = {}
    for _, entry in playerData.Quests.Current do
        local definition = QuestConfig.getById(entry.Id)
        if not definition then
            continue
        end

        table.insert(result, {
            Id = entry.Id,
            Tier = entry.Tier,
            Text = definition.Text,
            Goal = definition.Goal,
            Reward = definition.Reward,
            Completed = entry.Completed,
            Progress = math.min(
                QuestUtil.getProgress(playerData.Quests.Progress, definition.Tracker),
                definition.Goal
            ),
        })
    end

    return {
        Quests = result,
        Expires = playerData.Quests.Expires,
    }
end

---> client

function QuestService.Client:GetQuests(player: Player)
    return self.Server:GetQuests(player)
end

---> lifecycle

function QuestService:PlayerAdded(player: Player)
    task.spawn(function()
        local playerData = getData(player)
        if not playerData then
            return
        end

        self:_ensureQuests(player, playerData)

        -- Friend quests: credit both directions for everyone already in the server.
        local ok, friendPages = pcall(function()
            return Players:GetFriendsAsync(player.UserId)
        end)

        if not ok then
            return
        end

        local friendIds = {}
        local scanning = true
        while scanning do
            for _, friend in friendPages:GetCurrentPage() do
                friendIds[friend.Id] = true
            end
            if friendPages.IsFinished then
                scanning = false
            else
                local advanced = pcall(function()
                    friendPages:AdvanceToNextPageAsync()
                end)
                if not advanced then
                    scanning = false
                end
            end
        end

        for _, other in Players:GetPlayers() do
            if other ~= player and friendIds[other.UserId] then
                self:AdvanceQuest(player, "FriendJoined", tostring(other.UserId))
                self:AdvanceQuest(other, "FriendJoined", tostring(player.UserId))
            end
        end
    end)

    -- Play time accrues while the player is in the server.
    task.spawn(function()
        while player.Parent == Players do
            task.wait(PLAYTIME_TICK)
            if player.Parent ~= Players then
                break
            end
            self:AdvanceQuest(player, "PlayTime", 1)
        end
    end)
end

return QuestService
