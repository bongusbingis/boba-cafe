--[[
	SmallNotification
	Queued toast-style notification card that springs in above the bottom-left HUD buttons.
	Each notification slides in, fades its content in, holds for 5 seconds, then slides back out.
	Queue is processed one at a time; new notifications append to the end.

	External API (call from any client script):
		SmallNotification.Push({
			Title       = "Badge Earned!",
			Description = "You earned your first badge.",
			Image       = "rbxassetid://XXXX",
			SoundEnabled = true,   -- optional
		})
]]

--!nonstrict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = Shared:WaitForChild("UI")

---> dependencies
local React = require(Packages.React)
local ReactSpring = require(Packages.ReactSpring)

---> components / styles
local Pane = require(UI.Components.Pane)
local Styles = require(UI.Styles)

---> private
local c = React.createElement

---> module-level push queue backed by a BindableEvent so any script can call Push
local pushEvent = Instance.new("BindableEvent")

---> constants
local PANEL_IMAGE = "rbxassetid://2018256936"
local CARD_HEIGHT = 135 -- pixels; height the card springs to when visible
local ICON_SIZE = UDim2.fromScale(0.55, 0.55)
local HINTS = {
	"Join our group for a FREE pet!",
	"Having fun? Be sure to leave a like and favorite on our game!",
	"Join our group for 20 Boba Bucks!",
	"Want exclusive perks and items? Check out our Shop located above! ",
	"Interested in being a Celebrity? Check out the Celebrity tab in our Shop!",
	"Can't find the pet or trail purchases you made? Check the inventory tab above! ",
	"Can't wait any longer? Purchase Boba Bucks or Staff points in our Shop! ",
	"Boba Cafe is owned by Flez_ent!",
	"Want to become an instant staff member? Purchase the Barista donation role in our Shop above!",
	"Want to become one of the top pet owners? Play our game and earn Boba Bucks every minute!",
	"Need help? Find one of our moderation staff members around the cafe!",
	"Want to know more about updates? Join our communications server for more information!",
	"Need access to our fun water items? Rent our Fun Pass in our Shop!",
	"Want to get promoted as a Barista? Work to gain points!",
	"How to get promoted? When you reach a certain amount of points you will be automatically ranked!",
	"To hatch your pet, go to your inventory, click capsules, choose a capsule, and click hatch!",
	"Is hatching taking too long? Purchase the auto hatch product!",
	"Don't forget to explore the island!",
	"Complete quests and unlock new badges!",
}

local SPRING_SLIDE = { mass = 1, tension = 280, friction = 35 } -- bouncy "Back" feel
local SPRING_FADE = { mass = 1, tension = 10000, friction = 150 }

---> notification type
export type Notification = {
	Text: string,
	Image: string?,
	SoundEnabled: boolean?,
}

-- ─── public API ──────────────────────────────────────────────────────────────

local module = {}

--[=[
	Enqueues a notification to display on screen.
]=]
function module.Push(notification: Notification)
	pushEvent:Fire(notification)
end

module.Component = function()
	local queue, setQueue = React.useState({} :: { Notification })
	local processingRef = React.useRef(false)

	---> spring: sizeY drives card height (0 → CARD_HEIGHT)
	---> spring: opacity drives content transparency (1 = invisible, 0 = visible)
	local styles, api = ReactSpring.useSpring(function()
		return {
			SizeY = 0,
			Opacity = 1,
			config = SPRING_SLIDE,
		}
	end)

	React.useEffect(function()
		local this = task.spawn(function()
			while true do
				for _, hint in HINTS do
					task.wait(15)
					pushEvent:Fire({
						Text = hint,
					})
				end
			end
		end)
		return function()
			task.cancel(this)
		end
	end, {})

	---> listen for newly pushed notifications
	React.useEffect(function()
		local conn = pushEvent.Event:Connect(function(notification: Notification)
			setQueue(function(prev)
				local next = table.clone(prev)
				table.insert(next, notification)
				return next
			end)
		end)
		return function()
			conn:Disconnect()
		end
	end, {})

	---> process the head of the queue whenever it changes and we are not already animating
	React.useEffect(function()
		if processingRef.current or #queue == 0 then
			return
		end
		processingRef.current = true

		local thread = task.spawn(function()
			local current: Notification = queue[1]

			-- -- optional sound
			-- if current.SoundEnabled then
			-- 	pcall(function()
			-- 		ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SoundProvider")
			-- 			:WaitForChild("Get")("Announcement"):Play()
			-- 	end)
			-- end

			-- slide in (Back-style spring)
			api.start({ SizeY = CARD_HEIGHT, Opacity = 1, config = SPRING_SLIDE })
			task.wait(0.8) -- card is mostly open

			-- fade content in
			api.start({ Opacity = 0, config = SPRING_FADE })
			task.wait(8) -- hold

			-- fade content out
			api.start({ Opacity = 1, config = SPRING_FADE })
			task.wait(0.35)

			-- slide out
			api.start({ SizeY = 0, config = SPRING_SLIDE })
			task.wait(0.9)

			-- advance queue
			setQueue(function(prev)
				local next = table.clone(prev)
				table.remove(next, 1)
				return next
			end)
			processingRef.current = false
		end)

		return function()
			task.cancel(thread)
			processingRef.current = false
		end
	end, { queue })

	---> render nothing when queue is empty and card is fully closed
	---> (the spring still animates to 0 even after the item is removed)
	local current: Notification? = queue[1]

	return c(Pane, {
		ClassName = "Frame",
		Native = {
			-- card expands vertically via spring; width fills parent
			Size = styles.SizeY:map(function(h: number)
				return UDim2.new(1, 0, 0, h)
			end),
			BackgroundTransparency = 1,
			ClipsDescendants = false,
			LayoutOrder = -6,
		},
	}, {
		-- ── panel background (9-slice) ──────────────────────────────────────
		Panel = current and c("ImageLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Image = PANEL_IMAGE,
			Position = UDim2.fromScale(0.5, 0.5),
			ScaleType = Enum.ScaleType.Slice,
			Size = UDim2.fromScale(1, 1),
			SliceCenter = Rect.new(256, 256, 256, 256),
			SliceScale = 0.05,
		}, {
			-- inner tinted border
			InnerBorder = c("ImageLabel", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Image = PANEL_IMAGE,
				ImageColor3 = Color3.fromRGB(124, 103, 89),
				Position = UDim2.fromScale(0.5, 0.5),
				ScaleType = Enum.ScaleType.Slice,
				Size = UDim2.new(1, -6, 1, -6),
				SliceCenter = Rect.new(256, 256, 256, 256),
				SliceScale = 0.04,
			}),

			-- ── icon ───────────────────────────────────────────────────────
			Icon = current and c("ImageLabel", {
				AnchorPoint = Vector2.new(0.5, 0.45),
				BackgroundTransparency = 1,
				Image = current.Image or "rbxassetid://138404484604568",
				ImageTransparency = 0,--styles.Opacity,
				Position = UDim2.fromScale(0.5, 0),
				ScaleType = Enum.ScaleType.Fit,
				Size = ICON_SIZE,
			}, {
				UIAspectRatioConstraint = c("UIAspectRatioConstraint", { AspectRatio = 1 }),
			}),

			Label = c("TextLabel", {
				AnchorPoint = Vector2.new(0.5, 1),
				BackgroundTransparency = 1,
				FontFace = Styles.FONT_FREDOKA,
				Position = UDim2.fromScale(0.5, 0.9),
				Size = UDim2.fromScale(0.85, 0.65),
				Text = current.Text,
				TextColor3 = Styles.OFFWHITE,
				TextScaled = true,
				TextTransparency = styles.Opacity,
				TextXAlignment = Enum.TextXAlignment.Center,
				TextYAlignment = Enum.TextYAlignment.Top,
			}),
		}) or nil,
	})
end

return module
