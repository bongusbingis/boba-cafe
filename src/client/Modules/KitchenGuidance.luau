--!strict
--[[
	Module: KitchenGuidance
	Description: Pure logic behind the kitchen hints (M1.2 design 3.9, M1.5c/d). No Instances
	             are touched, so it is unit tested (server/Tests/KitchenGuidance.spec). The
	             Highlight, beam and toast code in KitchenController and AppDialogs calls it.

	Not a controller: Knit.AddControllersDeep only requires this file.
--]]

---> Dependencies

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local OrderSpec = require(ReplicatedStorage:WaitForChild("Shared").Ordering.OrderSpec)

---> Types

export type Point = { X: number, Y: number, Z: number } -- a Vector3 fits

export type Guidance = {
	Station: string?, -- the model name to highlight; nil at the Serve step
	Choice: string?, -- the dialog button to pulse at that station
	Label: string, -- "Medium Clear Cup", or "Serve your customer" at the Serve step
	IsServe: boolean, -- every step is done: the Highlight goes to the NPC
	Current: number,
	Total: number,
	Item: string, -- the spec's Item (the "first time each item appears" key)
}

export type BeamState = {
	CustomersSeen: number, -- distinct orders this session, counting the current one
	ItemSeenBefore: boolean, -- the current Item has been shown on an earlier order
	IdleSeconds: number, -- time since the held tool last changed
}

---> Constants

local KitchenGuidance = {}

-- TUNING (design 3.9): the beam shows for the first N customers of a session.
KitchenGuidance.BEAM_FIRST_CUSTOMERS = 3
-- TUNING (design 3.9): the beam shows again after this many seconds without progress.
KitchenGuidance.BEAM_IDLE_SECONDS = 20
-- TUNING (design 3.9): no more than this many Highlights exist at once.
KitchenGuidance.MAX_HIGHLIGHTS = 2
-- TUNING: stations that are never "the wrong station" (cleaning, lids, and the Blender
-- while PENDING JACK: Q3 is open). Using one is not a mistake to correct.
KitchenGuidance.NEUTRAL_STATIONS = { Sink = true, Lids = true, Blender = true } :: { [string]: boolean }

---> Public

-- The index of the nearest point to `origin` (straight-line distance), or nil for an
-- empty list. Ties keep the first.
function KitchenGuidance.NearestIndex(points: { Point }, origin: Point): number?
	local bestIndex: number? = nil
	local bestSquared = math.huge
	for index, point in points do
		local dx, dy, dz = point.X - origin.X, point.Y - origin.Y, point.Z - origin.Z
		local squared = dx * dx + dy * dy + dz * dz
		if squared < bestSquared then
			bestSquared = squared
			bestIndex = index
		end
	end
	return bestIndex
end

-- Turns whatever OrderController.CurrentOrder holds into an OrderSpec, or nil. The
-- ticket is the CustomerService NPC ticket { Id, NpcModel, Label, Spec = { Category,
-- Item, CustomInfo?, Size? }, PatienceEnd, PatienceTotal, Scripted, Rescue }; its
-- `.Spec` order item is resolved by `fromOrderItem` (normally OrderSpec.FromOrderItem).
-- A spec itself, a bare order item and a list whose first entry is one of those are
-- accepted too (notepad orders). Never errors.
function KitchenGuidance.ResolveSpec(order: any, fromOrderItem: (any) -> (any?, string?)): OrderSpec.OrderSpec?
	if typeof(order) ~= "table" then
		return nil
	end
	if typeof(order.Kind) == "string" and typeof(order.Item) == "string" and typeof(order.Label) == "string" then
		return order
	end
	if order.Spec ~= nil then
		return KitchenGuidance.ResolveSpec(order.Spec, fromOrderItem)
	end
	if typeof(order.Category) == "string" and typeof(order.Item) == "string" then
		local ok, spec = pcall(fromOrderItem, order)
		if ok and typeof(spec) == "table" then
			return spec
		end
		return nil
	end
	if order[1] ~= nil then
		return KitchenGuidance.ResolveSpec(order[1], fromOrderItem)
	end
	return nil
end

-- Resolves all OrderSpecs in an order (multi-item NPC tickets with .Items or .Specs,
-- notepad order arrays, or single-spec orders). Never errors.
function KitchenGuidance.ResolveSpecs(order: any, fromOrderItem: (any) -> (any?, string?)): { OrderSpec.OrderSpec }
	if typeof(order) ~= "table" then
		return {}
	end
	if typeof(order.Kind) == "string" and typeof(order.Item) == "string" and typeof(order.Label) == "string" then
		return { order }
	end

	if typeof(order.Specs) == "table" and #order.Specs > 0 then
		local list: { OrderSpec.OrderSpec } = {}
		for _, s in order.Specs do
			local spec = KitchenGuidance.ResolveSpec(s, fromOrderItem)
			if spec ~= nil then
				table.insert(list, spec)
			end
		end
		if #list > 0 then
			return list
		end
	end

	if typeof(order.Items) == "table" and #order.Items > 0 then
		local list: { OrderSpec.OrderSpec } = {}
		for _, it in order.Items do
			local spec = KitchenGuidance.ResolveSpec(it, fromOrderItem)
			if spec ~= nil then
				table.insert(list, spec)
			end
		end
		if #list > 0 then
			return list
		end
	end

	if order[1] ~= nil then
		local list: { OrderSpec.OrderSpec } = {}
		for _, it in ipairs(order) do
			local spec = KitchenGuidance.ResolveSpec(it, fromOrderItem)
			if spec ~= nil then
				table.insert(list, spec)
			end
		end
		if #list > 0 then
			return list
		end
	end

	if order.Spec ~= nil then
		local spec = KitchenGuidance.ResolveSpec(order.Spec, fromOrderItem)
		if spec ~= nil then
			return { spec }
		end
	end

	if typeof(order.Category) == "string" and typeof(order.Item) == "string" then
		local ok, spec = pcall(fromOrderItem, order)
		if ok and typeof(spec) == "table" then
			return { spec }
		end
	end

	return {}
end

-- Finds the currently active OrderSpec for a multi-spec order given the barista's tool
-- candidates (character + backpack) and held tool attributes.
-- Returns:
--   activeSpec: OrderSpec? (the spec currently being worked on or the next unfilled spec)
--   allDone: boolean (true if all specs have matching finished tools ready)
--   activeSpecIndex: number? (1-based index of activeSpec in specs)
--   totalSpecs: number (#specs)
function KitchenGuidance.FindActiveSpec(
	specs: { OrderSpec.OrderSpec },
	candidates: { { [string]: any } },
	heldAttrs: { [string]: any }?
): (OrderSpec.OrderSpec?, boolean, number?, number)
	local total = #specs
	if total == 0 then
		return nil, false, nil, 0
	end

	local picks = OrderSpec.PickTools(specs, candidates)
	if picks ~= nil then
		local heldIndex: number? = nil
		if heldAttrs ~= nil and typeof(heldAttrs) == "table" and heldAttrs.Item ~= nil then
			for specIndex, spec in specs do
				local grade = OrderSpec.Match(spec, heldAttrs)
				if grade == "Perfect" or grade == "Close" then
					heldIndex = specIndex
					break
				end
			end
		end
		local activeIndex = heldIndex or total
		return specs[activeIndex], true, activeIndex, total
	end

	local filled: { [number]: boolean } = {}
	local usedCandidate: { [number]: boolean } = {}
	for _, wanted in { "Perfect", "Close" } :: { OrderSpec.Grade } do
		for specIndex, spec in specs do
			if filled[specIndex] then
				continue
			end
			for candIndex, attrs in candidates do
				if usedCandidate[candIndex] then
					continue
				end
				local grade = OrderSpec.Match(spec, attrs)
				if grade == wanted then
					filled[specIndex] = true
					usedCandidate[candIndex] = true
					break
				end
			end
		end
	end

	local activeIndex: number? = nil
	if heldAttrs ~= nil and typeof(heldAttrs) == "table" and heldAttrs.Item ~= nil then
		for specIndex, spec in specs do
			if not filled[specIndex] then
				local stepState, problem = OrderSpec.StepState(spec, heldAttrs)
				if stepState > 1 and (problem == nil or problem.Severity ~= "Wrong") then
					activeIndex = specIndex
					break
				end
			end
		end
		if activeIndex == nil then
			-- A finished drink still in hand must not pin the card to its
			-- (completed) spec: only specs with no matching tool yet qualify.
			for specIndex, spec in specs do
				if filled[specIndex] then
					continue
				end
				local grade = OrderSpec.Match(spec, heldAttrs)
				if grade == "Perfect" or grade == "Close" then
					activeIndex = specIndex
					break
				end
			end
		end
	end

	if activeIndex == nil then
		for specIndex = 1, total do
			if not filled[specIndex] then
				activeIndex = specIndex
				break
			end
		end
	end

	local activeSpec = if activeIndex ~= nil then specs[activeIndex] else nil
	return activeSpec, false, activeIndex, total
end

-- Where the held tool is in the order. nil when the item has no recipe chain (no card,
-- no hints). `attrs` are the equipped tool's attributes, nil when nothing is held.
function KitchenGuidance.Compute(spec: OrderSpec.OrderSpec?, attrs: { [string]: any }?): Guidance?
	if spec == nil then
		return nil
	end
	local steps = OrderSpec.Steps(spec)
	if #steps == 0 then
		return nil
	end
	local current = OrderSpec.StepState(spec, attrs)
	local step = steps[current]
	if step == nil then
		return {
			Station = nil,
			Choice = nil,
			Label = "Serve your customer",
			IsServe = true,
			Current = current,
			Total = #steps,
			Item = spec.Item,
		}
	end
	return {
		Station = step.Station,
		Choice = step.Choice,
		Label = step.Label,
		IsServe = false,
		Current = current,
		Total = #steps,
		Item = spec.Item,
	}
end

-- Design 3.9: the beam shows for the first N customers, the first time each item
-- appears, and after the idle time. Any one is enough.
function KitchenGuidance.ShouldShowBeam(state: BeamState): boolean
	return state.CustomersSeen <= KitchenGuidance.BEAM_FIRST_CUSTOMERS
		or not state.ItemSeenBefore
		or state.IdleSeconds >= KitchenGuidance.BEAM_IDLE_SECONDS
end

-- The toast text when the player starts using `station` and it is not the current
-- step, or nil when there is nothing to say (right station, no guidance, neutral
-- station).
function KitchenGuidance.WrongStationMessage(guidance: Guidance?, station: string): string?
	if guidance == nil or guidance.Station == station then
		return nil
	end
	if KitchenGuidance.NEUTRAL_STATIONS[station] then
		return nil
	end
	return "Next: " .. guidance.Label
end

export type CustomerView = {
	State: any, -- the NPC model's State attribute
	PromptAction: any, -- the NPC model's PromptAction attribute (the CustomerPrompt's text)
	Position: Point,
}

-- AUDIT-FIX D1.2: with no ticket, a clocked-in player is guided to the nearest
-- customer waiting to order (State "AtCounter", prompt "Take Order"). Returns the
-- index into `customers`, or nil when nobody is waiting.
function KitchenGuidance.TakeOrderTarget(customers: { CustomerView }, origin: Point): number?
	local points: { Point } = {}
	local indexes: { number } = {}
	for index, customer in customers do
		if customer.State == "AtCounter" and customer.PromptAction == "Take Order" then
			table.insert(points, customer.Position)
			table.insert(indexes, index)
		end
	end
	local nearest = KitchenGuidance.NearestIndex(points, origin)
	return if nearest then indexes[nearest] else nil
end

return KitchenGuidance
