local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")

---> dependencies
local React = require(Packages.React)
local ReactRoblox = require(Packages.ReactRoblox)

---> components
local PaycheckCard = require(Shared.UI.Components.Core.Hud.PaycheckCard)

---> private
local c = React.createElement

return function(target)
	local root = ReactRoblox.createRoot(target)

	root:render(c("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
	}, {
		Celebration = c(PaycheckCard, {
			Preview = {
				Pay = 42,
				Tips = 8,
				Bonus = 10,
				Total = 60,
				StreakBonus = 0,
				Stars = 3,
				Served = 10,
				Walkouts = 0,
				Shift = 4,
				First = false,
			},
		}),
	}))

	return function()
		root:unmount()
	end
end
