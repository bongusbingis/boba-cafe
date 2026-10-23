return {
	Name = "jumppower",
	Aliases = { "jp", "jumpheight" },
	Description = "Sets the jump power or height of target player(s).",
	Group = "Moderation",
	Args = {
		{
			Type = "players",
			Name = "targets",
			Description = "The player(s) to modify",
		},
		{
			Type = "number",
			Name = "power",
			Description = "Jump power or jump height value",
		},
	},
}
