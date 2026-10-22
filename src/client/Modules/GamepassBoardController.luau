--!strict

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Knit = require(Packages.Knit)
local PassCatalog = require(Shared.Configuration.PassCatalog)
local ProductIds = require(Shared.Configuration.ProductIds)
local EventProducts = require(Shared.Utility.EventProducts)

local GamepassBoardController = Knit.CreateController({
	Name = "GamepassBoardController",
})

-- The boards stream (Workspace.StreamingEnabled): a board's Part/Union can arrive
-- after the Model, and are re-created after streaming out, without the cloned GUIs.
local function getBoardParts(board: Model): (BasePart?, BasePart?)
	local headerPart = board:FindFirstChild("Part")
	local bodyPart = board:FindFirstChild("Union") or board:FindFirstChildWhichIsA("UnionOperation")
	if headerPart and headerPart:IsA("BasePart") and bodyPart and bodyPart:IsA("BasePart") then
		return headerPart, bodyPart
	end
	return nil, nil
end

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
	local def = PassCatalog[passId]
	local description = if def then def.Description else nil
	local icon = if def then def.Icon else nil
	if not def or description == nil or icon == nil then
		warn(
			string.format(
				"[GamepassBoardController] No display data found for PassId %d on board %s",
				passId,
				board.Name
			)
		)
		return
	end

	local headerPart, bodyPart = getBoardParts(board)

	if not headerPart or not bodyPart then
		-- Not streamed in yet; setupBoard retries when the parts arrive.
		return
	end

	if not headerPart:FindFirstChild("HeaderGui") then
		setupHeader(headerPart, templatesFolder, def.Name, "Game Pass")
	end
	if bodyPart:FindFirstChild("BodyGui") then
		return
	end

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
		descLabel.Text = description
		if not descLabel.TextFits then
			descLabel.TextScaled = true
		end
	end

	if iconLabel then
		iconLabel.Image = icon
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
	local headerPart, bodyPart = getBoardParts(board)

	if not headerPart or not bodyPart then
		-- Not streamed in yet; setupBoard retries when the parts arrive.
		return
	end

	if not headerPart:FindFirstChild("HeaderGui") then
		setupHeader(headerPart, templatesFolder, "Donations", "Thank you for your support!")
	end
	if bodyPart:FindFirstChild("DonationGui") then
		return
	end

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

-- BoardType = "Products": Boba Party + Rush Hour developer products, laid out like the Donate! board.
local function setupProductsBoard(board: Model, templatesFolder: Instance)
	local headerPart, bodyPart = getBoardParts(board)

	if not headerPart or not bodyPart then
		return
	end

	if not headerPart:FindFirstChild("HeaderGui") then
		setupHeader(headerPart, templatesFolder, "Cafe Events", "Rush Hour for everyone!")
	end
	if bodyPart:FindFirstChild("DonationGui") then
		return
	end

	local guiTemplate = templatesFolder:WaitForChild("DonationGui") :: SurfaceGui
	local productsGui = guiTemplate:Clone()
	local scrollingFrame = productsGui:FindFirstChild("ScrollingFrame", true) :: ScrollingFrame?
	local templateBtn = if scrollingFrame then scrollingFrame:FindFirstChild("Template") :: GuiButton? else nil
	if not scrollingFrame or not templateBtn then
		warn(string.format("[GamepassBoardController] Template not found on products board %s", board.Name))
		return
	end
	templateBtn.Visible = false

	local uiList = scrollingFrame:FindFirstChildWhichIsA("UIListLayout")
	local buttons: { [string]: GuiButton } = {}

	for i, product in EventProducts.Products do
		if product.Id ~= nil then
			local btn = templateBtn:Clone()
			btn.Name = "Product_" .. product.Key
			btn.LayoutOrder = i
			btn.Visible = true
			btn.Parent = scrollingFrame
			buttons[product.Key] = btn
			local textLabel = btn:FindFirstChildWhichIsA("TextLabel")
			if textLabel then
				textLabel.Text = product.Name
			end
			btn.Activated:Connect(function()
				EventProducts.prompt(product)
			end)
		end
	end

	-- Party button hides during the post-party cooldown (still shown while a party runs, to extend it).
	local function refreshVisibility()
		for _, product in EventProducts.Products do
			local btn = buttons[product.Key]
			if btn then
				btn.Visible = EventProducts.available(product)
			end
		end
	end
	refreshVisibility()
	local conns = {
		workspace:GetAttributeChangedSignal("BobaParty"):Connect(refreshVisibility),
		workspace:GetAttributeChangedSignal("BobaPartyCooldownEndsAt"):Connect(refreshVisibility),
	}
	productsGui.Destroying:Connect(function()
		for _, conn in conns do
			conn:Disconnect()
		end
	end)

	task.spawn(function()
		local prices = EventProducts.fetchPrices()
		for _, product in EventProducts.Products do
			local btn = buttons[product.Key]
			local price = prices[product.Key]
			local textLabel = if btn then btn:FindFirstChildWhichIsA("TextLabel") else nil
			if textLabel and price then
				textLabel.Text = `{product.Name}  \u{e002} {price}`
			end
		end
	end)

	if uiList then
		local function updateCanvas()
			scrollingFrame.CanvasSize = UDim2.fromOffset(0, uiList.AbsoluteContentSize.Y)
		end
		uiList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateCanvas)
		task.defer(updateCanvas)
	end

	productsGui.Parent = bodyPart

	-- The cooldown ends by clock, not by an attribute change.
	task.spawn(function()
		while productsGui:IsDescendantOf(game) do
			task.wait(5)
			refreshVisibility()
		end
	end)
end

local function setupBoard(board: Instance, templatesFolder: Instance)
	if not board:IsA("Model") then
		return
	end

	local boardType = board:GetAttribute("BoardType")
	if boardType == "Products" then
		local function buildProducts()
			setupProductsBoard(board, templatesFolder)
		end
		board.ChildAdded:Connect(function(child)
			if child:IsA("BasePart") then
				task.defer(buildProducts)
			end
		end)
		buildProducts()
		return
	end
	local isDonation = boardType == "Donation" or board.Name == "Donate!"

	local passId = board:GetAttribute("PassId")
	if not isDonation and passId == nil then
		local attrWait = 0
		while passId == nil and attrWait < 5 do
			task.wait(0.2)
			attrWait += 0.2
			passId = board:GetAttribute("PassId")
		end
	end
	if not isDonation and not (typeof(passId) == "number" and passId > 0) then
		return
	end

	local function build()
		if isDonation then
			setupDonationBoard(board, templatesFolder)
		else
			setupGamepassBoard(board, passId, templatesFolder)
		end
	end

	-- Build now if the parts are here, and again whenever a part streams (back) in.
	board.ChildAdded:Connect(function(child)
		if child:IsA("BasePart") then
			task.defer(build)
		end
	end)
	build()
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
