return {
	Name = "award-badge",
	Aliases = { "badge", "awardbadge" },
	Description = "Awards a badge to player(s).",
	Group = "Progression",
	Args = {
		{
			Type = "players",
			Name = "targets",
			Description = "Target player(s)",
		},
		{
			Type = "badgeName",
			Name = "badge",
			Description = "Badge name",
		},
	},
}
