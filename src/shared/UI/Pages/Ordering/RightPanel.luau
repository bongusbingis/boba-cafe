local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = Shared:WaitForChild("UI")

local React = require(Packages.React)
local Pane = require(UI.Components.Pane)
local ActionButton = require(UI.Components.Buttons.ActionButton)
local OrderItem = require(script.Parent.OrderItem)
local Styles = require(UI.Styles)

local ORANGE = Color3.fromRGB(237, 114, 47)
local c = React.createElement
local localPlayer = Players.LocalPlayer or { Name = "bongusbingus" }

local function patienceColor(fraction: number)
	if fraction < 0.25 then
		return Styles.RED
	elseif fraction < 0.5 then
		return Styles.GOLD_MID
	end
	return Styles.GREEN
end

return function(props)
	local orderChildren = {
		UIListLayout = c("UIListLayout", {
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}

	for i, item in ipairs(props.OrderItems) do
		orderChildren["Order_" .. i] = c(OrderItem, {
			Name = props.ResolveItemName(item),
			Description = props.ResolveItemDescription(item),
			LayoutOrder = i,
			OnRemove = function()
				props.OnOrderItemRemoved(i)
			end,
		})
	end

	orderChildren["BottomSpacer"] = c("Frame", {
		BackgroundTransparency = 1,
		LayoutOrder = 9999,
		Size = UDim2.new(1, 0, 0, 24),
		Visible = true,
	})

	local hasRequestText = typeof(props.NpcOrderText) == "string" and #props.NpcOrderText > 0
	local showPatience = (
		props.IsNpc ~= false
		and (hasRequestText or props.NpcId ~= nil or props.Patience ~= nil or props.PatienceEnd ~= nil)
	) or props.PreviewPatience ~= nil

	local patience, setPatience = React.useState(props.PreviewPatience or props.Patience or 1)

	React.useEffect(function()
		if props.PreviewPatience ~= nil or props.Patience ~= nil then
			setPatience(props.PreviewPatience or props.Patience or 1)
			return
		end

		if not RunService:IsRunning() then
			return
		end

		local patienceEnd = props.PatienceEnd
		local patienceTotal = props.PatienceTotal
		local npcModel = nil
		if props.NpcId then
			local customersFolder = workspace:FindFirstChild("Customers")
			npcModel = if customersFolder then customersFolder:FindFirstChild(props.NpcId) else nil
			if npcModel then
				local endAttr = npcModel:GetAttribute("PatienceEnd")
				local totalAttr = npcModel:GetAttribute("PatienceTotal")
				if typeof(endAttr) == "number" then
					patienceEnd = endAttr
				end
				if typeof(totalAttr) == "number" then
					patienceTotal = totalAttr
				end
			end
		end

		if typeof(patienceEnd) ~= "number" or typeof(patienceTotal) ~= "number" or patienceTotal <= 0 then
			setPatience(1)
			return
		end

		local function updateFraction()
			local currentEnd = patienceEnd
			local currentTotal = patienceTotal
			if npcModel then
				local endAttr = npcModel:GetAttribute("PatienceEnd")
				local totalAttr = npcModel:GetAttribute("PatienceTotal")
				if typeof(endAttr) == "number" then
					currentEnd = endAttr
				end
				if typeof(totalAttr) == "number" then
					currentTotal = totalAttr
				end
			end
			local fraction = math.clamp((currentEnd - workspace:GetServerTimeNow()) / currentTotal, 0, 1)
			setPatience(math.floor(fraction * 200) / 200)
		end

		updateFraction()
		local conn = RunService.Heartbeat:Connect(updateFraction)
		return function()
			conn:Disconnect()
		end
	end, { props.PreviewPatience, props.Patience, props.PatienceEnd, props.PatienceTotal, props.NpcId })

	return c(Pane, {
		ClassName = "Frame",
		ListLayout = {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		},
		Native = {
			AnchorPoint = Vector2.new(1, 0),
			BackgroundColor3 = Color3.fromRGB(230, 230, 230),
			BackgroundTransparency = 0,
			Position = UDim2.fromScale(1, 0),
			Size = UDim2.fromScale(0.249926, 1),
		},
	}, {
		Barista = c(Pane, {
			ClassName = "Frame",
			Native = {
				BackgroundTransparency = 1,
				LayoutOrder = 1,
				Size = UDim2.fromScale(1, 0.2),
			},
		}, {
			Title = c(Pane, {
				ClassName = "TextLabel",
				Native = {
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					FontFace = Styles.FONT_FREDOKA,
					Position = UDim2.fromScale(0.5, 0.19),
					Size = UDim2.fromScale(0.89, 0.23),
					Text = "Serving as:",
					TextColor3 = ORANGE,
					TextScaled = true,
					TextXAlignment = Enum.TextXAlignment.Left,
				},
			}),

			Headshot = c(Pane, {
				ClassName = "ImageLabel",
				AspectRatio = 1,
				Native = {
					AnchorPoint = Vector2.new(0, 0.5),
					BackgroundTransparency = 1,
					Image = props.StaffAvatarUrl,
					Position = UDim2.fromScale(0.0647059, 0.632911),
					ScaleType = Enum.ScaleType.Fit,
					Size = UDim2.fromScale(0.282353, 0.594937),
				},
			}),

			Info = c(Pane, {
				ClassName = "Frame",
				ListLayout = {
					FillDirection = Enum.FillDirection.Vertical,
					HorizontalAlignment = Enum.HorizontalAlignment.Left,
					SortOrder = Enum.SortOrder.LayoutOrder,
				},
				Padding = {
					PaddingLeft = UDim.new(0.075, 0),
				},
				Native = {
					AnchorPoint = Vector2.new(0, 0.5),
					BackgroundTransparency = 1,
					Position = UDim2.fromScale(0.364706, 0.683544),
					Size = UDim2.fromScale(0.58, 0.5),
				},
			}, {
				PlayerName = c(Pane, {
					ClassName = "TextLabel",
					Native = {
						BackgroundTransparency = 1,
						FontFace = Styles.FONT_FREDOKA,
						LayoutOrder = 1,
						Size = UDim2.fromScale(1, 0.363022),
						Text = localPlayer.Name,
						TextColor3 = Color3.new(),
						TextScaled = true,
						TextXAlignment = Enum.TextXAlignment.Left,
					},
				}),

				PlayerRole = c(Pane, {
					ClassName = "TextLabel",
					Native = {
						AnchorPoint = Vector2.new(0.5, 0),
						BackgroundTransparency = 1,
						FontFace = Styles.FONT_FREDOKA,
						LayoutOrder = 2,
						Size = UDim2.fromScale(1, 0.363022),
						Text = if props.StaffLevel ~= nil
							then `Level {props.StaffLevel}`
							elseif props.StaffRole ~= nil then props.StaffRole
							else "Level 1",
						TextColor3 = Color3.new(),
						TextScaled = true,
						TextXAlignment = Enum.TextXAlignment.Left,
					},
				}),
			}),
		}),

		CustomerPatience = showPatience and c(Pane, {
			ClassName = "Frame",
			Native = {
				BackgroundTransparency = 1,
				LayoutOrder = 2,
				Size = UDim2.fromScale(1, 0.08),
			},
			Padding = {
				PaddingLeft = UDim.new(0.05, 0),
				PaddingRight = UDim.new(0.05, 0),
			},
			ListLayout = {
				FillDirection = Enum.FillDirection.Vertical,
				HorizontalAlignment = Enum.HorizontalAlignment.Left,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 4),
			},
		}, {
			Title = c(Pane, {
				ClassName = "TextLabel",
				Native = {
					BackgroundTransparency = 1,
					FontFace = Styles.FONT_FREDOKA,
					LayoutOrder = 1,
					Size = UDim2.fromScale(1, 0.55),
					Text = "Customer Patience:",
					TextColor3 = ORANGE,
					TextScaled = true,
					TextXAlignment = Enum.TextXAlignment.Left,
				},
			}),
			ProgressBar = c("Frame", {
				BackgroundColor3 = Styles.GRAY,
				BorderSizePixel = 0,
				LayoutOrder = 2,
				Size = UDim2.new(1, 0, 0, 8),
			}, {
				Corner = c("UICorner", { CornerRadius = Styles.CORNER_FULL }),
				Fill = c("Frame", {
					BackgroundColor3 = patienceColor(math.clamp(patience, 0, 1)),
					BorderSizePixel = 0,
					Size = UDim2.fromScale(math.clamp(patience, 0, 1), 1),
				}, {
					Corner = c("UICorner", { CornerRadius = Styles.CORNER_FULL }),
				}),
			}),
		}) or nil,

		Order = c(Pane, {
			ClassName = "Frame",
			Native = {
				BackgroundTransparency = 1,
				LayoutOrder = 3,
				Size = if showPatience then UDim2.fromScale(1, 0.58) else UDim2.fromScale(1, 0.65),
			},
			ListLayout = {
				FillDirection = Enum.FillDirection.Vertical,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0.025, 0),
			},
		}, {
			Title = c(Pane, {
				ClassName = "TextLabel",
				Native = {
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					FontFace = Styles.FONT_FREDOKA,
					Position = UDim2.fromScale(0.5, 0.19),
					Size = UDim2.fromScale(0.89, 0.085),
					Text = string.format("Order (%d/%d):", #props.OrderItems, props.MaxOrderItems),
					TextColor3 = ORANGE,
					TextScaled = true,
					TextXAlignment = Enum.TextXAlignment.Left,
					LayoutOrder = 1,
				},
			}),

			Separator = c(Pane, {
				ClassName = "Frame",
				Native = {
					AnchorPoint = Vector2.new(0.5, 0),
					BackgroundColor3 = Color3.fromRGB(202, 202, 202),
					BackgroundTransparency = 0,
					LayoutOrder = 2,
					Size = UDim2.fromScale(1, 0.005),
				},
			}),

			OrderList = c("ScrollingFrame", {
				Active = true,
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				BorderSizePixel = 0,
				BackgroundTransparency = 1,
				CanvasSize = UDim2.new(),
				Position = UDim2.fromScale(0.0549998, 0.343522),
				ScrollBarImageColor3 = Color3.new(),
				ScrollBarThickness = 5,
				ScrollingDirection = Enum.ScrollingDirection.Y,
				Size = UDim2.fromScale(0.92, 0.85),
				LayoutOrder = 3,
			}, orderChildren),

			Submit = #props.OrderItems > 0 and c(ActionButton, {
				Text = "Submit Order",
				Color = Styles.GREEN_DIM,
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.fromScale(0.163498, 0),
				Size = UDim2.fromScale(0.9, 0.195),
				OnClick = props.OnSubmit,
				LayoutOrder = 4,
			}) or nil,
		}),
	})
end
