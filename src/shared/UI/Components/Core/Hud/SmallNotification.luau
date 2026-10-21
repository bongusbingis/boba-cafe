--[[
	SmallNotification
	Toast-style notification card that springs in above the bottom-left HUD buttons.
	Each notification slides in, fades its content in, holds for 5 seconds, then slides back out.
	If a new notification is pushed while one is showing, it is queued (max 3) and shown
	next; queued toasts hold for a shorter time. Hints never interrupt gameplay toasts.

	Queue policy (REVIEW-FIX P2-2, FEEDBACK-VOICE 3): every toast has a tier, read from
	an optional `Priority` (1 high .. 5 low) or inferred from its text. The queue is
	ordered by tier, FIFO within a tier. When it is full, the oldest toast of the lowest
	tier is dropped; tier 1 (level up, quest complete/claimed, first order) is never
	dropped. A toast whose text is already showing or queued is ignored, a new
	"Order served!" replaces a queued one, and corrective toasts (wrong drink, wrong
	station, Clock In, or `Corrective = true`) replace the active toast at once; a
	displaced tier 1-2 toast goes back to the front of the queue.

	External API (call from any client script):
		SmallNotification.Push({
			Title       = "Badge Earned!",
			Description = "You earned your first badge.",
			Image       = "rbxassetid://XXXX",
			SoundEnabled = true,   -- optional
			Priority = 2,          -- optional, 1 (never dropped) .. 5 (hint)
			Corrective = true,     -- optional, replaces the active toast
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
local UiSfx = require(UI.Utility.UiSfx)

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
	"Can't find the pet or trail purchases you made? Check the inventory tab above! ",
	"Boba Cafe is owned by Flez_ent!",
	"Want to become one of the top pet owners? Play our game and earn Boba Bucks every minute!",
	"Need help? Find one of our moderation staff members around the cafe!",
	"Want to know more about updates? Join our communications server for more information!",
	"To hatch your pet, go to your inventory, click capsules, choose a capsule, and click hatch!",
	"Don't forget to explore the island!",
	"Complete quests and unlock new badges!",
}

local HOLD_DURATION = 5
local HOLD_BUSY = 2 -- TUNING: hold seconds when more toasts are queued
local HINT_QUIET_SECONDS = 20 -- TUNING: hints skip their turn this long after a gameplay toast
local QUEUE_CAP = 3
local SPRING_SLIDE = { mass = 1, tension = 280, friction = 35 } -- bouncy "Back" feel
local SPRING_FADE = { mass = 1, tension = 10000, friction = 150 }

---> notification type
export type Notification = {
	Text: string,
	Title: string?,
	Description: string?,
	_hint: boolean?,
	Image: string?,
	SoundEnabled: boolean?,
	Priority: number?,
	Corrective: boolean?,
}

local module = {}

---> module-level state shared with the component (single instance)
local idleSince: number? = os.clock()
local lastGameplayAt: number? = nil
local warnedNoText = false

local function endsWithPunctuation(text: string): boolean
	local last = string.sub(text, -1)
	return last == "!" or last == "?" or last == "." or last == ":"
end

local function isNonEmptyString(value): boolean
	return typeof(value) == "string" and value ~= ""
end

local function startsWith(text: string, prefix: string): boolean
	return string.sub(text, 1, #prefix) == prefix
end

-- Sound cue names for a toast, or nil (FEEDBACK-VOICE 4). Text matching is plain and case-sensitive.
local function soundFor(data): { string }?
	local text = data and data.Text
	if typeof(text) ~= "string" then
		return nil
	end
	if startsWith(text, "Level up!") then
		return nil -- LevelBar owns the level-up sound
	elseif startsWith(text, "Quest claimed!") then
		return { "Success" }
	elseif startsWith(text, "Quest complete:") then
		return { "Pop1" }
	elseif string.find(text, "completed the Team Combo!", 1, true) or startsWith(text, "Team Combo!") then
		return { "Pop1" }
	elseif startsWith(text, "Your first order!") then
		return { "Success" }
	end
	local combo = string.match(text, "^Combo ×(%d+)")
	if combo and UiSfx.IsComboMilestone(tonumber(combo)) then
		return { "Pop1" }
	end
	return nil
end

-- Tier 1 is never dropped; 5 is the rotating hint.
local TIER_TOP = 1
local TIER_DEFAULT = 3
local TIER_HINT = 5

local function localDisplayName(): string?
	local ok, name = pcall(function()
		local player = game:GetService("Players").LocalPlayer
		return player and player.DisplayName
	end)
	return if ok then name else nil
end

-- Tier and kind ("Corrective", "Served" or nil) of a toast (FEEDBACK-VOICE 3).
function module.Classify(data: Notification): (number, string?)
	local text = if typeof(data.Text) == "string" then data.Text else ""
	local kind: string? = nil
	if
		data.Corrective == true
		or startsWith(text, "Wrong drink")
		or startsWith(text, "Next: ")
		or startsWith(text, "Clock In to use the kitchen")
	then
		kind = "Corrective"
	elseif startsWith(text, "Order served!") then
		kind = "Served"
	end
	if typeof(data.Priority) == "number" then
		return math.clamp(math.floor(data.Priority), TIER_TOP, TIER_HINT), kind
	end
	if data._hint then
		return TIER_HINT, kind
	end
	if
		startsWith(text, "Level up!")
		or startsWith(text, "Quest complete:")
		or startsWith(text, "Quest claimed!")
		or startsWith(text, "Your first order!")
	then
		return TIER_TOP, kind
	end
	if startsWith(text, "Team Combo!") or startsWith(text, "New title:") or startsWith(text, "Rush Hour!") then
		return 2, kind
	end
	local name = string.match(text, "^(.-) completed the Team Combo!")
	if name ~= nil then
		return if name == localDisplayName() then 2 else 3, kind
	end
	if
		kind == "Served"
		or text == "Team Combo is over."
		or text == "Rush Hour is over."
		or startsWith(text, "Welcome to Boba Cafe!")
		or startsWith(text, "You can afford a capsule!")
		or startsWith(text, "Thank ")
	then
		return 4, kind
	end
	return TIER_DEFAULT, kind
end

-- Applies the queue policy for one pushed toast. Mutates `queue` and returns
-- "Show" (nothing active), "Replace" (show now over the active toast), "Queued" or "Dropped".
function module.Route(queue: { Notification }, active: Notification?, data: Notification): string
	if active ~= nil and active.Text == data.Text then
		return "Dropped"
	end
	for _, queued in queue do
		if queued.Text == data.Text then
			return "Dropped"
		end
	end
	if active == nil then
		return "Show"
	end
	local tier, kind = module.Classify(data)
	if tier == TIER_HINT then
		return "Dropped" -- hints never wait behind or interrupt gameplay toasts
	end
	if kind == "Corrective" then
		local activeTier, activeKind = module.Classify(active)
		if activeKind ~= "Corrective" and activeTier <= 2 then
			table.insert(queue, 1, active)
		end
		for index = #queue, 1, -1 do
			local _, queuedKind = module.Classify(queue[index])
			if queuedKind == "Corrective" then
				table.remove(queue, index)
			end
		end
		return "Replace"
	end
	if kind == "Served" then
		for index, queued in queue do
			local _, queuedKind = module.Classify(queued)
			if queuedKind == "Served" then
				queue[index] = data
				return "Queued"
			end
		end
	end
	local position = #queue + 1
	for index, queued in queue do
		if module.Classify(queued) > tier then
			position = index
			break
		end
	end
	table.insert(queue, position, data)
	while #queue > QUEUE_CAP do
		local lowest, drop = TIER_TOP, nil
		for index, queued in queue do
			local queuedTier = module.Classify(queued)
			if queuedTier > lowest then
				lowest, drop = queuedTier, index
			end
		end
		if drop == nil then
			break -- only tier 1 left: never dropped
		end
		local removed = table.remove(queue, drop)
		if removed == data then
			return "Dropped"
		end
	end
	return "Queued"
end

function module.Push(notification: Notification)
	local copy = table.clone(notification)
	if not isNonEmptyString(copy.Text) then
		local title, description = copy.Title, copy.Description
		if isNonEmptyString(title) and isNonEmptyString(description) then
			local sep = endsWithPunctuation(title) and " " or ": "
			copy.Text = title .. sep .. description
		elseif isNonEmptyString(title) then
			copy.Text = title
		elseif isNonEmptyString(description) then
			copy.Text = description
		else
			if not warnedNoText then
				warnedNoText = true
				warn("[SmallNotification] toast with no text")
			end
			return
		end
	end
	pushEvent:Fire(copy)
end

---> seconds since the panel became fully idle (no active toast, empty queue); 0 while busy
function module.IdleFor(): number
	if idleSince == nil then
		return 0
	end
	return os.clock() - idleSince
end

module.Component = function()
	type NotificationEntry = {
		Id: number,
		Data: Notification,
	}

	local activeEntry, setActiveEntry = React.useState(nil :: NotificationEntry?)
	local nextEntryId = React.useRef(0)
	local activeRef = React.useRef(nil :: NotificationEntry?) -- synchronous mirror of activeEntry
	local queueRef = React.useRef({} :: { Notification })
	local showNextRef = React.useRef(nil :: ((Notification) -> ())?)

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
					local busy = activeRef.current ~= nil
						or #queueRef.current > 0
						or (lastGameplayAt ~= nil and os.clock() - lastGameplayAt < HINT_QUIET_SECONDS)
					if not busy then
						pushEvent:Fire({
							Text = hint,
							_hint = true,
						})
					end
				end
			end
		end)
		return function()
			task.cancel(this)
		end
	end, {})

	---> listen for newly pushed notifications
	React.useEffect(function()
		local function show(notification: Notification)
			nextEntryId.current += 1
			local entry = {
				Id = nextEntryId.current,
				Data = notification,
			}
			activeRef.current = entry
			setActiveEntry(entry)
		end
		showNextRef.current = show

		local conn = pushEvent.Event:Connect(function(notification: Notification)
			idleSince = nil
			if not notification._hint then
				lastGameplayAt = os.clock()
			end
			local active = activeRef.current
			local route = module.Route(queueRef.current, active and active.Data, notification)
			if route == "Show" or route == "Replace" then
				show(notification)
			elseif route == "Dropped" and active == nil and #queueRef.current == 0 then
				idleSince = os.clock()
			end
		end)
		return function()
			conn:Disconnect()
		end
	end, {})

	---> animate the active notification; queued pushes replace it when it finishes
	React.useEffect(function()
		if not activeEntry then
			return
		end

		local thread = task.spawn(function()
			local currentEntryId = activeEntry.Id

			-- toast sound (SOUNDS D9): only the big beats; everything else stays silent
			local cues = soundFor(activeEntry.Data)
			if cues then
				pcall(UiSfx.Play, cues)
			end

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
			task.wait(if #queueRef.current > 0 then HOLD_BUSY else HOLD_DURATION) -- hold

			-- fade content out
			api.start({ Opacity = 1, config = SPRING_FADE })
			task.wait(0.35)

			-- slide out
			api.start({ SizeY = 0, config = SPRING_SLIDE })
			task.wait(0.9)

			-- advance only if this is still the active entry
			if activeRef.current and activeRef.current.Id == currentEntryId then
				local nextData = table.remove(queueRef.current, 1)
				if nextData and showNextRef.current then
					showNextRef.current(nextData)
				else
					activeRef.current = nil
					idleSince = os.clock()
					setActiveEntry(nil)
				end
			end
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
				ImageTransparency = 0, --styles.Opacity,
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
