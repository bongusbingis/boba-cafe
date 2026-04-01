--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")

---> dependencies
local React = require(Packages.React)
local ReactRoblox = require(Packages.ReactRoblox)

---> components
local Shop = require(Shared.UI.Pages.Shop)

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
		Shop = c(Shop, {
			Args = { "Pets" },
		}),
	}))

	return function()
		root:unmount()
	end
end
