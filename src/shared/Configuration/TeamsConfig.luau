--[[
    Module: TeamsConfig
    Description: Teams created by Teams.server.luau. A player's team follows the
                 server-owned `ClockedIn` attribute (see ShiftService): clocked-in
                 players are Baristas, everyone else is a Customer.
--]]

return {
	{
		Name = "Baristas",
		Color = BrickColor.new("Light purple"),
		ClockedIn = true,
		AutoAssignable = true, -- matches ShiftService's default (clocked in on join)
	},
	{
		Name = "Customers",
		Color = BrickColor.new("Grey"),
		ClockedIn = false,
		AutoAssignable = false,
	},
}
