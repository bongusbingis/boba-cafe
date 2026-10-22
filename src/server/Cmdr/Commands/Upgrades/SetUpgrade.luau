--!strict
return {
	Name = "set-upgrade",
	Aliases = { "upgrade", "setupgrade" },
	Description = "Sets a cafe upgrade to a specific level (Plants, Lights, TipJar, Jukebox).",
	Group = "Upgrades",
	Args = {
		{
			Type = "upgradeType",
			Name = "upgrade",
			Description = "Upgrade ID: Plants, Lights, TipJar, Jukebox",
		},
		{
			Type = "integer",
			Name = "level",
			Description = "Level to set (0 to max level)",
		},
	},
}
