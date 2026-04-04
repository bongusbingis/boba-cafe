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
	Tier: string,
	Color: Color3,
	Price: string,
	CanBeSold: boolean?,
	Animation: ColorAnimation?,
	OffSale: boolean?,
}

return setmetatable({
	---> static

    ---> basic
	["Crimson"] = {
		Tier = "Basic",
		Color = Color3.fromRGB(220, 50, 50),
		Price = "150",
		CanBeSold = true,
	},
	["Blue"] = {
		Tier = "Basic",
		Color = Color3.fromRGB(50, 150, 220),
		Price = " 150",
		CanBeSold = true,
	},
    ["Turquoise"] = {
		Tier = "Basic",
		Color = Color3.fromRGB(50, 220, 200),
		Price = " 150",
		CanBeSold = true,
	},
	["Emerald"] = {
		Tier = "Basic",
		Color = Color3.fromRGB(50, 180, 90),
		Price = " 150",
		CanBeSold = true,
	},
	["Violet"] = {
		Tier = "Basic",
		Color = Color3.fromRGB(140, 70, 220),
		Price = " 150",
		CanBeSold = true,
	},
	["Orange"] = {
		Tier = "Basic",
		Color = Color3.fromRGB(240, 120, 40),
		Price = " 150",
		CanBeSold = true,
	},
	["Slate"] = {
		Tier = "Basic",
		Color = Color3.fromRGB(100, 120, 150),
		Price = " 150",
		CanBeSold = true,
	},

    ---> uncommon
	["Gold"] = {
		Tier = "Uncommon",
		Color = Color3.fromRGB(255, 200, 50),
		Price = " 200",
		CanBeSold = true,
	},
    ["Rose"] = {
		Tier = "Uncommon",
		Color = Color3.fromRGB(220, 80, 120),
		Price = " 150",
		CanBeSold = true,
	},
	["Bubblegum"] = {
		Tier = "Uncommon",
		Color = Color3.fromRGB(255, 100, 180),
		Price = " 350",
		CanBeSold = true,
		Animation = {
			Frames = {
				{ Color = Color3.fromRGB(255, 100, 180), Transparency = 0, Hold = 0, Transition = 0.8 },
				{ Color = Color3.fromRGB(255, 100, 180), Transparency = 0.5, Hold = 0, Transition = 0.8 },
			},
		},
	},
	["Mint"] = {
		Tier = "Uncommon",
		Color = Color3.fromRGB(100, 220, 160),
		Price = " 200",
		CanBeSold = true,
	},
	["Lavender"] = {
		Tier = "Uncommon",
		Color = Color3.fromRGB(180, 140, 255),
		Price = " 200",
		CanBeSold = true,
	},
	["Tangerine"] = {
		Tier = "Uncommon",
		Color = Color3.fromRGB(255, 150, 60),
		Price = " 250",
		CanBeSold = true,
		Animation = {
			Frames = {
				{ Color = Color3.fromRGB(255, 150, 60), Transparency = 0, Hold = 0.3, Transition = 0.7 },
				{ Color = Color3.fromRGB(255, 200, 80), Transparency = 0, Hold = 0.3, Transition = 0.7 },
			},
		},
	},

    ---> rare
	["Sunset"] = {
		Tier = "Rare",
		Color = Color3.fromRGB(255, 100, 50),
		Price = " 400",
		CanBeSold = true,
		Animation = {
			Frames = {
				{ Color = Color3.fromRGB(255, 80, 50), Hold = 0, Transition = 1.2 },
				{ Color = Color3.fromRGB(255, 190, 50), Hold = 0, Transition = 1.2 },
				{ Color = Color3.fromRGB(255, 50, 100), Hold = 0, Transition = 1.2 },
			},
		},
	},
	["Aurora"] = {
		Tier = "Rare",
		Color = Color3.fromRGB(100, 255, 200),
		Price = " 500",
		CanBeSold = true,
		Animation = {
			Frames = {
				{ Color = Color3.fromRGB(100, 255, 200), Hold = 0, Transition = 1.0 },
				{ Color = Color3.fromRGB(100, 200, 255), Hold = 0, Transition = 1.0 },
				{ Color = Color3.fromRGB(160, 100, 255), Hold = 0, Transition = 1.0 },
				{ Color = Color3.fromRGB(255, 100, 200), Hold = 0, Transition = 1.0 },
			},
		},
	},
	["Ocean"] = {
		Tier = "Rare",
		Color = Color3.fromRGB(30, 120, 220),
		Price = " 450",
		CanBeSold = true,
		Animation = {
			Frames = {
				{ Color = Color3.fromRGB(30, 120, 220), Hold = 0, Transition = 1.5 },
				{ Color = Color3.fromRGB(30, 200, 220), Hold = 0, Transition = 1.5 },
				{ Color = Color3.fromRGB(60, 80, 200), Hold = 0, Transition = 1.5 },
			},
		},
	},
	["Ember"] = {
		Tier = "Rare",
		Color = Color3.fromRGB(255, 80, 20),
		Price = " 500",
		CanBeSold = true,
		Animation = {
			Frames = {
				{ Color = Color3.fromRGB(255, 80, 20), Hold = 0, Transition = 0.6 },
				{ Color = Color3.fromRGB(255, 160, 20), Hold = 0, Transition = 0.6 },
				{ Color = Color3.fromRGB(200, 40, 10), Hold = 0, Transition = 0.6 },
			},
		},
	},

    ---> epic
	["Void"] = {
		Tier = "Epic",
		Color = Color3.fromRGB(80, 50, 150),
		Price = " 600",
		CanBeSold = true,
		Animation = {
			Frames = {
				{ Color = Color3.fromRGB(80, 50, 150), Transparency = 0, Hold = 0, Transition = 2.0 },
				{ Color = Color3.fromRGB(30, 20, 80), Transparency = 0.35, Hold = 0, Transition = 2.0 },
			},
		},
	},
	["Eclipse"] = {
		Tier = "Epic",
		Color = Color3.fromRGB(20, 10, 60),
		Price = " 650",
		CanBeSold = true,
		Animation = {
			Frames = {
				{ Color = Color3.fromRGB(20, 10, 60), Transparency = 0, Hold = 0.5, Transition = 2.5 },
				{ Color = Color3.fromRGB(100, 60, 200), Transparency = 0, Hold = 0.5, Transition = 2.5 },
				{ Color = Color3.fromRGB(20, 10, 60), Transparency = 0.4, Hold = 0, Transition = 1.5 },
			},
		},
	},
	["Storm"] = {
		Tier = "Epic",
		Color = Color3.fromRGB(80, 100, 180),
		Price = " 650",
		CanBeSold = true,
		Animation = {
			Frames = {
				{ Color = Color3.fromRGB(80, 100, 180), Transparency = 0, Hold = 0, Transition = 1.8 },
				{ Color = Color3.fromRGB(180, 180, 255), Transparency = 0, Hold = 0, Transition = 0.1 },
				{ Color = Color3.fromRGB(80, 100, 180), Transparency = 0, Hold = 0, Transition = 1.8 },
				{ Color = Color3.fromRGB(40, 50, 120), Transparency = 0.2, Hold = 0, Transition = 1.2 },
			},
		},
	},

    ---> legendary
	["Prism"] = {
		Tier = "Legendary",
		Color = Color3.fromRGB(255, 50, 50),
		Price = " 800",
		CanBeSold = true,
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
	["Nebula"] = {
		Tier = "Legendary",
		Color = Color3.fromRGB(80, 20, 160),
		Price = " 800",
		CanBeSold = true,
		Animation = {
			Frames = {
				{ Color = Color3.fromRGB(80, 20, 160), Hold = 0, Transition = 1.2 },
				{ Color = Color3.fromRGB(20, 80, 200), Hold = 0, Transition = 1.2 },
				{ Color = Color3.fromRGB(160, 20, 120), Hold = 0, Transition = 1.2 },
				{ Color = Color3.fromRGB(40, 160, 200), Hold = 0, Transition = 1.2 },
				{ Color = Color3.fromRGB(120, 40, 200), Hold = 0, Transition = 1.2 },
			},
		},
	},
	["Inferno"] = {
		Tier = "Legendary",
		Color = Color3.fromRGB(255, 60, 0),
		Price = " 900",
		CanBeSold = true,
		Animation = {
			Frames = {
				{ Color = Color3.fromRGB(255, 60, 0), Hold = 0, Transition = 0.3 },
				{ Color = Color3.fromRGB(255, 140, 0), Hold = 0, Transition = 0.3 },
				{ Color = Color3.fromRGB(200, 20, 0), Hold = 0, Transition = 0.3 },
				{ Color = Color3.fromRGB(255, 220, 0), Hold = 0, Transition = 0.3 },
				{ Color = Color3.fromRGB(180, 0, 0), Hold = 0, Transition = 0.3 },
			},
		},
	},
}, {
    __index = {
        Capsules = {
            {
                Name = "Nametag Capsule",
                Price = " 150",
                Image = "rbxassetid://6073658218",
            },
            {
                Name = "10 Nametag Capsules",
                Price = " 150",
                Image = "rbxassetid://6073658218",
            },
            {
                Name = "50 Nametag Capsules",
                Price = " 150",
                Image = "rbxassetid://6073658218",
            }
        }
    }
})
