--[[
	Hud
	Renders groups of Hud buttons used for opening/closing page components.
	Props:
	- CurrentPage: ModuleScript currently selected.
	- SetCurrentPage: Callback to update the selected page (ModuleScript or nil).
]]

--!nonstrict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = Shared:WaitForChild("UI")

---> dependencies
local React = require(Packages.React)

---> components
local Pane = require(UI.Components.Pane)
local NormalButton = require(UI.Components.Buttons.NormalButton)

---> private
local c = React.createElement

return function(props: {
	CurrentPage: ModuleScript,
	SetCurrentPage: (pageComponent: ModuleScript | nil, ...any) -> (),
})
	return c(Pane, {
		ClassName = "Frame",
		ListLayout = {
			Padding = UDim.new(0.03, 0),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Bottom,
		},
		Native = {
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.fromScale(0.981, 0.981),
			Size = UDim2.fromScale(0.175, 0.3),
			--BackgroundTransparency = 0.5
		},
	}, {
		Points = c(NormalButton, {
			Color = Color3.fromRGB(255, 107, 107),
			Text = "Collapse Buttons",
		}),
	})
end
