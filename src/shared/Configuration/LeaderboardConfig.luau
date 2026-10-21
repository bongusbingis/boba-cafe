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
		},
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
		},
	} :: { [string]: BoardDefinition },
}

--- Derives the monthly OrderedDataStore key: YYYY_MM_ prefix followed by boardType.
--- Automatically resets monthly boards when month rolls over.
function LeaderboardConfig.GetMonthKey(boardType: string, timestamp: number?): string
	local t = timestamp or os.time()
	return os.date("%Y_%m_", t) .. boardType
end

return LeaderboardConfig
