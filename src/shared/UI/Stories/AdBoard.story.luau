local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = Shared:WaitForChild("UI")

---> dependencies
local React = require(Packages.React)
local ReactRoblox = require(Packages.ReactRoblox)

---> components
local Header = require(UI.Components.AdBoard.Header)
local PassBoard = require(UI.Components.AdBoard.PassBoard)
local CelebrityBoard = require(UI.Components.AdBoard.CelebrityBoard)

---> private
local c = React.createElement

local BOARD_COLOR = Color3.fromRGB(102, 204, 255)

return function(target)
	local root = ReactRoblox.createRoot(target)

	-- Boards render onto two separate parts in-world; stacked here to preview together.
	root:render(c("Frame", {
		BackgroundColor3 = Color3.fromRGB(40, 40, 40),
		Size = UDim2.fromScale(1, 1),
	}, {
		UIListLayout = c("UIListLayout", {
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),

		HeaderPreview = c("Frame", {
			BackgroundColor3 = BOARD_COLOR,
			LayoutOrder = 1,
			Size = UDim2.new(1, 0, 0, 60),
		}, {
			Content = c(Header, {
				Title = "Korblox",
				Subtitle = "Game Pass",
			}),
		}),

		BodyPreview = c("Frame", {
			BackgroundColor3 = Color3.fromRGB(226, 205, 178),
			LayoutOrder = 2,
			Size = UDim2.new(1, 0, 0, 320),
		}, {
			Content = c(PassBoard, {
				Description = "Gamepass description; why you should buy!",
				Image = "rbxasset://textures/ui/GuiImagePlaceholder.png",
				Price = "150",
				Color = BOARD_COLOR,
				OnPurchase = function()
					print("[AdBoard.story] purchase prompted")
				end,
			}),
		}),

		CelebrityPreview = c("Frame", {
			BackgroundColor3 = Color3.fromRGB(60, 50, 40),
			LayoutOrder = 3,
			Size = UDim2.new(1, 0, 0, 420),
		}, {
			Content = c(CelebrityBoard, {
				OnPurchase = function(productId)
					print("[AdBoard.story] celebrity purchase:", productId)
				end,
				OnPerkHover = function(perk)
					print("[AdBoard.story] perk hover:", perk and perk.Label or "none")
				end,
			}),
		}),
	}))

	return function()
		root:unmount()
	end
end
