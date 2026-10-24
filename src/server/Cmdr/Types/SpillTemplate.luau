return function(registry)
	registry:RegisterType(
		"spillTemplate",
		registry.Cmdr.Util.MakeEnumType("spillTemplate", {
			"Boba",
			"MeltedPopsicle",
		})
	)
end
