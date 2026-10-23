local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")

---> dependencies
local React = require(Packages.React)
local ReactRoblox = require(Packages.ReactRoblox)

---> components
local LevelUpCelebration = require(Shared.UI.Components.Core.Hud.LevelUpCelebration)

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
		Celebration = c(LevelUpCelebration, {
			Preview = {
				Level = 5,
				Title = "Barista",
				Unlocks = {
					"New drinks: Taro Milk Tea, Brown Sugar Boba, Matcha Latte, Mango Slush",
					"New title: Barista",
					"2 order tickets",
					"Orders with 2 items",
					"New nametag: Crimson",
				},
			},
		}),
	}))

	return function()
		root:unmount()
	end
end
