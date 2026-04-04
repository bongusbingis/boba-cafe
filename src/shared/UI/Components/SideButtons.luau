local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = Shared:WaitForChild("UI")

---> dependencies
local React = require(Packages.React)

---> components
local Pane = require(UI.Components.Pane)

---> styles
local Styles = require(UI.Styles)

---> private
local c = React.createElement

---> public
return function(props)
	return c(Pane, {
		ClassName = "ImageLabel",
		Native = {
			AnchorPoint = Vector2.new(0, 0.5),
			BackgroundTransparency = 1,
			Image = props.Image or "http://www.roblox.com/asset/?id=13438617189",
			ImageColor3 = props.ImageColor3 or Styles.GREEN_LIGHT,
			Position = props.Position or UDim2.fromScale(0.0193662, 0.5),
			Size = props.Size or UDim2.fromScale(0.230634, 0.939058),
		},
		ListLayout = props.ListLayout or {
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
            VerticalAlignment = Enum.VerticalAlignment.Top,
			Padding = UDim.new(0.05, 0),
			SortOrder = Enum.SortOrder.LayoutOrder,
		},
		Padding = {
			PaddingTop = UDim.new(0.035, 0),
		}
	}, props.children)
end