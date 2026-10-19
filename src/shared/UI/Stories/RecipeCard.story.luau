-- RecipeCard story: the five fixed M1.5b states for one Blueberry Boba spec.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = Shared:WaitForChild("UI")

---> dependencies
local React = require(Packages.React)
local ReactRoblox = require(Packages.ReactRoblox)

---> components
local RecipeCard = require(UI.Components.Core.Hud.RecipeCard)
local Styles = require(UI.Styles)

local c = React.createElement

local BOBA_SPEC = {
	Kind = "Drink",
	Item = "Boba",
	Size = "Medium",
	Syrup = "Blueberry",
	Tapioca = "Boba",
	Label = "Medium Blueberry Boba",
}

local STATES = {
	{
		Title = "1. Pending - nothing held",
		attrs = nil,
		patience = 0.9,
	},
	{
		Title = "2. Current - step 2, cup done",
		attrs = { Item = "Clear Cup", Size = "Medium" },
		patience = 0.7,
	},
	{
		Title = "3. All done - ready to serve",
		attrs = { Item = "Boba", Size = "Medium", Syrup = "Blueberry", Tapioca = "Boba" },
		patience = 1,
	},
	{
		Title = "4. Wrong - vanilla syrup",
		attrs = { Item = "Flavored Milk", Size = "Medium", Syrup = "Vanilla" },
		patience = 0.35,
	},
	{
		Title = "5. Close - large cup",
		attrs = { Item = "Boba", Size = "Large", Syrup = "Blueberry", Tapioca = "Boba" },
		patience = 0.15,
	},
}

return function(target)
	-- A demo cup so the header viewport renders in every state.
	local demoCup = Instance.new("Part")
	demoCup.Name = "DemoCup"
	demoCup.Shape = Enum.PartType.Cylinder
	demoCup.Size = Vector3.new(2, 2, 2)
	demoCup.Color = Color3.fromRGB(255, 255, 255)

	local sections = {}
	for index, state in STATES do
		sections["Section_" .. index] = c("Frame", {
			LayoutOrder = index,
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 0),
		}, {
			Layout = c("UIListLayout", {
				FillDirection = Enum.FillDirection.Vertical,
				Padding = UDim.new(0, 4),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			Title = c("TextLabel", {
				LayoutOrder = 0,
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				FontFace = Styles.FONT_FREDOKA,
				Size = UDim2.new(1, 0, 0, 18),
				Text = state.Title,
				TextColor3 = Styles.GREEN_DEEP,
				TextSize = 15,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			CardWrap = c("Frame", {
				LayoutOrder = 1,
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				Size = UDim2.new(0, 190, 0, 0),
			}, {
				Card = c(RecipeCard, {
					spec = BOBA_SPEC,
					attrs = state.attrs,
					tool = demoCup,
					patience = state.patience,
					shiftText = "Shift 1",
				}),
			}),
		})
	end

	local root = ReactRoblox.createRoot(target)
	root:render(c(
		"Frame",
		{
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 0),
		},
		(function()
			local children = table.clone(sections)
			children.Layout = c("UIListLayout", {
				FillDirection = Enum.FillDirection.Vertical,
				Padding = UDim.new(0, 12),
				SortOrder = Enum.SortOrder.LayoutOrder,
			})
			children.Padding = c("UIPadding", {
				PaddingTop = UDim.new(0, 12),
				PaddingBottom = UDim.new(0, 12),
				PaddingLeft = UDim.new(0, 12),
				PaddingRight = UDim.new(0, 12),
			})
			return children
		end)()
	))

	return function()
		root:unmount()
		demoCup:Destroy()
	end
end
