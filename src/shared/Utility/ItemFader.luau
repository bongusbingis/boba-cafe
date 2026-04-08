local TweenService = game:GetService("TweenService")

local ItemFader = {}
ItemFader.__index = ItemFader

function ItemFader.new()
	local self = setmetatable({}, ItemFader)

	self._fadeTime = 0.5
	self._items = {}

	return self
end

function ItemFader:AddItem(item)
	if item:IsA("Model") then
		for _, descendant in item:GetDescendants() do
			if descendant:IsA("BasePart") then
				table.insert(self._items, { Item = descendant, Transparency = descendant.Transparency })
			end
		end
	else
		table.insert(self._items, { Item = item, Transparency = item.Transparency })
	end
end

function ItemFader:FadeOut()
	for _, item in self._items do
		local Tween =
			TweenService:Create(item.Item, TweenInfo.new(self._fadeTime, Enum.EasingStyle.Linear), { Transparency = 1 })

		Tween:Play()

		Tween.Completed:Connect(function()
			Tween:Destroy()
		end)
	end
end

function ItemFader:FadeIn()
	for _, item in self._items do
		local Tween = TweenService:Create(
			item.Item,
			TweenInfo.new(self._fadeTime, Enum.EasingStyle.Linear),
			{ Transparency = item.Transparency }
		)

		Tween:Play()

		Tween.Completed:Connect(function()
			Tween:Destroy()
		end)
	end
end

function ItemFader:Destroy()
	self = nil
end

return ItemFader
