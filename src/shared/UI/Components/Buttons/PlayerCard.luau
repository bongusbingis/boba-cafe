--[[
	PlayerCard
	A square portrait card displaying a player's avatar and username.
	Used in grid-based player selection UIs.

	Props:
	- PlayerName: Display name shown at the bottom of the card.
	- UserId: Player UserId — when provided the headshot is fetched asynchronously.
	- AvatarImage: Explicit headshot URL, used as a fallback or when UserId is absent.
	- LayoutOrder: Layout ordering.
	- OnClick: Selection callback.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = Shared:WaitForChild("UI")

---> dependencies
local React = require(Packages.React)
local ReactSpring = require(Packages.ReactSpring)

---> components
local Pane = require(UI.Components.Pane)

---> styles
local Styles = require(UI.Styles)

---> constants
local SPRING_CONFIG = Styles.SPRING_STANDARD
local CARD_IMAGE = "http://www.roblox.com/asset/?id=13866611257"
local CARD_TINT = Color3.fromRGB(217, 217, 217)

---> private
local c = React.createElement

---> public
return function(props: {
	PlayerName: string,
	UserId: number?,
	AvatarImage: string?,
	LayoutOrder: number?,
	OnClick: (() -> ())?,
})
	local isHovering, setIsHovering = React.useState(false)
	local isPressing, setIsPressing = React.useState(false)

	local avatarUrl, setAvatarUrl = React.useState(
		props.AvatarImage or "rbxasset://textures/ui/GuiImagePlaceholder.png"
	)

	React.useEffect(function()
		if not props.UserId then return end
		task.spawn(function()
			local ok, url = pcall(
				Players.GetUserThumbnailAsync,
				Players,
				props.UserId,
				Enum.ThumbnailType.HeadShot,
				Enum.ThumbnailSize.Size352x352
			)
			if ok then
				setAvatarUrl(url)
			end
		end)
	end, { props.UserId })
	local styles = ReactSpring.useSpring({
		scale = isPressing and 0.94 or (isHovering and 1.06 or 1),
		config = SPRING_CONFIG,
	})

	return c(Pane, {
		ClassName = "TextButton",
		Scale = styles.scale,
		OnClick = props.OnClick,
		OnPress = props.OnClick and function()
			setIsPressing(true)
		end or nil,
		OnRelease = props.OnClick and function()
			setIsPressing(false)
		end or nil,
		OnHover = props.OnClick and function()
			setIsHovering(true)
		end or nil,
		OnLeave = props.OnClick and function()
			setIsHovering(false)
			setIsPressing(false)
		end or nil,
		Native = {
			AutoButtonColor = false,
			BackgroundTransparency = 1,
			LayoutOrder = props.LayoutOrder,
			Selectable = false,
			Text = "",
		},
	}, {
		Background = c(Pane, {
			ClassName = "ImageLabel",
			Native = {
				BackgroundColor3 = Color3.new(1, 1, 1),
				BackgroundTransparency = 0,
				Image = CARD_IMAGE,
				ImageColor3 = CARD_TINT,
				Size = UDim2.fromScale(1, 1),
			},
		}, {
			Avatar = c(Pane, {
				ClassName = "ImageLabel",
				Native = {
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					Image = avatarUrl,
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromScale(0.9, 0.9),
				},
			}),

			NameLabel = c(Pane, {
				ClassName = "TextLabel",
				MaxTextSize = 20,
				Native = {
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					FontFace = Styles.FONT_FREDOKA,
					Position = UDim2.fromScale(0.5, 0.738),
					Size = UDim2.fromScale(0.927641, 0.456633),
					Text = props.PlayerName,
					TextColor3 = Color3.new(1, 1, 1),
					TextScaled = true,
					TextStrokeTransparency = 0,
					ZIndex = 3,
				},
			}),
		}),
	})
end
