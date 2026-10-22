return function(registry)
	registry:RegisterType(
		"itemType",
		registry.Cmdr.Util.MakeEnumType("itemType", {
			"Capsules",
			"Nametags",
			"Particles",
			"Pets",
		})
	)
end
