--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")

---> dependencies
local React = require(Packages.React)
local ReactRoblox = require(Packages.ReactRoblox)

---> components
local Inventory = require(Shared.UI.Pages.Inventory)

---> private
local c = React.createElement

return function(target)
	local root = ReactRoblox.createRoot(target)
    
	root:render(c("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(0.7, 0.7),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
	}, {
		Inventory = c(Inventory, {
			Args = { "Nametags" },
		}),
	}))

	return function()
		root:unmount()
	end
end
