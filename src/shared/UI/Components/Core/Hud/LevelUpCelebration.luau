--[[
	Component: LevelUpCelebration
	Description: Full-screen, non-blocking level-up splash (LVLUP-POPUP), built on the Rush
	             Hour / Boba Party intro (Hud/EventIntro): a rotating GOLD spotlight behind a
	             big "LEVEL UP!" Banner pops in under the TopBar, a confetti burst fires from
	             it, the new level and title pop in under it, then each unlock pops in one by
	             one. Pops away on its own; nothing to dismiss, so play never stops. Listens to
	             ProgressionService.LeveledUp and plays multi-level grants back to back.
	             EventFxController handles the world side (confetti burst, FOV punch);
	             LevelBar plays the sound.
	Props:
	- Preview: Optional payload { Level: number, Title: string?, Unlocks: { string }? } for
	  stories. Shown at once and replayed every few seconds.
]]

--!nonstrict

---> Services

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

---> Dependencies

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = Shared:WaitForChild("UI")

local Knit = require(Packages.Knit)
local React = require(Packages.React)

local Styles = require(UI.Styles)
local Banner = require(UI.Components.Buttons.Banner)
local BackgroundSpotlight = require(UI.Components.Decoration.BackgroundSpotlight)
local PassUpsell = require(UI.Utility.PassUpsell)
local usePx = require(UI.Hooks.usePx)

---> Private

local c = React.createElement

-- Same beats as Hud/EventIntro.
local HOLD_SECONDS = 3.2
local POP_IN = TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local POP_OUT = TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.In)
local CONFETTI_COUNT = 70
local CONFETTI_COLORS = { Styles.GOLD, Styles.ROSE, Styles.GREEN_LIGHT, Styles.CORAL, Styles.CREAM, Styles.OFFWHITE }
local ORIGIN = Vector2.new(0.5, 0.3)

-- Level-up extras: the level line lands just after the banner, then the unlocks
-- one at a time. Each unlock buys the splash a little more time on screen.
local LEVEL_DELAY = 0.2
local UNLOCK_DELAY = 0.45
local UNLOCK_STAGGER = 0.12
local HOLD_PER_UNLOCK = 0.5
local HOLD_UPSELL = 6
local HOLD_MAX = 6
local HOLD_QUEUED = 1.8 -- shorter when more level-ups wait behind this one
local UNLOCK_TEXT_SIZE = 24 -- px; long lines wrap rather than shrink
local UPSELL_HEIGHT = 0.24

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

-- One piece: flies out of the banner, then tumbles down off screen. Same flight as
-- EventIntro.launchPiece.
local function launchPiece(layer: Frame)
	local piece = Instance.new("Frame")
	piece.AnchorPoint = Vector2.new(0.5, 0.5)
	piece.BackgroundColor3 = CONFETTI_COLORS[math.random(1, #CONFETTI_COLORS)]
	piece.BorderSizePixel = 0
	piece.Position = UDim2.fromScale(ORIGIN.X, ORIGIN.Y)
	piece.Rotation = math.random(0, 360)
	local long = math.random() < 0.5
	piece.Size = if long then UDim2.fromOffset(7, 14) else UDim2.fromOffset(10, 10)
	piece.ZIndex = 1
	piece.Parent = layer

	local angle = math.rad(math.random(200, 340)) -- mostly upward and out
	local reach = 0.12 + math.random() * 0.3
	local peak = UDim2.fromScale(ORIGIN.X + math.cos(angle) * reach * 1.4, ORIGIN.Y + math.sin(angle) * reach)
	local outTime = 0.35 + math.random() * 0.2
	local fallTime = 1.8 + math.random() * 1.4
	local spin = math.random(-720, 720)

	local out = TweenService:Create(
		piece,
		TweenInfo.new(outTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Position = peak, Rotation = piece.Rotation + spin * 0.3 }
	)
	out.Completed:Once(function()
		local drift = (math.random() - 0.5) * 0.12
		local fall =
			TweenService:Create(piece, TweenInfo.new(fallTime, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Position = UDim2.fromScale(peak.X.Scale + drift, 1.1),
				Rotation = piece.Rotation + spin,
			})
		fall.Completed:Once(function()
			piece:Destroy()
		end)
		fall:Play()
	end)
	out:Play()
end

-- A UIScale that starts at 0 and Back-pops to 1 after Delay seconds on mount.
local function DelayedPop(props: { Delay: number })
	local ref = React.useRef(nil)
	React.useEffect(function()
		local scale: UIScale? = ref.current
		if scale == nil then
			return
		end
		local thread = task.delay(props.Delay, function()
			TweenService:Create(scale, POP_IN, { Scale = 1 }):Play()
		end)
		return function()
			task.cancel(thread)
		end
	end, {})
	return c("UIScale", { Scale = 0, ref = ref })
end

-- White Fredoka line with a Deep stroke, as EventIntro's subtitle. With TextSize the
-- line keeps that size and wraps (growing taller) instead of shrinking to fit.
local function outlinedText(props: {
	Text: string,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	Size: UDim2,
	TextSize: number?,
	LayoutOrder: number?,
	Delay: number,
})
	local fixed = props.TextSize ~= nil
	return c("TextLabel", {
		AnchorPoint = props.AnchorPoint,
		AutomaticSize = if fixed then Enum.AutomaticSize.Y else nil,
		BackgroundTransparency = 1,
		FontFace = Styles.FONT_FREDOKA,
		LayoutOrder = props.LayoutOrder,
		Position = props.Position,
		Size = props.Size,
		Text = props.Text,
		TextColor3 = Styles.OFFWHITE,
		TextScaled = not fixed,
		TextSize = props.TextSize,
		TextWrapped = true,
		ZIndex = 11,
	}, {
		Stroke = c("UIStroke", { Color = Styles.GOLD_DEEP, Thickness = 2 }),
		Pop = c(DelayedPop, { Delay = props.Delay }),
	})
end

local function holdFor(unlockCount: number, upsell: boolean, queued: boolean): number
	if queued then
		return HOLD_QUEUED
	end
	local hold = math.min(HOLD_SECONDS + unlockCount * HOLD_PER_UNLOCK, HOLD_MAX)
	if upsell then
		hold = math.max(hold, HOLD_UPSELL)
	end
	return hold
end

---> Component

return function(props: {
	Preview: LevelUpPayload?,
})
	local preview = props.Preview
	local showingPreview = preview ~= nil and typeof(preview.Level) == "number"

	local queue, setQueue = React.useState({} :: { LevelUpPayload })
	local current, setCurrent = React.useState(nil :: { Payload: LevelUpPayload, Id: number }?)
	local scaleRef = React.useRef(nil)
	local layerRef = React.useRef(nil)
	local idRef = React.useRef(0)

	local function play(payload: LevelUpPayload)
		idRef.current += 1
		setCurrent({ Payload = payload, Id = idRef.current })
	end

	-- Unconditional (guard inside) so the hook count never varies. Stories replay the
	-- Preview; live play queues every LeveledUp payload.
	React.useEffect(function()
		if showingPreview then
			play(preview)
			local alive = true
			task.spawn(function()
				while alive do
					task.wait(holdFor(#cleanUnlocks(preview.Unlocks), false, false) + 1.5)
					if alive then
						play(preview)
					end
				end
			end)
			return function()
				alive = false
			end
		end
		if not RunService:IsRunning() then
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
	end, { preview })

	-- Idle with a payload waiting: take the next one.
	React.useEffect(function()
		if current ~= nil or #queue == 0 then
			return
		end
		local nextPayload = queue[1]
		setQueue(function(old: { LevelUpPayload })
			local rest = table.clone(old)
			table.remove(rest, 1)
			return rest
		end)
		play(nextPayload)
	end, { current, queue } :: { any })

	-- Upsell row (UPSELL lane 2): every 3rd level, no XP pass owned. Hooks run on every render.
	local px = usePx()
	local owned = PassUpsell.useOwned(PassUpsell.XP_PASS_IDS)
	local clickedId, setClickedId = React.useState(0)
	local level = if current ~= nil then current.Payload.Level else nil
	local capOk = level ~= nil and PassUpsell.ShouldShowOnLevelUp(level)
	local clicked = current ~= nil and clickedId == current.Id
	local offerPassId = if capOk and not clicked then PassUpsell.PickLevelUpOffer(owned) else nil
	local offerPrice = PassUpsell.usePrice(offerPassId)
	local showUpsell = offerPassId ~= nil and offerPrice ~= nil

	-- Read by the hold timer, which outlives this render.
	local queuedRef = React.useRef(false)
	queuedRef.current = #queue > 0
	local upsellRef = React.useRef(false)
	upsellRef.current = showUpsell

	-- Pop in, confetti, hold, pop out. A newer payload restarts the sequence.
	React.useEffect(function()
		if current == nil then
			return
		end
		local scale: UIScale? = scaleRef.current
		local layer: Frame? = layerRef.current
		local alive = true
		if scale then
			scale.Scale = 0
			TweenService:Create(scale, POP_IN, { Scale = 1 }):Play()
		end
		if layer then
			for _ = 1, CONFETTI_COUNT do
				launchPiece(layer)
			end
		end
		local mine = current.Id
		local unlockCount = #cleanUnlocks(current.Payload.Unlocks)
		-- Preview replays on its own clock and never pops out.
		if showingPreview then
			return function()
				alive = false
			end
		end
		task.spawn(function()
			-- Let the upsell price arrive before choosing the hold.
			task.wait(HOLD_QUEUED)
			if not alive or idRef.current ~= mine then
				return
			end
			local hold = holdFor(unlockCount, upsellRef.current, queuedRef.current)
			task.wait(math.max(hold - HOLD_QUEUED, 0))
			if not alive or idRef.current ~= mine then
				return
			end
			if scale then
				TweenService:Create(scale, POP_OUT, { Scale = 0 }):Play()
			end
			task.wait(POP_OUT.Time)
			if alive and idRef.current == mine then
				setCurrent(nil)
			end
		end)
		return function()
			alive = false
		end
	end, { current })

	-- Confetti outlives the card, so its layer stays mounted.
	local children = {
		Confetti = c("Frame", {
			Active = false,
			BackgroundTransparency = 1,
			ClipsDescendants = true,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 1,
			ref = layerRef,
		}),
	}

	if current ~= nil then
		local payload = current.Payload
		local title = if typeof(payload.Title) == "string" then payload.Title else ""
		local unlocks = cleanUnlocks(payload.Unlocks)
		local levelText = if title ~= "" then `Level {payload.Level}: {title}!` else `Level {payload.Level}!`

		local below: { [string]: any } = {
			Layout = c("UIListLayout", {
				FillDirection = Enum.FillDirection.Vertical,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				Padding = UDim.new(0, 4),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		}
		for index, line in unlocks do
			below[`Unlock_{index}`] = outlinedText({
				Text = line,
				Size = UDim2.fromScale(0.8, 0),
				TextSize = px(UNLOCK_TEXT_SIZE),
				LayoutOrder = index,
				Delay = UNLOCK_DELAY + (index - 1) * UNLOCK_STAGGER,
			})
		end
		if showUpsell then
			-- Secondary and lesser; clicking only opens the purchase prompt.
			local passId = offerPassId :: number
			below.Upsell = c("Frame", {
				BackgroundTransparency = 1,
				LayoutOrder = #unlocks + 1,
				Size = UDim2.fromScale(0.8, UPSELL_HEIGHT),
			}, {
				Row = c(PassUpsell.Row, {
					Text = `Level faster: +{PassUpsell.BOOST_PERCENT[passId] or 25}% XP`,
					ButtonText = `Get {PassUpsell.PriceText(offerPrice)}`,
					Lesser = true,
					Size = UDim2.fromScale(1, 1),
					OnClick = function()
						setClickedId(current.Id)
						PassUpsell.Prompt(passId)
					end,
				}),
				Pop = c(DelayedPop, { Delay = UNLOCK_DELAY + #unlocks * UNLOCK_STAGGER }),
			})
		end

		-- Keyed by Id so every level-up remounts and replays the staggered pops.
		children[`Card_{current.Id}`] = c("Frame", {
			Active = false,
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(ORIGIN.X, ORIGIN.Y),
			Size = UDim2.fromScale(0.5, 0.22),
			ZIndex = 2,
		}, {
			Aspect = c("UIAspectRatioConstraint", { AspectRatio = 3 }),
			SizeLimit = c("UISizeConstraint", {
				MaxSize = Vector2.new(560, 187),
				MinSize = Vector2.new(300, 100),
			}),
			Scale = c("UIScale", { Scale = 0, ref = scaleRef }),
			Spotlight = c(BackgroundSpotlight, {
				Native = {
					ImageColor3 = Styles.GOLD,
					ImageTransparency = 0.25,
					Position = UDim2.fromScale(0.5, 0.45),
					Size = UDim2.fromScale(1.3, 1.3),
					ZIndex = 0,
				},
			}),
			Title = c(Banner, {
				Text = "LEVEL UP!",
				Color = Styles.GOLD_MID,
				Position = UDim2.fromScale(0.5, 0.4),
				Size = UDim2.fromScale(1, 0.7),
			}),
			Subtitle = outlinedText({
				Text = levelText,
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.fromScale(0.5, 0.78),
				Size = UDim2.fromScale(0.9, 0.2),
				Delay = LEVEL_DELAY,
			}),
			Below = c("Frame", {
				Active = false,
				AnchorPoint = Vector2.new(0.5, 0),
				BackgroundTransparency = 1,
				Position = UDim2.fromScale(0.5, 1.04),
				Size = UDim2.fromScale(1, 1), -- row heights are in card heights; rows overflow downward
			}, below),
		})
	end

	return c("Frame", {
		Active = false,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 20,
	}, children)
end
