--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = Shared:WaitForChild("UI")

---> dependencies
local React = require(Packages.React)
local ReactRoblox = require(Packages.ReactRoblox)

---> components
local BottomLeft = require(UI.Components.Core.Hud.BottomLeft)
local Styles = require(UI.Styles)

---> private
local c = React.createElement

local function BottomLeftStoryContainer()
	local currentPage, setCurrentPage = React.useState(nil :: ModuleScript?)

	return c("Frame", {
		BackgroundTransparency = 0,
		BackgroundColor3 = Color3.fromRGB(38, 42, 48),
		Size = UDim2.fromScale(1, 1),
	}, {
		-- Ambient guidance notes
		InfoLabel = c("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.4),
			Size = UDim2.fromScale(0.7, 0.2),
			BackgroundTransparency = 1,
			FontFace = Styles.FONT_FREDOKA,
			Text = "BottomLeft HUD Controls\nIncludes Shift Clock In/Out, Boba Bucks, Points, and Staff Guide",
			TextColor3 = Styles.OFFWHITE,
			TextSize = 18,
		}),

		-- BottomLeft Component
		BottomLeft = c(BottomLeft, {
			CurrentPage = currentPage,
			SetCurrentPage = function(page: ModuleScript?)
				setCurrentPage(page)
			end,
		}),
	})
end

return function(target)
	local root = ReactRoblox.createRoot(target)

	root:render(c(BottomLeftStoryContainer))

	return function()
		root:unmount()
	end
end
