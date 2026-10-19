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
---> private
local c = React.createElement

return function(props: {
	CurrentPage: ModuleScript,
	SetCurrentPage: (pageComponent: ModuleScript | nil, ...any) -> (),
})
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
	})
end
