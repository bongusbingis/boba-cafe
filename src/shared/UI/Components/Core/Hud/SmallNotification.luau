--[[
	SmallNotification
	Toast-style notification card that springs in above the bottom-left HUD buttons.
	Each notification slides in, fades its content in, holds for 5 seconds, then slides back out.
	If a new notification is pushed mid-animation, the current one is interrupted and
	replaced immediately by the new one.

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

---> module-level push event so any script can call Push
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

local HOLD_DURATION = 5
local SPRING_SLIDE = { mass = 1, tension = 280, friction = 35 } -- bouncy "Back" feel
local SPRING_FADE = { mass = 1, tension = 10000, friction = 150 }

---> notification type
export type Notification = {
	Text: string,
	Image: string?,
	SoundEnabled: boolean?,
}

local module = {}

function module.Push(notification: Notification)
	pushEvent:Fire(notification)
end

module.Component = function()
	type NotificationEntry = {
		Id: number,
		Data: Notification,
	}

	local activeEntry, setActiveEntry = React.useState(nil :: NotificationEntry?)
	local nextEntryId = React.useRef(0)

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
					task.wait(60)
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
			nextEntryId.current += 1
			setActiveEntry({
				Id = nextEntryId.current,
				Data = notification,
			})
		end)
		return function()
			conn:Disconnect()
		end
	end, {})

	---> animate the active notification; new pushes interrupt by replacing activeEntry
	React.useEffect(function()
		if not activeEntry then
			return
		end

		local thread = task.spawn(function()
			local currentEntryId = activeEntry.Id

			-- -- optional sound
			-- if current.SoundEnabled then
			-- 	pcall(function()
			-- 		ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SoundProvider")
			-- 			:WaitForChild("Get")("Announcement"):Play()
			-- 	end)
			-- end

			-- slide in (Back-style spring). 'from' hard-resets state so replacement
			-- notifications animate cleanly even when interrupting mid-cycle.
			api.start({
				from = { SizeY = 0, Opacity = 1 },
				to = { SizeY = CARD_HEIGHT, Opacity = 1 },
				config = SPRING_SLIDE,
			})
			task.wait(0.8) -- card is mostly open

			-- fade content in
			api.start({ Opacity = 0, config = SPRING_FADE })
			task.wait(HOLD_DURATION) -- hold

			-- fade content out
			api.start({ Opacity = 1, config = SPRING_FADE })
			task.wait(0.35)

			-- slide out
			api.start({ SizeY = 0, config = SPRING_SLIDE })
			task.wait(0.9)

			-- clear only if this is still the active entry (it may have been replaced)
			setActiveEntry(function(prev)
				if prev and prev.Id == currentEntryId then
					return nil
				end
				return prev
			end)
		end)

		return function()
			task.cancel(thread)
		end
	end, { activeEntry })

	---> render nothing when there is no active notification
	local current: Notification? = activeEntry and activeEntry.Data or nil

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
