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

local function buildLines(summary): { string }
	local served = `Served {summary.Served or 0}`
	if (summary.Walkouts or 0) > 0 then
		served ..= ` · Walkouts {summary.Walkouts}`
	end
	local pay = `Pay {summary.Pay or 0} · Bonus {summary.Bonus or 0}`
	if (summary.Tips or 0) > 0 then
		pay ..= ` · Tips {summary.Tips}`
	end
	local lines = {
		string.rep("★", summary.Stars or 0)
			.. (if summary.NewBestShiftPay == true then " · Best shift ever!" else ""),
		served,
		pay,
	}
	if (summary.BestCombo or 0) >= 2 then
		if summary.NewBestCombo == true then
			table.insert(lines, `New best combo! x {summary.BestCombo}`)
		else
			table.insert(lines, `Best combo x {summary.BestCombo}`)
		end
	end
	if summary.ShiftStreak ~= nil then
		local streak = summary.ShiftStreak
		if (summary.StreakBonus or 0) > 0 then
			table.insert(lines, `Streak {streak} · +{summary.StreakBonus} BB streak bonus!`)
		else
			local remaining = ShiftConfig.STREAK_LENGTH - (streak % ShiftConfig.STREAK_LENGTH)
			table.insert(lines, `Streak {streak} · streak bonus in {remaining}`)
		end
	end
	if summary.Xp ~= nil then
		local progress = ""
		if summary.XpIntoLevel ~= nil and summary.XpForLevel ~= nil then
			progress = ` ({summary.XpIntoLevel}/{summary.XpForLevel})`
		end
		if summary.LevelBefore ~= nil and summary.LevelAfter ~= nil and summary.LevelAfter > summary.LevelBefore then
			table.insert(lines, `XP +{summary.Xp} · Level up! Level {summary.LevelAfter}{progress}`)
		elseif summary.LevelAfter ~= nil then
			table.insert(lines, `XP +{summary.Xp} · Level {summary.LevelAfter}{progress}`)
		else
			table.insert(lines, `XP +{summary.Xp}`)
		end
	end
	if summary.NextUnlock ~= nil then
		table.insert(lines, `Next: {summary.NextUnlock}`)
	elseif summary.First then
		table.insert(lines, "Next shift starts now")
	end
	return lines
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

	if summary == nil then
		return nil
	end

	local lines = buildLines(summary)
	-- Rows share the Container height so any line count fits (REVIEW-FIX P3-4); 0.12 is the usual row.
	local rowHeight = math.min(ROW_HEIGHT, (1 - ROW_GAP * (#lines - 1)) / math.max(#lines, 1))
	local rows = {}
	for index, line in lines do
		rows["Row" .. index] = c(Pane, {
			ClassName = "TextLabel",
			MaxTextSize = 22,
			Native = {
				BackgroundTransparency = 1,
				FontFace = Styles.FONT_FREDOKA,
				LayoutOrder = index,
				Size = UDim2.fromScale(0.95, rowHeight),
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
