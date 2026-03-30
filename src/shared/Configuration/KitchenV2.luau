--[[
	==============================================================================
	KitchenData.lua
	==============================================================================
	Kitchen-side data. Defines how each station type behaves when a barista
	interacts with it. All ingredient/flavor data lives in MenuData — this file
	only needs to change when station behavior itself changes (new station type,
	different Apply logic, stock config change).

	WHAT LIVES HERE:
	  StationTypes  - How each station type validates and applies itself to a tool.
	                  Keyed by the same stationType strings used in MenuData.Recipes
	                  Slots. KitchenService registers world instances against these.
	  CupGivers     - Configuration for cup dispenser stations. Keyed by CupType
	                  attribute value (matches Recipe.CupType).
	  StaticGivers  - Non-drink item givers (Dessert Wrappers, Fridge, etc.)

	WHAT NO LONGER LIVES HERE:
	  - BobaFlavors / SyrupFlavors / TeaLeafTypes / JellyTypes / TapiocaTypes
	    (all in MenuData — read from there directly)
	  - ValidRecipes / Actions action tables
	    (replaced by StationTypes + MenuData.Recipes)
	  - Stocking defaults
	    (in MenuData.Stocking — KitchenService reads them from there)

	STATION TYPE FIELDS:
	  Slot            The recipe slot id this station fills (matches a Slot.id in
	                  MenuData.Recipes). nil for stations with no slot (cup givers,
	                  finalize stations, giver-only stations).
	  CupTypeRequired The CupType attribute value the held tool must have. nil means
	                  any cup is accepted (e.g. IceMachine works for both cup types).
	  BlockIfFilled   If true, the station refuses if the slot is already filled.
	                  Default true for all ingredient stations.
	  Apply           function(tool, ingredientData, stationModel)
	                  Called by KitchenService when all checks pass. Writes the slot
	                  attribute onto the tool and applies any visual changes.
	                  ingredientData is the matching entry from the MenuData flavor
	                  table (has .Color, .StockType, etc.), or nil for stations that
	                  don't carry a specific ingredient (Ice Machine, Sugar, etc.).

	LICENSE:
	Copyright (C) bongusbingis - All Rights Reserved
	Code associated to this script applies under the Copyright, Designs and Patents Act 1988.
]]

local KitchenData = {}

-- ============================================================================
-- STATION TYPES
-- Each key matches a stationType value used in MenuData.Recipes Slots.
-- KitchenService looks up the station type when a ProximityPrompt fires and
-- runs the checks and Apply function defined here.
-- ============================================================================

KitchenData.StationTypes = {

	-- ------------------------------------------------------------------
	-- FlavorPowder
	-- Boba flavor powder bowls. One world instance per BobaFlavor entry.
	-- KitchenService spawns and registers these at startup.
	-- ------------------------------------------------------------------
	["FlavorPowder"] = {
		Slot = "Flavor",
		CupTypeRequired = "BobaCup",
		BlockIfFilled = true,
		Apply = function(tool: Tool, ingredientData: table)
			tool:SetAttribute("Flavor", ingredientData.Name)
			local liquid = tool:FindFirstChild("Liquid")
			if liquid then
				liquid.Color = ingredientData.Color
				liquid.Transparency = 0
			end
			-- Seasonal: neon tint on liquid and topping parts
			if ingredientData.Seasonal then
				for _, partName in { "Liquid", "Tapioca", "Jelly" } do
					local part = tool:FindFirstChild(partName)
					if part then
						part.Material = Enum.Material.Neon
					end
				end
			end
		end,
	},

	-- ------------------------------------------------------------------
	-- Milk
	-- Whole milk carton pour. One fixed station in the kitchen.
	-- ------------------------------------------------------------------
	["Milk"] = {
		Slot = "Milk",
		CupTypeRequired = "BobaCup",
		BlockIfFilled = true,
		Apply = function(tool: Tool, _ingredientData: table)
			tool:SetAttribute("Milk", true)
			local liquid = tool:FindFirstChild("Liquid")
			if liquid then
				liquid.Transparency = 0
			end
		end,
	},

	-- ------------------------------------------------------------------
	-- ToppingBar
	-- The topping selection station (tapioca + jelly).
	-- KitchenService presents a selection prompt; the chosen topping name
	-- is passed back as ingredientData.Name.
	-- ------------------------------------------------------------------
	["ToppingBar"] = {
		Slot = "Topping",
		CupTypeRequired = "BobaCup",
		BlockIfFilled = true,
		Apply = function(tool: Tool, ingredientData: table)
			tool:SetAttribute("Topping", ingredientData.Name)
			-- Show the correct topping part and tint it
			local isTapioca = ingredientData.Name:find("Tapioca")
			local partName = isTapioca and "Tapioca" or "Jelly"
			local part = tool:FindFirstChild(partName)
			if part then
				part.Transparency = 0
				part.Color = ingredientData.Color
			end
		end,
	},

	-- ------------------------------------------------------------------
	-- IceMachine
	-- Shared by boba and coffee. Presents a level selector prompt.
	-- The selected level string is passed as ingredientData.Name.
	-- ------------------------------------------------------------------
	["IceMachine"] = {
		Slot = "Ice",
		CupTypeRequired = nil, -- accepts both BobaCup and CoffeeCup
		BlockIfFilled = true,
		Apply = function(tool: Tool, ingredientData: table)
			-- ingredientData.Name = "Light" | "Regular" | "Extra"
			tool:SetAttribute("Ice", ingredientData.Name)
		end,
	},

	-- ------------------------------------------------------------------
	-- BobasSugar / CoffeeSugar
	-- Sugar level selection for boba and coffee respectively.
	-- Separate station types so they can be placed as different world
	-- objects while sharing nearly identical Apply logic.
	-- ------------------------------------------------------------------
	["BobasSugar"] = {
		Slot = "Sugar",
		CupTypeRequired = "BobaCup",
		BlockIfFilled = true,
		Apply = function(tool: Tool, ingredientData: table)
			-- ingredientData.Name = "Light" | "Regular" | "Extra"
			tool:SetAttribute("Sugar", ingredientData.Name)
		end,
	},

	["CoffeeSugar"] = {
		Slot = "Sugar",
		CupTypeRequired = "CoffeeCup",
		BlockIfFilled = true,
		Apply = function(tool: Tool, ingredientData: table)
			tool:SetAttribute("Sugar", ingredientData.Name)
		end,
	},

	-- ------------------------------------------------------------------
	-- SyrupPump
	-- Coffee syrup dispensers. One world instance per SyrupFlavor entry.
	-- KitchenService spawns and registers these at startup.
	-- ------------------------------------------------------------------
	["SyrupPump"] = {
		Slot = "Syrup",
		CupTypeRequired = "CoffeeCup",
		BlockIfFilled = true,
		Apply = function(tool: Tool, ingredientData: table)
			tool:SetAttribute("Syrup", ingredientData.Name)
			local liquid = tool:FindFirstChild("Liquid")
			if liquid then
				liquid.Color = ingredientData.Color
				liquid.Transparency = 0
			end
		end,
	},

	-- ------------------------------------------------------------------
	-- TeaLeaves
	-- Tea leaf dispensers. One world instance per TeaFlavor entry.
	-- ------------------------------------------------------------------
	["TeaLeaves"] = {
		Slot = "TeaLeaf",
		CupTypeRequired = "CoffeeCup",
		BlockIfFilled = true,
		Apply = function(tool: Tool, ingredientData: table)
			tool:SetAttribute("TeaLeaf", ingredientData.Name)
			local liquid = tool:FindFirstChild("Liquid")
			if liquid then
				liquid.Color = ingredientData.Color
				liquid.Transparency = 0
			end
		end,
	},

	-- ------------------------------------------------------------------
	-- HotWater
	-- Single fixed station. Sets the HotWater slot and reveals liquid.
	-- ------------------------------------------------------------------
	["HotWater"] = {
		Slot = "HotWater",
		CupTypeRequired = "CoffeeCup",
		BlockIfFilled = true,
		Apply = function(tool: Tool, _ingredientData: table)
			tool:SetAttribute("HotWater", true)
			local liquid = tool:FindFirstChild("Liquid")
			if liquid then
				liquid.Color = Color3.fromRGB(57, 160, 220)
				liquid.Transparency = 0
			end
		end,
	},

	-- ------------------------------------------------------------------
	-- Creamer
	-- Optional add-in for coffee. Single fixed station.
	-- ------------------------------------------------------------------
	["Creamer"] = {
		Slot = "Creamer",
		CupTypeRequired = "CoffeeCup",
		BlockIfFilled = true,
		Apply = function(tool: Tool, _ingredientData: table)
			tool:SetAttribute("Creamer", true)
		end,
	},

	-- ------------------------------------------------------------------
	-- CoffeeLid
	-- Attaches a lid to a coffee/tea cup. Required before finalization.
	-- ------------------------------------------------------------------
	["CoffeeLid"] = {
		Slot = "Lid",
		CupTypeRequired = "CoffeeCup",
		BlockIfFilled = true,
		Apply = function(tool: Tool, _ingredientData: table)
			tool:SetAttribute("Lid", true)
			local lid = tool:FindFirstChild("Lid")
			if lid then
				lid.Transparency = 0
			end
		end,
	},

	-- ------------------------------------------------------------------
	-- CupSleeve
	-- Optional sleeve for coffee cups. Not a recipe slot — it's cosmetic.
	-- Slot = nil means KitchenService skips slot validation entirely.
	-- ------------------------------------------------------------------
	["CupSleeve"] = {
		Slot = nil,
		CupTypeRequired = nil,
		BlockIfFilled = false,
		-- Blocks if already sleeved via the Sleeved attribute
		BlockIfAttribute = "Sleeved",
		Apply = function(tool: Tool, _ingredientData: table)
			tool:SetAttribute("Sleeved", true)
			local sleeve = tool:FindFirstChild("Sleeve")
			if sleeve then
				sleeve.Transparency = 0
			end
		end,
	},

	-- ------------------------------------------------------------------
	-- LidSealer
	-- Seals the lid on a boba cup. Required before a straw can be added.
	-- ------------------------------------------------------------------
	["LidSealer"] = {
		Slot = "HasLid",
		CupTypeRequired = "BobaCup",
		BlockIfFilled = true,
		-- LidSealer runs a special client prompt (lid sealing minigame).
		-- KitchenService checks for this flag and handles the prompt before Apply.
		IsLidSealer = true,
		Apply = function(tool: Tool, _ingredientData: table)
			tool:SetAttribute("HasLid", true)
			local lid = tool:FindFirstChild("Lid")
			if lid then
				lid.Transparency = 0.4
			end
		end,
	},

	-- ------------------------------------------------------------------
	-- BobaStraw
	-- Customer-facing station. Adds a straw after the lid is sealed.
	-- ------------------------------------------------------------------
	["BobaStraw"] = {
		Slot = "HasStraw",
		CupTypeRequired = "BobaCup",
		BlockIfFilled = true,
		CustomerCanUse = true,
		RequiresAttribute = "HasLid", -- tool must have this attribute set first
		Apply = function(tool: Tool, ingredientData: table)
			-- ingredientData.Color = randomly chosen straw color (set by KitchenService)
			tool:SetAttribute("HasStraw", true)
			local straw = tool:FindFirstChild("Straw")
			if straw then
				straw.Transparency = 0
				straw.Color = ingredientData.Color
			end
		end,
	},

	-- ------------------------------------------------------------------
	-- Blender
	-- Finalize station for MilkTea. KitchenService checks IsRecipeComplete
	-- before allowing use. Runs a client blending prompt, then finalizes.
	-- ------------------------------------------------------------------
	["Blender"] = {
		Slot = nil,
		IsFinalize = true,
		CupTypeRequired = "BobaCup",
		Apply = function(tool: Tool, _ingredientData: table)
			-- Visual: mark the drink as finalized
			tool:SetAttribute("Finalized", true)
		end,
	},

	-- ------------------------------------------------------------------
	-- CoffeeStirrer
	-- Finalize station for Coffee and Tea.
	-- ------------------------------------------------------------------
	["CoffeeStirrer"] = {
		Slot = nil,
		IsFinalize = true,
		CupTypeRequired = "CoffeeCup",
		Apply = function(tool: Tool, _ingredientData: table)
			tool:SetAttribute("Finalized", true)
		end,
	},
}

-- ============================================================================
-- CUP GIVERS
-- Configuration for cup dispenser stations. Keyed by the CupType attribute
-- value that will be stamped onto the tool when the cup is grabbed.
-- KitchenService uses these to set up ProximityPrompts on cup giver models.
--
-- Fields:
--   ModelName     The name of the world model to find via GetMatchingInstances
--   Sizes         Available size options shown in the selection prompt
--   StockDefaults DefaultStock and MaxInStorage for the StockingService
--   GetTool       function(size) → the Tool instance from KitchenStorage
-- ============================================================================

local KitchenStorage = game:GetService("ReplicatedStorage"):WaitForChild("SharedStorage").KitchenStorage

KitchenData.CupGivers = {
	["BobaCup"] = {
		ModelName = "Boba Cups",
		DefaultStock = 20,
		MaxInStorage = 5,
		Sizes = {
			{ Label = "Small", Icon = "rbxassetid://15408176900", ToolName = "Small Boba Cup" },
			{ Label = "Medium", Icon = "rbxassetid://15408180585", ToolName = "Medium Boba Cup" },
			{ Label = "Large", Icon = "rbxassetid://15408181880", ToolName = "Large Boba Cup" },
		},
	},
	["CoffeeCup"] = {
		ModelName = "Coffee Cups",
		DefaultStock = 15,
		MaxInStorage = 5,
		Sizes = {
			{ Label = "Small", Icon = "rbxassetid://15408176900", ToolName = "Small Coffee Cup" },
			{ Label = "Medium", Icon = "rbxassetid://15408180585", ToolName = "Medium Coffee Cup" },
			{ Label = "Large", Icon = "rbxassetid://15408181880", ToolName = "Large Coffee Cup" },
		},
	},
}

-- ============================================================================
-- STATIC GIVERS
-- Non-drink item givers (dessert wrappers, fridge, pastry display, etc.)
-- These don't participate in the recipe/slot system. KitchenService sets up
-- their prompts and routes interactions directly.
--
-- Fields:
--   ModelName      World model name
--   DefaultStock   Starting stock count
--   MaxInStorage   Max storable before restock
--   PrettyName     Display name for UI/restock messages (optional)
--   RequiresCupType  If set, player must hold a tool with this CupType attribute.
--                    Used for Fridge/Pastry Display which need a Dessert Wrapper.
-- ============================================================================

KitchenData.StaticGivers = {
	["Dessert Wrappers"] = {
		ModelName = "Dessert Wrappers",
		DefaultStock = 10,
		MaxInStorage = 5,
		ToolName = "Dessert Wrapper",
	},
	["Fridge"] = {
		ModelName = "Fridge",
		DefaultStock = 10,
		MaxInStorage = 5,
		PrettyName = "Frozen Treats",
		RequiresCupType = "DessertWrapper",
		-- Fridge presents a selection prompt (FridgeSelect) handled by KitchenService
		UseSelectionPrompt = true,
	},
	["Pastry Display"] = {
		ModelName = "Pastry Display",
		DefaultStock = 10,
		MaxInStorage = 5,
		PrettyName = "Pastries",
		RequiresCupType = "DessertWrapper",
		UseSelectionPrompt = true,
	},
}

-- ============================================================================
-- SELECTION PROMPTS
-- Defines the options shown when a station requires a player to choose a value
-- before the Apply function runs. KitchenService checks for SelectionPrompt
-- on a station type and presents the prompt before calling Apply, passing the
-- selected option back as ingredientData.
--
-- Used by: IceMachine, BobasSugar, CoffeeSugar, ToppingBar
-- ============================================================================

KitchenData.SelectionPrompts = {
	["IceMachine"] = {
		Title = "Add Ice",
		Text = "Select an ice level!",
		Options = {
			{ Label = "Light", Icon = "rbxassetid://15813147054" },
			{ Label = "Regular", Icon = "rbxassetid://15813159185" },
			{ Label = "Extra", Icon = "rbxassetid://15813136747" },
		},
	},
	["BobasSugar"] = {
		Title = "Add Sugar",
		Text = "Select a sugar level!",
		Options = {
			{ Label = "Light", Icon = "rbxassetid://15813147054" },
			{ Label = "Regular", Icon = "rbxassetid://15813159185" },
			{ Label = "Extra", Icon = "rbxassetid://15813136747" },
		},
	},
	["CoffeeSugar"] = {
		Title = "Add Sugar",
		Text = "Select a sugar level!",
		Options = {
			{ Label = "Light", Icon = "rbxassetid://15813147054" },
			{ Label = "Regular", Icon = "rbxassetid://15813159185" },
			{ Label = "Extra", Icon = "rbxassetid://15813136747" },
		},
	},
	-- ToppingBar options are built dynamically from MenuData at runtime by
	-- KitchenService (MenuData.GetAllToppingOptions), not declared here.
}

return KitchenData
