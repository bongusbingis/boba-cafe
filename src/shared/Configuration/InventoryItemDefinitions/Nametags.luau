export type AnimFrame = {
	Color: Color3,
	Transparency: number?,
	Hold: number,
	Transition: number?,
}

export type ColorAnimation = {
	Frames: { AnimFrame },
}

export type NametagColor = {
	Name: string,
	Tier: string,
	Color: Color3,
	Price: string,
	Animation: ColorAnimation?,
	OffSale: boolean?,
}

return {
	---> static
	{
		Name = "Crimson",
		Tier = "Basic",
		Color = Color3.fromRGB(220, 50, 50),
		Price = "150",
	},
	{
		Name = "Blue",
		Tier = "Basic",
		Color = Color3.fromRGB(50, 150, 220),
		Price = " 150",
	},
	{
		Name = "Emerald",
		Tier = "Basic",
		Color = Color3.fromRGB(50, 180, 90),
		Price = " 150",
	},
	{
		Name = "Gold",
		Tier = "Uncommon",
		Color = Color3.fromRGB(255, 200, 50),
		Price = " 200",
	},
    {
		Name = "Strawberry",
		Tier = "Uncommon",
		Color = Color3.fromRGB(255, 116, 120),
		Price = " 200",
	},

	---> animated
	{
		Name = "Bubblegum",
		Tier = "Uncommon",
		Color = Color3.fromRGB(255, 100, 180),
		Price = " 350",
		Animation = {
			Frames = {
				{ Color = Color3.fromRGB(255, 100, 180), Transparency = 0, Hold = 0, Transition = 0.8 },
				{ Color = Color3.fromRGB(255, 100, 180), Transparency = 0.5, Hold = 0, Transition = 0.8 },
			},
		},
	},
	{
		Name = "Sunset",
		Tier = "Rare",
		Color = Color3.fromRGB(255, 100, 50),
		Price = " 400",
		Animation = {
			Frames = {
				{ Color = Color3.fromRGB(255, 80, 50), Hold = 0, Transition = 1.2 },
				{ Color = Color3.fromRGB(255, 190, 50), Hold = 0, Transition = 1.2 },
				{ Color = Color3.fromRGB(255, 50, 100), Hold = 0, Transition = 1.2 },
			},
		},
	},
	{
		Name = "Aurora",
		Tier = "Rare",
		Color = Color3.fromRGB(100, 255, 200),
		Price = " 500",
		Animation = {
			Frames = {
				{ Color = Color3.fromRGB(100, 255, 200), Hold = 0, Transition = 1.0 },
				{ Color = Color3.fromRGB(100, 200, 255), Hold = 0, Transition = 1.0 },
				{ Color = Color3.fromRGB(160, 100, 255), Hold = 0, Transition = 1.0 },
				{ Color = Color3.fromRGB(255, 100, 200), Hold = 0, Transition = 1.0 },
			},
		},
	},
	{
		Name = "Void",
		Tier = "Epic",
		Color = Color3.fromRGB(80, 50, 150),
		Price = " 600",
		Animation = {
			Frames = {
				{ Color = Color3.fromRGB(80, 50, 150), Transparency = 0, Hold = 0, Transition = 2.0 },
				{ Color = Color3.fromRGB(30, 20, 80), Transparency = 0.35, Hold = 0, Transition = 2.0 },
			},
		},
	},
	{
		Name = "Prism",
		Tier = "Legendary",
		Color = Color3.fromRGB(255, 50, 50),
		Price = " 800",
		Animation = {
			Frames = {
				{ Color = Color3.fromRGB(255, 50, 50), Hold = 0, Transition = 0.45 },
				{ Color = Color3.fromRGB(255, 165, 50), Hold = 0, Transition = 0.45 },
				{ Color = Color3.fromRGB(255, 255, 50), Hold = 0, Transition = 0.45 },
				{ Color = Color3.fromRGB(50, 220, 80), Hold = 0, Transition = 0.45 },
				{ Color = Color3.fromRGB(50, 150, 255), Hold = 0, Transition = 0.45 },
				{ Color = Color3.fromRGB(180, 50, 255), Hold = 0, Transition = 0.45 },
			},
		},
	},
	{
		Name = "Valentine",
		Tier = "Special",
		Color = Color3.fromRGB(255, 120, 150),
		Price = " 300",
		OffSale = true,
		Animation = {
			Frames = {
				{ Color = Color3.fromRGB(255, 120, 150), Hold = 1.0, Transition = 0.8 },
				{ Color = Color3.fromRGB(255, 50, 100), Hold = 1.0, Transition = 0.8 },
			},
		},
	},
}
