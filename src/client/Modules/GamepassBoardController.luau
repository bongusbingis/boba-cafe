--!strict

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Knit = require(Packages.Knit)
local Gamepasses = require(Shared.Configuration.Gamepasses)
local ProductIds = require(Shared.Configuration.ProductIds)

local GamepassBoardController = Knit.CreateController({
	Name = "GamepassBoardController",
})

local function setupHeader(headerPart: BasePart, templatesFolder: Instance, title: string, subtitle: string)
	local headerGuiTemplate = templatesFolder:WaitForChild("HeaderGui") :: SurfaceGui
	local headerGui = headerGuiTemplate:Clone()
	local titleLabel = headerGui:FindFirstChild("Title") :: TextLabel?
	local subtitleLabel = headerGui:FindFirstChild("Subtitle") :: TextLabel?

	if not titleLabel or not subtitleLabel then
		for _, child in headerGui:GetChildren() do
			if child:IsA("TextLabel") then
				if not titleLabel and child.Position.Y.Scale < 0.5 then
					titleLabel = child
				else
					subtitleLabel = child
				end
			end
		end
	end

	if titleLabel then
		titleLabel.Text = title
	end
	if subtitleLabel then
		subtitleLabel.Text = subtitle
	end

	headerGui.Parent = headerPart
end

local function setupGamepassBoard(board: Model, passId: number, templatesFolder: Instance)
	local def = Gamepasses[passId]
	if not def then
		warn(
			string.format("[GamepassBoardController] No definition found for PassId %d on board %s", passId, board.Name)
		)
		return
	end

	local headerPart = board:WaitForChild("Part", 10) :: BasePart?
	local bodyPart = (board:WaitForChild("Union", 10) or board:FindFirstChildWhichIsA("UnionOperation")) :: BasePart?

	if not headerPart or not bodyPart then
		warn(string.format("[GamepassBoardController] Missing Part or Union on board %s", board.Name))
		return
	end

	if headerPart:FindFirstChild("HeaderGui") or bodyPart:FindFirstChild("BodyGui") then
		return
	end

	setupHeader(headerPart, templatesFolder, def.Name, "Game Pass")

	local bodyGuiTemplate = templatesFolder:WaitForChild("BodyGui") :: SurfaceGui
	local bodyGui = bodyGuiTemplate:Clone()
	local descFrame = bodyGui:FindFirstChild("DescriptionFrame", true)
	local purchaseBtn = descFrame and descFrame:FindFirstChild("Purchase", true) :: GuiButton?
	local contentFrame = descFrame and descFrame:FindFirstChild("Frame")

	local descLabel = if contentFrame then contentFrame:FindFirstChildWhichIsA("TextLabel") else nil
	local iconLabel = if contentFrame then contentFrame:FindFirstChildWhichIsA("ImageLabel") else nil
	if not descLabel then
		descLabel = bodyGui:FindFirstChild("TextLabel", true) :: TextLabel?
	end
	if not iconLabel then
		iconLabel = bodyGui:FindFirstChild("ImageLabel", true) :: ImageLabel?
	end
	local priceLabel = bodyGui:FindFirstChild("PriceInRobux", true) :: TextLabel?

	if descLabel then
		descLabel.Text = def.Description
		if not descLabel.TextFits then
			descLabel.TextScaled = true
		end
	end

	if iconLabel then
		iconLabel.Image = def.Icon
	end

	task.spawn(function()
		local success, info = pcall(function()
			return MarketplaceService:GetProductInfo(passId, Enum.InfoType.GamePass)
		end)
		if success and info and priceLabel then
			priceLabel.Text = tostring(info.PriceInRobux or 0)
			task.wait()
			local priceFrame = priceLabel.Parent
			if priceFrame and priceFrame:IsA("GuiObject") then
				priceLabel.Size = UDim2.new(0, priceLabel.TextBounds.X, 0.8, 0)
				local uiList = priceFrame:FindFirstChildWhichIsA("UIListLayout")
				if uiList then
					priceFrame.Size = UDim2.new(0, uiList.AbsoluteContentSize.X + 20, 0.15, 0)
				end
			end
		end
	end)

	local function promptPurchase()
		MarketplaceService:PromptGamePassPurchase(Players.LocalPlayer, passId)
	end

	if purchaseBtn then
		purchaseBtn.Activated:Connect(promptPurchase)
	end

	local clickDetector = board:FindFirstChildWhichIsA("ClickDetector")
	if not clickDetector then
		clickDetector = Instance.new("ClickDetector")
		clickDetector.MaxActivationDistance = 32
		clickDetector.Parent = board
	end
	clickDetector.MouseClick:Connect(function(player)
		if player == Players.LocalPlayer then
			promptPurchase()
		end
	end)

	bodyGui.Parent = bodyPart
end

local function setupDonationBoard(board: Model, templatesFolder: Instance)
	local headerPart = board:WaitForChild("Part", 10) :: BasePart?
	local bodyPart = (board:WaitForChild("Union", 10) or board:FindFirstChildWhichIsA("UnionOperation")) :: BasePart?

	if not headerPart or not bodyPart then
		warn(string.format("[GamepassBoardController] Missing Part or Union on donation board %s", board.Name))
		return
	end

	if headerPart:FindFirstChild("HeaderGui") or bodyPart:FindFirstChild("DonationGui") then
		return
	end

	setupHeader(headerPart, templatesFolder, "Donations", "Thank you for your support!")

	local donationGuiTemplate = templatesFolder:WaitForChild("DonationGui") :: SurfaceGui
	local donationGui = donationGuiTemplate:Clone()
	local scrollingFrame = donationGui:FindFirstChild("ScrollingFrame", true) :: ScrollingFrame?

	if not scrollingFrame then
		warn(string.format("[GamepassBoardController] ScrollingFrame not found on donation board %s", board.Name))
		return
	end

	local templateBtn = scrollingFrame:FindFirstChild("Template") :: GuiButton?
	if not templateBtn then
		warn(string.format("[GamepassBoardController] Template button not found on donation board %s", board.Name))
		return
	end
	templateBtn.Visible = false

	local uiList = scrollingFrame:FindFirstChildWhichIsA("UIListLayout")

	for _, donation in ProductIds.Donations do
		local productId = donation.ProductId
		local btn = templateBtn:Clone()
		btn.Name = "Product_" .. tostring(productId)
		btn.Visible = true
		btn.Parent = scrollingFrame

		btn.Activated:Connect(function()
			MarketplaceService:PromptProductPurchase(Players.LocalPlayer, productId)
		end)

		task.spawn(function()
			local success, info = pcall(function()
				return MarketplaceService:GetProductInfo(productId, Enum.InfoType.Product)
			end)
			if success and info then
				local price = info.PriceInRobux or 0
				local textLabel = btn:FindFirstChildWhichIsA("TextLabel")
				if textLabel then
					textLabel.Text = tostring(price)
				end
				btn.LayoutOrder = price
			end
		end)
	end

	if uiList then
		local function updateCanvas()
			scrollingFrame.CanvasSize = UDim2.fromOffset(0, uiList.AbsoluteContentSize.Y)
		end
		uiList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateCanvas)
		task.defer(updateCanvas)
	end

	donationGui.Parent = bodyPart
end

local function setupBoard(board: Instance, templatesFolder: Instance)
	if not board:IsA("Model") then
		return
	end

	local boardType = board:GetAttribute("BoardType")
	if boardType == "Donation" or board.Name == "Donate!" then
		setupDonationBoard(board, templatesFolder)
		return
	end

	local passId = board:GetAttribute("PassId")
	if passId == nil then
		local attrWait = 0
		while passId == nil and attrWait < 5 do
			task.wait(0.2)
			attrWait += 0.2
			passId = board:GetAttribute("PassId")
		end
	end

	if typeof(passId) == "number" and passId > 0 then
		setupGamepassBoard(board, passId, templatesFolder)
	end
end

function GamepassBoardController:KnitInit() end

function GamepassBoardController:KnitStart()
	task.spawn(function()
		local assets = Workspace:WaitForChild("Assets")
		local gamepassBoards = assets:WaitForChild("GamepassBoards")
		local sharedStorage = ReplicatedStorage:WaitForChild("SharedStorage")
		local templatesFolder = sharedStorage:WaitForChild("GamepassBoardTemplates")

		for _, board in gamepassBoards:GetChildren() do
			task.spawn(setupBoard, board, templatesFolder)
		end

		gamepassBoards.ChildAdded:Connect(function(board)
			task.spawn(setupBoard, board, templatesFolder)
		end)
	end)
end

return GamepassBoardController
