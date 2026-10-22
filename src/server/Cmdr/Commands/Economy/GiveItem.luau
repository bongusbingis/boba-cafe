return {
	Name = "give-item",
	Aliases = { "giveitem" },
	Description = "Gives an item (Capsules, Nametags, Particles, Pets) to player(s).",
	Group = "Economy",
	Args = {
		{
			Type = "players",
			Name = "targets",
			Description = "Target player(s)",
		},
		{
			Type = "itemType",
			Name = "itemType",
			Description = "Item type: Capsules, Nametags, Particles, Pets",
		},
		{
			Type = "string",
			Name = "itemName",
			Description = "Item name",
		},
	},
}
