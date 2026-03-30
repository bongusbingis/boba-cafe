--!strict

return function(default: number?)
	local layoutOrder = default or 0

	return function()
		layoutOrder += 1
		return layoutOrder
	end
end
