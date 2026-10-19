local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local OrderSpec = require(Shared.Ordering.OrderSpec)
local CustomerConfig = require(Shared.Configuration.CustomerConfig)

local Content = {}

Content.Tips = [[Clock in to use the kitchen.

Match the size and flavor on the ticket.

Perfect drinks pay the most.]]

-- RichText for every item NPCs can order, generated from OrderSpec.Steps.
function Content.build(): string
	local blocks = {}
	local seen = {}
	for _, entry in CustomerConfig.ORDER_POOL do
		local orderItem = entry.OrderItem
		if seen[orderItem.Item] then
			continue
		end
		seen[orderItem.Item] = true

		-- Sized entries get their Size when an order is picked; any size shows the same steps.
		local customInfo = table.clone(orderItem.CustomInfo or {})
		if entry.Sized and customInfo.Size == nil then
			customInfo.Size = "Medium"
		end
		local spec = OrderSpec.FromOrderItem({
			Category = orderItem.Category,
			Item = orderItem.Item,
			CustomInfo = customInfo,
		})
		if spec == nil then
			continue
		end

		local lines = { "<b>" .. orderItem.Item .. "</b>" }
		local rows = OrderSpec.Steps(spec)
		if #rows == 0 then
			table.insert(lines, '<font face="DenkOne">Grab it from the display.</font>')
		else
			for index, row in rows do
				table.insert(lines, `<font face="DenkOne">{index}. {row.Label}</font>`)
			end
		end
		table.insert(blocks, table.concat(lines, "\n"))
	end
	return table.concat(blocks, "\n\n")
end

return Content
