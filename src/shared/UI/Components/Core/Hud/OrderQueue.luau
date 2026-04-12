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
local Banner = require(UI.Components.Buttons.Banner)
local Pane = require(UI.Components.Pane)
local PromptButton = require(UI.Components.Buttons.PromptButton)

---> Private

local c = React.createElement
local BASE_IMAGE = "http://www.roblox.com/asset/?id=13473433246"
local BORDER_IMAGE = "http://www.roblox.com/asset/?id=13382163077"

local function getStatusText(position: number): string
	local ahead = position - 1
	if ahead == 0 then
		return "You're next!"
	end

	return ahead .. (ahead == 1 and " barista ahead of you" or " baristas ahead of you")
end

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

	local statusText = getStatusText(position)

	return c(Pane, {
		ClassName = "Frame",
		AspectRatio = 2.23008,
		Native = {
			AnchorPoint = Vector2.new(0.5, 1),
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0.5, 0.92),
			Size = UDim2.fromScale(0.265, 0.175),
			ZIndex = 10,
		},
	}, {
		UISizeConstraint = c("UISizeConstraint", {
			MaxSize = Vector2.new(330, 165),
			MinSize = Vector2.new(210, 105),
		}),

		Base = c(Pane, {
			ClassName = "ImageLabel",
			Native = {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Image = BASE_IMAGE,
				Position = UDim2.fromScale(0.5, 0.5),
				ScaleType = Enum.ScaleType.Slice,
				Size = UDim2.fromScale(1, 1),
				SliceCenter = Rect.new(104, 96, 408, 416),
			},
		}, {
			Container = c(Pane, {
				ClassName = "Frame",
				ListLayout = {
					FillDirection = Enum.FillDirection.Vertical,
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					Padding = UDim.new(0.06, 0),
				},
				Native = {
					AnchorPoint = Vector2.new(0.5, 0),
					BackgroundTransparency = 1,
					Position = UDim2.fromScale(0.5, 0.315665),
					Size = UDim2.fromScale(0.92, 0.63),
				},
			}, {
				Status = c(Pane, {
					ClassName = "TextLabel",
					MaxTextSize = 26,
					Native = {
						AnchorPoint = Vector2.new(0.5, 0),
						AutomaticSize = Enum.AutomaticSize.Y,
						BackgroundTransparency = 1,
						FontFace = Styles.FONT_FREDOKA,
						Position = UDim2.fromScale(0.5, 0),
						Size = UDim2.fromScale(0.95, 0),
						Text = statusText,
						TextColor3 = Styles.GREEN_LIGHT,
						TextScaled = true,
						TextWrapped = true,
						TextXAlignment = Enum.TextXAlignment.Center,
					},
				}),

				LeaveButton = c(PromptButton, {
					Text = "Leave Queue",
					Color = Styles.CORAL,
					Size = UDim2.fromScale(0.64, 0.38),
					OnClick = function()
						if RunService:IsRunning() then
							Knit.GetController("OrderController"):LeaveQueue()
						end
					end,
				}),
			}),

			Border = c(Pane, {
				ClassName = "ImageLabel",
				Native = {
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					Image = BORDER_IMAGE,
					ImageColor3 = Styles.GREEN_LIGHT,
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromScale(0.970972, 0.938198),
				},
			}),

			Title = c(Banner, {
				Text = "Order Queue",
				Color = Styles.GREEN,
				Size = UDim2.fromScale(1.21645, 0.371931),
			}),
		}),
	})
end
