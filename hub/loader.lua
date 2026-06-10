--[[
	MicroHub loader — matches game.PlaceId and runs the correct game script.
]]

local Compat = nil
local Bootstrap = nil

local INLINE_CONFIG = {
	Name = "MicroHub",
	Version = "1.0.0",
	Repository = "https://raw.githubusercontent.com/sysscan/microhub/main/hub",
	HttpRetries = 2,
}

local function getLocalRoot()
	local genv = getgenv and getgenv() or _G
	if typeof(genv.HUB_LOCAL_ROOT) == "string" and genv.HUB_LOCAL_ROOT ~= "" then
		return genv.HUB_LOCAL_ROOT:gsub("/+$", "")
	end
	return "hub"
end

local function useLocalMode()
	local genv = getgenv and getgenv() or _G
	if genv.HUB_LOCAL == true then
		return true
	end
	if typeof(readfile) == "function" and typeof(isfile) == "function" then
		local root = getLocalRoot()
		return isfile(root .. "/config.lua") and isfile(root .. "/manifest.lua")
	end
	return false
end

local function readLocalFile(relativePath)
	if typeof(readfile) ~= "function" or typeof(isfile) ~= "function" then
		return nil
	end
	local path = getLocalRoot() .. "/" .. relativePath
	if not isfile(path) then
		return nil
	end
	local ok, source = pcall(readfile, path)
	if ok and typeof(source) == "string" and #source > 0 then
		return source
	end
	return nil
end

local function loadCompatModule(repo)
	if Compat then
		return true
	end

	local source = readLocalFile("lib/compat.lua")
	if not source then
		local ok, remoteSource = pcall(function()
			return game:HttpGet(repo .. "/lib/compat.lua")
		end)
		if ok and typeof(remoteSource) == "string" and #remoteSource > 0 then
			source = remoteSource
		elseif syn and syn.request then
			ok, remoteSource = pcall(function()
				return syn.request({ Url = repo .. "/lib/compat.lua", Method = "GET" }).Body
			end)
			if ok and typeof(remoteSource) == "string" and #remoteSource > 0 then
				source = remoteSource
			end
		end
	end

	if not source then
		return false, "failed to fetch compat"
	end

	local fn, err
	if typeof(loadstring) == "function" then
		fn, err = loadstring(source, "MicroHub.Compat")
	elseif typeof(load) == "function" then
		fn, err = load(source, "MicroHub.Compat")
	else
		return false, "executor missing loadstring/load"
	end

	if not fn then
		return false, err
	end

	local moduleOk, module = pcall(fn)
	if not moduleOk or typeof(module) ~= "table" then
		return false, "compat did not return a table"
	end

	Compat = module
	return true
end

local function loadBootstrap(repo, retries)
	if Bootstrap then
		return true
	end

	local source = readLocalFile("lib/bootstrap.lua")
	if not source then
		local ok, remoteSource = Compat.httpGet(repo .. "/lib/bootstrap.lua")
		if ok and typeof(remoteSource) == "string" and #remoteSource > 0 then
			source = remoteSource
		end
	end

	if not source then
		return false, "failed to fetch bootstrap"
	end

	local fn, err = Compat.compile(source, "MicroHub.Bootstrap")
	if not fn then
		return false, err
	end

	local moduleOk, module = pcall(fn)
	if not moduleOk or typeof(module) ~= "table" then
		return false, "bootstrap did not return a table"
	end

	Bootstrap = module
	if useLocalMode() then
		Bootstrap.setLocalRoot(getLocalRoot())
	end
	return true
end

local function fetchTableModule(repo, relativePath, chunkName, retries)
	local source = Bootstrap.readLocal(relativePath)
	if not source then
		local ok, remoteSource = Compat.httpGet(repo .. "/" .. relativePath)
		if not ok then
			return false, remoteSource
		end
		source = remoteSource
	end

	return Bootstrap.loadTableModule(source, chunkName)
end

local function resolveRepository()
	local genv = getgenv and getgenv() or _G
	if typeof(genv.HUB_REPO) == "string" and genv.HUB_REPO ~= "" then
		return genv.HUB_REPO:gsub("/+$", "")
	end
	return INLINE_CONFIG.Repository
end

local function loadConfig(repo)
	local config = INLINE_CONFIG
	local configSource = readLocalFile("config.lua")

	if not configSource then
		local ok, remoteSource = Compat.httpGet(repo .. "/config.lua")
		if ok and typeof(remoteSource) == "string" and #remoteSource > 0 then
			configSource = remoteSource
		end
	end

	if configSource then
		local fn, err = Compat.compile(configSource, "MicroHub.Config")
		if fn then
			local runOk, value = pcall(fn)
			if runOk and typeof(value) == "table" then
				config = value
			end
		end
	end

	return config, config.Repository or repo
end

local function runLoader()
	local repo = resolveRepository()

	local compatOk, compatErr = loadCompatModule(repo)
	if not compatOk then
		warn("[MicroHub] Compat error:", compatErr)
		return
	end

	local config, activeRepo = loadConfig(repo)
	repo = activeRepo

	local bootOk, bootErr = loadBootstrap(repo, config.HttpRetries or 2)
	if not bootOk then
		warn("[MicroHub] Bootstrap error:", bootErr)
		return
	end

	if Bootstrap.isLoaded(config.Name) then
		Bootstrap.notify(config.Name, "Already loaded", 3)
		return
	end

	local manifestOk, manifest = fetchTableModule(repo, "manifest.lua", "MicroHub.Manifest", config.HttpRetries or 2)
	if not manifestOk then
		Bootstrap.notify(config.Name, "Manifest failed: " .. tostring(manifest), 6)
		return
	end

	local placeId = game.PlaceId
	local index = Bootstrap.buildPlaceIdIndex(manifest)
	local entry = index[placeId]

	if not entry then
		Bootstrap.notify(
			config.Name,
			string.format("Unsupported game (PlaceId %s)", tostring(placeId)),
			7
		)
		warn(string.format("[%s] Unsupported PlaceId: %s", config.Name, tostring(placeId)))
		return
	end

	local modulePath = entry.module
	if typeof(modulePath) ~= "string" or modulePath == "" then
		Bootstrap.notify(config.Name, "Invalid manifest entry", 5)
		return
	end

	Bootstrap.notify(
		config.Name,
		string.format("Loading %s v%s", entry.name or "script", entry.version or config.Version),
		3
	)

	local scriptOk, scriptSource = Bootstrap.fetchModule(repo, modulePath, config.HttpRetries or 2)
	if not scriptOk then
		Bootstrap.notify(config.Name, "Script fetch failed", 6)
		warn(string.format("[%s] Fetch failed for %s: %s", config.Name, modulePath, tostring(scriptSource)))
		return
	end

	local loadOk, loadErr = Bootstrap.loadSource(scriptSource, "MicroHub.Game." .. (entry.name or "Unknown"))
	if not loadOk then
		Bootstrap.notify(config.Name, "Script error (see console)", 6)
		warn(string.format("[%s] Runtime error in %s: %s", config.Name, modulePath, tostring(loadErr)))
		return
	end

	Bootstrap.markLoaded(config.Name)
	Bootstrap.notify(config.Name, string.format("%s loaded", entry.name or "Game"), 4)
end

local ok, err = pcall(runLoader)
if not ok then
	warn("[MicroHub] Loader crashed:", err)
end
