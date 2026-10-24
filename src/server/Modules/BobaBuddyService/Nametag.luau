--!strict
--[[
	Nametag
	Overhead billboard for Boba Buddy instances: "{DisplayName}'s Boba Buddy"
	with chore indicator and live remaining duration.
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Styles = require(Shared.UI.Styles)

local Nametag = {}

function Nametag.Attach(model: Model, owner: Player, chore: string, getRemainingSeconds: () -> number): BillboardGui
	local root = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("Head")
	assert(root, "BobaBuddy model must have a primary part or root part")

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "BobaBuddyNametag"
	billboard.Size = UDim2.fromOffset(200, 60)
	billboard.StudsOffset = Vector3.new(0, 3.2, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 60
	billboard.ResetOnSpawn = false

	local frame = Instance.new("Frame")
	frame.Name = "Container"
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundTransparency = 1
	frame.Parent = billboard

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.fromScale(1, 0.45)
	title.Position = UDim2.fromScale(0, 0)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.FredokaOne
	title.TextSize = 16
	title.TextColor3 = Styles.WHITE
	title.TextStrokeColor3 = Styles.CHARCOAL
	title.TextStrokeTransparency = 0.4
	title.Text = `{owner.DisplayName}'s Boba Buddy`
	title.Parent = frame

	local badge = Instance.new("TextLabel")
	badge.Name = "Badge"
	badge.Size = UDim2.fromScale(0.8, 0.4)
	badge.Position = UDim2.fromScale(0.1, 0.5)
	badge.BackgroundColor3 = if chore == "Cleaner" then Styles.MINT else Styles.ORANGE
	badge.BackgroundTransparency = 0.2
	badge.Font = Enum.Font.GothamBold
	badge.TextSize = 12
	badge.TextColor3 = Styles.CHARCOAL
	badge.Text = `{chore} (3:00)`
	badge.Parent = frame

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = badge

	local stroke = Instance.new("UIStroke")
	stroke.Color = Styles.WHITE
	stroke.Thickness = 1.2
	stroke.Transparency = 0.5
	stroke.Parent = badge

	-- Update remaining time every second
	task.spawn(function()
		while billboard.Parent do
			local remaining = math.max(0, math.floor(getRemainingSeconds()))
			local mins = math.floor(remaining / 60)
			local secs = remaining % 60
			badge.Text = string.format("%s (%d:%02d)", chore, mins, secs)
			if remaining <= 0 then
				break
			end
			task.wait(1)
		end
	end)

	billboard.Adornee = root
	billboard.Parent = model
	return billboard
end

return Nametag
