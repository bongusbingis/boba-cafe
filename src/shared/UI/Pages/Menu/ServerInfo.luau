local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = Shared:WaitForChild("UI")

---> dependencies
local React = require(Packages.React)

---> styles
local Styles = require(UI.Styles)

---> private
local c = React.createElement
local nextOrderFunctionFactory = require(UI.Utility.nextOrderFunctionFactory)

local function formatUptime(seconds: number): string
	local h = math.floor(seconds / 3600)
	local m = math.floor((seconds % 3600) / 60)
	local s = math.floor(seconds % 60)
	return string.format("%d:%d:%d", h, m, s)
end

local function label(props: {
	Text: string,
	YScale: number,
	Position: UDim2?,
	Font: Font?,
})
	return c("TextLabel", {
		Text = props.Text,
		BackgroundTransparency = 1,
		TextColor3 = Styles.GREEN,
		TextScaled = true,
		FontFace = props.Font or Font.new("rbxasset://fonts/families/DenkOne.json"),
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = props.Position,
		Size = UDim2.fromScale(1, props.YScale),
	})
end

return function()
	local uptime, setUptime = React.useState(math.floor(workspace.DistributedGameTime))
	local playerCount, setPlayerCount = React.useState(#Players:GetPlayers())

	React.useEffect(function()
		local running = true

		local function tick()
			if not running then
				return
			end
			setUptime(math.floor(workspace.DistributedGameTime))
			task.delay(1, tick)
		end
		tick()

		return function()
			running = false
		end
	end, {})

	React.useEffect(function()
		local addedConn = Players.PlayerAdded:Connect(function()
			setPlayerCount(#Players:GetPlayers())
		end)
		local removedConn = Players.PlayerRemoving:Connect(function()
			task.defer(function()
				setPlayerCount(#Players:GetPlayers())
			end)
		end)

		return function()
			addedConn:Disconnect()
			removedConn:Disconnect()
		end
	end, {})

	local nextOrder = nextOrderFunctionFactory()

	local infos = {
		{ Title = "Server Uptime", Text = formatUptime(uptime) },
		{ Title = "Players Online", Text = tostring(playerCount) },
		{ Title = "Server Version", Text = tostring(game.PlaceVersion) },
	}

	local children = {
		c("UIListLayout", {
			Padding = UDim.new(0.015, 0),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		c(label, {
			Text = "Server Info",
			YScale = 0.1,
			Font = Font.new("rbxasset://fonts/families/FredokaOne.json"),
		}),
	}

	for _, info in ipairs(infos) do
		table.insert(
			children,
			c("Frame", {
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 0.15),
				LayoutOrder = nextOrder(),
			}, {
				c(label, {
					Text = info.Title,
					YScale = 0.35,
				}),
				c(label, {
					Text = info.Text,
					YScale = 0.65,
					Position = UDim2.fromScale(0, 0.3),
				}),
			})
		)
	end

	return c("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
	}, children)
end
