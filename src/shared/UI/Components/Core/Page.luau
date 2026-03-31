--[[
	Page
	Animates the visibility and positioning of a page container with spring physics.
	Props:
	- IsVisible: Boolean controlling the page visibility (animation triggered on content change).
	- OnClosing: Function that receives a callback to trigger the closing animation.
	- PageContent: React node(s) to render inside the page.
]]


local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = Shared:WaitForChild("UI")

---> dependencies
local React = require(Packages.React)
local ReactSpring = require(ReplicatedStorage.Packages.ReactSpring)

---> components
local Pane = require(UI.Components.Pane)

---> constants

local ORIGIN_POSITION = UDim2.fromScale(0.5, 0.65)
local GOAL_POSITION = UDim2.fromScale(0.5, 0.5)

local ORIGIN_SCALE = 0.6
local GOAL_SCALE = 0.8

--local ANIM_FROM_OUT = UDim2.fromScale(0.5, 0.1)
local SPRING_CONFIG = {
	mass = 1,
	tension = 2500,
	friction = 100,
}

---> private
local c = React.createElement

---> public
return function(props: {
	IsVisible: boolean,
	OnClosing: (() -> ()) -> (),
	PageContent: nil,
})
	local styles, api = ReactSpring.useSpring(function()
		return {
			Position = ORIGIN_POSITION,
			Scale = ORIGIN_SCALE,
			config = SPRING_CONFIG,
		}
	end)

	React.useEffect(function()
		--UISounds.PlayWoosh()
		api.start({
			from = { Position = ORIGIN_POSITION, Scale = ORIGIN_SCALE },
			to = { Position = GOAL_POSITION, Scale = GOAL_SCALE },
		})
		props.OnClosing(function()
			return api.start({
				from = { Position = GOAL_POSITION, Scale = GOAL_SCALE },
				to = { Position = ORIGIN_POSITION, Scale = ORIGIN_SCALE },
			})
		end)
	end, { props.PageContent })

	return c(Pane, {
		Scale = styles.Scale,
		Native = {
			Size = UDim2.fromScale(0.8, 0.8),
			Position = styles.Position,
			AnchorPoint = Vector2.new(0.5, 0.5),
		},
	}, props.PageContent)
end
