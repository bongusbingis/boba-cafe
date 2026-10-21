--!strict
--[[
	SeatingConfig (REVIVAL-001 BIG-B4). Served NPCs sit and drink. Every value is
	TUNING -- PROPOSED (tuning); none is an economy value. ENABLED is the release
	fallback (DEC-054 Q-G13): false = seating off, behaviour as before B4.
--]]
local SeatingConfig = {
	ENABLED = false, -- set by the BIG-B4-P1 perf result
	SEATED_BUDGET = 8, -- NPCs in the seat phase at once (claim to despawn)
	SIT_CHANCE = 0.8, -- PROPOSED (tuning)
	SEAT_MAX_DISTANCE_STUDS = 80, -- PROPOSED (tuning)
	SIT_SECONDS_MIN = 20, -- PROPOSED (tuning)
	SIT_SECONDS_MAX = 40, -- PROPOSED (tuning)
	SEAT_WALK_TIMEOUT_SECONDS = 8, -- PROPOSED (tuning)
	SEAT_ARRIVE_RADIUS_STUDS = 4, -- PROPOSED (tuning)
	SIT_CONFIRM_SECONDS = 0.5, -- PROPOSED (tuning)
	SEAT_RETRY_COUNT = 1, -- PROPOSED (tuning)
	SEATED_POLL_SECONDS = 1, -- PROPOSED (tuning)
	STAND_STEP_STUDS = 2.5, -- PROPOSED (tuning)
	SIT_ANIMS = { "BoothSit", "CafeSit", "ComfySit", "CouchSit" }, -- PROPOSED (tuning)
	SEATED_LINE_CHANCE = 0.5, -- PROPOSED (tuning)
	SEATED_LINE_DELAY_SECONDS = 6, -- PROPOSED (tuning)
	PATHFINDING = true, -- PROPOSED (tuning)
	PATH_WAYPOINT_TIMEOUT_SECONDS = 3, -- PROPOSED (tuning)
	PATH_MAX_WAYPOINTS = 60, -- PROPOSED (tuning)
	STRESS_BARISTAS = 12, -- Studio perf check only: PacingTarget(12) = 16
	STRESS_SERVE_AFTER_SECONDS = 4, -- Studio perf check only
}
return SeatingConfig
