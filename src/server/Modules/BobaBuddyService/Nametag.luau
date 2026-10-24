--!strict
--[[
	Nametag
	Overhead billboard for Boba Buddy instances.
	Utilizes Fredoka One typography displaying "{username}'s Boba Buddy"
	and the role underneath with nothing else.
--]]

local NAMETAG_SIZE = UDim2.fromScale(4, 2.5)
local NAMETAG_SIZE_OFFSET = Vector2.new(0, 1.125)
local FONT_FREDOKA = Font.new("rbxasset://fonts/families/FredokaOne.json")

local Nametag = {}

function Nametag.Attach(model: Model, owner: Player, chore: string): BillboardGui
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
	usernameLabel.FontFace = FONT_FREDOKA
	usernameLabel.Position = UDim2.fromScale(0, 0.70)
	usernameLabel.Size = UDim2.fromScale(1, 0.18)
	usernameLabel.TextColor3 = Color3.new(1, 1, 1)
	usernameLabel.TextScaled = true
	usernameLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	usernameLabel.TextStrokeTransparency = 0.5
	usernameLabel.Text = `{owner.Name}'s Boba Buddy`
	usernameLabel.Parent = frame

	local roleLabel = Instance.new("TextLabel")
	roleLabel.Name = "RoleLabel"
	roleLabel.BackgroundTransparency = 1
	roleLabel.FontFace = FONT_FREDOKA
	roleLabel.Position = UDim2.fromScale(0, 0.88)
	roleLabel.Size = UDim2.fromScale(1, 0.15)
	roleLabel.TextColor3 = Color3.new(1, 1, 1)
	roleLabel.TextScaled = true
	roleLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	roleLabel.TextStrokeTransparency = 0.5
	roleLabel.Text = chore
	roleLabel.Parent = frame

	billboard.Parent = model
	return billboard
end

return Nametag
