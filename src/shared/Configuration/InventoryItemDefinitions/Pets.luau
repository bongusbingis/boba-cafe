local petsStorage = game:GetService("ReplicatedStorage").SharedStorage.Pets

export type Pet = {
	Name: string,
	Tier: string,
	PetModel: Instance,
	OffSale: boolean?,
}

return setmetatable({
	---> common
	{
		Name = "Ant Pet",
		Tier = "Common",
		Icon = "",
		PetModel = petsStorage["Ant Pet"],
	},
	{
		Name = "Duck Pet",
		Tier = "Common",
		Icon = "",
		PetModel = petsStorage["Duck Pet"],
	},
	{
		Name = "Monkey Pet",
		Tier = "Common",
		Icon = "",
		PetModel = petsStorage["Monkey Pet"],
	},
	{
		Name = "Sheep Pet",
		Tier = "Common",
		Icon = "",
		PetModel = petsStorage["Sheep Pet"],
	},
	{
		Name = "Squid Pet",
		Tier = "Common",
		Icon = "",
		PetModel = petsStorage["Squid Pet"],
	},

	---> uncommon
	{
		Name = "Cow Pet",
		Tier = "Uncommon",
		Icon = "",
		PetModel = petsStorage["Cow Pet"],
	},
	{
		Name = "Ladybug Pet",
		Tier = "Uncommon",
		Icon = "",
		PetModel = petsStorage["Ladybug Pet"],
	},
	{
		Name = "Pig Pet",
		Tier = "Uncommon",
		Icon = "",
		PetModel = petsStorage["Pig Pet"],
	},
	{
		Name = "Shark Pet",
		Tier = "Uncommon",
		Icon = "",
		PetModel = petsStorage["Shark Pet"],
	},
	{
		Name = "Tiger Pet",
		Tier = "Uncommon",
		Icon = "",
		PetModel = petsStorage["Tiger Pet"],
	},
	{
		Name = "Whale Pet",
		Tier = "Uncommon",
		Icon = "",
		PetModel = petsStorage["Whale Pet"],
	},

	---> rare
	{
		Name = "Blue Squid Pet",
		Tier = "Rare",
		Icon = "",
		PetModel = petsStorage["Blue Squid Pet"],
	},
	{
		Name = "Cat Pet",
		Tier = "Rare",
		Icon = "",
		PetModel = petsStorage["Cat Pet"],
	},
	{
		Name = "Dog Pet",
		Tier = "Rare",
		Icon = "",
		PetModel = petsStorage["Dog Pet"],
	},
	{
		Name = "Eagle Pet",
		Tier = "Rare",
		Icon = "",
		PetModel = petsStorage["Eagle Pet"],
	},
	{
		Name = "Frog Pet",
		Tier = "Rare",
		Icon = "",
		PetModel = petsStorage["Frog Pet"],
	},
	{
		Name = "Snow Pet",
		Tier = "Rare",
		Icon = "",
		PetModel = petsStorage["Snow Pet"],
	},

	---> epic
	{
		Name = "Hen Pet",
		Tier = "Epic",
		Icon = "",
		PetModel = petsStorage["Hen Pet"],
	},
	{
		Name = "Spider Pet",
		Tier = "Epic",
		Icon = "",
		PetModel = petsStorage["Spider Pet"],
	},
	{
		Name = "Wolf Pet",
		Tier = "Epic",
		Icon = "",
		PetModel = petsStorage["Wolf Pet"],
	},

	---> legendary
	{
		Name = "Seahorse Pet",
		Tier = "Legendary",
		Icon = "",
		PetModel = petsStorage["Seahorse Pet"],
	},
	{
		Name = "Fish Pet",
		Tier = "Legendary",
		Icon = "",
		PetModel = petsStorage["Fish Pet"],
	},
	{
		Name = "Rainbow Squid Pet",
		Tier = "Legendary", -- was Mythic; mapped to Legendary (no Mythic tier in new system)
		Icon = "",
		PetModel = petsStorage["Rainbow Squid Pet"],
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
