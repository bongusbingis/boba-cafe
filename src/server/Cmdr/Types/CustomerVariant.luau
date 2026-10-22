return function(registry)
	registry:RegisterType(
		"customerVariant",
		registry.Cmdr.Util.MakeEnumType("customerVariant", {
			"Customer",
			"VIP",
			"Karen",
		})
	)
end
