--[[
    Module: Recipes
    Description: Pure data definitions mapping recipe names to their ordered action lists.

    WARNING: This file must never contain server logic, RemoteEvent calls,
    or any code that has side effects. It is intended to be safe for
    replication to the client. Keep it as plain data only.
--]]

---> Services

local ReplicatedStorage = game:GetService("ReplicatedStorage")

---> Assets

local SharedStorage = ReplicatedStorage:WaitForChild("SharedStorage")

local Tools = SharedStorage.Tools.Kitchen

---> Modules

local RecipeConstructors = require(script.Parent.RecipeConstructors)

local makeCoffeeVariant = RecipeConstructors.makeCoffeeVariant
local makeTeaVariant = RecipeConstructors.makeTeaVariant
local makeHotChocolateVariant = RecipeConstructors.makeHotChocolateVariant
local makeCupGiver = RecipeConstructors.makeCupGiver
local makeGrabSelector = RecipeConstructors.makeGrabSelector

---> Recipes

local Recipes = {}

Recipes.Tapioca = {
	["Fruity Twist"] = Color3.fromRGB(230, 170, 156),
	["Passion Madness"] = Color3.fromRGB(135, 197, 204),
	["Mystic Burst"] = Color3.fromRGB(183, 150, 227),
	["Tropical Heaven"] = Color3.fromRGB(207, 242, 203),
	["Marshmallow Delight"] = Color3.fromRGB(252, 255, 253),
	["Normal"] = Color3.fromRGB(17, 17, 17),
	["Strawberry"] = Color3.fromRGB(214, 94, 100),
	["Banana Blast"] = Color3.fromRGB(245, 240, 174),
	["Tutti Frutti"] = Color3.fromRGB(171, 196, 219),
	["Pumpkin Paradise"] = Color3.fromRGB(247, 189, 126),
}

Recipes.Syrups = {
	["Classic Milk Tea"] = Color3.fromRGB(255, 250, 214),
	["Avocado"] = Color3.fromRGB(104, 184, 88),
	["Strawberry Banana"] = Color3.fromRGB(255, 140, 194),
	["Taro"] = Color3.fromRGB(224, 166, 255),
	["Mango"] = Color3.fromRGB(255, 192, 92),
	["Honeycomb"] = Color3.fromRGB(255, 222, 92),
	["Coconut"] = Color3.fromRGB(255, 254, 247),
	["Matcha"] = Color3.fromRGB(155, 227, 145),
	["Chocolate Banana"] = Color3.fromRGB(171, 140, 87),
	["Passion Fruit"] = Color3.fromRGB(255, 247, 105),
	["Thai Milk Tea"] = Color3.fromRGB(255, 170, 51),
	["Watermelon"] = Color3.fromRGB(255, 54, 111),
	["Strawberry"] = Color3.fromRGB(255, 112, 167),
	["Almond"] = Color3.fromRGB(255, 254, 222),
	["Brown Sugar"] = Color3.fromRGB(227, 175, 98),
	["Lychee"] = Color3.fromRGB(255, 69, 122),
	["Chocolate"] = Color3.fromRGB(176, 119, 86),
	["Green Tea"] = Color3.fromRGB(117, 242, 99),
	["Mint"] = Color3.fromRGB(212, 255, 222),
	["Raspberry"] = Color3.fromRGB(214, 113, 90),
	["Orange"] = Color3.fromRGB(255, 169, 89),
	["Cherry"] = Color3.fromRGB(255, 69, 78),
	["Earl Grey"] = Color3.fromRGB(255, 89, 0),
	["Guava"] = Color3.fromRGB(235, 173, 131),
	["Dragon Fruit"] = Color3.fromRGB(255, 5, 47),
}

Recipes.Items = {
	["Clear Cup"] = makeCupGiver("Clear Cup"),
	["Cup"] = makeCupGiver("Cup"),

	["Mug"] = {
		HoldDuration = 0,
		Actions = {
			--{ "AnimateRaw", Animations.Grab_01, true },
			{ "GiveTool", Tools["Mug"] },
		},
	},

	["Milk"] = {
		Actions = {
			{ "ToolNameValidityCheck", { "#Clear Cup|=Mug" } },
			{ "SetToolHoldingProperty", "Liquid", "Color", Color3.new(1, 1, 1) },
			{ "SetToolHoldingProperty", "Liquid", "Transparency", 0 },
			{
				"RenameToolHolding",
				function(old: string)
					return old .. " + Milk"
				end,
			},
		},
	},

	["Coffee Machine"] = {
		HoldDuration = 7,
		Actions = {
			{ "ToolNameValidityCheck", { "#Cup", "!Clear" } },
			{
				"SelectFrom",
				{
					Title = "Coffee Machine",
					Text = "Choose a coffee:",
					Buttons = {
						{ Text = "Regular" },
						{ Text = "Decaf" },
						{ Text = "Espresso" },
						{ Text = "Cappuccino" },
						{ Text = "Americano" },
						{ Text = "Cortado" },
						{ Text = "Koa Coffee" },
					},
				},
				{
					["Regular"] = makeCoffeeVariant("Regular", Color3.fromRGB(204, 161, 135)),
					["Decaf"] = makeCoffeeVariant("Decaf", Color3.fromRGB(128, 101, 84)),
					["Espresso"] = makeCoffeeVariant("Espresso", Color3.fromRGB(217, 137, 87)),
					["Cappuccino"] = makeCoffeeVariant("Cappuccino", Color3.fromRGB(255, 194, 140)),
					["Americano"] = makeCoffeeVariant("Americano", Color3.fromRGB(134, 102, 73)),
					["Cortado"] = makeCoffeeVariant("Cortado", Color3.fromRGB(212, 151, 97)),
					["Koa Coffee"] = makeCoffeeVariant("Koa Coffee", Color3.fromRGB(168, 129, 108)),
				},
			},
		},
	},

	["Sugar"] = {
		Actions = {
			{ "ToolNameValidityCheck", { "!Sugar" } },
			{
				"RenameToolHolding",
				function(old: string)
					return old .. " + Sugar"
				end,
			},
		},
	},

	["Ice Machine"] = {
		HoldDuration = 5,
		Actions = {
			{ "ToolNameValidityCheck", { table.concat(RecipeConstructors.getCoffeeNames(), "|") .. "|=Tea", "!Clear", "!Ice" } },
			{ "SetToolHoldingProperty", "Liquid", "Transparency", 0.5 },
			{
				"RenameToolHolding",
				function(old: string)
					return old .. " + Ice"
				end,
			},
		},
	},

	["Blender"] = {
		Actions = {
			{ "ToolNameValidityCheck", { "#Milk", "#Syrup" } },
			{
				"SetToolHoldingProperty",
				"Liquid",
				"Color",
				function(liquid)
					return liquid.Color:Lerp(Color3.new(1, 1, 1), 0.5)
				end,
			},
			{
				"RenameToolHolding",
				function(old: string)
					-- old --> "[Flavor] Milk"
					local flavor = old:split(" ")
					flavor = table.concat(flavor, " ", 3, #flavor - 1)
					return flavor and (flavor .. " Milk") or ""
				end,
			},
		},
	},

    ---> hot chocolate
	["Hot Chocolate Powder"] = makeHotChocolateVariant("", Color3.fromRGB(176, 119, 86)),
	["Caramel Hot Chocolate Powder"] = makeHotChocolateVariant("Caramel", Color3.fromRGB(227, 151, 104)),
	["Vanilla Hot Chocolate Powder"] = makeHotChocolateVariant("Vanilla", Color3.fromRGB(248, 211, 189)),

    ---> tea
	["Caramel Chai Tea Powder"] = makeTeaVariant("Caramel Chai Tea", Color3.fromRGB(204, 161, 135)),
	["Lemon Tea Powder"] = makeTeaVariant("Lemon Tea", Color3.fromRGB(255, 194, 140)),
	["Green Tea Powder"] = makeTeaVariant("Green Tea", Color3.fromRGB(212, 151, 97)),
	["Earl Grey Tea Powder"] = makeTeaVariant("Earl Grey Tea", Color3.fromRGB(168, 129, 108)),
	["Peach Tea Powder"] = makeTeaVariant("Peach Tea", Color3.fromRGB(128, 101, 84)),
	["Vanilla Chai Tea Powder"] = makeTeaVariant("Vanilla Chai Tea", Color3.fromRGB(217, 137, 87)),

	["Lids"] = {
		Actions = {
			{
				"SetToolHoldingProperty",
				"CoffeeLid",
				"Transparency",
				function(part: MeshPart)
					local customValue = part:FindFirstChild("CustomValue")
					return customValue and customValue.Value or 0
				end,
			},
		},
	},

	---> food display
	["Food Display"] = makeGrabSelector("Food Display", "Choose a treat:", {
		Tools.Mochi["Orange Mochi"],
		Tools.Mochi["Mint Mochi"],
		Tools.Mochi["Strawberry Mochi"],
		Tools.Mochi["Vanilla Mochi"],
		Tools.Mochi["Cookies n' Cream Mochi"],
		Tools.Macaron["Vanilla Macaron"],
		Tools.Macaron["Cookies n' Cream Macaron"],
		Tools.Macaron["Caramel Macaron"],
		Tools.Macaron["Strawberry Macaron"],
		Tools.Macaron["Blueberry Macaron"],
		Tools.Macaron["Cherry Macaron"],
		Tools.Macaron["Mint Macaron"],
		Tools.Macaron["Chocolate Macaron"],
		Tools.Pastry["Fudge Brownie"],
	}),

	---> ice cream freezer
	["Ice Cream Freezer"] = makeGrabSelector("Ice Cream Freezer", "Choose a flavor:", {
		Tools.IceCream["Strawberry Ice Cream"],
		Tools.IceCream["Mint Ice Cream"],
		Tools.IceCream["Chocolate Ice Cream"],
		Tools.IceCream["Pistachio Ice Cream"],
		Tools.IceCream["Cookie Dough Ice Cream"],
		Tools.IceCream["Vanilla Ice Cream"],
		Tools.IceCream["Bubble Gum Ice Cream"],
		Tools.IceCream["Ube Ice Cream"],
		Tools.IceCream["Orange Sherbet Ice Cream"],
		Tools.IceCream["Cotton Candy Ice Cream"],
		Tools.IceCream["Cherry Sherbet Ice Cream"],
		Tools.IceCream["Watermelon Sherbet Ice Cream"],
	}),
}

for name: string, color: Color3 in Recipes.Syrups do
	Recipes.Items[name .. " Syrup"] = {
		Actions = {
			{ "ToolNameValidityCheck", { "#Cup %+ Milk" } },
			{ "SetToolHoldingProperty", "Liquid", "Color", color },
			{ "RenameToolHolding", `Milk + {name} Syrup` },
		},
	}
end

for name: string, color: Color3 in Recipes.Tapioca do
	name = name .. " Tapioca"
	Recipes.Items[name] = {
		Actions = {
			{ "ToolNameValidityCheck", { "# Milk" } },
			{
				"SetToolHoldingProperty",
				"Tapioca",
				"Color",
				color,
			},
			{
				"SetToolHoldingProperty",
				"Tapioca",
				"Transparency",
				0,
			},
			{
				"RenameToolHolding",
				function(old: string)
					-- [Flavor] Milk ---> [Flavor] Boba
					return old:gsub("Milk", "Boba")
				end,
			},
		},
	}
end

return Recipes
