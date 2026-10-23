return {
	Name = "resetpetname",
	Aliases = {},
	Description = "Clears a player's custom pet name. Give a pet display name or ItemId to reset one pet, or omit to reset all renamed pets.",
	Group = "Moderation",
	Args = {
		{
			Type = "player",
			Name = "target",
			Description = "The player whose pet name to reset",
		},
		{
			Type = "string",
			Name = "pet",
			Description = "Pet display name or ItemId (omit for all renamed pets)",
			Optional = true,
		},
		{
			Type = "string",
			Name = "reason",
			Description = "Reason for the reset",
			Optional = true,
		},
	},
}
