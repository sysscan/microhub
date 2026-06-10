--[[
	MicroHub loader
	Docs: https://docs.voltbz.net/docs/miscellaneous (request)
]]

local HUB_VERSION = 3

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
	return typeof(readfile) == "function" and typeof(isfile) == "function"
end

local function notify(title, text)
	pcall(function()
		game:GetService("StarterGui"):SetCore("SendNotification", {
			Title = title,
			Text = text,
			Duration = 5,
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
		return res.Body
	end
	local msg = res and (res.StatusMessage or res.StatusCode) or "no response"
	error("HTTP failed (" .. tostring(msg) .. "): " .. url, 0)
end

local function fetch(base, path, forceRemote)
	local localPath = getLocalRoot() .. "/" .. path
	local source
	local usedLocal = false

	if not forceRemote and useLocalFiles() and isfile(localPath) then
		source = readfile(localPath)
		usedLocal = true
	else
		source = fetchHttp(base, path)
	end

	source = sanitize(source)

	if usedLocal and hasUtf8Bom(source) then
		warn("[MicroHub] stale local file has BOM, using remote:", path)
		source = sanitize(fetchHttp(base, path))
	end

	return source
end

local function compile(source, chunkName)
	local fn, err = loadstring(sanitize(source), chunkName)
	if not fn then
		error("compile " .. chunkName .. ": " .. tostring(err), 0)
	end
	return fn
end

local function loadTable(base, path, forceRemote)
	local fn = compile(fetch(base, path, forceRemote), path)
	local ok, result = pcall(fn)
	if not ok then
		error("run " .. path .. ": " .. tostring(result), 0)
	end
	if typeof(result) ~= "table" then
		error(path .. " must return a table", 0)
	end
	return result
end

local function ensureUILibrary(base)
	if typeof(shared[UI_LIB_KEY]) == "table" and typeof(shared[UI_LIB_KEY].create) == "function" then
		return shared[UI_LIB_KEY]
	end
	local lib = loadTable(base, "lib/ui.lua")
	shared[UI_LIB_KEY] = lib
	return lib
end

local function runScript(base, path)
	local fn = compile(fetch(base, path), path)
	local ok, runErr = pcall(fn)
	if not ok then
		error("run " .. path .. ": " .. tostring(runErr), 0)
	end
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

local function loadManifest(base, placeId)
	local manifest = mergeManifest(loadTable(base, "manifest.lua"))
	if findGame(manifest, placeId) then
		return manifest
	end

	if useLocalFiles() then
		warn("[MicroHub] PlaceId", placeId, "missing from local manifest — retrying remote manifest")
		local genv = getGenv()
		local previous = genv.HUB_FORCE_REMOTE
		genv.HUB_FORCE_REMOTE = true
		local ok, remoteManifest = pcall(function()
			return mergeManifest(loadTable(base, "manifest.lua", true))
		end)
		genv.HUB_FORCE_REMOTE = previous
		if ok and findGame(remoteManifest, placeId) then
			return remoteManifest
		end
	end

	return manifest
end

local success, err = pcall(function()
	local base = DEFAULT_BASE
	local config = loadTable(base, "config.lua")
	base = config.Repository or base
	local hubName = config.Name or "MicroHub"

	if shared[LOADED_KEY] == hubName then
		notify(hubName, "Already loaded")
		return
	end

	local placeId = game.PlaceId
	local manifest = loadManifest(base, placeId)
	local entry = findGame(manifest, placeId)

	if not entry then
		notify(hubName, "Unsupported game — PlaceId " .. tostring(placeId))
		warn(
			"[" .. hubName .. "] Unsupported PlaceId:",
			placeId,
			"(loader v" .. tostring(HUB_VERSION) .. ", GameId:",
			game.GameId .. ")"
		)
		return
	end

	notify(hubName, "Loading " .. (entry.name or "script") .. "...")
	ensureUILibrary(base)
	runScript(base, entry.module)
	shared[LOADED_KEY] = hubName
	notify(hubName, (entry.name or "Game") .. " loaded")
end)

if not success then
	warn("[MicroHub]", err)
	notify("MicroHub", tostring(err))
end
