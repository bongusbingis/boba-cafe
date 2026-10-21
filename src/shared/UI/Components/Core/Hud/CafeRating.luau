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

---> Dependencies

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = Shared:WaitForChild("UI")

local React = require(Packages.React)

local Styles = require(UI.Styles)
local Banner = require(UI.Components.Buttons.Banner)
local Pane = require(UI.Components.Pane)

---> Private

local c = React.createElement

---> Component

return function()
	local rating, setRating = React.useState(50)
	local rush, setRush = React.useState(false)
	local clockedIn, setClockedIn = React.useState(true)
	local endsAt, setEndsAt = React.useState(nil)
	local party, setParty = React.useState(false)
	local _tick, setTick = React.useState(0)

	if RunService:IsRunning() then
		React.useEffect(function()
			local player = Players.LocalPlayer
			local function refresh()
				local value = workspace:GetAttribute("CafeRating")
				setRating(if typeof(value) == "number" then value else 50)
				setRush(workspace:GetAttribute("RushHour") == true)
				local ends = workspace:GetAttribute("RushEndsAt")
				setEndsAt(if typeof(ends) == "number" then ends else nil)
				setParty(workspace:GetAttribute("BobaParty") == true)
				setClockedIn(player:GetAttribute("ClockedIn") ~= false)
			end
			refresh()
			local conns = {
				workspace:GetAttributeChangedSignal("CafeRating"):Connect(refresh),
				workspace:GetAttributeChangedSignal("RushHour"):Connect(refresh),
				workspace:GetAttributeChangedSignal("RushEndsAt"):Connect(refresh),
				workspace:GetAttributeChangedSignal("BobaParty"):Connect(refresh),
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

	if not clockedIn then
		return nil
	end

	local remaining = 0
	if hasCountdown then
		remaining = math.ceil(endsAt - workspace:GetServerTimeNow())
	end
	local bannerText = "Cafe Rating"
	if rush then
		bannerText = if party then "Boba Party!" else "Rush Hour!"
		if remaining > 0 then
			bannerText ..= string.format(" %d:%02d", math.floor(remaining / 60), remaining % 60)
		end
	end

	local alpha = math.clamp(rating / 100, 0, 1)

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
				BackgroundColor3 = Styles.GREEN,
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
				Text = `{math.floor(rating + 0.5)}%`,
				TextColor3 = Styles.GREEN_DEEP,
				TextScaled = true,
				ZIndex = 2,
			}),
		}),

		Title = c(Banner, {
			Text = bannerText,
			Color = Styles.GREEN,
			Position = UDim2.fromScale(0.5, 0.3),
			Size = UDim2.fromScale(0.7, 0.55),
		}),
	})
end
