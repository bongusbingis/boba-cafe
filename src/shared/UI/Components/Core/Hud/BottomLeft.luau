--[[
	Hud
	Renders groups of Hud buttons used for opening/closing page components.
	Props:
	- CurrentPage: ModuleScript currently selected.
	- SetCurrentPage: Callback to update the selected page (ModuleScript or nil).
]]

--!nonstrict
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = Shared:WaitForChild("UI")

---> dependencies
local Knit = require(Packages.Knit)
local React = require(Packages.React)

---> constants
local SKIP_HATCH_PRODUCT_ID = 1143554452
local HATCH_DURATION_SECONDS = 15 * 60

---> styles
local Styles = require(UI.Styles)

---> components
local Pane = require(UI.Components.Pane)
local NormalButton = require(UI.Components.Buttons.NormalButton)

---> private
local c = React.createElement

local function extractTimeLeft(s: string)
	local t: {} = s:split(":")
	local minutes: string = t[1]
	local seconds: string = t[2]
	local minutesNum = tonumber(minutes) or 0
	local secondsNum = tonumber(seconds) or 0
	return minutesNum * 60 + secondsNum
end
	
local function formatClock(totalSeconds: number)
	totalSeconds = math.max(0, totalSeconds)
	local minutes = math.floor(totalSeconds / 60)
	local seconds = totalSeconds % 60
	return string.format("%02d:%02d", minutes, seconds)
end

return function(props: {
	CurrentPage: ModuleScript,
	SetCurrentPage: (pageComponent: ModuleScript | nil, ...any) -> (),
})
	local currency, setCurrency = React.useState({
		BobaBucks = 0,
		Points = 0,
	})

	local capsuleHatching, setCapsuleHatching = React.useState(nil)
	local hatchClockText, setHatchClockText = React.useState("00:00")
	local requestedReadyHatchRef = React.useRef(false)

	React.useEffect(function()
		if not capsuleHatching or capsuleHatching == false then
			setHatchClockText("00:00")
			requestedReadyHatchRef.current = false
			return
		end

		local baseAccumulated = 0
		if typeof(capsuleHatching) == "table" and capsuleHatching.TimeAccumulated then
			baseAccumulated = capsuleHatching.TimeAccumulated
		end

		local function updateClock(elapsedInSession: number)
			local remaining = HATCH_DURATION_SECONDS - (baseAccumulated + elapsedInSession)
			setHatchClockText(formatClock(remaining))

			if remaining <= 0 and not requestedReadyHatchRef.current then
				requestedReadyHatchRef.current = true
				setCapsuleHatching(false)
				Knit.GetService("CapsuleService"):TryCompleteReadyHatch()
			end
		end

		updateClock(0)

		local this = task.spawn(function()
			local elapsedInSession = 0
			while true do
				elapsedInSession += 1
				updateClock(elapsedInSession)
				task.wait(1)
			end
		end)

		return function()
			task.cancel(this)
		end
	end, { capsuleHatching })

	if RunService:IsRunning() then
		React.useEffect(function()
			Knit.GetController("DataController"):GetDataAsync():andThen(function(playerData)
				setCurrency(playerData.Currency)

				local currentHatching = playerData.HatchingPet
				if currentHatching and currentHatching ~= false then
					setCapsuleHatching(currentHatching)
				end

				-- task.spawn(function()
				-- 	while true do
				-- 		task.wait(1)
				-- 		if playerData.HatchingPet ~= false then
				-- 			setCapsuleHatching(playerData.HatchingPet)
				-- 		end
				-- 	end
				-- end)

				playerData:ListenToChange({"HatchingPet"}, function(newValue)
					setCapsuleHatching(newValue or false)
				end)

				playerData:ListenToChange({ "HatchingPet", "TimeAccumulated" }, function(newTimeAccumulated)
					if playerData.HatchingPet and playerData.HatchingPet ~= false then
						local current = playerData.HatchingPet
						setCapsuleHatching({
							CapsuleName = current.CapsuleName,
							TimeAccumulated = newTimeAccumulated,
						})
					end
				end)

				for type, _ in playerData.Currency do
					playerData:ListenToChange({ "Currency", type }, function(newValue: number)
						setCurrency(function(prev)
							local new = table.clone(prev)
							new[type] = newValue
							return new
						end)
					end)
				end
			end)
		end, {})
	end

	return c(Pane, {
		ClassName = "Frame",
		Native = {
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0.025, 0.981),
			Size = UDim2.new(0, 300, 0.3, 0),
		},
		ListLayout = {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			VerticalAlignment = Enum.VerticalAlignment.Bottom,
			Padding = UDim.new(0.02, 0),
			SortOrder = Enum.SortOrder.LayoutOrder,
		},
	}, {
		capsuleHatching and c(Pane, {
			ClassName = "ImageButton",
			AspectRatio = 1,
			OnClick = function()
				if extractTimeLeft(hatchClockText) <= 30 then
					return
				end
				MarketplaceService:PromptProductPurchase(Players.LocalPlayer, SKIP_HATCH_PRODUCT_ID)
			end,
			Native = {
				Image = "rbxassetid://6073658218",
				LayoutOrder = 2,
				Size = UDim2.fromScale(0.4, 0.4),
			},
		}, {
			c("TextLabel", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				FontFace = Styles.FONT_FREDOKA,
				Position = UDim2.fromScale(0.5, 0.725),
				Size = UDim2.fromScale(0.85, 0.3),
				Text = hatchClockText,
				TextScaled = true,
				TextColor3 = Styles.OFFWHITE,
				ZIndex = 2,
			}, {
				UIStroke = c("UIStroke", {
					Color = Color3.new(0, 0, 0),
					Thickness = 2,
				}),
			}),
		}),

		c(Pane, {
			ClassName = "Frame",
			ListLayout = {
				Padding = UDim.new(0.03, 0),
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				VerticalAlignment = Enum.VerticalAlignment.Bottom,
			},
			Native = {
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.fromScale(0, 1),
				Size = UDim2.fromScale(0.5, 1),
				BackgroundTransparency = 1,
				LayoutOrder = 1,
			},
		}, {
			Bucks = c(NormalButton, {
				PlusButton = true,
				Icon = "rbxassetid://13382286492",
				Color = Styles.GREEN_LIGHT,
				Text = currency.BobaBucks,
				OnClick = function()
					props.SetCurrentPage(UI.Pages.Shop, "Currency")
				end,
			}),

			Points = c(NormalButton, {
				PlusButton = true,
				Icon = "rbxassetid://13391365805",
				Color = Styles.CORAL,
				Text = currency.Points,
				OnClick = function()
					props.SetCurrentPage(UI.Pages.Shop, "Currency")
				end,
			}),
		}),
	})
end
