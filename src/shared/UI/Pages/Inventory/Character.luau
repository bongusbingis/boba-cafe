--!strict
--[[
	Character.luau
	Inventory tab for Character customization:
	  - Cafe Uniforms (Default, Star Employee) with 3D player Viewport preview
	  - Costumes (Boba Buddy Costume with 3D player Viewport preview)
--]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = Shared:WaitForChild("UI")

local React = require(Packages.React)
local Knit = require(Packages.Knit)

local Styles = require(UI.Styles)
local Pane = require(UI.Components.Pane)
local PromptButton = require(UI.Components.Buttons.PromptButton)
local ViewportCostumePreview = require(UI.Components.ViewportCostumePreview)
local GamepassUtil = require(Shared.Utility.GamepassUtil)
local ProductIds = require(Shared.Configuration.ProductIds)

local c = React.createElement

local STAR_EMPLOYEE_PASS_ID = 219650999

-- Category section header matching ShopCategory anatomy
local function SectionHeader(props: {
	Title: string,
	LayoutOrder: number,
})
	return c(Pane, {
		ClassName = "ImageLabel",
		Native = {
			BackgroundTransparency = 1,
			Image = "http://www.roblox.com/asset/?id=13465572823",
			ImageColor3 = Styles.GREEN_LIGHT,
			LayoutOrder = props.LayoutOrder,
			Size = UDim2.fromScale(0.981, 0.065),
			SizeConstraint = Enum.SizeConstraint.RelativeXX,
			SliceCenter = Rect.new(0, 0, 1019, 40),
		},
	}, {
		Title = c(Pane, {
			ClassName = "TextLabel",
			Native = {
				AnchorPoint = Vector2.new(0.5, 0),
				BackgroundTransparency = 1,
				FontFace = Styles.FONT_FREDOKA,
				Position = UDim2.fromScale(0.5, 0.13),
				Size = UDim2.fromScale(0.94, 0.7),
				Text = props.Title,
				TextColor3 = Color3.new(1, 1, 1),
				TextScaled = true,
				TextXAlignment = Enum.TextXAlignment.Left,
			},
		}),
	})
end

local function SectionFooter(props: {
	LayoutOrder: number,
})
	return c(Pane, {
		ClassName = "ImageLabel",
		Native = {
			BackgroundTransparency = 1,
			Image = "http://www.roblox.com/asset/?id=13465749908",
			ImageColor3 = Styles.GREEN_LIGHT,
			LayoutOrder = props.LayoutOrder,
			Size = UDim2.fromScale(0.981, 0.02),
			SizeConstraint = Enum.SizeConstraint.RelativeXX,
		},
	})
end

local function ItemCardRow(props: {
	Title: string,
	Description: string,
	StatusBadge: string?,
	BadgeColor: Color3?,
	ButtonText: string,
	ButtonColor: Color3?,
	ButtonDisabled: boolean?,
	CustomPreview: any?,
	LayoutOrder: number,
	OnClick: () -> (),
})
	return c(Pane, {
		ClassName = "Frame",
		CornerRadius = Styles.CORNER_CARD,
		Stroke = { Color = Styles.GREEN_DEEP, Thickness = 2 },
		Native = {
			BackgroundColor3 = Styles.GREEN_LIGHT,
			BackgroundTransparency = 0.2,
			LayoutOrder = props.LayoutOrder,
			Size = UDim2.new(0.981, 0, 0, 95),
		},
	}, {
		List = c("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0.02, 0),
		}),

		Preview = c(Pane, {
			ClassName = "Frame",
			CornerRadius = Styles.CORNER_BUTTON,
			Native = {
				BackgroundColor3 = Styles.GREEN_DIM,
				BackgroundTransparency = 0.3,
				LayoutOrder = 1,
				Size = UDim2.fromOffset(80, 80),
			},
		}, {
			Content = props.CustomPreview,
		}),

		Info = c(Pane, {
			ClassName = "Frame",
			ListLayout = {
				FillDirection = Enum.FillDirection.Vertical,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, 4),
			},
			Native = {
				BackgroundTransparency = 1,
				LayoutOrder = 2,
				Size = UDim2.fromScale(0.52, 0.9),
			},
		}, {
			Title = c("TextLabel", {
				BackgroundTransparency = 1,
				FontFace = Styles.FONT_FREDOKA,
				LayoutOrder = 1,
				Size = UDim2.new(1, 0, 0, 22),
				Text = props.Title,
				TextColor3 = Color3.new(1, 1, 1),
				TextSize = 18,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			Desc = c("TextLabel", {
				BackgroundTransparency = 1,
				FontFace = Styles.FONT_FREDOKA,
				LayoutOrder = 2,
				Size = UDim2.new(1, 0, 0, 32),
				Text = props.Description,
				TextColor3 = Color3.fromRGB(240, 245, 240),
				TextSize = 13,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Top,
			}),
			Badge = if props.StatusBadge
				then c(Pane, {
					ClassName = "TextLabel",
					CornerRadius = Styles.CORNER_PILL,
					Native = {
						BackgroundColor3 = props.BadgeColor or Styles.GREEN,
						BackgroundTransparency = 0.1,
						FontFace = Styles.FONT_FREDOKA,
						LayoutOrder = 3,
						Size = UDim2.fromOffset(80, 20),
						Text = props.StatusBadge,
						TextColor3 = Color3.new(1, 1, 1),
						TextSize = 12,
					},
				})
				else nil,
		}),

		Action = c(Pane, {
			ClassName = "Frame",
			ListLayout = {
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				VerticalAlignment = Enum.VerticalAlignment.Center,
			},
			Native = {
				BackgroundTransparency = 1,
				LayoutOrder = 3,
				Size = UDim2.fromScale(0.24, 0.85),
			},
		}, {
			Button = c(PromptButton, {
				Text = props.ButtonText,
				Color = props.ButtonColor or Styles.GREEN,
				Disabled = props.ButtonDisabled,
				Size = UDim2.fromScale(1, 0.45),
				OnClick = props.OnClick,
			}),
		}),
	})
end

return function()
	local localPlayer = Players.LocalPlayer
	local charData, setCharData = React.useState({
		EquippedUniform = "Default",
		OwnedCostumes = {} :: { [string]: boolean },
		EquippedCostume = nil :: string?,
	})
	local ownsStarEmployee, setOwnsStarEmployee = React.useState(false)
	local isClockedIn, setIsClockedIn = React.useState(false)
	local inFlightRef = React.useRef(false)

	local function refresh()
		if not RunService:IsRunning() then
			return
		end

		local charService = Knit.GetService("CharacterCustomizationService")
		if charService and charService.GetCharacterState then
			charService
				:GetCharacterState()
				:andThen(function(state)
					if state then
						setCharData(state)
					end
				end)
				:catch(function() end)
		end

		if localPlayer then
			pcall(function()
				local owns = (GamepassUtil :: any):PlayerOwnsPassAsync(localPlayer, STAR_EMPLOYEE_PASS_ID)
				setOwnsStarEmployee(owns == true)
			end)

			local shiftService = Knit.GetService("ShiftService")
			if shiftService and shiftService.IsClockedIn then
				setIsClockedIn(shiftService:IsClockedIn(localPlayer))
			else
				setIsClockedIn(localPlayer:GetAttribute("ClockedIn") == true)
			end
		end
	end

	React.useEffect(function()
		refresh()

		if not RunService:IsRunning() then
			return
		end

		local charService = Knit.GetService("CharacterCustomizationService")
		local conn
		if charService and charService.CharacterCustomizationChanged then
			conn = charService.CharacterCustomizationChanged:Connect(function(state)
				if state then
					setCharData(state)
				end
			end)
		end

		local passConn = MarketplaceService.PromptGamePassPurchaseFinished:Connect(
			function(player, passId, wasPurchased)
				if wasPurchased and player == localPlayer and passId == STAR_EMPLOYEE_PASS_ID then
					setOwnsStarEmployee(true)
				end
			end
		)

		return function()
			if conn then
				conn:Disconnect()
			end
			passConn:Disconnect()
		end
	end, {})

	local function equipUniform(uniformId: string?)
		if inFlightRef.current or not RunService:IsRunning() then
			return
		end

		if isClockedIn and (uniformId == nil or uniformId == "") then
			local dialogController = Knit.GetController("DialogController")
			if dialogController then
				local prompt = dialogController.new("ButtonPrompt", {
					Title = "Uniform Required",
					Text = "Staff must always wear a cafe uniform while clocked in!",
					Buttons = { { Text = "Understood", Color = Styles.GREEN } },
				})
				prompt:Fire()
			end
			return
		end

		inFlightRef.current = true

		local charService = Knit.GetService("CharacterCustomizationService")
		charService
			:EquipUniform(uniformId)
			:andThen(function(ok, reason)
				inFlightRef.current = false
				if not ok and reason == "UniformMandatoryWhileClockedIn" then
					local dialogController = Knit.GetController("DialogController")
					if dialogController then
						local prompt = dialogController.new("ButtonPrompt", {
							Title = "Uniform Required",
							Text = "Staff must always wear a cafe uniform while clocked in!",
							Buttons = { { Text = "Understood", Color = Styles.GREEN } },
						})
						prompt:Fire()
					end
				elseif ok then
					refresh()
				end
			end)
			:catch(function()
				inFlightRef.current = false
			end)
	end

	local function equipCostume(costumeId: string?)
		if inFlightRef.current or not RunService:IsRunning() then
			return
		end
		inFlightRef.current = true

		local charService = Knit.GetService("CharacterCustomizationService")
		charService
			:EquipCostume(costumeId)
			:andThen(function(ok, _reason)
				inFlightRef.current = false
				if ok then
					refresh()
				end
			end)
			:catch(function()
				inFlightRef.current = false
			end)
	end

	local isDefaultEquipped = charData.EquippedUniform == "Default"
	local isStarEquipped = charData.EquippedUniform == "StarEmployee"
	local ownsBobaCostume = charData.OwnedCostumes and charData.OwnedCostumes["BobaCostume"] == true
	local isBobaCostumeEquipped = charData.EquippedCostume == "BobaCostume"

	return c("ScrollingFrame", {
		Active = true,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		CanvasSize = UDim2.new(),
		Position = UDim2.fromScale(0, 0),
		ScrollBarImageColor3 = Color3.new(),
		ScrollBarImageTransparency = 1,
		ScrollBarThickness = 5,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Size = UDim2.fromScale(1, 1),
	}, {
		Padding = c("UIPadding", {
			PaddingTop = UDim.new(0, 8),
			PaddingBottom = UDim.new(0, 16),
			PaddingLeft = UDim.new(0, 4),
			PaddingRight = UDim.new(0, 4),
		}),
		List = c("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 10),
		}),

		-- Section 1: Uniforms
		UniformsHeader = c(SectionHeader, {
			Title = "Cafe Uniforms",
			LayoutOrder = 10,
		}),

		DefaultUniform = c(ItemCardRow, {
			Title = "Default Uniform",
			Description = "Standard issue Boba Cafe barista attire.",
			StatusBadge = if isDefaultEquipped then "Equipped" else nil,
			BadgeColor = Styles.GREEN,
			ButtonText = if isDefaultEquipped then "Unequip" else "Equip",
			ButtonColor = if isDefaultEquipped then Styles.CORAL else Styles.GREEN,
			CustomPreview = c(ViewportCostumePreview, {
				Uniform = "Default",
				Size = UDim2.fromScale(1, 1),
			}),
			LayoutOrder = 11,
			OnClick = function()
				if isDefaultEquipped then
					equipUniform(nil)
				else
					equipUniform("Default")
				end
			end,
		}),

		StarUniform = c(ItemCardRow, {
			Title = "Star Employee Uniform",
			Description = "Gold-accented attire for Star Employee gamepass owners.",
			StatusBadge = if isStarEquipped then "Equipped" else nil,
			BadgeColor = Styles.GREEN,
			ButtonText = if isStarEquipped then "Unequip" elseif ownsStarEmployee then "Equip" else "Unlock",
			ButtonColor = if isStarEquipped then Styles.CORAL elseif ownsStarEmployee then Styles.GREEN else Styles.GOLD,
			CustomPreview = c(ViewportCostumePreview, {
				Uniform = "StarEmployee",
				Size = UDim2.fromScale(1, 1),
			}),
			LayoutOrder = 12,
			OnClick = function()
				if not ownsStarEmployee then
					MarketplaceService:PromptGamePassPurchase(localPlayer, STAR_EMPLOYEE_PASS_ID)
				elseif isStarEquipped then
					equipUniform(nil)
				else
					equipUniform("StarEmployee")
				end
			end,
		}),

		UniformsFooter = c(SectionFooter, {
			LayoutOrder = 13,
		}),

		-- Section 2: Costumes
		CostumesHeader = c(SectionHeader, {
			Title = "Wearable Costumes",
			LayoutOrder = 20,
		}),

		BobaBuddyCostume = c(ItemCardRow, {
			Title = "Boba Buddy Costume",
			Description = "Become a giant wearable boba cup companion!",
			StatusBadge = if isBobaCostumeEquipped then "Equipped" elseif ownsBobaCostume then "Owned" else nil,
			BadgeColor = Styles.GREEN,
			ButtonText = if isBobaCostumeEquipped then "Unequip" elseif ownsBobaCostume then "Equip" else "Buy",
			ButtonColor = if isBobaCostumeEquipped
				then Styles.CORAL
				elseif ownsBobaCostume then Styles.GREEN
				else Styles.GREEN,
			CustomPreview = c(ViewportCostumePreview, {
				Costume = "BobaCostume",
				Size = UDim2.fromScale(1, 1),
			}),
			LayoutOrder = 21,
			OnClick = function()
				if isBobaCostumeEquipped then
					equipCostume(nil)
				elseif ownsBobaCostume then
					equipCostume("BobaCostume")
				else
					local id = ProductIds.BobaBuddyCostume
					if id ~= nil and localPlayer then
						MarketplaceService:PromptProductPurchase(localPlayer, id)
					end
				end
			end,
		}),

		CostumesFooter = c(SectionFooter, {
			LayoutOrder = 22,
		}),
	})
end
