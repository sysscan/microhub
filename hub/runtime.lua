--[[
	MicroHub runtime — shared fetch/load/registry for loader and game scripts.
	Loaded once by loader.lua into getgenv().__MicroHub.
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

function Runtime.init(config)
	Runtime._config = config or {}
	Runtime._base = Runtime._config.Repository or "https://raw.githubusercontent.com/sysscan/microhub/main/hub"
	local root = getGenv().HUB_LOCAL_ROOT
	if typeof(root) == "string" and root ~= "" then
		Runtime._localRoot = root:gsub("/+$", "")
	end
	getGenv().__MicroHub = Runtime
	Runtime.purgeStaleLocals()
	return Runtime
end

function Runtime.purgeStaleLocals()
	local versions = Runtime._config.ModuleVersions
	if typeof(versions) ~= "table" then
		return
	end
	for path, version in pairs(versions) do
		if typeof(version) == "string" and version ~= "" then
			local localPath = Runtime._localRoot .. "/" .. path
			if typeof(isfile) == "function" and isfile(localPath) then
				local localSource = Runtime.readLocal(path)
				if localSource and not Runtime.sourceHasVersion(localSource, version) then
					warn("[MicroHub] purging stale local cache:", localPath, "(need " .. version .. ")")
					if typeof(delfile) == "function" then
						pcall(delfile, localPath)
					end
				end
			end
		end
	end
end

function Runtime.useLocal()
	local genv = getGenv()
	return genv.HUB_USE_LOCAL == true and genv.HUB_FORCE_REMOTE ~= true
end

function Runtime.hasUtf8Bom(source)
	return typeof(source) == "string"
		and #source >= 3
		and source:byte(1) == 0xEF
		and source:byte(2) == 0xBB
		and source:byte(3) == 0xBF
end

function Runtime.sanitize(source)
	if typeof(source) ~= "string" then
		return source
	end
	while Runtime.hasUtf8Bom(source) do
		source = source:sub(4)
	end
	return source
end

function Runtime.expectedVersion(path)
	local versions = Runtime._config and Runtime._config.ModuleVersions
	if typeof(versions) ~= "table" then
		return nil
	end
	return versions[path]
end

function Runtime.sourceHasVersion(source, version)
	return typeof(version) == "string"
		and version ~= ""
		and typeof(source) == "string"
		and source:find(version, 1, true) ~= nil
end

function Runtime.ensureParentDirs(filePath)
	if typeof(isfolder) ~= "function" or typeof(makefolder) ~= "function" then
		return
	end
	local acc = ""
	for part in string.gmatch(filePath, "[^/]+") do
		local nextPath = acc == "" and part or (acc .. "/" .. part)
		if nextPath ~= filePath and not isfolder(nextPath) then
			pcall(makefolder, nextPath)
		end
		acc = nextPath
	end
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
	if typeof(readfile) ~= "function" or typeof(isfile) ~= "function" or not isfile(localPath) then
		return nil
	end
	return Runtime.sanitize(readfile(localPath))
end

function Runtime.writeLocal(path, source)
	if typeof(writefile) ~= "function" then
		return false
	end
	local localPath = Runtime._localRoot .. "/" .. path
	Runtime.ensureParentDirs(localPath)
	local ok = pcall(writefile, localPath, source)
	return ok
end

function Runtime.fetch(path, opts)
	opts = opts or {}
	local version = opts.version or Runtime.expectedVersion(path)
	local forceRemote = opts.forceRemote == true
		or getGenv().HUB_FORCE_REMOTE == true
		or (typeof(version) == "string" and version ~= "" and not Runtime.useLocal())

	if not forceRemote and Runtime.useLocal() then
		local localSource = Runtime.readLocal(path)
		if localSource then
			if Runtime.hasUtf8Bom(localSource) then
				warn("[MicroHub] BOM in local file, refetching:", path)
			elseif not version or Runtime.sourceHasVersion(localSource, version) then
				return localSource, "local"
			else
				warn("[MicroHub] stale local file (need " .. version .. "):", path)
			end
		end
	end

	local source = Runtime.fetchHttp(path)
	if version and not Runtime.sourceHasVersion(source, version) then
		error(path .. " from remote is missing version marker " .. version, 0)
	end

	if opts.cache ~= false then
		Runtime.writeLocal(path, source)
	end
	return source, "remote"
end

function Runtime.compile(source, chunkName)
	local fn, err = loadstring(Runtime.sanitize(source), chunkName or "MicroHub")
	if not fn then
		error("compile " .. tostring(chunkName) .. ": " .. tostring(err), 0)
	end
	return fn
end

function Runtime.run(path, opts)
	local source, origin = Runtime.fetch(path, opts)
	local fn = Runtime.compile(source, path)
	local ok, runErr = pcall(fn)
	if not ok then
		error("run " .. path .. ": " .. tostring(runErr), 0)
	end
	return origin
end

function Runtime.loadTable(path, opts)
	local source = Runtime.fetch(path, opts)
	local fn = Runtime.compile(source, path)
	local ok, result = pcall(fn)
	if not ok then
		error("run " .. path .. ": " .. tostring(result), 0)
	end
	if typeof(result) ~= "table" then
		error(path .. " must return a table", 0)
	end
	return result, source
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
end

function Runtime.loadModule(path, id, opts)
	opts = opts or {}
	id = id or path
	local expected = opts.version or Runtime.expectedVersion(path)
	if typeof(expected) == "string" and expected ~= "" then
		opts.forceRemote = true
		opts.version = expected
	end
	Runtime.unloadModule(id)

	local source = Runtime.fetch(path, {
		version = opts.version,
		forceRemote = opts.forceRemote,
		cache = opts.cache,
	})
	local fn = Runtime.compile(source, path)
	local ok, result = pcall(fn)
	if not ok then
		error("run " .. path .. ": " .. tostring(result), 0)
	end

	local mod = getGenv().__Bronx3ACDebug or result
	if typeof(mod) ~= "table" then
		error(path .. " must return a table module", 0)
	end

	if opts.validate and expected and typeof(mod.getVersion) == "function" then
		if mod.getVersion() ~= expected then
			error(path .. " version mismatch (got " .. tostring(mod.getVersion()) .. ", need " .. expected .. ")", 0)
		end
	end

	Runtime._modules[id] = mod
	return mod
end

function Runtime.getConfig()
	return Runtime._config
end

return Runtime
