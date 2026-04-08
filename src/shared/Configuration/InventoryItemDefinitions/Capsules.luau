export type Capsule = {
	Price: string,
	Image: string,
	ItemType: string,
	CanBeSold: boolean?,
	Count: number?,
	MinTier: string?,
}

return setmetatable({
	---> nametag capsules
	["Nametag Capsule"] = {
		Price = " 150",
		Image = "rbxassetid://6073658218",
		ItemType = "Nametags",
		CanBeSold = true,
	} :: Capsule,

	---> pet capsules
	["Regular Pet Capsule"] = {
		Price = " 75",
		Image = "rbxassetid://6073658218",
		ItemType = "Pets",
		MinTier = "Basic",
		CanBeSold = true,
	} :: Capsule,
	["Rare Pet Capsule"] = {
		Price = " 250",
		Image = "rbxassetid://7621095542",
		ItemType = "Pets",
		MinTier = "Rare",
		CanBeSold = true,
	} :: Capsule,
	["Epic Pet Capsule"] = {
		Price = " 800",
		Image = "rbxassetid://9369156094",
		ItemType = "Pets",
		MinTier = "Epic",
		CanBeSold = true,
	} :: Capsule,
}, {
	__index = {
		-- "Sell" is omitted here; InventoryComponent appends it automatically
		-- for any item with CanBeSold = true.
		ActionOverride = { { Text = "Hatch" } },
	}
})
