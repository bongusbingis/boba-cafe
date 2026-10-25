local Boba = require(game:GetService("ReplicatedStorage"):WaitForChild("Boba"))
local Maid = require(Boba.Packages.Maid)
local ReplicaController = require(Boba.Packages.ReplicaController)
local PhoneMenuController = {}

local ProductsData
local ViewportProvider
local PhoneServiceReplica

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PopUp = script.Parent.Parent.PopUp
local PopOptions = PopUp.ItemOptions
local PopSelect = PopUp.SelectList

local CenterFrame = script.Parent.Center
local TopFrame = script.Parent.Top

local MenuFrame = CenterFrame.Menu
local categoryTemplate = MenuFrame.Template

local MyOrderFrame = CenterFrame.MyOrder
local OrderFrame = MyOrderFrame.OrderFrame
local itemTemplate = OrderFrame.Template

local CurrentOrder = {}

-- NAVIGATION
local menuNavButton = TopFrame.Buttons.Menu
local myOrderNavButton = TopFrame.Buttons.MyOrder

local function toggleMenu(button)
	TweenService:Create(button.TextLabel,TweenInfo.new(0.2),{TextColor3 = Color3.fromRGB(48, 48, 48)}):Play()
	TweenService:Create(button.Frame,TweenInfo.new(0.2),{BackgroundTransparency = 0}):Play()
end

local function untoggleMenu(button)
	TweenService:Create(button.TextLabel,TweenInfo.new(0.2),{TextColor3 = Color3.fromRGB(128, 128, 128)}):Play()
	TweenService:Create(button.Frame,TweenInfo.new(0.2),{BackgroundTransparency = 1}):Play()
end

menuNavButton.MouseButton1Click:Connect(function()
	toggleMenu(menuNavButton)
	untoggleMenu(myOrderNavButton)
	MenuFrame.Visible = true
	MyOrderFrame.Visible = false
end)

myOrderNavButton.MouseButton1Click:Connect(function()
	toggleMenu(myOrderNavButton)
	untoggleMenu(menuNavButton)
	MyOrderFrame.Visible = true
	MenuFrame.Visible = false
end)
-- NAVIGATION

local function ResetOrderingSystem()
	for _,item in pairs(OrderFrame:GetChildren()) do
		if item:IsA("Frame") and item.Visible then
			item:Destroy()
		end
	end
	CurrentOrder = {}
end

local function SubmitOrder(order)
	if #CurrentOrder > 0 then
		PhoneServiceReplica:FireServer("PlaceMobileOrder", order)
		ResetOrderingSystem()
	end
end

MyOrderFrame.Button.MouseButton1Click:Connect(function()
	SubmitOrder(CurrentOrder)
end)

local function ShowPopUp(show)
	PopUp.Visible = true
	for _,frame in pairs(PopUp:GetChildren()) do
		if frame:IsA("Frame") then
			frame.Visible = false
		end
	end
	PopUp:FindFirstChild(show).Visible = true
end

local function HidePopUp()
	PopUp.Visible = false
	for _,frame in pairs(PopUp:GetChildren()) do
		if frame:IsA("Frame") then
			frame.Visible = false
		end
	end
end

-- Select Option
local function SelectOption(Category,SelectionName,Selection)
	ShowPopUp("SelectList")

	local ToReturn = nil

	-- Load New Items
	for ItemName,ItemData in pairs(Selection) do
		local ItemButton = PopSelect.ScrollingFrame.Template:Clone()
		ItemButton.Name = ItemName
		ItemButton.Parent = PopSelect.ScrollingFrame
		ItemButton.Frame.TextLabel.Text = ItemName
		ItemButton.Frame.BackgroundColor3 = ItemData.Color or Color3.fromRGB(255,255,255)
		ItemButton.LayoutOrder = ItemData.LayoutOrder or 0
		ItemButton.Visible = true

		-- Button Animation
		ItemButton.MouseEnter:Connect(function()
			TweenService:Create(ItemButton.Frame,TweenInfo.new(0.5,Enum.EasingStyle.Back),{Position = UDim2.new(0,0,0,0),Size = UDim2.new(1,0,1,0)}):Play()
		end)

		ItemButton.MouseLeave:Connect(function()
			TweenService:Create(ItemButton.Frame,TweenInfo.new(0.75,Enum.EasingStyle.Back),{Position = UDim2.new(0,5,0,5),Size = UDim2.new(1,-10,1,-10)}):Play()
		end)

		ItemButton.MouseButton1Click:Connect(function()
			ToReturn = ItemName
		end)
	end

	-- Scrolling Canvas Size
	wait()
	PopSelect.ScrollingFrame.CanvasSize = UDim2.new(0,0,0,PopSelect.ScrollingFrame.UIListLayout.AbsoluteContentSize.Y+5)

	while ToReturn == nil do wait() end
	HidePopUp()

	-- Remove Previous Items
	for _,Item in pairs(PopSelect.ScrollingFrame:GetChildren()) do
		if Item:IsA("ImageButton") and Item.Visible then
			Item:Destroy()
		end
	end

	return ToReturn
end

local function AddToOrder(Item,DefaultInfo,CustomInfo)
	print(CurrentOrder)
	if #CurrentOrder >= 3 then return end
	table.insert(CurrentOrder,{Item = Item,DefaultInfo = DefaultInfo,CustomInfo = CustomInfo})

	local CurrentFrame = itemTemplate:Clone()
	CurrentFrame.Parent = OrderFrame

	local ItemName = DefaultInfo['ItemName']
	if DefaultInfo['Select'] then
		for Type,_ in pairs(DefaultInfo['Select']) do
			ItemName = CustomInfo[Type].." "..ItemName
		end
	end

	CurrentFrame.TopFrame.ItemName.Text = ItemName

	if DefaultInfo['RequiredSelection'] then
		for Type,_ in pairs(DefaultInfo['RequiredSelection']) do
			local CurrentInfoFrame = CurrentFrame.InfoFrameTemplate:Clone()
			CurrentInfoFrame.Parent = CurrentFrame
			CurrentInfoFrame.TextLabel.Text = Type..": "..CustomInfo[Type]
			CurrentInfoFrame.Visible = true
		end
	end

	if DefaultInfo['Options'] then
		for Type,DefaultValue in pairs(DefaultInfo['Options']) do
			if DefaultValue ~= CustomInfo[Type] then
				local CurrentInfoFrame = CurrentFrame.InfoFrameTemplate:Clone()
				CurrentInfoFrame.Parent = CurrentFrame
				if not CustomInfo[Type] then
					CurrentInfoFrame.TextLabel.Text = "- NO "..Type
				else
					CurrentInfoFrame.TextLabel.Text = "+ "..Type
				end
				CurrentInfoFrame.Visible = true
			end
		end
	end

	CurrentFrame.Size = UDim2.new(1,-5,0,CurrentFrame.UIListLayout.AbsoluteContentSize.Y+2)

	CurrentFrame.TopFrame.RemoveItem.MouseButton1Click:Connect(function()
		CurrentFrame:Destroy()
		wait()
		OrderFrame.CanvasSize = UDim2.new(0,0,0,OrderFrame.UIListLayout.AbsoluteContentSize.Y)
		for num,Order in pairs(CurrentOrder) do
			if Order.Item == Item and Order.DefaultInfo == DefaultInfo and Order.CustomInfo == CustomInfo then
				table.remove(CurrentOrder,num)
				break
			end
		end
	end)

	CurrentFrame.Visible = true
	wait()
	OrderFrame.CanvasSize = UDim2.new(0,0,0,OrderFrame.UIListLayout.AbsoluteContentSize.Y)
end

local function AddItemToOrder(Category,Item)
	-- Remove Previous Items
	for _,Item in pairs(PopOptions.ScrollingFrame:GetChildren()) do
		if Item:IsA("Frame") and Item.Visible then
			Item:Destroy()
		end
	end

	local CurrentItemInfo = {}

	local ItemInfo = ProductsData[Category]['Items'][Item]

	if ItemInfo['Select'] then
		for SelectionName,Selection in pairs(ItemInfo['Select']) do
			local CurrentFrame = PopOptions.ScrollingFrame.SelectTemplate:Clone()
			CurrentFrame.Parent = PopOptions.ScrollingFrame
			CurrentFrame.TextLabel.Text = SelectionName
			CurrentFrame.Visible = true
			for i=1, #Selection do
				local Button = CurrentFrame.Selector.Frame.SelectionFrame.Template:Clone()
				Button.Parent = CurrentFrame.Selector.Frame.SelectionFrame
				Button.Size = UDim2.new(1/#Selection,0,1,0)
				Button.TextLabel.Text = Selection[i]
				if i == 1 then
					CurrentItemInfo[SelectionName] = Selection[i]
					Button.BackgroundColor3 = Color3.fromRGB(255, 104, 5)
				else
					Button.TextLabel.TextColor3 = Color3.fromRGB(255, 104, 5)
				end
				if i ~= #Selection then
					local Line = CurrentFrame.Selector.Frame.BarsFrame.Template:Clone()
					Line.Parent = CurrentFrame.Selector.Frame.BarsFrame
					Line.Position = UDim2.new(1/#Selection*i,-1,0,0)
					Line.Visible = true
				end
				Button.Visible = true

				Button.MouseButton1Click:Connect(function()
					for _,ImageButton in pairs(CurrentFrame.Selector.Frame.SelectionFrame:GetChildren()) do
						if ImageButton:IsA("ImageButton") and ImageButton.Visible then
							ImageButton.BackgroundColor3 = Color3.fromRGB(255,255,255)
							ImageButton.TextLabel.TextColor3 = Color3.fromRGB(255, 104, 5)
						end
					end
					CurrentItemInfo[SelectionName] = Selection[i]
					Button.BackgroundColor3 = Color3.fromRGB(255, 104, 5)
					Button.TextLabel.TextColor3 = Color3.fromRGB(255,255,255)
				end)
			end
		end
	end
	if ItemInfo['RequiredSelection'] then
		for SelectionName,Selection in pairs(ItemInfo['RequiredSelection']) do
			CurrentItemInfo[SelectionName] = SelectOption(Category,SelectionName,Selection)
			local CurrentFrame = PopOptions.ScrollingFrame.RequiredSelectionTemplate:Clone()
			CurrentFrame.Parent = PopOptions.ScrollingFrame
			CurrentFrame.TextLabel.Text = SelectionName
			CurrentFrame.Visible = true

			CurrentFrame.ItemInfo.Frame.TextLabel.Text = CurrentItemInfo[SelectionName]
			CurrentFrame.ItemInfo.Frame.BackgroundColor3 = Selection[CurrentItemInfo[SelectionName]].Color

			CurrentFrame.ItemInfo.MouseEnter:Connect(function()
				TweenService:Create(CurrentFrame.ItemInfo.Frame,TweenInfo.new(0.5,Enum.EasingStyle.Back),{Position = UDim2.new(0,0,0,0),Size = UDim2.new(1,0,1,0)}):Play()
			end)

			CurrentFrame.ItemInfo.MouseLeave:Connect(function()
				TweenService:Create(CurrentFrame.ItemInfo.Frame,TweenInfo.new(0.75,Enum.EasingStyle.Back),{Position = UDim2.new(0,5,0,5),Size = UDim2.new(1,-10,1,-10)}):Play()
			end)

			CurrentFrame.ItemInfo.MouseButton1Click:Connect(function()
				CurrentItemInfo[SelectionName] = SelectOption(Category,SelectionName,Selection)
				CurrentFrame.ItemInfo.Frame.TextLabel.Text = CurrentItemInfo[SelectionName]
				CurrentFrame.ItemInfo.Frame.BackgroundColor3 = Selection[CurrentItemInfo[SelectionName]].Color
				ShowPopUp("ItemOptions")
			end)
		end
	end
	if ItemInfo['Options'] then
		for SelectionName,Selection in pairs(ItemInfo['Options']) do
			CurrentItemInfo[SelectionName] = Selection
			local CurrentFrame = PopOptions.ScrollingFrame.OptionsTemplate:Clone()
			CurrentFrame.Parent = PopOptions.ScrollingFrame
			CurrentFrame.TextLabel.Text = SelectionName
			CurrentFrame.Visible = true

			if CurrentItemInfo[SelectionName] then
				CurrentFrame.ItemInfo.Frame.Frame.BackgroundColor3 = Color3.fromRGB(255, 104, 5)
			else
				CurrentFrame.ItemInfo.Frame.Frame.BackgroundColor3 = Color3.fromRGB(204, 204, 204)
			end

			CurrentFrame.ItemInfo.MouseButton1Click:Connect(function()
				CurrentItemInfo[SelectionName] = not CurrentItemInfo[SelectionName]
				if CurrentItemInfo[SelectionName] then
					CurrentFrame.ItemInfo.Frame.Frame.BackgroundColor3 = Color3.fromRGB(255, 104, 5)
				else
					CurrentFrame.ItemInfo.Frame.Frame.BackgroundColor3 = Color3.fromRGB(204, 204, 204)
				end
			end)
		end
	end
	wait()
	ShowPopUp("ItemOptions")
	PopOptions.ScrollingFrame.CanvasSize = UDim2.new(0,0,0,PopOptions.ScrollingFrame.UIListLayout.AbsoluteContentSize.Y or 0)

	if PopOptions.ScrollingFrame.UIListLayout.AbsoluteContentSize.Y == 0 then
		HidePopUp()
		AddToOrder(Item,ItemInfo,CurrentItemInfo)
	else
		local maid = Maid.New()
		maid:GiveTask(PopUp.MouseButton1Click:Connect(function()
			maid:DoCleaning()
			HidePopUp()
		end))

		maid:GiveTask(PopOptions.Button.MouseButton1Click:Connect(function()
			maid:DoCleaning()

			HidePopUp()
			AddToOrder(Item,ItemInfo,CurrentItemInfo)
		end))
	end
end

function PhoneMenuController:Start()
	ProductsData = Boba.Shared.FoodService.FoodTable
	ViewportProvider = Boba.Shared.ViewportProvider
	for categoryName, categoryData in pairs(ProductsData) do
		local currentCategory = categoryTemplate:Clone()
		currentCategory.Parent = MenuFrame
		currentCategory.LayoutOrder = categoryData.LayoutOrder
		currentCategory.TextLabel.Text = categoryName
		currentCategory.Visible = true

		local ItemsFrame = currentCategory.ScrollingFrame
		local itemTemplate = ItemsFrame.Template
		itemTemplate.ViewportFrame.BackgroundColor3 = categoryData.Color
		for itemName,itemData in pairs(categoryData.Items) do
			local currentItem = itemTemplate:Clone()
			currentItem.Parent = ItemsFrame
			currentItem.TextLabel.Text = itemName

			local viewData = itemData.View
			if viewData then
				local model = viewData.Model
				local viewport = currentItem.ViewportFrame
				local direction = viewData.Direction or Enum.NormalId.Left
				local distance = viewData.ModelDistance or 0.5
				ViewportProvider(viewport,model,direction,distance)
			end
			currentItem.Visible = true

			currentItem.MouseButton1Click:Connect(function()
				AddItemToOrder(categoryName,itemName)
			end)
		end
		wait()
		ItemsFrame.Changed:Connect(function()
			ItemsFrame.CanvasSize = UDim2.new(0,ItemsFrame.UIListLayout.AbsoluteContentSize.X,0,0)
		end)
	end

	wait()
	MenuFrame.Changed:Connect(function()
		MenuFrame.CanvasSize = UDim2.new(0,0,0,MenuFrame.UIListLayout.AbsoluteContentSize.Y)
	end)
end

function PhoneMenuController:Init()
	ReplicaController.ReplicaOfClassCreated("PhoneServiceReplica", function(replica)
		PhoneServiceReplica = replica
	end)
end

return PhoneMenuController
