--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = Shared:WaitForChild("UI")

local React = require(Packages.React)
local Knit = require(Packages.Knit)
local Styles = require(UI.Styles)
local WorldPath = require(Shared.Utility.WorldPath)
local DailyRewardConfig = require(Shared.Configuration.DailyRewardConfig)

local PromptButton = require(UI.Components.Buttons.PromptButton)
local ShopItem = require(UI.Components.Buttons.ShopItem)
local usePx = require(UI.Hooks.usePx)
local PassUpsell = require(UI.Utility.PassUpsell)

local c = React.createElement

local BUTTON_HEIGHT = 50

-- UI sounds are authored in the place (SoundService.SFX.UI, else SoundService.UISounds).
-- A missing sound is skipped.
local function playUiSound(name: string)
	local sound = WorldPath.find(SoundService, { "SFX", "UI", name })
		or WorldPath.find(SoundService, { "UISounds", name })
		or WorldPath.find(SoundService, { "SFX", name })
	if sound and sound:IsA("Sound") then
		sound:Play()
	end
end

local function formatCountdown(totalSeconds: number): string
	totalSeconds = math.max(0, math.floor(totalSeconds))
	local hours = math.floor(totalSeconds / 3600)
	local minutes = math.floor((totalSeconds % 3600) / 60)
	local seconds = totalSeconds % 60
	if hours > 0 then
		return string.format("%02d:%02d:%02d", hours, minutes, seconds)
	else
		return string.format("%02d:%02d", minutes, seconds)
	end
end

local function DailyRewardsBody(props: { Status: { [string]: any }? })
	local px = usePx()
	local status, setStatus = React.useState(props.Status)
	local isClaiming, setIsClaiming = React.useState(false)
	-- UPSELL lane 2: the VIP line shows only after a claim made in this dialog.
	local justClaimed, setJustClaimed = React.useState(false)
	local vipClicked, setVipClicked = React.useState(false)
	local vipPrice = PassUpsell.usePrice(PassUpsell.VIP)

	-- Sync status if props.Status changes
	React.useEffect(function()
		if props.Status then
			setStatus(props.Status)
		end
	end, { props.Status })

	-- If no status passed, query DailyRewardService on mount
	React.useEffect(function()
		if not status and RunService:IsRunning() then
			local ok, service = pcall(function()
				return Knit.GetService("DailyRewardService")
			end)
			if ok and service then
				service
					:GetRewardStatus()
					:andThen(function(latestStatus)
						if latestStatus then
							setStatus(latestStatus)
						end
					end)
					:catch(function(err)
						warn("[DailyRewardsDialog] Failed to fetch reward status:", err)
					end)
			end
		end
	end, {})

	-- Fallback status for offline preview / specs
	local currentStatus = status
		or {
			CanClaim = true,
			DayToClaim = 1,
			SecondsUntilNextClaim = 0,
			Expired = false,
			CurrentStreak = 0,
			LastClaimTime = 0,
			IsVIP = false,
			Reward = DailyRewardConfig.REWARDS[1],
			DataLoaded = true,
		}

	local secondsLeft, setSecondsLeft = React.useState(function()
		return currentStatus.SecondsUntilNextClaim or 0
	end)

	React.useEffect(function()
		if currentStatus then
			setSecondsLeft(currentStatus.SecondsUntilNextClaim or 0)
		end
	end, { currentStatus })

	-- Cooldown countdown timer
	React.useEffect(function()
		if not currentStatus or currentStatus.CanClaim or secondsLeft <= 0 then
			return
		end

		local running = true
		task.spawn(function()
			while running and secondsLeft > 0 do
				task.wait(1)
				if not running then
					break
				end
				setSecondsLeft(function(prev)
					if prev <= 1 then
						-- Cooldown expired; refresh status from server
						if RunService:IsRunning() then
							task.spawn(function()
								local ok, service = pcall(function()
									return Knit.GetService("DailyRewardService")
								end)
								if ok and service then
									local sOk, sStatus = service:GetRewardStatus():await()
									if sOk and sStatus then
										setStatus(sStatus)
									end
								end
							end)
						end
						return 0
					end
					return prev - 1
				end)
			end
		end)

		return function()
			running = false
		end
	end, { currentStatus.CanClaim, secondsLeft > 0 })

	local function handleClaim()
		if isClaiming or not currentStatus.CanClaim then
			return
		end
		setIsClaiming(true)

		if not RunService:IsRunning() then
			-- Offline / story preview mode
			setIsClaiming(false)
			playUiSound("Success")
			setStatus(function(prev)
				local s = prev or currentStatus
				local nextStreak = s.DayToClaim
				return {
					CanClaim = false,
					DayToClaim = (nextStreak % 7) + 1,
					SecondsUntilNextClaim = DailyRewardConfig.CLAIM_COOLDOWN_SECONDS,
					CurrentStreak = nextStreak,
					LastClaimTime = os.time(),
					IsVIP = s.IsVIP,
					Reward = DailyRewardConfig.REWARDS[(nextStreak % 7) + 1],
					DataLoaded = true,
				}
			end)
			return
		end

		task.spawn(function()
			local ok, service = pcall(function()
				return Knit.GetService("DailyRewardService")
			end)
			if not ok or not service then
				setIsClaiming(false)
				return
			end

			-- Knit promise :await() yields (promiseOk, claimOk, reason, grantResult).
			local promiseOk, claimOk, reason, grantResult = service:ClaimReward():await()
			setIsClaiming(false)

			if promiseOk and claimOk then
				playUiSound("Success")
				setJustClaimed(true)

				setStatus(function(prev)
					local prevStatus = prev or currentStatus
					local nextStreak = grantResult and grantResult.Streak or prevStatus.DayToClaim
					return {
						CanClaim = false,
						DayToClaim = (nextStreak % 7) + 1,
						SecondsUntilNextClaim = DailyRewardConfig.CLAIM_COOLDOWN_SECONDS,
						CurrentStreak = nextStreak,
						LastClaimTime = os.time(),
						IsVIP = prevStatus.IsVIP,
						Reward = DailyRewardConfig.REWARDS[(nextStreak % 7) + 1],
						DataLoaded = true,
					}
				end)
			else
				warn("[DailyRewardsDialog] Claim failed:", if promiseOk then reason else claimOk)
				-- The claim stays available: status is untouched on a refused claim.
				local toastText = "Couldn't claim right now - try again in a moment."
				if promiseOk and reason == "InventoryFull" then
					toastText = "Your capsule inventory is full - make room to claim today's reward!"
				end
				local okController, dialogController = pcall(function()
					return Knit.GetController("DialogController")
				end)
				if okController and dialogController and dialogController.Toast then
					dialogController:Toast(toastText)
				end
			end
		end)
	end

	local canClaim = currentStatus.CanClaim == true
	local dayToClaim = currentStatus.DayToClaim or 1
	local streak = currentStatus.CurrentStreak or 0
	local isVIP = currentStatus.IsVIP == true
	local vipMultiplier = if isVIP then DailyRewardConfig.VIP_MULTIPLIER else 1

	-- Determine subtitle message
	local subtitleText
	if canClaim then
		subtitleText =
			`Streak: {streak} {if streak == 1 then "Day" else "Days"} • Claim today's Day {dayToClaim} reward!`
	elseif secondsLeft > 0 then
		subtitleText =
			`Streak: {streak} {if streak == 1 then "Day" else "Days"} • Next reward in {formatCountdown(secondsLeft)}`
	else
		subtitleText = `Streak: {streak} {if streak == 1 then "Day" else "Days"} • 7-Day Cycle Complete!`
	end

	-- Build the seven reward rows (one ShopItem per day)
	local rows: { [string]: any } = {}
	for day = 1, 7 do
		local reward = DailyRewardConfig.REWARDS[day]
		local bucksAmount = if reward then reward.BobaBucks * vipMultiplier else 0
		local capsuleName = if reward then reward.Capsule else nil

		-- Status logic
		local isClaimed = false
		local isCurrent = false

		if canClaim then
			if day < dayToClaim then
				isClaimed = true
			elseif day == dayToClaim then
				isCurrent = true
			end
		elseif (streak > 0 and (streak % 7 == 0)) or day <= (streak % 7) then
			isClaimed = true
		end

		local label = `Day {day}: {bucksAmount} Boba Bucks`
		if capsuleName then
			label ..= ` + {if day == 4 then "Regular Capsule" else "Rare Capsule"}`
		end
		if isClaimed then
			label = `✓ {label}`
		elseif isCurrent then
			label ..= " - Claim now!"
		end

		rows[`Day_{day}`] = c(ShopItem, {
			Label = label,
			Color = if isClaimed then Styles.GREEN_LIGHT elseif isCurrent then Styles.GOLD_MID else Styles.GRAY,
			LayoutOrder = day,
			OnClick = if isCurrent and canClaim then handleClaim else nil,
		})
	end

	rows.UIListLayout = c("UIListLayout", {
		Padding = UDim.new(0, px(3)),
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
	rows.BottomSpacer = c("Frame", {
		BackgroundTransparency = 1,
		LayoutOrder = 9999,
		Size = UDim2.new(1, 0, 0, px(20)),
		Visible = true,
	})

	-- The claimed day is the streak position (1-7); its reward is the value the row shows.
	local claimedDay = if streak > 0 then ((streak - 1) % 7) + 1 else nil
	local claimedReward = if claimedDay then DailyRewardConfig.REWARDS[claimedDay] else nil
	local showVipUpsell = justClaimed
		and not canClaim
		and not isVIP
		and not vipClicked
		and vipPrice ~= nil
		and claimedReward ~= nil

	local hintText = if isVIP then `{subtitleText} • 2x VIP` else subtitleText

	local rewardsTab = c("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
	}, {
		Title = c("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundTransparency = 1,
			FontFace = Styles.FONT_FREDOKA,
			Position = UDim2.fromScale(0.470149, 0),
			Size = UDim2.fromScale(0.94, 0.09),
			Text = "7-Day Rewards",
			TextColor3 = Styles.GREEN,
			TextScaled = true,
		}),

		Hint = c("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundTransparency = 1,
			FontFace = Styles.FONT_FREDOKA,
			Position = UDim2.fromScale(0.5, 0.095),
			Size = UDim2.fromScale(0.94, 0.085),
			Text = hintText,
			TextColor3 = Styles.GRAY,
			TextScaled = true,
		}),

		Rewards = c("ScrollingFrame", {
			Active = true,
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			CanvasSize = UDim2.new(),
			Position = UDim2.fromScale(0, 0.2),
			ScrollBarImageColor3 = Color3.new(),
			ScrollBarThickness = 5,
			ScrollingDirection = Enum.ScrollingDirection.Y,
			Size = if showVipUpsell then UDim2.new(1, 0, 0.64, -px(BUTTON_HEIGHT - 4)) else UDim2.fromScale(1, 0.64),
		}, rows),

		VipUpsell = if showVipUpsell
			then c(PassUpsell.Row, {
				Text = `VIP would have given you {DailyRewardConfig.VIP_MULTIPLIER}x ({claimedReward.BobaBucks} BB)`,
				ButtonText = `Get VIP {PassUpsell.PriceText(vipPrice)}`,
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new(0.5, 0, 0.98, -(px(BUTTON_HEIGHT) + px(6))),
				Size = UDim2.new(0.94, 0, 0, px(BUTTON_HEIGHT - 6)),
				OnClick = function()
					setVipClicked(true)
					PassUpsell.Prompt(PassUpsell.VIP)
				end,
			})
			else nil,

		BottomBar = c("Frame", {
			AnchorPoint = Vector2.new(0.5, 1),
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0.5, 0.98),
			Size = UDim2.new(0.6, 0, 0, px(BUTTON_HEIGHT)),
		}, {
			ClaimButton = if canClaim
				then c(PromptButton, {
					Text = `Claim Day {dayToClaim} Reward`,
					Color = Styles.GREEN,
					Size = UDim2.fromScale(1, 1),
					OnClick = handleClaim,
				})
				else c(PromptButton, {
					Text = if secondsLeft > 0 then `Next in {formatCountdown(secondsLeft)}` else "All Claimed!",
					Color = Styles.GRAY,
					Disabled = true,
					Size = UDim2.fromScale(1, 1),
				}),
		}),
	})

	return rewardsTab
end

return DailyRewardsBody
