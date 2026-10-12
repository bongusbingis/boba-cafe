--[[
    Module: LeaderboardService
    Description: Drives the physical leaderboard displays in
    workspace.Assets.Leaderboards, backed by OrderedDataStores.

    See Shared.Configuration.LeaderboardConfig for the expected world layout and the
    board list. Monthly boards are namespaced by calendar month, so they roll over on
    their own without a reset job.

    Other services record progress through :Increment(); this service only reads and
    renders it.
--]]

---> services
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

---> dependencies
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Packages = ReplicatedStorage:WaitForChild("Packages")

local Knit = require(Packages.Knit)
local LeaderboardConfig = require(Shared.Configuration.LeaderboardConfig)

---> module declaration
local LeaderboardService = Knit.CreateService({
    Name = "LeaderboardService",
    Client = {
        --- Fired whenever a board's standings are re-read, so the client can re-render
        --- without polling.
        BoardUpdated = Knit.CreateSignal(),
    },
})

---> state

-- userId -> { Username, Icon }. Names and avatars change rarely and the lookups are
-- rate-limited, so this is cached for the life of the server.
local profileCache: { [number]: { Username: string, Icon: string } } = {}

-- Latest standings per board model. The client renders from this; the server never
-- touches board GUIs.
local boardData: { [Instance]: { Name: string, IsMonthly: boolean, Caption: string, Rows: { any } } } = {}

local leaderboardsFolder: Folder? = nil

--- Wraps a board's data with the model itself, so the client knows which board to
--- render onto.
local function makePayload(board: Instance)
    local data = boardData[board]
    if not data then
        return nil
    end

    return {
        Board = board,
        Caption = data.Caption,
        Rows = data.Rows,
    }
end

---> private

local function getFolder(): Folder?
    if leaderboardsFolder and leaderboardsFolder.Parent then
        return leaderboardsFolder
    end

    local assets = workspace:FindFirstChild("Assets")
    leaderboardsFolder = assets and assets:FindFirstChild(LeaderboardConfig.FOLDER_NAME) :: Folder?

    return leaderboardsFolder
end

--- Username and headshot for a user, with bounded retries. Returns nil when the lookup
--- keeps failing (deleted account, API outage) so the caller can skip that row rather
--- than stalling the whole refresh — V3 retried forever here.
local function getProfile(userId: number): { Username: string, Icon: string }?
    local cached = profileCache[userId]
    if cached then
        return cached
    end

    for attempt = 1, LeaderboardConfig.PROFILE_LOOKUP_RETRIES do
        local ok, username = pcall(function()
            return Players:GetNameFromUserIdAsync(userId)
        end)

        if ok then
            local iconOk, icon = pcall(function()
                return Players:GetUserThumbnailAsync(
                    userId,
                    Enum.ThumbnailType.HeadShot,
                    Enum.ThumbnailSize.Size100x100
                )
            end)

            local entry = {
                Username = username,
                Icon = iconOk and icon or "",
            }
            profileCache[userId] = entry
            return entry
        end

        if attempt < LeaderboardConfig.PROFILE_LOOKUP_RETRIES then
            task.wait(LeaderboardConfig.PROFILE_LOOKUP_DELAY)
        end
    end

    warn(string.format("[LeaderboardService] Could not resolve user %d — skipping row.", userId))
    return nil
end

--- Statues belonging to `board`, keyed by the rank they represent.
local function getStatues(board: Instance): { [number]: Model }
    local folder = getFolder()
    local statuesFolder = folder and folder:FindFirstChild("Statues")
    local result = {}

    if not statuesFolder then
        return result
    end

    for _, statue in statuesFolder:GetChildren() do
        local configuration = statue:FindFirstChild("Configuration")
        if not configuration then
            continue
        end

        local linked = configuration:FindFirstChild("Leaderboard")
        local position = configuration:FindFirstChild("Pos")

        if linked and position and (linked :: ObjectValue).Value == board then
            result[(position :: IntValue).Value] = statue :: Model
        end
    end

    return result
end

local function applyStatue(statue: Model, userId: number, username: string, isMonthly: boolean)
    local humanoid = statue:FindFirstChildWhichIsA("Humanoid")
    local configuration = statue:FindFirstChild("Configuration")

    if humanoid then
        pcall(function()
            humanoid:ApplyDescription(Players:GetHumanoidDescriptionFromUserId(userId))
        end)
    end

    local head = statue:FindFirstChild("Head")
    local overhead = head and head:FindFirstChild("Overhead")
    if not overhead then
        return
    end

    local nickname = overhead:FindFirstChild("Nickname")
    if nickname and nickname:IsA("TextLabel") then
        nickname.Text = username
    end

    local roleLabel = overhead:FindFirstChild("Role")
    local roleValue = configuration and configuration:FindFirstChild("Role")
    if roleLabel and roleLabel:IsA("TextLabel") and roleValue then
        local role = (roleValue :: StringValue).Value
        roleLabel.Text = if isMonthly then `{os.date("!%B %Y")} {role}` else role
    end
end

local function refreshBoard(board: Instance, isMonthly: boolean)
    local definition = LeaderboardConfig.Boards[board.Name]
    if not definition then
        -- A model in the folder with no matching config entry; nothing to show.
        return
    end

    local storeName = LeaderboardConfig.getStoreName(board.Name, isMonthly)
    if not storeName then
        return
    end

    local ok, pages = pcall(function()
        return DataStoreService:GetOrderedDataStore(storeName):GetSortedAsync(false, LeaderboardConfig.MAX_ENTRIES)
    end)

    if not ok then
        warn(string.format("[LeaderboardService] Failed to read '%s': %s", storeName, tostring(pages)))
        return
    end

    local statues = getStatues(board)
    local rows = {}

    for rank, entry in pages:GetCurrentPage() do
        local userId = tonumber(entry.key)
        -- V3 bailed out of the whole board on a negative key; skip the row instead.
        if not userId or userId <= 0 then
            continue
        end

        local profile = getProfile(userId)
        if not profile then
            continue
        end

        table.insert(rows, {
            Rank = rank,
            UserId = userId,
            Username = profile.Username,
            Icon = profile.Icon,
            Value = LeaderboardConfig.formatValue(board.Name, entry.value),
        })

        -- Statues are posed server-side: HumanoidDescription has to replicate.
        local statue = statues[rank]
        if statue then
            applyStatue(statue, userId, profile.Username, isMonthly)
        end
    end

    -- The rendered board is React on the client (see LeaderboardController); the server
    -- only publishes data. V3 cloned a hand-built row Template, but no board in the
    -- place file actually has one — Union has no SurfaceGui at all.
    boardData[board] = {
        Name = board.Name,
        IsMonthly = isMonthly,
        Caption = if isMonthly then string.upper(os.date("!%B %Y")) else "ALL TIME",
        Rows = rows,
    }

    LeaderboardService.Client.BoardUpdated:FireAll(makePayload(board))
end

local function refreshAll()
    local folder = getFolder()
    if not folder then
        return
    end

    for _, categoryName in { "Global", "Monthly" } do
        local category = folder:FindFirstChild(categoryName)
        if not category then
            continue
        end

        for _, board in category:GetChildren() do
            -- Each board is isolated: one malformed model must not stop the rest.
            local ok, err = pcall(refreshBoard, board, categoryName == "Monthly")
            if not ok then
                warn(string.format("[LeaderboardService] Board '%s' failed: %s", board.Name, tostring(err)))
            end
        end
    end
end

---> public

--- Adds `amount` to a player's standing on `boardName`. Call this from wherever the
--- underlying stat changes. Monthly and Global are both updated so the two stay in step.
function LeaderboardService:Increment(boardName: string, userId: number, amount: number)
    local definition = LeaderboardConfig.Boards[boardName]
    if not definition then
        warn(string.format("[LeaderboardService] Unknown board '%s'.", tostring(boardName)))
        return
    end

    if typeof(amount) ~= "number" or amount == 0 then
        return
    end

    for _, isMonthly in { false, true } do
        local storeName = LeaderboardConfig.getStoreName(boardName, isMonthly)
        if storeName then
            local ok, err = pcall(function()
                DataStoreService:GetOrderedDataStore(storeName):IncrementAsync(tostring(userId), amount)
            end)

            if not ok then
                warn(string.format("[LeaderboardService] Increment failed on '%s': %s", storeName, tostring(err)))
            end
        end
    end
end

---> client

--- Every board's current standings, for a client that just joined.
function LeaderboardService.Client:GetBoards()
    local payloads = {}

    for board in boardData do
        local payload = makePayload(board)
        if payload then
            table.insert(payloads, payload)
        end
    end

    return payloads
end

---> lifecycle

function LeaderboardService:KnitStart()
    if not getFolder() then
        warn(string.format(
            "[LeaderboardService] No workspace.Assets.%s folder — leaderboards disabled.",
            LeaderboardConfig.FOLDER_NAME
        ))
        return
    end

    task.spawn(function()
        while true do
            refreshAll()
            task.wait(LeaderboardConfig.REFRESH_INTERVAL)
        end
    end)
end

return LeaderboardService
