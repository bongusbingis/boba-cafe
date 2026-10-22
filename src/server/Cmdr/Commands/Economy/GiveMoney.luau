return {
	Name = "give-money",
	Aliases = { "givebb", "addmoney", "givemoney" },
	Description = "Grants BobaBucks to player(s).",
	Group = "Economy",
	Args = {
		{
			Type = "players",
			Name = "targets",
			Description = "Players to grant money to",
		},
		{
			Type = "integer",
			Name = "amount",
			Description = "Amount of BobaBucks",
		},
	},
}
