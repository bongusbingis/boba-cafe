--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = Shared:WaitForChild("UI")

---> dependencies
local React = require(Packages.React)
local ReactRoblox = require(Packages.ReactRoblox)

---> components
local Hud = require(UI.Components.Core.Hud)
local Styles = require(UI.Styles)

---> private
local c = React.createElement

local function HudStoryContainer()
	local currentPage, setCurrentPage = React.useState(nil :: ModuleScript?)

	return c("Frame", {
		BackgroundTransparency = 0,
		BackgroundColor3 = Color3.fromRGB(35, 38, 42),
		Size = UDim2.fromScale(1, 1),
	}, {
		-- Mock game background indicator
		BackgroundLabel = c("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			BackgroundTransparency = 1,
			FontFace = Styles.FONT_FREDOKA,
			Text = "BOBA CAFE - IN-GAME VIEWPORT\n(HUD Mounted)",
			TextColor3 = Color3.fromRGB(80, 85, 92),
			TextSize = 24,
			Size = UDim2.fromScale(0.6, 0.2),
		}),

		-- HUD
		Hud = c(Hud, {
			CurrentPage = currentPage,
			SetCurrentPage = function(page: ModuleScript?)
				setCurrentPage(page)
			end,
		}),

		-- Page Preview (when clicked in HUD)
		PageContainer = if currentPage ~= nil
			then c("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(0.7, 0.7),
				BackgroundTransparency = 1,
				ZIndex = 5,
			}, {
				Page = c(require(currentPage), {
					Args = {},
				}),
			})
			else nil,

		-- Debug reset button
		ResetOverlay = if currentPage ~= nil
			then c("TextButton", {
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new(0.5, 0, 1, -12),
				Size = UDim2.fromOffset(160, 32),
				BackgroundColor3 = Styles.RED,
				FontFace = Styles.FONT_FREDOKA,
				Text = "Close Open Page",
				TextColor3 = Styles.OFFWHITE,
				TextSize = 14,
				ZIndex = 20,
				[React.Event.Activated] = function()
					setCurrentPage(nil)
				end,
			}, {
				Corner = c("UICorner", {
					CornerRadius = UDim.new(0, 8),
				}),
			})
			else nil,
	})
end

return function(target)
	local root = ReactRoblox.createRoot(target)

	root:render(c(HudStoryContainer))

	return function()
		root:unmount()
	end
end
