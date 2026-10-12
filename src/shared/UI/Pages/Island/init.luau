--[[
    Page: Island
    Description: Celebrity private islands — shows whether you're a Celebrity, lets you
    visit any loaded island, and offers the Roblox Premium trial if eligible.

    Backed by CelebrityService (IsCelebrity / GetLoadedIslands / VisitIsland /
    ClaimPremiumTrial).
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
local OpenableMenu = require(UI.Components.Core.OpenableMenu)

---> private
local c = React.createElement

local LocalPlayer = Players.LocalPlayer

---> public
return function(props)
	-- nil = loading
	local islands, setIslands = React.useState(nil)
	local isCelebrity, setIsCelebrity = React.useState(false)
	local status, setStatus = React.useState("")

	local refresh = React.useCallback(function()
		task.spawn(function()
			local service = Knit.GetService("CelebrityService")

			local celebOk, celeb = service:IsCelebrity():await()
			if celebOk then
				setIsCelebrity(celeb == true)
			end

			local ok, list = service:GetLoadedIslands():await()
			setIslands(if ok and list then list else {})
		end)
	end, {})

	React.useEffect(function()
		refresh()

		local service = Knit.GetService("CelebrityService")
		local changed = service.IslandChanged:Connect(refresh)

		return function()
			changed:Disconnect()
		end
	end, { refresh })

	local function visit(userId: number)
		task.spawn(function()
			local ok, success, message = Knit.GetService("CelebrityService"):VisitIsland(userId):await()
			setStatus(if ok and message then message else "Couldn't teleport.")
			if ok and success then
				props.ClosePage()
			end
		end)
	end

	---> island list
	local rows: { [string]: any } = {
		UIListLayout = c("UIListLayout", {
			Padding = UDim.new(0.02, 0),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}

	if islands == nil then
		rows.Loading = c(Pane, {
			ClassName = "TextLabel",
			Native = {
				BackgroundTransparency = 1,
				FontFace = Styles.FONT_FREDOKA,
				Size = UDim2.fromScale(1, 0.12),
				Text = "Loading islands...",
				TextColor3 = Styles.GRAY,
				TextScaled = true,
			},
		})
	elseif #islands == 0 then
		rows.Empty = c(Pane, {
			ClassName = "TextLabel",
			Native = {
				BackgroundTransparency = 1,
				FontFace = Styles.FONT_FREDOKA,
				Size = UDim2.fromScale(1, 0.12),
				Text = "No islands are loaded right now.",
				TextColor3 = Styles.GRAY,
				TextScaled = true,
			},
		})
	else
		for index, island in islands do
			local isOwn = island.UserId == LocalPlayer.UserId

			rows[`Island{island.UserId}`] = c(Pane, {
				ClassName = "Frame",
				CornerRadius = Styles.CORNER_CARD,
				Stroke = { Color = if isOwn then Styles.GOLD else Styles.GREEN_LIGHT, Thickness = 2.5 },
				Native = {
					BackgroundColor3 = Styles.OFFWHITE,
					BackgroundTransparency = 0,
					LayoutOrder = index,
					Size = UDim2.fromScale(1, 0.16),
				},
			}, {
				Name = c(Pane, {
					ClassName = "TextLabel",
					Native = {
						BackgroundTransparency = 1,
						FontFace = Styles.FONT_FREDOKA,
						Position = UDim2.fromScale(0.05, 0.2),
						Size = UDim2.fromScale(0.55, 0.6),
						Text = if isOwn then `{island.Name} (you)` else island.Name,
						TextColor3 = Styles.GREEN_DEEP,
						TextScaled = true,
						TextTruncate = Enum.TextTruncate.AtEnd,
						TextXAlignment = Enum.TextXAlignment.Left,
					},
				}),

				Visit = c(Pane, {
					ClassName = "TextButton",
					CornerRadius = Styles.CORNER_PILL,
					OnClick = function()
						visit(island.UserId)
					end,
					Native = {
						AnchorPoint = Vector2.new(1, 0.5),
						BackgroundColor3 = Styles.GREEN_BADGE,
						BackgroundTransparency = 0,
						FontFace = Styles.FONT_FREDOKA,
						Position = UDim2.fromScale(0.95, 0.5),
						Size = UDim2.fromScale(0.3, 0.6),
						Text = "Visit",
						TextColor3 = Styles.OFFWHITE,
						TextScaled = true,
					},
				}),
			})
		end
	end

	local content = c(Pane, {
		ClassName = "Frame",
		Native = {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
		},
	}, {
		Heading = c(Pane, {
			ClassName = "TextLabel",
			Native = {
				BackgroundTransparency = 1,
				FontFace = Styles.FONT_FREDOKA,
				Position = UDim2.fromScale(0, 0.02),
				Size = UDim2.fromScale(1, 0.09),
				Text = "Celebrity Islands",
				TextColor3 = Styles.GREEN,
				TextScaled = true,
			},
		}),

		Membership = c(Pane, {
			ClassName = "TextLabel",
			Native = {
				BackgroundTransparency = 1,
				FontFace = Styles.FONT_FREDOKA,
				Position = UDim2.fromScale(0, 0.115),
				Size = UDim2.fromScale(1, 0.05),
				Text = if isCelebrity
					then "Your island is loaded — visit anyone below."
					else "Become a Celebrity to get your own island.",
				TextColor3 = Styles.GREEN_DEEP,
				TextScaled = true,
			},
		}),

		List = c(Pane, {
			ClassName = "ScrollingFrame",
			Native = {
				AnchorPoint = Vector2.new(0.5, 0),
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				CanvasSize = UDim2.new(),
				Position = UDim2.fromScale(0.5, 0.22),
				ScrollBarImageColor3 = Styles.OFFWHITE,
				ScrollBarThickness = 6,
				ScrollingDirection = Enum.ScrollingDirection.Y,
				Size = UDim2.fromScale(0.92, 0.6),
			},
		}, rows),

		Status = c(Pane, {
			ClassName = "TextLabel",
			Native = {
				BackgroundTransparency = 1,
				FontFace = Styles.FONT_FREDOKA,
				Position = UDim2.fromScale(0.06, 0.84),
				Size = UDim2.fromScale(0.88, 0.05),
				Text = status,
				TextColor3 = Styles.GREEN_DEEP,
				TextScaled = true,
			},
		}),

		-- No "Claim Premium Trial" button here: the HUD only shows the Island button to
		-- existing Celebrities, so a trial offer on this page would be unreachable by
		-- the only people it applies to. Selling/claiming Celebrity belongs on the
		-- Shop's existing Celebrity tab, which every player can open.
	})

	return c(OpenableMenu, {
		TitleText = "Island",
		TitleColor = Styles.GOLD_MID,
		Pages = {
			{
				Key = "Islands",
				Label = "Islands",
				LayoutOrder = 1,
				Content = { Page = content },
				ButtonColor = Styles.GOLD_MID,
				ButtonTextColor = Styles.GOLD_DEEP,
			},
		},
		OnClose = function()
			props.ClosePage()
		end,
	})
end
