export type Tier = {
    Name: string,
    Color: Color3,
    Weight: number,
}

return {
	Basic = {
        Color = Color3.fromRGB(190, 190, 190),
        Weight = 0.5,
        SellPrice = 10,
    },
	Uncommon = {
        Color = Color3.fromHSV(0.388889, 0.6, 0.784314),
        Weight = 0.25,
        SellPrice = 15,
    },
	Rare = {
        Color = Color3.fromRGB(80, 150, 255),
        Weight = 0.15,
        SellPrice = 25,
    },
	Epic = {
        Color = Color3.fromRGB(180, 80, 255),
        Weight = 0.05,
        SellPrice = 50,
    },
	Legendary = {
        Color = Color3.fromRGB(255, 185, 30),
        Weight = 0.01,
        SellPrice = 100,
    },
	Special = {
        Color = Color3.fromRGB(255, 150, 40),
        Weight = 0,
    },
}
