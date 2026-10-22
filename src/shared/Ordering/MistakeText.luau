--!strict
--[[
	MistakeText.luau (REVIVAL-001 AUDIT-FIX D1.3)
	Plain-language text for an order mistake, in the FEEDBACK-VOICE style: short,
	sentence case, no exclamation mark, at most 60 characters for normal values.

	`Field(field, wanted)` takes an OrderSpec reason ("Item", "Size", "Syrup",
	"Tapioca", "Iced", "Sugar", "Missing", "PoorPour") and the value the customer
	wanted (a string, a boolean for Iced/Sugar, or nil when unknown).
	`FromSpec(reason, spec)` reads the wanted value from an OrderSpec. Pure: the
	server uses it for serve toasts, the tablet for a mismatched order.
--]]

local MistakeText = {}

local GENERIC = "That isn't what they ordered."

function MistakeText.Field(field: string?, wanted: any?): string
	local hasWanted = typeof(wanted) == "string" and wanted ~= ""
	if field == "Item" then
		return if hasWanted then `Wrong item: they wanted {wanted}` else "Wrong item for this order."
	elseif field == "Size" then
		return if hasWanted then `Wrong size: they wanted {wanted}` else "Wrong size for this order."
	elseif field == "Syrup" then
		return if hasWanted then `Wrong syrup: they wanted {wanted}` else "Wrong syrup for this order."
	elseif field == "Tapioca" then
		return if hasWanted then `Wrong tapioca: they wanted {wanted}` else "Wrong tapioca for this order."
	elseif field == "Iced" then
		if wanted == true then
			return "Missing ice: they wanted it iced"
		elseif wanted == false then
			return "Too much ice: they wanted no ice"
		end
		return "Wrong ice for this order."
	elseif field == "Sugar" then
		if wanted == true then
			return "Missing sugar: they wanted sugar"
		elseif wanted == false then
			return "Extra sugar: they wanted no sugar"
		end
		return "Wrong sugar for this order."
	elseif field == "Missing" then
		return "Something from the order is missing."
	elseif field == "PoorPour" then
		return "Messy pour: stop the pour in the green"
	elseif field == "Count" then
		return if typeof(wanted) == "number"
			then `Wrong count: they wanted {wanted} item{if wanted == 1 then "" else "s"}`
			else "Wrong number of items."
	end
	return GENERIC
end

function MistakeText.FromSpec(reason: string?, spec: { [string]: any }?): string
	if spec == nil or reason == nil then
		return MistakeText.Field(reason, nil)
	end
	if reason == "Item" then
		return MistakeText.Field(reason, spec.Label or spec.Item)
	end
	return MistakeText.Field(reason, spec[reason])
end

return MistakeText
