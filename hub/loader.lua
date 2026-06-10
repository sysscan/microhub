--[[
	MicroHub loader
	Docs: https://docs.voltbz.net/docs/miscellaneous (request)

	Remote-first by default. Stale executor workspace copies are ignored unless:
	  getgenv().HUB_USE_LOCAL = true

	Force refresh everything from GitHub:
	  getgenv().HUB_FORCE_REMOTE = true

	Re-run the loader anytime — previous hub modules are stopped first.
]]

local LOADER_VERSION = 4
local DEFAULT_BASE = "https://raw.githubusercontent.com/sysscan/microhub/main/hub"
local LOADED_KEY = "__MicroHubLoaded"
local UI_LIB_KEY = "__MicroHubUILib"

local KNOWN_GAME_LIST = {
	{
		name = "Warfare",
		module = "games/warfare.lua",
		placeIds = { 83902709332473 },
	},
	{
		name = "Tha Bronx 3",
		module = "games/tha-bronx3.lua",
		placeIds = { 16472538603, 18642421777 },
	},
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

local function getLocalRoot()
	local root = getGenv().HUB_LOCAL_ROOT
	if typeof(root) == "string" and root ~= "" then
		return root:gsub("/+$", "")
	end
	return "hub"
end

local function useLocalFiles()
	if getGenv().HUB_FORCE_REMOTE == true then
		return false
	end
	return getGenv().HUB_USE_LOCAL == true
		and typeof(readfile) == "function"
		and typeof(isfile) == "function"
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

local function hasUtf8Bom(source)
	return typeof(source) == "string"
		and #source >= 3
		and source:byte(1) == 0xEF
		and source:byte(2) == 0xBB
		and source:byte(3) == 0xBF
end

local function sanitize(source)
	if typeof(source) ~= "string" then
		return source
	end
	while hasUtf8Bom(source) do
		source = source:sub(4)
	end
	return source
end

local function fetchHttp(base, path)
	local url = base .. "/" .. path .. "?t=" .. tostring(os.time())
	local res = request({ Url = url, Method = "GET" })
	if res and res.Success and typeof(res.Body) == "string" and #res.Body > 0 then
		return sanitize(res.Body)
	end
	local msg = res and (res.StatusMessage or res.StatusCode) or "no response"
	error("HTTP failed (" .. tostring(msg) .. "): " .. url, 0)
end

local function bootstrapFetch(base, path)
	local localPath = getLocalRoot() .. "/" .. path
	local source

	if useLocalFiles() and isfile(localPath) then
		source = sanitize(readfile(localPath))
		if hasUtf8Bom(source) then
			warn("[MicroHub] stale local file has BOM, using remote:", path)
			source = fetchHttp(base, path)
		end
	else
		source = fetchHttp(base, path)
	end

	if typeof(writefile) == "function" and not useLocalFiles() then
		pcall(writefile, localPath, source)
	end

	return source
end

local function bootstrapCompile(source, chunkName)
	local fn, err = loadstring(sanitize(source), chunkName)
	if not fn then
		error("compile " .. chunkName .. ": " .. tostring(err), 0)
	end
	return fn
end

local function bootstrapLoadTable(base, path)
	local fn = bootstrapCompile(bootstrapFetch(base, path), path)
	local ok, result = pcall(fn)
	if not ok then
		error("run " .. path .. ": " .. tostring(result), 0)
	end
	if typeof(result) ~= "table" then
		error(path .. " must return a table", 0)
	end
	return result
end

local function normalizeId(value)
	if value == nil then
		return nil
	end
	local asNumber = tonumber(value)
	if asNumber ~= nil then
		return asNumber
	end
	return tostring(value)
end

local function idsMatch(left, right)
	local a = normalizeId(left)
	local b = normalizeId(right)
	if a == nil or b == nil then
		return false
	end
	return a == b
end

local function entryCoversPlace(gameEntry, placeId)
	if typeof(gameEntry) ~= "table" or typeof(gameEntry.placeIds) ~= "table" then
		return false
	end
	for _, id in ipairs(gameEntry.placeIds) do
		if idsMatch(id, placeId) then
			return true
		end
	end
	return false
end

local function findGame(manifest, placeId)
	for _, gameEntry in ipairs(manifest) do
		if entryCoversPlace(gameEntry, placeId) then
			return gameEntry
		end
	end
	local normalized = normalizeId(placeId)
	return KNOWN_GAMES_BY_ID[normalized] or KNOWN_GAMES_BY_ID[tostring(normalized)]
end

local function mergeManifest(manifest)
	local merged = {}
	local covered = {}

	local function markEntry(entry)
		if typeof(entry.placeIds) ~= "table" then
			return
		end
		for _, id in ipairs(entry.placeIds) do
			covered[normalizeId(id)] = true
		end
	end

	for _, entry in ipairs(manifest) do
		table.insert(merged, entry)
		markEntry(entry)
	end

	local extra = getGenv().HUB_EXTRA_GAMES
	if typeof(extra) == "table" then
		for _, entry in ipairs(extra) do
			table.insert(merged, entry)
			markEntry(entry)
		end
	end

	for _, entry in ipairs(KNOWN_GAME_LIST) do
		local missing = false
		for _, id in ipairs(entry.placeIds) do
			if not covered[normalizeId(id)] then
				missing = true
				break
			end
		end
		if missing then
			table.insert(merged, entry)
			markEntry(entry)
		end
	end

	return merged
end

local function teardownPreviousHub(hubName)
	local genv = getGenv()
	local hub = genv.__MicroHub
	if typeof(hub) == "table" and typeof(hub.unloadAll) == "function" then
		pcall(hub.unloadAll)
	end
	shared[LOADED_KEY] = nil
	shared[UI_LIB_KEY] = nil
end

local function ensureUILibrary(hub)
	if typeof(shared[UI_LIB_KEY]) == "table" and typeof(shared[UI_LIB_KEY].create) == "function" then
		return shared[UI_LIB_KEY]
	end
	local lib = hub.loadTable("lib/ui.lua")
	shared[UI_LIB_KEY] = lib
	return lib
end

local success, err = pcall(function()
	local base = DEFAULT_BASE
	local config = bootstrapLoadTable(base, "config.lua")
	base = config.Repository or base

	local runtimeSource = bootstrapFetch(base, "runtime.lua")
	local runtimeFn = bootstrapCompile(runtimeSource, "hub/runtime.lua")
	local ok, Runtime = pcall(runtimeFn)
	if not ok or typeof(Runtime) ~= "table" or typeof(Runtime.init) ~= "function" then
		error("runtime.lua failed: " .. tostring(Runtime), 0)
	end

	local hubName = config.Name or "MicroHub"
	local wasLoaded = shared[LOADED_KEY] == hubName

	local hub = Runtime.init(config)
	teardownPreviousHub(hubName)

	local placeId = game.PlaceId
	local manifest = mergeManifest(hub.loadTable("manifest.lua"))
	local entry = findGame(manifest, placeId)

	if not entry then
		notify(hubName, "Unsupported game — PlaceId " .. tostring(placeId))
		warn(
			"[" .. hubName .. "] Unsupported PlaceId:",
			placeId,
			"(loader v" .. tostring(LOADER_VERSION) .. ", hub " .. tostring(config.Version) .. ")"
		)
		return
	end

	notify(hubName, (wasLoaded and "Reloading " or "Loading ") .. (entry.name or "script") .. "...")
	ensureUILibrary(hub)
	hub.run(entry.module)
	shared[LOADED_KEY] = hubName
	notify(hubName, (entry.name or "Game") .. " loaded (v" .. tostring(config.Version) .. ")")
end)

if not success then
	warn("[MicroHub]", err)
	notify("MicroHub", tostring(err))
end
