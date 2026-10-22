--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = Shared:WaitForChild("UI")

---> dependencies
local React = require(Packages.React)
local ReactRoblox = require(Packages.ReactRoblox)

---> components
local Recipes = require(UI.Pages.Recipes)
local Styles = require(UI.Styles)

---> private
local c = React.createElement

local SAMPLE_ITEMS = {
	"Blueberry Boba",
	"Strawberry Boba",
	"Matcha Boba",
	"Mango Boba",
	"Taro Boba",
}

local function RecipesStoryContainer()
	local selectedItem, setSelectedItem = React.useState("Blueberry Boba")

	local itemButtons = {}
	for index, itemName in ipairs(SAMPLE_ITEMS) do
		local isSelected = selectedItem == itemName
		itemButtons["Item_" .. itemName] = c("TextButton", {
			LayoutOrder = index,
			Size = UDim2.fromOffset(110, 28),
			BackgroundColor3 = if isSelected then Styles.ROSE_MID else Styles.GREEN_DIM,
			BackgroundTransparency = 0,
			FontFace = Styles.FONT_FREDOKA,
			Text = itemName:gsub(" Boba", ""),
			TextColor3 = Styles.OFFWHITE,
			TextSize = 13,
			[React.Event.Activated] = function()
				setSelectedItem(itemName)
			end,
		}, {
			Corner = c("UICorner", {
				CornerRadius = UDim.new(0, 6),
			}),
		})
	end

	return c("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
	}, {
		-- Top switch bar to quickly preview focusing different recipes
		PickerBar = c("Frame", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 8),
			Size = UDim2.new(0.85, 0, 0, 32),
			BackgroundTransparency = 1,
			ZIndex = 10,
		}, {
			Layout = c("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				Padding = UDim.new(0, 8),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			Buttons = React.createFragment(itemButtons),
		}),

		-- Centered 0.7 x 0.7 page frame as per STYLE.md §5
		PageFrame = c("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(0.7, 0.7),
			Position = UDim2.fromScale(0.5, 0.53),
			AnchorPoint = Vector2.new(0.5, 0.5),
		}, {
			RecipesPage = c(Recipes, {
				Args = { selectedItem },
			}),
		}),
	})
end

return function(target)
	local root = ReactRoblox.createRoot(target)

	root:render(c(RecipesStoryContainer))

	return function()
		root:unmount()
	end
end
