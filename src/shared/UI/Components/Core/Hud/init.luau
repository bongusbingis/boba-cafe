local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = Shared:WaitForChild("UI")

---> dependencies
local React = require(Packages.React)

---> components
local Pane = require(UI.Components.Pane)
local TopBar = require(script.TopBar)
local BottomLeft = require(script.BottomLeft)
local BottomRight = require(script.BottomRight)
local OrderTicket = require(script.OrderTicket)
local OrderQueue = require(script.OrderQueue)
local ShiftCard = require(script.ShiftCard)
local CafeRating = require(script.CafeRating)
local QuestCard = require(script.QuestCard)
---> private
local c = React.createElement

return function(props: {
	CurrentPage: ModuleScript,
	SetCurrentPage: (pageComponent: ModuleScript | nil, ...any) -> (),
})
	-- Quests is a closed-by-default pop-up card, not a page (DEC-048).
	local questsOpen, setQuestsOpen = React.useState(false)
	local questsCloseRef = React.useRef(nil)
	local questsOpenRef = React.useRef(false)
	questsOpenRef.current = questsOpen

	local closeQuests = React.useCallback(function()
		setQuestsOpen(false)
	end, {})

	local toggleQuests = React.useCallback(function()
		if questsOpenRef.current then
			if questsCloseRef.current then
				questsCloseRef.current()
			else
				setQuestsOpen(false)
			end
			return
		end
		-- App toggles: passing the open page closes it.
		if props.CurrentPage ~= nil then
			props.SetCurrentPage(props.CurrentPage)
		end
		setQuestsOpen(true)
	end, { props.CurrentPage, props.SetCurrentPage })

	-- Shop / Inventory / Menu and the card are never stacked.
	React.useEffect(function()
		if props.CurrentPage ~= nil and questsOpenRef.current then
			if questsCloseRef.current then
				questsCloseRef.current()
			else
				setQuestsOpen(false)
			end
		end
	end, { props.CurrentPage })

	return c(Pane, {
		Native = {
			Size = UDim2.fromScale(1, 1),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
		},
	}, {
		TopBar = c(TopBar, {
			CurrentPage = props.CurrentPage,
			SetCurrentPage = props.SetCurrentPage,
		}),

		BottomLeft = c(BottomLeft, {
			CurrentPage = props.CurrentPage,
			SetCurrentPage = props.SetCurrentPage,
		}),

		BottomRight = c(BottomRight, {
			CurrentPage = props.CurrentPage,
			SetCurrentPage = props.SetCurrentPage,
			QuestsOpen = questsOpen,
			OnToggleQuests = toggleQuests,
		}),

		TicketStack = c("Frame", {
			-- Same anchor the single ticket used; tickets stack top to bottom.
			AnchorPoint = Vector2.new(1, 1),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0.99, 0.92),
			Size = UDim2.fromOffset(190, 0),
			ZIndex = 10,
		}, {
			Layout = c("UIListLayout", {
				FillDirection = Enum.FillDirection.Vertical,
				Padding = UDim.new(0, 10),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			OrderTicket = c(OrderTicket, { stacked = true, slot = 1, layoutOrder = 1 }),
			OrderTicket2 = c(OrderTicket, { stacked = true, slot = 2, layoutOrder = 2 }),
		}),
		OrderQueue = c(OrderQueue, {}),
		ShiftCard = c(ShiftCard, {}),
		CafeRating = c(CafeRating, {}),

		-- Last sibling, ZIndex 20 on its single outer Frame (above TicketStack 10).
		QuestPopup = if questsOpen then c(QuestCard, { OnClose = closeQuests, CloseRef = questsCloseRef }) else nil,
	})
end
