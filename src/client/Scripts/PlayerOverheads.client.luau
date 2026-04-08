local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Packages = ReplicatedStorage:WaitForChild("Packages")

local Knit = require(Packages.Knit)
local React = require(Packages.React)
local ReactRoblox = require(Packages.ReactRoblox)

local Inventory = require(Shared.Inventory)

local c = React.createElement

local function overheadComponent(props: {
	Username: string,
	Role: string,
	SpecialTags: string,

	Nickname: string?,
	IsCelebrity: boolean?,
})
	return c("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	}, {
		Username = c("TextLabel", {
			BackgroundTransparency = 1,
			FontFace = Font.new(
				"rbxasset://fonts/families/SourceSansPro.json",
				Enum.FontWeight.Bold,
				Enum.FontStyle.Normal
			),
			Position = UDim2.fromScale(0, 0.725),
			Size = UDim2.fromScale(1, 0.15),
			Text = props.Username,
			TextColor3 = Color3.new(1, 1, 1),
			TextScaled = true,
		}),

		Nickname = c("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundTransparency = 1,
			FontFace = Font.new("rbxasset://fonts/families/DenkOne.json"),
			Position = UDim2.fromScale(0.5, 0.45),
			Size = UDim2.fromScale(3, 0.3),
			Text = props.Nickname or props.Username,
			TextColor3 = Color3.new(1, 1, 1),
			TextScaled = true,
		}),

		SpecialTags = c("TextLabel", {
			BackgroundTransparency = 1,
			FontFace = Font.new("rbxasset://fonts/families/Arial.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
			Position = UDim2.fromScale(0, 0.35),
			Size = UDim2.fromScale(1, 0.15),
			Text = "",
			TextColor3 = Color3.new(1, 1, 1),
			TextScaled = true,
		}),

		Role = c("TextLabel", {
			BackgroundTransparency = 1,
			FontFace = Font.new(
				"rbxasset://fonts/families/SourceSansPro.json",
				Enum.FontWeight.Regular,
				Enum.FontStyle.Italic
			),
			Position = UDim2.fromScale(0, 0.85),
			Size = UDim2.fromScale(1, 0.15),
			Text = props.Role,
			TextColor3 = Color3.new(1, 1, 1),
			TextScaled = true,
		}),

		CelebrityTag = props.IsCelebrity and c("TextLabel", {
			BackgroundTransparency = 1,
			FontFace = Font.new("rbxasset://fonts/families/Arial.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
			Size = UDim2.fromScale(1, 0.35),
			Text = "👑",
			TextColor3 = Color3.new(1, 1, 1),
			TextScaled = true,
		}) or nil,
	})
end

local function buildOverhead(player: Player, character: Model)
	Knit.OnStart():await()
	Knit.GetController("DataController"):GetDataAsync():andThen(function(playerData)
		local uiHandle = Instance.new("BillboardGui")
		uiHandle.Adornee = character:WaitForChild("Head")

		uiHandle.Size = UDim2.fromScale(4, 2.5)
		uiHandle.SizeOffset = Vector2.new(0, 1.125)
		uiHandle.Parent = Players.LocalPlayer.PlayerGui

        local currentRoot = ReactRoblox.createRoot(uiHandle)
		local function rerender(_root, nickname)
            if nickname == "" then
                nickname = player.Name
            end
			_root:render(c(overheadComponent, {
				Username = player.Name,
				Role = "Customer",
				SpecialTags = "",
				Nickname = nickname,
			}))
		end

		rerender(currentRoot, playerData.Nickname)

        playerData:ListenToChange({"Nickname"}, function(newNickname)
            rerender(currentRoot, newNickname)
        end)
	end)
end

local function playerAdded(player: Player)
	if player.Character then
		buildOverhead(player, player.Character)
	end
	player.CharacterAdded:Connect(function(character)
		buildOverhead(player, character)
	end)
end

for _, player in Players:GetPlayers() do
	playerAdded(player)
end
Players.PlayerAdded:Connect(playerAdded)
