--[[
    Module: ActivityService
    Description: Tracks how long staff are actively in the server and feeds the
    "Most Active" leaderboard.

    Playtime for the Statistics page is already accumulated by DataService on
    PlayerRemoving; this service covers the staff-activity half only.

    V3 also posted a session summary to a Discord webhook via WebhookProxy. That is cut
    from scope — and the V3 source had the webhook URL, including its token, hardcoded
    in the module. It is deliberately not reproduced here.
--]]

---> services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

---> dependencies
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Packages = ReplicatedStorage:WaitForChild("Packages")

local Knit = require(Packages.Knit)
local RankUtil = require(Shared.Utility.RankUtil)

---> module declaration
local ActivityService = Knit.CreateService({
    Name = "ActivityService",
})

---> constants

--- Minimum rank counted as staff for activity purposes (Barista and above).
local MIN_ACTIVITY_RANK = 8

--- Seconds without input before a player is treated as idle.
local AFK_THRESHOLD = 300

--- Board that receives accumulated active minutes.
local ACTIVITY_BOARD = "Most Active"

---> state

type Session = {
    JoinedAt: number,
    AfkSeconds: number,
    LastActive: number,
    IsStaff: boolean,
}

local sessions: { [number]: Session } = {}

---> private

--- Active seconds for a session, excluding idle time.
local function getActiveSeconds(session: Session): number
    local total = os.time() - session.JoinedAt
    return math.max(0, total - session.AfkSeconds)
end

local function finishSession(player: Player)
    local session = sessions[player.UserId]
    if not session then
        return
    end
    sessions[player.UserId] = nil

    if not session.IsStaff then
        return
    end

    local activeMinutes = math.floor(getActiveSeconds(session) / 60)
    if activeMinutes <= 0 then
        return
    end

    -- The leaderboard stores seconds so it can format as hours/minutes.
    local leaderboardService = Knit.GetService("LeaderboardService")
    if leaderboardService then
        leaderboardService:Increment(ACTIVITY_BOARD, player.UserId, activeMinutes * 60)
    end
end

---> public

--- Active seconds so far this session, or 0 if untracked.
function ActivityService:GetActiveSeconds(player: Player): number
    local session = sessions[player.UserId]
    return if session then getActiveSeconds(session) else 0
end

--- Marks a player as having just done something, ending any idle stretch.
function ActivityService:MarkActive(player: Player)
    local session = sessions[player.UserId]
    if not session then
        return
    end

    local idleFor = os.time() - session.LastActive
    if idleFor >= AFK_THRESHOLD then
        session.AfkSeconds += idleFor
    end

    session.LastActive = os.time()
end

---> client

--[=[
    Reports idle time observed on the client, since Player.Idled is LocalScript-only.

    `seconds` is clamped: a client could otherwise claim an enormous idle stretch and
    zero out its own activity, or send a negative value to inflate it.
]=]
function ActivityService.Client:ReportIdle(player: Player, seconds: number)
    if typeof(seconds) ~= "number" or seconds ~= seconds then
        return
    end

    local session = sessions[player.UserId]
    if not session then
        return
    end

    local elapsed = os.time() - session.JoinedAt
    local claimed = math.clamp(math.floor(seconds), 0, elapsed)

    -- Never let reported idle exceed the session itself.
    session.AfkSeconds = math.min(elapsed, session.AfkSeconds + claimed)
    session.LastActive = os.time()
end

---> lifecycle

function ActivityService:PlayerAdded(player: Player)
    local now = os.time()

    -- Record the session immediately so nothing is lost while the rank lookup yields.
    sessions[player.UserId] = {
        JoinedAt = now,
        AfkSeconds = 0,
        LastActive = now,
        IsStaff = false,
    }

    task.spawn(function()
        local isStaff = RankUtil:GetRankAsync(player) >= MIN_ACTIVITY_RANK

        local session = sessions[player.UserId]
        if session then
            session.IsStaff = isStaff
        end
    end)

    -- No idle hook here: Player.Idled only fires in a LocalScript for the LocalPlayer,
    -- so it cannot be connected server-side. AFK time is accumulated through
    -- :MarkActive and :ReportIdle instead.
end

function ActivityService:PlayerRemoving(player: Player)
    finishSession(player)
end

function ActivityService:KnitStart()
    -- Flush sessions on shutdown so a server closing does not discard staff activity.
    game:BindToClose(function()
        for _, player in Players:GetPlayers() do
            finishSession(player)
        end
    end)
end

return ActivityService
