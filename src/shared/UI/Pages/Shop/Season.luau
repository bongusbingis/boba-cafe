local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = Shared:WaitForChild("UI")

---> dependencies
local React = require(Packages.React)
local Knit = require(Packages.Knit)

---> configuration
local ProductIds = require(Shared.Configuration.ProductIds)
local SeasonConfig = require(Shared.Configuration.SeasonConfig)

---> styles
local Styles = require(UI.Styles)

---> components
local Pane = require(UI.Components.Pane)
local PromptButton = require(UI.Components.Buttons.PromptButton)
local usePx = require(UI.Hooks.usePx)

---> private
local c = React.createElement

local HEADER_HEIGHT = 120
local ROW_HEIGHT = 96

local PERK_NAMES = {
	QuestSlot = "+1 Quest Slot",
	HatchSpeed = "+25% Hatch Speed",
	QuestReroll = "+1 Daily Reroll",
}

local function rewardText(reward): string
	if reward == nil then
		return ""
	end
	if reward.Type == "BobaBucks" then
		return `{reward.Amount} BB`
	elseif reward.Type == "Capsule" then
		return reward.Name
	elseif reward.Type == "Nametag" then
		return `{reward.Name} Nametag`
	elseif reward.Type == "Title" then
		return "Season 1 Title"
	elseif reward.Type == "Perk" then
		return PERK_NAMES[reward.Perk] or reward.Perk
	end
	return ""
end

local function previewState()
	return {
		Success = true,
		SeasonId = 1,
		Xp = 200,
		Premium = false,
		ClaimedTiers = { [3] = true },
		StarterBundleClaimed = false,
		DaysLeft = 21,
	}
end

-- Highest fully-reached tier and the fraction of the way into the next one.
local function progressFor(xp: number): (number, number)
	local tier = 0
	while tier < SeasonConfig.TIER_COUNT and xp >= SeasonConfig.XpCumulative(tier + 1) do
		tier += 1
	end
	if tier >= SeasonConfig.TIER_COUNT then
		return SeasonConfig.TIER_COUNT, 1
	end
	local into = xp - (if tier > 0 then SeasonConfig.XpCumulative(tier) else 0)
	local need = SeasonConfig.XpRequired(tier + 1)
	return tier, math.clamp(into / need, 0, 1)
end

-- One season tier as a list row. Page-local composition of Pane +
-- Styles tokens only: no new shared component.
local function TierRow(props)
	local px = usePx()
	local verdict = props.Verdict
	local freeReward = props.FreeReward
	local premiumReward = props.PremiumReward
	local tier = props.Tier
	local xpNeeded = props.XpNeeded

	local isPremiumOnly = premiumReward ~= nil and freeReward == nil
	local isEmpty = freeReward == nil and premiumReward == nil

	local cardBg = Styles.OFFWHITE
	local strokeColor = Color3.fromRGB(220, 226, 220)
	local strokeThickness = 1.5
	local dimmed = false

	local buttonText = "Locked"
	local buttonColor = Styles.GRAY
	local buttonDisabled = true
	local onClick = nil

	local tierBadgeBg = Color3.fromRGB(235, 240, 235)
	local tierBadgeTextColor = Styles.GREEN_DEEP

	if isPremiumOnly then
		cardBg = Styles.CREAM
		strokeColor = Styles.GOLD
		strokeThickness = 1.5
		tierBadgeBg = Styles.GOLD:Lerp(Color3.new(1, 1, 1), 0.7)
		tierBadgeTextColor = Styles.GOLD_DEEP
	end

	if verdict == "Ok" then
		cardBg = Styles.GREEN_LIGHT:Lerp(Color3.new(1, 1, 1), 0.5)
		strokeColor = Styles.GREEN
		strokeThickness = 2
		tierBadgeBg = Styles.GREEN
		tierBadgeTextColor = Color3.new(1, 1, 1)
		buttonText = "Claim"
		buttonColor = Styles.GREEN
		buttonDisabled = false
		onClick = props.OnClaim
	elseif verdict == "Claimed" then
		dimmed = true
		cardBg = Color3.fromRGB(244, 246, 244)
		strokeColor = Styles.GRAY:Lerp(Color3.new(1, 1, 1), 0.5)
		strokeThickness = 1
		tierBadgeBg = Color3.fromRGB(230, 232, 230)
		tierBadgeTextColor = Styles.GRAY
		buttonText = "Claimed"
		buttonColor = Styles.GRAY
		buttonDisabled = true
	elseif verdict == "PremiumRequired" then
		cardBg = Styles.CREAM
		strokeColor = Styles.GOLD
		strokeThickness = 2
		tierBadgeBg = Styles.GOLD:Lerp(Color3.new(1, 1, 1), 0.6)
		tierBadgeTextColor = Styles.GOLD_DEEP
		buttonText = "Premium"
		buttonColor = Styles.GOLD
		buttonDisabled = false
		onClick = props.OnPremium
	else
		-- Locked or empty
		dimmed = true
		cardBg = Color3.fromRGB(248, 250, 248)
		strokeColor = Color3.fromRGB(224, 228, 224)
		strokeThickness = 1.5
		tierBadgeBg = Color3.fromRGB(235, 238, 235)
		tierBadgeTextColor = Styles.GRAY
		buttonText = if isEmpty then "–" else "Locked"
		buttonColor = Styles.GRAY
		buttonDisabled = true
	end

	-- Build reward lines
	local rewardElements = {
		UIListLayout = c("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, px(3)),
		}),
	}

	if isEmpty then
		rewardElements["EmptyLabel"] = c("TextLabel", {
			BackgroundTransparency = 1,
			FontFace = Styles.FONT_FREDOKA,
			LayoutOrder = 1,
			Size = UDim2.new(1, 0, 0, px(32)),
			Text = "No Reward",
			TextColor3 = Styles.GRAY,
			TextSize = 22,
			TextXAlignment = Enum.TextXAlignment.Left,
		})
	else
		local order = 1
		if freeReward ~= nil then
			rewardElements["FreeReward"] = c(Pane, {
				ClassName = "Frame",
				ListLayout = {
					FillDirection = Enum.FillDirection.Horizontal,
					SortOrder = Enum.SortOrder.LayoutOrder,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					Padding = UDim.new(0, px(10)),
				},
				Native = {
					BackgroundTransparency = 1,
					LayoutOrder = order,
					Size = UDim2.new(1, 0, 0, px(32)),
				},
			}, {
				Pill = c(Pane, {
					ClassName = "Frame",
					CornerRadius = 1,
					Native = {
						BackgroundColor3 = Styles.GREEN_LIGHT,
						BackgroundTransparency = 0,
						Size = UDim2.fromOffset(px(70), px(30)),
					},
				}, {
					Label = c("TextLabel", {
						BackgroundTransparency = 1,
						FontFace = Styles.FONT_FREDOKA,
						Size = UDim2.fromScale(1, 1),
						Text = "FREE",
						TextColor3 = Styles.GREEN_DEEP,
						TextSize = 16,
					}),
				}),
				Text = c("TextLabel", {
					BackgroundTransparency = 1,
					FontFace = Styles.FONT_FREDOKA,
					Size = UDim2.new(1, -px(82), 1, 0),
					Text = rewardText(freeReward),
					TextColor3 = if dimmed then Styles.GRAY else Styles.GREEN_DEEP,
					TextSize = 22,
					TextTruncate = Enum.TextTruncate.AtEnd,
					TextXAlignment = Enum.TextXAlignment.Left,
				}),
			})
			order += 1
		end

		if premiumReward ~= nil then
			rewardElements["PremiumReward"] = c(Pane, {
				ClassName = "Frame",
				ListLayout = {
					FillDirection = Enum.FillDirection.Horizontal,
					SortOrder = Enum.SortOrder.LayoutOrder,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					Padding = UDim.new(0, px(10)),
				},
				Native = {
					BackgroundTransparency = 1,
					LayoutOrder = order,
					Size = UDim2.new(1, 0, 0, px(32)),
				},
			}, {
				Pill = c(Pane, {
					ClassName = "Frame",
					CornerRadius = 1,
					Native = {
						BackgroundColor3 = Styles.CREAM,
						BackgroundTransparency = 0,
						Size = UDim2.fromOffset(px(104), px(30)),
					},
				}, {
					Label = c("TextLabel", {
						BackgroundTransparency = 1,
						FontFace = Styles.FONT_FREDOKA,
						Size = UDim2.fromScale(1, 1),
						Text = "PREMIUM",
						TextColor3 = Styles.GOLD_DEEP,
						TextSize = 16,
					}),
				}),
				Text = c("TextLabel", {
					BackgroundTransparency = 1,
					FontFace = Styles.FONT_FREDOKA,
					Size = UDim2.new(1, -px(116), 1, 0),
					Text = rewardText(premiumReward),
					TextColor3 = if dimmed then Styles.GRAY else Styles.GOLD_DEEP,
					TextSize = 22,
					TextTruncate = Enum.TextTruncate.AtEnd,
					TextXAlignment = Enum.TextXAlignment.Left,
				}),
			})
			order += 1
		end
	end

	return c(Pane, {
		ClassName = "Frame",
		CornerRadius = Styles.CORNER_CARD,
		Stroke = { Color = strokeColor, Thickness = strokeThickness },
		Padding = {
			PaddingLeft = UDim.new(0, px(16)),
			PaddingRight = UDim.new(0, px(16)),
			PaddingTop = UDim.new(0, px(10)),
			PaddingBottom = UDim.new(0, px(10)),
		},
		Native = {
			BackgroundColor3 = cardBg,
			BackgroundTransparency = 0,
			LayoutOrder = props.LayoutOrder,
			Size = UDim2.new(1, 0, 0, px(ROW_HEIGHT)),
		},
	}, {
		TierBadge = c(Pane, {
			ClassName = "Frame",
			CornerRadius = 1,
			Native = {
				AnchorPoint = Vector2.new(0, 0.5),
				BackgroundColor3 = tierBadgeBg,
				BackgroundTransparency = 0,
				Position = UDim2.fromScale(0, 0.5),
				Size = UDim2.fromOffset(px(94), px(46)),
			},
		}, {
			Label = c("TextLabel", {
				BackgroundTransparency = 1,
				FontFace = Styles.FONT_FREDOKA,
				Size = UDim2.fromScale(1, 1),
				Text = `Tier {tier}`,
				TextColor3 = tierBadgeTextColor,
				TextSize = 22,
			}),
		}),

		Rewards = c(Pane, {
			ClassName = "Frame",
			Native = {
				AnchorPoint = Vector2.new(0, 0.5),
				BackgroundTransparency = 1,
				Position = UDim2.new(0, px(112), 0.5, 0),
				Size = UDim2.new(1, -px(260), 1, 0),
			},
		}, rewardElements),

		ActionColumn = c(Pane, {
			ClassName = "Frame",
			ListLayout = {
				FillDirection = Enum.FillDirection.Vertical,
				HorizontalAlignment = Enum.HorizontalAlignment.Right,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, px(4)),
			},
			Native = {
				AnchorPoint = Vector2.new(1, 0.5),
				BackgroundTransparency = 1,
				Position = UDim2.fromScale(1, 0.5),
				Size = UDim2.new(0, px(130), 1, 0),
			},
		}, {
			Button = c(PromptButton, {
				Text = buttonText,
				Color = buttonColor,
				Size = UDim2.new(1, 0, 0, px(42)),
				Disabled = buttonDisabled,
				OnClick = onClick,
			}),
			LockHint = if verdict == "Locked"
					and xpNeeded ~= nil
					and xpNeeded > 0
				then c("TextLabel", {
					BackgroundTransparency = 1,
					FontFace = Styles.FONT_FREDOKA,
					LayoutOrder = 2,
					Size = UDim2.new(1, 0, 0, px(16)),
					Text = `{xpNeeded} XP needed`,
					TextColor3 = Styles.GRAY,
					TextSize = 14,
					TextXAlignment = Enum.TextXAlignment.Right,
				})
				else nil,
		}),
	})
end

---> public
return function()
	local px = usePx()
	local state, setState = React.useState(nil)
	local price, setPrice = React.useState(nil)
	local inFlightRef = React.useRef(false)

	local function fetchState()
		if not RunService:IsRunning() then
			setState(previewState())
			return
		end
		task.spawn(function()
			local ok, result = pcall(function()
				return Knit.GetService("SeasonPassService"):GetSeasonState():expect()
			end)
			if ok and typeof(result) == "table" and result.Success then
				setState(result)
			end
		end)
	end

	React.useEffect(function()
		local mounted = true
		fetchState()

		task.spawn(function()
			local id = ProductIds.SeasonPass
			if id ~= nil then
				local ok, info = pcall(function()
					return MarketplaceService:GetProductInfoAsync(id, Enum.InfoType.Product)
				end)
				if mounted and ok and typeof(info) == "table" and info.PriceInRobux ~= nil then
					setPrice(`\u{e002} {info.PriceInRobux}`)
				end
			end
		end)

		local conn = nil
		pcall(function()
			conn = Knit.GetService("SeasonPassService").SeasonPassChanged:Connect(function()
				fetchState()
			end)
		end)

		return function()
			mounted = false
			if conn then
				conn:Disconnect()
			end
		end
	end, {})

	local function promptPurchase()
		local id = ProductIds.SeasonPass
		local localPlayer = Players.LocalPlayer
		if id ~= nil and localPlayer then
			MarketplaceService:PromptProductPurchase(localPlayer, id)
		end
	end

	local function claimTier(tier: number)
		if inFlightRef.current then
			return
		end
		inFlightRef.current = true
		task.spawn(function()
			pcall(function()
				Knit.GetService("SeasonPassService"):ClaimTier(tier):expect()
			end)
			inFlightRef.current = false
			fetchState()
		end)
	end

	local seasonId = 0
	local daysLeft = 0
	local xp = 0
	local isPremium = false
	local claimedTiers: { [number]: boolean | string } = {}
	if state ~= nil then
		seasonId = state.SeasonId or 0
		daysLeft = state.DaysLeft or 0
		xp = state.Xp or 0
		isPremium = state.Premium == true
		claimedTiers = state.ClaimedTiers or {}
	end

	local claimedCount = 0
	for tier = 1, SeasonConfig.TIER_COUNT do
		if claimedTiers[tier] == true then
			claimedCount += 1
		end
	end

	local currentTier, nextFraction = progressFor(xp)

	local tierRowChildren = {
		UIPadding = c("UIPadding", {
			PaddingTop = UDim.new(0, px(2)),
			PaddingBottom = UDim.new(0, px(16)),
			PaddingLeft = UDim.new(0, px(4)),
			PaddingRight = UDim.new(0, px(4)),
		}),
	}
	if state ~= nil then
		local viewState: SeasonConfig.SeasonState = {
			SeasonId = seasonId,
			Xp = xp,
			Premium = isPremium,
			ClaimedTiers = claimedTiers,
		}
		for tier = 1, SeasonConfig.TIER_COUNT do
			local track = SeasonConfig.TRACK[tier]
			local freeReward = if track then track.Free else nil
			local premiumReward = if track then track.Premium else nil
			local verdict = SeasonConfig.ValidateClaim(viewState, tier)

			local neededXp = SeasonConfig.XpCumulative(tier) - xp
			local xpDisplay = if neededXp > 0 then neededXp else nil

			tierRowChildren[`tier_{tier}`] = c(TierRow, {
				Tier = tier,
				Verdict = verdict,
				FreeReward = freeReward,
				PremiumReward = premiumReward,
				XpNeeded = xpDisplay,
				LayoutOrder = tier,
				OnClaim = function()
					claimTier(tier)
				end,
				OnPremium = function()
					promptPurchase()
				end,
			})
		end
	end

	return c("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
	}, {
		Title = c("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundTransparency = 1,
			FontFace = Styles.FONT_FREDOKA,
			Position = UDim2.fromScale(0.470149, 0),
			Size = UDim2.fromScale(0.94, 0.09),
			Text = "Season",
			TextColor3 = Styles.GREEN,
			TextScaled = true,
		}),

		Content = c("ScrollingFrame", {
			Active = true,
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			CanvasSize = UDim2.new(),
			Position = UDim2.fromScale(0, 0.112),
			ScrollBarImageColor3 = Color3.new(),
			ScrollBarThickness = 5,
			ScrollingDirection = Enum.ScrollingDirection.Y,
			Size = UDim2.fromScale(1, 0.888),
			Visible = state ~= nil,
		}, {
			Padding = c("UIPadding", {
				PaddingTop = UDim.new(0, px(4)),
				PaddingBottom = UDim.new(0, px(8)),
				PaddingLeft = UDim.new(0, px(4)),
				PaddingRight = UDim.new(0, px(6)),
			}),

			UIListLayout = c("UIListLayout", {
				Padding = UDim.new(0.02, 0),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),

			Header = c(Pane, {
				ClassName = "Frame",
				CornerRadius = Styles.CORNER_CARD,
				Stroke = { Color = Styles.GREEN, Thickness = 2 },
				ListLayout = {
					FillDirection = Enum.FillDirection.Horizontal,
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0.02, 0),
				},
				Native = {
					BackgroundColor3 = Styles.GREEN_LIGHT:Lerp(Color3.new(1, 1, 1), 0.72),
					BackgroundTransparency = 0,
					LayoutOrder = 1,
					Size = UDim2.new(0.98, 0, 0, px(HEADER_HEIGHT)),
				},
			}, {
				Info = c(Pane, {
					ClassName = "Frame",
					ListLayout = {
						FillDirection = Enum.FillDirection.Vertical,
						SortOrder = Enum.SortOrder.LayoutOrder,
						VerticalAlignment = Enum.VerticalAlignment.Center,
						Padding = UDim.new(0.01, 0),
					},
					Native = {
						BackgroundTransparency = 1,
						LayoutOrder = 1,
						Size = UDim2.fromScale(0.54, 0.9),
					},
				}, {
					Name = c(Pane, {
						ClassName = "TextLabel",
						MaxTextSize = 24,
						Native = {
							BackgroundTransparency = 1,
							FontFace = Styles.FONT_FREDOKA,
							LayoutOrder = 1,
							Size = UDim2.fromScale(1, 0.36),
							Text = if seasonId > 0 then `Season {seasonId}` else "Season",
							TextColor3 = Styles.GREEN_DEEP,
							TextScaled = true,
							TextXAlignment = Enum.TextXAlignment.Left,
						},
					}),
					Sub = c(Pane, {
						ClassName = "TextLabel",
						MaxTextSize = 13,
						Native = {
							BackgroundTransparency = 1,
							FontFace = Styles.FONT_FREDOKA,
							LayoutOrder = 2,
							Size = UDim2.fromScale(1, 0.24),
							Text = `{daysLeft} days left · {currentTier} of {SeasonConfig.TIER_COUNT} tiers`,
							TextColor3 = Styles.GRAY,
							TextScaled = true,
							TextXAlignment = Enum.TextXAlignment.Left,
						},
					}),
					Progress = c(Pane, {
						ClassName = "Frame",
						CornerRadius = 1,
						Native = {
							BackgroundColor3 = Color3.fromRGB(225, 230, 225),
							BackgroundTransparency = 0,
							LayoutOrder = 3,
							Size = UDim2.fromScale(1, 0.18),
						},
					}, {
						UIStroke = c("UIStroke", {
							Color = Color3.fromRGB(220, 226, 220),
							Thickness = 1.5,
						}),
						Fill = c(Pane, {
							ClassName = "Frame",
							CornerRadius = 1,
							Native = {
								BackgroundColor3 = Styles.GREEN,
								BackgroundTransparency = 0,
								Size = UDim2.fromScale(math.clamp(nextFraction, 0, 1), 1),
							},
						}),
					}),
				}),

				Buy = if not isPremium
					then c(Pane, {
						ClassName = "Frame",
						ListLayout = {
							FillDirection = Enum.FillDirection.Vertical,
							HorizontalAlignment = Enum.HorizontalAlignment.Center,
							VerticalAlignment = Enum.VerticalAlignment.Center,
							SortOrder = Enum.SortOrder.LayoutOrder,
							Padding = UDim.new(0.04, 0),
						},
						Native = {
							BackgroundTransparency = 1,
							LayoutOrder = 2,
							Size = UDim2.fromScale(0.4, 0.9),
						},
					}, {
						BuyButton = c(PromptButton, {
							Text = "Buy Season Pass",
							Color = Styles.GREEN,
							LayoutOrder = 1,
							Size = UDim2.fromScale(1, 0.5),
							Disabled = ProductIds.SeasonPass == nil,
							OnClick = promptPurchase,
						}),
						Price = c(Pane, {
							ClassName = "TextLabel",
							MaxTextSize = 18,
							Native = {
								BackgroundTransparency = 1,
								FontFace = Styles.FONT_FREDOKA,
								LayoutOrder = 2,
								Size = UDim2.fromScale(1, 0.3),
								Text = price or (if ProductIds.SeasonPass == nil then "Coming soon" else "..."),
								TextColor3 = Styles.GREEN_DEEP,
								TextScaled = true,
								TextXAlignment = Enum.TextXAlignment.Center,
							},
						}),
					})
					else c(Pane, {
						ClassName = "Frame",
						ListLayout = {
							FillDirection = Enum.FillDirection.Vertical,
							HorizontalAlignment = Enum.HorizontalAlignment.Center,
							VerticalAlignment = Enum.VerticalAlignment.Center,
							SortOrder = Enum.SortOrder.LayoutOrder,
							Padding = UDim.new(0.04, 0),
						},
						Native = {
							BackgroundTransparency = 1,
							LayoutOrder = 2,
							Size = UDim2.fromScale(0.4, 0.9),
						},
					}, {
						PremiumTag = c(Pane, {
							ClassName = "TextLabel",
							MaxTextSize = 20,
							Native = {
								BackgroundTransparency = 1,
								FontFace = Styles.FONT_FREDOKA,
								LayoutOrder = 1,
								Size = UDim2.fromScale(1, 0.4),
								Text = "Premium",
								TextColor3 = Styles.GOLD_DEEP,
								TextScaled = true,
								TextXAlignment = Enum.TextXAlignment.Center,
							},
						}),
						Claimed = c(Pane, {
							ClassName = "TextLabel",
							MaxTextSize = 14,
							Native = {
								BackgroundTransparency = 1,
								FontFace = Styles.FONT_FREDOKA,
								LayoutOrder = 2,
								Size = UDim2.fromScale(1, 0.3),
								Text = `{claimedCount}/{SeasonConfig.TIER_COUNT} tiers claimed`,
								TextColor3 = Styles.GREEN_DEEP,
								TextScaled = true,
								TextXAlignment = Enum.TextXAlignment.Center,
							},
						}),
					}),
			}),

			Hint = c("TextLabel", {
				BackgroundTransparency = 1,
				FontFace = Styles.FONT_FREDOKA,
				LayoutOrder = 2,
				Size = UDim2.fromScale(0.98, 0.04),
				Text = "Complete serves, spills, shifts and quests to earn Season XP.",
				TextColor3 = Styles.GREEN_DEEP,
				TextScaled = true,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),

			Track = c(Pane, {
				ClassName = "Frame",
				ListLayout = {
					FillDirection = Enum.FillDirection.Vertical,
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, px(8)),
				},
				Native = {
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
					LayoutOrder = 3,
					Size = UDim2.fromScale(0.98, 0),
				},
			}, tierRowChildren),

			BottomSpacer = c("Frame", {
				BackgroundTransparency = 1,
				LayoutOrder = 9999,
				Size = UDim2.new(1, 0, 0, px(40)),
				Visible = true,
			}),
		}),

		LoadingSpinner = if state == nil
			then c("ImageLabel", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Image = "rbxassetid://5634393881",
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(0.175, 0.175),
				SizeConstraint = Enum.SizeConstraint.RelativeXX,
				ScaleType = Enum.ScaleType.Fit,
			})
			else nil,
	})
end
