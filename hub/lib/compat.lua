local Compat = {}

function Compat.compile(source, chunkName)
	if typeof(source) ~= "string" or #source == 0 then
		return nil, "empty source"
	end

	if typeof(loadstring) == "function" then
		local fn, err = loadstring(source, chunkName)
		if fn then
			return fn, nil
		end
		if typeof(load) == "function" then
			return load(source, chunkName)
		end
		return nil, err
	end

	if typeof(load) == "function" then
		return load(source, chunkName)
	end

	return nil, "executor missing loadstring/load"
end

function Compat.httpGet(url)
	local lastError = "unknown error"

	local function try(label, callback)
		local ok, result = pcall(callback)
		if ok and typeof(result) == "string" and #result > 0 then
			return result
		end
		lastError = ok and "empty response" or tostring(result)
		return nil
	end

	local 	body = try("game:HttpGet", function()
		return game:HttpGet(url)
	end)
	if body then
		return true, body
	end

	body = try("game.HttpGet", function()
		return game.HttpGet(game, url)
	end)
	if body then
		return true, body
	end

	if syn and typeof(syn.request) == "function" then
		body = try("syn.request", function()
			return syn.request({ Url = url, Method = "GET" }).Body
		end)
		if body then
			return true, body
		end
	end

	if typeof(request) == "function" then
		body = try("request", function()
			return request({ Url = url, Method = "GET" }).Body
		end)
		if body then
			return true, body
		end
	end

	if typeof(http_request) == "function" then
		body = try("http_request", function()
			return http_request({ Url = url, Method = "GET" }).Body
		end)
		if body then
			return true, body
		end
	end

	local HttpService = game:GetService("HttpService")
	body = try("HttpService", function()
		return HttpService:GetAsync(url)
	end)
	if body then
		return true, body
	end

	return false, lastError
end

function Compat.runSource(source, chunkName)
	local fn, compileError = Compat.compile(source, chunkName)
	if not fn then
		return false, compileError
	end

	local ok, runError = pcall(fn)
	if not ok then
		return false, runError
	end

	return true
end

function Compat.runUrl(url, chunkName)
	local ok, source = Compat.httpGet(url)
	if not ok then
		return false, "HttpGet failed for " .. url .. ": " .. tostring(source)
	end

	return Compat.runSource(source, chunkName)
end

return Compat
