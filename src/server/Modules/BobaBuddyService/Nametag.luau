--!strict
--[[
	Nametag
	Overhead billboard for Boba Buddy instances matching the Customer NPC overhead style
	(CustomerService/Npc.luau & PlayerOverheads.client.luau).
--]]

local NAMETAG_SIZE = UDim2.fromScale(4, 2.5)
local NAMETAG_SIZE_OFFSET = Vector2.new(0, 1.125)

local Nametag = {}

function Nametag.Attach(model: Model, owner: Player, chore: string, getRemainingSeconds: () -> number): BillboardGui
	local head = model:FindFirstChild("Head") or model.PrimaryPart or model:FindFirstChild("HumanoidRootPart")
	assert(head, "BobaBuddy model must have a primary part or root part")

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Nametag"
	billboard.Adornee = head
	billboard.Size = NAMETAG_SIZE
	billboard.SizeOffset = NAMETAG_SIZE_OFFSET
	billboard.LightInfluence = 0
	billboard.MaxDistance = 60
	billboard.ResetOnSpawn = false

	local frame = Instance.new("Frame")
	frame.Name = "Container"
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.fromScale(1, 1)
	frame.Parent = billboard

	local usernameLabel = Instance.new("TextLabel")
	usernameLabel.Name = "UsernameLabel"
	usernameLabel.BackgroundTransparency = 1
	usernameLabel.FontFace =
		Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal)
	usernameLabel.Position = UDim2.fromScale(0, 0.725)
	usernameLabel.Size = UDim2.fromScale(1, 0.15)
	usernameLabel.TextColor3 = Color3.new(1, 1, 1)
	usernameLabel.TextScaled = true
	usernameLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	usernameLabel.TextStrokeTransparency = 0.5
	usernameLabel.Text = `{owner.DisplayName}'s Boba Buddy`
	usernameLabel.Parent = frame

	local roleLabel = Instance.new("TextLabel")
	roleLabel.Name = "RoleLabel"
	roleLabel.BackgroundTransparency = 1
	roleLabel.FontFace =
		Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Regular, Enum.FontStyle.Italic)
	roleLabel.Position = UDim2.fromScale(0, 0.85)
	roleLabel.Size = UDim2.fromScale(1, 0.15)
	roleLabel.TextColor3 = Color3.new(1, 1, 1)
	roleLabel.TextScaled = true
	roleLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	roleLabel.TextStrokeTransparency = 0.5
	roleLabel.RichText = true
	roleLabel.Text = `{chore} (3:00)`
	roleLabel.Parent = frame

	-- Update remaining time every second
	task.spawn(function()
		while billboard.Parent do
			local remaining = math.max(0, math.floor(getRemainingSeconds()))
			local mins = math.floor(remaining / 60)
			local secs = remaining % 60
			roleLabel.Text = string.format("%s (%d:%02d)", chore, mins, secs)
			if remaining <= 0 then
				break
			end
			task.wait(1)
		end
	end)

	billboard.Parent = model
	return billboard
end

return Nametag
