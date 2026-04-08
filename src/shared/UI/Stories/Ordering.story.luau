--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")

---> dependencies
local React = require(Packages.React)
local ReactRoblox = require(Packages.ReactRoblox)

---> components
local Ordering = require(Shared.UI.Pages.Ordering.RightPanel)

---> private
local c = React.createElement

local function resolveItemName(orderItem)
	local name = orderItem.DefaultInfo.ItemName
	if orderItem.DefaultInfo.Select then
		for variantType in orderItem.DefaultInfo.Select do
			local chosen = orderItem.CustomInfo[variantType]
			if chosen then
				name = tostring(chosen) .. " " .. name
			end
		end
	end
	return name
end

local function resolveItemDescription(orderItem)
	local lines = {}
	if orderItem.DefaultInfo.RequiredSelection then
		for selType in orderItem.DefaultInfo.RequiredSelection do
			table.insert(lines, selType .. ":\n	- " .. (orderItem.CustomInfo[selType] or "?"))
		end
	end
	if orderItem.DefaultInfo.Options then
		for optType, defaultValue in orderItem.DefaultInfo.Options do
			local chosen = orderItem.CustomInfo[optType]
			if chosen ~= defaultValue then
				table.insert(lines, if chosen then ("+ " .. optType) else ("- NO " .. optType))
			end
		end
	end
	return table.concat(lines, "\n")
end

local mockOrderItems: { any } = {
	{
		DefaultInfo = {
			ItemName = "Boba",
			Select = {
				Size = { "Small", "Medium", "Large" },
				Temperature = { "Hot", "Cold" },
			},
			RequiredSelection = {
				["Syrup Flavor"] = {},
				["Tapioca Flavor"] = {},
			},
			Options = {
				Iced = false,
				Sugar = false,
			},
		},
		CustomInfo = {
			Size = "Large",
			Temperature = "Cold",
			["Syrup Flavor"] = "Blueberry",
			["Tapioca Flavor"] = "Mango",
			Iced = true,
			Sugar = false,
		},
	},
	{
		DefaultInfo = {
			ItemName = "Vanilla Macaron",
			Options = {
				GiftWrap = false,
			},
		},
		CustomInfo = {
			GiftWrap = true,
		},
	},
	-- {
	-- 	DefaultInfo = {
	-- 		ItemName = "Water",
	-- 		Select = {
	-- 			Temperature = { "Cold", "Hot" },
	-- 			Size = { "Small", "Medium", "Large" },
	-- 		},
	-- 		Options = {
	-- 			Ice = true,
	-- 		},
	-- 	},
	-- 	CustomInfo = {
	-- 		Temperature = "Hot",
	-- 		Size = "Small",
	-- 		Ice = false,
	-- 	},
	-- },
}

return function(target)
	local root = ReactRoblox.createRoot(target)
    
	root:render(c("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(0.9, 0.9),
		Position = UDim2.fromScale(0.5, 0.9),
		AnchorPoint = Vector2.new(0.5, 0.5),
	}, {
		UIScale = c("UIScale", {
			Scale = 1.8,
		}),
		Ordering = c(Ordering, {
			OrderItems = mockOrderItems,
			MaxOrderItems = 3,
			StaffRole = "Customer",
			StaffAvatarUrl = "rbxasset://textures/ui/GuiImagePlaceholder.png",
			ResolveItemName = resolveItemName,
			ResolveItemDescription = resolveItemDescription,
			OnOrderItemRemoved = function() end,
			OnSubmit = function() end,
		}),
	}))

	return function()
		root:unmount()
	end
end
