--[[
	MicroHub runtime — fetch, load, and unload hub modules.
	Default: always HTTP from GitHub. Set HUB_USE_LOCAL = true to read workspace files.
]]

local Runtime = {
	_config = nil,
	_base = nil,
	_localRoot = "hub",
	_modules = {},
}

local function getGenv()
	return getgenv and getgenv() or _G
end

function Runtime.getGenv()
	return getGenv()
end

function Runtime.useLocal()
	local genv = getGenv()
	return genv.HUB_USE_LOCAL == true
		and typeof(readfile) == "function"
		and typeof(isfile) == "function"
end

function Runtime.init(config)
	Runtime._config = config or {}
	Runtime._base = Runtime._config.Repository or "https://raw.githubusercontent.com/sysscan/microhub/main/hub"
	local root = getGenv().HUB_LOCAL_ROOT
	if typeof(root) == "string" and root ~= "" then
		Runtime._localRoot = root:gsub("/+$", "")
	end
	getGenv().__MicroHub = Runtime
	return Runtime
end

function Runtime.sanitize(source)
	if typeof(source) ~= "string" then
		return source
	end
	while #source >= 3 and source:byte(1) == 0xEF and source:byte(2) == 0xBB and source:byte(3) == 0xBF do
		source = source:sub(4)
	end
	return source
end

function Runtime.fetchHttp(path)
	if typeof(request) ~= "function" then
		error("request() unavailable — cannot fetch " .. path, 0)
	end
	local url = Runtime._base .. "/" .. path .. "?t=" .. tostring(os.time())
	local res = request({ Url = url, Method = "GET" })
	if res and res.Success and typeof(res.Body) == "string" and #res.Body > 0 then
		return Runtime.sanitize(res.Body)
	end
	local msg = res and (res.StatusMessage or res.StatusCode) or "no response"
	error("HTTP failed (" .. tostring(msg) .. "): " .. url, 0)
end

function Runtime.readLocal(path)
	local localPath = Runtime._localRoot .. "/" .. path
	if not isfile(localPath) then
		return nil
	end
	return Runtime.sanitize(readfile(localPath))
end

function Runtime.fetch(path)
	if Runtime.useLocal() then
		local source = Runtime.readLocal(path)
		if source then
			return source, "local"
		end
		error("local file missing: " .. Runtime._localRoot .. "/" .. path, 0)
	end
	return Runtime.fetchHttp(path), "remote"
end

function Runtime.compile(source, chunkName)
	local fn, err = loadstring(Runtime.sanitize(source), chunkName or "MicroHub")
	if not fn then
		error("compile " .. tostring(chunkName) .. ": " .. tostring(err), 0)
	end
	return fn
end

function Runtime.run(path)
	local source, origin = Runtime.fetch(path)
	local fn = Runtime.compile(source, path)
	local ok, runErr = pcall(fn)
	if not ok then
		error("run " .. path .. ": " .. tostring(runErr), 0)
	end
	return origin
end

function Runtime.loadTable(path)
	local source = Runtime.fetch(path)
	local fn = Runtime.compile(source, path)
	local ok, result = pcall(fn)
	if not ok then
		error("run " .. path .. ": " .. tostring(result), 0)
	end
	if typeof(result) ~= "table" then
		error(path .. " must return a table", 0)
	end
	return result
end

function Runtime.unloadModule(id)
	local mod = Runtime._modules[id]
	if typeof(mod) == "table" and typeof(mod.stop) == "function" then
		pcall(mod.stop)
	end
	Runtime._modules[id] = nil
	if id == "bronx3-ac-debug" then
		getGenv().__Bronx3ACDebug = nil
	end
end

function Runtime.unloadAll()
	for id in pairs(Runtime._modules) do
		Runtime.unloadModule(id)
	end

	local genv = getGenv()
	local legacy = genv.__Bronx3ACDebug
	if typeof(legacy) == "table" and typeof(legacy.stop) == "function" then
		pcall(legacy.stop)
	end
	genv.__Bronx3ACDebug = nil
	genv.__Bronx3ACDebugAutoStart = nil
	genv.__Bronx3ACDebugContext = nil

	local unloadGame = genv.__ThaBronx3Unload
	if typeof(unloadGame) == "function" then
		pcall(unloadGame)
	end
	genv.__ThaBronx3Unload = nil
	genv.__ThaBronx3FlyStep = nil
end

function Runtime.loadModule(path, id)
	id = id or path
	Runtime.unloadModule(id)

	local source = Runtime.fetch(path)
	local fn = Runtime.compile(source, path)
	local ok, result = pcall(fn)
	if not ok then
		error("run " .. path .. ": " .. tostring(result), 0)
	end

	local mod = getGenv().__Bronx3ACDebug or result
	if typeof(mod) ~= "table" then
		error(path .. " must return a table module", 0)
	end

	Runtime._modules[id] = mod
	return mod
end

function Runtime.getConfig()
	return Runtime._config
end

return Runtime
