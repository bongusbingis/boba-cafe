local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = Shared:WaitForChild("UI")

---> dependencies
local React = require(Packages.React)
local ReactRoblox = require(Packages.ReactRoblox)

---> components
local SmallNotification = require(UI.Components.Core.Hud.SmallNotification)
local Pane = require(UI.Components.Pane)
local Styles = require(UI.Styles)

local c = React.createElement

local SAMPLE_NOTIFICATIONS = {
	{
		Title = "Badge Earned!",
		Text = "You earned your first badge.",
		--Image = "rbxassetid://2124469255",
	},
	{
		Title = "Level Up!",
		Text = "You reached a new rank.",
		--Image = "rbxassetid://2150110948",
	},
	{
		Title = "Welcome!",
		Text = "Thanks for visiting Boba Café.",
		--Image = "rbxassetid://5634393881",
	},
}

return function(target)
	local root = ReactRoblox.createRoot(target)

	-- Render the notification component anchored to the bottom-left,
	-- mimicking where it appears in the real HUD.
	root:render(c(Pane, {
		Native = {
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0.05, 0.95),
			Size = UDim2.fromOffset(150, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
		},
		ListLayout = {
			FillDirection = Enum.FillDirection.Vertical,
			VerticalAlignment = Enum.VerticalAlignment.Bottom,
			Padding = UDim.new(0, 4),
		},
	}, {
		Notification = c(SmallNotification.Component, {}),

		-- ghost placeholder so the anchoring is visible
		Placeholder = c("TextLabel", {
			BackgroundColor3 = Color3.fromRGB(50, 50, 50),
			BackgroundTransparency = 0.6,
			FontFace = Styles.FONT_FREDOKA,
			Size = UDim2.fromOffset(300, 50),
			Text = "↑ notification appears here",
			TextColor3 = Styles.OFFWHITE,
			TextScaled = true,
			LayoutOrder = 99,
		}, {
			UICorner = c("UICorner", { CornerRadius = UDim.new(0.15, 0) }),
		}),
	}))

	-- fire the three sample notifications with a short stagger
	task.spawn(function()
		for i, notif in SAMPLE_NOTIFICATIONS do
			task.wait(if i == 1 then 0.5 else 7.5) -- first fires quickly; rest queue after ~7.5s each
			SmallNotification.Push(notif)
		end
	end)

	return function()
		root:unmount()
	end
end
