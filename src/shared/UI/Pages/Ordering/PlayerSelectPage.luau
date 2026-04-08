local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = Shared:WaitForChild("UI")

local React = require(Packages.React)
local Pane = require(UI.Components.Pane)
local PlayerCard = require(UI.Components.Buttons.PlayerCard)
local Styles = require(UI.Styles)

local c = React.createElement

return function(props)
	local playerChildren = {
		UIGridLayout = c("UIGridLayout", {
			CellPadding = UDim2.fromScale(0.039, 0.065),
			CellSize = UDim2.fromScale(0.25, 0.5),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}

	if #props.NearbyPlayers == 0 then
		playerChildren.Empty = c(Pane, {
			ClassName = "TextLabel",
			Native = {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				FontFace = Styles.FONT_FREDOKA,
				Position = UDim2.fromScale(0.5, 0.4),
				Size = UDim2.fromScale(0.8, 0.15),
				Text = "No players nearby",
				TextColor3 = Styles.GRAY,
				TextScaled = true,
			},
		})
	else
		for i, player in ipairs(props.NearbyPlayers) do
			playerChildren["Player_" .. i] = c(PlayerCard, {
				PlayerName = player.Name,
				UserId = player.UserId,
				LayoutOrder = i,
				OnClick = function()
					props.OnPlayerSelected(player)
				end,
			})
		end
	end

	return c(Pane, {
		ClassName = "Frame",
		Native = {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
		},
	}, {
		Grid = c("ScrollingFrame", {
			Active = true,
			AnchorPoint = Vector2.new(0.5, 0.5),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			BorderSizePixel = 0,
			BackgroundTransparency = 1,
			CanvasSize = UDim2.new(),
			Position = UDim2.fromScale(0.518627, 0.55),
			ScrollBarImageColor3 = Color3.new(),
			ScrollBarThickness = 5,
			Size = UDim2.fromScale(0.964196, 0.8),
		}, playerChildren),

		Search = c(Pane, {
			ClassName = "Frame",
			Native = {
				BackgroundColor3 = Color3.new(1, 1, 1),
				BackgroundTransparency = 0,
				Position = UDim2.fromScale(0.0365295, 0),
				Size = UDim2.fromScale(0.619106, 0.118342),
			},
		}, {
			TextBox = c("TextBox", {
				BackgroundTransparency = 1,
				FontFace = Styles.FONT_FREDOKA,
				PlaceholderText = "Search...",
				Size = UDim2.fromScale(1, 1),
				Text = "",
				TextColor3 = Color3.new(),
				TextScaled = true,
				TextXAlignment = Enum.TextXAlignment.Left,
			}, {
				UITextSizeConstraint = c("UITextSizeConstraint", { MaxTextSize = 25 }),
			}),

			Underline = c(Pane, {
				ClassName = "Frame",
				Native = {
					BackgroundColor3 = Color3.fromRGB(25, 25, 25),
					BackgroundTransparency = 0,
					Position = UDim2.fromScale(0, 1),
					Size = UDim2.new(1, 0, 0, 1),
				},
			}),
		}),
	})
end
