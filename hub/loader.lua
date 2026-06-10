--[[
	MicroHub loader — paste once in Volt, re-run anytime to reload.

	Docs: https://docs.voltbz.net/docs/miscellaneous (request)

	Default: every file is fetched from GitHub. Nothing is cached to your workspace.
	Dev mode: getgenv().HUB_USE_LOCAL = true  (read hub/ from executor workspace)
]]

local LOADER_VERSION = 8
local DEFAULT_BASE = "https://raw.githubusercontent.com/sysscan/microhub/main/hub"
local LOADED_KEY = "__MicroHubLoaded"
local UI_LIB_KEY = "__MicroHubUILib"

local KNOWN_GAME_LIST = {
	{ name = "Warfare", module = "games/warfare.lua", placeIds = { 83902709332473 } },
	{ name = "Tha Bronx 3", module = "games/tha-bronx3.lua", placeIds = { 16472538603, 18642421777 } },
}

local KNOWN_GAMES_BY_ID = {}
for _, entry in ipairs(KNOWN_GAME_LIST) do
	for _, id in ipairs(entry.placeIds) do
		KNOWN_GAMES_BY_ID[id] = entry
		KNOWN_GAMES_BY_ID[tostring(id)] = entry
	end
end

local function getGenv()
	return getgenv and getgenv() or _G
end

local function notify(title, text, duration)
	pcall(function()
		game:GetService("StarterGui"):SetCore("SendNotification", {
			Title = title,
			Text = text,
			Duration = duration or 5,
		})
	end)
end

local function sanitize(source)
	if typeof(source) ~= "string" then
		return source
	end
	while #source >= 3 and source:byte(1) == 0xEF and source:byte(2) == 0xBB and source:byte(3) == 0xBF do
		source = source:sub(4)
	end
	return source
end

local function cacheBust()
	return tostring(os.time()) .. "_" .. tostring(math.random(100000, 999999999))
end

local function fetchHttp(base, path)
	local url = base .. "/" .. path .. "?t=" .. cacheBust()
	local res = request({
		Url = url,
		Method = "GET",
		Headers = { ["Cache-Control"] = "no-cache, no-store" },
	})
	if res and res.Success and typeof(res.Body) == "string" and #res.Body > 0 then
		return sanitize(res.Body)
	end
	local msg = res and (res.StatusMessage or res.StatusCode) or "no response"
	error("HTTP failed (" .. tostring(msg) .. "): " .. url, 0)
end

local function wantsLocalFile(path)
	if getGenv().HUB_USE_LOCAL ~= true or typeof(isfile) ~= "function" then
		return false
	end
	-- UI always from GitHub unless explicitly opted in (avoids stale workspace ui.lua).
	if path == "lib/ui.lua" and getGenv().HUB_UI_LOCAL ~= true then
		return false
	end
	return true
end

local function loadModuleSource(base, path)
	local root = getGenv().HUB_LOCAL_ROOT or "hub"
	if wantsLocalFile(path) and isfile(root .. "/" .. path) then
		return sanitize(readfile(root .. "/" .. path)), "local"
	end
	return fetchHttp(base, path), "remote"
end

local function loadTable(base, path)
	local source = loadModuleSource(base, path)
	local fn, err = loadstring(source, path)
	if not fn then
		error("compile " .. path .. ": " .. tostring(err), 0)
	end
	local ok, result = pcall(fn)
	if not ok then
		error("run " .. path .. ": " .. tostring(result), 0)
	end
	if typeof(result) ~= "table" then
		error(path .. " must return a table", 0)
	end
	return result, source
end

local function normalizeId(value)
	local n = tonumber(value)
	return n ~= nil and n or tostring(value)
end

local function findGame(manifest, placeId)
	for _, entry in ipairs(manifest) do
		if typeof(entry.placeIds) == "table" then
			for _, id in ipairs(entry.placeIds) do
				if normalizeId(id) == normalizeId(placeId) then
					return entry
				end
			end
		end
	end
	return KNOWN_GAMES_BY_ID[placeId] or KNOWN_GAMES_BY_ID[tostring(placeId)]
end

local function mergeManifest(manifest)
	local merged, covered = {}, {}
	local function mark(entry)
		for _, id in ipairs(entry.placeIds or {}) do
			covered[normalizeId(id)] = true
		end
	end
	for _, entry in ipairs(manifest) do
		table.insert(merged, entry)
		mark(entry)
	end
	for _, entry in ipairs(getGenv().HUB_EXTRA_GAMES or {}) do
		table.insert(merged, entry)
		mark(entry)
	end
	for _, entry in ipairs(KNOWN_GAME_LIST) do
		for _, id in ipairs(entry.placeIds) do
			if not covered[normalizeId(id)] then
				table.insert(merged, entry)
				mark(entry)
				break
			end
		end
	end
	return merged
end

local success, err = pcall(function()
	warn("[MicroHub] boot loader v" .. LOADER_VERSION)
	local genv = getGenv()
	if genv.HUB_USE_LOCAL == true then
		warn("[MicroHub] HUB_USE_LOCAL is on — workspace hub/ overrides most files (not lib/ui.lua)")
	end
	local base = DEFAULT_BASE
	local config = loadTable(base, "config.lua")
	base = config.Repository or base

	local runtimeSource = loadModuleSource(base, "runtime.lua")
	local runtimeFn = loadstring(runtimeSource, "hub/runtime.lua")
	local ok, Runtime = pcall(runtimeFn)
	if not ok or typeof(Runtime) ~= "table" or typeof(Runtime.init) ~= "function" then
		error("runtime.lua failed: " .. tostring(Runtime), 0)
	end

	local hubName = config.Name or "MicroHub"
	local wasLoaded = shared[LOADED_KEY] == hubName
	local hub = Runtime.init(config)

	local prev = getGenv().__MicroHub
	if typeof(prev) == "table" and typeof(prev.unloadAll) == "function" then
		pcall(prev.unloadAll)
	end
	shared[LOADED_KEY] = nil
	shared[UI_LIB_KEY] = nil

	local entry = findGame(mergeManifest(hub.loadTable("manifest.lua")), game.PlaceId)
	if not entry then
		notify(hubName, "Unsupported game — PlaceId " .. tostring(game.PlaceId))
		warn("[" .. hubName .. "] Unsupported PlaceId:", game.PlaceId)
		return
	end

	warn(
		"[MicroHub] loader v" .. LOADER_VERSION,
		"hub v" .. tostring(config.Version),
		wasLoaded and "(reload)" or "(fresh)"
	)
	notify(hubName, (wasLoaded and "Reloading " or "Loading ") .. (entry.name or "script") .. "...")

	do
		local uiSource, uiOrigin = loadModuleSource(base, "lib/ui.lua")
		if typeof(uiSource) == "string" and uiSource:find("TouchTap", 1, true) then
			local hint = uiOrigin == "local"
				and "Update workspace hub/lib/ui.lua or set getgenv().HUB_USE_LOCAL = false."
				or "GitHub copy is stale — wait a minute and re-run."
			error("lib/ui.lua outdated (TouchTap). " .. hint, 0)
		end
		local uiFn, uiErr = loadstring(uiSource, "lib/ui.lua")
		if not uiFn then
			error("compile lib/ui.lua: " .. tostring(uiErr), 0)
		end
		local uiOk, uiResult = pcall(uiFn)
		if not uiOk then
			error("run lib/ui.lua: " .. tostring(uiResult), 0)
		end
		if typeof(uiResult) ~= "table" then
			error("lib/ui.lua must return a table", 0)
		end
		shared[UI_LIB_KEY] = uiResult
		warn("[MicroHub] UI", uiOrigin, "v" .. tostring(uiResult.version or "?"))
	end

	local origin = hub.run(entry.module)
	warn("[MicroHub]", entry.module, "from", origin)
	shared[LOADED_KEY] = hubName
	notify(hubName, (entry.name or "Game") .. " loaded (v" .. tostring(config.Version) .. ")")
end)

if not success then
	warn("[MicroHub]", err)
	notify("MicroHub", tostring(err))
end
