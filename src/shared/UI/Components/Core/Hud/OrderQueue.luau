--[[
    Component: OrderQueue
    Description: Prototype HUD overlay shown when the local player is waiting
                 in the barista queue for an order to be assigned to them.

    Renders nothing when the player is not queued (position = nil).
    Build onto this: animations, a countdown, a queue list, etc.
--]]

--!nonstrict

---> Services

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

---> Dependencies

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = Shared:WaitForChild("UI")

local Knit = require(Packages.Knit)
local React = require(Packages.React)

local Styles = require(UI.Styles)

---> Private

local c = React.createElement

---> Component

return function()
	local position, setPosition = React.useState(nil :: number?)

	if RunService:IsRunning() then
		React.useEffect(function()
			local controller = Knit.GetController("OrderController")

			-- Snapshot on mount in case we joined the queue before this rendered
			setPosition(controller.QueuePosition)

			local conn = controller.QueueChanged:Connect(function(newPosition: number?)
				setPosition(newPosition)
			end)

			return function()
				conn:Disconnect()
			end
		end, {})
	end

	-- Nothing to render when not in queue
	if not position then
		return nil
	end

	local ahead = position - 1
	local statusText = if ahead == 0
		then "You're next!"
		else ahead .. (ahead == 1 and " barista ahead of you" or " baristas ahead of you")

	return c("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Color3.fromRGB(245, 245, 245),
		BorderSizePixel = 0,
		Position = UDim2.new(0.5, 0, 0.92, 0),
		Size = UDim2.new(0, 220, 0, 0),
		ZIndex = 10,
	}, {
		Corner = c("UICorner", { CornerRadius = UDim.new(0, 6) }),
		Stroke = c("UIStroke", { Color = Styles.GREEN_DIM, Thickness = 1 }),
		Layout = c("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 0),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),

		-- Header
		Header = c("Frame", {
			LayoutOrder = 0,
			BackgroundColor3 = Styles.GREEN,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, 28),
		}, {
			Corner = c("UICorner", { CornerRadius = UDim.new(0, 6) }),
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
				Text = "Order Queue",
				TextColor3 = Styles.OFFWHITE,
				TextSize = 15,
			}),
		}),

		-- Status line
		Status = c("TextLabel", {
			LayoutOrder = 1,
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			FontFace = Styles.FONT_FREDOKA,
			Size = UDim2.new(1, -16, 0, 0),
			Text = statusText,
			TextColor3 = Styles.GREEN_DEEP,
			TextSize = 14,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Center,
		}, {
			PaddingTop = c("UIPadding", { PaddingTop = UDim.new(0, 8) }),
		}),

		-- Leave Queue button
		LeaveButton = c("TextButton", {
			LayoutOrder = 2,
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = Styles.CORAL,
			BorderSizePixel = 0,
			FontFace = Styles.FONT_FREDOKA,
			Size = UDim2.new(1, -20, 0, 32),
			Text = "Leave Queue",
			TextColor3 = Styles.OFFWHITE,
			TextSize = 14,
			[React.Event.Activated] = function()
				if RunService:IsRunning() then
					Knit.GetController("OrderController"):LeaveQueue()
				end
			end,
		}, {
			Corner = c("UICorner", { CornerRadius = UDim.new(0, 4) }),
			Margin = c("UIPadding", {
				PaddingLeft = UDim.new(0, 10),
				PaddingRight = UDim.new(0, 10),
				PaddingBottom = UDim.new(0, 8),
				PaddingTop = UDim.new(0, 6),
			}),
		}),
	})
end
