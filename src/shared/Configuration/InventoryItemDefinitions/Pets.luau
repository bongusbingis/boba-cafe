local petsStorage = game:GetService("ReplicatedStorage").SharedStorage.Pets

export type Pet = {
	Tier: string,
	PetModel: Instance,
	CanBeSold: boolean?,
	OffSale: boolean?,
}

return setmetatable({
	---> Basic
	["Ant Pet"] = {
		Tier = "Basic",
		Icon = "",
		PetModel = petsStorage["Ant Pet"],
		CanBeSold = true,
	},
	["Duck Pet"] = {
		Tier = "Basic",
		Icon = "",
		PetModel = petsStorage["Duck Pet"],
		CanBeSold = true,
	},
	["Monkey Pet"] = {
		Tier = "Basic",
		Icon = "",
		PetModel = petsStorage["Monkey Pet"],
		CanBeSold = true,
	},
	["Sheep Pet"] = {
		Tier = "Basic",
		Icon = "",
		PetModel = petsStorage["Sheep Pet"],
		CanBeSold = true,
	},
	["Squid Pet"] = {
		Tier = "Basic",
		Icon = "",
		PetModel = petsStorage["Squid Pet"],
		CanBeSold = true,
	},

	---> unBasic
	["Cow Pet"] = {
		Tier = "UnBasic",
		Icon = "",
		PetModel = petsStorage["Cow Pet"],
		CanBeSold = true,
	},
	["Ladybug Pet"] = {
		Tier = "UnBasic",
		Icon = "",
		PetModel = petsStorage["Ladybug Pet"],
		CanBeSold = true,
	},
	["Pig Pet"] = {
		Tier = "UnBasic",
		Icon = "",
		PetModel = petsStorage["Pig Pet"],
		CanBeSold = true,
	},
	["Shark Pet"] = {
		Tier = "UnBasic",
		Icon = "",
		PetModel = petsStorage["Shark Pet"],
		CanBeSold = true,
	},
	["Tiger Pet"] = {
		Tier = "UnBasic",
		Icon = "",
		PetModel = petsStorage["Tiger Pet"],
		CanBeSold = true,
	},
	["Whale Pet"] = {
		Tier = "UnBasic",
		Icon = "",
		PetModel = petsStorage["Whale Pet"],
		CanBeSold = true,
	},

	---> rare
	["Blue Squid Pet"] = {
		Tier = "Rare",
		Icon = "",
		PetModel = petsStorage["Blue Squid Pet"],
		CanBeSold = true,
	},
	["Cat Pet"] = {
		Tier = "Rare",
		Icon = "",
		PetModel = petsStorage["Cat Pet"],
		CanBeSold = true,
	},
	["Dog Pet"] = {
		Tier = "Rare",
		Icon = "",
		PetModel = petsStorage["Dog Pet"],
		CanBeSold = true,
	},
	["Eagle Pet"] = {
		Tier = "Rare",
		Icon = "",
		PetModel = petsStorage["Eagle Pet"],
		CanBeSold = true,
	},
	["Frog Pet"] = {
		Tier = "Rare",
		Icon = "",
		PetModel = petsStorage["Frog Pet"],
		CanBeSold = true,
	},
	["Snow Pet"] = {
		Tier = "Rare",
		Icon = "",
		PetModel = petsStorage["Snow Pet"],
		CanBeSold = true,
	},

	---> epic
	["Hen Pet"] = {
		Tier = "Epic",
		Icon = "",
		PetModel = petsStorage["Hen Pet"],
		CanBeSold = true,
	},
	["Spider Pet"] = {
		Tier = "Epic",
		Icon = "",
		PetModel = petsStorage["Spider Pet"],
		CanBeSold = true,
	},
	["Wolf Pet"] = {
		Tier = "Epic",
		Icon = "",
		PetModel = petsStorage["Wolf Pet"],
		CanBeSold = true,
	},

	---> legendary
	["Seahorse Pet"] = {
		Tier = "Legendary",
		Icon = "",
		PetModel = petsStorage["Seahorse Pet"],
		CanBeSold = true,
	},
	["Fish Pet"] = {
		Tier = "Legendary",
		Icon = "",
		PetModel = petsStorage["Fish Pet"],
		CanBeSold = true,
	},
	["Rainbow Squid Pet"] = {
		Tier = "Legendary", -- was Mythic; mapped to Legendary (no Mythic tier in new system)
		Icon = "",
		PetModel = petsStorage["Rainbow Squid Pet"],
		CanBeSold = true,
	},

	---> special (event-only; was VerySpecial)
}, {
	__index = {
		Capsules = {
			{
				Name = "Regular Pet Capsule",
				Price = " 75",
				Image = "rbxassetid://6073658218",
			},
			{
				Name = "Rare Pet Capsule",
				Price = " 250",
				Image = "rbxassetid://7621095542",
			},
			{
				Name = "Epic Pet Capsule",
				Price = " 800",
				Image = "rbxassetid://9369156094",
			},
		},
	},
})
