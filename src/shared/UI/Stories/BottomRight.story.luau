--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = Shared:WaitForChild("UI")

---> dependencies
local React = require(Packages.React)
local ReactRoblox = require(Packages.ReactRoblox)

---> components
local BottomRight = require(UI.Components.Core.Hud.BottomRight)
local Styles = require(UI.Styles)

---> private
local c = React.createElement

local function BottomRightStoryContainer()
	local questsOpen, setQuestsOpen = React.useState(false)

	return c("Frame", {
		BackgroundTransparency = 0,
		BackgroundColor3 = Color3.fromRGB(38, 42, 48),
		Size = UDim2.fromScale(1, 1),
	}, {
		-- Ambient instructions
		Info = c("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.4),
			Size = UDim2.fromScale(0.7, 0.2),
			BackgroundTransparency = 1,
			FontFace = Styles.FONT_FREDOKA,
			Text = "BottomRight HUD\nIncludes jump button clearance and Quest popup toggle",
			TextColor3 = Styles.OFFWHITE,
			TextSize = 18,
		}),

		-- Status readout
		Status = c("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.7, 0.08),
			BackgroundTransparency = 1,
			FontFace = Styles.FONT_FREDOKA,
			Text = "Quests Open State: " .. tostring(questsOpen),
			TextColor3 = if questsOpen then Styles.GREEN else Styles.GRAY,
			TextSize = 16,
		}),

		-- Component
		BottomRight = c(BottomRight, {
			QuestsOpen = questsOpen,
			OnToggleQuests = function()
				setQuestsOpen(not questsOpen)
			end,
		}),
	})
end

return function(target)
	local root = ReactRoblox.createRoot(target)

	root:render(c(BottomRightStoryContainer))

	return function()
		root:unmount()
	end
end
