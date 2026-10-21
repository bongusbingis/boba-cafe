--[[
	Component: LevelBar
	Description: Level pill and XP bar above the Shift pill (REVIVAL-001 HUD-LEVELBAR).
	             Reads the replicated profile Level / XP (display only). Look copies
	             CafeRating's Track / Fill / Banner. LevelBar.Flash() flashes the pill.
	Props:
	- LayoutOrder: number? applied to the outer Pane.
]]

--!nonstrict

---> Services

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

---> Dependencies

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = Shared:WaitForChild("UI")

local Knit = require(Packages.Knit)
local React = require(Packages.React)
local ReactSpring = require(Packages.ReactSpring)

local Progression = require(Shared.Configuration.Progression)
local Styles = require(UI.Styles)
local Banner = require(UI.Components.Buttons.Banner)
local Pane = require(UI.Components.Pane)

---> Constants

local FLASH_SECONDS = 0.8
local FLASH_SCALE = 1.08
local LAYOUT_ORDER = -1

---> Private

local c = React.createElement
local flashEvent = Instance.new("BindableEvent")

local function LevelBarComponent(props: { LayoutOrder: number? })
	local level, setLevel = React.useState(1)
	local xp, setXp = React.useState(0)
	local flashing, setFlashing = React.useState(false)

	if RunService:IsRunning() then
		React.useEffect(function()
			local alive = true
			local conns = {}
			Knit.GetController("DataController"):GetDataAsync():andThen(function(playerData)
				if not alive then
					return
				end
				setLevel(playerData.Level or 1)
				setXp(playerData.XP or 0)
				table.insert(
					conns,
					playerData:ListenToChange({ "Level" }, function(newValue)
						setLevel(newValue or 1)
					end)
				)
				table.insert(
					conns,
					playerData:ListenToChange({ "XP" }, function(newValue)
						setXp(newValue or 0)
					end)
				)
			end)
			return function()
				alive = false
				for _, conn in conns do
					conn:Disconnect()
				end
			end
		end, {})

		React.useEffect(function()
			local generation = 0
			local conn = flashEvent.Event:Connect(function()
				generation += 1
				local mine = generation
				setFlashing(true)
				task.delay(FLASH_SECONDS, function()
					if generation == mine then
						setFlashing(false)
					end
				end)
			end)
			return function()
				generation += 1
				conn:Disconnect()
			end
		end, {})
	end

	local isMax = level >= Progression.MAX_LEVEL
	local need = Progression.XpToNext(level)
	local fraction = if isMax then 1 else math.clamp(xp / need, 0, 1)

	local fill = ReactSpring.useSpring({
		alpha = fraction,
		config = Styles.SPRING_STANDARD,
	})
	local pop = ReactSpring.useSpring({
		Scale = if flashing then FLASH_SCALE else 1,
		config = Styles.SPRING_STANDARD,
	})

	return c(Pane, {
		ClassName = "Frame",
		AspectRatio = 5,
		Scale = pop.Scale,
		Native = {
			Active = false,
			BackgroundTransparency = 1,
			LayoutOrder = props.LayoutOrder or LAYOUT_ORDER,
			Size = UDim2.fromScale(1, 1),
		},
	}, {
		Track = c("Frame", {
			Active = false,
			AnchorPoint = Vector2.new(0.5, 1),
			BackgroundColor3 = Styles.OFFWHITE,
			BorderSizePixel = 0,
			Position = UDim2.fromScale(0.5, 1),
			Size = UDim2.fromScale(0.9, 0.38),
		}, {
			Corner = c("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
			Fill = c("Frame", {
				Active = false,
				BackgroundColor3 = Styles.GOLD,
				BorderSizePixel = 0,
				Size = fill.alpha:map(function(a)
					return UDim2.fromScale(a, 1)
				end),
			}, {
				Corner = c("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
			}),
			Label = c("TextLabel", {
				Active = false,
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				FontFace = Styles.FONT_FREDOKA,
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(0.5, 0.8),
				Text = if isMax then "MAX" else `{math.floor(xp)}/{math.floor(need)}`,
				TextColor3 = Styles.GREEN_DEEP,
				TextScaled = true,
				ZIndex = 2,
			}),
		}),

		Title = c(Banner, {
			Text = `Lv {level}`,
			Color = if flashing then Styles.GOLD else Styles.GOLD_MID,
			Position = UDim2.fromScale(0.5, 0.3),
			Size = UDim2.fromScale(0.7, 0.55),
		}),
	})
end

---> Public

local function Flash()
	flashEvent:Fire()
end

return {
	Component = LevelBarComponent,
	Flash = Flash,
}
