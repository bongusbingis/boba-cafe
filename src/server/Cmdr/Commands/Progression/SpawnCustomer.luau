return {
	Name = "spawn-customer",
	Aliases = { "customer", "spawnnpc" },
	Description = "Spawns an NPC customer at the cafe.",
	Group = "Progression",
	Args = {
		{
			Type = "customerVariant",
			Name = "variant",
			Description = "Variant: Customer, VIP, Karen",
			Optional = true,
		},
	},
}
