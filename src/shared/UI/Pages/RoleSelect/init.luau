--[[
    Page: RoleSelect
    Description: The full-screen "how do you want to play?" choice shown on every join for
    players below the rank bypass.

    This is a deliberate hard gate between joining and playing, which the retention
    research warns about — so it is kept to one screen, two choices and no reading. It has
    no close button because there is no valid third answer; picking a role IS dismissing it.

    Unlike the OpenableMenu pages this is not routed through App's page swapper: it must be
    able to appear without a HUD button being pressed, and it must sit above everything
    else. It drives its own visibility from OnboardingService.

    The Barista strip under the Worker card is the progression the player is working
    toward. It always states its own unlock condition — a locked control that does not say
    why is the thing this whole pass exists to remove.
--]]

--!nonstrict

---> services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = Shared:WaitForChild("UI")

---> dependencies
local React = require(Packages.React)
local Knit = require(Packages.Knit)

---> styles
local Styles = require(UI.Styles)

---> components
local Pane = require(UI.Components.Pane)

---> hooks
local usePx = require(UI.Hooks.usePx)

---> private
local c = React.createElement

--- Card geometry in pre-scale pixels. Fixed rather than a fraction of the screen so the
--- two cards stay the same shape on a phone and on a monitor.
local CARD_WIDTH = 260
local CARD_HEIGHT = 300
local CARD_GAP = 24

local ROLE_COPY = {
	{
		Role = "Customer",
		Title = "Customer",
		Blurb = "Relax, explore the cafe and order a drink.",
		Color = Styles.GOLD_MID,
		TextColor = Styles.GOLD_DEEP,
	},
	{
		Role = "Worker",
		Title = "Worker",
		Blurb = "Take orders from customers and earn Boba Bucks.",
		Color = Styles.GREEN_MID,
		TextColor = Styles.GREEN_DEEP,
	},
}

---> public

--- `InitialState` seeds the screen for the story runner. In game it is nil and the state
--- comes from the service.
return function(props: { InitialState: any? }?)
	local px = usePx()

	-- nil until the server answers. The screen renders as soon as it does; there is no
	-- spinner, because a load screen in front of the first decision is exactly the delay
	-- this flow is trying to avoid.
	local state, setState = React.useState(props and props.InitialState or nil)
	-- Set the moment a role is picked, so the gate closes on the click rather than waiting
	-- for the round trip.
	local chosen, setChosen = React.useState(false)

	if RunService:IsRunning() then
		React.useEffect(function()
			local service = Knit.GetService("OnboardingService")

			task.spawn(function()
				local ok, result = service:GetState():await()
				if ok and result then
					setState(result)
				end
			end)

			local conn = service.StateChanged:Connect(setState)

			return function()
				conn:Disconnect()
			end
		end, {})
	end

	if not state or not state.ShowRoleSelect or chosen then
		return nil
	end

	local function choose(role: string)
		setChosen(true)

		if RunService:IsRunning() then
			Knit.GetService("OnboardingService"):SelectRole(role)
		end
	end

	---> the two role cards

	local cards: { [string]: any } = {
		UIListLayout = c("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, px(CARD_GAP)),
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}),
	}

	for index, entry in ROLE_COPY do
		cards[entry.Role] = c(Pane, {
			ClassName = "TextButton",
			CornerRadius = Styles.CORNER_CARD,
			Stroke = { Color = entry.Color, Thickness = 3 },
			OnClick = function()
				choose(entry.Role)
			end,
			Native = {
				AutoButtonColor = true,
				BackgroundColor3 = Styles.OFFWHITE,
				LayoutOrder = index,
				Size = UDim2.fromOffset(px(CARD_WIDTH), px(CARD_HEIGHT)),
				Text = "",
			},
		}, {
			Banner = c(Pane, {
				ClassName = "Frame",
				CornerRadius = Styles.CORNER_CARD,
				Native = {
					BackgroundColor3 = entry.Color,
					Position = UDim2.fromScale(0, 0),
					Size = UDim2.fromScale(1, 0.22),
				},
			}, {
				Label = c(Pane, {
					ClassName = "TextLabel",
					Native = {
						BackgroundTransparency = 1,
						FontFace = Styles.FONT_FREDOKA,
						Size = UDim2.fromScale(1, 1),
						Text = entry.Title,
						TextColor3 = Styles.OFFWHITE,
						TextScaled = true,
					},
				}, {
					UITextSizeConstraint = c("UITextSizeConstraint", { MaxTextSize = px(34) }),
				}),
			}),

			Blurb = c(Pane, {
				ClassName = "TextLabel",
				Native = {
					BackgroundTransparency = 1,
					FontFace = Styles.FONT_FREDOKA,
					Position = UDim2.fromScale(0.08, 0.3),
					Size = UDim2.fromScale(0.84, 0.34),
					Text = entry.Blurb,
					TextColor3 = entry.TextColor,
					TextScaled = true,
					TextWrapped = true,
				},
			}, {
				UITextSizeConstraint = c("UITextSizeConstraint", { MaxTextSize = px(20) }),
			}),

			-- Names what happens on click. New players should never have to guess what a
			-- button will do to them.
			Action = c(Pane, {
				ClassName = "TextLabel",
				CornerRadius = Styles.CORNER_PILL,
				Native = {
					AnchorPoint = Vector2.new(0.5, 1),
					BackgroundColor3 = entry.Color,
					FontFace = Styles.FONT_FREDOKA,
					Position = UDim2.fromScale(0.5, 0.92),
					Size = UDim2.fromScale(0.72, 0.14),
					Text = if entry.Role == "Worker" and not state.WorkerOnboarded
						then "Start training"
						else "Play",
					TextColor3 = Styles.OFFWHITE,
					TextScaled = true,
				},
			}, {
				UITextSizeConstraint = c("UITextSizeConstraint", { MaxTextSize = px(22) }),
			}),
		})
	end

	---> barista progression strip

	local baristaText: string
	if state.BaristaUnlocked then
		baristaText = "Barista unlocked — you can make drinks in the kitchen."
	elseif state.CanTrainBarista then
		baristaText = "You can train as a Barista now!"
	else
		baristaText = `Barista: {state.BaristaLockReason or "Keep working to unlock."}`
	end

	local showTrainButton = state.CanTrainBarista == true

	local barista = c(Pane, {
		ClassName = "Frame",
		CornerRadius = Styles.CORNER_PILL,
		Stroke = { Color = Styles.GREEN_DEEP, Thickness = 2 },
		Native = {
			AnchorPoint = Vector2.new(0.5, 1),
			BackgroundColor3 = Styles.CREAM,
			Position = UDim2.fromScale(0.5, 0.94),
			Size = UDim2.fromOffset(px((CARD_WIDTH * 2) + CARD_GAP), px(56)),
		},
	}, {
		UIPadding = c("UIPadding", {
			PaddingBottom = UDim.new(0, px(8)),
			PaddingLeft = UDim.new(0, px(16)),
			PaddingRight = UDim.new(0, px(16)),
			PaddingTop = UDim.new(0, px(8)),
		}),

		Label = c(Pane, {
			ClassName = "TextLabel",
			Native = {
				BackgroundTransparency = 1,
				FontFace = Styles.FONT_FREDOKA,
				Position = UDim2.fromScale(0, 0),
				Size = UDim2.fromScale(if showTrainButton then 0.68 else 1, 0.5),
				Text = baristaText,
				TextColor3 = Styles.GREEN_DEEP,
				TextScaled = true,
				TextXAlignment = Enum.TextXAlignment.Left,
			},
		}, {
			UITextSizeConstraint = c("UITextSizeConstraint", { MaxTextSize = px(18) }),
		}),

		-- The bar makes a ten-minute wait legible as progress rather than as a refusal.
		Track = c(Pane, {
			ClassName = "Frame",
			CornerRadius = Styles.CORNER_FULL,
			Native = {
				AnchorPoint = Vector2.new(0, 1),
				BackgroundColor3 = Styles.OFFWHITE,
				Position = UDim2.fromScale(0, 1),
				Size = UDim2.fromScale(if showTrainButton then 0.68 else 1, 0.28),
			},
		}, {
			Fill = c(Pane, {
				ClassName = "Frame",
				CornerRadius = Styles.CORNER_FULL,
				Native = {
					BackgroundColor3 = if state.BaristaUnlocked then Styles.GREEN_BADGE else Styles.GREEN_MID,
					Size = UDim2.fromScale(
						if state.BaristaUnlocked then 1 else (state.BaristaProgress or 0),
						1
					),
				},
			}),
		}),

		TrainButton = if showTrainButton
			then c(Pane, {
				ClassName = "TextButton",
				CornerRadius = Styles.CORNER_PILL,
				OnClick = function()
					if RunService:IsRunning() then
						Knit.GetService("OnboardingService"):StartTraining("Barista")
					end
				end,
				Native = {
					AnchorPoint = Vector2.new(1, 0.5),
					AutoButtonColor = true,
					BackgroundColor3 = Styles.GREEN_MID,
					FontFace = Styles.FONT_FREDOKA,
					Position = UDim2.fromScale(1, 0.5),
					Size = UDim2.fromScale(0.28, 0.9),
					Text = "Train",
					TextColor3 = Styles.OFFWHITE,
					TextScaled = true,
				},
			}, {
				UITextSizeConstraint = c("UITextSizeConstraint", { MaxTextSize = px(22) }),
			})
			else nil,
	})

	return c(Pane, {
		ClassName = "Frame",
		Native = {
			BackgroundColor3 = Styles.GREEN_DEEP,
			BackgroundTransparency = 0.25,
			Size = UDim2.fromScale(1, 1),
			-- Above the HUD and any open page: this is a gate, not a panel.
			ZIndex = 50,
		},
	}, {
		Heading = c(Pane, {
			ClassName = "TextLabel",
			Native = {
				BackgroundTransparency = 1,
				FontFace = Styles.FONT_FREDOKA,
				Position = UDim2.fromScale(0, 0.08),
				Size = UDim2.fromScale(1, 0.1),
				Text = "How do you want to play?",
				TextColor3 = Styles.OFFWHITE,
				TextScaled = true,
			},
		}, {
			UITextSizeConstraint = c("UITextSizeConstraint", { MaxTextSize = px(44) }),
		}),

		Subheading = c(Pane, {
			ClassName = "TextLabel",
			Native = {
				BackgroundTransparency = 1,
				FontFace = Styles.FONT_FREDOKA,
				Position = UDim2.fromScale(0, 0.185),
				Size = UDim2.fromScale(1, 0.05),
				Text = "You can switch any time you rejoin.",
				TextColor3 = Styles.CREAM,
				TextScaled = true,
			},
		}, {
			UITextSizeConstraint = c("UITextSizeConstraint", { MaxTextSize = px(20) }),
		}),

		Cards = c(Pane, {
			ClassName = "Frame",
			Native = {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Position = UDim2.fromScale(0.5, 0.52),
				Size = UDim2.new(1, 0, 0, px(CARD_HEIGHT)),
			},
		}, cards),

		Barista = barista,
	})
end
