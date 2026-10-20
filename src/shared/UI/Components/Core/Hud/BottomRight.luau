--[[
	Hud
	Renders groups of Hud buttons used for opening/closing page components.
	Props:
	- CurrentPage: ModuleScript currently selected.
	- SetCurrentPage: Callback to update the selected page (ModuleScript or nil).
	- QuestsOpen: Whether the Quests pop-up card is open.
	- OnToggleQuests: Opens the Quests card when closed, closes it when open.
]]

--!nonstrict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = Shared:WaitForChild("UI")

---> dependencies
local React = require(Packages.React)

---> styles
local Styles = require(UI.Styles)

---> components
local Pane = require(UI.Components.Pane)
local NormalButton = require(UI.Components.Buttons.NormalButton)

---> constants
local BUTTON_SIZE = UDim2.fromScale(1, 1)
-- Shifts the mount left of Roblox's mobile jump button (DEC-048, Q24 = A).
local JUMP_BUTTON_CLEARANCE = 130

---> private
local c = React.createElement

return function(props: {
	CurrentPage: ModuleScript,
	SetCurrentPage: (pageComponent: ModuleScript | nil, ...any) -> (),
	QuestsOpen: boolean?,
	OnToggleQuests: (() -> ())?,
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
			Position = UDim2.new(0.981, -JUMP_BUTTON_CLEARANCE, 0.981, 0),
			Size = UDim2.fromScale(0.175, 0.065),
			--BackgroundTransparency = 0.5
		},
	}, {
		Quests = c(NormalButton, {
			Icon = "",
			Size = BUTTON_SIZE,
			Color = Styles.GREEN_MID,
			Text = "Quests",
			OnClick = function()
				if props.OnToggleQuests then
					props.OnToggleQuests()
				end
			end,
			LayoutOrder = 1,
		}),
	})
end
