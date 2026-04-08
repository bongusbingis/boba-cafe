local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = Shared:WaitForChild("UI")

---> dependencies
local React = require(Packages.React)
local ReactSpring = require(Packages.ReactSpring)

---> styles
local Styles = require(UI.Styles)

---> components
local Pane = require(UI.Components.Pane)
local ShopItem = require(UI.Components.Buttons.ShopItem)

---> hooks
local usePx = require(UI.Hooks.usePx)

---> private
local c = React.createElement

local SPRING_CONFIG = { mass = 1, tension = 400, friction = 36 }
local ROW_HEIGHT_PX = 40

---> Sub-item expandable container with open/close height animation
local function SubItemContainer(props: {
	SubItems: { any },
	IsClosing: boolean,
	OnClosed: () -> (),
	ItemColor: Color3,
	HeaderColor: Color3,
	LayoutOrder: number,
})
	local px = usePx()
	local rowHeight = px(ROW_HEIGHT_PX)
	local totalHeight = #props.SubItems * rowHeight

	local styles, api = ReactSpring.useSpring(function()
		return {
			clipHeight = 0,
			config = SPRING_CONFIG,
		}
	end)

	React.useEffect(function()
		api.start({ clipHeight = totalHeight })
	end, {})

	React.useEffect(function()
		if props.IsClosing then
			api.start({ clipHeight = 0 }):andThen(props.OnClosed)
		end
	end, { props.IsClosing })

	local rows = {
		Layout = c("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }),
	}

	for j, subItem in ipairs(props.SubItems) do
		local isHeader = subItem.IsHeader == true
		local paddingLeft = if isHeader then px(10) else px(26)
		rows[tostring(j)] = c("TextLabel", {
			BackgroundColor3 = if isHeader then props.HeaderColor else props.ItemColor,
			BackgroundTransparency = 0,
			BorderSizePixel = 0,
			FontFace = Styles.FONT_FREDOKA,
			LayoutOrder = j,
			Size = UDim2.new(1, 0, 0, rowHeight),
			Text = subItem.Label,
			TextColor3 = Color3.new(1, 1, 1),
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,
		}, {
			Constraint = c("UITextSizeConstraint", {
				MaxTextSize = px(18),
			}),
			Padding = c("UIPadding", {
				PaddingLeft = UDim.new(0, paddingLeft),
			}),
		})
	end

	return c("Frame", {
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		LayoutOrder = props.LayoutOrder,
		Size = styles.clipHeight:map(function(h)
			return UDim2.new(1, 0, 0, h)
		end),
	}, rows)
end

---> public
export type SubItem = {
	Label: string,
	IsHeader: boolean?,
}

export type Item = {
	Label: string,
	Price: string?,
	SubItems: { SubItem }?,
}

export type Props = {
	Title: string,
	Items: { Item },
	LayoutOrder: number?,
	Color: Color3?,
	OnPurchase: ((item: Item) -> ())?,
}

return function(props: Props)
	local expandedItem, setExpandedItem = React.useState(nil)
	local closingItem, setClosingItem = React.useState(nil)

	local itemColor = props.Color and props.Color:Lerp(Color3.new(0, 0, 0), 0.175) or Styles.GREEN
	local subHeaderColor = itemColor:Lerp(Color3.new(0, 0, 0), 0.08)
	local subOptionColor = itemColor:Lerp(Color3.new(1, 1, 1), 0.04)

	local children = {
		UIListLayout = c("UIListLayout", {
			Padding = UDim.new(0, 3),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),

		Header = c(Pane, {
			ClassName = "ImageLabel",
			Native = {
				BackgroundTransparency = 1,
				Image = "http://www.roblox.com/asset/?id=13465572823",
				ImageColor3 = props.Color or Styles.GREEN_LIGHT,
				Size = UDim2.fromScale(0.981, 0.065),
				SizeConstraint = Enum.SizeConstraint.RelativeXX,
				SliceCenter = Rect.new(0, 0, 1019, 40),
			},
		}, {
			Title = c(Pane, {
				ClassName = "TextLabel",
				Native = {
					AnchorPoint = Vector2.new(0.5, 0),
					BackgroundTransparency = 1,
					FontFace = Styles.FONT_FREDOKA,
					Position = UDim2.fromScale(0.5, 0.132084),
					Size = UDim2.fromScale(0.94, 0.7),
					Text = props.Title,
					TextColor3 = Color3.new(1, 1, 1),
					TextScaled = true,
					TextXAlignment = Enum.TextXAlignment.Left,
				},
			}),
		}),

		Footer = c(Pane, {
			ClassName = "ImageLabel",
			Native = {
				BackgroundTransparency = 1,
				Image = "http://www.roblox.com/asset/?id=13465749908",
				ImageColor3 = props.Color or Styles.GREEN_LIGHT,
				LayoutOrder = 999999999,
				Size = UDim2.fromScale(0.981, 0.02),
				SizeConstraint = Enum.SizeConstraint.RelativeXX,
			},
		}),
	}

	for i, item in ipairs(props.Items) do
		local baseOrder = i * 10000
		local isExpanded = expandedItem == item.Label
		local isThisClosing = closingItem == item.Label

		children[item.Label] = c(ShopItem, {
			Label = item.Label,
			Price = item.Price,
			Color = itemColor,
			LayoutOrder = baseOrder,
			OnClick = if item.SubItems then function()
				if isExpanded then
					setClosingItem(item.Label)
					setExpandedItem(nil)
				else
					setClosingItem(expandedItem)
					setExpandedItem(item.Label)
				end
			end else (if props.OnPurchase then function()
				props.OnPurchase(item)
			end else nil),
		})

		if item.SubItems and (isExpanded or isThisClosing) then
			children[item.Label .. "_sub"] = c(SubItemContainer, {
				SubItems = item.SubItems,
				IsClosing = isThisClosing,
				OnClosed = function()
					setClosingItem(nil)
				end,
				ItemColor = subOptionColor,
				HeaderColor = subHeaderColor,
				LayoutOrder = baseOrder + 1,
			})
		end
	end

	return c("Frame", {
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = props.LayoutOrder,
		Size = UDim2.fromScale(1, 0),
	}, children)
end
