return {
	Name = "clock-out",
	Aliases = { "clockout", "shiftend" },
	Description = "Clocks out player(s) from their shift (triggers paycheck summary).",
	Group = "Progression",
	Args = {
		{
			Type = "players",
			Name = "targets",
			Description = "Target player(s)",
		},
	},
}
