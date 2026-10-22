--[[
	Component: PaycheckCard
	Description: Non-modal shift paycheck receipt (PAYCHECK-WIRE). The HUD
	             mounts it always; it renders only while a paycheck payload
	             is active. Listens to ShiftService.Paycheck (the server fires
	             the shift's pay lines on every shift end) and queues payloads.
	             The popup IS the check (ported art in PaycheckArt): a centered
	             Page pop, CloseButton on the check's top-right corner,
	             auto-dismiss after 8 s. The pay breakdown lives on ShiftCard.
	             Never blocks input behind it.
	Props:
	- Preview: Optional payload for stories. Shown at once, never auto-dismissed.
]]

--!nonstrict

---> Services

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

---> Dependencies

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = Shared:WaitForChild("UI")

local Knit = require(Packages.Knit)
local React = require(Packages.React)

local Page = require(UI.Components.Core.Page)
local CloseButton = require(UI.Components.Buttons.CloseButton)
local usePx = require(UI.Hooks.usePx)

---> Private

local c = React.createElement

-- Mirrors App.luau PAGE_SWAP_DELAY: lets the close spring start before unmounting.
local CLOSE_DELAY = 0.025
local AUTO_DISMISS_SECONDS = 8

local CLOSE_BUTTON_W = 0.0919732
local CLOSE_BUTTON_H = 0.123874
local CLOSE_BUTTON_X = 0.980770
local CLOSE_BUTTON_Y = 0.147523
-- CloseButton draws itself at fixed fractions of its parent, so anchor the
-- holder at the button's own center: the X then lands exactly on Position.
local CLOSE_CENTER_X = CLOSE_BUTTON_X + CLOSE_BUTTON_W / 2
local CLOSE_CENTER_Y = CLOSE_BUTTON_Y + CLOSE_BUTTON_H / 2

export type PaycheckPayload = {
	Pay: number?,
	Tips: number?,
	Bonus: number?,
	Total: number?,
	StreakBonus: number?,
	Stars: number?,
	Served: number?,
	Walkouts: number?,
	Shift: number?,
	First: boolean?,
}

-- PAYCHECK ART SLOT (ported from the original game's check):
-- a check ImageLabel with overlay fields positioned in fractions of the
-- image, exactly as authored. Field mapping from the old handler:
-- Player = LocalPlayer.Name, Date = today, Amount = shift Total,
-- AmountString = "{Total} Boba Bucks", Reason = first-shift line or
-- "Shift N complete". Dropped from the old handler on purpose: the
-- fly-in/out tween (the Page pop replaces it), screen darken, and
-- tap-anywhere-to-dismiss (all three would block input behind the card).
local CHECK_IMAGE = "rbxassetid://15045483052"
local CHECK_FONT = Font.new("rbxasset://fonts/families/AccanthisADFStd.json")

local function PaycheckArt(props: { Payload: PaycheckPayload? })
	local payload = props.Payload
	local total = 0
	if typeof(payload) == "table" then
		total = tonumber(payload.Total) or 0
	end
	local shift = if typeof(payload) == "table" then tonumber(payload.Shift) or 0 else 0
	local first = if typeof(payload) == "table" then payload.First == true else false
	local playerName = "Barista"
	pcall(function()
		local localPlayer = Players.LocalPlayer
		if localPlayer ~= nil then
			playerName = localPlayer.Name
		end
	end)
	return c("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
	}, {
		player = c("TextLabel", {
			BackgroundTransparency = 1,
			FontFace = CHECK_FONT,
			Position = UDim2.fromScale(0.27, 0.395),
			Size = UDim2.fromScale(0.432058, 0.0769334),
			Text = playerName,
			TextColor3 = Color3.new(),
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),
		date = c("TextLabel", {
			BackgroundTransparency = 1,
			FontFace = CHECK_FONT,
			Position = UDim2.fromScale(0.706974, 0.239941),
			Size = UDim2.fromScale(0.130096, 0.0734288),
			Text = `{os.date("%m/%d/%Y")}`,
			TextColor3 = Color3.new(),
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),
		amount = c("TextLabel", {
			BackgroundTransparency = 1,
			FontFace = CHECK_FONT,
			Position = UDim2.fromScale(0.726266, 0.388826),
			Size = UDim2.fromScale(0.130096, 0.0964954),
			Text = tostring(total),
			TextColor3 = Color3.new(),
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),
		amountString = c("TextLabel", {
			BackgroundTransparency = 1,
			FontFace = CHECK_FONT,
			Position = UDim2.fromScale(0.163441, 0.537934),
			Size = UDim2.fromScale(0.498322, 0.0857867),
			Text = `{total} Boba Bucks`,
			TextColor3 = Color3.new(),
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),
		reason = c("TextLabel", {
			BackgroundTransparency = 1,
			FontFace = CHECK_FONT,
			Position = UDim2.fromScale(0.167, 0.685),
			Size = UDim2.fromScale(0.498322, 0.0857867),
			Text = if first then "First shift complete!" else `Shift {shift} complete`,
			TextColor3 = Color3.new(),
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),
		block = c("Frame", {
			BackgroundColor3 = Color3.fromRGB(214, 237, 208),
			BorderColor3 = Color3.new(),
			BorderSizePixel = 0,
			Position = UDim2.fromScale(0.674383, 0.561986),
			Size = UDim2.fromScale(0.0756752, 0.1),
		}),
	})
end

-- The popup IS the check: the amounts print on it, and ShiftCard keeps
-- the pay breakdown. A CloseButton rides the check's top-right corner;
-- auto-dismiss still applies. No card chrome around it.
local function PaycheckBody(props: {
	Payload: PaycheckPayload,
	OnCloseRequested: () -> (),
})
	local px = usePx()
	local closeSize = px(56)

	return c("ImageLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Image = CHECK_IMAGE,
		Position = UDim2.fromScale(0.5, 0.5),
		ScaleType = Enum.ScaleType.Fit,
		Size = UDim2.fromScale(0.7, 0.28),
	}, {
		uIAspectRatioConstraint = c("UIAspectRatioConstraint", {
			AspectRatio = 2.5,
		}),
		Art = c(PaycheckArt, { Payload = props.Payload }),
		CloseHolder = c("Frame", {
			AnchorPoint = Vector2.new(CLOSE_CENTER_X, CLOSE_CENTER_Y),
			BackgroundTransparency = 1,
			Position = UDim2.new(1, -px(20), 0, px(20)),
			Size = UDim2.fromOffset(closeSize / CLOSE_BUTTON_W, closeSize / CLOSE_BUTTON_H),
			ZIndex = 2,
		}, {
			CloseButton = c(CloseButton, { OnClick = props.OnCloseRequested }),
		}),
	})
end

---> Component

return function(props: {
	Preview: PaycheckPayload?,
})
	local preview = props.Preview
	local showingPreview = preview ~= nil

	local queue, setQueue = React.useState({} :: { PaycheckPayload })
	local closeFnRef = React.useRef(nil)
	local isClosingRef = React.useRef(false)
	local generationRef = React.useRef(0)

	-- Stable identity: Page restarts its spring whenever PageContent changes.
	local advance = React.useCallback(function()
		isClosingRef.current = false
		setQueue(function(old: { PaycheckPayload })
			local next = table.clone(old)
			table.remove(next, 1)
			return next
		end)
	end, {})

	local handleClose = React.useCallback(function()
		if isClosingRef.current then
			return
		end
		isClosingRef.current = true
		if closeFnRef.current then
			closeFnRef.current()
		end
		task.spawn(function()
			task.wait(CLOSE_DELAY)
			advance()
		end)
	end, {})

	-- Unconditional (guard inside): the hook count never varies between
	-- renders. Stories render with a Preview and no Knit service, so the
	-- subscription is skipped there exactly as before.
	React.useEffect(function()
		if not RunService:IsRunning() or showingPreview then
			return
		end
		local ok, service = pcall(function()
			return Knit.GetService("ShiftService")
		end)
		if not ok or service == nil then
			return
		end
		local conn = service.Paycheck:Connect(function(payload: any)
			if typeof(payload) ~= "table" then
				return
			end
			setQueue(function(old: { PaycheckPayload })
				local next = table.clone(old)
				table.insert(next, table.clone(payload))
				return next
			end)
		end)
		return function()
			conn:Disconnect()
		end
	end, {})

	local active: PaycheckPayload? = if showingPreview then preview else queue[1]

	-- Auto-dismiss the active card; the generation guard keeps a slow timer
	-- from dismissing a newer paycheck that arrived behind it.
	React.useEffect(function()
		if active == nil or showingPreview then
			return
		end
		generationRef.current += 1
		local mine = generationRef.current
		local thread = task.delay(AUTO_DISMISS_SECONDS, function()
			if generationRef.current == mine then
				handleClose()
			end
		end)
		return function()
			generationRef.current += 1
			task.cancel(thread)
		end
	end, { active })

	-- Unconditional: every hook runs on every render.
	local pageContent = React.useMemo(function()
		if active == nil then
			return nil
		end
		local shown: PaycheckPayload = active
		return c(PaycheckBody, {
			Payload = shown,
			OnCloseRequested = handleClose,
		})
	end, { active })

	if active == nil or pageContent == nil then
		return nil
	end

	return c("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 20,
	}, {
		Page = c(Page, {
			IsVisible = true,
			PageContent = pageContent,
			OnClosing = function(cb)
				closeFnRef.current = cb
			end,
		}),
	})
end
