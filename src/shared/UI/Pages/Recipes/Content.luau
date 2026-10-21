local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local OrderSpec = require(Shared.Ordering.OrderSpec)
local CustomerConfig = require(Shared.Configuration.CustomerConfig)

local Content = {}

Content.Tips = [[Clock in to use the kitchen.

Match the size and flavor on the ticket.

Perfect drinks pay the most.]]

local LOCKED_TRANSPARENCY = 0.35 -- STYLE 3.3 disabled text

-- RichText for every drink NPCs can order, generated from OrderSpec.Steps. One block per
-- ORDER_POOL entry (deduped by Key). Drinks above `level` show "Unlocks at Level N" dimmed and
-- sit last. Order: focused unlocked blocks, other unlocked blocks, then locked by level.
function Content.build(focusItem: string?, level: number?): string
	local playerLevel = level or 1
	local focused = {}
	local unlocked = {}
	local locked = {}
	local seen = {}
	for index, entry in CustomerConfig.ORDER_POOL do
		local orderItem = entry.OrderItem
		local key = entry.Key or orderItem.Item
		if seen[key] then
			continue
		end
		seen[key] = true
		local title = entry.Label or orderItem.Item

		if entry.MinLevel > playerLevel then
			local text = `<font transparency="{LOCKED_TRANSPARENCY}"><b>{title}</b>\n`
				.. `<font face="DenkOne">Unlocks at Level {entry.MinLevel}</font></font>`
			table.insert(locked, { Text = text, MinLevel = entry.MinLevel, Index = index })
			continue
		end

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

		local lines = { "<b>" .. title .. "</b>" }
		local rows = OrderSpec.Steps(spec)
		if #rows == 0 then
			table.insert(lines, '<font face="DenkOne">Grab it from the display.</font>')
		else
			for stepIndex, row in rows do
				table.insert(lines, `<font face="DenkOne">{stepIndex}. {row.Label}</font>`)
			end
		end
		table.insert(
			if focusItem ~= nil and orderItem.Item == focusItem then focused else unlocked,
			table.concat(lines, "\n")
		)
	end

	table.sort(locked, function(a, b)
		if a.MinLevel ~= b.MinLevel then
			return a.MinLevel < b.MinLevel
		end
		return a.Index < b.Index
	end)

	local blocks = {}
	table.move(focused, 1, #focused, #blocks + 1, blocks)
	table.move(unlocked, 1, #unlocked, #blocks + 1, blocks)
	for _, block in locked do
		table.insert(blocks, block.Text)
	end
	return table.concat(blocks, "\n\n")
end

return Content
