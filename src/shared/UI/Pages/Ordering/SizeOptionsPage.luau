local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = Shared:WaitForChild("UI")

local React = require(Packages.React)
local Pane = require(UI.Components.Pane)
local ActionButton = require(UI.Components.Buttons.ActionButton)
local Styles = require(UI.Styles)
local AddonCheckbox = require(script.Parent.AddonCheckbox)

local ORANGE = Color3.fromRGB(237, 114, 47)
local c = React.createElement

local function count(t: {[any]: any})
    if not t then
        return 0
    end

    local n = 0
    for _ in t do
        n += 1
    end
    return n
end

local function hasSelectableChoices(selectTable: {[any]: { any }}?): boolean
	if not selectTable then
		return false
	end

	for _, options in selectTable do
		if typeof(options) == "table" and #options > 1 then
			return true
		end
	end

	return false
end

return function(props)
	local item = props.Item
	if not item then
		return nil
	end

	local canAdd = props.OrderItemsCount < props.MaxOrderItems
	local scrollChildren = {
		UIListLayout = c("UIListLayout", {
			Padding = UDim.new(0.05, 0),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
        UIPadding = c("UIPadding", {
            PaddingTop = UDim.new(0.015, 0),
            PaddingLeft = UDim.new(0.015, 0),
        }),
	}

    scrollChildren["ItemName"] = c(Pane, {
        ClassName = "TextLabel",
        Native = {
            BackgroundTransparency = 1,
            FontFace = Styles.FONT_FREDOKA,
            Size = UDim2.fromScale(1, 0.115),
            Text = item.ItemName,
            TextColor3 = ORANGE,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextScaled = true,
            LayoutOrder = -1,
        },
    })

	local sectionOrder = 0

	if item.Select then
		for selType, options in item.Select do
			if typeof(options) ~= "table" or #options <= 1 then
				continue
			end

			sectionOrder += 1

			local btnChildren = {
				UIListLayout = c("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					Padding = UDim.new(0.01, 0),
					SortOrder = Enum.SortOrder.LayoutOrder,
					VerticalAlignment = Enum.VerticalAlignment.Center,
				}),
			}

			for i, optVal in ipairs(options) do
				local isSelected = props.CustomInfo[selType] == optVal
				btnChildren[optVal] = c(Pane, {
					ClassName = "TextButton",
					OnClick = function()
						local newInfo = table.clone(props.CustomInfo)
						newInfo[selType] = optVal
						props.OnCustomInfoChanged(newInfo)
					end,
					Native = {
						AutoButtonColor = false,
						BackgroundColor3 = if isSelected then ORANGE else Color3.new(1, 1, 1),
						BackgroundTransparency = 0,
						LayoutOrder = i,
						Size = UDim2.fromScale(0.965 / #options, 0.873),
						Text = "",
					},
				}, {
					Label = c(Pane, {
						ClassName = "TextLabel",
						Native = {
							AnchorPoint = Vector2.new(0.5, 0.5),
							BackgroundTransparency = 1,
							FontFace = Styles.FONT_FREDOKA,
							Position = UDim2.fromScale(0.5, 0.5),
							Size = UDim2.fromScale(0.85, 0.6),
							Text = optVal,
							TextColor3 = if isSelected then Color3.new(1, 1, 1) else ORANGE,
							TextScaled = true,
						},
					}),
				})
			end

			scrollChildren["Sel_" .. selType] = c(Pane, {
				ClassName = "Frame",
				ListLayout = {
					FillDirection = Enum.FillDirection.Vertical,
					Padding = UDim.new(0.08, 0),
				},
				Native = {
					BackgroundTransparency = 1,
					LayoutOrder = sectionOrder,
					Size = UDim2.fromScale(0.955, 0.26),
				},
			}, {
				Title = c(Pane, {
					ClassName = "TextLabel",
					Native = {
						BackgroundTransparency = 1,
						FontFace = Styles.FONT_FREDOKA,
						LayoutOrder = 1,
						Size = UDim2.fromScale(1, 0.35),
						Text = selType,
						TextColor3 = ORANGE,
						TextScaled = true,
						TextXAlignment = Enum.TextXAlignment.Left,
					},
				}),

				Buttons = c(Pane, {
					ClassName = "Frame",
					Native = {
						BackgroundColor3 = Styles.GRAY,
						BackgroundTransparency = 0,
						LayoutOrder = 2,
						Size = UDim2.fromScale(0.9, 0.5),
					},
				}, btnChildren),
			})
		end
	end

	if item.Options and count(item.Options) > 0 then
		sectionOrder += 1
		local addonChildren = {
			UIListLayout = c("UIListLayout", {
				FillDirection = Enum.FillDirection.Vertical,
				Padding = UDim.new(0.1, 0),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			Title = c(Pane, {
				ClassName = "TextLabel",
				Native = {
					BackgroundTransparency = 1,
					FontFace = Styles.FONT_FREDOKA,
					LayoutOrder = 1,
					Size = UDim2.fromScale(1, 0.275),
					Text = "Add-ons",
					TextColor3 = ORANGE,
					TextScaled = true,
					TextXAlignment = Enum.TextXAlignment.Left,
				},
			}),
		}

		local addonOrder = 2
		for optType in item.Options do
			addonChildren[optType] = c(AddonCheckbox, {
				Label = optType,
				Checked = props.CustomInfo[optType] == true,
				LayoutOrder = addonOrder,
				OnToggle = function()
					local newInfo = table.clone(props.CustomInfo)
					newInfo[optType] = not newInfo[optType]
					props.OnCustomInfoChanged(newInfo)
				end,
			})
			addonOrder += 1
		end

		scrollChildren["Addons"] = c(Pane, {
			ClassName = "Frame",
			Native = {
				BackgroundTransparency = 1,
				LayoutOrder = sectionOrder,
				Size = UDim2.fromScale(0.955, 0.345),
			},
		}, addonChildren)
	end

	if not hasSelectableChoices(item.Select) and count(item.Options) == 0 then
        scrollChildren["NoOptions"] = c(Pane, {
            ClassName = "TextLabel",
            Native = {
                BackgroundTransparency = 1,
                FontFace = Styles.FONT_FREDOKA,
                LayoutOrder = 1,
                Size = UDim2.fromScale(1, 0.075),
                Text = "No options for this item",
                TextColor3 = Styles.GRAY,
                TextScaled = true,
                TextXAlignment = Enum.TextXAlignment.Left,
            },
        })
    end

	return c(Pane, {
		ClassName = "Frame",
		Native = {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
		},
	}, {
		Content = c("ScrollingFrame", {
			Active = true,
			AnchorPoint = Vector2.new(0.5, 0),
			BorderSizePixel = 0,
			BackgroundTransparency = 1,
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			Position = UDim2.fromScale(0.518628, 0),
			ScrollBarImageColor3 = Color3.new(),
			ScrollBarThickness = 5,
			Size = UDim2.fromScale(0.964196, 0.85),
		}, scrollChildren),

		Buttons = c(Pane, {
			ClassName = "Frame",
			Native = {
				AnchorPoint = Vector2.new(0, 1),
				BackgroundTransparency = 1,
				Position = UDim2.fromScale(0, 0.95),
				Size = UDim2.fromScale(1, 0.13),
			},
		}, {
			AddToOrder = canAdd and c(ActionButton, {
				Text = "Add to Order",
				Color = ORANGE,
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.fromScale(0.05, 0.5),
				Size = UDim2.fromScale(0.4, 1),
				OnClick = props.OnAddToOrder,
			}) or c(Pane, {
				ClassName = "TextLabel",
				Native = {
					AnchorPoint = Vector2.new(0, 0.5),
					BackgroundTransparency = 1,
					FontFace = Styles.FONT_FREDOKA,
					Position = UDim2.fromScale(0.05, 0.5),
					Size = UDim2.fromScale(0.4, 0.6),
					Text = "Order full (3/3)",
					TextColor3 = Styles.GRAY,
					TextScaled = true,
				},
			}),

			Cancel = c(ActionButton, {
				Text = "Cancel",
				Color = Styles.RED,
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.fromScale(0.55, 0.5),
				Size = UDim2.fromScale(0.4, 1),
				OnClick = props.OnCancel,
			}),
		}),
	})
end
