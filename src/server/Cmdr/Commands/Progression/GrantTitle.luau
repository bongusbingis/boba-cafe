return {
	Name = "grant-title",
	Aliases = { "granttitle", "title" },
	Description = "Grants a title to player(s) by ID.",
	Group = "Progression",
	Args = {
		{
			Type = "players",
			Name = "targets",
			Description = "Target player(s)",
		},
		{
			Type = "string",
			Name = "titleId",
			Description = "Title ID (e.g. BetaTester, EventChampion, CafeFavourite)",
		},
	},
}
