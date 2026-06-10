local Bootstrap = {}

local LOADED_KEY = "__HubLoaded"
Bootstrap.localRoot = nil

function Bootstrap.isLoaded(hubName)
	return shared[LOADED_KEY] == hubName
end

function Bootstrap.markLoaded(hubName)
	shared[LOADED_KEY] = hubName
end

function Bootstrap.setLocalRoot(root)
	if typeof(root) == "string" and root ~= "" then
		Bootstrap.localRoot = root:gsub("/+$", "")
	end
end

function Bootstrap.canReadLocal()
	return typeof(readfile) == "function" and typeof(isfile) == "function"
end

function Bootstrap.readLocal(relativePath)
	if not Bootstrap.localRoot or not Bootstrap.canReadLocal() then
		return nil
	end

	local path = Bootstrap.localRoot .. "/" .. relativePath
	if isfile(path) then
		local ok, source = pcall(readfile, path)
		if ok and typeof(source) == "string" and #source > 0 then
			return source
		end
	end

	return nil
end

function Bootstrap.notify(title, text, duration)
	duration = duration or 5
	if typeof(game) ~= "Instance" then
		return
	end

	local ok = pcall(function()
		local StarterGui = game:GetService("StarterGui")
		StarterGui:SetCore("SendNotification", {
			Title = title,
			Text = text,
			Duration = duration,
		})
	end)

	if not ok then
		warn(string.format("[%s] %s", title, text))
	end
end

function Bootstrap.httpGet(url, retries)
	retries = retries or 2
	local lastError = "unknown error"

	for attempt = 1, retries + 1 do
		local ok, result = pcall(function()
			return game:HttpGet(url)
		end)

		if ok and typeof(result) == "string" and #result > 0 then
			return true, result
		end

		lastError = ok and "empty response" or tostring(result)

		if syn and syn.request then
			ok, result = pcall(function()
				return syn.request({ Url = url, Method = "GET" }).Body
			end)
			if ok and typeof(result) == "string" and #result > 0 then
				return true, result
			end
			lastError = ok and "empty response" or tostring(result)
		end

		if typeof(request) == "function" then
			ok, result = pcall(function()
				return request({ Url = url, Method = "GET" }).Body
			end)
			if ok and typeof(result) == "string" and #result > 0 then
				return true, result
			end
			lastError = ok and "empty response" or tostring(result)
		end

		if attempt <= retries then
			task.wait(0.35 * attempt)
		end
	end

	return false, lastError
end

function Bootstrap.fetchModule(baseUrl, relativePath, retries)
	local localSource = Bootstrap.readLocal(relativePath)
	if localSource then
		return true, localSource
	end

	local url = baseUrl .. "/" .. relativePath
	local ok, source = Bootstrap.httpGet(url, retries)
	if not ok then
		return false, source
	end
	return true, source
end

function Bootstrap.loadTableModule(source, chunkName)
	local fn, compileError
	if typeof(loadstring) == "function" then
		fn, compileError = loadstring(source, chunkName)
	elseif typeof(load) == "function" then
		fn, compileError = load(source, chunkName)
	else
		return false, "executor missing loadstring/load"
	end

	if not fn then
		return false, compileError
	end

	local runOk, value = pcall(fn)
	if not runOk then
		return false, value
	end

	if typeof(value) ~= "table" then
		return false, chunkName .. " must return a table"
	end

	return true, value
end

function Bootstrap.loadSource(source, chunkName)
	local fn, compileError
	if typeof(loadstring) == "function" then
		fn, compileError = loadstring(source, chunkName)
	elseif typeof(load) == "function" then
		fn, compileError = load(source, chunkName)
	else
		return false, "executor missing loadstring/load"
	end

	if not fn then
		return false, compileError
	end

	local ok, runError = pcall(fn)
	if not ok then
		return false, runError
	end

	return true
end

function Bootstrap.buildPlaceIdIndex(manifest)
	local index = {}

	for _, entry in ipairs(manifest) do
		if typeof(entry) == "table" and typeof(entry.placeIds) == "table" then
			for _, placeId in ipairs(entry.placeIds) do
				index[placeId] = entry
			end
		end
	end

	return index
end

return Bootstrap
