--!strict
--[[
	OrderSpec.luau
	What an order item asks for, and how a finished tool is graded against it.

	Pure and shared: the server validates and grades with it, and the client can
	use it for the ticket and recipe card. Specs are derived from the Menu
	(`FromMenuItem` / `FromOrderItem`); tools are graded from their attributes
	(`Match` / `PickTools`). Tool attribute names are `Item`, `Size`, `Syrup`,
	`Tapioca`, `Iced` and `Sugar`. Tool names are never read.

	Reasons returned by `FromMenuItem` / `FromOrderItem` name the CustomInfo key
	that failed ("Size", "Syrup Flavor", "Tapioca Flavor", "Iced" / "Ice",
	"Sugar"). Reasons returned by `Match` / `PickTools` name the spec field
	("Item", "Size", "Syrup", "Tapioca", "Iced", "Sugar", or "Missing").
--]]

---> types
export type Grade = "Perfect" | "Close" | "Wrong"

export type OrderSpec = {
	Kind: "Drink" | "Grab",
	Item: string, -- compared with the tool's "Item" attribute
	Size: string?, -- "Small" | "Medium" | "Large" | "Mug"; Drinks only
	Syrup: string?, -- set when the item has RequiredSelection "Syrup Flavor"
	Tapioca: string?, -- set when the item has RequiredSelection "Tapioca Flavor"
	Iced: boolean?, -- nil = the item has no ice option
	Sugar: boolean?, -- nil = the item has no sugar option
	Label: string, -- "Medium Custom Boba" (same format as the staff screen)
}

type Table = { [string]: any }

---> constants
local SYRUP_KEY = "Syrup Flavor"
local TAPIOCA_KEY = "Tapioca Flavor"
local SUGAR_KEY = "Sugar"
-- Menu spells the ice option "Ice" on Water and "Iced" on everything else.
local ICED_KEYS = { "Iced", "Ice" }

---> private
-- Shared.Ordering.Menu reads the authored SelectorModels, so it is required on the
-- first FromOrderItem call and not at require time. This keeps the rest of the
-- module usable without the place content.
local foodTable: Table? = nil
local menuFailed = false

local function getFoodTable(): Table?
	if foodTable == nil and not menuFailed then
		local ok, menu = pcall(function()
			local siblings: any = script.Parent
			return require(siblings.Menu)
		end)
		if ok and typeof(menu) == "table" and typeof(menu.FoodTable) == "table" then
			foodTable = menu.FoodTable
		else
			menuFailed = true
			warn("[OrderSpec] Shared.Ordering.Menu failed to load:", menu)
		end
	end
	return foodTable
end

-- The chosen key of a RequiredSelection group. Returns (nil, true) when the item
-- has no such group, (choice, true) for a valid choice, and (nil, false) when the
-- group exists but the choice is missing or not one of its keys.
local function readSelection(def: Table, customInfo: Table, groupName: string): (string?, boolean)
	local groups = def.RequiredSelection
	local group = if typeof(groups) == "table" then groups[groupName] else nil
	if group == nil then
		return nil, true
	end

	local chosen = customInfo[groupName]
	if typeof(group) ~= "table" or typeof(chosen) ~= "string" or group[chosen] == nil then
		return nil, false
	end
	return chosen, true
end

-- The value of a boolean option. The first of `keys` that the item offers in
-- def.Options is used: the CustomInfo value when it is a boolean, else the Menu
-- default. Returns (nil, nil) when the item offers none of them, and
-- (nil, key) when CustomInfo holds a non-boolean for it.
local function readOption(def: Table, customInfo: Table, keys: { string }): (boolean?, string?)
	local options = def.Options
	if typeof(options) ~= "table" then
		return nil, nil
	end

	for _, key in keys do
		local default = options[key]
		if default ~= nil then
			local chosen = customInfo[key]
			if chosen == nil then
				return default == true, nil
			elseif typeof(chosen) ~= "boolean" then
				return nil, key
			end
			return chosen, nil
		end
	end
	return nil, nil
end

---> public
local OrderSpec = {}

-- Derives a spec from a Menu item definition and the customer's choices.
-- Returns nil and the failing CustomInfo key for any invalid input.
function OrderSpec.FromMenuItem(def: Table, customInfo: Table): (OrderSpec?, string?)
	if typeof(def) ~= "table" then
		return nil, "Item"
	end
	if typeof(customInfo) ~= "table" then
		return nil, "CustomInfo"
	end

	local item = def.ServeItem or def.ItemName
	if typeof(item) ~= "string" then
		return nil, "Item"
	end
	local displayName: string = if typeof(def.ItemName) == "string" then def.ItemName else item

	local sizes = if typeof(def.Select) == "table" then def.Select.Size else nil
	local isDrink = typeof(sizes) == "table"

	local size: string? = nil
	if isDrink then
		local chosenSize = customInfo.Size
		if typeof(chosenSize) ~= "string" or table.find(sizes, chosenSize) == nil then
			return nil, "Size"
		end
		size = chosenSize
	end

	local syrup, syrupOk = readSelection(def, customInfo, SYRUP_KEY)
	if not syrupOk then
		return nil, SYRUP_KEY
	end

	local tapioca, tapiocaOk = readSelection(def, customInfo, TAPIOCA_KEY)
	if not tapiocaOk then
		return nil, TAPIOCA_KEY
	end

	local iced, badIcedKey = readOption(def, customInfo, ICED_KEYS)
	if badIcedKey ~= nil then
		return nil, badIcedKey
	end

	local sugar, badSugarKey = readOption(def, customInfo, { SUGAR_KEY })
	if badSugarKey ~= nil then
		return nil, badSugarKey
	end

	local spec: OrderSpec = {
		Kind = if isDrink then "Drink" else "Grab",
		Item = item,
		Size = size,
		Syrup = syrup,
		Tapioca = tapioca,
		Iced = iced,
		Sugar = sugar,
		Label = if size ~= nil then size .. " " .. displayName else displayName,
	}
	return spec, nil
end

-- Looks the item up in the server-side Menu (never the client's DefaultInfo) and
-- derives its spec. A missing CustomInfo counts as empty. Returns nil and the
-- failing field ("Category", "Item", "CustomInfo", "Menu" or a CustomInfo key).
function OrderSpec.FromOrderItem(
	orderItem: { Category: string, Item: string, CustomInfo: Table? }
): (OrderSpec?, string?)
	if typeof(orderItem) ~= "table" then
		return nil, "Item"
	end
	if typeof(orderItem.Category) ~= "string" then
		return nil, "Category"
	end
	if typeof(orderItem.Item) ~= "string" then
		return nil, "Item"
	end
	local customInfo = if orderItem.CustomInfo == nil then {} else orderItem.CustomInfo
	if typeof(customInfo) ~= "table" then
		return nil, "CustomInfo"
	end

	local menu = getFoodTable()
	if menu == nil then
		return nil, "Menu"
	end
	local category = menu[orderItem.Category]
	if typeof(category) ~= "table" then
		return nil, "Category"
	end
	local def = if typeof(category.Items) == "table" then category.Items[orderItem.Item] else nil
	if typeof(def) ~= "table" then
		return nil, "Item"
	end

	return OrderSpec.FromMenuItem(def, customInfo)
end

-- Grades one tool's attributes against a spec. Returns the grade and the spec
-- fields that were wrong, in the fixed order Item, Syrup, then Size, Tapioca,
-- Iced, Sugar. Extra attributes are ignored.
--   Item differs                 -> Wrong
--   Grab item                    -> Perfect
--   Syrup differs                -> Wrong
--   0 / 1 / 2+ minor mistakes    -> Perfect / Close / Wrong
-- A missing boolean attribute counts as false.
function OrderSpec.Match(spec: OrderSpec, attrs: Table): (Grade, { string })
	if attrs.Item ~= spec.Item then
		return "Wrong", { "Item" }
	end
	if spec.Kind == "Grab" then
		return "Perfect", {}
	end
	if spec.Syrup ~= nil and attrs.Syrup ~= spec.Syrup then
		return "Wrong", { "Syrup" }
	end

	local mistakes: { string } = {}
	if spec.Size ~= nil and attrs.Size ~= spec.Size then
		table.insert(mistakes, "Size")
	end
	if spec.Tapioca ~= nil and attrs.Tapioca ~= spec.Tapioca then
		table.insert(mistakes, "Tapioca")
	end
	if spec.Iced ~= nil and (attrs.Iced == true) ~= spec.Iced then
		table.insert(mistakes, "Iced")
	end
	if spec.Sugar ~= nil and (attrs.Sugar == true) ~= spec.Sugar then
		table.insert(mistakes, "Sugar")
	end

	if #mistakes == 0 then
		return "Perfect", mistakes
	elseif #mistakes == 1 then
		return "Close", mistakes
	end
	return "Wrong", mistakes
end

-- Assigns one candidate tool to each spec from a shared candidate list (held tool
-- first, then the backpack). Pass 1 gives each spec its first unused Perfect
-- candidate; pass 2 gives each spec still unfilled its first unused Close
-- candidate. A candidate is used at most once.
--   Every spec filled -> ({ candidate index per spec }, Close if any pick was
--                         Close else Perfect, {})
--   Any spec unfilled -> (nil, "Wrong", reasons). One spec: Match against the first
--                         candidate. Otherwise (or with no candidates): { "Missing" }.
function OrderSpec.PickTools(specs: { OrderSpec }, candidates: { Table }): ({ number }?, Grade, { string })
	local picked: { [number]: number } = {}
	local used: { [number]: boolean } = {}
	local anyClose = false

	for _, wanted in { "Perfect", "Close" } :: { Grade } do
		for specIndex, spec in specs do
			if picked[specIndex] ~= nil then
				continue
			end
			for candidateIndex, attrs in candidates do
				if used[candidateIndex] then
					continue
				end
				local grade = OrderSpec.Match(spec, attrs)
				if grade == wanted then
					picked[specIndex] = candidateIndex
					used[candidateIndex] = true
					anyClose = anyClose or grade == "Close"
					break
				end
			end
		end
	end

	local picks: { number } = {}
	for specIndex = 1, #specs do
		local candidateIndex = picked[specIndex]
		if candidateIndex == nil then
			if #specs == 1 and candidates[1] ~= nil then
				local _, reasons = OrderSpec.Match(specs[1], candidates[1])
				return nil, "Wrong", reasons
			end
			return nil, "Wrong", { "Missing" }
		end
		picks[specIndex] = candidateIndex
	end

	return picks, if anyClose then "Close" else "Perfect", {}
end

return OrderSpec
