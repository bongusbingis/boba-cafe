return {
	Name = "give-all-items",
	Aliases = { "giveall", "allitems" },
	Description = "Grants all items in the game to player(s).",
	Group = "Economy",
	Args = {
		{
			Type = "players",
			Name = "targets",
			Description = "Target player(s)",
		},
	},
}
