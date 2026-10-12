--[[
    Component: ObjectiveCard
    Description: The persistent objective shown while the worker onboarding runs.

    Deliberately small and wordless-ish: one line naming the current goal, and a row of
    pips showing how far through the player is. The research is blunt that walls of text
    fail for the audience this game actually gets — the beacon in the world does the
    pointing, and this only says what and how far.

    Renders nothing when there is no objective, so it costs nothing outside onboarding.
--]]

--!nonstrict

---> Services

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = Shared:WaitForChild("UI")

---> Dependencies

local Knit = require(Packages.Knit)
local React = require(Packages.React)
local OnboardingConfig = require(Shared.Configuration.OnboardingConfig)

---> Styles

local Styles = require(UI.Styles)

---> Components

local Pane = require(UI.Components.Pane)

---> Hooks

local usePx = require(UI.Hooks.usePx)

---> Private

local c = React.createElement

--- Pre-scale card geometry. Sits top-centre, clear of both HUD columns and of the order
--- ticket, which owns the middle-bottom of the screen.
local CARD_WIDTH = 330
local CARD_HEIGHT = 74

---> Component

--- The `Initial*` props seed the card for the story runner; in game they are nil and the
--- state comes from OnboardingController.
return function(props: {
	InitialObjective: any?,
	InitialStepIndex: number?,
	InitialObjectiveText: string?,
}?)
	local px = usePx()

	local objective, setObjective = React.useState(props and props.InitialObjective or nil)
	local stepIndex, setStepIndex = React.useState(props and props.InitialStepIndex or 0)
	-- Server-supplied line naming the actual customer; falls back to the step's static text.
	local objectiveText, setObjectiveText = React.useState(props and props.InitialObjectiveText or nil)

	if RunService:IsRunning() then
		React.useEffect(function()
			local controller = Knit.GetController("OnboardingController")

			-- Snapshot on mount: the objective may already be set by the time the HUD
			-- renders.
			setObjective(controller.Objective)
			setObjectiveText(controller.ObjectiveText)
			if controller.State then
				setStepIndex(controller.State.StepIndex or 0)
			end

			local objectiveConn = controller.ObjectiveChanged:Connect(setObjective)
			local stateConn = controller.StateChanged:Connect(function(state)
				setStepIndex(state.StepIndex or 0)
				setObjectiveText(state.ObjectiveText)
			end)

			return function()
				objectiveConn:Disconnect()
				stateConn:Disconnect()
			end
		end, {})
	end

	if not objective then
		return nil
	end

	local total = #OnboardingConfig.WORKER_STEPS

	---> progress pips

	local pips: { [string]: any } = {
		UIListLayout = c("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, px(5)),
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}),
	}

	for index = 1, total do
		pips[`Pip{index}`] = c(Pane, {
			ClassName = "Frame",
			CornerRadius = Styles.CORNER_FULL,
			Native = {
				BackgroundColor3 = if index <= stepIndex then Styles.GREEN_BADGE else Styles.OFFWHITE,
				LayoutOrder = index,
				Size = UDim2.fromOffset(px(if index == stepIndex + 1 then 12 else 8), px(8)),
			},
		})
	end

	return c(Pane, {
		ClassName = "Frame",
		CornerRadius = Styles.CORNER_CARD,
		Stroke = { Color = Styles.GREEN_MID, Thickness = 2 },
		Native = {
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundColor3 = Styles.CREAM,
			-- Below the top bar, above everything else in the HUD.
			Position = UDim2.fromScale(0.5, 0.14),
			Size = UDim2.fromOffset(px(CARD_WIDTH), px(CARD_HEIGHT)),
			ZIndex = 12,
		},
	}, {
		UIPadding = c("UIPadding", {
			PaddingBottom = UDim.new(0, px(8)),
			PaddingLeft = UDim.new(0, px(12)),
			PaddingRight = UDim.new(0, px(12)),
			PaddingTop = UDim.new(0, px(6)),
		}),

		Heading = c(Pane, {
			ClassName = "TextLabel",
			Native = {
				BackgroundTransparency = 1,
				FontFace = Styles.FONT_FREDOKA,
				Position = UDim2.fromScale(0, 0),
				Size = UDim2.fromScale(1, 0.22),
				Text = `Step {math.min(stepIndex + 1, total)} of {total}`,
				TextColor3 = Styles.GREEN_DEEP,
				TextScaled = true,
				TextXAlignment = Enum.TextXAlignment.Left,
			},
		}, {
			UITextSizeConstraint = c("UITextSizeConstraint", { MaxTextSize = px(14) }),
		}),

		Objective = c(Pane, {
			ClassName = "TextLabel",
			Native = {
				BackgroundTransparency = 1,
				FontFace = Styles.FONT_FREDOKA,
				Position = UDim2.fromScale(0, 0.26),
				Size = UDim2.fromScale(1, 0.42),
				Text = objectiveText or objective.Objective,
				TextColor3 = Styles.GREEN,
				TextScaled = true,
				TextXAlignment = Enum.TextXAlignment.Left,
			},
		}, {
			UITextSizeConstraint = c("UITextSizeConstraint", { MaxTextSize = px(26) }),
		}),

		Pips = c(Pane, {
			ClassName = "Frame",
			Native = {
				AnchorPoint = Vector2.new(0.5, 1),
				BackgroundTransparency = 1,
				Position = UDim2.fromScale(0.5, 1),
				Size = UDim2.fromScale(1, 0.2),
			},
		}, pips),
	})
end
