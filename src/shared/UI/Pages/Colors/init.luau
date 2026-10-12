--[[
    Page: Colors
    Description: Recolour your equipped nametag. Backed by the Nametag Customizer game
    pass via CosmeticsService:SetNametagColor.

    A swatch palette plus RGB sliders rather than V3's BTHSVColorPicker module — the
    same result with no third-party colour-picker dependency.
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = Shared:WaitForChild("UI")

---> dependencies
local React = require(Packages.React)
local Knit = require(Packages.Knit)

---> styles
local Styles = require(UI.Styles)

---> components
local Pane = require(UI.Components.Pane)
local Page = require(UI.Components.Core.Page)

---> private
local c = React.createElement

local SWATCHES = {
	Color3.fromRGB(220, 50, 50),
	Color3.fromRGB(255, 130, 40),
	Color3.fromRGB(255, 205, 60),
	Color3.fromRGB(120, 220, 90),
	Color3.fromRGB(60, 200, 180),
	Color3.fromRGB(70, 150, 255),
	Color3.fromRGB(150, 100, 255),
	Color3.fromRGB(255, 120, 200),
	Color3.fromRGB(255, 255, 255),
	Color3.fromRGB(140, 140, 150),
	Color3.fromRGB(60, 60, 70),
	Color3.fromRGB(255, 215, 37),
}

local CHANNELS = { "R", "G", "B" }
local CHANNEL_TINT = {
	R = Color3.fromRGB(230, 70, 70),
	G = Color3.fromRGB(90, 210, 90),
	B = Color3.fromRGB(80, 140, 255),
}

---> public
return function(props)
	local color, setColor = React.useState(Color3.fromRGB(255, 255, 255))
	local status, setStatus = React.useState("")
	local busy, setBusy = React.useState(false)

	local function apply(newColor: Color3?)
		if busy then
			return
		end
		setBusy(true)

		task.spawn(function()
			local service = Knit.GetService("CosmeticsService")
			local ok, success, message = service:SetNametagColor(newColor):await()

			setBusy(false)
			-- ok is the promise result; success/message come from the server.
			setStatus(if ok then (message or "") else "Something went wrong.")
			if ok and success and newColor then
				setColor(newColor)
			end
		end)
	end

	---> swatches
	local swatchChildren: { [string]: any } = {
		UIGridLayout = c("UIGridLayout", {
			CellPadding = UDim2.fromScale(0.02, 0.06),
			CellSize = UDim2.fromScale(0.145, 0.4),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}

	for index, swatch in SWATCHES do
		swatchChildren[`Swatch{index}`] = c(Pane, {
			ClassName = "TextButton",
			CornerRadius = Styles.CORNER_CARD,
			Stroke = { Color = Styles.OFFWHITE, Thickness = 2 },
			OnClick = function()
				setColor(swatch)
			end,
			Native = {
				BackgroundColor3 = swatch,
				BackgroundTransparency = 0,
				LayoutOrder = index,
				Text = "",
			},
		})
	end

	---> channel sliders, as -/+ steppers (draggable sliders need input plumbing the
	---> dialog layer does not currently provide)
	local sliderChildren: { [string]: any } = {
		UIListLayout = c("UIListLayout", {
			Padding = UDim.new(0.04, 0),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}

	for index, channel in CHANNELS do
		local value = math.round(color[channel] * 255)

		local function nudge(delta: number)
			local channels = {
				R = math.round(color.R * 255),
				G = math.round(color.G * 255),
				B = math.round(color.B * 255),
			}
			channels[channel] = math.clamp(channels[channel] + delta, 0, 255)
			setColor(Color3.fromRGB(channels.R, channels.G, channels.B))
		end

		sliderChildren[channel] = c(Pane, {
			ClassName = "Frame",
			Native = {
				BackgroundTransparency = 1,
				LayoutOrder = index,
				Size = UDim2.fromScale(1, 0.3),
			},
		}, {
			Label = c(Pane, {
				ClassName = "TextLabel",
				Native = {
					BackgroundTransparency = 1,
					FontFace = Styles.FONT_FREDOKA,
					Size = UDim2.fromScale(0.18, 1),
					Text = channel,
					TextColor3 = CHANNEL_TINT[channel],
					TextScaled = true,
				},
			}),

			Minus = c(Pane, {
				ClassName = "TextButton",
				CornerRadius = Styles.CORNER_FULL,
				OnClick = function()
					nudge(-15)
				end,
				Native = {
					BackgroundColor3 = Styles.GREEN_DEEP,
					BackgroundTransparency = 0,
					FontFace = Styles.FONT_FREDOKA,
					Position = UDim2.fromScale(0.2, 0.1),
					Size = UDim2.fromScale(0.16, 0.8),
					Text = "-",
					TextColor3 = Styles.OFFWHITE,
					TextScaled = true,
				},
			}),

			Value = c(Pane, {
				ClassName = "TextLabel",
				Native = {
					BackgroundTransparency = 1,
					FontFace = Styles.FONT_FREDOKA,
					Position = UDim2.fromScale(0.38, 0.1),
					Size = UDim2.fromScale(0.24, 0.8),
					Text = tostring(value),
					TextColor3 = Styles.OFFWHITE,
					TextScaled = true,
				},
			}),

			Plus = c(Pane, {
				ClassName = "TextButton",
				CornerRadius = Styles.CORNER_FULL,
				OnClick = function()
					nudge(15)
				end,
				Native = {
					BackgroundColor3 = Styles.GREEN_DEEP,
					BackgroundTransparency = 0,
					FontFace = Styles.FONT_FREDOKA,
					Position = UDim2.fromScale(0.64, 0.1),
					Size = UDim2.fromScale(0.16, 0.8),
					Text = "+",
					TextColor3 = Styles.OFFWHITE,
					TextScaled = true,
				},
			}),
		})
	end

	local pageContent = c(Pane, {
		ClassName = "Frame",
		AspectRatio = 1.3468467,
		CornerRadius = Styles.CORNER_CARD,
		Stroke = { Color = Styles.OFFWHITE, Thickness = 3.5 },
		Native = {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Styles.GREEN_MID,
			BackgroundTransparency = 0,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.39647886, 0.5434795),
		},
	}, {
		Title = c(Pane, {
			ClassName = "TextLabel",
			Native = {
				BackgroundTransparency = 1,
				FontFace = Styles.FONT_FREDOKA,
				Position = UDim2.fromScale(0.04, 0.03),
				Size = UDim2.fromScale(0.6, 0.1),
				Text = "Nametag Colour",
				TextColor3 = Styles.OFFWHITE,
				TextScaled = true,
				TextXAlignment = Enum.TextXAlignment.Left,
			},
		}),

		Close = c(Pane, {
			ClassName = "TextButton",
			CornerRadius = Styles.CORNER_FULL,
			OnClick = function()
				props.ClosePage()
			end,
			Native = {
				AnchorPoint = Vector2.new(1, 0),
				BackgroundColor3 = Styles.RED,
				BackgroundTransparency = 0,
				FontFace = Styles.FONT_FREDOKA,
				Position = UDim2.fromScale(0.965, 0.04),
				Size = UDim2.fromScale(0.08, 0.1),
				Text = "X",
				TextColor3 = Styles.OFFWHITE,
				TextScaled = true,
			},
		}),

		---> live preview of the player's tag
		Preview = c(Pane, {
			ClassName = "Frame",
			CornerRadius = Styles.CORNER_PILL,
			Stroke = { Color = Styles.OFFWHITE, Thickness = 2 },
			Native = {
				AnchorPoint = Vector2.new(0.5, 0),
				BackgroundColor3 = color,
				BackgroundTransparency = 0,
				Position = UDim2.fromScale(0.5, 0.15),
				Size = UDim2.fromScale(0.6, 0.12),
			},
		}, {
			Name = c(Pane, {
				ClassName = "TextLabel",
				Native = {
					BackgroundTransparency = 1,
					FontFace = Styles.FONT_FREDOKA,
					Size = UDim2.fromScale(1, 1),
					Text = Players.LocalPlayer.DisplayName,
					TextColor3 = Styles.OFFWHITE,
					TextScaled = true,
					TextStrokeTransparency = 0.5,
				},
			}),
		}),

		Swatches = c(Pane, {
			ClassName = "Frame",
			Native = {
				AnchorPoint = Vector2.new(0.5, 0),
				BackgroundTransparency = 1,
				Position = UDim2.fromScale(0.5, 0.3),
				Size = UDim2.fromScale(0.88, 0.18),
			},
		}, swatchChildren),

		Sliders = c(Pane, {
			ClassName = "Frame",
			Native = {
				AnchorPoint = Vector2.new(0.5, 0),
				BackgroundTransparency = 1,
				Position = UDim2.fromScale(0.5, 0.51),
				Size = UDim2.fromScale(0.8, 0.22),
			},
		}, sliderChildren),

		Status = c(Pane, {
			ClassName = "TextLabel",
			Native = {
				BackgroundTransparency = 1,
				FontFace = Styles.FONT_FREDOKA,
				Position = UDim2.fromScale(0.1, 0.75),
				Size = UDim2.fromScale(0.8, 0.06),
				Text = status,
				TextColor3 = Styles.CREAM,
				TextScaled = true,
			},
		}),

		Apply = c(Pane, {
			ClassName = "TextButton",
			CornerRadius = Styles.CORNER_PILL,
			OnClick = function()
				apply(color)
			end,
			Native = {
				AnchorPoint = Vector2.new(0.5, 1),
				BackgroundColor3 = if busy then Styles.GRAY else Styles.GREEN_BADGE,
				BackgroundTransparency = 0,
				FontFace = Styles.FONT_FREDOKA,
				Position = UDim2.fromScale(0.33, 0.96),
				Size = UDim2.fromScale(0.34, 0.11),
				Text = if busy then "..." else "Apply",
				TextColor3 = Styles.OFFWHITE,
				TextScaled = true,
			},
		}),

		Reset = c(Pane, {
			ClassName = "TextButton",
			CornerRadius = Styles.CORNER_PILL,
			OnClick = function()
				apply(nil)
			end,
			Native = {
				AnchorPoint = Vector2.new(0.5, 1),
				BackgroundColor3 = Styles.RED,
				BackgroundTransparency = 0,
				FontFace = Styles.FONT_FREDOKA,
				Position = UDim2.fromScale(0.7, 0.96),
				Size = UDim2.fromScale(0.26, 0.11),
				Text = "Reset",
				TextColor3 = Styles.OFFWHITE,
				TextScaled = true,
			},
		}),
	})

	return c(Page, {
		IsVisible = true,
		PageContent = pageContent,
		OnClosing = function() end,
	})
end
