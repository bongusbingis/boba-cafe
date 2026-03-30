--!strict

local EMPTY_TABLE = {}

return function <key, value>(...: { [key]: value}?): { [key]: value}
	local finalDict
	local didChange = false

	for i = 1, select("#", ...) do
		local dict = select(i, ...)
		if dict and next(dict) then
			if not finalDict then
				finalDict = dict
			else
				if not didChange then
					finalDict = table.clone(finalDict)
					didChange = true
				end
				for k, v in dict do
					finalDict[k] = v
				end
			end
		end
	end

	return finalDict or EMPTY_TABLE
end