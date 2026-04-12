--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")

---> dependencies
local React = require(Packages.React)
local ReactRoblox = require(Packages.ReactRoblox)

---> components
local MobileOrder = require(Shared.UI.Pages.MobileOrder)

---> private
local c = React.createElement

return function(target)
	local root = ReactRoblox.createRoot(target)
    
	root:render(c("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
	}, {
		MobileOrder = c(MobileOrder, {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.fromScale(0.5, 0.95),
			Size = UDim2.fromOffset(300, 640),
			MaxSize = Vector2.new(300, 640),
		}),
	}))

	return function()
		root:unmount()
	end
end
