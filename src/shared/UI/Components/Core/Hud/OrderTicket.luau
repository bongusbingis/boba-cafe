--[[
    Component: OrderTicket
    Description: Prototype HUD overlay that shows the active order a staff member
                 has claimed. Renders nothing when the player has no active order.

    Intentionally unstyled — use plain colours only so this can be skinned later.
    Build onto this component: animations, asset images, scroll for large orders, etc.

    Listens to OrderController via GoodSignal connections wired in useEffect so
    connections are always cleaned up when the component unmounts.

    Shows the RecipeCard step list (M1.5b) when the order resolves to a spec.
--]]

--!nonstrict

---> Services

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

---> Dependencies

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = Shared:WaitForChild("UI")
local Ordering = Shared:WaitForChild("Ordering")

local Knit = require(Packages.Knit)
local React = require(Packages.React)

local Styles = require(UI.Styles)
local OrderSpec = require(Ordering.OrderSpec)
local RecipeCard = require(script.Parent.RecipeCard)
local UiSfx = require(UI.Utility.UiSfx)

---> Private

local c = React.createElement

-- Infers the interaction class for a completed step to trigger class-specific audio.
local function getStepInteractionClass(step: any): string?
	if typeof(step) ~= "table" or typeof(step.Station) ~= "string" then
		return nil
	end
	local station = step.Station
	if
		station == "Milk"
		or station == "Steamed Milk"
		or string.find(station, "Syrup")
		or string.find(station, "Water")
	then
		return "Pour"
	elseif
		string.find(station, "Tapioca")
		or string.find(station, "Powder")
		or string.find(station, "Sugar")
		or string.find(station, "Ice Cream")
	then
		return "Scoop"
	elseif string.find(station, "Coffee") or string.find(station, "Ice Machine") or string.find(station, "Machine") then
		return "Machine"
	elseif string.find(station, "Blender") then
		return "Blender"
	elseif
		station == "Cup"
		or station == "Clear Cup"
		or station == "Mug"
		or string.find(station, "Display")
		or string.find(station, "Freezer")
	then
		return "Grab"
	end
	return nil
end

local ALIAS_CATEGORIES = {
	Coffee = "Coffees",
	["Hot Cocoa"] = "Hot Cocoas",
	Tea = "Teas",
	Boba = "Boba Teas",
}

local function ensureItemDefaultInfo(item: { [string]: any })
	if item.DefaultInfo ~= nil then
		return
	end
	local ok, menu = pcall(function()
		return require(Ordering:WaitForChild("Menu"))
	end)
	if ok and typeof(menu) == "table" and typeof(menu.FoodTable) == "table" then
		local catKey = item.Category
		local cat = menu.FoodTable[catKey] or (catKey and menu.FoodTable[ALIAS_CATEGORIES[catKey]])
		if cat and typeof(cat.Items) == "table" and item.Item and cat.Items[item.Item] then
			item.DefaultInfo = cat.Items[item.Item]
		end
	end
end

-- Builds the display name for an order item, prepending any selected variant.
local function resolveItemName(item: { [string]: any }): string
	if item.DefaultInfo and typeof(item.DefaultInfo.ItemName) == "string" then
		local name: string = item.DefaultInfo.ItemName
		if item.DefaultInfo.Select and typeof(item.CustomInfo) == "table" then
			for variantType in item.DefaultInfo.Select do
				local chosen = item.CustomInfo[variantType]
				if chosen then
					name = chosen .. " " .. name
				end
			end
		end
		return name
	end
	if typeof(item.Label) == "string" then
		return item.Label
	end
	if typeof(item.Item) == "string" then
		local size = if typeof(item.CustomInfo) == "table" then item.CustomInfo.Size else nil
		return if size then size .. " " .. item.Item else item.Item
	end
	return "Unknown"
end

-- Returns a flat list of customisation strings for an item (e.g. "+ Boba", "- NO Ice").
local function resolveCustomisations(item: { [string]: any }): { string }
	local lines: { string } = {}
	if item.DefaultInfo == nil or item.CustomInfo == nil then
		return lines
	end

	if item.DefaultInfo.RequiredSelection then
		for selType in item.DefaultInfo.RequiredSelection do
			table.insert(lines, selType .. ": " .. (item.CustomInfo[selType] or "?"))
		end
	end

	if item.DefaultInfo.Options then
		for optType, defaultValue in item.DefaultInfo.Options do
			local chosen = item.CustomInfo[optType]
			if chosen ~= defaultValue then
				table.insert(lines, if chosen then ("+ " .. optType) else ("- NO " .. optType))
			end
		end
	end

	return lines
end

---> Spec resolution

-- Finds the candidate attributes and tool instance that match a specific OrderSpec,
-- taking into account already-used candidates for previous specs so that duplicate
-- items in an order don't falsely share the same candidate tool.
local function getSpecCandidate(
	targetSpecIndex: number?,
	specs: { any },
	candidateList: { { [string]: any } },
	toolsList: { Instance }?
): ({ [string]: any }?, Instance?)
	if not targetSpecIndex or not specs or not candidateList or not specs[targetSpecIndex] then
		return nil, nil
	end
	local picked: { [number]: number } = {}
	local used: { [number]: boolean } = {}
	for _, wanted in { "Perfect", "Close" } :: { OrderSpec.Grade } do
		for specIndex, spec in specs do
			if picked[specIndex] ~= nil then
				continue
			end
			for candidateIndex, attrs in candidateList do
				if used[candidateIndex] then
					continue
				end
				local grade = OrderSpec.Match(spec, attrs)
				if grade == wanted then
					picked[specIndex] = candidateIndex
					used[candidateIndex] = true
					break
				end
			end
		end
	end
	local candIdx = picked[targetSpecIndex]
	if candIdx ~= nil then
		local attrs = candidateList[candIdx]
		local tool = if toolsList ~= nil then toolsList[candIdx] else nil
		return attrs, tool
	end
	return nil, nil
end

-- Determines which spec indices in `specs` have matching completed items in `candidates`.
local function getCompletedSpecs(
	specs: { OrderSpec.OrderSpec },
	candidates: { { [string]: any } },
	allDone: boolean?,
	isReady: boolean?
): { [number]: boolean }
	local completed: { [number]: boolean } = {}
	if isReady or allDone then
		for i = 1, #specs do
			completed[i] = true
		end
		return completed
	end
	if not specs or not candidates or #specs == 0 or #candidates == 0 then
		return completed
	end
	local usedCandidate: { [number]: boolean } = {}
	for _, wanted in { "Perfect", "Close" } :: { OrderSpec.Grade } do
		for specIndex, spec in specs do
			if completed[specIndex] then
				continue
			end
			for candIndex, attrs in candidates do
				if usedCandidate[candIndex] then
					continue
				end
				local grade = OrderSpec.Match(spec, attrs)
				if grade == wanted then
					completed[specIndex] = true
					usedCandidate[candIndex] = true
					break
				end
			end
		end
	end
	return completed
end

-- Uses KitchenGuidance. KitchenGuidance lives under StarterPlayerScripts, so it is
-- required lazily here at runtime instead of at the top of the file.
local function getGuidanceModule()
	local player = Players.LocalPlayer
	if player == nil then
		return nil
	end
	local ok, guidance = pcall(function()
		local playerScripts = player:WaitForChild("PlayerScripts", 5)
		if playerScripts == nil then
			return nil
		end
		local client = playerScripts:WaitForChild("Client", 5)
		if client == nil then
			return nil
		end
		local modules = client:WaitForChild("Modules", 5)
		if modules == nil then
			return nil
		end
		return require(modules:WaitForChild("KitchenGuidance", 5))
	end)
	if not ok or guidance == nil then
		return nil
	end
	return guidance
end

---> Patience bar

-- Thin patience bar (same colours as RecipeCard). Used by the second ticket and
-- by any collapsed ticket.
local function patienceBar(patience: number, layoutOrder: number)
	return c("Frame", {
		LayoutOrder = layoutOrder,
		BackgroundColor3 = Styles.GRAY,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 6),
	}, {
		Fill = c("Frame", {
			BackgroundColor3 = if patience < 0.25
				then Styles.RED
				elseif patience < 0.5 then Styles.GOLD_MID
				else Styles.GREEN,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(math.clamp(patience, 0, 1), 1),
		}),
	})
end

---> Item Row

-- Renders a single order item: its name and any customisation lines beneath it.
local function ItemRow(props: {
	item: { [string]: any },
	layoutOrder: number,
	isCompleted: boolean?,
	onOpenRecipe: (() -> ())?,
})
	local item = props.item
	local name = resolveItemName(item)
	local customisations = resolveCustomisations(item)

	local customisationElements = {}
	for i, line in customisations do
		customisationElements["Custom_" .. i] = c("TextLabel", {
			LayoutOrder = i,
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			FontFace = Styles.FONT_FREDOKA,
			Size = UDim2.new(1, -8, 0, 14),
			Text = line,
			TextColor3 = Styles.GRAY,
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Left,
		})
	end

	local displayName = if props.isCompleted then `<font color="#48c774">✓</font> {name}` else name

	return c("Frame", {
		LayoutOrder = props.layoutOrder,
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Styles.OFFWHITE,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 0),
	}, {
		Layout = c("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			Padding = UDim.new(0, 2),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Padding = c("UIPadding", {
			PaddingTop = UDim.new(0, 4),
			PaddingBottom = UDim.new(0, 4),
			PaddingLeft = UDim.new(0, 8),
			PaddingRight = UDim.new(0, 8),
		}),

		ItemName = c("TextButton", {
			LayoutOrder = 0,
			Active = props.onOpenRecipe ~= nil,
			AutoButtonColor = false,
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			FontFace = Styles.FONT_FREDOKA,
			RichText = true,
			Size = UDim2.new(1, -8, 0, 18),
			Text = displayName,
			TextColor3 = Styles.GREEN_DEEP,
			TextSize = 15,
			TextXAlignment = Enum.TextXAlignment.Left,
			[React.Event.Activated] = props.onOpenRecipe,
		}),

		Customisations = next(customisationElements) and c(
			"Frame",
			{
				LayoutOrder = 1,
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 0),
			},
			(function()
				-- table.unpack only works on integer-keyed tables; merge into a single
				-- dict so React receives all children regardless of key type.
				local children = table.clone(customisationElements)
				children.Layout = c("UIListLayout", {
					FillDirection = Enum.FillDirection.Vertical,
					Padding = UDim.new(0, 1),
					SortOrder = Enum.SortOrder.LayoutOrder,
				})
				return children
			end)()
		) or nil,
	})
end

---> OrderTicket

return function(props: {
	stacked: boolean?,
	slot: number?,
	layoutOrder: number?,
	SetCurrentPage: ((page: any, ...any) -> ())?,
	PreviewOrder: { [string]: any }?,
	PreviewPatience: number?,
})
	-- slot 2 is the second NPC ticket (level 5+): label and patience only.
	local isSecond = props.slot == 2
	local order, setOrder = React.useState(props.PreviewOrder)
	local readyNode, setReadyNode = React.useState(nil :: Instance?)
	local candidates, setCandidates = React.useState({} :: { { [string]: any } })
	local candidateTools, setCandidateTools = React.useState({} :: { Instance })
	local toolAttrs, setToolAttrs = React.useState(nil :: { [string]: any }?)
	local toolInst, setToolInst = React.useState(nil :: Instance?)
	local patience, setPatience = React.useState(props.PreviewPatience)
	local character, setCharacter =
		React.useState(if Players.LocalPlayer ~= nil then Players.LocalPlayer.Character else nil)
	local selectedSpecIndex, setSelectedSpecIndex = React.useState(nil :: number?)
	-- Phones start collapsed to the header line; a tap on the header toggles.
	local canCollapse = UserInputService.TouchEnabled
	local collapsed, setCollapsed = React.useState(canCollapse)
	local lastStep = React.useRef({ spec = nil, tool = nil, done = 0 })

	local guidance = getGuidanceModule()
	local specs = if guidance ~= nil and order ~= nil then guidance.ResolveSpecs(order, OrderSpec.FromOrderItem) else {}
	local activeSpec, allDone, activeIndex, totalSpecs =
		if guidance ~= nil and #specs > 0 then guidance.FindActiveSpec(specs, candidates, toolAttrs) else nil,
		false,
		nil,
		#specs
	local currentSpecIndex = selectedSpecIndex or activeIndex or #specs
	local currentSpec = if selectedSpecIndex ~= nil and specs[selectedSpecIndex] ~= nil
		then specs[selectedSpecIndex]
		else (activeSpec or specs[#specs])

	local cardAttrs = toolAttrs
	local cardTool = toolInst
	local isComplete = false

	if currentSpec ~= nil then
		local matchingAttrs, matchingTool = getSpecCandidate(currentSpecIndex, specs, candidates, candidateTools)
		if matchingAttrs ~= nil then
			if cardAttrs == nil then
				cardAttrs = matchingAttrs
				cardTool = matchingTool
			else
				local _, problem = OrderSpec.StepState(currentSpec, cardAttrs)
				if problem ~= nil and problem.Severity == "Wrong" then
					cardAttrs = matchingAttrs
					cardTool = matchingTool
				end
			end
			isComplete = true
		elseif allDone then
			isComplete = true
		end
	end

	if RunService:IsRunning() and props.PreviewOrder == nil then
		React.useEffect(function()
			local controller = Knit.GetController("OrderController")

			-- Snapshot current state on mount so the ticket is correct even if
			-- signals fired before this component rendered.
			if isSecond then
				setOrder(controller.Tickets[2])
			else
				setOrder(controller.CurrentOrder)
			end
			setReadyNode(controller.ReadyNode)
			if Players.LocalPlayer ~= nil then
				setCharacter(Players.LocalPlayer.Character)
			end

			local connOrder = if isSecond
				then controller.TicketsChanged:Connect(function(tickets)
					setOrder(tickets[2])
				end)
				else controller.OrderChanged:Connect(function(newOrder: { any }?)
					setOrder(newOrder)
				end)

			local connReady = controller.ReadyNodeChanged:Connect(function(node: Instance?)
				setReadyNode(node)
			end)

			local connChar = nil
			if Players.LocalPlayer ~= nil then
				connChar = Players.LocalPlayer.CharacterAdded:Connect(function(newCharacter: Model)
					setCharacter(newCharacter)
				end)
			end

			return function()
				connOrder:Disconnect()
				connReady:Disconnect()
				if connChar ~= nil then
					connChar:Disconnect()
				end
			end
		end, {})
	end

	if RunService:IsRunning() and props.PreviewPatience == nil then
		-- Live patience fraction of an NPC ticket (PatienceEnd is server time). Quantised
		-- so React only re-renders when the bar visibly moves; nil hides the bar.
		React.useEffect(function()
			local patienceEnd = if order ~= nil then order.PatienceEnd else nil
			local patienceTotal = if order ~= nil then order.PatienceTotal else nil
			if typeof(patienceEnd) ~= "number" or typeof(patienceTotal) ~= "number" or patienceTotal <= 0 then
				setPatience(nil)
				return
			end
			local conn = RunService.Heartbeat:Connect(function()
				local fraction = math.clamp((patienceEnd - workspace:GetServerTimeNow()) / patienceTotal, 0, 1)
				setPatience(math.floor(fraction * 200) / 200)
			end)
			return function()
				conn:Disconnect()
			end
		end, { order })

		-- Tracks the equipped tool: ChildAdded/ChildRemoved on the character
		-- plus AttributeChanged on the tool itself. Every change snapshots
		-- synchronously, so the card recomputes well within 0.2 s.
		React.useEffect(function()
			if character == nil then
				setToolInst(nil)
				setToolAttrs(nil)
				setCandidates({})
				setCandidateTools({})
				return
			end
			local toolConns: { [Instance]: RBXScriptConnection } = {}
			local function disconnectToolConns()
				for _, conn in toolConns do
					conn:Disconnect()
				end
				table.clear(toolConns)
			end

			local function refresh()
				disconnectToolConns()
				local tool = character:FindFirstChildWhichIsA("Tool")
				setToolInst(tool)
				if tool ~= nil then
					setToolAttrs(tool:GetAttributes())
					toolConns[tool] = tool.AttributeChanged:Connect(refresh)
				else
					setToolAttrs(nil)
				end

				local candidateAttrsList = {}
				local candidateToolsList = {}
				local function addFrom(container: Instance?)
					if not container then
						return
					end
					for _, child in container:GetChildren() do
						if child:IsA("Tool") and child:GetAttribute("Served") ~= true then
							table.insert(candidateAttrsList, child:GetAttributes())
							table.insert(candidateToolsList, child)
							if not toolConns[child] then
								toolConns[child] = child.AttributeChanged:Connect(refresh)
							end
						end
					end
				end
				addFrom(character)
				if Players.LocalPlayer ~= nil then
					addFrom(Players.LocalPlayer:FindFirstChild("Backpack"))
				end
				setCandidates(candidateAttrsList)
				setCandidateTools(candidateToolsList)
			end
			refresh()
			local connAdded = character.ChildAdded:Connect(refresh)
			local connRemoved = character.ChildRemoved:Connect(refresh)
			local backpack = if Players.LocalPlayer ~= nil then Players.LocalPlayer:FindFirstChild("Backpack") else nil
			local bpAdded = if backpack ~= nil then backpack.ChildAdded:Connect(refresh) else nil
			local bpRemoved = if backpack ~= nil then backpack.ChildRemoved:Connect(refresh) else nil
			return function()
				connAdded:Disconnect()
				connRemoved:Disconnect()
				if bpAdded ~= nil then
					bpAdded:Disconnect()
				end
				if bpRemoved ~= nil then
					bpRemoved:Disconnect()
				end
				disconnectToolConns()
			end
		end, { character })

		-- Step tick (SOUNDS D6): progress on the same held tool for the same order only.
		React.useEffect(function()
			if isSecond or currentSpec == nil then
				return
			end
			local current = OrderSpec.StepState(currentSpec, toolAttrs)
			local done = math.clamp(current - 1, 0, #OrderSpec.Steps(currentSpec))
			local last = lastStep.current
			if done > last.done and last.spec == currentSpec and toolInst ~= nil and last.tool == toolInst then
				local steps = OrderSpec.Steps(currentSpec)
				local completedStep = steps[done]
				local class = getStepInteractionClass(completedStep)
				local cues = {}
				if class then
					table.insert(cues, "StepDone_" .. class)
				end
				table.insert(cues, "StepDone")
				UiSfx.Play(cues)
			end
			lastStep.current = { spec = currentSpec, tool = toolInst, done = done }
		end, { currentSpec, toolAttrs, toolInst })
	end

	-- A new order (different Id, or non-nil after nil) re-opens a collapsed ticket and clears selection.
	local orderKey = if order ~= nil then (order.Id or order) else nil
	React.useEffect(function()
		setSelectedSpecIndex(nil)
		if orderKey ~= nil and canCollapse then
			setCollapsed(false)
		end
	end, { orderKey })

	-- Equipping a tool refocuses the ticket onto the held item
	React.useEffect(function()
		if toolInst ~= nil then
			setSelectedSpecIndex(nil)
		end
	end, { toolInst })

	-- Nothing to show when the player has no active order
	if not order then
		return nil
	end

	-- Build one ItemRow per order item
	local rawItems = if typeof(order) == "table"
			and typeof(order.Items) == "table"
			and #order.Items > 0
		then order.Items
		else order

	local completedSpecs = getCompletedSpecs(specs, candidates, allDone, readyNode ~= nil)

	local itemRows = {}
	if typeof(rawItems) == "table" and #rawItems > 0 then
		for i, item in ipairs(rawItems) do
			ensureItemDefaultInfo(item)
			if i > 1 then
				-- Thin divider between items
				itemRows["Divider_" .. i] = c("Frame", {
					LayoutOrder = (i - 1) * 2,
					BackgroundColor3 = Styles.GRAY,
					BorderSizePixel = 0,
					Size = UDim2.new(1, 0, 0, 1),
				})
			end
			itemRows["Item_" .. i] = c(ItemRow, {
				LayoutOrder = (i - 1) * 2 + 1,
				item = item,
				isCompleted = completedSpecs[i] == true,
				onOpenRecipe = function()
					setSelectedSpecIndex(i)
					if props.SetCurrentPage ~= nil and typeof(item.Item) == "string" then
						props.SetCurrentPage(UI.Pages.Recipes, item.Item)
					end
				end,
			})
		end
	elseif typeof(order.Label) == "string" then
		local isCompleted = allDone or readyNode ~= nil or completedSpecs[1] == true
		itemRows.TicketLabel = c("TextLabel", {
			LayoutOrder = 1,
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			FontFace = Styles.FONT_FREDOKA,
			RichText = true,
			Size = UDim2.new(1, 0, 0, 18),
			Text = if isCompleted then `<font color="#48c774">✓</font> {order.Label}` else order.Label,
			TextColor3 = Styles.GREEN_DEEP,
			TextSize = 15,
			TextWrapped = true,
		})
	end

	-- Recipe card section: only when the order resolves to a spec with steps.
	local hasCard = not isSecond and currentSpec ~= nil and #OrderSpec.Steps(currentSpec) > 0
	local recipeDivider = hasCard
			and c("Frame", {
				LayoutOrder = 2,
				BackgroundColor3 = Styles.GRAY,
				BorderSizePixel = 0,
				Size = UDim2.new(1, 0, 0, 1),
			})
		or nil
	local recipe = hasCard
			and c(RecipeCard, {
				layoutOrder = 3,
				spec = currentSpec,
				attrs = cardAttrs,
				tool = cardTool,
				-- Shift text arrives with M2.
				patience = patience,
				shiftText = nil,
				allDone = allDone,
				isComplete = isComplete,
				itemIndex = currentSpecIndex,
				itemTotal = totalSpecs,
			})
		or nil

	-- The second ticket shows its patience bar (same colours as RecipeCard).
	local secondPatience = if isSecond and typeof(patience) == "number" then patienceBar(patience, 3) else nil
	-- Collapsed tickets (both slots) keep the patience bar directly under the header.
	local collapsedPatience = if collapsed and typeof(patience) == "number" then patienceBar(patience, 1) else nil

	-- "Ready for pick up" footer, shown once the order has been deposited
	local readyFooter = readyNode
			and c("Frame", {
				-- UI-REVISION: was math.huge, which overflows LayoutOrder (int32) and
				-- sorted the footer above the header.
				LayoutOrder = 100,
				BackgroundColor3 = Styles.GREEN,
				BorderSizePixel = 0,
				Size = UDim2.new(1, 0, 0, 32),
			}, {
				-- Round the bottom to match the card, square the top (header's trick, flipped).
				Corner = c("UICorner", { CornerRadius = UDim.new(0, 6) }),
				TopBlocker = c("Frame", {
					BackgroundColor3 = Styles.GREEN,
					BorderSizePixel = 0,
					Size = UDim2.new(1, 0, 0, 6),
				}),
				Label = c("TextLabel", {
					BackgroundTransparency = 1,
					FontFace = Styles.FONT_FREDOKA,
					Size = UDim2.fromScale(1, 1),
					Text = "Ready for Pick Up!",
					TextColor3 = Styles.OFFWHITE,
					TextScaled = true,
					ZIndex = 2,
				}, {
					Padding = c("UIPadding", {
						PaddingTop = UDim.new(0, 6),
						PaddingBottom = UDim.new(0, 6),
					}),
				}),
			})
		or nil

	return c("Frame", {
		-- Anchored to the right side of the screen, grows upward from the bottom
		-- (stacked tickets sit in the Hud TicketStack instead).
		AnchorPoint = if props.stacked then nil else Vector2.new(1, 1),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Color3.fromRGB(245, 245, 245),
		BorderSizePixel = 0,
		LayoutOrder = props.layoutOrder,
		Position = if props.stacked then nil else UDim2.fromScale(0.99, 0.92),
		Size = if props.stacked then UDim2.fromScale(1, 0) else UDim2.fromOffset(190, 0),
		ZIndex = 10,
	}, {
		Corner = c("UICorner", { CornerRadius = UDim.new(0, 6) }),
		Stroke = c("UIStroke", {
			Color = Styles.GREEN_DIM,
			Thickness = 1,
		}),
		Layout = c("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			Padding = UDim.new(0, 0),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),

		-- Header (a tap toggles the collapsed ticket on touch devices)
		Header = c("TextButton", {
			LayoutOrder = 0,
			Active = canCollapse,
			AutoButtonColor = canCollapse,
			BackgroundColor3 = Styles.GREEN,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, 28),
			Text = "",
			[React.Event.Activated] = if canCollapse
				then function()
					setCollapsed(not collapsed)
				end
				else nil,
		}, {
			Corner = c("UICorner", { CornerRadius = UDim.new(0, 6) }),
			-- Square off the bottom corners so it blends into the body
			BottomBlocker = c("Frame", {
				AnchorPoint = Vector2.new(0, 1),
				BackgroundColor3 = Styles.GREEN,
				BorderSizePixel = 0,
				Position = UDim2.fromScale(0, 1),
				Size = UDim2.new(1, 0, 0, 6),
			}),
			Label = c("TextLabel", {
				BackgroundTransparency = 1,
				FontFace = Styles.FONT_FREDOKA,
				Size = UDim2.fromScale(1, 1),
				-- DEC-059: a real player's order is tagged in the header.
				Text = if collapsed and typeof(order.Label) == "string"
					then order.Label
					elseif order.Real == true then (if isSecond then "Real Customer 2" else "Real Customer")
					elseif isSecond then "Order Ticket 2"
					else "Order Ticket",
				TextColor3 = Styles.OFFWHITE,
				TextSize = 15,
				TextTruncate = Enum.TextTruncate.AtEnd,
			}),
		}),

		-- Item list, recipe card and footer hide while collapsed to the header
		PatienceCollapsed = collapsedPatience,
		Items = if collapsed
			then nil
			else c(
				"Frame",
				{
					LayoutOrder = 1,
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
					Size = UDim2.fromScale(1, 0),
				},
				(function()
					local children = table.clone(itemRows)
					children.Layout = c("UIListLayout", {
						FillDirection = Enum.FillDirection.Vertical,
						Padding = UDim.new(0, 0),
						SortOrder = Enum.SortOrder.LayoutOrder,
					})
					return children
				end)()
			),

		Patience2 = if collapsed then nil else secondPatience,
		DividerRecipe = if collapsed then nil else recipeDivider,
		Recipe = if collapsed then nil else recipe,
		ReadyFooter = if collapsed then nil else readyFooter,
	})
end
