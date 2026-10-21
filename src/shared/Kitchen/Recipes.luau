--[[
    Module: Recipes
    Description: Pure data definitions mapping recipe names to their ordered action lists.

    WARNING: This file must never contain server logic, RemoteEvent calls,
    or any code that has side effects. It is intended to be safe for
    replication to the client. Keep it as plain data only.

    Tools come from SharedStorage.Tools.Kitchen through RecipeConstructors.getTool,
    which warns and returns nil when a tool is missing. A recipe whose tools are
    all missing is left out of Recipes.Items instead of erroring the require.

    Tool attributes (REVIVAL-001 M1.1 section 3): each station ends with a
    { "SetToolAttributes", { ... } } step (the givers pass attributes to GiveTool
    instead), so a station whose validity check fails leaves the tool unmarked. The
    names are the OrderSpec contract: Item, Size, Syrup, Tapioca, Iced, Sugar and Lid.
    `Item` must equal the Menu item's `ServeItem or ItemName`. Tool names are
    unchanged and are still what the validity checks read.
--]]

---> Modules

local RecipeConstructors = require(script.Parent.RecipeConstructors)

local makeCoffeeVariant = RecipeConstructors.makeCoffeeVariant
local makeTeaVariant = RecipeConstructors.makeTeaVariant
local makeHotChocolateVariant = RecipeConstructors.makeHotChocolateVariant
local makeCupGiver = RecipeConstructors.makeCupGiver
local makeGrabSelector = RecipeConstructors.makeGrabSelector
local getTool = RecipeConstructors.getTool
local getTools = RecipeConstructors.getTools

---> Assets

local mugTool = getTool({ "Mug" })

local foodDisplayTools = getTools({
	{ "Mochi", "Orange Mochi" },
	{ "Mochi", "Mint Mochi" },
	{ "Mochi", "Strawberry Mochi" },
	{ "Mochi", "Vanilla Mochi" },
	{ "Mochi", "Cookies n' Cream Mochi" },
	{ "Macaron", "Vanilla Macaron" },
	{ "Macaron", "Cookies n' Cream Macaron" },
	{ "Macaron", "Caramel Macaron" },
	{ "Macaron", "Strawberry Macaron" },
	{ "Macaron", "Blueberry Macaron" },
	{ "Macaron", "Cherry Macaron" },
	{ "Macaron", "Mint Macaron" },
	{ "Macaron", "Chocolate Macaron" },
	{ "Pastry", "Fudge Brownie" },
})

local iceCreamTools = getTools({
	{ "IceCream", "Strawberry Ice Cream" },
	{ "IceCream", "Mint Ice Cream" },
	{ "IceCream", "Chocolate Ice Cream" },
	{ "IceCream", "Pistachio Ice Cream" },
	{ "IceCream", "Cookie Dough Ice Cream" },
	{ "IceCream", "Vanilla Ice Cream" },
	{ "IceCream", "Bubble Gum Ice Cream" },
	{ "IceCream", "Ube Ice Cream" },
	{ "IceCream", "Orange Sherbet Ice Cream" },
	{ "IceCream", "Cotton Candy Ice Cream" },
	{ "IceCream", "Cherry Sherbet Ice Cream" },
	{ "IceCream", "Watermelon Sherbet Ice Cream" },
})

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
	--["Avocado"] = Color3.fromRGB(104, 184, 88),
	["Strawberry Banana"] = Color3.fromRGB(255, 140, 194),
	["Taro"] = Color3.fromRGB(224, 166, 255),
	["Mango"] = Color3.fromRGB(255, 192, 92),
	--["Honeycomb"] = Color3.fromRGB(255, 222, 92),
	["Coconut"] = Color3.fromRGB(255, 254, 247),
	["Matcha"] = Color3.fromRGB(155, 227, 145),
	["Chocolate Banana"] = Color3.fromRGB(171, 140, 87),
	["Passion Fruit"] = Color3.fromRGB(255, 247, 105),
	["Thai Milk Tea"] = Color3.fromRGB(255, 170, 51),
	["Watermelon"] = Color3.fromRGB(255, 54, 111),
	["Strawberry"] = Color3.fromRGB(255, 112, 167),
	--["Almond"] = Color3.fromRGB(255, 254, 222),
	["Brown Sugar"] = Color3.fromRGB(227, 175, 98),
	["Lychee"] = Color3.fromRGB(255, 69, 122),
	["Chocolate"] = Color3.fromRGB(176, 119, 86),
	["Green Tea"] = Color3.fromRGB(117, 242, 99),
	--["Mint"] = Color3.fromRGB(212, 255, 222),
	["Raspberry"] = Color3.fromRGB(214, 113, 90),
	--["Orange"] = Color3.fromRGB(255, 169, 89),
	["Cherry"] = Color3.fromRGB(255, 69, 78),
	--["Earl Grey"] = Color3.fromRGB(255, 89, 0),
	["Guava"] = Color3.fromRGB(235, 173, 131),
	["Dragon Fruit"] = Color3.fromRGB(255, 5, 47),
}

-- Q14: the Sugar and Ice Machine gates read attributes, so the coffee Item values
-- drop the "=" name-pattern prefix getCoffeeNames stores. Evaluated while
-- Recipes.Items is built, after the Coffee Machine branches register.
local function coffeeItemList(): string
	local names: { string } = {}
	for _, name in RecipeConstructors.getCoffeeNames() do
		table.insert(names, (name:gsub("^=", "")))
	end
	return table.concat(names, "|")
end

Recipes.Items = {
	["Clear Cup"] = makeCupGiver("Clear Cup"),
	["Cup"] = makeCupGiver("Cup"),

	["Mug"] = mugTool and {
		HoldDuration = 0,
		Actions = {
			--{ "AnimateRaw", Animations.Grab_01, true },
			{ "GiveTool", mugTool, { Size = "Mug" } }, -- Item defaults to the tool name, "Mug"
		},
	} or nil,

	["Sink"] = {
		Sound = "Sink",
		SkillMoment = true, -- BIG-B7 pour meter
		HoldDuration = 3,
		Actions = {
			{ "ToolNameValidityCheck", { "#Cup|!Milk" } },
			{
				"SelectFrom",
				{
					Title = "Sink",
					Text = "Choose water temperature:",
					Buttons = {
						{ Text = "Cold Water", Color = Color3.fromRGB(100, 170, 240) },
						{ Text = "Hot Water", Color = Color3.fromRGB(210, 100, 80) },
					},
				},
				{
					["Cold Water"] = {
						{ "SetToolHoldingProperty", "Liquid", "Color", Color3.fromRGB(100, 186, 253) },
						{ "SetToolHoldingProperty", "Liquid", "Transparency", 0 },
						{
							"RenameToolHolding",
							function(old: string)
								local size = old:split(" ")[1]
								return size .. " Cold Water"
							end,
						},
						{ "SetToolAttributes", { Item = "Water" } },
					},
					["Hot Water"] = {
						{ "SetToolHoldingProperty", "Liquid", "Color", Color3.fromRGB(255, 180, 140) },
						{ "SetToolHoldingProperty", "Liquid", "Transparency", 0 },
						{
							"RenameToolHolding",
							function(old: string)
								local size = old:split(" ")[1]
								return size .. " Hot Water"
							end,
						},
						{ "SetToolAttributes", { Item = "Water" } },
					},
				},
			},
		},
	},

	["Milk"] = {
		Sound = "Pour",
		SkillMoment = true, -- BIG-B7 pour meter
		HoldDuration = 2,
		Actions = {
			{ "ToolNameValidityCheck", { "#Clear Cup|=Mug" } },
			{ "SetToolHoldingProperty", "Liquid", "Color", Color3.new(1, 1, 1) },
			{ "SetToolHoldingProperty", "Liquid", "Transparency", 0 },
			{
				"RenameToolHolding",
				function(old: string)
					local isMug = old:find("Mug") ~= nil
					local append = isMug and " + Steamed Milk" or " + Milk"
					return old .. append
				end,
			},
			{ "SetToolAttributes", { Item = "Milk" } },
		},
	},

	["Coffee Machine"] = {
		Sound = "Machine",
		SkillMoment = true, -- BIG-B7 pour meter
		HoldDuration = 4, -- TUNING (Q14)
		Actions = {
			{ "ToolNameValidityCheck", { "#Cup", "!Clear" } },
			{
				"SelectFrom",
				{
					Title = "Coffee Machine",
					Text = "Choose a coffee:",
					DialogType = "PromptSelection",
					Buttons = {
						{ Text = "Regular" },
						{ Text = "Decaf" },
						{ Text = "Espresso" },
						{ Text = "Cappuccino" },
						{ Text = "Americano" },
						{ Text = "Cortado" },
						{ Text = "Koa Coffee" },
					},
					Items = {
						{ Name = "Regular", ModelName = "Medium Cup" },
						{ Name = "Decaf", ModelName = "Medium Cup" },
						{ Name = "Espresso", ModelName = "Medium Cup" },
						{ Name = "Cappuccino", ModelName = "Medium Cup" },
						{ Name = "Americano", ModelName = "Medium Cup" },
						{ Name = "Cortado", ModelName = "Medium Cup" },
						{ Name = "Koa Coffee", ModelName = "Medium Cup" },
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
		Sound = "Powder",
		HoldDuration = 1,
		Actions = {
			{ "ToolAttributeCheck", { Item = coffeeItemList(), Sugar = false } },
			{
				"RenameToolHolding",
				function(old: string)
					return old .. " + Sugar"
				end,
			},
			{ "SetToolAttributes", { Sugar = true } },
		},
	},

	["Ice Machine"] = {
		Sound = "IceCubes",
		HoldDuration = 3, -- TUNING (Q14)
		Actions = {
			{ "ToolAttributeCheck", { Item = coffeeItemList(), Iced = false } },
			{
				"RenameToolHolding",
				function(old: string)
					return "Iced " .. old
				end,
			},
			{ "SetToolAttributes", { Iced = true } },
		},
	},

	["Blender"] = {
		Sound = "Blender",
		HoldDuration = 5,
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
			-- No SetToolAttributes: blending is optional and OrderSpec does not match it
			-- (PENDING JACK: Q3). If Jack requires the Blender, add
			-- { "SetToolAttributes", { Blended = true } } here and a `Blended` field to
			-- OrderSpec.Match; nothing else changes.
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
		HoldDuration = 1,
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
			-- Recorded for the recipe card only; OrderSpec.Match does not read it in M1.
			{ "SetToolAttributes", { Lid = true } },
		},
	},

	---> food display
	["Food Display"] = makeGrabSelector("Food Display", "Choose a treat:", foodDisplayTools),

	---> ice cream freezer
	["Ice Cream Freezer"] = makeGrabSelector("Ice Cream Freezer", "Choose a flavor:", iceCreamTools),
}

for name: string, color: Color3 in Recipes.Syrups do
	Recipes.Items[name .. " Syrup"] = {
		Sound = "Pour",
		SkillMoment = true, -- BIG-B7 pour meter
		HoldDuration = 2,
		Actions = {
			{ "ToolNameValidityCheck", { "#Cup %+ Milk" } },
			{ "SetToolHoldingProperty", "Liquid", "Color", color },
			{ "RenameToolHolding", `Milk + {name} Syrup` },
			{ "SetToolAttributes", { Item = "Flavored Milk", Syrup = name } },
		},
	}
end

for name: string, color: Color3 in Recipes.Tapioca do
	local tapiocaFlavor = name -- the Tapioca key, which is the OrderSpec Tapioca value
	name = name .. " Tapioca"
	Recipes.Items[name] = {
		Sound = "Pop",
		HoldDuration = 2,
		Actions = {
			-- Accepts "Milk + [Flavor] Syrup" (straight from the syrup step) and the
			-- blended "[Flavor] Milk". Cup names ("... + Milk") are rejected.
			{ "ToolNameValidityCheck", { "#^Milk %+ .+ Syrup|#^[^%+]+ Milk" } },
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
					-- "Milk + [Flavor] Syrup" or "[Flavor] Milk" ---> "[Flavor] Boba"
					-- Anything after the flavor (e.g. " + Sugar") is kept.
					local flavor, rest = old:match("^Milk %+ (.+) Syrup(.*)$")
					if not flavor then
						flavor, rest = old:match("^([^%+]+) Milk(.*)$")
					end
					return flavor and (flavor .. " Boba" .. rest) or old
				end,
			},
			{ "SetToolAttributes", { Item = "Boba", Tapioca = tapiocaFlavor } },
		},
	}
end

return Recipes
