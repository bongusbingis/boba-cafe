local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = Shared:WaitForChild("UI")

---> dependencies
local React = require(Packages.React)
local ReactSpring = require(Packages.ReactSpring)
local InventoryItemDefinitions = require(Shared.Configuration.InventoryItemDefinitions)
local Pane = require(UI.Components.Pane)
local Styles = require(UI.Styles)

---> components
local BackgroundSpotlight = require(UI.Components.Decoration.BackgroundSpotlight)
local ItemCard = require(UI.Components.Buttons.ItemCard)

---> types
type CapsuleOpeningData = {
	CapsuleImage: string,
	Reward: any,
	ItemType: string,
	IsInstant: boolean,
}

---> private
local c = React.createElement

local function resolveRewardCardProps(capsuleData: CapsuleOpeningData): ItemCard.Props?
	local reward = capsuleData.Reward
	if typeof(reward) ~= "table" then
		return nil
	end

	local rewardName = reward.Name
	if typeof(rewardName) ~= "string" then
		return nil
	end

	local itemType = capsuleData.ItemType
	local definitions = if typeof(itemType) == "string" then InventoryItemDefinitions[itemType] else nil
	local definition = if definitions then definitions[rewardName] else nil

	local tier = if typeof(reward.Tier) == "string" then reward.Tier else nil
	if tier == nil and definition and typeof(definition.Tier) == "string" then
		tier = definition.Tier
	end

	local props: ItemCard.Props = {
		Name = rewardName,
		Tier = tier or "Basic",
		Size = UDim2.fromScale(1, 1),
        ZIndex = 1,
	}

	if definition then
		if definition.PetModel then
			props.Model = definition.PetModel
		elseif definition.Image then
			props.Image = definition.Image
		elseif definition.Color then
			props.Color = definition.Color
			if definition.Animation then
				props.Animation = definition.Animation
			end
		end
	end

	return props
end

return function(props: {
	Capsule: CapsuleOpeningData,
    OnOpened: () -> (),
})
    local opened, setOpened = React.useState(false)
	local rewardCardProps = React.useMemo(function()
		return resolveRewardCardProps(props.Capsule)
	end, { props.Capsule })

	local spring, _ = ReactSpring.useSpring(function()
		return {
			from = {
				scale = 0.5,
				position = UDim2.fromScale(0.5, 0.8),
				textTransparency = 1,
			},
			to = {
				scale = 1,
				position = UDim2.fromScale(0.5, 0.5),
				textTransparency = 0,
			},
			config = {
				mass = 1,
				tension = 170,
				friction = 26,
			},
		}
	end)

	local openedStyles, openedApi = ReactSpring.useSpring(function()
		return {
			capsuleScale = 1,
			rewardScale = 0,
			config = {
				mass = 0.9,
				tension = 200,
				friction = 20,
			},
		}
	end)

	React.useEffect(function()
		openedApi.start({
			capsuleScale = if opened then 0 else 1,
			rewardScale = if opened then 1 else 0,
		})
	end, { opened })

	return c(Pane, {
		ClassName = "Frame",
		Scale = spring.scale,
		Native = {
			Size = UDim2.fromScale(0.7, 0.7),
			Position = spring.position,
			AnchorPoint = Vector2.new(0.5, 0.5),
		},
	}, {
		BackgroundSpotlight = c(BackgroundSpotlight, {
			Native = {
				ZIndex = 0,
                Size = UDim2.fromScale(0.8, 0.8),
			},
		}),

        Darken = c(Pane, {
            ClassName = "Frame",
            Scale = 4,
            Native = {
                Active = true,
                BackgroundColor3 = Color3.new(0, 0, 0),
                BackgroundTransparency = spring.textTransparency:map(function(value)
                    return 0.5 + (value * 0.5)
                end),
                Size = UDim2.fromScale(1, 1),
                Position = UDim2.fromScale(0.5, 0.5),
                AnchorPoint = Vector2.new(0.5, 0.5),
                ZIndex = -1
            },
        }),

		Capsule = c(Pane, {
			ClassName = "ImageButton",
			AspectRatio = 1,
            OnClick = function()
                if not opened then
					setOpened(true)
					task.delay(2, props.OnOpened)
				end
            end,
			Native = {
				Size = openedStyles.capsuleScale:map(function(value)
					return UDim2.fromScale(0.5 * value, 0.5 * value)
				end),
				Position = UDim2.fromScale(0.5, 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Image = props.Capsule.CapsuleImage,
				ImageTransparency = openedStyles.capsuleScale:map(function(value)
					return 1 - value
				end),
				ZIndex = 1,
			},
		}),

		RewardCard = c(Pane, {
			ClassName = "Frame",
			AspectRatio = 1,
			Native = {
				BackgroundTransparency = 1,
				Size = openedStyles.rewardScale:map(function(value)
					return UDim2.fromScale(0.5 * value, 0.5 * value)
				end),
				Position = UDim2.fromScale(0.5, 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5),
				ZIndex = 2,
			},
		}, {
			Card = if rewardCardProps then c(ItemCard, rewardCardProps) else c("TextLabel", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				FontFace = Styles.FONT_FREDOKA,
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(1, 0.3),
				Text = typeof(props.Capsule.Reward) == "table" and tostring(props.Capsule.Reward.Name) or "Reward",
				TextColor3 = Color3.new(1, 1, 1),
				TextScaled = true,
				ZIndex = 3,
			}),
		}),

		Hint = c("TextLabel", {
			TextTransparency = spring.textTransparency,
			Visible = not opened,
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundTransparency = 1,
			FontFace = Styles.FONT_DENKONE,
			Position = UDim2.fromScale(0.5, 0.75),
			Size = UDim2.fromScale(1, 0.15),
			Text = "Your capsule is ready to be hatched!\nClick to open.",
			TextColor3 = Color3.new(1, 1, 1),
			TextScaled = true,
            ZIndex = 5,
			--SizeConstraint = Enum.SizeConstraint.RelativeXX,
		}),
	})
end
