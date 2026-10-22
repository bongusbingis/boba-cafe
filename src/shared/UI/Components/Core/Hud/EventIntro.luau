--[[
	Component: EventIntro
	Description: Full-screen, non-blocking splash when Rush Hour or a Boba Party starts, or a
	             party is extended (EVENT-FX). A rotating spotlight behind a big Banner pops in
	             under the TopBar, a confetti burst fires from it, and it pops away after a few
	             seconds. Shown to everyone, clocked in or not. EventFxController handles the
	             world side; MusicController plays the fanfare.
	Props:
	- Preview: Optional intro ("Rush" | "Party" | "Extended" | "RushExtended") for stories. Shown at once and
	  replayed every few seconds.
	- PreviewBuyer: Optional buyer name for the Party/Extended preview.
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

local React = require(Packages.React)

local Styles = require(UI.Styles)
local CafeEvent = require(Shared.Utility.CafeEvent)
local RatingConfig = require(Shared.Configuration.RatingConfig)
local Banner = require(UI.Components.Buttons.Banner)
local BackgroundSpotlight = require(UI.Components.Decoration.BackgroundSpotlight)

---> Private

local c = React.createElement

local HOLD_SECONDS = 3.2
local POP_IN = TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local POP_OUT = TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.In)
local CONFETTI_COUNT = 70
local CONFETTI_COLORS = { Styles.GOLD, Styles.ROSE, Styles.GREEN_LIGHT, Styles.CORAL, Styles.CREAM, Styles.OFFWHITE }
local ORIGIN = Vector2.new(0.5, 0.3)

type Look = { Title: string, Subtitle: string, Color: Color3, Deep: Color3 }

local function lookFor(intro: CafeEvent.Intro, buyer: string?): Look
	local mult = RatingConfig.RUSH_PAY_MULT
	if intro == "Party" then
		return {
			Title = "BOBA PARTY!",
			Subtitle = if buyer
				then `{buyer} is throwing a party! \u{00D7}{mult} pay!`
				else `Party time! \u{00D7}{mult} pay for everyone!`,
			Color = Styles.ROSE_MID,
			Deep = Styles.ROSE_DEEP,
		}
	elseif intro == "Extended" then
		local minutes = math.floor(RatingConfig.BOBA_PARTY_EXTENSION_SECONDS / 60)
		return {
			Title = "PARTY EXTENDED!",
			Subtitle = if buyer then `+{minutes} minutes thanks to {buyer}!` else `+{minutes} minutes of party!`,
			Color = Styles.ROSE_MID,
			Deep = Styles.ROSE_DEEP,
		}
	end
	if intro == "RushExtended" then
		local minutes = math.floor(RatingConfig.RUSH_SECONDS / 60)
		return {
			Title = "RUSH EXTENDED!",
			Subtitle = if buyer then `+{minutes} minutes thanks to {buyer}!` else `+{minutes} minutes of rush!`,
			Color = Styles.GOLD_MID,
			Deep = Styles.GOLD_DEEP,
		}
	end
	return {
		Title = "RUSH HOUR!",
		Subtitle = if buyer
			then `{buyer} started a Rush Hour! \u{00D7}{mult} pay!`
			else `More customers! \u{00D7}{mult} pay!`,
		Color = Styles.GOLD_MID,
		Deep = Styles.GOLD_DEEP,
	}
end

-- One piece: flies out of the banner, then tumbles down off screen.
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

---> Component

return function(props: {
	Preview: CafeEvent.Intro?,
	PreviewBuyer: string?,
})
	local current, setCurrent = React.useState(nil :: { Intro: CafeEvent.Intro, Buyer: string?, Id: number }?)
	local scaleRef = React.useRef(nil)
	local layerRef = React.useRef(nil)
	local idRef = React.useRef(0)

	local function play(intro: CafeEvent.Intro, buyer: string?)
		idRef.current += 1
		setCurrent({ Intro = intro, Buyer = buyer, Id = idRef.current })
	end

	-- Unconditional (guard inside) so the hook count never varies.
	React.useEffect(function()
		if props.Preview ~= nil then
			play(props.Preview, props.PreviewBuyer)
			local alive = true
			task.spawn(function()
				while alive do
					task.wait(HOLD_SECONDS + 1.5)
					if alive then
						play(props.Preview, props.PreviewBuyer)
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
		local last = CafeEvent.read()
		return CafeEvent.observe(function(state)
			local intro = CafeEvent.introFor(last, state)
			last = state
			if intro ~= nil then
				play(intro, state.Buyer)
			end
		end)
	end, { props.Preview })

	-- Pop in, confetti, hold, pop out. A newer intro restarts the sequence.
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
		task.delay(HOLD_SECONDS, function()
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
			BackgroundTransparency = 1,
			ClipsDescendants = true,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 1,
			ref = layerRef,
		}),
	}

	if current ~= nil then
		local look = lookFor(current.Intro, current.Buyer)
		children.Card = c("Frame", {
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
					ImageColor3 = look.Color,
					ImageTransparency = 0.25,
					Position = UDim2.fromScale(0.5, 0.45),
					Size = UDim2.fromScale(1.3, 1.3),
					ZIndex = 0,
				},
			}),
			Title = c(Banner, {
				Text = look.Title,
				Color = look.Color,
				Position = UDim2.fromScale(0.5, 0.4),
				Size = UDim2.fromScale(1, 0.7),
			}),
			Subtitle = c("TextLabel", {
				AnchorPoint = Vector2.new(0.5, 0),
				BackgroundTransparency = 1,
				FontFace = Styles.FONT_FREDOKA,
				Position = UDim2.fromScale(0.5, 0.78),
				Size = UDim2.fromScale(0.9, 0.2),
				Text = look.Subtitle,
				TextColor3 = Styles.OFFWHITE,
				TextScaled = true,
				ZIndex = 11,
			}, {
				Stroke = c("UIStroke", { Color = look.Deep, Thickness = 2 }),
			}),
		})
	end

	return c("Frame", {
		Active = false,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 15,
	}, children)
end
