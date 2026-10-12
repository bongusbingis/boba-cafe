--[[
    Module: LeaderboardConfig
    Description: Physical leaderboard boards and the OrderedDataStores behind them.

    Expected world layout (workspace.Assets.Leaderboards):

        Leaderboards
        ├── Global          all-time boards
        │   └── <Board>     Model named exactly as a Boards entry below
        ├── Monthly         boards that reset each calendar month
        │   └── <Board>
        └── Statues         podium statues, linked to a board by Configuration values

    Each board Model must contain:
        Union.SurfaceGui.Frame.ScrollingFrame.Template   invisible row template, cloned per rank
        Part.SurfaceGui.TimePeriod                       TextLabel ("ALL TIME" or "MONTH YEAR")

    Each statue Model must contain a Configuration folder with:
        Leaderboard  ObjectValue -> the board Model it belongs to
        Pos          IntValue    -> rank it represents (1 = first place)
        Role         StringValue -> label shown under the name
        Animation    Animation   -> idle animation (optional)
--]]

local LeaderboardConfig = {}

--- Folder under workspace.Assets holding the boards.
LeaderboardConfig.FOLDER_NAME = "Leaderboards"

--- Suffix appended to every OrderedDataStore name. Bump this to wipe all boards
--- without touching player profiles. V3 read this from a ServerScriptService attribute;
--- keeping it in config makes it visible and reviewable.
LeaderboardConfig.DATASTORE_KEY = "_V3_01"

--- Seconds between full refreshes. Each refresh does one GetSortedAsync per board, so
--- keep this comfortably above the DataStore budget for the number of boards.
LeaderboardConfig.REFRESH_INTERVAL = 120

--- Rows fetched and displayed per board.
LeaderboardConfig.MAX_ENTRIES = 100

--- Bounded retry for username/thumbnail lookups. V3 retried forever, which hangs the
--- whole refresh loop on a deleted account.
LeaderboardConfig.PROFILE_LOOKUP_RETRIES = 3
LeaderboardConfig.PROFILE_LOOKUP_DELAY = 3

--- Boards, keyed by the Model name in the world. `Key` is the OrderedDataStore base
--- name (no spaces). Monthly boards get a "MMMYY_" prefix at runtime.
---
--- "Most Tips" from V3 is deliberately absent — tipping is cut.
LeaderboardConfig.Boards = {
	["Most Staff Points"] = { Key = "MostStaffPoints", Abbreviate = true },
	["Most Boba Bucks"] = { Key = "MostBobaBucks", Abbreviate = true },
	["Most Active"] = { Key = "MostActive", Abbreviate = false, Format = "Time" },
	["Top Donators"] = { Key = "TopDonators", Abbreviate = true },
}

--- 1234 -> "1.23k". Used for boards flagged Abbreviate.
function LeaderboardConfig.abbreviate(value: number): string
	if value < 1000 then
		return tostring(value)
	end
	if value < 1000000 then
		return string.format("%.2fk", value / 1000)
	end
	return string.format("%.2fm", value / 1000000)
end

--- Seconds -> "12h 34m", for activity boards.
function LeaderboardConfig.formatTime(value: number): string
	local hours = math.floor(value / 3600)
	local minutes = math.floor((value % 3600) / 60)

	if hours > 0 then
		return string.format("%dh %dm", hours, minutes)
	end
	return string.format("%dm", minutes)
end

--- Display string for a raw board value.
function LeaderboardConfig.formatValue(boardName: string, value: number): string
	local definition = LeaderboardConfig.Boards[boardName]
	if not definition then
		return tostring(value)
	end

	if definition.Format == "Time" then
		return LeaderboardConfig.formatTime(value)
	end

	if definition.Abbreviate then
		return LeaderboardConfig.abbreviate(value)
	end

	return tostring(value)
end

--- OrderedDataStore name for a board. Monthly boards are namespaced per calendar month
--- so they roll over on their own with no reset job.
function LeaderboardConfig.getStoreName(boardName: string, isMonthly: boolean, now: number?): string?
	local definition = LeaderboardConfig.Boards[boardName]
	if not definition then
		return nil
	end

	local base = definition.Key

	if isMonthly then
		base = string.upper(os.date("!%b%y_", now or os.time())) .. base
	end

	return base .. LeaderboardConfig.DATASTORE_KEY
end

return LeaderboardConfig
