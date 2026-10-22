--!strict
return {
	Name = "spawn-spill",
	Aliases = { "spill", "createspill" },
	Description = "Spawns a spill on the cafe floor.",
	Group = "Events",
	Args = {
		{
			Type = "string",
			Name = "type",
			Description = "Spill type (Water, Boba, Tea)",
			Optional = true,
		},
	},
}
