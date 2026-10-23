return {
	Name = "speed",
	Aliases = { "ws", "walkspeed" },
	Description = "Sets the walkspeed of target player(s).",
	Group = "Moderation",
	Args = {
		{
			Type = "players",
			Name = "targets",
			Description = "The player(s) to modify",
		},
		{
			Type = "number",
			Name = "speed",
			Description = "Walkspeed value",
		},
	},
}
