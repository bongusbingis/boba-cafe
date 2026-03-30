--[[
	Pane
	Renders a flexible container component that wraps Roblox UI elements (Frame, ImageLabel, etc) and
	supports layout, styling, and interaction props.
	Props:
	- ClassName: The type of Roblox UI element to create (Frame, ImageLabel, TextButton, ImageButton).
	- Scale: Optional UIScale value.
	- Padding: Table specifying UIPadding values (PaddingBottom, PaddingTop, PaddingLeft, PaddingRight).
	- CornerRadius: UDim or number to define UICorner radius.
	- AspectRatio: Number for UIAspectRatioConstraint.
	- AutomaticSize: Enum.AutomaticSize value for automatic resizing.
	- ListLayout: UIListLayout properties to apply (FillDirection, SortOrder, Padding, etc).
	- GridLayout: UIGridLayout properties.
	- Gradient: UIGradient properties.
	- Stroke: UIStroke properties.
	- Native: Additional native Roblox UI properties to merge.
	- OnClick, OnPress, OnRelease, OnHover, OnLeave: Event handlers for mouse interactions.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = Shared:WaitForChild("UI")

---> dependencies
local React = require(Packages.React)

---> types
export type ListLayout = {
	FillDirection: Enum.FillDirection,
}

---> private
local joinDicts = require(UI.Utility.joinDicts)
local c = React.createElement

---> public
return React.forwardRef(function(
	props: {
		ClassName: "Frame" | "ImageLabel" | "TextButton" | "TextLabel" | "ImageButton",

		Stroke: {
			[string]: any,
		},
		Scale: number?,
		Padding: {
			PaddingBottom: UDim,
			PaddingTop: UDim,
			PaddingLeft: UDim,
			PaddingRight: UDim,
		},

		MaxTextSize: number?, ---> textlabels only
		CornerRadius: UDim | number?,
		AspectRatio: any,

		AutomaticSize: Enum.AutomaticSize?,
		OnChange: {string} & {() -> ()},

		ListLayout: {
			FillDirection: Enum.FillDirection?,
			SortOrder: Enum.SortOrder?,

			HorizontalAlignment: Enum.HorizontalAlignment?,
			VerticalAlignment: Enum.VerticalAlignment?,

			Padding: UDim,
			[string]: any,
		},

		GridLayout: {},

		Gradient: {
			Rotation: number?,
			Color: ColorSequence,
		},

		Native: { [any]: any }?,
        children: {},
	},
	ref
)
	local isButton = props["OnClick"] ~= nil or props["OnRelease"] ~= nil
	local events = {
		[React.Event.MouseEnter] = props["OnHover"],
		[React.Event.MouseLeave] = props["OnLeave"],
	}
	if isButton then
		--events[React.Event.MouseEnter] = props.OnHover
		--events[React.Event.MouseLeave] = props.OnLeave
		events[React.Event.MouseButton1Down] = props["OnPress"]
            or props["OnClick"] --- OnClick will fire on MouseButton1Down if OnPress is not provided
            or props["OnRelease"] --- OnRelease will fire on MouseButton1Down if neither OnPress nor OnClick are provided
		events[React.Event.MouseButton1Up] = props["OnRelease"]
		events[React.Event.Activated] = props["OnClick"]
	end

	if props["OnChange"] then
		events[React.Change[props["OnChange"][1]]] = props["OnChange"][2]
	end

	local aspectRatioProps
	if typeof(props["AspectRatio"]) == "number" then
		aspectRatioProps = { AspectRatio = props["AspectRatio"]}
	else
		aspectRatioProps = props["AspectRatio"]
	end

	return c(
		props.ClassName or "Frame",
		joinDicts({
			BackgroundTransparency = props.Native and props.Native.BackgroundTransparency or 1,
			AutomaticSize = props.AutomaticSize,
			BorderSizePixel = 0,
			ref = ref,
		}, props.Native, events),
		{
			UICorner = props.CornerRadius and c("UICorner", {
				CornerRadius = if typeof(props.CornerRadius) == "UDim"
					then props.CornerRadius
					else UDim.new(props.CornerRadius, 0),
			}),

			UIListLayout = props.ListLayout
				and c("UIListLayout", joinDicts(props.ListLayout, { SortOrder = Enum.SortOrder.LayoutOrder })),
			UIGridLayout = props.GridLayout
				and c("UIGridLayout", joinDicts(props.GridLayout, { SortOrder = Enum.SortOrder.LayoutOrder }), {
					UIAspectRatioConstraint = if props["GridLayoutAspectRatio"]
						then c("UIAspectRatioConstraint", {
							AspectRatio = props["GridLayoutAspectRatio"],
						})
						else nil,
				}),
			UIGradient = props.Gradient and c("UIGradient", props.Gradient),

			UIScale = props.Scale and c("UIScale", {
				Scale = props.Scale,
			}),

			UIStroke = props.Stroke and c("UIStroke", props.Stroke),

			UIAspectRatioConstraint = aspectRatioProps and c("UIAspectRatioConstraint", aspectRatioProps),

			-- UIAspectRatioConstraint = props.AspectRatio and if typeof(props.AspectRatio == "number")
			-- 	then c("UIAspectRatioConstraint", {
			-- 		AspectRatio = props.AspectRatio,
			-- 	})
			-- 	else c("UIAspectRatioConstraint", props.AspectRatio),

			UIPadding = props.Padding and c("UIPadding", {
				PaddingBottom = props.Padding.PaddingBottom,
				PaddingTop = props.Padding.PaddingTop,
				PaddingLeft = props.Padding.PaddingLeft,
				PaddingRight = props.Padding.PaddingRight,
			}),

			UITextSizeConstraint = props["MaxTextSize"]
				and props["ClassName"] == "TextLabel"
				and c("UITextSizeConstraint", {
					MaxTextSize = props["MaxTextSize"],
				}),
		},
		props.children
	)
end)
