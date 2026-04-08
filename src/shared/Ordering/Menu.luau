local FoodService = {}
local Models = game.ReplicatedStorage:WaitForChild("SelectorModels")

local CUP_MODELS = Models["Cup"]
local DEFAULT_CUP_MODEL = "Medium Cup"
local DEFAULT_MODEL_DISTANCE = 0.75

local SIZE_SMALL_MEDIUM_LARGE = { "Small", "Medium", "Large" }
local SIZE_MUG = { "Mug" }
local TEMPERATURE_COLD_HOT = { "Cold", "Hot" }

local TOP_MENU_COLOR = Color3.fromRGB(255, 105, 185)
local TOP_MENU_ITEM_COLOR = Color3.fromRGB(255, 139, 230)

local SMOOTHIE_NAMES = {
	"Apricot Smoothie",
	"Banana Smoothie",
	"Blueberry Smoothie",
	"Cherry Smoothie",
	"Grapefruit Smoothie",
	"Grapes Smoothie",
	"Kiwi Smoothie",
	"Orange Smoothie",
	"Peach Smoothie",
	"Pear Smoothie",
	"Pineapple Smoothie",
	"Strawberry Banana Smoothie",
	"Strawberry Kiwi Smoothie",
	"Strawberry Smoothie",
	"Watermelon Smoothie",
	"Wild Berries Smoothie",
}

local COFFEE_NAMES = {
	"Regular",
	"Espresso",
	"Decaf",
	"Cappuccino",
	"Americano",
	"Cortado",
	"Koa Coffee",
	"Latte",
}

local TEA_ITEMS = {
	{ "Green", "Green Tea" },
	{ "Lemon", "Lemon Tea" },
	{ "Peach", "Peach Tea" },
	{ "Earl Grey", "Earl Grey Tea" },
	{ "Oolong", "Oolong Tea" },
	{ "Vanilla Chai", "Vanilla Chai Tea" },
	{ "Caramel Chai", "Caramel Chai Tea" },
}

local HOT_COCOA_ITEMS = {
	{ "Classic", "Hot Chocolate" },
	{ "Salted", "Salted Hot Chocolate" },
	{ "Caramel", "Caramel Hot Chocolate" },
	{ "Vanilla", "Vanilla Hot Chocolate" },
}

local COFFEE_OPTIONS = {
	["Iced"] = false,
	["Sugar"] = false,
}

local TEA_OPTIONS = {
	["Iced"] = false,
}

local function assignFields(base: { [string]: any }, extra: { [string]: any }?)
	if not extra then
		return base
	end

	for key, value in extra do
		base[key] = value
	end

	return base
end

local function buildCupView(modelName: string, includeDistance: boolean?)
	local view = {
		Model = CUP_MODELS:FindFirstChild(modelName),
	}

	if includeDistance ~= false then
		view.ModelDistance = DEFAULT_MODEL_DISTANCE
	end

	return view
end

local function buildCupItem(itemName: string, modelName: string, sizeOptions: { string }?, extra: { [string]: any }?)
	local item = {
		ItemName = itemName,
		View = buildCupView(modelName),
	}

	if sizeOptions then
		item.Select = {
			["Size"] = sizeOptions,
		}
	end

	return assignFields(item, extra)
end

local function buildSmoothieItems(withColor: boolean)
	local items = {}

	for _, smoothieName in ipairs(SMOOTHIE_NAMES) do
		items[smoothieName] = buildCupItem(smoothieName, DEFAULT_CUP_MODEL, SIZE_SMALL_MEDIUM_LARGE)
		if withColor then
			items[smoothieName].Color = TOP_MENU_ITEM_COLOR
		end
	end

	return items
end

local function buildCoffeeItems()
	local items = {}

	for _, coffeeName in ipairs(COFFEE_NAMES) do
		items[coffeeName] = buildCupItem(coffeeName, DEFAULT_CUP_MODEL, SIZE_SMALL_MEDIUM_LARGE, {
			Options = COFFEE_OPTIONS,
		})
	end

	return items
end

local function buildTeaItems()
	local items = {}

	for _, teaDef in ipairs(TEA_ITEMS) do
		items[teaDef[1]] = buildCupItem(teaDef[2], DEFAULT_CUP_MODEL, SIZE_SMALL_MEDIUM_LARGE, {
			Options = TEA_OPTIONS,
		})
	end

	return items
end

local function buildHotCocoaItems()
	local items = {}

	for _, cocoaDef in ipairs(HOT_COCOA_ITEMS) do
		items[cocoaDef[1]] = buildCupItem(cocoaDef[2], DEFAULT_CUP_MODEL, SIZE_MUG)
	end

	return items
end

local TapiocaFlavor = {
	['Fruity Twist'] = {
		Color = Color3.fromRGB(230, 170, 156)
	},
	['Passion Madness'] = {
		Color = Color3.fromRGB(135, 197, 204)
	},
	['Mystic Burst'] = {
		Color = Color3.fromRGB(183, 150, 227)
	},
	['Tropical Heaven'] = {
		Color = Color3.fromRGB(207, 242, 203)
	},
	['Marshmallow Delight'] = {
		Color = Color3.fromRGB(252, 255, 253)
	},
	['Normal'] = {
		Color = Color3.fromRGB(17, 17, 17)
	},
	['Strawberry'] = {
		Color = Color3.fromRGB(214, 94, 100)
	},
	['Banana Blast'] = {
		Color = Color3.fromRGB(245, 240, 174)
	},
	['Tutti Frutti'] = {
		Color = Color3.fromRGB(171, 196, 219)
	},
	['Pumpkin Paradise'] = {
		Color = Color3.fromRGB(247, 189, 126)
	},
}

local SyrupFlavor = {
	['Pumpkin Spice'] = {
		Color = Color3.fromRGB(255, 147, 75)
	},
	['Banana'] = {
		Color = Color3.fromRGB(255, 250, 84)
	},
	['Classic Milk Tea'] = {
		Color = Color3.fromRGB(255, 250, 214)
	},
	['Avocado'] = {
		Color = Color3.fromRGB(104, 184, 88)
	},
	['Strawberry Banana'] = {
		Color = Color3.fromRGB(255, 140, 194)
	},
	['Taro'] = {
		Color = Color3.fromRGB(224, 166, 255)
	},
	['Mango'] = {
		Color = Color3.fromRGB(255, 192, 92)
	},
	['Honeycomb'] = {
		Color = Color3.fromRGB(255, 222, 92)
	},
	['Coconut'] = {
		Color = Color3.fromRGB(255, 254, 247)
	},
	['Matcha'] = {
		Color = Color3.fromRGB(155, 227, 145)
	},
	['Chocolate Banana'] = {
		Color = Color3.fromRGB(171, 140, 87)
	},
	['Passion Fruit'] = {
		Color = Color3.fromRGB(255, 247, 105)
	},
	['Thai Milk Tea'] = {
		Color = Color3.fromRGB(255, 170, 51)
	},
	['Watermelon'] = {
		Color = Color3.fromRGB(255, 54, 111)
	},
	['Strawberry'] = {
		Color = Color3.fromRGB(255, 112, 167)
	},
	['Almond'] = {
		Color = Color3.fromRGB(255, 254, 222)
	},
	['Brown Sugar'] = {
		Color = Color3.fromRGB(227, 175, 98)
	},
	['Lychee'] = {
		Color = Color3.fromRGB(255, 69, 122)
	},
	['Chocolate'] = {
		Color = Color3.fromRGB(176, 119, 86)
	},
	['Green Tea'] = {
		Color = Color3.fromRGB(117, 242, 99)
	},
	['Mint'] = {
		Color = Color3.fromRGB(212, 255, 222)
	},
	['Raspberry'] = {
		Color = Color3.fromRGB(214, 113, 90)
	},
	['Orange'] = {
		Color = Color3.fromRGB(255, 169, 89)
	},
	['Cherry'] = {
		Color = Color3.fromRGB(255, 69, 78)
	},
	['Guava'] = {
		Color = Color3.fromRGB(235, 173, 131)
	},
	['Dragon Fruit'] = {
		Color = Color3.fromRGB(255, 5, 47)
	},
	["Blueberry"] = {
		Color = Color3.fromRGB(79, 134, 247),
	},
	["Peach"] = {
		Color = Color3.fromRGB(255, 203, 164),
	},
	["Oreo"] = {
		Color = Color3.fromRGB(18, 18, 18),
	},
	--['Peppermint'] = {
	--	Color = Color3.fromRGB(255, 135, 137)
	--},
}

local topMenuItems = buildSmoothieItems(true)
topMenuItems["Pumpkin Spice Boba"] = {
	Color = TOP_MENU_ITEM_COLOR,
	ItemName = "Boba",
	RequiredSelection = {
		["Tapioca Flavor"] = TapiocaFlavor,
	},
	Select = {
		["Size"] = SIZE_SMALL_MEDIUM_LARGE,
	},
}

FoodService["TopMenuSpecial"] = {
	Title = "New Arrivals",
	Color = TOP_MENU_COLOR,
	Items = topMenuItems,
}

FoodService['FoodTable'] = {
	['Boba Teas'] = {
		Icon = 'rbxassetid://5200075003',
		Color = Color3.fromRGB(242, 82, 82),
		LayoutOrder = 1,
		Items = {
			['Custom Boba'] = {
				ItemName = "Boba",
				View = buildCupView("Boba", false),
				RequiredSelection = {
					['Syrup Flavor'] = SyrupFlavor,
					['Tapioca Flavor'] = TapiocaFlavor,
				},
				Select = {
					["Size"] = SIZE_SMALL_MEDIUM_LARGE,
				},
				--Options = {
				--['Ice'] = false, (no ice in bobas apparently) :(
				--},
			},
			['Pumpkin Spice Boba'] = {
				ItemName = "Boba",
				View = buildCupView("Boba", false),
				RequiredSelection = {
					['Syrup Flavor'] = {
						['Pumpkin Spice'] = {
							Color = Color3.fromRGB(255, 147, 75)
						},
					},
					['Tapioca Flavor'] = TapiocaFlavor,
				},
				Select = {
					["Size"] = SIZE_SMALL_MEDIUM_LARGE,
				},
				--Options = {
				--['Ice'] = false, (no ice in bobas apparently) :(
				--},
			},
		}
	},
	
	['Smoothies'] = {
		Icon = 'rbxassetid://10866283725',
		Color = Color3.fromRGB(164, 140, 242),
		LayoutOrder = 2,
		Items = buildSmoothieItems(false)
	},
	
	['Coffees'] = {
		Icon = 'rbxassetid://5200039850',
		Color = Color3.fromRGB(242, 189, 82),
		LayoutOrder = 3,
		Items = buildCoffeeItems()
	},

	['Teas'] = {
		Icon = 'rbxassetid://5200012216',
		Color = Color3.fromRGB(189, 242, 82),
		LayoutOrder = 4,
		Items = buildTeaItems()
	},

	['Hot Cocoas'] = {
		Icon = 'rbxassetid://5200020364',
		Color = Color3.fromRGB(82, 242, 82),
		LayoutOrder = 5,
		Items = buildHotCocoaItems()
	},

	['Pastries'] = {
		Icon = 'rbxassetid://5199988764',
		Color = Color3.fromRGB(82, 242, 189),
		LayoutOrder = 6,
		Items = {
			['Fudge Brownie'] = {
				ItemName = "Fudge Brownie",
				View = {
					Model = Models["Pastry"]:FindFirstChild("Fudge Brownie"),
					Direction = Enum.NormalId.Top
				},
			},
			["Boba Popsicle"] = {
				ItemName = "Boba Popsicle",
				View = {
					Model = Models["Pastry"]:FindFirstChild("Boba Popsicle"),
				},
			},
			["Chocolate Cake Pop"] = {
				ItemName = "Chocolate Cake Pop",
				View = {
					Model = Models["Pastry"]:FindFirstChild("Chocolate Cake Pop"),
				},			},
			["Vanilla Cake Pop"] = {
				ItemName = "Vanilla Cake Pop",
				View = {
					Model = Models["Pastry"]:FindFirstChild("Vanilla Cake Pop"),
				},			},
			["Strawberry Cake Pop"] = {
				ItemName = "Strawberry Cake Pop",
				View = {
					Model = Models["Pastry"]:FindFirstChild("Strawberry Cake Pop"),
				},
			},
			["Chocolate Chip Cookie"] = {
				ItemName = "Chocolate Chip Cookie",
				View = {
					Model = Models["Pastry"]:FindFirstChild("Chocolate Chip Cookie"),
					Direction = Enum.NormalId.Front
				},
			},
			["Double Chocolate Cookie"] = {
				ItemName = "Double Chocolate Cookie",
				View = {
					Model = Models["Pastry"]:FindFirstChild("Double Chocolate Cookie"),
					Direction = Enum.NormalId.Front
				},
			},
			["Croissant"] = {
				ItemName = "Croissant",
				View = {
					Model = Models["Pastry"]:FindFirstChild("Croissant"),
					Direction = Enum.NormalId.Front
				},
			},
			["Chocolate Muffin"] = {
				ItemName = "Chocolate Muffin",
				View = {
					Model = Models["Pastry"]:FindFirstChild("Chocolate Muffin"),
				},
			},
			["Chocolate Eclaire"] = {
				ItemName = "Chocolate Eclaire",
				View = {
					Model = Models["Pastry"]:FindFirstChild("Chocolate Eclaire"),
					Direction = Enum.NormalId.Front
				},
			},
			["Cinnamon Roll"] = {
				ItemName = "Cinnamon Roll",
				View = {
					Model = Models["Pastry"]:FindFirstChild("Cinnamon Roll"),
					Direction = Enum.NormalId.Front
				},
			},
			["Cheesecake"] = {
				ItemName = "Cheesecake",
				View = {
					Model = Models["Pastry"]:FindFirstChild("Cheesecake"),
					Direction = Enum.NormalId.Top
				},
			},
			["Strawberry Donut"] = {
				ItemName = "Strawberry Donut",
				View = {
					Model = Models["Pastry"]:FindFirstChild("Strawberry Donut"),
					Direction = Enum.NormalId.Top
				},
			},
			["Boba Cupcake"] = {
				ItemName = "Boba Cupcake",
				View = {
					Model = Models["Pastry"]:FindFirstChild("Boba Cupcake"),
					Direction = Enum.NormalId.Top
				},
			},
		}
	},

	['Ice Creams'] = {
		Icon = 'rbxassetid://5200075171',
		Color = Color3.fromRGB(82, 189, 242),
		LayoutOrder = 7,
		Items = {
			['Cookie Dough'] = {
				ItemName = "Cookie Dough Ice Cream",	
				View = {
					Model = Models["IceCream"]:FindFirstChild("Cookie Dough Ice Cream"),
				},
			},
			['Ube'] = {
				ItemName = "Ube Ice Cream",
				View = {
					Model = Models["IceCream"]:FindFirstChild("Ube Ice Cream"),
				},
			},
			['Vanilla'] = {
				ItemName = "Vanilla Ice Cream",
				View = {
					Model = Models["IceCream"]:FindFirstChild("Vanilla Ice Cream"),
				},
			},
			['Chocolate'] = {
				ItemName = "Chocolate Ice Cream",
				View = {
					Model = Models["IceCream"]:FindFirstChild("Chocolate Ice Cream"),
				},
			},
			['Mint'] = {
				ItemName = "Mint Ice Cream",
				View = {
					Model = Models["IceCream"]:FindFirstChild("Mint Ice Cream"),
				},
			},
			['Cherry Sherbet'] = {
				ItemName = "Cherry Sherbet Ice Cream",
				View = {
					Model = Models["IceCream"]:FindFirstChild("Cherry Sherbet Ice Cream"),
				},
			},
			['Orange Sherbet'] = {
				ItemName = "Orange Sherbet Ice Cream",
				View = {
					Model = Models["IceCream"]:FindFirstChild("Orange Sherbet Ice Cream"),
				},
			},
			['Watermelon Sherbet'] = {
				ItemName = "Watermelon Sherbet Ice Cream",
				View = {
					Model = Models["IceCream"]:FindFirstChild("Watermelon Sherbet Ice Cream"),
				},
			},
			['Bubble Gum'] = {
				ItemName = "Bubble Gum Ice Cream",
				View = {
					Model = Models["IceCream"]:FindFirstChild("Bubble Gum Ice Cream"),
				},
			},
			['Cotton Candy'] = {
				ItemName = "Cotton Candy Ice Cream",
				View = {
					Model = Models["IceCream"]:FindFirstChild("Cotton Candy Ice Cream"),
				},
			},
			['Pistachio'] = {
				ItemName = "Pistachio Ice Cream",	
				View = {
					Model = Models["IceCream"]:FindFirstChild("Pistachio Ice Cream"),
				},
			},
			['Strawberry'] = {
				ItemName = "Strawberry Ice Cream",
				View = {
					Model = Models["IceCream"]:FindFirstChild("Strawberry Ice Cream"),
				},
			},
		}
	},

	['Macarons'] = {
		Icon = 'rbxassetid://5200090620',
		Color = Color3.fromRGB(82, 82, 242),
		LayoutOrder = 8,
		Items = {
			['Vanilla'] = {
				ItemName = "Vanilla Macaron",
				View = {
					Model = Models["Macaron"]:FindFirstChild("Vanilla Macaron"),
				},
			},
			['Chocolate'] = {
				ItemName = "Chocolate Macaron",
				View = {
					Model = Models["Macaron"]:FindFirstChild("Chocolate Macaron"),
				},
			},
			['Mint'] = {
				ItemName = "Mint Macaron",
				View = {
					Model = Models["Macaron"]:FindFirstChild("Mint Macaron"),
				},
			},
			['Caramel Cake'] = {
				ItemName = "Caramel Macaron",
				View = {
					Model = Models["Macaron"]:FindFirstChild("Caramel Macaron"),
				},
			},
			['Cookies n\' Cream'] = {
				ItemName = "Cookies n' Cream Macaron",
				View = {
					Model = Models["Macaron"]:FindFirstChild("Cookies n' Cream Macaron"),
				},
			},
			['Blueberry'] = {
				ItemName = "Blueberry Macaron",
				View = {
					Model = Models["Macaron"]:FindFirstChild("Blueberry Macaron"),
				},
			},
			['Strawberry'] = {
				ItemName = "Strawberry Macaron",
				View = {
					Model = Models["Macaron"]:FindFirstChild("Strawberry Macaron"),
				},
			},
			['Cherry'] = {
				ItemName = "Cherry Macaron",
				View = {
					Model = Models["Macaron"]:FindFirstChild("Cherry Macaron"),
				},
			},
		}
	},

	['Mochis'] = {
		Icon = 'rbxassetid://5200100905',
		Color = Color3.fromRGB(189, 82, 242),
		LayoutOrder = 9,
		Items = {
			['Mint'] = {
				ItemName = "Mint Mochi",
				View = {
					Model = Models["Mochi"]:FindFirstChild("Mint Mochi"),
				},
			},
			['Cookie & Cream'] = {
				ItemName = "Cookies n' Cream Mochi",
				View = {
					Model = Models["Mochi"]:FindFirstChild("Cookies n' Cream Mochi"),
				},
			},
			['Vanilla'] = {
				ItemName = "Vanilla Mochi",
				View = {
					Model = Models["Mochi"]:FindFirstChild("Vanilla Mochi"),
				},
			},
			['Strawberry'] = {
				ItemName = "Strawberry Mochi",
				View = {
					Model = Models["Mochi"]:FindFirstChild("Strawberry Mochi"),
				},
			},
			['Orange Cream'] = {
				ItemName = "Orange Cream Mochi",
				View = {
					Model = Models["Mochi"]:FindFirstChild("Orange Mochi"),
				},
			},
		}
	},

	['Others'] = {
		Icon = 'rbxassetid://5200075249',
		Color = Color3.fromRGB(153, 153, 153),
		LayoutOrder = 10,
		Items = {
			['Water'] = {
				ItemName = "Water",
				View = buildCupView("Water"),
				Select = {
					["Temperature"] = TEMPERATURE_COLD_HOT,
					["Size"] = SIZE_SMALL_MEDIUM_LARGE,
				},
				Options = {
					['Ice'] = true,
				},
			},
			['Cup'] = {
				ItemName = "Cup",
				View = buildCupView("Medium Clear Cup"),
				Select = {
					["Size"] = SIZE_SMALL_MEDIUM_LARGE,
				},
			},
			['Milk'] = {
				ItemName = "Milk",
				View = buildCupView("Milk"),
				Select = {
					["Size"] = SIZE_SMALL_MEDIUM_LARGE,
				},
			},
			['Flavored Milk'] = {
				ItemName = "Milk",
				View = buildCupView("Flavored Milk"),
				RequiredSelection = {
					['Syrup Flavor'] = SyrupFlavor,
				},
				Select = {
					["Size"] = SIZE_SMALL_MEDIUM_LARGE,
				},
			},
		}
	},
}

return FoodService