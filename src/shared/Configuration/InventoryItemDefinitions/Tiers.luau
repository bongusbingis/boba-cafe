export type Tier = {
    Name: string,
    Color: Color3,
    Weight: number,
}

return {
	Common = {
		Color = Color3.fromRGB(190, 190, 190),
		Weight = 0.6,
	},
	Basic = {
        Color = Color3.fromRGB(190, 190, 190),
        Weight = 0.5,
    },
	Uncommon = {
        Color = Color3.fromHSV(0.388889, 0.6, 0.784314),
        Weight = 0.25,
    },
	Rare = {
        Color = Color3.fromRGB(80, 150, 255),
        Weight = 0.15,
    },
	Epic = {
        Color = Color3.fromRGB(180, 80, 255),
        Weight = 0.7,
    },
	Legendary = {
        Color = Color3.fromRGB(255, 185, 30),
        Weight = 0.3,
    },
	Special = {
        Color = Color3.fromRGB(255, 150, 40),
        Weight = 0,
    },
}
