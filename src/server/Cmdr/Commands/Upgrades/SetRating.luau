--!strict
return {
	Name = "set-rating",
	Aliases = { "caferating", "setrating", "rating" },
	Description = "Sets the cafe rating score / stars.",
	Group = "Upgrades",
	Args = {
		{
			Type = "number",
			Name = "rating",
			Description = "Cafe rating (e.g. 1.0 to 5.0)",
		},
	},
}
