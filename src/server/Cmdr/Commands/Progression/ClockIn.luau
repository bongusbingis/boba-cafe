return {
	Name = "clock-in",
	Aliases = { "clockin", "shiftstart" },
	Description = "Clocks in player(s) for a barista shift.",
	Group = "Progression",
	Args = {
		{
			Type = "players",
			Name = "targets",
			Description = "Target player(s)",
		},
	},
}
