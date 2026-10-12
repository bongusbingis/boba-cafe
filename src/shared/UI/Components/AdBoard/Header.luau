--[[
    Component: AdBoard/Header
    Description: The title strip above an ad board. Rendered into its own SurfaceGui
    because the header sits on a separate part from the body panel in the build.

    Layout matches the original hand-built header: two stacked labels, name over kind.
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

---> public
return function(props: {
	Title: string,
	Subtitle: string,
})
	-- React Lua has no createFragment (that is a Roact API); a Fragment element with
	-- named children is the equivalent.
	return c(React.Fragment, nil, {
		Title = c("TextLabel", {
			BackgroundTransparency = 1,
			FontFace = Styles.FONT_FREDOKA,
			Size = UDim2.fromScale(1, 0.65),
			Text = props.Title,
			TextColor3 = Color3.new(1, 1, 1),
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),

		Subtitle = c("TextLabel", {
			BackgroundTransparency = 1,
			FontFace = Styles.FONT_FREDOKA,
			Position = UDim2.fromScale(0, 0.65),
			Size = UDim2.fromScale(1, 0.35),
			Text = props.Subtitle,
			TextColor3 = Color3.new(1, 1, 1),
			TextScaled = true,
		}),
	})
end
