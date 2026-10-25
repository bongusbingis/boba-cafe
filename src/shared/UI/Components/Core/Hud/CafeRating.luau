--[[
    Component: CafeRating
    Description: Server-wide Cafe Rating meter & Rush Event entry point (REVIVAL-001 M2-RATING, DEC-021),
                 restyled to Jack's Studio design (2026-10-23): slice-scaled pod hanging under the TopBar
                 base, "Cafe Rating" label above a light track, green fill + percent, and a GOLD_MID
                 "+ Rush" / "+ Time" button on the right. Reads CafeRating, RushHour, BobaParty workspace
                 attributes. During Rush Hour / Boba Party the label becomes the event banner + countdown,
                 the fill recolors (GOLD_MID / ROSE_MID) and shows "x2 pay", and the button becomes "+ Time".
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
local Pane = require(UI.Components.Pane)
local UiSfx = require(UI.Utility.UiSfx)
local EventProducts = require(Shared.Utility.EventProducts)

---> Private

local c = React.createElement

local MAX_NAME_CHARS = 8
-- EVENT-FX: the buy button pulses on the swing theme's beat while a Rush runs.
local PULSE = TweenInfo.new(0.35, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
local PULSE_SCALE = 1.08

-- Jack's Studio design colors: the track is a light gray, not a Styles token
-- (approved by Jack in the provided design). The button gold is Styles.GOLD_MID.
local TRACK_GRAY = Color3.fromRGB(225, 225, 225)

-- Buyer name truncated with ".." if longer than MAX_NAME_CHARS.
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

return function()
	local rating, setRating = React.useState(50)
	local rush, setRush = React.useState(false)
	local endsAt, setEndsAt = React.useState(nil)
	local party, setParty = React.useState(false)
	local buyer, setBuyer = React.useState(nil)
	local _tick, setTick = React.useState(0)
	local pulseRef = React.useRef(nil)
	local openingRef = React.useRef(false)

	React.useEffect(function()
		if not RunService:IsRunning() then
			return nil
		end
		local player = Players.LocalPlayer
		local lastRush = workspace:GetAttribute("RushHour") == true
		local function refresh()
			local rushNow = workspace:GetAttribute("RushHour") == true
			if rushNow and not lastRush and (not player or player:GetAttribute("ClockedIn") ~= false) then
				UiSfx.Play("Rush")
			end
			lastRush = rushNow
			local value = workspace:GetAttribute("CafeRating")
			setRating(if typeof(value) == "number" then value else 50)
			setRush(rushNow)
			local ends = workspace:GetAttribute("RushEndsAt")
			setEndsAt(if typeof(ends) == "number" then ends else nil)
			local partyNow = workspace:GetAttribute("BobaParty") == true
			setParty(partyNow)
			local partyBuyer = workspace:GetAttribute("BobaPartyBuyer")
			local rushBuyer = workspace:GetAttribute("RushHourBuyer")
			local buyerNow = if partyNow then partyBuyer else rushBuyer
			setBuyer(if typeof(buyerNow) == "string" then buyerNow else nil)
		end
		refresh()
		local conns = {
			workspace:GetAttributeChangedSignal("CafeRating"):Connect(refresh),
			workspace:GetAttributeChangedSignal("RushHour"):Connect(refresh),
			workspace:GetAttributeChangedSignal("RushEndsAt"):Connect(refresh),
			workspace:GetAttributeChangedSignal("BobaParty"):Connect(refresh),
			workspace:GetAttributeChangedSignal("BobaPartyBuyer"):Connect(refresh),
			workspace:GetAttributeChangedSignal("RushHourBuyer"):Connect(refresh),
		}
		return function()
			for _, conn in conns do
				conn:Disconnect()
			end
		end
	end, {})

	local hasCountdown = rush and endsAt ~= nil
	React.useEffect(function()
		if not RunService:IsRunning() or not hasCountdown then
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

	-- Pulse animation for the button during Rush Hour
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
	end, { rush })

	-- Open event choice dialog (live prices, ButtonPrompt via DialogController).
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
		remaining = math.max(0, math.ceil(endsAt - workspace:GetServerTimeNow()))
	end
	local bannerText = "Cafe Rating"
	if rush then
		if party and typeof(buyer) == "string" then
			bannerText = `{shortName(buyer)}'s Party!`
		elseif party then
			bannerText = "Boba Party!"
		elseif typeof(buyer) == "string" then
			bannerText = `{shortName(buyer)}'s Rush!`
		else
			bannerText = "Rush Hour!"
		end
		if remaining > 0 then
			bannerText ..= string.format(" %d:%02d", math.floor(remaining / 60), remaining % 60)
		end
	end

	local alpha = math.clamp(rating / 100, 0, 1)
	local color = if party then Styles.ROSE_MID elseif rush then Styles.GOLD_MID else Styles.GREEN
	local barText = `{math.floor(rating + 0.5)}%`
	if rush then
		local total = if party then RatingConfig.BOBA_PARTY_SECONDS else RatingConfig.RUSH_SECONDS
		alpha = if hasCountdown then math.clamp(remaining / math.max(1, total), 0, 1) else 1
		barText = `\u{00D7}{RatingConfig.RUSH_PAY_MULT} pay`
	end

	local btnText = if rush then "+ Time" else "+ Rush"
	local btnColor = if party then Styles.ROSE_MID else Styles.GOLD_MID

	return c(Pane, {
		ClassName = "ImageLabel",
		Native = {
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundTransparency = 1,
			Image = "http://www.roblox.com/asset/?id=13407992271",
			ImageColor3 = Styles.GREEN,
			Position = UDim2.fromScale(0.5, 0.327),
			ScaleType = Enum.ScaleType.Slice,
			Size = UDim2.fromScale(0.509847, 1.04717),
			SliceCenter = Rect.new(68, 73, 332, 90),
			SliceScale = 0.35,
		},
	}, {
		Border = c(Pane, {
			ClassName = "ImageLabel",
			Native = {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Image = "http://www.roblox.com/asset/?id=13408001982",
				ImageColor3 = Styles.OFFWHITE,
				Position = UDim2.fromScale(0.5, 0.281037),
				ScaleType = Enum.ScaleType.Slice,
				Size = UDim2.new(1, 5, 1.43793, 5),
				SliceCenter = Rect.new(68, 73, 332, 90),
				SliceScale = 0.35,
			},
		}),

		Inner = c("Frame", {
			AnchorPoint = Vector2.new(0.5, 1),
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0.5, 0.94),
			Size = UDim2.new(0.91, 0, 0.013, 22),
			ZIndex = 3,
		}, {
			Track = c("Frame", {
				BackgroundColor3 = TRACK_GRAY,
				BorderSizePixel = 0,
				LayoutOrder = 2,
				Size = UDim2.fromScale(0.723279, 0.8),
				ZIndex = 3,
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
					Size = UDim2.fromScale(0.95, 0.9),
					Text = barText,
					TextColor3 = Color3.fromRGB(48, 62, 44),
					TextScaled = true,
					ZIndex = 4,
				}),
				Tap = c("TextButton", {
					BackgroundTransparency = 1,
					Size = UDim2.fromScale(1, 1),
					Text = "",
					ZIndex = 5,
					[React.Event.Activated] = openBuyChoice,
				}),
				Stroke = c("UIStroke", {
					Color = Color3.new(1, 1, 1),
					StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
					Thickness = 0.15,
				}),
			}),

			BuyBtn = c("TextButton", {
				BackgroundColor3 = btnColor,
				BorderSizePixel = 0,
				FontFace = Styles.FONT_FREDOKA,
				LayoutOrder = 3,
				Position = UDim2.fromScale(0.752034, -0.133444),
				Size = UDim2.fromScale(0.254583, 1.02046),
				Text = btnText,
				TextColor3 = Styles.OFFWHITE,
				TextScaled = true,
				ZIndex = 3,
				[React.Event.Activated] = openBuyChoice,
			}, {
				Corner = c("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
				Scale = c("UIScale", { ref = pulseRef }),
				Padding = c("UIPadding", {
					PaddingLeft = UDim.new(0, 4),
					PaddingRight = UDim.new(0, 4),
				}),
			}),
		}),

		Label = c("TextLabel", {
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 1,
			FontFace = Styles.FONT_FREDOKA,
			LayoutOrder = 1,
			Position = UDim2.fromScale(0.045, 0.18),
			Size = UDim2.fromScale(0.65, 0.38),
			Text = bannerText,
			TextColor3 = Styles.OFFWHITE,
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 3,
		}, {
			Constraint = c("UITextSizeConstraint", {
				MaxTextSize = 20,
				MinTextSize = 10,
			}),
		}),
	})
end
