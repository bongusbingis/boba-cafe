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
	SetCurrentPage: (pageComponent: ModuleScript | nil) -> (),
})
	return c(Pane, {
		ClassName = "Frame",
		ListLayout = {
			Padding = UDim.new(0.03, 0),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Bottom,
		},
		Native = {
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0.025, 0.981),
			Size = UDim2.fromScale(0.175, 0.3),
			--BackgroundTransparency = 0.5
		},
	}, {
		Bucks = c(NormalButton, {
			PlusButton = true,
			Icon = "rbxassetid://13382286492",
			Color = Color3.fromRGB(150, 189, 136),
			Text = "1,000",
		}),

		Points = c(NormalButton, {
			PlusButton = true,
			Icon = "rbxassetid://13391365805",
			Color = Color3.fromRGB(255, 107, 107),
			Text = "1,000",
		}),
	})
end
