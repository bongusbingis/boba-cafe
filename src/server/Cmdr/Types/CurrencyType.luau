return function(registry)
	registry:RegisterType(
		"currencyType",
		registry.Cmdr.Util.MakeEnumType("currencyType", {
			"BobaBucks",
			"Points",
		})
	)
end
