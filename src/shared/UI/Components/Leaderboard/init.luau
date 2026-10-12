--[[
    Component: Leaderboard
    Description: A ranked standings board rendered onto a world SurfaceGui.

    V3 cloned a hand-built "Template" row out of the board model, but no board in the
    place file actually has one — the row list is built here instead, so a board only
    needs geometry.
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = Shared:WaitForChild("UI")

---> dependencies
local React = require(Packages.React)

---> styles
local Styles = require(UI.Styles)

---> private
local c = React.createElement

local ROW_HEIGHT = 0.1
local MEDAL_COLORS = {
	[1] = Color3.fromRGB(255, 215, 37),
	[2] = Color3.fromRGB(205, 205, 215),
	[3] = Color3.fromRGB(205, 145, 90),
}

export type Row = {
	Rank: number,
	UserId: number,
	Username: string,
	Icon: string,
	Value: string,
}

---> public
return function(props: {
	Title: string,
	Caption: string,
	Rows: { Row },
	Color: Color3?,
})
	local color = props.Color or Styles.GREEN

	local rowChildren: { [string]: any } = {
		UIListLayout = c("UIListLayout", {
			Padding = UDim.new(0.01, 0),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}

	for _, row in props.Rows do
		rowChildren[`Row{row.Rank}`] = c("Frame", {
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 0.75,
			LayoutOrder = row.Rank,
			Size = UDim2.fromScale(1, ROW_HEIGHT),
		}, {
			UICorner = c("UICorner", { CornerRadius = UDim.new(0.15, 0) }),

			Rank = c("TextLabel", {
				BackgroundTransparency = 1,
				FontFace = Styles.FONT_FREDOKA,
				Position = UDim2.fromScale(0.02, 0.15),
				Size = UDim2.fromScale(0.1, 0.7),
				Text = tostring(row.Rank),
				-- Top three get medal colours; everyone else the board tint.
				TextColor3 = MEDAL_COLORS[row.Rank] or color,
				TextScaled = true,
			}),

			Avatar = c("ImageLabel", {
				BackgroundTransparency = 1,
				Image = row.Icon,
				Position = UDim2.fromScale(0.13, 0.1),
				Size = UDim2.fromScale(0.8, 0.8),
				SizeConstraint = Enum.SizeConstraint.RelativeYY,
			}),

			Username = c("TextLabel", {
				BackgroundTransparency = 1,
				FontFace = Styles.FONT_FREDOKA,
				Position = UDim2.fromScale(0.25, 0.15),
				Size = UDim2.fromScale(0.45, 0.7),
				Text = row.Username,
				TextColor3 = Color3.new(1, 1, 1),
				TextScaled = true,
				TextTruncate = Enum.TextTruncate.AtEnd,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),

			Value = c("TextLabel", {
				BackgroundTransparency = 1,
				FontFace = Styles.FONT_FREDOKA,
				Position = UDim2.fromScale(0.72, 0.15),
				Size = UDim2.fromScale(0.26, 0.7),
				Text = row.Value,
				TextColor3 = color,
				TextScaled = true,
				TextXAlignment = Enum.TextXAlignment.Right,
			}),
		})
	end

	return c("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
	}, {
		UIPadding = c("UIPadding", {
			PaddingBottom = UDim.new(0.03, 0),
			PaddingLeft = UDim.new(0.04, 0),
			PaddingRight = UDim.new(0.04, 0),
			PaddingTop = UDim.new(0.03, 0),
		}),

		Title = c("TextLabel", {
			BackgroundTransparency = 1,
			FontFace = Styles.FONT_FREDOKA,
			Size = UDim2.fromScale(1, 0.1),
			Text = props.Title,
			TextColor3 = color,
			TextScaled = true,
		}),

		Caption = c("TextLabel", {
			BackgroundTransparency = 1,
			FontFace = Styles.FONT_FREDOKA,
			Position = UDim2.fromScale(0, 0.1),
			Size = UDim2.fromScale(1, 0.06),
			Text = props.Caption,
			TextColor3 = Color3.new(1, 1, 1),
			TextScaled = true,
			TextTransparency = 0.35,
		}),

		Empty = if #props.Rows == 0
			then c("TextLabel", {
				BackgroundTransparency = 1,
				FontFace = Styles.FONT_FREDOKA,
				Position = UDim2.fromScale(0, 0.4),
				Size = UDim2.fromScale(1, 0.1),
				Text = "No entries yet",
				TextColor3 = Color3.new(1, 1, 1),
				TextScaled = true,
				TextTransparency = 0.5,
			})
			else nil,

		Rows = c("ScrollingFrame", {
			Active = true,
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			CanvasSize = UDim2.new(),
			Position = UDim2.fromScale(0, 0.18),
			ScrollBarImageColor3 = color,
			ScrollBarThickness = 4,
			ScrollingDirection = Enum.ScrollingDirection.Y,
			Size = UDim2.fromScale(1, 0.82),
		}, rowChildren),
	})
end
