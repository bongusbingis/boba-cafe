--[[
	Component: LevelUpCelebration
	Description: Non-modal level-up celebration card (LVLUP-POPUP). The HUD
	             mounts it always; it renders only while a level-up payload
	             is active. Listens to ProgressionService.LeveledUp (the
	             server fires the new level plus its unlock lines on every
	             level-up) and queues multi-level grants. Centered Page pop
	             with a GREEN "LEVEL UP!" header, the new level and title,
	             one row per unlock, and a GREEN dismiss button. Auto-dismiss
	             after 8 s. Never blocks input behind it, so play continues.
	Props:
	- Preview: Optional payload { Level: number, Title: string?,
	  Unlocks: { string }? } for stories. Shown at once, never auto-dismissed.
]]

--!nonstrict

---> Services

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

---> Dependencies

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = Shared:WaitForChild("UI")

local Knit = require(Packages.Knit)
local React = require(Packages.React)

local Styles = require(UI.Styles)
local Pane = require(UI.Components.Pane)
local Page = require(UI.Components.Core.Page)
local Banner = require(UI.Components.Buttons.Banner)
local CloseButton = require(UI.Components.Buttons.CloseButton)
local PromptButton = require(UI.Components.Buttons.PromptButton)
local usePx = require(UI.Hooks.usePx)

---> Private

local c = React.createElement

-- Mirrors App.luau PAGE_SWAP_DELAY: lets the close spring start before unmounting.
local CLOSE_DELAY = 0.025
local AUTO_DISMISS_SECONDS = 8
local CARD_WIDTH = 330

local CLOSE_BUTTON_W = 0.0919732
local CLOSE_BUTTON_H = 0.123874
local CLOSE_BUTTON_X = 0.980770
local CLOSE_BUTTON_Y = 0.147523

export type LevelUpPayload = {
	Level: number,
	Title: string?,
	Unlocks: { string }?,
}

local function cleanUnlocks(raw: any): { string }
	local out: { string } = {}
	if typeof(raw) ~= "table" then
		return out
	end
	for _, line in raw do
		if typeof(line) == "string" and line ~= "" then
			table.insert(out, line)
		end
	end
	return out
end

local function CelebrationCard(props: {
	Payload: LevelUpPayload,
	OnCloseRequested: () -> (),
})
	local px = usePx()
	local payload = props.Payload
	local title = if typeof(payload.Title) == "string" then payload.Title else ""
	local unlocks = cleanUnlocks(payload.Unlocks)
	local closeSize = px(56)

	local rows: { [string]: any } = {}
	rows.Padding = c("UIPadding", {
		PaddingTop = UDim.new(0, px(8)),
		PaddingBottom = UDim.new(0, px(8)),
		PaddingLeft = UDim.new(0, px(12)),
		PaddingRight = UDim.new(0, px(12)),
	})
	rows.Layout = c("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		Padding = UDim.new(0, px(6)),
		SortOrder = Enum.SortOrder.LayoutOrder,
	})

	rows.LevelLine = c("TextLabel", {
		LayoutOrder = 1,
		BackgroundTransparency = 1,
		FontFace = Styles.FONT_FREDOKA,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Text = `Level {payload.Level}`,
		TextColor3 = Styles.GREEN,
		TextSize = px(30),
		TextXAlignment = Enum.TextXAlignment.Center,
	})

	if title ~= "" then
		rows.TitleLine = c("TextLabel", {
			LayoutOrder = 2,
			BackgroundTransparency = 1,
			FontFace = Styles.FONT_DENKONE,
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Text = title,
			TextColor3 = Styles.GREEN_DEEP,
			TextSize = px(20),
			TextXAlignment = Enum.TextXAlignment.Center,
		})
	end

	local nextOrder = 3
	if #unlocks > 0 then
		rows.Divider = c("Frame", {
			LayoutOrder = nextOrder,
			BackgroundColor3 = Styles.GRAY,
			BackgroundTransparency = 0.5,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, 1),
		})
		nextOrder += 1
		for index, line in unlocks do
			rows[`Unlock_{index}`] = c("TextLabel", {
				LayoutOrder = nextOrder,
				BackgroundTransparency = 1,
				FontFace = Styles.FONT_FREDOKA,
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				Text = `• {line}`,
				TextColor3 = Styles.GREEN_DEEP,
				TextSize = px(18),
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Left,
			})
			nextOrder += 1
		end
	end

	rows.Dismiss = c(PromptButton, {
		Text = "Awesome!",
		Color = Styles.GREEN,
		Size = UDim2.new(1, 0, 0, px(50)),
		LayoutOrder = nextOrder,
		OnClick = props.OnCloseRequested,
	})

	local header = c("Frame", {
		LayoutOrder = 1,
		BackgroundColor3 = Styles.GREEN,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, px(60)),
	}, {
		Corner = c("UICorner", { CornerRadius = UDim.new(0, 6) }),
		BottomSquare = c("Frame", {
			AnchorPoint = Vector2.new(0, 1),
			BackgroundColor3 = Styles.GREEN,
			BorderSizePixel = 0,
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.new(1, 0, 0, 6),
		}),
		Banner = c(Banner, {
			Text = "LEVEL UP!",
			Color = Styles.GOLD,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.62, 0.72),
		}),
		CloseHolder = c("Frame", {
			AnchorPoint = Vector2.new(CLOSE_BUTTON_X, CLOSE_BUTTON_Y),
			BackgroundTransparency = 1,
			Position = UDim2.new(1, -(px(6) + closeSize / 2), 0.5, 0),
			Size = UDim2.fromOffset(closeSize / CLOSE_BUTTON_W, closeSize / CLOSE_BUTTON_H),
		}, {
			CloseButton = c(CloseButton, { OnClick = props.OnCloseRequested }),
		}),
	})

	local body = c("Frame", {
		LayoutOrder = 2,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
	}, rows)

	return c(Pane, {
		ClassName = "Frame",
		CornerRadius = UDim.new(0, 6),
		Stroke = {
			Color = Styles.GREEN_DIM,
			Thickness = 1,
		},
		ListLayout = {
			FillDirection = Enum.FillDirection.Vertical,
			SortOrder = Enum.SortOrder.LayoutOrder,
		},
		Native = {
			AnchorPoint = Vector2.new(0.5, 0.5),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = Styles.OFFWHITE,
			BackgroundTransparency = 0,
			BorderSizePixel = 0,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.7, 0),
		},
	}, {
		WidthLimit = c("UISizeConstraint", { MaxSize = Vector2.new(px(CARD_WIDTH), math.huge) }),
		Header = header,
		Body = body,
	})
end

---> Component

return function(props: {
	Preview: LevelUpPayload?,
})
	local preview = props.Preview
	local showingPreview = preview ~= nil and typeof(preview.Level) == "number"

	local queue, setQueue = React.useState({} :: { LevelUpPayload })
	local closeFnRef = React.useRef(nil)
	local isClosingRef = React.useRef(false)
	local generationRef = React.useRef(0)

	-- Stable identity: Page restarts its spring whenever PageContent changes.
	local advance = React.useCallback(function()
		isClosingRef.current = false
		setQueue(function(old: { LevelUpPayload })
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
			return Knit.GetService("ProgressionService")
		end)
		if not ok or service == nil then
			return
		end
		local conn = service.LeveledUp:Connect(function(payload: any)
			if typeof(payload) ~= "table" or typeof(payload.Level) ~= "number" then
				return
			end
			setQueue(function(old: { LevelUpPayload })
				local next = table.clone(old)
				table.insert(next, {
					Level = payload.Level,
					Title = payload.Title,
					Unlocks = cleanUnlocks(payload.Unlocks),
				})
				return next
			end)
		end)
		return function()
			conn:Disconnect()
		end
	end, {})

	local active: LevelUpPayload? = if showingPreview then preview else queue[1]

	-- Auto-dismiss the active card; the generation guard keeps a slow timer
	-- from dismissing a newer level-up that arrived behind it.
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

	-- Unconditional: every hook runs on every render, so a payload arriving
	-- later can never change the hook count (hooks-after-early-return crash).
	local pageContent = React.useMemo(function()
		if active == nil then
			return nil
		end
		local shown: LevelUpPayload = active
		return c(CelebrationCard, {
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
