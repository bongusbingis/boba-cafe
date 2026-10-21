--!strict
--[[
	LeaderboardConfig.luau
	Monthly Leaderboards configuration and key derivation (REVIVAL-001 M4-LEADERBOARDS, DEC-032).
]]

export type BoardDefinition = {
	BoardName: string,
	ModelName: string,
	Metric: string,
	Hidden: boolean?,
	-- All-time OrderedDataStore behind the Global board. Set only where the pre-revival (main, a476819) all-time
	-- store holds the same metric, so its history keeps showing; otherwise GetAllTimeKey uses AllTime_<board>.
	AllTimeStore: string?,
}

local LeaderboardConfig = {
	REFRESH_INTERVAL_SECONDS = 120,
	FLUSH_MAX_ATTEMPTS = 3, -- total write attempts per delta, one per flush cycle
	TOP_LIMIT = 10,
	BOARDS = {
		MostTips = {
			BoardName = "Most Tips",
			ModelName = "Most Tips",
			Metric = "BobaBucks",
			Hidden = true, -- DEC-035 Q4
		},
		MostBobaBucks = {
			BoardName = "Most Boba Bucks",
			ModelName = "Most Boba Bucks",
			Metric = "BobaBucks",
			AllTimeStore = "MostBobaBucks_V3_01", -- pre-revival Global store (same metric)
		},
		-- PENDING JACK: the pre-revival Global stores MostStaffPoints_V3_01 (staff points, not orders) and
		-- MostActive_V3_01 (seconds, not minutes) hold different units, so they are left untouched, not merged.
		OrdersServed = {
			BoardName = "Most Orders Served",
			ModelName = "Most Staff Points",
			Metric = "Orders",
		},
		MostActive = {
			BoardName = "Most Active",
			ModelName = "Most Active",
			Metric = "Minutes",
		},
		TopDonators = {
			BoardName = "Top Donators",
			ModelName = "Top Donators",
			Metric = "Robux",
			AllTimeStore = "TopDonators_V3_01", -- pre-revival Global store (same metric)
		},
	} :: { [string]: BoardDefinition },
}

--- Derives the monthly OrderedDataStore key: YYYY_MM_ prefix followed by boardType.
--- Automatically resets monthly boards when month rolls over. UTC ("!"), matching os.time() and the board's
--- FormatUniversalTime month label, so a Studio session near a month boundary writes the same month as servers.
function LeaderboardConfig.GetMonthKey(boardType: string, timestamp: number?): string
	local t = timestamp or os.time()
	return os.date("!%Y_%m_", t) .. boardType
end

--- TAKEOVER-REVIEW-FIX P2-4: the all-time OrderedDataStore key behind the Global boards (never resets). Reuses
--- the pre-revival store where the board defines AllTimeStore, so existing player totals are not orphaned.
function LeaderboardConfig.GetAllTimeKey(boardType: string): string
	local def = LeaderboardConfig.BOARDS[boardType]
	if def ~= nil and def.AllTimeStore ~= nil then
		return def.AllTimeStore
	end
	return "AllTime_" .. boardType
end

return LeaderboardConfig
