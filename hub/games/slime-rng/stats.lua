local M = {}

function M.create(opts)
	local services = opts.services

	local function abbreviate(value)
		local Abbreviate = services.getAbbreviate()
		if Abbreviate then
			local ok, text = pcall(Abbreviate, value)
			if ok and text then
				return tostring(text)
			end
		end
		return tostring(value)
	end

	local function hudLines()
		local client = services.getDataClient()
		if not client then
			return {}
		end

		local lines = {}
		local coins = client:get("coins")
		local goop = client:get("goop")
		local rebirths = client:get("rebirths")
		local zone = client:get("zone")
		local maxZone = client:get("maxZone")
		local furthestZone = client:get("furthestZone")

		if coins ~= nil then
			table.insert(lines, "Coins: " .. abbreviate(coins))
		end
		if goop ~= nil then
			table.insert(lines, "Goop: " .. abbreviate(goop))
		end
		if rebirths ~= nil then
			table.insert(lines, "Rebirths: " .. tostring(rebirths))
		end
		if zone ~= nil then
			table.insert(lines, "Zone: " .. tostring(zone))
		end
		if maxZone ~= nil then
			table.insert(lines, "Max Zone: " .. tostring(maxZone))
		end
		if furthestZone ~= nil then
			table.insert(lines, "Furthest: " .. tostring(furthestZone))
		end

		local RollSlice = services.getRollSlice()
		if RollSlice and RollSlice.luck then
			local ok, luck = pcall(RollSlice.luck)
			if ok and luck then
				table.insert(lines, "Luck: " .. abbreviate(luck))
			end
		end

		return lines
	end

	return {
		abbreviate = abbreviate,
		hudLines = hudLines,
	}
end

return M
