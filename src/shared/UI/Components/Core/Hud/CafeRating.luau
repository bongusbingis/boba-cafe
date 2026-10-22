--[[
    Component: CafeRating
    Description: Server-wide Cafe Rating meter (REVIVAL-001 M2-RATING, DEC-021). Sits top
                 centre directly under the TopBar time pod. Reads the CafeRating and
                 RushHour workspace attributes; hidden until the player is clocked in.
--]]

--!nonstrict

---> Services

local Players = game:GetService("Players")
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
local RatingConfig = require(Shared.Configuration.RatingConfig)
local Banner = require(UI.Components.Buttons.Banner)
local Pane = require(UI.Components.Pane)
local PromptButton = require(UI.Components.Buttons.PromptButton)
local UiSfx = require(UI.Utility.UiSfx)
local EventProducts = require(Shared.Utility.EventProducts)

---> Private

local c = React.createElement

local MAX_NAME_CHARS = 8
-- EVENT-FX: the banner bounces on the swing theme's beat while a Rush runs.
local PULSE = TweenInfo.new(0.35, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
local PULSE_SCALE = 1.08

-- D8: buyer name unchanged when 8 chars or fewer, else first 8 chars + "..".
local function shortName(name: string): string
	local len = utf8.len(name)
	if len ~= nil and len <= MAX_NAME_CHARS then
		return name
	end
	local cut = utf8.offset(name, MAX_NAME_CHARS + 1)
	if cut == nil then
		return name
	end
	return string.sub(name, 1, cut - 1) .. ".."
end

---> Component

return function(props: { CurrentPage: ModuleScript? })
	local rating, setRating = React.useState(50)
	local rush, setRush = React.useState(false)
	local clockedIn, setClockedIn = React.useState(true)
	local endsAt, setEndsAt = React.useState(nil)
	local party, setParty = React.useState(false)
	local buyer, setBuyer = React.useState(nil)
	local _tick, setTick = React.useState(0)
	local pulseRef = React.useRef(nil)
	local openingRef = React.useRef(false)

	if RunService:IsRunning() then
		React.useEffect(function()
			local player = Players.LocalPlayer
			local lastRush = workspace:GetAttribute("RushHour") == true
			local function refresh()
				local rushNow = workspace:GetAttribute("RushHour") == true
				if rushNow and not lastRush and player:GetAttribute("ClockedIn") ~= false then
					UiSfx.Play("Rush")
				end
				lastRush = rushNow
				local value = workspace:GetAttribute("CafeRating")
				setRating(if typeof(value) == "number" then value else 50)
				setRush(workspace:GetAttribute("RushHour") == true)
				local ends = workspace:GetAttribute("RushEndsAt")
				setEndsAt(if typeof(ends) == "number" then ends else nil)
				setParty(workspace:GetAttribute("BobaParty") == true)
				local buyerNow = workspace:GetAttribute("BobaPartyBuyer")
				setBuyer(if typeof(buyerNow) == "string" then buyerNow else nil)
				setClockedIn(player:GetAttribute("ClockedIn") ~= false)
			end
			refresh()
			local conns = {
				workspace:GetAttributeChangedSignal("CafeRating"):Connect(refresh),
				workspace:GetAttributeChangedSignal("RushHour"):Connect(refresh),
				workspace:GetAttributeChangedSignal("RushEndsAt"):Connect(refresh),
				workspace:GetAttributeChangedSignal("BobaParty"):Connect(refresh),
				workspace:GetAttributeChangedSignal("BobaPartyBuyer"):Connect(refresh),
				player:GetAttributeChangedSignal("ClockedIn"):Connect(refresh),
			}
			return function()
				for _, conn in conns do
					conn:Disconnect()
				end
			end
		end, {})
	end

	local hasCountdown = rush and endsAt ~= nil
	if RunService:IsRunning() then
		React.useEffect(function()
			if not hasCountdown then
				return nil
			end
			local alive = true
			task.spawn(function()
				while alive do
					task.wait(1)
					if alive then
						setTick(function(n)
							return n + 1
						end)
					end
				end
			end)
			return function()
				alive = false
			end
		end, { rush, endsAt })
	end

	-- Unconditional (guard inside); the pulse frame is only mounted while clocked in.
	React.useEffect(function()
		local scale: UIScale? = pulseRef.current
		if not rush or scale == nil then
			return nil
		end
		scale.Scale = 1
		local tween = TweenService:Create(scale, PULSE, { Scale = PULSE_SCALE })
		tween:Play()
		return function()
			tween:Cancel()
			scale.Scale = 1
		end
	end, { rush, clockedIn })

	if not clockedIn then
		return nil
	end

	-- Tap the meter: choose Boba Party or Rush Hour (live prices, ButtonPrompt via DialogController).
	local function openBuyChoice()
		if openingRef.current then
			return
		end
		openingRef.current = true
		task.spawn(function()
			local prices = EventProducts.fetchPrices()
			local buttons = {}
			local byText = {}
			local lines = {}
			for _, product in EventProducts.Products do
				if EventProducts.available(product) then
					local price = prices[product.Key]
					local text = if price then `{product.Name} \u{e002} {price}` else product.Name
					table.insert(buttons, { Text = text, Color = Styles.GREEN })
					byText[text] = product
					table.insert(lines, `{product.Name}: {product.Blurb}.`)
				end
			end
			if EventProducts.partyOnCooldown() then
				local left = math.max(
					0,
					math.ceil(workspace:GetAttribute("BobaPartyCooldownEndsAt") - workspace:GetServerTimeNow())
				)
				table.insert(
					lines,
					string.format("Boba Party is available again in %d:%02d.", math.floor(left / 60), left % 60)
				)
			end
			table.insert(lines, "Buying during an event adds time!")
			table.insert(buttons, { Text = "Cancel", Color = Styles.RED })
			local ok, dialog = pcall(function()
				return Knit.GetController("DialogController").new("ButtonPrompt", {
					Title = "Cafe Event",
					Text = table.concat(lines, " "),
					Buttons = buttons,
				})
			end)
			if not ok then
				openingRef.current = false
				return
			end
			dialog:Fire():andThen(function(choice)
				openingRef.current = false
				local product = byText[choice]
				if product ~= nil then
					EventProducts.prompt(product)
				end
			end)
		end)
	end

	local remaining = 0
	if hasCountdown then
		remaining = math.ceil(endsAt - workspace:GetServerTimeNow())
	end
	local bannerText = "Cafe Rating"
	if rush then
		if party and typeof(buyer) == "string" then
			bannerText = `{shortName(buyer)}'s Party!`
		elseif party then
			bannerText = "Boba Party!"
		else
			bannerText = "Rush Hour!"
		end
		if remaining > 0 then
			bannerText ..= string.format(" %d:%02d", math.floor(remaining / 60), remaining % 60)
		end
	end

	-- UI-REVISION: during a Rush the rating is frozen, so the bar shows the Rush
	-- itself instead of a stale percentage: it drains with the time left and
	-- reads the pay boost.
	local alpha = math.clamp(rating / 100, 0, 1)
	local color = if party then Styles.ROSE_MID elseif rush then Styles.GOLD_MID else Styles.GREEN
	local deep = if party then Styles.ROSE_DEEP elseif rush then Styles.GOLD_DEEP else Styles.GREEN_DEEP
	local barText = `{math.floor(rating + 0.5)}%`
	if rush then
		local total = if party then RatingConfig.BOBA_PARTY_SECONDS else RatingConfig.RUSH_SECONDS
		alpha = if hasCountdown then math.clamp(remaining / math.max(1, total), 0, 1) else 1
		barText = `\u{00D7}{RatingConfig.RUSH_PAY_MULT} pay`
	end

	return c(Pane, {
		ClassName = "Frame",
		AspectRatio = 5,
		Native = {
			Active = false,
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0.5, 0.115),
			Size = UDim2.fromScale(0.2, 0.08),
			ZIndex = 10,
		},
	}, {
		UISizeConstraint = c("UISizeConstraint", {
			MaxSize = Vector2.new(300, 60),
			MinSize = Vector2.new(190, 38),
		}),

		Track = c("Frame", {
			AnchorPoint = Vector2.new(0.5, 1),
			BackgroundColor3 = Styles.OFFWHITE,
			BorderSizePixel = 0,
			Position = UDim2.fromScale(0.5, 1),
			Size = UDim2.fromScale(0.9, 0.38),
		}, {
			Corner = c("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
			Fill = c("Frame", {
				BackgroundColor3 = color,
				BorderSizePixel = 0,
				Size = UDim2.fromScale(alpha, 1),
			}, {
				Corner = c("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
			}),
			Percent = c("TextLabel", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				FontFace = Styles.FONT_FREDOKA,
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(0.5, 0.8),
				Text = barText,
				TextColor3 = deep,
				TextScaled = true,
				ZIndex = 2,
			}),
		}),

		-- Visible buy entry point under the meter (the meter itself stays non-interactive).
		BuyEvent = c("Frame", {
			Visible = props.CurrentPage == nil,
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0.5, 1.08),
			Size = UDim2.fromScale(0.5, 0.6),
			ZIndex = 10,
		}, {
			Button = c(PromptButton, {
				Text = if rush then "Add Time!" else "Start a Rush!",
				Color = if party then Styles.ROSE_MID elseif rush then Styles.GOLD_MID else Styles.GREEN,
				Size = UDim2.fromScale(1, 1),
				OnClick = openBuyChoice,
			}),
		}),

		Pulse = c("Frame", {
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0.5, 0),
			Size = UDim2.fromScale(1, 1),
			ZIndex = 10,
		}, {
			Scale = c("UIScale", { ref = pulseRef }),
			Title = c(Banner, {
				Text = bannerText,
				Color = color,
				Position = UDim2.fromScale(0.5, 0.3),
				Size = UDim2.fromScale(0.85, 0.65),
			}),
		}),
	})
end
