--!strict
--[[
	BackgroundSpotlight
	Displays a rotating background shine/spotlight effect.
	Props:
	- Native: Optional dictionary of native ImageLabel props to merge with defaults.
]]


local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = Shared:WaitForChild("UI")

---> dependencies
local React = require(ReplicatedStorage.Packages.React)

---> components
local Pane = require(UI.Components.Pane)

---> constants
local ANIMATE_TIME = 10

---> private
local c = React.createElement
local useClock = require(UI.Hooks.useClock)
local joinDicts = require(UI.Utility.joinDicts)

return function(props: {
    Native: {[string]: any}?
})
	local clockBinding = useClock()
	return c(Pane, {
		ClassName = "ImageLabel",
		AspectRatio = 1,
		Native = joinDicts({
			Image = "rbxassetid://127221443901777",
			ZIndex = 0,
			Size = UDim2.fromScale(1.75, 1.75),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Rotation = clockBinding:map(function(clock: number)
				local dps = 360 / ANIMATE_TIME
				local rotation = (clock * dps) % 360
				return rotation
			end),
		}, props.Native),
	})
end
