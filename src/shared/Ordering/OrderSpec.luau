--!strict
--[[
	OrderSpec.luau
	What an order item asks for, and how a finished tool is graded against it.

	Pure and shared: the server validates and grades with it, and the client can
	use it for the ticket and recipe card. Specs are derived from the Menu
	(`FromMenuItem` / `FromOrderItem`); tools are graded from their attributes
	(`Match` / `PickTools`). Tool attribute names are `Item`, `Size`, `Syrup`,
	`Tapioca`, `Iced` and `Sugar` (stations also write `Lid`, which nothing reads).
	Tool names are never read.

	The recipe card reads `Steps` (the rows for a spec) and `StepState` (which row
	is current and whether the held tool already has a mistake), both pure and
	computed from the spec and the held tool's attributes (REVIVAL-001 M1.2 design
	section 3.8). `Steps` returns {} for items without a card chain (see `Steps`).

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

-- One row of the recipe card (design 3.8).
export type Step = {
	Station: string, -- the Recipes.Items key the step uses (also the Model name to highlight)
	Choice: string?, -- the dialog button to pulse at that station; nil when the step opens no dialog
	Label: string, -- the card row text
	Optional: boolean?, -- reserved for rows a player may skip; no step sets it yet
}

export type Severity = "Wrong" | "Close"

-- A mistake the held tool already carries. `Match` would grade the finished tool
-- with the same Severity, and Reasons lists the same fields in the same order.
export type Problem = {
	Step: number?, -- index into Steps(spec); nil when the mistake has no row (ice or sugar nobody asked for)
	Severity: Severity,
	Reason: string, -- the first failing spec field: "Item", "Syrup", "Size", "Tapioca", "Iced" or "Sugar"
	Reasons: { string }, -- every failing field, in Match order (two Close mistakes together are Wrong)
}

type Table = { [string]: any }

-- A card row plus how to tell it is done (see isDone).
type Stage = {
	Step: Step,
	Item: string?, -- the tool's Item once this stage is done; nil for rows that only set a flag
	AnyItem: boolean?, -- done with any Item set (the coffee cup, whose next Item is an open choice)
	Field: string?, -- the attribute this row sets: "Size", "Syrup", "Tapioca", "Iced", "Sugar" or "Blended"
}

type Chain = {
	Stages: { Stage },
	Ranks: { [string]: number }, -- legitimate Item -> index of the stage that sets it
	FieldSteps: { [string]: number }, -- Field -> index of the stage that sets it
}

---> constants
local SYRUP_KEY = "Syrup Flavor"
local TAPIOCA_KEY = "Tapioca Flavor"
local SUGAR_KEY = "Sugar"
-- Menu spells the ice option "Ice" on Water and "Iced" on everything else.
local ICED_KEYS = { "Iced", "Ice" }

-- PENDING JACK: Q3 (M1.2 design 3.2). false = the Blender is not a boba step, as
-- recommended. true adds a Blender row between Syrup and Tapioca (the only place
-- its gate allows) that is done when the tool has Blended = true. Flipping it is
-- not enough on its own: Recipes.Items.Blender must write { Blended = true } and
-- Match must grade it (see the Blender note in Shared/Kitchen/Recipes), or the
-- row can never complete.
local REQUIRE_BLENDER = false

-- Grab items are picked at the Food Display, except ice cream (the Ice Cream
-- Freezer). The spec carries no category, so the Item name decides; every Menu
-- and Recipes ice cream ends this way (checked by the "Ice Creams" test).
local ICE_CREAM_SUFFIX = " Ice Cream"

-- Attributes that are `true` once set. Everything else on a card row is a string.
local FLAG_FIELDS: { [string]: boolean } = { Iced = true, Sugar = true, Blended = true }
-- The fields Match counts as minor mistakes, in its order.
local MINOR_FIELDS = { "Size", "Tapioca", "Iced", "Sugar" }

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

-- A cup row: the player picks a size in the cup's dialog. `anyItem` is for the
-- coffee cup, whose next Item (the coffee type) is a choice we cannot list.
local function cupStage(cup: string, size: string, anyItem: boolean): Stage
	return {
		Step = { Station = cup, Choice = size, Label = size .. " " .. cup },
		Item = cup,
		AnyItem = anyItem,
		Field = "Size",
	}
end

-- The card rows for a spec, or nil when the item has no card chain: teas, water
-- (PENDING JACK: Q22), smoothies, the bare Clear Cup and anything else whose
-- fields match no chain below. Chains follow M1.2 design 3.2.
local function buildStages(spec: OrderSpec): { Stage }?
	if spec.Kind == "Grab" then
		local isIceCream = string.sub(spec.Item, -#ICE_CREAM_SUFFIX) == ICE_CREAM_SUFFIX
		local station = if isIceCream then "Ice Cream Freezer" else "Food Display"
		-- The picker's button text is the item name.
		return { { Step = { Station = station, Choice = spec.Item, Label = spec.Item }, Item = spec.Item } }
	end

	local size = spec.Size
	if size == nil then
		return nil
	end

	if size == "Mug" then
		-- Hot cocoa: Mug -> steamed Milk -> the flavour's powder station, which is
		-- named after the item ("Caramel Hot Chocolate Powder").
		local powder = spec.Item .. " Powder"
		return {
			{ Step = { Station = "Mug", Label = "Mug" }, Item = "Mug", Field = "Size" },
			{ Step = { Station = "Milk", Label = "Steamed Milk" }, Item = "Milk" },
			{ Step = { Station = powder, Label = powder }, Item = spec.Item },
		}
	end

	local syrup, tapioca = spec.Syrup, spec.Tapioca
	if syrup ~= nil and tapioca ~= nil then
		-- Boba: Clear Cup (size) -> Milk -> Syrup -> [Blender] -> Tapioca.
		local stages: { Stage } = {
			cupStage("Clear Cup", size, false),
			{ Step = { Station = "Milk", Label = "Milk" }, Item = "Milk" },
			{
				Step = { Station = syrup .. " Syrup", Label = syrup .. " Syrup" },
				Item = "Flavored Milk",
				Field = "Syrup",
			},
		}
		if REQUIRE_BLENDER then
			table.insert(stages, { Step = { Station = "Blender", Label = "Blender" }, Field = "Blended" })
		end
		table.insert(stages, {
			Step = { Station = tapioca .. " Tapioca", Label = tapioca .. " Tapioca" },
			Item = spec.Item,
			Field = "Tapioca",
		})
		return stages
	end

	if spec.Iced ~= nil and spec.Sugar ~= nil then
		-- Coffee: Cup (size) -> Coffee Machine (type) -> [Ice Machine] -> [Sugar].
		-- Ice and sugar are rows only when the order asks for them.
		local stages: { Stage } = {
			cupStage("Cup", size, true),
			{
				Step = { Station = "Coffee Machine", Choice = spec.Item, Label = spec.Item },
				Item = spec.Item,
			},
		}
		if spec.Iced then
			table.insert(stages, { Step = { Station = "Ice Machine", Label = "Ice" }, Field = "Iced" })
		end
		if spec.Sugar then
			table.insert(stages, { Step = { Station = "Sugar", Label = "Sugar" }, Field = "Sugar" })
		end
		return stages
	end

	return nil
end

local function buildChain(spec: OrderSpec): Chain?
	if typeof(spec) ~= "table" or typeof(spec.Item) ~= "string" then
		return nil
	end
	local stages = buildStages(spec)
	if stages == nil then
		return nil
	end

	local ranks: { [string]: number } = {}
	local fieldSteps: { [string]: number } = {}
	for index, stage in stages do
		if stage.Item ~= nil then
			ranks[stage.Item] = index
		end
		if stage.Field ~= nil then
			fieldSteps[stage.Field] = index
		end
	end
	return { Stages = stages, Ranks = ranks, FieldSteps = fieldSteps }
end

-- Design 3.8 "done when": the row's Item has been reached (or a later stage's),
-- and the attribute it sets is present.
local function isDone(chain: Chain, index: number, attrs: Table): boolean
	local stage = chain.Stages[index]

	if stage.Item ~= nil then
		local item = attrs.Item
		if typeof(item) ~= "string" then
			return false
		end
		if not stage.AnyItem then
			local rank = chain.Ranks[item]
			if rank == nil or rank < index then
				return false
			end
		end
	end

	local field = stage.Field
	if field == nil then
		return true
	end
	local value = attrs[field]
	if FLAG_FIELDS[field] then
		return value == true
	end
	return value ~= nil
end

-- The mistake the held tool already has, if any, using Match's severities and
-- early returns: a wrong Item or Syrup is Wrong on its own, one minor mistake is
-- Close, two or more are Wrong. Only attributes already set count, since a missing
-- one is just a row still to do. `current` is the row the Item mistake is shown on.
local function findProblem(spec: OrderSpec, chain: Chain, attrs: Table, current: number): Problem?
	local item = attrs.Item
	if typeof(item) == "string" and chain.Ranks[item] == nil then
		return { Step = current, Severity = "Wrong", Reason = "Item", Reasons = { "Item" } }
	end

	if spec.Syrup ~= nil and attrs.Syrup ~= nil and attrs.Syrup ~= spec.Syrup then
		return { Step = chain.FieldSteps.Syrup, Severity = "Wrong", Reason = "Syrup", Reasons = { "Syrup" } }
	end

	local reasons: { string } = {}
	for _, field in MINOR_FIELDS do
		local wanted = (spec :: any)[field]
		local have = attrs[field]
		if wanted == nil or have == nil then
			continue
		end
		-- Ice and sugar are only ever set to true, so only an unwanted one is a mistake.
		local mistaken = if typeof(wanted) == "boolean" then have == true and wanted == false else have ~= wanted
		if mistaken then
			table.insert(reasons, field)
		end
	end
	if #reasons == 0 then
		return nil
	end
	return {
		Step = chain.FieldSteps[reasons[1]],
		Severity = if #reasons == 1 then "Close" else "Wrong",
		Reason = reasons[1],
		Reasons = reasons,
	}
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

-- The recipe card rows for a spec, in card order (design 3.8):
--   Boba   Clear Cup (Choice = size) -> Milk -> "<Syrup> Syrup" -> "<Tapioca> Tapioca"
--   Coffee Cup (Choice = size) -> Coffee Machine (Choice = coffee) -> Ice Machine -> Sugar
--          (Ice Machine and Sugar only when the spec asks for them)
--   Cocoa  Mug -> Milk -> "<Item> Powder"
--   Grab   Food Display or Ice Cream Freezer (Choice = the item)
-- Returns {} for items with no chain (teas and water, PENDING JACK: Q22; smoothies;
-- the bare Clear Cup): the card should not show. A fresh table on every call.
function OrderSpec.Steps(spec: OrderSpec): { Step }
	local steps: { Step } = {}
	local chain = buildChain(spec)
	if chain ~= nil then
		for index, stage in chain.Stages do
			steps[index] = stage.Step
		end
	end
	return steps
end

-- Where the held tool is in the spec's steps. `attrs` are the equipped tool's
-- attributes (nil when nothing is held). Returns:
--   current  the index of the first step that is not done: 1 when nothing is held,
--            #Steps(spec) + 1 when the tool is ready to serve
--   problem  nil, or the mistake the tool already carries (see Problem). The card
--            and OrderSpec.Match always agree on Severity:
--              Item or Syrup differs          -> Wrong
--              Size / Tapioca / Iced / Sugar  -> Close, or Wrong when two or more
--            An Item that is not part of the chain is shown on `current`.
-- Items with no chain return (1, nil), as does a tool with no attributes.
function OrderSpec.StepState(spec: OrderSpec, attrs: Table?): (number, Problem?)
	local chain = buildChain(spec)
	if chain == nil or typeof(attrs) ~= "table" then
		return 1, nil
	end

	local current = #chain.Stages + 1
	for index = 1, #chain.Stages do
		if not isDone(chain, index, attrs) then
			current = index
			break
		end
	end

	return current, findProblem(spec, chain, attrs, current)
end

return OrderSpec
