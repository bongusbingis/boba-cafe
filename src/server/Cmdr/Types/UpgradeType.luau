return function(registry)
	registry:RegisterType(
		"upgradeType",
		registry.Cmdr.Util.MakeEnumType("upgradeType", {
			"Plants",
			"Lights",
		})
	)
end
