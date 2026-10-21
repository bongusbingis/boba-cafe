local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local React = require(Packages.React)
local Knit = require(Packages.Knit)

local UI = Shared:WaitForChild("UI")
local Styles = require(UI.Styles)
local Pane = require(UI.Components.Pane)
local Page = require(UI.Components.Core.Page)

local Content = require(script.Content)

local c = React.createElement
local usePx = require(UI.Hooks.usePx)

return function(props)
	local px = usePx()
	local player = Players.LocalPlayer
	local function readLevel(): number
		local value = player and player:GetAttribute("Level")
		return if typeof(value) == "number" then value else 1
	end
	local level, setLevel = React.useState(readLevel)
	React.useEffect(function()
		if player == nil then
			return nil
		end
		local connection = player:GetAttributeChangedSignal("Level"):Connect(function()
			setLevel(readLevel())
		end)
		return function()
			connection:Disconnect()
		end
	end, {})
	local page, setPage = React.useState("Recipes")

	local isRecipes = page == "Recipes"
	local isTips = page == "Tips"

	local function makeToggleState(targetPage)
		return function()
			setPage(targetPage)
		end
	end

	local textContent = c(Pane, {
		ClassName = "ScrollingFrame",
		Native = {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.fromScale(0.5, 1),
			Size = UDim2.fromScale(1, 0.875),
			BackgroundTransparency = 1,
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollBarThickness = 10,
			ScrollBarImageColor3 = Styles.ROSE_DEEP,
			ScrollBarImageTransparency = 0,
			CanvasSize = UDim2.new(),
		},
	}, {
		Label = c(Pane, {
			ClassName = "TextLabel",
			Native = {
				AutomaticSize = Enum.AutomaticSize.Y,
				Size = UDim2.fromScale(0.95, 0),
				FontFace = Styles.FONT_FREDOKA,
				Position = UDim2.fromScale(0.025, 0),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Top,
				TextColor3 = Styles.OFFWHITE,
				TextSize = px(35),
				TextWrapped = true,
				Text = if isRecipes then Content.build(nil, level) else Content.Tips,
				RichText = true,
			},
		}),
	})

	local pageContent = c(Pane, {
		ClassName = "Frame",
		AspectRatio = 0.75,
		CornerRadius = Styles.CORNER_CARD,
		Stroke = {
			Color = Styles.OFFWHITE,
			Thickness = 3.5,
		},
		Native = {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.fromScale(1.05, 0.5),
			BackgroundTransparency = 0,
			BackgroundColor3 = Styles.ROSE_MID,
			Size = UDim2.fromScale(0.65, 0.85),
		},
	}, {
		TextContent = textContent,
		Line = c(Pane, {
			ClassName = "Frame",
			Native = {
				Size = UDim2.new(1, 0, 0, px(5)),
				Position = UDim2.fromScale(0, 0.1),
				BackgroundColor3 = Styles.OFFWHITE,
				BackgroundTransparency = 0,
				ZIndex = 2,
			},
		}),
		Separator = c(Pane, {
			ClassName = "Frame",
			Native = {
				Size = UDim2.new(0, px(5), 0.1, 0),
				Position = UDim2.fromScale(0.43, 0),
				AnchorPoint = Vector2.new(0.5, 0),
				BackgroundColor3 = Styles.OFFWHITE,
				BackgroundTransparency = 0,
				ZIndex = 2,
			},
		}),
		TopBar = c(Pane, {
			ClassName = "Frame",
			CornerRadius = Styles.CORNER_CARD,
			Native = {
				Size = UDim2.fromScale(1, 0.1),
				ZIndex = 2,
			},
			ListLayout = {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, 5),
			},
		}, {
			Title = c(Pane, {
				ClassName = "TextButton",
				Stroke = isRecipes and {
					Color = Styles.ROSE_DEEP,
					Thickness = px(5),
				} or nil,
				OnClick = makeToggleState("Recipes"),
				Native = {
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					FontFace = Styles.FONT_FREDOKA,
					Position = UDim2.fromScale(0.5, 0.5),
					TextColor3 = Styles.OFFWHITE,
					TextScaled = true,
					Text = "Recipes",
					Size = UDim2.fromScale(0.425, 0.8),
					AutomaticSize = Enum.AutomaticSize.X,
				},
			}),
			Test = c(Pane, {
				ClassName = "TextButton",
				Stroke = isTips and {
					Color = Styles.ROSE_DEEP,
					Thickness = px(5),
				} or nil,
				OnClick = makeToggleState("Tips"),
				Native = {
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					FontFace = Styles.FONT_FREDOKA,
					Position = UDim2.fromScale(0.5, 0.5),
					TextColor3 = Styles.OFFWHITE,
					TextScaled = true,
					Text = "Tips",
					Size = UDim2.fromScale(0.55, 0.8),
					RichText = true,
					AutomaticSize = Enum.AutomaticSize.X,
				},
			}),
		}),
	})
	return c(Page, {
		IsVisible = true,
		PageContent = pageContent,
		OnClosing = function() end,
	})
end
