--[[
    Component: ShiftCard
    Description: Non-blocking end-of-shift card (REVIVAL-001 M2-SHIFT). Appears when the
                 server fires ShiftService.ShiftEnded and removes itself after
                 summary.Seconds. No overlay, no buttons; it never takes input.
--]]

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

local Styles = require(UI.Styles)
local Banner = require(UI.Components.Buttons.Banner)
local Pane = require(UI.Components.Pane)

---> Private

local c = React.createElement
local BASE_IMAGE = "http://www.roblox.com/asset/?id=13473433246"
local BORDER_IMAGE = "http://www.roblox.com/asset/?id=13382163077"

local function buildLines(summary): { string }
	local lines = {
		string.rep("★", summary.Stars or 0),
		`Customers served: {summary.Served or 0}`,
		`Pay: {summary.Pay or 0}  Bonus: {summary.Bonus or 0}`,
		`Best combo: x {summary.BestCombo or 0}`,
	}
	if summary.Xp ~= nil then
		table.insert(lines, `XP: +{summary.Xp}`)
		if summary.LevelBefore ~= nil and summary.LevelAfter ~= nil and summary.LevelAfter > summary.LevelBefore then
			table.insert(lines, `Level up! Level {summary.LevelAfter}`)
		end
	end
	if summary.First then
		table.insert(lines, "Next shift starts now")
	end
	return lines
end

---> Component

return function()
	local summary, setSummary = React.useState(nil :: any)

	if RunService:IsRunning() then
		React.useEffect(function()
			local conn = Knit.GetService("ShiftService").ShiftEnded:Connect(function(newSummary)
				setSummary(newSummary)
			end)

			return function()
				conn:Disconnect()
			end
		end, {})
	end

	-- Remove itself after summary.Seconds; a newer summary restarts the timer.
	React.useEffect(function()
		if summary == nil then
			return nil
		end
		local thread = task.delay(summary.Seconds or 6, function()
			setSummary(nil)
		end)
		return function()
			pcall(task.cancel, thread)
		end
	end, { summary })

	if summary == nil then
		return nil
	end

	local lines = buildLines(summary)
	local rows = {}
	for index, line in lines do
		rows["Row" .. index] = c(Pane, {
			ClassName = "TextLabel",
			MaxTextSize = 22,
			Native = {
				BackgroundTransparency = 1,
				FontFace = Styles.FONT_FREDOKA,
				LayoutOrder = index,
				Size = UDim2.fromScale(0.95, 0.12),
				Text = line,
				TextColor3 = Styles.OFFWHITE,
				TextScaled = true,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Center,
			},
		})
	end

	-- Top-right zone: free in STYLE 2.4. Frame and labels do not take input.
	return c(Pane, {
		ClassName = "Frame",
		AspectRatio = 1.2,
		Native = {
			Active = false,
			AnchorPoint = Vector2.new(1, 0),
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0.99, 0.14),
			Size = UDim2.fromScale(0.2, 0.3),
			ZIndex = 10,
		},
	}, {
		UISizeConstraint = c("UISizeConstraint", {
			MaxSize = Vector2.new(300, 250),
			MinSize = Vector2.new(190, 160),
		}),

		Base = c(Pane, {
			ClassName = "ImageLabel",
			Native = {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Image = BASE_IMAGE,
				Position = UDim2.fromScale(0.5, 0.5),
				ScaleType = Enum.ScaleType.Slice,
				Size = UDim2.fromScale(1, 1),
				SliceCenter = Rect.new(104, 96, 408, 416),
			},
		}, {
			Container = c(Pane, {
				ClassName = "Frame",
				ListLayout = {
					FillDirection = Enum.FillDirection.Vertical,
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					VerticalAlignment = Enum.VerticalAlignment.Top,
					Padding = UDim.new(0.02, 0),
				},
				Native = {
					AnchorPoint = Vector2.new(0.5, 0),
					BackgroundTransparency = 1,
					Position = UDim2.fromScale(0.5, 0.2),
					Size = UDim2.fromScale(0.92, 0.72),
				},
			}, rows),

			Border = c(Pane, {
				ClassName = "ImageLabel",
				Native = {
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					Image = BORDER_IMAGE,
					ImageColor3 = Styles.GREEN_LIGHT,
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromScale(0.970972, 0.938198),
				},
			}),

			Title = c(Banner, {
				Text = "Shift Complete",
				Color = Styles.GREEN,
				Size = UDim2.fromScale(1.21645, 0.28),
			}),
		}),
	})
end
