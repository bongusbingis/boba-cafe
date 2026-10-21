--[[
    Component: ShiftCard
    Description: Non-blocking end-of-shift card (REVIVAL-001 M2-SHIFT). Appears when the
                 server fires ShiftService.ShiftEnded and removes itself after
                 summary.Seconds. No overlay, no buttons; it never takes input.
--]]

--!nonstrict

---> Services

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

---> Dependencies

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = Shared:WaitForChild("UI")

local Knit = require(Packages.Knit)
local React = require(Packages.React)
local ReactSpring = require(Packages.ReactSpring)
local ShiftConfig = require(Shared.Configuration.ShiftConfig)
local WorldPath = require(Shared.Utility.WorldPath)

local Styles = require(UI.Styles)
local Banner = require(UI.Components.Buttons.Banner)
local Pane = require(UI.Components.Pane)

---> Private

local c = React.createElement
local BASE_IMAGE = "http://www.roblox.com/asset/?id=13473433246"
local BORDER_IMAGE = "http://www.roblox.com/asset/?id=13382163077"

local ROW_HEIGHT = 0.12 -- share of the Container per row
local ROW_GAP = 0.02
local STAR_NOTE_SPEEDS = { 1, 1.2599, 1.4983 } -- PlaybackSpeed for note 1, 2, 3 (root, major third, fifth)
local STAR_NOTE_GAP = 0.2
local STAR_NOTE_MAX = 3
local STAR_NOTE_LIFETIME = 3

-- UI-REVISION: body text is GREEN_LIGHT on the light panel (OrderQueue / dialog body
-- rule; it was OFFWHITE, nearly invisible), numbers are GREEN_DEEP rich text, and the
-- star row is GOLD (rank, FEEDBACK-VOICE 5). Copy follows FEEDBACK-VOICE 1.
local VALUE_HEX = "#" .. Styles.GREEN_DEEP:ToHex()
local OPEN_SPRING = { mass = 1, tension = 2500, friction = 100 } -- Page open spring (STYLE 5)

local function v(value: any): string
	return `<font color="{VALUE_HEX}">{value}</font>`
end

local function buildLines(summary): { string }
	local served = `Served {v(summary.Served or 0)}`
	if (summary.Walkouts or 0) > 0 then
		served ..= ` · Walkouts {v(summary.Walkouts)}`
	end
	local pay = `{v("+" .. (summary.Pay or 0) .. " BB")} pay · {v("+" .. (summary.Bonus or 0))} bonus`
	if (summary.Tips or 0) > 0 then
		pay ..= ` · {v("+" .. summary.Tips)} tips`
	end
	local lines = { served, pay }
	if (summary.BestCombo or 0) >= 2 then
		if summary.NewBestCombo == true then
			table.insert(lines, `New best combo! {v("×" .. summary.BestCombo)}`)
		else
			table.insert(lines, `Best combo {v("×" .. summary.BestCombo)}`)
		end
	end
	if summary.ShiftStreak ~= nil then
		local streak = summary.ShiftStreak
		if (summary.StreakBonus or 0) > 0 then
			table.insert(lines, `Streak {v(streak)} · {v("+" .. summary.StreakBonus .. " BB")} streak bonus!`)
		else
			local remaining = ShiftConfig.STREAK_LENGTH - (streak % ShiftConfig.STREAK_LENGTH)
			table.insert(lines, `Streak {v(streak)} · bonus in {v(remaining)}`)
		end
	end
	if summary.Xp ~= nil then
		local progress = ""
		if summary.XpIntoLevel ~= nil and summary.XpForLevel ~= nil then
			progress = ` ({summary.XpIntoLevel}/{summary.XpForLevel})`
		end
		local xp = v("+" .. summary.Xp .. " XP")
		if summary.LevelBefore ~= nil and summary.LevelAfter ~= nil and summary.LevelAfter > summary.LevelBefore then
			table.insert(lines, `{xp} · Level up! {v("Level " .. summary.LevelAfter)}`)
		elseif summary.LevelAfter ~= nil then
			table.insert(lines, `{xp} · Level {summary.LevelAfter}{progress}`)
		else
			table.insert(lines, xp)
		end
	end
	if summary.NextUnlock ~= nil then
		table.insert(lines, `Next: {summary.NextUnlock}`)
	elseif summary.First then
		table.insert(lines, "Next shift starts now")
	end
	return lines
end

-- The headline row: stars, plus "Best shift ever!" on a record.
local function starText(summary): string
	local stars = math.clamp(math.floor(summary.Stars or 0), 0, STAR_NOTE_MAX)
	local text = string.rep("★", stars) .. string.rep("☆", STAR_NOTE_MAX - stars)
	if summary.NewBestShiftPay == true then
		text ..= "  Best shift ever!"
	end
	return text
end

local function playStarJingle(stars: any)
	if typeof(stars) ~= "number" then
		return
	end
	local count = math.clamp(math.floor(stars), 0, STAR_NOTE_MAX)
	if count < 1 then
		return
	end
	task.spawn(function()
		for index = 1, count do
			pcall(function()
				local sound = WorldPath.find(SoundService, { "SFX", "UI", "StarNote" })
					or WorldPath.find(SoundService, { "UISounds", "StarNote" })
				if sound and sound:IsA("Sound") then
					local note = sound:Clone()
					note.PlaybackSpeed = STAR_NOTE_SPEEDS[index]
					note.Parent = sound.Parent
					note:Play()
					Debris:AddItem(note, STAR_NOTE_LIFETIME)
				end
			end)
			if index < count then
				task.wait(STAR_NOTE_GAP)
			end
		end
	end)
end

---> Component

return function()
	local summary, setSummary = React.useState(nil :: any)

	if RunService:IsRunning() then
		React.useEffect(function()
			local conn = Knit.GetService("ShiftService").ShiftEnded:Connect(function(newSummary)
				setSummary(newSummary)
				playStarJingle(if typeof(newSummary) == "table" then newSummary.Stars else nil)
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

	-- Pops in with the Page open spring each time a summary arrives.
	local styles, api = ReactSpring.useSpring(function()
		return { scale = 0.6, config = OPEN_SPRING }
	end)
	React.useEffect(function()
		-- Hidden (nil) resets to 0.6 off screen, so the next card pops in again.
		api.start({ scale = if summary ~= nil then 1 else 0.6, config = OPEN_SPRING })
	end, { summary })

	if summary == nil then
		return nil
	end

	local lines = buildLines(summary)
	-- Rows share the Container height so any line count fits (REVIEW-FIX P3-4); 0.12 is the usual row.
	-- The star row counts as 1.5 rows.
	local rowHeight = math.min(ROW_HEIGHT, (1 - ROW_GAP * #lines) / (#lines + 1.5))
	local rows = {
		Stars = c(Pane, {
			ClassName = "TextLabel",
			MaxTextSize = 30,
			Native = {
				BackgroundTransparency = 1,
				FontFace = Styles.FONT_FREDOKA,
				LayoutOrder = 0,
				Size = UDim2.fromScale(0.95, rowHeight * 1.5),
				Text = starText(summary),
				TextColor3 = Styles.GOLD,
				TextScaled = true,
				TextXAlignment = Enum.TextXAlignment.Center,
			},
		}, {
			Stroke = c("UIStroke", {
				Color = Styles.GOLD_DEEP,
				Thickness = 1,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
			}),
		}),
	}
	for index, line in lines do
		rows["Row" .. index] = c(Pane, {
			ClassName = "TextLabel",
			MaxTextSize = 22,
			Native = {
				BackgroundTransparency = 1,
				FontFace = Styles.FONT_FREDOKA,
				LayoutOrder = index,
				RichText = true,
				Size = UDim2.fromScale(0.95, rowHeight),
				Text = line,
				TextColor3 = Styles.GREEN_LIGHT,
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
		Scale = styles.scale,
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
					Padding = UDim.new(ROW_GAP, 0),
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
