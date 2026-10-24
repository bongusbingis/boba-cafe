--!strict
return {
	Name = "spawn-spill",
	Aliases = { "spill", "createspill" },
	Description = "Spawns a spill on the cafe floor.",
	Group = "Events",
	Args = {
		{
			Type = "spillTemplate",
			Name = "template",
			Description = "Spill template (Boba, MeltedPopsicle). Defaults to random if omitted.",
			Optional = true,
		},
	},
}
