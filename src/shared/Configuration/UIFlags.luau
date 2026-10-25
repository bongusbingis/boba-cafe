--!strict
--[[
	UIFlags
	Display switches only; no data is touched.

	SHOW_POINTS: Points currently have no use in the game (audit D6.3), so the Points
	shop packs are hidden. The Points currency, profile data and server code are kept.
	Set true to show the Points packs in Shop > Currency again.
]]

return {
	SHOW_POINTS = false,
	BobaBuddyUpsellEnabled = true,
	InstantBrewUpsellEnabled = true,
}
