return {
	Name = "give-capsule",
	Aliases = { "givecapsule" },
	Description = "Grants an earned capsule to player(s).",
	Group = "Economy",
	Args = {
		{
			Type = "players",
			Name = "targets",
			Description = "Target player(s)",
		},
		{
			Type = "string",
			Name = "capsuleName",
			Description = "Capsule name (e.g. Common, Rare, etc.)",
		},
	},
}
